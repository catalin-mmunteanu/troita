import 'package:sqflite/sqflite.dart';

import '../liturgical/fast_level.dart';
import '../liturgical/liturgical_calendar.dart';
import '../models/feast.dart';
import '../models/sinaxar.dart';
import 'feast_repository.dart';

/// Everything the calendar screens need about one day, assembled in one place.
class DayEntry {
  const DayEntry({
    required this.date,
    required this.feasts,
    required this.liturgical,
    this.sinaxar,
    this.override,
  });

  final DateTime date;
  final List<Feast> feasts;
  final LiturgicalDay liturgical;
  final Sinaxar? sinaxar;
  final DayOverride? override;

  Feast? get primary => feasts.isEmpty ? null : feasts.first;

  FeastRank get rank => primary?.rank ?? FeastRank.simplu;

  bool get isSunday => date.weekday == DateTime.sunday;

  /// Every commemoration on the day, joined the way a printed calendar sets it.
  String get title => feasts.isEmpty
      ? 'Pomenirea zilei'
      : feasts.map((Feast f) => f.name).join('; ');
}

/// Assembles [DayEntry] values from the feast table, the bundled sinaxar text
/// and the published overrides, on top of the computed liturgical engine.
class DayRepository {
  DayRepository(this._db, this._feasts);

  final Database _db;
  final FeastRepository _feasts;

  final Map<String, Sinaxar?> _sinaxarCache = <String, Sinaxar?>{};
  final Map<String, DayOverride?> _overrideCache = <String, DayOverride?>{};

  static String _key(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Sinaxar?> sinaxarFor(DateTime date) async {
    final String key = _key(date);
    if (_sinaxarCache.containsKey(key)) return _sinaxarCache[key];
    final List<Map<String, Object?>> rows = await _db.query(
      'sinaxar',
      where: 'month_day = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    return _sinaxarCache[key] =
        rows.isEmpty ? null : Sinaxar.fromRow(rows.first);
  }

  Future<DayOverride?> overrideFor(DateTime date) async {
    final String key = '${date.year}:${_key(date)}';
    if (_overrideCache.containsKey(key)) return _overrideCache[key];
    final List<Map<String, Object?>> rows = await _db.query(
      'day_overrides',
      where: 'year = ? AND month_day = ?',
      whereArgs: <Object?>[date.year, _key(date)],
      limit: 1,
    );
    return _overrideCache[key] =
        rows.isEmpty ? null : DayOverride.fromRow(rows.first);
  }

  /// The published level wins over the computed one.
  ///
  /// Not a lack of confidence in the engine — it is exact on period boundaries,
  /// glas and the weekly fast. But dezlegările inside a great fast follow each
  /// day's commemoration rather than the weekday, and no rule reproduces that.
  /// Where a published value exists, use it; otherwise compute.
  static FastLevel? _parseLevel(String? raw) => switch (raw) {
        'none' => FastLevel.none,
        'dairy' => FastLevel.dairy,
        'fish' => FastLevel.fish,
        'wineOil' => FastLevel.wineOil,
        'fast' => FastLevel.fast,
        'strict' => FastLevel.strict,
        _ => null,
      };

  Future<DayEntry> entryFor(DateTime date, {bool withText = false}) async {
    final DateTime d = DateTime(date.year, date.month, date.day);
    final List<Feast> feasts = await _feasts.onDate(d);
    final DayOverride? override = await overrideFor(d);

    LiturgicalDay day = LiturgicalCalendar.dayFor(
      d,
      rank: feasts.isEmpty ? FeastRank.simplu : feasts.first.rank,
      dezlegare: feasts
          .map((Feast f) => f.dezlegare)
          .firstWhere((FastLevel? x) => x != null, orElse: () => null),
    );

    final FastLevel? published = _parseLevel(override?.fastLevel);
    if (published != null && published != day.fastLevel) {
      day = LiturgicalDay(
        date: day.date,
        fastLevel: published,
        period: day.period,
        isPeriodStart: day.isPeriodStart,
        isPeriodEnd: day.isPeriodEnd,
        glas: override?.glas ?? day.glas,
        voscreasna: override?.voscreasna ?? day.voscreasna,
        note: override?.notes ?? day.note,
      );
    }

    return DayEntry(
      date: d,
      feasts: feasts,
      liturgical: day,
      sinaxar: withText ? await sinaxarFor(d) : null,
      override: override,
    );
  }

  /// Every day in a month, in order. One pass, for the day list.
  Future<List<DayEntry>> forMonth(int year, int month) async {
    final int days = DateTime(year, month + 1, 0).day;
    return <DayEntry>[
      for (int day = 1; day <= days; day++)
        await entryFor(DateTime(year, month, day)),
    ];
  }

  Future<bool> hasSinaxarText() async {
    final int count = Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM sinaxar'),
        ) ??
        0;
    return count > 0;
  }
}
