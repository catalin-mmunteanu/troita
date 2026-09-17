import 'package:sqflite/sqflite.dart';

import '../liturgical/fasting_period.dart';
import '../models/fast_day.dart';
import 'user_database.dart';

/// Reads and writes the user's record of kept fast days.
class FastJournalRepository {
  FastJournalRepository(this._db);

  final Database _db;

  static Future<FastJournalRepository> open() async =>
      FastJournalRepository((await UserDatabase.open()).db);

  // ------------------------------------------------------------------ writes

  /// Answer "ați ținut postul?".
  ///
  /// Preserves any mood already recorded when the answer stays Da, so
  /// re-tapping Da does not silently erase the face. Answering Nu clears the
  /// mood, because "how did it feel" only makes sense for a kept day.
  Future<void> setKept(DateTime date, bool kept) async {
    final FastDay? existing = await forDate(date);
    await _db.insert(
      'fast_days',
      <String, Object?>{
        'date': FastDay.key(date),
        'kept': kept ? 1 : 0,
        'mood': kept ? existing?.mood?.value : null,
        'note': existing?.note,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Set or clear the optional mood. Implies the day was kept.
  Future<void> setMood(DateTime date, FastMood? mood) async {
    final FastDay? existing = await forDate(date);
    await _db.insert(
      'fast_days',
      <String, Object?>{
        'date': FastDay.key(date),
        'kept': 1,
        'mood': mood?.value,
        'note': existing?.note,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Tapping the selected answer again removes the day entirely — the undo,
  /// without a separate delete affordance.
  Future<void> clear(DateTime date) async {
    await _db.delete(
      'fast_days',
      where: 'date = ?',
      whereArgs: <Object?>[FastDay.key(date)],
    );
  }

  Future<void> toggleKept(DateTime date, bool kept) async {
    final FastDay? existing = await forDate(date);
    if (existing != null && existing.kept == kept) {
      await clear(date);
    } else {
      await setKept(date, kept);
    }
  }

  Future<void> toggleMood(DateTime date, FastMood mood) async {
    final FastDay? existing = await forDate(date);
    await setMood(date, existing?.mood == mood ? null : mood);
  }

  // ------------------------------------------------------------------- reads

  Future<FastDay?> forDate(DateTime date) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'fast_days',
      where: 'date = ?',
      whereArgs: <Object?>[FastDay.key(date)],
      limit: 1,
    );
    return rows.isEmpty ? null : FastDay.fromRow(rows.first);
  }

  /// Marked days in a range, keyed by `YYYY-MM-DD` for O(1) lookup while
  /// building a list of rows.
  Future<Map<String, FastDay>> inRange(DateTime from, DateTime to) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'fast_days',
      where: 'date >= ? AND date <= ?',
      whereArgs: <Object?>[FastDay.key(from), FastDay.key(to)],
    );
    return <String, FastDay>{
      for (final Map<String, Object?> r in rows)
        r['date']! as String: FastDay.fromRow(r),
    };
  }

  /// Aggregate for one period.
  ///
  /// The denominator is days *elapsed*, not the period's full length. Measuring
  /// against the full length would show someone as 5% through Postul Mare on
  /// day two, which reads as failure rather than progress.
  Future<FastStats> statsFor(FastingPeriod period, {DateTime? asOf}) async {
    final DateTime now = asOf ?? DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final Map<String, FastDay> days = await inRange(period.start, period.end);

    final DateTime lastCounted =
        today.isBefore(period.end) ? today : period.end;
    final int elapsed = today.isBefore(period.start)
        ? 0
        : lastCounted.difference(period.start).inDays + 1;

    final Map<FastMood, int> byMood = <FastMood, int>{};
    int kept = 0;
    int notKept = 0;
    for (final FastDay d in days.values) {
      if (d.kept) {
        kept++;
        if (d.mood != null) byMood[d.mood!] = (byMood[d.mood!] ?? 0) + 1;
      } else {
        notKept++;
      }
    }

    return FastStats(
      kept: kept,
      notKept: notKept,
      elapsed: elapsed.clamp(0, period.days),
      total: period.days,
      byMood: byMood,
    );
  }

  /// Everything ever marked, for the all-time figure.
  Future<FastStats> allTime() async {
    final List<Map<String, Object?>> rows = await _db.query('fast_days');
    final Map<FastMood, int> byMood = <FastMood, int>{};
    int kept = 0;
    int notKept = 0;
    for (final Map<String, Object?> r in rows) {
      final FastDay d = FastDay.fromRow(r);
      if (d.kept) {
        kept++;
        if (d.mood != null) byMood[d.mood!] = (byMood[d.mood!] ?? 0) + 1;
      } else {
        notKept++;
      }
    }
    return FastStats(
      kept: kept,
      notKept: notKept,
      elapsed: rows.length,
      total: rows.length,
      byMood: byMood,
    );
  }

  Future<int> totalKept() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM fast_days WHERE kept = 1'),
      ) ??
      0;
}
