import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/data/day_repository.dart';

/// A month-at-a-glance grid, opened by tapping the month name in the calendar
/// header.
///
/// The day list is the primary view and stays that way — it is the one that is
/// readable at arm's length. But a list cannot answer "which Sunday is the
/// 20th" or "how far is it to Crăciun" without scrolling, and that is the
/// question a wall calendar answers instantly. So the grid exists as a lookup,
/// not as a reading surface: numerals only, large, coloured by rank. No feast
/// names, no fasting dots. Every pixel that would go to secondary information
/// goes to the numeral instead, which is why the grid can afford 22pt here
/// where the old full-time grid was stuck at 14.
///
/// Returns the day the user picked, or null if they dismissed it.
Future<DateTime?> showMonthGrid(
  BuildContext context, {
  required DateTime month,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: TroitaColors.paper,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(TroitaRadius.large)),
    ),
    builder: (BuildContext context) => _MonthGridSheet(month: month),
  );
}

class _MonthGridSheet extends StatefulWidget {
  const _MonthGridSheet({required this.month});

  final DateTime month;

  @override
  State<_MonthGridSheet> createState() => _MonthGridSheetState();
}

class _MonthGridSheetState extends State<_MonthGridSheet> {
  late DateTime _month;
  Map<int, DayEntry> _byDay = const <int, DayEntry>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.month.year, widget.month.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final AppState state = AppScope.of(context);
    final List<DayEntry> days =
        await state.days.forMonth(_month.year, _month.month);
    if (!mounted) return;
    setState(() {
      // Keyed by day number rather than trusting list order — a gap in the
      // source data would otherwise shift every following day by one.
      _byDay = <int, DayEntry>{
        for (final DayEntry d in days) d.date.day: d,
      };
      _loading = false;
    });
  }

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final int daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Romanian calendars start the week on Monday; DateTime.monday == 1.
    final int leading = DateTime(_month.year, _month.month, 1).weekday - 1;
    final int cells = ((leading + daysInMonth) / 7).ceil() * 7;

    final String title = toBeginningOfSentenceCase(
          DateFormat('LLLL yyyy', 'ro').format(_month),
        ) ??
        '';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TroitaSpacing.gap,
          TroitaSpacing.listGap,
          TroitaSpacing.gap,
          TroitaSpacing.gap,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 40,
              height: 4,
              decoration: const BoxDecoration(
                color: TroitaColors.border,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
            const SizedBox(height: TroitaSpacing.gap),
            Row(
              children: <Widget>[
                _Arrow(icon: Icons.chevron_left, onTap: () => _shift(-1)),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontSize: 22),
                  ),
                ),
                _Arrow(icon: Icons.chevron_right, onTap: () => _shift(1)),
              ],
            ),
            const SizedBox(height: TroitaSpacing.gap),
            Row(
              children: <Widget>[
                for (final String label in _weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TroitaCalendarText.weekday.copyWith(
                          color: label == _weekdays.last
                              ? TroitaColors.feastRed
                              : TroitaColors.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: TroitaSpacing.listGap),
            // Swipeable, like the day list behind it. A sheet that answers only
            // to its arrows, while the list underneath follows the finger,
            // reads as the gesture having stopped working.
            //
            // Reserve the grid's height while loading so the sheet does not
            // jump once the days arrive. The cell height is pinned rather than
            // derived from the width: with a square aspect ratio a tablet would
            // make each cell as tall as it is wide, and the grid would overflow
            // the box reserved here — silently clipped, because the grid does
            // not scroll.
            GestureDetector(
              // Only the horizontal axis, so a tap on a day still reaches the
              // cell underneath.
              onHorizontalDragEnd: (DragEndDetails d) {
                final double v = d.velocity.pixelsPerSecond.dx;
                if (v.abs() < 200) return;
                _shift(v < 0 ? 1 : -1);
              },
              child: SizedBox(
              height: (cells ~/ 7) * _cellHeight + (cells ~/ 7 - 1) * 2,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                        mainAxisExtent: _cellHeight,
                      ),
                      itemCount: cells,
                      itemBuilder: (BuildContext context, int i) {
                        final int day = i - leading + 1;
                        if (day < 1 || day > daysInMonth) {
                          return const SizedBox.shrink();
                        }
                        final DateTime date =
                            DateTime(_month.year, _month.month, day);
                        return _DayCell(
                          date: date,
                          entry: _byDay[day],
                          isToday: date == today,
                          onTap: () => Navigator.of(context).pop(date),
                        );
                      },
                    ),
              ),
            ),
            const SizedBox(height: TroitaSpacing.gap),
            const _Legend(),
          ],
        ),
      ),
    );
  }
}

const List<String> _weekdays = <String>['Lu', 'Ma', 'Mi', 'Jo', 'Vi', 'Sâ', 'Du'];

/// Comfortably above the 44pt minimum target, and tall enough for a 22pt
/// numeral without the six-row months pushing the sheet off-screen.
const double _cellHeight = 52;

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.entry,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final DayEntry? entry;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Until the month loads, days read as ordinary rather than flickering from
    // black to red a frame later.
    final Color colour = entry == null
        ? TroitaColors.calendarInk
        : calendarDayColor(
            rank: entry!.rank,
            isSunday: entry!.isSunday,
            inMonth: true,
          );

    return Material(
      color: isToday ? TroitaColors.accentSurface : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: TroitaRadius.smallAll,
        side: isToday
            ? const BorderSide(color: TroitaColors.burgundy, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: TroitaRadius.smallAll,
        child: Center(
          child: Text(
            '${date.day}',
            style: TroitaCalendarText.numeral.copyWith(
              fontSize: 22,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: colour,
            ),
          ),
        ),
      ),
    );
  }
}

/// Without this the colours are a private convention. Three words each is
/// enough for someone who already knows the calendar, and enough to teach
/// someone who does not.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: TroitaSpacing.gap,
      runSpacing: 4,
      children: const <Widget>[
        _LegendItem(colour: TroitaColors.feastRed, label: 'Cruce roșie · duminici'),
        _LegendItem(colour: TroitaColors.feastBlue, label: 'Cruce albastră'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.colour, required this.label});

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('—',
            style: TextStyle(
                color: colour, fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 12, color: TroitaColors.muted)),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: TroitaColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: TroitaRadius.smallAll,
          side: BorderSide(color: TroitaColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: TroitaRadius.smallAll,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: TroitaColors.ink),
          ),
        ),
      );
}
