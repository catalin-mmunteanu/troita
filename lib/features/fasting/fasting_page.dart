import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../app/troita_icons.dart';
import '../../core/format_ro.dart' as ro;
import '../../core/liturgical/fast_level.dart';
import '../../core/liturgical/fasting_period.dart';
import '../../core/liturgical/liturgical_calendar.dart';
import '../../core/models/fast_day.dart';
import 'mood_selector.dart';

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
  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final List<FastingPeriod> all = <FastingPeriod>[
      ...LiturgicalCalendar.greatFasts(today.year - 1),
      ...LiturgicalCalendar.greatFasts(today.year),
      ...LiturgicalCalendar.greatFasts(today.year + 1),
    ]..sort((FastingPeriod a, FastingPeriod b) => a.start.compareTo(b.start));

    // Not `.firstOrNull` — that is a package:collection extension, not core.
    final List<FastingPeriod> current =
        all.where((FastingPeriod p) => p.contains(today)).toList();
    final FastingPeriod? active = current.isEmpty ? null : current.first;
    final List<FastingPeriod> upcoming = all
        .where((FastingPeriod p) => p.start.isAfter(today))
        .take(4)
        .toList();
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
          ...upcoming.map((FastingPeriod p) =>
              _PeriodCard(period: p, today: today, status: PeriodStatus.upcoming)),

          if (past.isNotEmpty) ...<Widget>[
            const _SectionHeader('Posturi încheiate'),
            ...past.map((FastingPeriod p) => _PeriodCard(
                period: p, today: today, status: PeriodStatus.finished)),
          ],

          const _SectionHeader('Total'),
          const _AllTimeCard(),
          const _WeeklyRuleCard(),
        ],
      ),
    );
  }
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
    final int dayNumber = today.difference(period.start).inDays + 1;
    final int left = period.end.difference(today).inDays;

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

          const Divider(height: 26),

          FutureBuilder<FastDay?>(
            future: state.journal.forDate(today),
            builder: (BuildContext context, AsyncSnapshot<FastDay?> snap) =>
                FastDayEditor(
              day: snap.data,
              question: 'Ați ținut postul astăzi?',
              onKept: (bool k) => state.setFastKept(today, k),
              onMood: (FastMood m) => state.setFastMood(today, m),
            ),
          ),

          const Divider(height: 26),
          _PeriodStats(period: period),
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
    final int until = next!.start.difference(today).inDays;

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
          const SizedBox(height: 8),
          Text(
            'Miercurea și vinerea rămân zile de post.',
            style: Theme.of(context).textTheme.bodySmall,
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
  });

  final FastingPeriod period;
  final DateTime today;
  final PeriodStatus status;

  @override
  Widget build(BuildContext context) {
    final String range =
        '${DateFormat('d MMM', 'ro').format(period.start)} – '
        '${DateFormat('d MMM yyyy', 'ro').format(period.end)}';

    final String when = status == PeriodStatus.upcoming
        ? 'Începe ${ro.inDays(period.start.difference(today).inDays)}'
        : 'Încheiat ${DateFormat('MMMM yyyy', 'ro').format(period.end)}';

    return Container(
      margin: const EdgeInsets.fromLTRB(
        TroitaSpacing.page, 0, TroitaSpacing.page, TroitaSpacing.gap,
      ),
      padding: const EdgeInsets.all(TroitaSpacing.card),
      decoration: TroitaTheme.cardDecoration(),
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
              _StatusChip(status: status),
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
          const SizedBox(height: 4),
          Text(when,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (status == PeriodStatus.finished) ...<Widget>[
            const Divider(height: 22),
            _PeriodStats(period: period, compact: true),
          ],
        ],
      ),
    );
  }
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

        return Column(
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
            if (stats.byMood.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  for (final FastMood mood in FastMood.values)
                    if ((stats.byMood[mood] ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Row(
                          children: <Widget>[
                            Icon(MoodSelector.iconFor(mood, filled: true),
                                size: 20,
                                color: MoodSelector.colourFor(mood)),
                            const SizedBox(width: 5),
                            Text(
                              '${stats.byMood[mood]}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: MoodSelector.colourFor(mood),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ],
          ],
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
      padding: const EdgeInsets.all(TroitaSpacing.card),
      decoration: TroitaTheme.cardDecoration(),
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
              Text('de post ținute de când folosiți aplicația',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          );
        },
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(100),
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
  const _StatusChip({required this.status});

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
        borderRadius: BorderRadius.circular(100),
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _WeeklyRuleCard extends StatelessWidget {
  const _WeeklyRuleCard();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(
          TroitaSpacing.page, TroitaSpacing.gap, TroitaSpacing.page, 0,
        ),
        padding: const EdgeInsets.all(TroitaSpacing.card),
        decoration: TroitaTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Miercurea și vinerea',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Zile de post de peste an, în afara săptămânilor de harți: '
              'de la Crăciun la Bobotează, după Duminica Vameșului și a '
              'Fariseului, în Săptămâna Luminată și după Rusalii.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
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
