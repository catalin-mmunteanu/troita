/// One recorded day: the answer to "ați ținut postul?".
///
/// There was a `mood` here too — greu, bine, ușor — from an optional second
/// question. The question is gone; the database column it lived in is left in
/// place rather than migrated away, since dropping a column in SQLite means
/// copying the table, and an ignored column costs nothing.
class FastDay {
  const FastDay({
    required this.date,
    required this.kept,
    this.note,
  });

  final DateTime date;

  /// The answer to "ați ținut postul?" — the only required field.
  final bool kept;

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

  static const FastStats empty = FastStats(
    kept: 0,
    notKept: 0,
    elapsed: 0,
    total: 0,
  );

  int get answered => kept + notKept;

  double get fraction => elapsed == 0 ? 0 : (kept / elapsed).clamp(0.0, 1.0);
}
