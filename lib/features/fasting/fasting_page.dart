import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../app/troita_icons.dart';
import '../../core/liturgical/fast_level.dart';
import '../../core/liturgical/fasting_period.dart';
import '../../core/liturgical/liturgical_calendar.dart';

/// `posturi-fasting` (2:296).
///
/// Entirely computed — this screen needs no data source at all, which is why it
/// was the first one worth building.
class FastingPage extends StatelessWidget {
  const FastingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    // Show this year's fasts, then next year's, so December doesn't dead-end.
    final List<FastingPeriod> periods = <FastingPeriod>[
      ...LiturgicalCalendar.greatFasts(today.year),
      ...LiturgicalCalendar.greatFasts(today.year + 1),
    ].where((FastingPeriod p) => !p.end.isBefore(today)).take(5).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TroitaSpacing.page, TroitaSpacing.page, TroitaSpacing.page, 6,
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
          ...periods.map((FastingPeriod p) =>
              _PeriodCard(period: p, today: today)),
          const _WeeklyRuleCard(),
        ],
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.period, required this.today});

  final FastingPeriod period;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final PeriodStatus status = period.statusOn(today);
    final bool active = status == PeriodStatus.active;

    final String range = period.start.year == period.end.year
        ? '${DateFormat('d MMMM', 'ro').format(period.start)} – '
            '${DateFormat('d MMMM yyyy', 'ro').format(period.end)}'
        : '${DateFormat('d MMM yyyy', 'ro').format(period.start)} – '
            '${DateFormat('d MMM yyyy', 'ro').format(period.end)}';

    return Container(
      margin: const EdgeInsets.fromLTRB(
        TroitaSpacing.page, 0, TroitaSpacing.page, TroitaSpacing.gap,
      ),
      padding: const EdgeInsets.all(TroitaSpacing.card),
      decoration: TroitaTheme.cardDecoration(
        color: active ? TroitaColors.accentSurface : null,
        borderColor: active ? TroitaColors.gold : null,
      ),
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
          const SizedBox(height: TroitaSpacing.gap),
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
          if (active) ...<Widget>[
            const SizedBox(height: 6),
            _Progress(period: period, today: today),
          ],
          const Divider(height: 24),
          Text('REGULI GENERALE',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            period.note ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          _DezlegariPreview(period: period),
        ],
      ),
    );
  }
}

/// `Frame` (2:311) — the În curând / Următor / Finalizat pill.
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

/// The week ahead inside an active fast — this is the question people actually
/// open the app to answer.
class _DezlegariPreview extends StatelessWidget {
  const _DezlegariPreview({required this.period});

  final FastingPeriod period;

  @override
  Widget build(BuildContext context) {
    // One representative of each weekday within the period, so the pattern of
    // dezlegări is legible without scrolling forty days.
    final List<DateTime> sample = <DateTime>[];
    DateTime cursor = period.start;
    while (sample.length < 7 && !cursor.isAfter(period.end)) {
      sample.add(cursor);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final DateTime d in sample)
          _DayChip(
            weekday: DateFormat('EEE', 'ro').format(d),
            level: LiturgicalCalendar.dayFor(d).fastLevel,
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.weekday, required this.level});

  final String weekday;
  final FastLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: TroitaColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TroitaColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fastLevelColor(level),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$weekday · ${level.shortLabel}',
            style: const TextStyle(fontSize: 11, color: TroitaColors.ink),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.period, required this.today});

  final FastingPeriod period;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final int elapsed = today.difference(period.start).inDays + 1;
    final double fraction = (elapsed / period.days).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: TroitaColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(
              TroitaColors.burgundy,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ziua $elapsed din ${period.days}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _WeeklyRuleCard extends StatelessWidget {
  const _WeeklyRuleCard();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: TroitaSpacing.page),
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
