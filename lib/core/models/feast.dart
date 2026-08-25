import '../liturgical/fast_level.dart';
import 'feast_calendar.dart';

/// A commemoration from the `feasts` table.
///
/// Fixed feasts carry [monthDay]; movable ones carry [movableKey], resolved
/// against Pascha by [FeastCalendar]. Exactly one is non-null.
class Feast {
  const Feast({
    required this.id,
    required this.name,
    required this.rank,
    this.monthDay,
    this.movableKey,
    this.shortName,
    this.kind,
    this.note,
    this.dezlegare,
  });

  final String id;
  final String name;
  final FeastRank rank;

  /// 'MM-DD' for fixed feasts.
  final String? monthDay;

  /// Key into FeastCalendar's movable table.
  final String? movableKey;

  final String? shortName;

  /// domnesc | maica_domnului | sfant | romanesc
  final String? kind;

  final String? note;

  /// Overrides the fast level the engine would otherwise compute — Sf. Nicolae
  /// brings a dezlegare la pește even though it falls inside the Nativity fast.
  final FastLevel? dezlegare;

  bool get isMovable => movableKey != null;

  String get displayName => shortName ?? name;

  /// The date this feast falls on in [year], or null if unresolvable.
  DateTime? dateIn(int year) {
    if (movableKey != null) {
      return FeastCalendar.resolve('movable:$movableKey', year: year);
    }
    if (monthDay == null) return null;
    return FeastCalendar.resolve(monthDay, year: year);
  }

  static FastLevel? _parseDezlegare(String? value) => switch (value) {
        'fish' => FastLevel.fish,
        'wineOil' => FastLevel.wineOil,
        'wine_oil' => FastLevel.wineOil,
        'none' => FastLevel.none,
        'dairy' => FastLevel.dairy,
        _ => null,
      };

  factory Feast.fromRow(Map<String, Object?> row) => Feast(
        id: row['id']! as String,
        name: row['name']! as String,
        rank: FeastRank.parse(row['rank'] as String?),
        monthDay: row['month_day'] as String?,
        movableKey: row['movable_key'] as String?,
        shortName: row['short_name'] as String?,
        kind: row['kind'] as String?,
        note: row['note'] as String?,
        dezlegare: _parseDezlegare(row['dezlegare'] as String?),
      );
}
