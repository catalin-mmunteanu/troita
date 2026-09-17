/// How a kept fast day felt.
///
/// Only ever recorded alongside `kept = true`, and always optional — the
/// question is "did you keep it", and how it felt is a second, skippable one.
enum FastMood {
  hard(-1),
  ok(0),
  good(1);

  const FastMood(this.value);

  final int value;

  static FastMood? fromValue(int? v) => switch (v) {
        -1 => FastMood.hard,
        0 => FastMood.ok,
        1 => FastMood.good,
        _ => null,
      };

  String get label => switch (this) {
        FastMood.hard => 'Greu',
        FastMood.ok => 'Bine',
        FastMood.good => 'Ușor',
      };

  String get description => switch (this) {
        FastMood.hard => 'Am ținut postul, dar mi-a fost greu',
        FastMood.ok => 'Am ținut postul',
        FastMood.good => 'Am ținut postul cu bucurie',
      };
}

/// One recorded day.
class FastDay {
  const FastDay({
    required this.date,
    required this.kept,
    this.mood,
    this.note,
  });

  final DateTime date;

  /// The answer to "ați ținut postul?" — the only required field.
  final bool kept;

  /// Optional. Null means the user answered Da and skipped the faces.
  final FastMood? mood;

  final String? note;

  static String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  factory FastDay.fromRow(Map<String, Object?> row) {
    final List<String> parts = (row['date']! as String).split('-');
    return FastDay(
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      kept: ((row['kept'] as num?)?.toInt() ?? 1) == 1,
      mood: FastMood.fromValue((row['mood'] as num?)?.toInt()),
      note: row['note'] as String?,
    );
  }
}

/// Aggregate for one fasting period, or for all time.
class FastStats {
  const FastStats({
    required this.kept,
    required this.notKept,
    required this.elapsed,
    required this.total,
    required this.byMood,
  });

  /// Days answered Da.
  final int kept;

  /// Days answered Nu. Shown plainly, without commentary.
  final int notKept;

  /// Days of the period that have already passed. The denominator — counting
  /// against the full length while a fast is still running would show everyone
  /// as failing for six weeks.
  final int elapsed;

  /// Full length of the period.
  final int total;

  final Map<FastMood, int> byMood;

  static const FastStats empty = FastStats(
    kept: 0,
    notKept: 0,
    elapsed: 0,
    total: 0,
    byMood: <FastMood, int>{},
  );

  int get answered => kept + notKept;

  double get fraction => elapsed == 0 ? 0 : (kept / elapsed).clamp(0.0, 1.0);
}
