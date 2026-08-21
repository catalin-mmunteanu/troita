import 'package:sqflite/sqflite.dart';

/// How church data gets onto the device.
///
/// This is the entire backend migration, isolated behind one interface.
///
///  * MVP: [BundledSeedSync] — the native side copies a prepopulated .db out of
///    assets, so `sync()` has nothing to do.
///  * Later: [RemoteSync] — `GET /churches?bbox=…&since=…` and upsert into the
///    same tables.
///
/// The database stays the runtime source of truth in both cases. This matters
/// more than it looks: the geofencing path runs in a dead process with no
/// network guarantee, so it must never depend on an API call. The backend is a
/// sync source, not a query path. Lock that in now and the migration is purely
/// additive.
abstract interface class ChurchSyncService {
  /// Returns the number of rows written. [since] is ignored by implementations
  /// that have no notion of incremental updates.
  Future<int> sync({DateTime? since});

  Future<DateTime?> lastSyncedAt();
}

/// MVP implementation: the seed is baked into the APK and installed natively.
class BundledSeedSync implements ChurchSyncService {
  const BundledSeedSync(this.seedVersion);

  final String? seedVersion;

  @override
  Future<int> sync({DateTime? since}) async => 0;

  @override
  Future<DateTime?> lastSyncedAt() async => null;
}

/// Sketch of the post-backend implementation. Left unwired on purpose — it
/// exists so the shape of the eventual call site is fixed today.
class RemoteSync implements ChurchSyncService {
  RemoteSync({required this.db, required this.baseUri, required this.fetchJson});

  final Database db;
  final Uri baseUri;

  /// Injected so this file needs no HTTP dependency yet.
  final Future<List<Map<String, Object?>>> Function(Uri uri) fetchJson;

  @override
  Future<int> sync({DateTime? since}) async {
    final Uri uri = baseUri.replace(
      path: '/v1/churches',
      queryParameters: <String, String>{
        if (since != null) 'since': since.toUtc().toIso8601String(),
      },
    );

    final List<Map<String, Object?>> rows = await fetchJson(uri);

    // Upsert on the stable id. Soft deletes arrive as rows with deleted = 1 so
    // a removed church disappears from the geofence window on the next rebuild
    // without needing a separate deletion feed.
    final Batch batch = db.batch();
    for (final Map<String, Object?> row in rows) {
      batch.insert(
        'churches',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    await db.insert(
      'meta',
      <String, Object?>{
        'key': 'last_synced_at',
        'value': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return rows.length;
  }

  @override
  Future<DateTime?> lastSyncedAt() async {
    final List<Map<String, Object?>> rows = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: <Object?>['last_synced_at'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['value']! as String);
  }
}
