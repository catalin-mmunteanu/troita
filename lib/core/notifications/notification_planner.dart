import '../data/church_marks_repository.dart';
import '../data/church_repository.dart';
import '../data/day_repository.dart';
import '../data/lecturi_repository.dart';
import '../data/name_days_repository.dart';
import '../liturgical/fast_level.dart';
import '../liturgical/fasting_period.dart';
import '../liturgical/liturgical_calendar.dart';
import '../models/church.dart';
import '../models/feast.dart';
import '../models/feast_calendar.dart';
import '../models/lecturi.dart';
import '../models/name_days.dart';
import '../models/saved_name.dart';
import 'notification_prefs.dart';
import 'notification_service.dart';

/// Decides what gets scheduled, and when.
///
/// Local notifications only — no server, no push. Android keeps a limited
/// number of pending alarms (500 per app), so we schedule a rolling window
/// rather than a year, and refresh it every time the app opens. With every
/// kind on "Toate" the window holds about 300; the window is long enough
/// that a fortnight away from the phone changes nothing.
///
/// Each kind has a level (Toate · Doar importante · Oprit); what the levels
/// mean for each kind is written in [NotifKind.describe], and the rules here
/// follow those sentences. The pure parts — which days, which names — are
/// static and tested on their own (`test/notification_rules_test.dart`).
class NotificationPlanner {
  const NotificationPlanner(
    this._days,
    this._notifications, {
    ChurchRepository? churches,
    ChurchMarksRepository? marks,
    LecturiRepository? lecturi,
    NameDaysRepository? nameDays,
    List<SavedName> savedNames = const <SavedName>[],
    bool journal = false,
  })  : _churches = churches,
        _marks = marks,
        _lecturi = lecturi,
        _nameDays = nameDays,
        _savedNames = savedNames,
        _journal = journal;

  final DayRepository _days;
  final TroitaNotifications _notifications;
  final ChurchRepository? _churches;
  final ChurchMarksRepository? _marks;
  final LecturiRepository? _lecturi;
  final NameDaysRepository? _nameDays;
  final List<SavedName> _savedNames;

  /// Whether the fast journal is on; the evening question needs it.
  final bool _journal;

  /// Days ahead to schedule. 60 keeps us under Android's pending-alarm
  /// ceiling while surviving a long gap between openings.
  static const int windowDays = 60;

  Future<PlanResult> reschedule(NotificationPrefs prefs) async {
    await _notifications.cancelAll();

    if (!await _notifications.areEnabled()) {
      return const PlanResult(daily: 0, fasts: 0, blocked: true);
    }

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    // Every kind looks at the same sixty days, so read them once. One day
    // more: the evening-before kinds look at tomorrow.
    final List<DayEntry> days = <DayEntry>[];
    for (int offset = 0; offset <= windowDays; offset++) {
      days.add(await _days
          .entryFor(DateTime(today.year, today.month, today.day + offset)));
    }

    // Each kind on its own: one failing (a broken asset, a missing church)
    // must not cost the others.
    Future<int> guarded(
        NotifKind kind, Future<int> Function(NotifLevel) run) async {
      final NotifLevel level = prefs.level(kind);
      if (level == NotifLevel.off) return 0;
      try {
        return await run(level);
      } catch (_) {
        return 0;
      }
    }

    final int daily = await guarded(NotifKind.saint,
            (NotifLevel l) => _scheduleDaily(days, prefs, l)) +
        await guarded(NotifKind.gospel,
            (NotifLevel l) => _scheduleGospel(days, prefs, l)) +
        await guarded(NotifKind.dezlegari,
            (NotifLevel l) => _scheduleDezlegari(days, prefs, l));

    final int other = await guarded(NotifKind.fasts,
            (NotifLevel l) => _scheduleFastReminders(today, days, prefs, l)) +
        await guarded(NotifKind.hram,
            (NotifLevel l) => _scheduleHramReminders(today, prefs, l)) +
        await guarded(NotifKind.nameDays,
            (NotifLevel l) => _scheduleNameDays(today, prefs, l)) +
        await guarded(
            NotifKind.ajun, (NotifLevel l) => _scheduleAjun(days, prefs, l)) +
        await guarded(
            NotifKind.mosi, (NotifLevel l) => _scheduleMosi(days, prefs, l)) +
        await guarded(NotifKind.legale,
            (NotifLevel l) => _scheduleLegale(today, prefs, l)) +
        (_journal
            ? await guarded(NotifKind.jurnal,
                (NotifLevel l) => _scheduleJurnal(days, prefs, l))
            : 0);

    return PlanResult(daily: daily, fasts: other, blocked: false);
  }

  // ------------------------------------------------------------ the morning

  Future<int> _scheduleDaily(
      List<DayEntry> days, NotificationPrefs prefs, NotifLevel level) async {
    int count = 0;
    for (final DayEntry entry in days.take(windowDays)) {
      final FeastRank rank = entry.rank;
      if (level == NotifLevel.important && !_isMajor(rank)) continue;

      // Counted only when something was actually scheduled. Today's slot is
      // skipped once its hour has passed, and counting it anyway made the
      // settings screen report one more notification than was queued.
      final bool queued = await _notifications.scheduleDaily(
        date: entry.date,
        rank: rank,
        title: entry.primary?.displayName ?? 'Pomenirea zilei',
        body: _body(entry),
        prefs: prefs,
      );
      if (queued) count++;
    }
    return count;
  }

  /// Evanghelia zilei: the reference as title, the first verse as text. Days
  /// without Liturgy (Great Lent weekdays, Holy Friday) get nothing.
  Future<int> _scheduleGospel(
      List<DayEntry> days, NotificationPrefs prefs, NotifLevel level) async {
    final LecturiRepository? repo = _lecturi;
    if (repo == null) return 0;
    final Lecturi lecturi = await repo.lecturi();
    final BibliaNT biblia = await repo.biblia();
    int count = 0;
    for (final DayEntry entry in days.take(windowDays)) {
      if (level == NotifLevel.important &&
          !entry.isSunday &&
          !_isMajor(entry.rank)) {
        continue;
      }
      final LecturaZi? day = lecturi.on(entry.date);
      if (day == null || !day.hasGospel) continue;
      final List<Verse> verses = biblia.text(day.evanghelie);
      final String body =
          verses.isEmpty ? day.evanghelieCite! : _firstWords(verses.first.text);
      final bool queued = await _notifications.scheduleGospel(
        date: entry.date,
        title: 'Evanghelia zilei · ${day.evanghelieCite}',
        body: body,
        prefs: prefs,
      );
      if (queued) count++;
    }
    return count;
  }

  /// "Azi: post cu dezlegare la pește", on the days of a fast that have one.
  Future<int> _scheduleDezlegari(
      List<DayEntry> days, NotificationPrefs prefs, NotifLevel level) async {
    int count = 0;
    for (final DayEntry entry in days.take(windowDays)) {
      if (!isDezlegare(entry.liturgical.fastLevel, level)) continue;
      final String? period = entry.liturgical.period?.label;
      final bool queued = await _notifications.scheduleSimple(
        base: TroitaNotifications.dezlegariBase,
        day: entry.date,
        hour: prefs.hour,
        minute: prefs.minute,
        channelId: TroitaNotifications.channelDezlegari,
        channelName: 'Dezlegări în post',
        title: 'Azi: ${entry.liturgical.summary.toLowerCase()}',
        body: <String>[
          if (period != null) period,
          if (entry.primary != null) entry.primary!.displayName,
        ].join(' · '),
        opens: entry.date,
      );
      if (queued) count++;
    }
    return count;
  }

  static bool isDezlegare(FastLevel fast, NotifLevel level) =>
      fast == FastLevel.fish ||
      (level == NotifLevel.all && fast == FastLevel.wineOil);

  /// Ajunul Crăciunului, al Bobotezei and Sâmbăta Mare in the morning; with
  /// "Toate", the evening before each other praznic împărătesc too.
  Future<int> _scheduleAjun(
      List<DayEntry> days, NotificationPrefs prefs, NotifLevel level) async {
    int count = 0;
    for (int i = 0; i < windowDays; i++) {
      final DayEntry entry = days[i];
      final String? ajun = ajunName(entry.date);
      if (ajun != null) {
        final bool queued = await _notifications.scheduleSimple(
          base: TroitaNotifications.ajunBase,
          day: entry.date,
          hour: prefs.hour,
          minute: prefs.minute,
          channelId: TroitaNotifications.channelAjun,
          channelName: 'Ajunuri și praznice',
          title: 'Azi: $ajun',
          body: entry.liturgical.summary,
          opens: entry.date,
        );
        if (queued) count++;
        continue;
      }
      if (level != NotifLevel.all) continue;
      final DayEntry tomorrow = days[i + 1];
      if (tomorrow.rank != FeastRank.praznic) continue;
      final bool queued = await _notifications.scheduleSimple(
        base: TroitaNotifications.ajunBase,
        day: entry.date,
        hour: prefs.eveningHour,
        minute: prefs.eveningMinute,
        channelId: TroitaNotifications.channelAjun,
        channelName: 'Ajunuri și praznice',
        title:
            'Mâine: ${tomorrow.primary?.displayName ?? 'praznic împărătesc'}',
        body: tomorrow.liturgical.summary,
        opens: tomorrow.date,
      );
      if (queued) count++;
    }
    return count;
  }

  /// The three ajunuri, by date. Null on every other day. Their feasts
  /// (Crăciun, Boboteaza, Paștele) get no evening notice of their own: the
  /// ajun already is one.
  static String? ajunName(DateTime d) {
    if (d.month == 12 && d.day == 24) return 'Ajunul Crăciunului';
    if (d.month == 1 && d.day == 5) return 'Ajunul Bobotezei';
    if (_fromPascha(d) == -1) return 'Sâmbăta Mare';
    return null;
  }

  // ------------------------------------------------------------ the evening

  /// The evening before each great fast; with "Toate", before the one-day
  /// fasts too (5 ianuarie, 29 august, 14 septembrie).
  ///
  /// Wednesday and Friday are deliberately excluded. They are fast days too,
  /// but reminding someone 104 times a year about something they already know
  /// is how an app gets its notifications turned off entirely.
  Future<int> _scheduleFastReminders(DateTime today, List<DayEntry> days,
      NotificationPrefs prefs, NotifLevel level) async {
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
      final bool queued = await _notifications.scheduleFastReminder(
        eveningBefore: _dayBefore(period.start),
        fastStart: period.start,
        periodLabel: period.label,
        body: _fastBody(period),
        prefs: prefs,
      );
      if (queued) count++;
    }

    if (level == NotifLevel.all) {
      for (final DayEntry entry in days.skip(1)) {
        final String? name = oneDayFast(entry.date);
        if (name == null) continue;
        final bool queued = await _notifications.scheduleFastReminder(
          eveningBefore: _dayBefore(entry.date),
          fastStart: entry.date,
          periodLabel: name,
          title: 'Mâine: zi de post',
          body: '$name · ${entry.liturgical.summary}',
          prefs: prefs,
        );
        if (queued) count++;
      }
    }
    return count;
  }

  /// The fixed one-day fasts, by date.
  static String? oneDayFast(DateTime d) => switch ((d.month, d.day)) {
        (1, 5) => 'Ajunul Bobotezei',
        (8, 29) => 'Tăierea Capului Sfântului Ioan Botezătorul',
        (9, 14) => 'Înălțarea Sfintei Cruci',
        _ => null,
      };

  /// Favourite churches only: a reminder for every church in Romania would be
  /// thirteen thousand of them. Churches without a known hram, or whose hram
  /// is a moveable feast the calendar cannot place, are skipped quietly.
  Future<int> _scheduleHramReminders(
      DateTime today, NotificationPrefs prefs, NotifLevel level) async {
    final ChurchRepository? churches = _churches;
    final ChurchMarksRepository? marks = _marks;
    if (churches == null || marks == null) return 0;

    final DateTime horizon =
        DateTime(today.year, today.month, today.day + windowDays);
    int count = 0;
    for (final String id in await marks.favouriteIds()) {
      final Church? c = await churches.byId(id);
      if (c == null) continue;
      final DateTime? feast = FeastCalendar.next(c.feastDay, from: today);
      if (feast == null || feast.isAfter(horizon)) continue;
      for (final bool onTheDay in <bool>[
        false,
        if (level == NotifLevel.all) true,
      ]) {
        final bool queued = await _notifications.scheduleHramReminder(
          churchId: c.id,
          churchName: c.name,
          patron: c.patron,
          feastDay: feast,
          prefs: prefs,
          onTheDay: onTheDay,
        );
        if (queued) count++;
      }
    }
    return count;
  }

  /// The saved names: the morning of the name day, and with "Toate" the
  /// evening before. Names that share a day share one notification.
  Future<int> _scheduleNameDays(
      DateTime today, NotificationPrefs prefs, NotifLevel level) async {
    final NameDaysRepository? repo = _nameDays;
    if (repo == null || _savedNames.isEmpty) return 0;
    final Map<DateTime, List<NameDayHit>> byDay =
        nameDaysAhead(await repo.load(), _savedNames, today, windowDays);

    int count = 0;
    for (final MapEntry<DateTime, List<NameDayHit>> e in byDay.entries) {
      final String who =
          joinRo(e.value.map((NameDayHit h) => h.saved.display).toList());
      final String saints = <String>{
        for (final NameDayHit h in e.value) h.feast.saint,
      }.join('; ');
      if (await _notifications.scheduleSimple(
        base: TroitaNotifications.nameDayBase,
        day: e.key,
        hour: prefs.hour,
        minute: prefs.minute,
        channelId: TroitaNotifications.channelNames,
        channelName: 'Zile de nume',
        title: 'Azi e ziua de nume: $who',
        body: '$saints. La mulți ani!',
        opens: e.key,
      )) {
        count++;
      }
      if (level != NotifLevel.all) continue;
      if (await _notifications.scheduleSimple(
        base: TroitaNotifications.nameEveBase,
        day: _dayBefore(e.key),
        hour: prefs.eveningHour,
        minute: prefs.eveningMinute,
        channelId: TroitaNotifications.channelNames,
        channelName: 'Zile de nume',
        title: 'Mâine e ziua de nume: $who',
        body: saints,
        opens: e.key,
      )) {
        count++;
      }
    }
    return count;
  }

  /// Each saved name's next name day within [window] days of [today], on
  /// its primary feast, grouped by day.
  static Map<DateTime, List<NameDayHit>> nameDaysAhead(NameDays nameDays,
      List<SavedName> saved, DateTime today, int window) {
    final DateTime horizon =
        DateTime(today.year, today.month, today.day + window);
    final Map<DateTime, List<NameDayHit>> out = <DateTime, List<NameDayHit>>{};
    for (final SavedName s in saved) {
      final List<NameFeast> feasts = nameDays.feastsFor(s.name);
      if (feasts.isEmpty) continue;
      final NameFeast primary = feasts.first;
      for (final int year in <int>[today.year, today.year + 1]) {
        final DateTime? d = primary.dateIn(year);
        if (d == null || d.isBefore(today)) continue;
        if (!d.isAfter(horizon)) {
          (out[d] ??= <NameDayHit>[]).add(NameDayHit(s, primary));
        }
        break;
      }
    }
    return out;
  }

  /// Moșii, from the published calendar's notes; with "Toate", every day of
  /// pomenirea morților. The evening before.
  Future<int> _scheduleMosi(
      List<DayEntry> days, NotificationPrefs prefs, NotifLevel level) async {
    int count = 0;
    for (int i = 0; i + 1 < days.length; i++) {
      final DayEntry tomorrow = days[i + 1];
      final String? name = pomenire(
        tomorrow.date,
        notes: tomorrow.override?.notes,
        computed: tomorrow.computed,
        level: level,
      );
      if (name == null) continue;
      final bool queued = await _notifications.scheduleSimple(
        base: TroitaNotifications.mosiBase,
        day: days[i].date,
        hour: prefs.eveningHour,
        minute: prefs.eveningMinute,
        channelId: TroitaNotifications.channelMosi,
        channelName: 'Moșii și pomenirea morților',
        title: 'Mâine: $name',
        body: 'Pomenirea morților.',
        opens: tomorrow.date,
      );
      if (queued) count++;
    }
    return count;
  }

  static final RegExp _mosi = RegExp(r'Mo[șş]ii de [a-zăâîșşțţ]+');
  static final RegExp _pomenire = RegExp(r'[Pp]omenirea mor[țţ]ilor');

  /// "Moșii de iarnă", "Sâmbăta a II-a din Post", or null.
  ///
  /// Published years carry it in the day's [notes]. Years [computed] from
  /// Pascha have no notes, so the Paschal ones come from their offsets:
  /// Moșii de iarnă (−57) and de vară (+48), the Saturdays of Great Lent and
  /// of Lazarus. Moșii de toamnă and de primăvară have no rule that fits the
  /// published years (toamnă: 7 November 2026, 30 October 2027; primăvară:
  /// 9 March 2027 only), so computed years leave them out rather than guess.
  static String? pomenire(
    DateTime date, {
    required String? notes,
    required bool computed,
    required NotifLevel level,
  }) {
    final String text = notes ?? '';
    final Match? mosi = _mosi.firstMatch(text);
    if (mosi != null) return mosi.group(0)!.replaceAll('ş', 'ș');
    if (text.isNotEmpty) {
      if (level != NotifLevel.all) return null;
      // Notes are joined with "; ": "Post; Sâmbăta a II-a din Post -
      // Pomenirea morților; Nu se fac nunți".
      for (final String note in text.split(';')) {
        if (!_pomenire.hasMatch(note)) continue;
        final String head = note.split(RegExp(r'\s+-\s+')).first.trim();
        return _pomenire.hasMatch(head) ? 'pomenirea morților' : head;
      }
      return null;
    }
    if (!computed) return null;
    return switch (_fromPascha(date)) {
      -57 => 'Moșii de iarnă',
      48 => 'Moșii de vară',
      -43 || -36 || -29 || -22 || -15 || -8 when level == NotifLevel.all =>
        'pomenirea morților',
      _ => null,
    };
  }

  /// The evening before each legal holiday; with "Doar importante", only
  /// those on a working day.
  Future<int> _scheduleLegale(
      DateTime today, NotificationPrefs prefs, NotifLevel level) async {
    final DateTime horizon =
        DateTime(today.year, today.month, today.day + windowDays);
    final Map<DateTime, List<String>> holidays = <DateTime, List<String>>{
      ...legalHolidays(today.year),
      ...legalHolidays(today.year + 1),
    };
    int count = 0;
    for (final MapEntry<DateTime, List<String>> h in holidays.entries) {
      if (!h.key.isAfter(today) || h.key.isAfter(horizon)) continue;
      final bool workday = h.key.weekday <= DateTime.friday;
      if (level == NotifLevel.important && !workday) continue;
      final bool queued = await _notifications.scheduleSimple(
        base: TroitaNotifications.legaleBase,
        day: _dayBefore(h.key),
        hour: prefs.eveningHour,
        minute: prefs.eveningMinute,
        channelId: TroitaNotifications.channelLegale,
        channelName: 'Sărbători legale',
        title: workday
            ? 'Mâine e zi liberă: ${h.value.join(', ')}'
            : 'Mâine: ${h.value.join(', ')}',
        body: workday
            ? 'Sărbătoare legală.'
            : 'Sărbătoare legală, într-o zi de weekend.',
        opens: h.key,
      );
      if (queued) count++;
    }
    return count;
  }

  /// Codul muncii, art. 139: the 17 legal holidays of [year], with Orthodox
  /// Pascha and Rusalii. Two can share a day (1 June and the second day of
  /// Rusalii in 2026), so each day lists its names.
  static Map<DateTime, List<String>> legalHolidays(int year) {
    final DateTime p = FeastCalendar.pascha(year);
    DateTime fromPascha(int d) => DateTime(p.year, p.month, p.day + d);
    final List<(DateTime, String)> all = <(DateTime, String)>[
      (DateTime(year, 1, 1), 'Anul Nou'),
      (DateTime(year, 1, 2), 'a doua zi de Anul Nou'),
      (DateTime(year, 1, 6), 'Boboteaza'),
      (DateTime(year, 1, 7), 'Sfântul Ioan Botezătorul'),
      (DateTime(year, 1, 24), 'Ziua Unirii Principatelor Române'),
      (fromPascha(-2), 'Vinerea Mare'),
      (fromPascha(0), 'Paștele'),
      (fromPascha(1), 'a doua zi de Paști'),
      (DateTime(year, 5, 1), 'Ziua Muncii'),
      (DateTime(year, 6, 1), 'Ziua Copilului'),
      (fromPascha(49), 'Rusaliile'),
      (fromPascha(50), 'a doua zi de Rusalii'),
      (DateTime(year, 8, 15), 'Adormirea Maicii Domnului'),
      (DateTime(year, 11, 30), 'Sfântul Apostol Andrei'),
      (DateTime(year, 12, 1), 'Ziua Națională a României'),
      (DateTime(year, 12, 25), 'Crăciunul'),
      (DateTime(year, 12, 26), 'a doua zi de Crăciun'),
    ];
    final Map<DateTime, List<String>> out = <DateTime, List<String>>{};
    for (final (DateTime d, String name) in all) {
      (out[d] ??= <String>[]).add(name);
    }
    for (final List<String> names in out.values) {
      names[0] = _capital(names[0]);
    }
    return out;
  }

  /// "Ați ținut postul azi?", in the evening of a fast day. Only for those
  /// who keep the journal; the tap opens the day, where the answer goes.
  Future<int> _scheduleJurnal(
      List<DayEntry> days, NotificationPrefs prefs, NotifLevel level) async {
    int count = 0;
    for (final DayEntry entry in days.take(windowDays)) {
      if (!entry.liturgical.isFasting) continue;
      final bool great = entry.liturgical.period?.kind.isGreatFast ?? false;
      if (level == NotifLevel.important && !great) continue;
      final bool queued = await _notifications.scheduleSimple(
        base: TroitaNotifications.jurnalBase,
        day: entry.date,
        hour: prefs.eveningHour,
        minute: prefs.eveningMinute,
        channelId: TroitaNotifications.channelJurnal,
        channelName: 'Jurnal de post',
        title: 'Ați ținut postul azi?',
        body: 'Însemnați ziua în jurnalul de post.',
        opens: entry.date,
      );
      if (queued) count++;
    }
    return count;
  }

  // ------------------------------------------------------------------ utils

  static bool _isMajor(FeastRank rank) =>
      rank == FeastRank.praznic || rank == FeastRank.cruceRosie;

  static DateTime _dayBefore(DateTime d) =>
      DateTime(d.year, d.month, d.day - 1);

  /// Days from that year's Pascha, in UTC: a local difference across the
  /// spring clock change is 23 hours short and would round a day off.
  static int _fromPascha(DateTime d) {
    final DateTime p = FeastCalendar.pascha(d.year);
    return DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(p.year, p.month, p.day))
        .inDays;
  }

  static String _capital(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// "Ana", "Ana și Ion", "Ana, Ion și Maria".
  static String joinRo(List<String> items) {
    if (items.length <= 1) return items.join();
    return '${items.sublist(0, items.length - 1).join(', ')} și ${items.last}';
  }

  /// The opening of the pericope, cut at a word, for the notification line.
  static String _firstWords(String text, {int max = 160}) {
    if (text.length <= max) return text;
    final int cut = text.lastIndexOf(' ', max);
    return '${text.substring(0, cut > 0 ? cut : max)}…';
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

/// One saved name on its name day.
class NameDayHit {
  const NameDayHit(this.saved, this.feast);

  final SavedName saved;
  final NameFeast feast;
}

class PlanResult {
  const PlanResult({
    required this.daily,
    required this.fasts,
    required this.blocked,
  });

  /// Morning notifications: saint, gospel, dezlegări.
  final int daily;

  /// Everything else: fasts, hram, names, ajun, Moși, legale, journal.
  final int fasts;

  /// True when the OS permission is missing, so nothing could be scheduled.
  final bool blocked;

  int get total => daily + fasts;
}
