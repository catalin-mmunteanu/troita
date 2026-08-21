/// Resolves `feast_day` values to a real date.
///
/// Fixed feasts are stored as `MM-DD`. Everything tied to Pascha is stored as
/// `movable:<key>` and computed here, because a hardcoded date would be wrong
/// every year — and for a lot of Romanian churches (Sfânta Treime, Izvorul
/// Tămăduirii, Înălțarea Domnului) the hram *is* movable.
class FeastCalendar {
  const FeastCalendar._();

  /// Offsets in days from Pascha.
  static const Map<String, int> _movable = {
    'lazarus_saturday': -8,
    'palm_sunday': -7,
    'theodore_saturday': -43, // Saturday of the first week of Great Lent
    'pascha': 0,
    'bright_friday': 5, // Izvorul Tămăduirii
    'ascension': 39,
    'pentecost': 49,
    'pentecost_monday': 50, // Sfânta Treime
    'all_saints': 56,
    // Added for the feasts table: these carry commemorations of their own.
    'orthodoxy_sunday': -42, // Duminica Ortodoxiei
    'thomas_sunday': 7, // Duminica Tomii
    'myrrhbearers': 14, // Duminica Mironosițelor
    'romanian_saints': 63, // Duminica Sfinților Români
  };

  /// Orthodox Pascha in the Gregorian calendar.
  ///
  /// Meeus's Julian algorithm gives the Julian-calendar date; the Julian
  /// calendar currently runs 13 days behind the Gregorian one, and will until
  /// 2100 — hence the constant rather than a general conversion.
  static DateTime pascha(int year) {
    final a = year % 4;
    final b = year % 7;
    final c = year % 19;
    final d = (19 * c + 15) % 30;
    final e = (2 * a + 4 * b - d + 34) % 7;
    final month = (d + e + 114) ~/ 31;
    final day = ((d + e + 114) % 31) + 1;
    final julianOffset = year < 2100 ? 13 : 14;
    // Day arithmetic inside the constructor rather than Duration: adding a
    // Duration crosses DST boundaries and can land an hour into the day before.
    return DateTime(year, month, day + julianOffset);
  }

  /// The feast's date in [year], or null if the value can't be parsed.
  static DateTime? resolve(String? feastDay, {int? year}) {
    if (feastDay == null || feastDay.isEmpty) return null;
    final y = year ?? DateTime.now().year;

    if (feastDay.startsWith('movable:')) {
      final offset = _movable[feastDay.substring(8)];
      if (offset == null) return null;
      final p = pascha(y);
      return DateTime(p.year, p.month, p.day + offset);
    }

    final parts = feastDay.split('-');
    if (parts.length != 2) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    if (month == null || day == null) return null;
    return DateTime(y, month, day);
  }

  /// The next occurrence, rolling into next year if this year's has passed.
  static DateTime? next(String? feastDay, {DateTime? from}) {
    final now = from ?? DateTime.now();
    final thisYear = resolve(feastDay, year: now.year);
    if (thisYear == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    if (!thisYear.isBefore(today)) return thisYear;
    return resolve(feastDay, year: now.year + 1);
  }

  static int? daysUntil(String? feastDay, {DateTime? from}) {
    final date = next(feastDay, from: from);
    if (date == null) return null;
    final now = from ?? DateTime.now();
    return date.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  static bool isToday(String? feastDay, {DateTime? from}) =>
      daysUntil(feastDay, from: from) == 0;
}
