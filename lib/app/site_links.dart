/// The website's addresses for the app's screens: one URL scheme for both.
///
/// troita.ro has a page for every day, fast and year the app shows, so a
/// shared day is a link anyone can open, and a link opens the app when it is
/// installed (Android App Links: the intent filter in AndroidManifest.xml and
/// troita.ro/.well-known/assetlinks.json). Keep these paths in step with the
/// site's routes (troita-web: src/app/).
abstract final class SiteLinks {
  static const String base = 'https://www.troita.ro';
  static const Set<String> hosts = <String>{'www.troita.ro', 'troita.ro'};

  static const List<String> months = <String>[
    'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie', //
    'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
  ];

  static const String privacy = '$base/confidentialitate';
  static const String about = '$base/despre';
  static const String today = '$base/azi';

  /// The day inside its month page: /calendar-ortodox/2026/noiembrie#ziua-21.
  static String day(DateTime d) =>
      '$base/calendar-ortodox/${d.year}/${months[d.month - 1]}#ziua-${d.day}';

  static String month(int year, int month) =>
      '$base/calendar-ortodox/$year/${months[month - 1]}';

  /// The date a troita.ro link points at, or null when it is not a day.
  ///
  /// /azi → today; /calendar-ortodox/2026/noiembrie#ziua-21 → that day;
  /// a month without a day → its first day.
  static DateTime? dateOf(Uri uri, {DateTime? now}) {
    if (!hosts.contains(uri.host)) return null;
    final List<String> parts =
        uri.pathSegments.where((String s) => s.isNotEmpty).toList();
    if (parts.length == 1 && parts.first == 'azi') {
      final DateTime t = now ?? DateTime.now();
      return DateTime(t.year, t.month, t.day);
    }
    if (parts.length != 3 || parts.first != 'calendar-ortodox') return null;
    final int? year = int.tryParse(parts[1]);
    final int month = months.indexOf(parts[2]) + 1;
    if (year == null || month == 0) return null;
    final RegExpMatch? m = RegExp(r'^ziua-(\d{1,2})$').firstMatch(uri.fragment);
    final int day = m == null ? 1 : int.parse(m.group(1)!);
    if (day < 1 || day > DateTime(year, month + 1, 0).day) return null;
    return DateTime(year, month, day);
  }
}
