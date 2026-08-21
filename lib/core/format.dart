import 'package:intl/intl.dart';

import 'models/feast_calendar.dart';

/// Shared formatting. Romanian-only for now; when a second locale appears these
/// become the call sites to swap for ARB lookups.
class Fmt {
  const Fmt._();

  static String distance(double? metres) {
    if (metres == null) return '';
    if (metres < 950) return '${(metres / 10).round() * 10} m';
    if (metres < 10000) return '${(metres / 1000).toStringAsFixed(1)} km';
    return '${(metres / 1000).round()} km';
  }

  static String kind(String kind) => switch (kind) {
        'monastery' => 'Mănăstire',
        'cathedral' => 'Catedrală',
        'chapel' => 'Paraclis',
        'wayside_cross' => 'Troiță',
        _ => 'Biserică',
      };

  static String? feast(String? feastDay) {
    final DateTime? date = FeastCalendar.next(feastDay);
    if (date == null) return null;
    return DateFormat('d MMMM', 'ro').format(date);
  }

  static String? feastRelative(String? feastDay) {
    final int? days = FeastCalendar.daysUntil(feastDay);
    if (days == null) return null;
    return switch (days) {
      0 => 'Hramul este astăzi',
      1 => 'Hramul este mâine',
      < 14 => 'Hramul peste $days zile',
      _ => null,
    };
  }

  static String date(DateTime? d) =>
      d == null ? '' : DateFormat('d MMM, HH:mm', 'ro').format(d);
}
