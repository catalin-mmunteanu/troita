import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/data/day_repository.dart';
import '../../core/models/feast.dart';
import '../../core/models/lecturi.dart';
import '../../core/notifications/notification_prefs.dart';
import 'reading_widgets.dart';

/// Lecturi: the sinaxar and the Liturgy readings of a day, to read.
///
/// The third tab opens it on today. A day's "Evanghelia" and "Sinaxar"
/// buttons and the morning notifications open the same screen on their day
/// and sub-tab. Days move with the arrows under the tabs, not by swiping: a
/// horizontal swipe already switches Sinaxar and Evanghelie. The text size
/// is kept between visits, because the people who need it larger need it
/// larger every time.
class LecturiPage extends StatefulWidget {
  const LecturiPage({super.key, this.date, this.tab = ReadingTab.sinaxar});

  /// The day to open on; today when null.
  final DateTime? date;
  final ReadingTab tab;

  @override
  State<LecturiPage> createState() => _LecturiPageState();
}

class _LecturiPageState extends State<LecturiPage>
    with SingleTickerProviderStateMixin {
  static const String _kScale = 'reading_scale';

  late final TabController _tabs = TabController(
      length: ReadingTab.values.length, vsync: this, initialIndex: widget.tab.index);
  late DateTime _date = _dayOf(widget.date ?? DateTime.now());
  double _scale = 1.0;
  DayEntry? _entry;
  LecturaZi? _lectura;
  BibliaNT? _biblia;
  bool _loading = true;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((SharedPreferences p) {
      final double? s = p.getDouble(_kScale);
      if (s != null && mounted) setState(() => _scale = s.clamp(0.85, 1.75));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppState state = AppScope.of(context);
    final DateTime date = _date;
    setState(() => _loading = true);
    DayEntry? entry;
    LecturaZi? lectura;
    BibliaNT? biblia;
    try {
      entry = await state.days.entryFor(date, withText: true);
    } catch (_) {}
    try {
      lectura = (await state.lecturi.lecturi()).on(date);
      biblia = await state.lecturi.biblia();
    } catch (_) {}
    if (!mounted || date != _date) return;
    setState(() {
      _entry = entry;
      _lectura = lectura;
      _biblia = biblia;
      _loading = false;
    });
  }

  void _go(DateTime d) {
    setState(() => _date = _dayOf(d));
    _load();
  }

  Future<void> _setScale(double s) async {
    setState(() => _scale = s);
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setDouble(_kScale, s);
  }

  @override
  Widget build(BuildContext context) {
    final bool isToday = _date == _dayOf(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturi'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Text mai mic',
            onPressed: _scale <= 0.85 ? null : () => _setScale(_scale - 0.15),
            icon: const Text('A−', style: TextStyle(fontSize: 15)),
          ),
          IconButton(
            tooltip: 'Text mai mare',
            onPressed: _scale >= 1.75 ? null : () => _setScale(_scale + 0.15),
            icon: const Text('A+', style: TextStyle(fontSize: 19)),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const <Widget>[Tab(text: 'Sinaxar'), Tab(text: 'Evanghelie')],
        ),
      ),
      body: Column(
        children: <Widget>[
          _DayNav(
            date: _date,
            isToday: isToday,
            onPrev: () => _go(_date.subtract(const Duration(days: 1))),
            onNext: () => _go(_date.add(const Duration(days: 1))),
            onToday: () => _go(DateTime.now()),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: <Widget>[_sinaxar(context), _gospel(context)],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sinaxar(BuildContext context) {
    final DayEntry? entry = _entry;
    final TextTheme text = Theme.of(context).textTheme;
    final List<Feast> feasts = entry?.feasts ?? const <Feast>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      children: <Widget>[
        for (final Feast f in feasts.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              f.name,
              style: TroitaCalendarText.commemoration.copyWith(
                fontSize: 21 * _scale,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (entry?.sinaxar != null && !entry!.sinaxar!.isEmpty)
          SinaxarText(sinaxar: entry.sinaxar!, scale: _scale)
        else
          Text(
            'Sinaxarul pentru această zi nu este încă inclus.',
            style: text.bodyMedium?.copyWith(fontSize: 15 * _scale, height: 1.6),
          ),
      ],
    );
  }

  Widget _gospel(BuildContext context) {
    final AppState state = AppScope.of(context);
    final NotificationPrefs prefs = state.notificationPrefs;
    final LecturaZi? lectura = _lectura;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 48),
      children: <Widget>[
        if (lectura != null && _biblia != null)
          ReadingsCard(
            lectura: lectura,
            biblia: _biblia!,
            scale: _scale,
            gospelFirst: true,
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Pentru această zi nu avem lecturile.'),
          ),
        if (lectura?.none != null) _NextSunday(from: _date, onGo: _go),
        if (!prefs.gospel)
          Container(
            margin: const EdgeInsets.only(top: 14),
            decoration: TroitaTheme.cardDecoration(),
            child: SwitchListTile(
              value: false,
              onChanged: (bool v) => state.setNotificationPrefs(
                  prefs.copyWith(gospel: v)),
              title: const Text('Primiți Evanghelia în fiecare dimineață'),
              subtitle: Text('La ora ${prefs.gospelTimeLabel}. Ora se '
                  'schimbă din Profil → Setări.'),
            ),
          ),
      ],
    );
  }
}

/// "‹  marți, 24 noiembrie 2026  ›", with "Azi" when away from today.
class _DayNav extends StatelessWidget {
  const _DayNav({
    required this.date,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime date;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final String label = toBeginningOfSentenceCase(
          DateFormat('EEEE, d MMMM yyyy', 'ro').format(date),
        ) ??
        '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Ziua dinainte',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (!isToday)
            TextButton(onPressed: onToday, child: const Text('Azi')),
          IconButton(
            tooltip: 'Ziua următoare',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// On a day without Liturgy: a way to the next Sunday's Gospel.
class _NextSunday extends StatelessWidget {
  const _NextSunday({required this.from, required this.onGo});

  final DateTime from;
  final ValueChanged<DateTime> onGo;

  @override
  Widget build(BuildContext context) {
    final int add = DateTime.sunday - from.weekday;
    final DateTime sunday = from.add(Duration(days: add <= 0 ? add + 7 : add));
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => onGo(sunday),
        child: Text('Evanghelia de duminică, '
            '${DateFormat('d MMMM', 'ro').format(sunday)}'),
      ),
    );
  }
}
