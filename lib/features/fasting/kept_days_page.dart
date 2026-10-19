import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/data/day_repository.dart';
import '../../core/format_ro.dart' as ro;
import '../../core/liturgical/fasting_period.dart';
import '../calendar/day_detail_page.dart';

/// The days answered Da, newest first, grouped by month.
///
/// Opened from the all-time total on the Posturi page, or — with [period] —
/// from one fast's tally, showing only that fast's days. Each row names the
/// day's saint and rule, because a bare list of dates says when, not what the
/// day was; tapping one opens the day.
class KeptDaysPage extends StatefulWidget {
  const KeptDaysPage({this.period, super.key});

  /// When set, only the days of this fast.
  final FastingPeriod? period;

  @override
  State<KeptDaysPage> createState() => _KeptDaysPageState();
}

class _KeptDaysPageState extends State<KeptDaysPage> {
  List<DayEntry>? _days;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final AppState state = AppScope.of(context);
    final List<DateTime> dates = await state.journal.keptDays(
      from: widget.period?.start,
      to: widget.period?.end,
    );
    final List<DayEntry> days = <DayEntry>[
      for (final DateTime d in dates) await state.days.entryFor(d),
    ];
    if (mounted) setState(() => _days = days);
  }

  @override
  Widget build(BuildContext context) {
    final List<DayEntry>? days = _days;
    final String title = widget.period == null
        ? 'Zilele de post ținute'
        : widget.period!.label;

    return Scaffold(
      backgroundColor: TroitaColors.paper,
      appBar: AppBar(
        backgroundColor: TroitaColors.paper,
        surfaceTintColor: Colors.transparent,
        title: Text(title, maxLines: 2),
      ),
      body: days == null
          ? const Center(child: CircularProgressIndicator())
          : days.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(TroitaSpacing.page * 1.5),
                  child: Center(
                    child: Text(
                      'Nicio zi însemnată ca ținută încă.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: TroitaColors.muted),
                    ),
                  ),
                )
              : _List(days: days),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.days});

  final List<DayEntry> days;

  @override
  Widget build(BuildContext context) {
    final DateFormat monthFmt = DateFormat('LLLL yyyy', 'ro');
    final DateFormat weekdayFmt = DateFormat('EEEE', 'ro');

    // Month headers interleaved with the rows they head.
    final List<Widget> children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
            TroitaSpacing.page, TroitaSpacing.gap, TroitaSpacing.page, 0),
        child: Text(
          '${ro.days(days.length)} în total',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: TroitaColors.burgundy,
          ),
        ),
      ),
    ];
    String? currentMonth;
    for (final DayEntry e in days) {
      final String month =
          toBeginningOfSentenceCase(monthFmt.format(e.date)) ?? '';
      if (month != currentMonth) {
        currentMonth = month;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(
              TroitaSpacing.page, TroitaSpacing.page, TroitaSpacing.page, 6),
          child: Text(month.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge),
        ));
      }
      children.add(_DayTile(entry: e, weekday: weekdayFmt));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: TroitaSpacing.page),
      children: children,
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.entry, required this.weekday});

  final DayEntry entry;
  final DateFormat weekday;

  @override
  Widget build(BuildContext context) {
    final String saint = entry.primary?.displayName ?? 'Pomenirea zilei';
    final String? rule =
        entry.liturgical.isFasting ? entry.liturgical.fastLevel.label : null;

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => DayDetailPage(date: entry.date),
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: TroitaSpacing.page, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 46,
              child: Column(
                children: <Widget>[
                  Text('${entry.date.day}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: TroitaColors.ink,
                        height: 1.1,
                      )),
                  Text(
                    weekday.format(entry.date).substring(0, 3),
                    style: const TextStyle(
                        fontSize: 11.5, color: TroitaColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(saint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, color: TroitaColors.ink, height: 1.3)),
                  if (rule != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(rule,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: fastLevelColor(entry.liturgical.fastLevel),
                          )),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.check_circle,
                  size: 20, color: TroitaColors.burgundy),
            ),
          ],
        ),
      ),
    );
  }
}
