import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/design_tokens.dart';
import '../../app/theme.dart';
import '../../app/troita_icons.dart';
import '../../core/format_ro.dart' as ro;
import '../../core/liturgical/calendar_days.dart';
import '../../core/liturgical/fasting_period.dart';
import '../../core/liturgical/liturgical_calendar.dart';
import '../../core/models/fast_day.dart';
import 'fast_period_page.dart';
import 'kept_days_page.dart';
import 'fast_day_editor.dart';

/// `posturi-fasting` (2:296), now with the journal.
///
/// The fasting rules are entirely computed — this screen needs no data source.
/// What the user adds on top of it lives in a separate database that content
/// updates never touch.
class FastingPage extends StatefulWidget {
  const FastingPage({super.key});

  @override
  State<FastingPage> createState() => _FastingPageState();
}

class _FastingPageState extends State<FastingPage> {
  /// How many years of coming fasts the list goes to.
  static const int _yearsAhead = 4;

  /// Years the user opened or closed by hand. Absent: the default, which is
  /// open for this year and the next, closed after.
  final Map<int, bool> _expanded = <int, bool>{};

  bool _isOpen(int year, int thisYear) =>
      _expanded[year] ?? year <= thisYear + 1;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final List<FastingPeriod> all = <FastingPeriod>[
      ...LiturgicalCalendar.greatFasts(today.year - 1),
      ...LiturgicalCalendar.greatFasts(today.year),
      for (int y = today.year + 1; y <= today.year + _yearsAhead; y++)
        ...LiturgicalCalendar.greatFasts(y),
    ]..sort((FastingPeriod a, FastingPeriod b) => a.start.compareTo(b.start));

    // Not `.firstOrNull` — that is a package:collection extension, not core.
    final List<FastingPeriod> current =
        all.where((FastingPeriod p) => p.contains(today)).toList();
    final FastingPeriod? active = current.isEmpty ? null : current.first;
    final List<FastingPeriod> upcoming = all
        .where((FastingPeriod p) => p.start.isAfter(today))
        .toList();
    // Coming fasts by the year they begin in.
    final Map<int, List<FastingPeriod>> byYear = <int, List<FastingPeriod>>{};
    for (final FastingPeriod p in upcoming) {
      (byYear[p.start.year] ??= <FastingPeriod>[]).add(p);
    }
    final List<FastingPeriod> past = all.reversed
        .where((FastingPeriod p) => p.end.isBefore(today))
        .take(3)
        .toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        // Keyed on the revision so marking a day rebuilds the FutureBuilders
        // below rather than serving their cached snapshots.
        key: ValueKey<int>(state.journalRevision),
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TroitaSpacing.page, TroitaSpacing.page, TroitaSpacing.page, 4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Ghid de Post',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'Marile perioade liturgice de înfrânare și rugăciune.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: TroitaSpacing.gap),

          if (active != null)
            _ActiveFastCard(period: active, today: today)
          else
            _BetweenFastsCard(next: upcoming.isEmpty ? null : upcoming.first,
                today: today),

          const _SectionHeader('Următoarele posturi'),
          for (final MapEntry<int, List<FastingPeriod>> e in byYear.entries)
            ..._yearGroup(e.key, e.value, today),

          if (past.isNotEmpty) ...<Widget>[
            const _SectionHeader('Posturi încheiate'),
            ...past.map((FastingPeriod p) => _PeriodCard(
                period: p, today: today, status: PeriodStatus.finished)),
          ],

          // The tallies go last: the page is first a guide to the fasts,
          // and the journal is something some people keep.
          if (state.journalEnabled) ...<Widget>[
            const _SectionHeader('Zile ținute'),
            if (active != null) _KeptCard(period: active),
            ...past.map((FastingPeriod p) => _KeptCard(period: p)),
            const _AllTimeCard(),
          ],
        ],
      ),
    );
  }

  /// A year's heading, which opens and closes it, and its fasts when open.
  /// The fasts of a year the user had to open show their dates only: a
  /// count of days that far ahead says nothing.
  List<Widget> _yearGroup(int year, List<FastingPeriod> fasts, DateTime today) {
    final bool open = _isOpen(year, today.year);
    final bool byDefault = year <= today.year + 1;
    return <Widget>[
      _YearHeader(
        year: year,
        count: fasts.length,
        open: open,
        onTap: () => setState(() => _expanded[year] = !open),
      ),
      if (open)
        ...fasts.map((FastingPeriod p) => _PeriodCard(
              period: p,
              today: today,
              status: PeriodStatus.upcoming,
              showCountdown: byDefault,
            )),
    ];
  }
}

/// "2027 · 4 posturi" with a chevron; a button for screen readers.
class _YearHeader extends StatelessWidget {
  const _YearHeader({
    required this.year,
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int year;
  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        expanded: open,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: TroitaSpacing.page, vertical: 6),
              child: Row(
                children: <Widget>[
                  Text('$year',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: TroitaColors.burgundy,
                          )),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      count == 1 ? 'un post' : '$count posturi',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more,
                      color: TroitaColors.burgundy),
                ],
              ),
            ),
          ),
        ),
      );
}

/// A fast's tally at the bottom of the page: its name, then the days kept.
class _KeptCard extends StatelessWidget {
  const _KeptCard({required this.period});

  final FastingPeriod period;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(
          TroitaSpacing.page, 0, TroitaSpacing.page, TroitaSpacing.gap,
        ),
        padding: const EdgeInsets.all(TroitaSpacing.card),
        decoration: TroitaTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${period.label} ${period.start.year}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            _PeriodStats(period: period, compact: true),
          ],
        ),
      );

}

/// The card for a fast that is running now: how far in, how much left, today's
/// rating, and the tally so far.
class _ActiveFastCard extends StatelessWidget {
  const _ActiveFastCard({required this.period, required this.today});

  final FastingPeriod period;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final int dayNumber = calendarDaysBetween(period.start, today) + 1;
    final int left = calendarDaysBetween(today, period.end);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: TroitaSpacing.page),
      padding: const EdgeInsets.all(TroitaSpacing.card),
      decoration: TroitaTheme.cardDecoration(
        color: TroitaColors.accentSurface,
        borderColor: TroitaColors.gold,
        radius: TroitaRadius.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(period.label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Ziua $dayNumber din ${period.days} · ${ro.remaining(left)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          _Progress(fraction: dayNumber / period.days),

          if (state.journalEnabled) ...<Widget>[
            const Divider(height: 26),
            FutureBuilder<FastDay?>(
              future: state.journal.forDate(today),
              builder: (BuildContext context, AsyncSnapshot<FastDay?> snap) =>
                  FastDayEditor(
                day: snap.data,
                question: 'Ați ținut postul astăzi?',
                onKept: (bool k) => state.setFastKept(today, k),
              ),
            ),
          ],

          // An explicit row rather than making the whole card tappable: this
          // card already owns the Da/Nu control, and a card-wide tap target
          // wrapped around a rating widget takes taps meant for it.
          const Divider(height: 26),
          InkWell(
            onTap: () => openFastPeriod(context, period),
            borderRadius: TroitaRadius.smallAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Text(
                    'Vezi toate zilele postului',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: TroitaColors.burgundy,
                        ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      size: 18, color: TroitaColors.burgundy),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BetweenFastsCard extends StatelessWidget {
  const _BetweenFastsCard({required this.next, required this.today});

  final FastingPeriod? next;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    if (next == null) return const SizedBox.shrink();
    final int until = calendarDaysBetween(today, next!.start);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: TroitaSpacing.page),
      padding: const EdgeInsets.all(TroitaSpacing.card),
      decoration: TroitaTheme.cardDecoration(radius: TroitaRadius.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Nu suntem într-un post mare',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '${next!.label} începe ${ro.inDays(until)}, '
            'pe ${DateFormat('d MMMM', 'ro').format(next!.start)}.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.period,
    required this.today,
    required this.status,
    this.showCountdown = true,
  });

  final FastingPeriod period;
  final DateTime today;
  final PeriodStatus status;

  /// For a coming fast: the days left to it, in place of a status chip.
  final bool showCountdown;

  @override
  Widget build(BuildContext context) {
    final String range =
        '${DateFormat('d MMM', 'ro').format(period.start)} – '
        '${DateFormat('d MMM yyyy', 'ro').format(period.end)}';

    final bool upcoming = status == PeriodStatus.upcoming;
    final int until = calendarDaysBetween(today, period.start);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        TroitaSpacing.page, 0, TroitaSpacing.page, TroitaSpacing.gap,
      ),
      decoration: TroitaTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openFastPeriod(context, period),
        child: Padding(
      padding: const EdgeInsets.all(TroitaSpacing.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(period.label,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(width: 8),
              if (!upcoming)
                _StatusChip(label: status.label, status: status)
              else if (showCountdown)
                _StatusChip(label: ro.inDays(until), status: status),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: TroitaColors.muted),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const Icon(TroitaIcons.calendar,
                  size: 16, color: TroitaColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(range,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
          if (!upcoming) ...<Widget>[
            const SizedBox(height: 4),
            Text(
                'Încheiat ${DateFormat('MMMM yyyy', 'ro').format(period.end)}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ],
      ),
        ),
      ),
    );
  }
}

/// One route, so every way into a fast lands on the same screen.
void openFastPeriod(BuildContext context, FastingPeriod period) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => FastPeriodPage(period: period)),
  );
}

/// Gentle totals. No streaks — a visibly broken streak is when people stop
/// opening the app, and this is a spiritual practice rather than a game.
class _PeriodStats extends StatelessWidget {
  const _PeriodStats({required this.period, this.compact = false});

  final FastingPeriod period;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return FutureBuilder<FastStats>(
      future: state.journal.statsFor(period),
      builder: (BuildContext context, AsyncSnapshot<FastStats> snap) {
        final FastStats stats = snap.data ?? FastStats.empty;
        if (stats.elapsed == 0 || stats.answered == 0) {
          return Text('Nicio zi însemnată încă.',
              style: Theme.of(context).textTheme.bodySmall);
        }

        final Widget tally = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${ro.days(stats.kept)} ținute din ${stats.elapsed} trecute',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: compact ? 15 : 17),
            ),
            if (stats.notKept > 0)
              Text(
                '${ro.days(stats.notKept)} însemnate ca neținute',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        );
        if (stats.kept == 0) return tally;

        // Tappable only when there is something to list.
        return InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => KeptDaysPage(period: period),
          )),
          borderRadius: TroitaRadius.smallAll,
          child: Row(
            children: <Widget>[
              Expanded(child: tally),
              const Icon(Icons.chevron_right,
                  size: 20, color: TroitaColors.muted),
            ],
          ),
        );
      },
    );
  }
}

class _AllTimeCard extends StatelessWidget {
  const _AllTimeCard();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: TroitaSpacing.page),
      decoration: TroitaTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const KeptDaysPage(),
          )),
          child: Padding(
      padding: const EdgeInsets.all(TroitaSpacing.card),
      child: FutureBuilder<FastStats>(
        future: state.journal.allTime(),
        builder: (BuildContext context, AsyncSnapshot<FastStats> snap) {
          final FastStats stats = snap.data ?? FastStats.empty;
          if (stats.kept == 0) {
            return Text(
              'Aici veți vedea totalul zilelor de post însemnate.',
              style: Theme.of(context).textTheme.bodySmall,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                ro.days(stats.kept),
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 30),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text('de post ținute de când folosiți aplicația',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const Text('Vezi zilele',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: TroitaColors.burgundy,
                      )),
                  const Icon(Icons.chevron_right,
                      size: 18, color: TroitaColors.burgundy),
                ],
              ),
            ],
          );
        },
      ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(TroitaTokenRadius.xs),
        child: LinearProgressIndicator(
          value: fraction.clamp(0.0, 1.0),
          minHeight: 8,
          backgroundColor: TroitaColors.border,
          valueColor:
              const AlwaysStoppedAnimation<Color>(TroitaColors.burgundy),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.status});

  final String label;
  final PeriodStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground, Color? borderColor) =
        switch (status) {
      PeriodStatus.active => (
          TroitaColors.burgundy,
          TroitaColors.onBurgundy,
          null,
        ),
      PeriodStatus.upcoming => (
          TroitaColors.accentSurface,
          TroitaColors.burgundy,
          TroitaColors.gold,
        ),
      PeriodStatus.finished => (
          TroitaColors.surfaceSubtle,
          TroitaColors.muted,
          TroitaColors.border,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(TroitaTokenRadius.xs),
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          TroitaSpacing.page, 26, TroitaSpacing.page, 10,
        ),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge,
        ),
      );
}
