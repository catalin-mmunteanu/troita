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

/// The calendar, as a horizontally paged stack of month-long day lists.
///
/// The list itself replaced a seven-column month grid. The grid looked like the
/// Figma mockup, but it forced day numbers to 14pt and pushed the fasting state
/// into a four-pixel dot — unreadable for the people most likely to open this
/// every morning. A printed Romanian calendar is a list for the same reason,
/// and a list has room to spell things out.
///
/// Months are a [PageView] rather than a swap of the list's contents. Both can
/// be driven by the same arrows, but only one lets the next month follow the
/// finger, and that motion is what tells the user the gesture exists at all —
/// nothing on screen advertises it.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  /// The page the app opens on. Paging is bounded rather than infinite: a
  /// hundred years either way is more than anyone will swipe through, and it
  /// keeps the calendar inside the range the liturgical engine is verified
  /// over instead of letting someone arrive at year 9000 and read nonsense.
  static const int _anchorPage = 1200;
  static const int _pageCount = 2401;

  late final DateTime _anchorMonth;
  late final PageController _pages;

  DateTime _month = DateTime.now();
  int _revision = 0;

  /// Months already read from the database, so swiping back is instant and
  /// does not flash a spinner at someone moving between two months.
  final Map<String, _MonthData> _cache = <String, _MonthData>{};

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _anchorMonth = DateTime(now.year, now.month);
    _month = _anchorMonth;
    _pages = PageController(initialPage: _anchorPage);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) =>
      DateTime(_anchorMonth.year, _anchorMonth.month + (page - _anchorPage));

  int _pageForMonth(DateTime month) =>
      _anchorPage +
      (month.year - _anchorMonth.year) * 12 +
      (month.month - _anchorMonth.month);

  static String _key(DateTime month) => '${month.year}-${month.month}';

  /// One place that reads a month, so the [PageView]'s pages stay dumb and the
  /// cache cannot be bypassed by one of them.
  Future<_MonthData> _dataFor(DateTime month) async {
    final String key = _key(month);
    final _MonthData? hit = _cache[key];
    if (hit != null) return hit;

    final AppState state = AppScope.of(context);
    final List<DayEntry> days =
        await state.days.forMonth(month.year, month.month);
    final Map<String, FastDay> marked = await state.journal.inRange(
      DateTime(month.year, month.month, 1),
      DateTime(month.year, month.month + 1, 0),
    );
    return _cache[key] = _MonthData(days: days, marked: marked);
  }

  void _goToPage(int page) {
    _pages.animateToPage(
      page.clamp(0, _pageCount - 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _shiftMonth(int delta) => _goToPage(_pageForMonth(_month) + delta);

  void _goToday() {
    final DateTime now = DateTime.now();
    final int target = _pageForMonth(DateTime(now.year, now.month));
    // Far from today, sliding through eleven months of animation is slower and
    // more disorienting than simply arriving.
    if ((target - _pageForMonth(_month)).abs() > 2) {
      _pages.jumpToPage(target);
    } else {
      _goToPage(target);
    }
  }

  Future<void> _openMonthGrid() async {
    final DateTime? picked = await showMonthGrid(context, month: _month);
    if (picked == null || !mounted) return;

    // The user may have paged to another month inside the grid. Follow them, so
    // that closing the saint's page leaves the list where they were looking
    // rather than back where they started.
    final int target = _pageForMonth(DateTime(picked.year, picked.month));
    if (target != _pageForMonth(_month)) {
      _pages.jumpToPage(target.clamp(0, _pageCount - 1));
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DayDetailPage(date: picked)),
    );
  }

  int _seenRevision = 0;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    // Ratings can be made from Posturi or a day page. Drop the cache and bump
    // the revision so every live page reloads, rather than making each row
    // listen for itself.
    if (state.journalRevision != _seenRevision) {
      _seenRevision = state.journalRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _cache.clear();
          _revision++;
        });
      });
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
            child: PageView.builder(
              controller: _pages,
              itemCount: _pageCount,
              onPageChanged: (int page) =>
                  setState(() => _month = _monthForPage(page)),
              itemBuilder: (BuildContext context, int page) {
                final DateTime month = _monthForPage(page);
                return _MonthList(
                  // Keyed by month and revision: a rating made elsewhere has to
                  // rebuild this page's state, not just its widget.
                  key: ValueKey<String>('${_key(month)}#$_revision'),
                  month: month,
                  today: today,
                  load: _dataFor,
                  onTapDay: (DateTime date) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DayDetailPage(date: date),
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

/// One month's worth of days, read once and held.
class _MonthData {
  const _MonthData({required this.days, required this.marked});

  final List<DayEntry> days;
  final Map<String, FastDay> marked;
}

class _MonthList extends StatefulWidget {
  const _MonthList({
    required this.month,
    required this.today,
    required this.load,
    required this.onTapDay,
    super.key,
  });

  final DateTime month;
  final DateTime today;
  final Future<_MonthData> Function(DateTime) load;
  final ValueChanged<DateTime> onTapDay;

  @override
  State<_MonthList> createState() => _MonthListState();
}

class _MonthListState extends State<_MonthList> {
  final ScrollController _scroll = ScrollController();
  _MonthData? _data;

  /// Rough height of a row, used only to land near today on first open. Exact
  /// enough for that and not worth measuring: being a row or two off is
  /// invisible, and measuring would mean building the list twice.
  static const double _rowEstimate = 132;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final _MonthData data = await widget.load(widget.month);
    if (!mounted) return;
    setState(() => _data = data);

    final DateTime today = widget.today;
    if (today.year != widget.month.year || today.month != widget.month.month) {
      return;
    }
    // Land a couple of rows above today, so the user sees where they are in
    // the month rather than at the very top of the viewport.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final double target = ((today.day - 3).clamp(0, 31)) * _rowEstimate;
      _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final _MonthData? data = _data;
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      controller: _scroll,
      itemCount: data.days.length,
      itemBuilder: (BuildContext context, int i) {
        final DayEntry entry = data.days[i];
        return DayRow(
          entry: entry,
          isToday: entry.date == widget.today,
          marked: data.marked[FastDay.key(entry.date)],
          onTap: () => widget.onTapDay(entry.date),
        );
      },
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
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Keyed by month so the name cross-fades as the pages
                        // slide, instead of snapping when the swipe settles.
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            title,
                            key: ValueKey<String>(title),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontSize: 24),
                          ),
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
