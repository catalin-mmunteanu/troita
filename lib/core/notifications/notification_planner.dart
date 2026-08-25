import '../data/day_repository.dart';
import '../liturgical/fast_level.dart';
import '../liturgical/fasting_period.dart';
import '../liturgical/liturgical_calendar.dart';
import '../models/feast.dart';
import 'notification_prefs.dart';
import 'notification_service.dart';

/// Decides what gets scheduled, and when.
///
/// Local notifications only — no server, no push. Android keeps a limited
/// number of pending alarms, so we schedule a rolling window rather than a
/// year, and refresh it every time the app opens. For an app people open most
/// mornings that is plenty; the window is long enough that a fortnight away
/// from the phone changes nothing.
class NotificationPlanner {
  const NotificationPlanner(this._days, this._notifications);

  final DayRepository _days;
  final TroitaNotifications _notifications;

  /// Days ahead to schedule. 60 keeps us far under Android's pending-alarm
  /// ceiling while surviving a long gap between openings.
  static const int windowDays = 60;

  Future<PlanResult> reschedule(NotificationPrefs prefs) async {
    await _notifications.cancelAll();

    if (!await _notifications.areEnabled()) {
      return const PlanResult(daily: 0, fasts: 0, blocked: true);
    }

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    int daily = 0;
    if (prefs.mode != DailyNotificationMode.off) {
      daily = await _scheduleDaily(today, prefs);
    }

    int fasts = 0;
    if (prefs.fastReminders) {
      fasts = await _scheduleFastReminders(today);
    }

    return PlanResult(daily: daily, fasts: fasts, blocked: false);
  }

  Future<int> _scheduleDaily(DateTime today, NotificationPrefs prefs) async {
    int count = 0;
    for (int offset = 0; offset < windowDays; offset++) {
      final DateTime date =
          DateTime(today.year, today.month, today.day + offset);
      final DayEntry entry = await _days.entryFor(date);
      final FeastRank rank = entry.rank;

      final bool major =
          rank == FeastRank.praznic || rank == FeastRank.cruceRosie;
      if (prefs.mode == DailyNotificationMode.majorOnly && !major) continue;

      final String title = entry.primary?.displayName ?? 'Pomenirea zilei';
      final String body = _body(entry);

      await _notifications.scheduleDaily(
        date: date,
        rank: rank,
        title: title,
        body: body,
        prefs: prefs,
      );
      count++;
    }
    return count;
  }

  /// The four great fasts only.
  ///
  /// Wednesday and Friday are deliberately excluded. They are fast days too,
  /// but reminding someone 104 times a year about something they already know
  /// is how an app gets its notifications turned off entirely.
  Future<int> _scheduleFastReminders(DateTime today) async {
    final DateTime horizon =
        DateTime(today.year, today.month, today.day + windowDays);

    final List<FastingPeriod> periods = <FastingPeriod>[
      ...LiturgicalCalendar.greatFasts(today.year),
      ...LiturgicalCalendar.greatFasts(today.year + 1),
    ].where((FastingPeriod p) =>
        p.kind.isGreatFast &&
        p.start.isAfter(today) &&
        !p.start.isAfter(horizon)).toList();

    int count = 0;
    for (final FastingPeriod period in periods) {
      final DateTime eve = DateTime(
        period.start.year,
        period.start.month,
        period.start.day - 1,
      );
      await _notifications.scheduleFastReminder(
        eveningBefore: eve,
        fastStart: period.start,
        periodLabel: period.label,
        body: _fastBody(period),
      );
      count++;
    }
    return count;
  }

  static String _body(DayEntry entry) {
    final List<String> parts = <String>[
      if (entry.feasts.isNotEmpty)
        entry.feasts.map((Feast f) => f.name).join('; '),
      if (entry.liturgical.isFasting) entry.liturgical.fastLevel.label,
    ];
    return parts.isEmpty ? 'Pomenirea zilei' : parts.join('\n');
  }

  static String _fastBody(FastingPeriod period) {
    final String range = '${period.start.day}.${period.start.month} – '
        '${period.end.day}.${period.end.month}';
    return <String>[
      range,
      if (period.note != null) period.note!,
    ].join(' · ');
  }
}

class PlanResult {
  const PlanResult({
    required this.daily,
    required this.fasts,
    required this.blocked,
  });

  final int daily;
  final int fasts;

  /// True when the OS permission is missing, so nothing could be scheduled.
  final bool blocked;

  int get total => daily + fasts;
}
