/// Whole calendar days between two dates, immune to daylight-saving time.
///
/// `b.difference(a).inDays` looks like the obvious way to count days and is
/// wrong in Romania once a year. `DateTime(y, m, d)` is local midnight, and
/// `difference` measures real elapsed time, so any span containing the
/// last-Sunday-of-March change is a whole number of days *minus one hour* —
/// and `inDays` truncates it down a day. Postul Mare always crosses that
/// change, which made it 47 days long on every Romanian phone while tests run
/// on a UTC machine happily saw 48.
///
/// Rebuilding both dates as UTC midnights removes the time zone from the
/// question entirely: there are no DST transitions in UTC, so the difference
/// is always an exact multiple of 24 hours.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;
