import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:troita/core/data/local_church_repository.dart';
import 'package:troita/core/models/church.dart';

/// Builds an in-memory database with the production schema, so these tests
/// exercise the same SQL the app runs.
Future<Database> _seed() async {
  final Database db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('''
    CREATE TABLE churches (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, kind TEXT NOT NULL,
      denomination TEXT, lat REAL NOT NULL, lon REAL NOT NULL, patron TEXT,
      feast_day TEXT, year_built INTEGER, history TEXT, photo_ref TEXT,
      priority INTEGER NOT NULL DEFAULT 0,
      address TEXT, wikidata TEXT, source TEXT NOT NULL,
      verified INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
  ''');

  Future<void> add(String id, String name, double lat, double lon,
      {String? feast, int deleted = 0, int priority = 0}) async {
    await db.insert('churches', <String, Object?>{
      'id': id, 'name': name, 'kind': 'church', 'lat': lat, 'lon': lon,
      'feast_day': feast, 'priority': priority, 'source': 'manual',
      'updated_at': '2026-01-01T00:00:00Z', 'deleted': deleted,
    });
  }

  // Real Bucharest coordinates so the distances mean something.
  await add('c:coltea', 'Colțea', 44.43306, 26.10250, priority: 80);
  await add('c:stavropoleos', 'Stavropoleos', 44.43183, 26.09747, priority: 100);
  await add('c:cernica', 'Cernica', 44.42306, 26.28306, feast: '12-06');
  await add('c:snagov', 'Snagov', 44.70500, 26.17694);
  await add('c:sters', 'Demolată', 44.43300, 26.10240, deleted: 1);
  return db;
}

void main() {
  setUpAll(sqfliteFfiInit);

  late LocalChurchRepository repo;

  setUp(() async => repo = LocalChurchRepository(await _seed()));
  tearDown(() async => repo.close());

  test('nearby orders by true distance, not by bounding box', () async {
    final List<Church> found = await repo.nearby(
      lat: 44.4325, lon: 26.1039, radiusM: 20000,
    );
    expect(found.map((Church c) => c.id).toList(),
        <String>['c:coltea', 'c:stavropoleos', 'c:cernica']);
    expect(found.first.distanceM, lessThan(200));
  });

  test('nearby excludes rows outside the radius', () async {
    final List<Church> found = await repo.nearby(
      lat: 44.4325, lon: 26.1039, radiusM: 1000,
    );
    expect(found.map((Church c) => c.id), isNot(contains('c:cernica')));
    expect(found.map((Church c) => c.id), isNot(contains('c:snagov')));
  });

  test('nearby never returns soft-deleted rows', () async {
    final List<Church> found = await repo.nearby(
      lat: 44.4325, lon: 26.1039, radiusM: 20000,
    );
    expect(found.map((Church c) => c.id), isNot(contains('c:sters')));
  });

  test('nearby respects the limit', () async {
    final List<Church> found = await repo.nearby(
      lat: 44.4325, lon: 26.1039, radiusM: 50000, limit: 2,
    );
    expect(found, hasLength(2));
  });

  test('byId round-trips', () async {
    expect((await repo.byId('c:snagov'))?.name, 'Snagov');
    expect(await repo.byId('c:nonexistent'), isNull);
  });

  test('search matches name fragments', () async {
    final List<Church> found = await repo.search('stavro');
    expect(found.single.id, 'c:stavropoleos');
  });

  test('upcomingFeasts filters by proximity to the feast', () async {
    // Cernica's hram is 6 December; nothing else has a feast at all.
    final List<Church> found = await repo.upcomingFeasts(days: 400);
    expect(found.map((Church c) => c.id), <String>['c:cernica']);
  });
}
