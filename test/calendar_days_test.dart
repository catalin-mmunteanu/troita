import 'package:flutter_test/flutter_test.dart';
import 'package:troita/core/liturgical/calendar_days.dart';
import 'package:troita/core/liturgical/liturgical_calendar.dart';

/// These only bite on a machine whose local zone observes daylight saving —
/// on a UTC CI runner the old `difference().inDays` passed them too. That is
/// precisely how Postul Mare shipped as 47 days on Romanian phones: run them
/// with `TZ=Europe/Bucharest flutter test` to see the case that matters.
void main() {
  group('calendarDaysBetween', () {
    test('counts across the March clock change', () {
      // 29 March 2026 loses an hour in Romania.
      expect(calendarDaysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)),
          2);
      expect(calendarDaysBetween(DateTime(2026, 2, 23), DateTime(2026, 4, 11)),
          47);
    });

    test('counts across the October clock change', () {
      // 25 October 2026 gains an hour.
      expect(
          calendarDaysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)),
          2);
    });

    test('ignores the time of day', () {
      expect(
          calendarDaysBetween(
              DateTime(2026, 3, 28, 23, 59), DateTime(2026, 3, 29, 0, 1)),
          1);
    });

    test('is negative when going backwards', () {
      expect(calendarDaysBetween(DateTime(2026, 4, 11), DateTime(2026, 2, 23)),
          -47);
    });
  });

  test('Postul Mare is 48 days every year, whatever the clock does', () {
    for (int year = 2024; year <= 2035; year++) {
      expect(LiturgicalCalendar.postulMare(year).days, 48, reason: '$year');
    }
  });
}
