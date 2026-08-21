import 'fast_level.dart';

/// A named stretch of the year with its own fasting rules.
class FastingPeriod {
  const FastingPeriod({
    required this.kind,
    required this.start,
    required this.end,
    this.note,
  });

  final FastingPeriodKind kind;

  /// Inclusive.
  final DateTime start;

  /// Inclusive.
  final DateTime end;

  final String? note;

  String get label => kind.label;

  int get days => end.difference(start).inDays + 1;

  bool contains(DateTime date) {
    final DateTime d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  bool isFirstDay(DateTime date) =>
      DateTime(date.year, date.month, date.day) == start;

  bool isLastDay(DateTime date) =>
      DateTime(date.year, date.month, date.day) == end;

  PeriodStatus statusOn(DateTime today) {
    final DateTime d = DateTime(today.year, today.month, today.day);
    if (d.isBefore(start)) return PeriodStatus.upcoming;
    if (d.isAfter(end)) return PeriodStatus.finished;
    return PeriodStatus.active;
  }
}

enum PeriodStatus {
  active,
  upcoming,
  finished;

  String get label => switch (this) {
        PeriodStatus.active => 'În desfășurare',
        PeriodStatus.upcoming => 'În curând',
        PeriodStatus.finished => 'Finalizat',
      };
}
