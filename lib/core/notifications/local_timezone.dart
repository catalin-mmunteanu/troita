import 'package:timezone/timezone.dart' as tz;

/// Resolves the device's IANA time zone without a plugin.
///
/// `flutter_timezone` existed here to return one string. It also ships a
/// `buildscript` block pinning Kotlin Gradle Plugin 1.7.10 and AGP 7.3.0, which
/// against a modern toolchain produces "Daemon compilation failed: null" — an
/// unreasonable price for `Europe/Bucharest`.
///
/// Instead: match the device's current UTC offset against a short candidate
/// list. The offset alone is ambiguous — +02:00 in winter is Bucharest,
/// Athens, Helsinki and Cairo — so candidates are ordered by who actually uses
/// this app, and Romania wins ties. Getting it wrong picks a zone with an
/// identical offset *and* identical DST behaviour, which means the notification
/// still fires at the right wall-clock moment.
///
/// The only real failure is a user in a zone with the same current offset but
/// different DST rules, who would see the daily notification shift by an hour
/// for a few weeks a year. That is an acceptable trade for deleting a
/// dependency that cannot compile.
abstract final class LocalTimezone {
  /// Ordered by likelihood for a Romanian Orthodox calendar: home first, then
  /// Moldova, then the main diaspora destinations.
  static const List<String> _candidates = <String>[
    'Europe/Bucharest',
    'Europe/Chisinau',
    'Europe/Rome',
    'Europe/Madrid',
    'Europe/Berlin',
    'Europe/Paris',
    'Europe/Brussels',
    'Europe/Vienna',
    'Europe/London',
    'Europe/Dublin',
    'Europe/Lisbon',
    'Europe/Athens',
    'Europe/Kyiv',
    'Europe/Istanbul',
    'Europe/Moscow',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Toronto',
    'Asia/Jerusalem',
    'Asia/Dubai',
    'Australia/Sydney',
  ];

  static const String fallback = 'Europe/Bucharest';

  /// Best-effort IANA name for the device's current zone.
  ///
  /// Call after `initializeTimeZones()` — it needs the database loaded to read
  /// each candidate's current offset.
  static String resolve({DateTime? now}) {
    final DateTime instant = now ?? DateTime.now();
    final Duration deviceOffset = instant.timeZoneOffset;

    for (final String name in _candidates) {
      final tz.Location location;
      try {
        location = tz.getLocation(name);
      } catch (_) {
        continue; // not in the bundled database
      }
      final tz.TZDateTime there = tz.TZDateTime.from(instant, location);
      if (there.timeZoneOffset == deviceOffset) return name;
    }

    return fallback;
  }

  /// Sets `tz.local`. Returns the name chosen, for logging.
  static String apply({DateTime? now}) {
    final String name = resolve(now: now);
    tz.setLocalLocation(tz.getLocation(name));
    return name;
  }
}
