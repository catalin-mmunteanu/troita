import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/data/day_repository.dart';
import '../../core/format_ro.dart';
import '../../core/liturgical/calendar_days.dart';
import '../../core/liturgical/fast_level.dart';
import '../../core/liturgical/fasting_period.dart';
import '../../core/liturgical/liturgical_calendar.dart';
import '../../core/models/fast_day.dart';
import '../calendar/day_detail_page.dart';

/// One fast, end to end: its exact dates, every day in it, and which of those
/// days are dezlegări.
///
/// The days are read through [DayRepository.forRange] rather than computed from
/// the engine. The engine is exact on the boundaries and on the weekly rule,
/// but dezlegările inside a great fast follow the day's commemoration rather
/// than its weekday — it was about 60% right on Postul Apostolilor — so the
/// published calendar wins, which is what entryFor already arranges.
class FastPeriodPage extends StatefulWidget {
  const FastPeriodPage({required this.period, super.key});

  final FastingPeriod period;

  @override
  State<FastPeriodPage> createState() => _FastPeriodPageState();
}

class _FastPeriodPageState extends State<FastPeriodPage> {
  List<DayEntry>? _days;
  Map<String, FastDay> _marked = const <String, FastDay>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final AppState state = AppScope.of(context);
    final List<DayEntry> days = await state.days.forRange(
      widget.period.start,
      widget.period.end,
    );
    final Map<String, FastDay> marked = await state.journal.inRange(
      widget.period.start,
      widget.period.end,
    );
    if (!mounted) return;
    setState(() {
      _days = days;
      _marked = marked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final FastingPeriod p = widget.period;
    final List<DayEntry>? days = _days;

    return Scaffold(
      backgroundColor: TroitaColors.paper,
      appBar: AppBar(
        backgroundColor: TroitaColors.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: TroitaColors.ink,
        title: Text(
          p.label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: days == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                TroitaSpacing.page,
                0,
                TroitaSpacing.page,
                TroitaSpacing.page,
              ),
              children: <Widget>[
                _Summary(period: p, days: days),
                const SizedBox(height: TroitaSpacing.gap),
                _PeriodGrid(
                  days: days,
                  marked: _marked,
                  onTapDay: (DateTime d) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DayDetailPage(date: d),
                    ),
                  ),
                ),
                const SizedBox(height: TroitaSpacing.gap),
                _Legend(days: days),
                const SizedBox(height: TroitaSpacing.page),
                _Dezlegari(
                  days: days,
                  onTapDay: (DateTime d) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DayDetailPage(date: d),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ------------------------------------------------------------------- summary

class _Summary extends StatelessWidget {
  const _Summary({required this.period, required this.days});

  final FastingPeriod period;
  final List<DayEntry> days;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final PeriodStatus status = period.statusOn(today);

    final int fasting = days
        .where((DayEntry d) => _isStrictish(d.liturgical.fastLevel))
        .length;
    final int relief = days.length - fasting;

    final DateFormat long = DateFormat('d MMMM y', 'ro');

    return Container(
      padding: const EdgeInsets.all(TroitaSpacing.card),
      decoration: BoxDecoration(
        color: TroitaColors.surfaceSubtle,
        borderRadius: TroitaRadius.mediumAll,
        border: Border.all(color: TroitaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${long.format(period.start)} — ${long.format(period.end)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: TroitaColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            <String>[
              status.label,
              plural(days.length, 'zi', 'zile'),
            ].join(' · '),
            style: const TextStyle(fontSize: 13, color: TroitaColors.muted),
          ),
          if (status == PeriodStatus.active) ...<Widget>[
            const SizedBox(height: TroitaSpacing.gap),
            _DayCounter(period: period, today: today, total: days.length),
          ],
          const SizedBox(height: TroitaSpacing.gap),
          Row(
            children: <Widget>[
              Expanded(
                child: _Stat(
                  value: '$fasting',
                  label: fasting == 1 ? 'zi de post' : 'zile de post',
                  colour: TroitaColors.burgundy,
                ),
              ),
              Expanded(
                child: _Stat(
                  value: '$relief',
                  label: relief == 1 ? 'zi cu dezlegare' : 'zile cu dezlegare',
                  colour: TroitaColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A day counts as fasting when nothing is loosened on it.
bool _isStrictish(FastLevel level) =>
    level == FastLevel.fast || level == FastLevel.strict;

class _DayCounter extends StatelessWidget {
  const _DayCounter({
    required this.period,
    required this.today,
    required this.total,
  });

  final FastingPeriod period;
  final DateTime today;

  /// The number of day rows on this page, passed in rather than recomputed so
  /// the counter and the summary above it cannot disagree. They did: one
  /// counted rows (48), the other measured elapsed time across the March clock
  /// change (47).
  final int total;

  @override
  Widget build(BuildContext context) {
    final int elapsed = calendarDaysBetween(period.start, today) + 1;
    final double progress = (elapsed / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Ziua $elapsed din $total',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: TroitaColors.burgundy,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: TroitaColors.border,
            valueColor:
                const AlwaysStoppedAnimation<Color>(TroitaColors.burgundy),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.colour,
  });

  final String value;
  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: colour,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 12, color: TroitaColors.muted)),
      ],
    );
  }
}

// ---------------------------------------------------------------------- grid

/// The whole fast as one picture.
///
/// This is what answers "exact ce perioadă": a list of forty-eight rows tells
/// you the same facts and never lets you see the shape of them — where the
/// dezlegări fall, how long the unbroken stretches are, which week is hardest.
class _PeriodGrid extends StatelessWidget {
  const _PeriodGrid({
    required this.days,
    required this.marked,
    required this.onTapDay,
  });

  final List<DayEntry> days;
  final Map<String, FastDay> marked;
  final ValueChanged<DateTime> onTapDay;

  static const List<String> _weekdays = <String>[
    'Lu', 'Ma', 'Mi', 'Jo', 'Vi', 'Sâ', 'Du',
  ];

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    // A fast starts on whatever weekday it starts on, so the first row is
    // padded to put every day under its own column. Without this the columns
    // are meaningless and Sunday stops being findable at a glance.
    final int leading = days.first.date.weekday - 1;
    final int cells = (((leading + days.length) / 7).ceil()) * 7;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final String w in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TroitaCalendarText.weekday.copyWith(
                      color: w == _weekdays.last
                          ? TroitaColors.feastRed
                          : TroitaColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            // Pinned rather than square: on a tablet a square cell would be as
            // tall as it is wide and a seven-week fast would run off the page.
            mainAxisExtent: 46,
          ),
          itemCount: cells,
          itemBuilder: (BuildContext context, int i) {
            final int index = i - leading;
            if (index < 0 || index >= days.length) {
              return const SizedBox.shrink();
            }
            final DayEntry entry = days[index];
            return _DayCell(
              entry: entry,
              isToday: entry.date == today,
              recorded: marked.containsKey(FastDay.key(entry.date)),
              onTap: () => onTapDay(entry.date),
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.entry,
    required this.isToday,
    required this.recorded,
    required this.onTap,
  });

  final DayEntry entry;
  final bool isToday;
  final bool recorded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FastLevel level = entry.liturgical.fastLevel;
    final Color fill = fastLevelColor(level);
    // Fasting days are solid and dezlegări are pale, so relief reads as relief
    // at a glance and the colour then says which kind it is.
    final bool solid = _isStrictish(level);

    return Material(
      color: solid ? fill : fill.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: TroitaRadius.smallAll,
        side: isToday
            ? const BorderSide(color: TroitaColors.ink, width: 2)
            : BorderSide(color: fill.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: TroitaRadius.smallAll,
        child: Stack(
          children: <Widget>[
            Center(
              child: Text(
                '${entry.date.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  color: solid ? TroitaColors.onBurgundy : TroitaColors.ink,
                ),
              ),
            ),
            if (recorded)
              Positioned(
                right: 3,
                top: 3,
                child: Icon(
                  Icons.check,
                  size: 10,
                  color: solid
                      ? TroitaColors.onBurgundy
                      : TroitaColors.burgundy,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Only the levels this fast actually contains. A legend listing all six would
/// have the reader looking for an ajunare that is not there.
class _Legend extends StatelessWidget {
  const _Legend({required this.days});

  final List<DayEntry> days;

  @override
  Widget build(BuildContext context) {
    final Map<FastLevel, int> counts = <FastLevel, int>{};
    for (final DayEntry d in days) {
      final FastLevel l = d.liturgical.fastLevel;
      counts[l] = (counts[l] ?? 0) + 1;
    }
    final List<FastLevel> present = FastLevel.values
        .where((FastLevel l) => counts.containsKey(l))
        .toList(growable: false);

    return Wrap(
      spacing: TroitaSpacing.gap,
      runSpacing: 6,
      children: <Widget>[
        for (final FastLevel l in present)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _isStrictish(l)
                      ? fastLevelColor(l)
                      : fastLevelColor(l).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: fastLevelColor(l).withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${l.shortLabel} · ${counts[l]}',
                style: const TextStyle(
                    fontSize: 12, color: TroitaColors.muted),
              ),
            ],
          ),
      ],
    );
  }
}

// ----------------------------------------------------------- the dezlegări

/// Every day the fast is loosened, and what loosens it.
///
/// The grid shows where they fall; this says why. Inside a great fast a
/// dezlegare almost always belongs to a commemoration, and naming the saint is
/// the difference between a rule to memorise and one that makes sense.
class _Dezlegari extends StatelessWidget {
  const _Dezlegari({required this.days, required this.onTapDay});

  final List<DayEntry> days;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final List<DayEntry> relief = days
        .where((DayEntry d) => !_isStrictish(d.liturgical.fastLevel))
        .toList(growable: false);

    if (relief.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(TroitaSpacing.card),
        decoration: BoxDecoration(
          color: TroitaColors.surfaceSubtle,
          borderRadius: TroitaRadius.mediumAll,
          border: Border.all(color: TroitaColors.border),
        ),
        child: const Text(
          'Nicio zi de dezlegare în acest post.',
          style: TextStyle(fontSize: 13, color: TroitaColors.muted),
        ),
      );
    }

    final DateFormat short = DateFormat('EEEE, d MMMM', 'ro');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'ZILE DE DEZLEGARE',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: TroitaSpacing.listGap),
        Container(
          decoration: BoxDecoration(
            color: TroitaColors.paper,
            borderRadius: TroitaRadius.mediumAll,
            border: Border.all(color: TroitaColors.border),
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < relief.length; i++) ...<Widget>[
                if (i > 0)
                  const Divider(height: 1, color: TroitaColors.border),
                _ReliefRow(
                  entry: relief[i],
                  formatter: short,
                  onTap: () => onTapDay(relief[i].date),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReliefRow extends StatelessWidget {
  const _ReliefRow({
    required this.entry,
    required this.formatter,
    required this.onTap,
  });

  final DayEntry entry;
  final DateFormat formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FastLevel level = entry.liturgical.fastLevel;
    final _Reason reason = _Reason.of(entry);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TroitaSpacing.card,
          vertical: 11,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: fastLevelColor(level),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    toBeginningOfSentenceCase(
                          formatter.format(entry.date),
                        ) ??
                        '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TroitaColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    level.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: fastLevelColor(level),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: TroitaColors.muted,
                      // A saint reads as a name; a rule reads as a gloss.
                      fontStyle:
                          reason.fromFeast ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: TroitaColors.muted),
          ],
        ),
      ),
    );
  }
}


/// Why a day is loosened: the saint commemorated, or simply the weekday.
///
/// The first version named the day's first saint for every dezlegare. In
/// Postul Mare that was wrong for 14 of the 17: Saturday and Sunday get oil and
/// wine by the rule of the fast, whoever is commemorated, and crediting the
/// saint teaches the reader a rule that does not exist.
///
/// So the day is compared with what the rule alone gives — the engine with no
/// rank and no feast dezlegare. If the published level is looser than that, a
/// commemoration did it and is named. Otherwise the rule did, and it is said
/// as a rule: the engine's own note where it has one (Buna Vestire, Florii,
/// Joia Mare), the weekday where it does not.
class _Reason {
  const _Reason(this.text, {required this.fromFeast});

  final String text;
  final bool fromFeast;

  static _Reason of(DayEntry entry) {
    final FastLevel actual = entry.liturgical.fastLevel;
    final LiturgicalDay rule = LiturgicalCalendar.dayFor(entry.date);

    // Lower index is looser: FastLevel is ordered from none to strict.
    final bool feastLoosened = actual.index < rule.fastLevel.index;
    if (feastLoosened && entry.feasts.isNotEmpty) {
      return _Reason(entry.feasts.first.name, fromFeast: true);
    }
    if (rule.note != null) return _Reason(rule.note!, fromFeast: false);

    final String weekday = DateFormat('EEEE', 'ro').format(entry.date);
    return _Reason('Rânduiala postului pentru $weekday', fromFeast: false);
  }
}
