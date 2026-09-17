import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Everything the user creates, in a database of its own.
///
/// This is deliberately **not** `churches.db`. That file is replaced wholesale
/// by `ChurchStore.copySeed()` whenever a new dataset ships, so anything stored
/// there would vanish the first time you push updated calendar data. A user's
/// record of a fast they kept is not something to lose in a content update.
///
/// Owned entirely by Dart — the native side never touches it.
class UserDatabase {
  UserDatabase._(this.db);

  final Database db;

  static const String fileName = 'troita_user.db';
  static const int _version = 2;

  static UserDatabase? _instance;

  static Future<UserDatabase> open() async {
    if (_instance != null) return _instance!;

    final String dir = await getDatabasesPath();
    await Directory(dir).create(recursive: true);
    final String path = p.join(dir, fileName);

    final Database db = await openDatabase(
      path,
      version: _version,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        await db.execute(_createFastDays);
        // Range scans by date are the only query shape, and TEXT dates in
        // ISO order sort correctly, so the primary key already covers it.
        await db.execute(
          'CREATE INDEX idx_fast_days_updated ON fast_days(updated_at DESC)',
        );
      },
      onUpgrade: (Database db, int from, int to) async {
        if (from < 2) await _migrateToV2(db);
      },
    );

    return _instance = UserDatabase._(db);
  }

  /// v2 splits "did you keep it" from "how did it feel".
  ///
  /// In v1 the presence of a row meant the fast was kept and `mood` was
  /// required. Now `kept` is explicit — a user can record a day they did not
  /// keep — and `mood` is optional, because being asked how it felt every day
  /// is a chore.
  ///
  /// SQLite cannot drop a NOT NULL constraint in place, so this is the
  /// copy-and-rename dance. Existing rows backfill to kept = 1, which is what
  /// they meant.
  static const String _createFastDays = '''
    CREATE TABLE fast_days (
      date       TEXT    PRIMARY KEY,   -- 'YYYY-MM-DD', local date
      kept       INTEGER NOT NULL,      -- 1 = Da, 0 = Nu
      mood       INTEGER,               -- -1 greu, 0 bine, 1 ușor; optional
      note       TEXT,
      updated_at INTEGER NOT NULL
    )
  ''';

  static Future<void> _migrateToV2(Database db) async {
    await db.transaction((Transaction txn) async {
      await txn.execute('ALTER TABLE fast_days RENAME TO fast_days_v1');
      await txn.execute(_createFastDays);
      await txn.execute('''
        INSERT INTO fast_days (date, kept, mood, note, updated_at)
        SELECT date, 1, mood, note, updated_at FROM fast_days_v1
      ''');
      await txn.execute('DROP TABLE fast_days_v1');
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_fast_days_updated '
        'ON fast_days(updated_at DESC)',
      );
    });
  }

  Future<void> close() async {
    await db.close();
    _instance = null;
  }
}
