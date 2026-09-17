import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../app/troita_icons.dart';
import '../../core/data/day_repository.dart';
import '../../core/models/fast_day.dart';
import 'day_detail_page.dart';
import 'day_row.dart';
import 'month_grid_sheet.dart';

/// The calendar, as a scrolling list of days.
///
/// This replaced a seven-column month grid. The grid looked like the Figma
/// mockup, but it forced day numbers to 14pt and pushed the fasting state into
/// a four-pixel dot — unreadable for the people most likely to open this every
/// morning. A printed Romanian calendar is a list for the same reason, and a
/// list has room to spell things out.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  final ScrollController _scroll = ScrollController();

  List<DayEntry> _days = const <DayEntry>[];
  Map<String, FastDay> _marked = const <String, FastDay>{};
  bool _loading = true;

  static const double _rowEstimate = 132;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(scrollToday: true));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool scrollToday = false}) async {
    setState(() => _loading = true);
    final AppState state = AppScope.of(context);
    final List<DayEntry> days =
        await state.days.forMonth(_month.year, _month.month);
    final Map<String, FastDay> marked = await state.journal.inRange(
      DateTime(_month.year, _month.month, 1),
      DateTime(_month.year, _month.month + 1, 0),
    );
    if (!mounted) return;
    setState(() {
      _days = days;
      _marked = marked;
      _loading = false;
    });

    if (!scrollToday) return;
    final DateTime now = DateTime.now();
    if (now.year != _month.year || now.month != _month.month) return;
    // Land a couple of rows above today so the user sees where they are in the
    // month rather than at the very top of the viewport.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final double target = ((now.day - 3).clamp(0, 31)) * _rowEstimate;
      _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
    });
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  void _goToday() {
    final DateTime now = DateTime.now();
    setState(() => _month = DateTime(now.year, now.month));
    _load(scrollToday: true);
  }

  Future<void> _openMonthGrid() async {
    final DateTime? picked = await showMonthGrid(context, month: _month);
    if (picked == null || !mounted) return;

    // The user may have paged to another month inside the grid. Follow them, so
    // that closing the saint's page leaves the list where they were looking
    // rather than back where they started.
    if (picked.year != _month.year || picked.month != _month.month) {
      setState(() => _month = DateTime(picked.year, picked.month));
      await _load();
      if (!mounted) return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DayDetailPage(date: picked)),
    );
  }

  int _seenRevision = 0;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    // Ratings can be made from Posturi or a day page; pick them up when we
    // come back rather than making every row listen individually.
    if (state.journalRevision != _seenRevision) {
      _seenRevision = state.journalRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final bool isCurrentMonth =
        now.year == _month.year && now.month == _month.month;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Header(
            month: _month,
            onPrevious: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
            onToday: isCurrentMonth ? null : _goToday,
            onTapMonth: _openMonthGrid,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    itemCount: _days.length,
                    itemBuilder: (BuildContext context, int i) {
                      final DayEntry entry = _days[i];
                      return DayRow(
                        entry: entry,
                        isToday: entry.date == today,
                        marked: _marked[FastDay.key(entry.date)],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DayDetailPage(date: entry.date),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onTapMonth,
    this.onToday,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTapMonth;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    final String title = toBeginningOfSentenceCase(
          DateFormat('LLLL yyyy', 'ro').format(month),
        ) ??
        '';

    return Container(
      padding: const EdgeInsets.fromLTRB(TroitaSpacing.page, 10, 10, 10),
      decoration: const BoxDecoration(
        color: TroitaColors.paper,
        border: Border(bottom: BorderSide(color: TroitaColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // The month name doubles as the button that opens the grid.
                // A caret is the only affordance there is room for, so the
                // tap target is stretched to the full 44pt height instead.
                InkWell(
                  onTap: onTapMonth,
                  borderRadius: TroitaRadius.smallAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontSize: 24),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.expand_more,
                            size: 22, color: TroitaColors.muted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Text('CALENDAR ORTODOX',
                        style: Theme.of(context).textTheme.labelLarge),
                    if (onToday != null) ...<Widget>[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: onToday,
                        child: const Text(
                          'Astăzi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: TroitaColors.burgundy,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          _NavButton(icon: Icons.chevron_left, onTap: onPrevious),
          const SizedBox(width: 6),
          _NavButton(icon: Icons.chevron_right, onTap: onNext),
          const SizedBox(width: 6),
          _NavButton(icon: TroitaIcons.search, onTap: () {}),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

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
          // 44 is the smallest comfortable target; these are used constantly.
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: TroitaColors.ink),
          ),
        ),
      );
}
