import 'package:sqflite/sqflite.dart';

import '../liturgical/fast_level.dart';
import '../models/feast.dart';

/// Reads the curated `feasts` table and resolves it onto real dates.
///
/// The table is ~80 rows, so it is loaded once and indexed in memory. Resolving
/// movable feasts means the index is per-year; years are cached as they are
/// asked for, which in practice means one or two.
class FeastRepository {
  FeastRepository(this._db);

  final Database _db;

  List<Feast>? _all;
  final Map<int, Map<int, List<Feast>>> _byYear = <int, Map<int, List<Feast>>>{};

  static Future<FeastRepository> open(String path) async =>
      FeastRepository(await openDatabase(path, readOnly: true));

  Future<List<Feast>> all() async {
    if (_all != null) return _all!;
    final List<Map<String, Object?>> rows = await _db.query('feasts');
    return _all = rows.map(Feast.fromRow).toList(growable: false);
  }

  /// Index for [year], keyed by day-of-year so lookups are O(1).
  Future<Map<int, List<Feast>>> _index(int year) async {
    final Map<int, List<Feast>>? cached = _byYear[year];
    if (cached != null) return cached;

    final Map<int, List<Feast>> index = <int, List<Feast>>{};
    for (final Feast f in await all()) {
      final DateTime? date = f.dateIn(year);
      if (date == null) continue;
      index.putIfAbsent(_key(date), () => <Feast>[]).add(f);
    }
    // Highest rank first, so `forDate` can just take the head.
    for (final List<Feast> list in index.values) {
      list.sort((Feast a, Feast b) => b.rank.weight.compareTo(a.rank.weight));
    }
    return _byYear[year] = index;
  }

  static int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// Every feast falling on [date], most important first.
  Future<List<Feast>> onDate(DateTime date) async {
    final Map<int, List<Feast>> index = await _index(date.year);
    return index[_key(DateTime(date.year, date.month, date.day))] ??
        const <Feast>[];
  }

  /// The one that should drive the day's marker and fasting override.
  Future<Feast?> primaryOn(DateTime date) async {
    final List<Feast> feasts = await onDate(date);
    return feasts.isEmpty ? null : feasts.first;
  }

  /// Convenience for the engine: rank and dezlegare in a single lookup.
  Future<({FeastRank rank, FastLevel? dezlegare})> ruleOn(DateTime date) async {
    final Feast? feast = await primaryOn(date);
    return (
      rank: feast?.rank ?? FeastRank.simplu,
      // A lower-ranked feast can still carry the dezlegare, so scan them all.
      dezlegare: (await onDate(date))
          .map((Feast f) => f.dezlegare)
          .firstWhere((FastLevel? d) => d != null, orElse: () => null),
    );
  }

  /// All feasts in a calendar month, keyed by day number.
  Future<Map<int, List<Feast>>> forMonth(int year, int month) async {
    final Map<int, List<Feast>> index = await _index(year);
    final Map<int, List<Feast>> out = <int, List<Feast>>{};
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final List<Feast>? hits = index[_key(DateTime(year, month, day))];
      if (hits != null && hits.isNotEmpty) out[day] = hits;
    }
    return out;
  }

  /// The next [limit] feasts of at least [minRank], for the home list.
  Future<List<({Feast feast, DateTime date})>> upcoming({
    DateTime? from,
    int limit = 5,
    FeastRank minRank = FeastRank.cruceRosie,
  }) async {
    final DateTime start = from ?? DateTime.now();
    final DateTime today = DateTime(start.year, start.month, start.day);

    final List<({Feast feast, DateTime date})> out =
        <({Feast feast, DateTime date})>[];

    // Look into next year too, so late December doesn't come back empty.
    for (final int year in <int>[today.year, today.year + 1]) {
      for (final Feast f in await all()) {
        if (f.rank.weight < minRank.weight) continue;
        final DateTime? date = f.dateIn(year);
        if (date == null || date.isBefore(today)) continue;
        out.add((feast: f, date: date));
      }
      if (out.length >= limit) break;
    }

    out.sort((({Feast feast, DateTime date}) a,
            ({Feast feast, DateTime date}) b) =>
        a.date.compareTo(b.date));
    return out.take(limit).toList(growable: false);
  }

  Future<void> close() => _db.close();
}
