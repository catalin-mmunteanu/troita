import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:troita/core/data/local_church_repository.dart';
import 'package:troita/core/models/church.dart';

/// Builds an in-memory database from tool/schema.sql itself.
///
/// This used to carry its own copy of the CREATE TABLE, which drifted the
/// moment the real schema gained `search_fold`: the repository started
/// querying a column the test database did not have, and every search test
/// failed with "no such column". Loading the canonical file means the test can
/// only ever disagree with production on purpose.
Future<Database> _seed() async {
  final Database db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  final String schema = File('tool/schema.sql').readAsStringSync()
      // Comments first: several contain semicolons mid-sentence, which would
      // otherwise split a statement in half.
      .replaceAll(RegExp(r'--[^\n]*'), '');
  for (final String statement in schema.split(';')) {
    final String sql = statement.trim();
    if (sql.isNotEmpty) await db.execute(sql);
  }

  Future<void> add(String id, String name, double lat, double lon,
      {String? feast, int deleted = 0, int priority = 0}) async {
    await db.insert('churches', <String, Object?>{
      'id': id, 'name': name, 'kind': 'church', 'lat': lat, 'lon': lon,
      // Folded exactly as build_seed.add_search_fold does, so search runs
      // against the same haystack it sees in production.
      'search_fold': LocalChurchRepository.foldForSearch(name),
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

  test('search ignores diacritics and case', () async {
    // Typed the way a phone keyboard produces it: no ț, no capital.
    expect((await repo.search('coltea')).single.id, 'c:coltea');
    expect((await repo.search('COLȚEA')).single.id, 'c:coltea');
  });

  test('search never returns soft-deleted rows', () async {
    // "Demolată" is deleted; its fold is still in the table.
    expect(await repo.search('demolata'), isEmpty);
  });

  test('upcomingFeasts filters by proximity to the feast', () async {
    // Cernica's hram is 6 December; nothing else has a feast at all.
    final List<Church> found = await repo.upcomingFeasts(days: 400);
    expect(found.map((Church c) => c.id), <String>['c:cernica']);
  });
}
