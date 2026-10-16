import 'package:sqflite/sqflite.dart';

import 'user_database.dart';

/// The user's marks on one church.
class ChurchMark {
  const ChurchMark({
    required this.churchId,
    this.favourite = false,
    this.visited = false,
    this.visitedOn,
  });

  final String churchId;
  final bool favourite;
  final bool visited;

  /// The day it was first marked visited, if it is.
  final DateTime? visitedOn;

  bool get isEmpty => !favourite && !visited;

  factory ChurchMark.fromRow(Map<String, Object?> row) {
    final String? on = row['visited_on'] as String?;
    return ChurchMark(
      churchId: row['church_id']! as String,
      favourite: ((row['favourite'] as num?)?.toInt() ?? 0) == 1,
      visited: ((row['visited'] as num?)?.toInt() ?? 0) == 1,
      visitedOn: on == null ? null : DateTime.tryParse(on),
    );
  }
}

/// Favourites and visits, stored in troita_user.db so a data update never
/// touches them.
class ChurchMarksRepository {
  ChurchMarksRepository(this._db);

  final Database _db;

  static Future<ChurchMarksRepository> open() async =>
      ChurchMarksRepository((await UserDatabase.open()).db);

  Future<ChurchMark> forChurch(String id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'church_marks',
      where: 'church_id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? ChurchMark(churchId: id) : ChurchMark.fromRow(rows.first);
  }

  /// Every church with at least one mark, most recently changed first.
  Future<List<ChurchMark>> all() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'church_marks',
      where: 'favourite = 1 OR visited = 1',
      orderBy: 'updated_at DESC',
    );
    return rows.map(ChurchMark.fromRow).toList(growable: false);
  }

  Future<Set<String>> favouriteIds() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'church_marks',
      columns: <String>['church_id'],
      where: 'favourite = 1',
    );
    return <String>{for (final Map<String, Object?> r in rows) r['church_id']! as String};
  }

  Future<ChurchMark> setFavourite(String id, bool on) async {
    final ChurchMark current = await forChurch(id);
    return _write(ChurchMark(
      churchId: id,
      favourite: on,
      visited: current.visited,
      visitedOn: current.visitedOn,
    ));
  }

  /// Marking visited records the day; unmarking forgets it.
  Future<ChurchMark> setVisited(String id, bool on) async {
    final ChurchMark current = await forChurch(id);
    final DateTime now = DateTime.now();
    return _write(ChurchMark(
      churchId: id,
      favourite: current.favourite,
      visited: on,
      visitedOn: on
          ? (current.visitedOn ?? DateTime(now.year, now.month, now.day))
          : null,
    ));
  }

  Future<ChurchMark> _write(ChurchMark mark) async {
    if (mark.isEmpty) {
      // No row for a church with no marks: the table stays the list of
      // churches the user cares about, not of every one they ever tapped.
      await _db.delete('church_marks',
          where: 'church_id = ?', whereArgs: <Object?>[mark.churchId]);
      return mark;
    }
    final DateTime? on = mark.visitedOn;
    await _db.insert(
      'church_marks',
      <String, Object?>{
        'church_id': mark.churchId,
        'favourite': mark.favourite ? 1 : 0,
        'visited': mark.visited ? 1 : 0,
        'visited_on': on == null
            ? null
            : '${on.year.toString().padLeft(4, '0')}-'
                '${on.month.toString().padLeft(2, '0')}-'
                '${on.day.toString().padLeft(2, '0')}',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return mark;
  }
}
