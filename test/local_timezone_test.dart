import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:troita/core/notifications/local_timezone.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('LocalTimezone.resolve', () {
    test('picks Bucharest for EET in winter', () {
      // 15 January, +02:00 — Bucharest, Athens and Helsinki all match, and the
      // candidate order is what makes Romania win.
      final DateTime winter = tz.TZDateTime(
        tz.getLocation('Europe/Bucharest'), 2026, 1, 15, 12,
      );
      expect(LocalTimezone.resolve(now: winter), 'Europe/Bucharest');
    });

    test('picks Bucharest for EEST in summer', () {
      final DateTime summer = tz.TZDateTime(
        tz.getLocation('Europe/Bucharest'), 2026, 7, 15, 12,
      );
      expect(LocalTimezone.resolve(now: summer), 'Europe/Bucharest');
    });

    test('distinguishes central European time from eastern', () {
      final DateTime rome = tz.TZDateTime(
        tz.getLocation('Europe/Rome'), 2026, 1, 15, 12,
      );
      // +01:00 in January cannot be Bucharest.
      expect(LocalTimezone.resolve(now: rome), isNot('Europe/Bucharest'));
      expect(tz.getLocation(LocalTimezone.resolve(now: rome))
          .currentTimeZone.offset,
          tz.getLocation('Europe/Rome').currentTimeZone.offset);
    });

    test('falls back to Bucharest rather than throwing', () {
      // No candidate is at +05:45 (Kathmandu), so the fallback must hold.
      // A TZDateTime carries its zone's offset; a plain DateTime.utc() would
      // report +00:00 however many minutes are added, and match London.
      final DateTime odd = tz.TZDateTime(
        tz.getLocation('Asia/Kathmandu'), 2026, 3, 1, 12,
      );
      expect(odd.timeZoneOffset, const Duration(hours: 5, minutes: 45));
      expect(LocalTimezone.resolve(now: odd), LocalTimezone.fallback);
    });

    test('apply() sets tz.local and returns the name', () {
      final String name = LocalTimezone.apply();
      expect(name, isNotEmpty);
      expect(tz.local.name, name);
    });
  });
}
