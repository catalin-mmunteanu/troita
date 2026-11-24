import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/site_links.dart';
import '../../app/theme.dart';
import '../../app/troita_icons.dart';
import '../../core/data/day_repository.dart';
import '../../core/liturgical/calendar_days.dart';
import '../../core/liturgical/fast_level.dart';
import '../../core/liturgical/liturgical_calendar.dart';
import '../../core/models/church.dart';
import '../../core/models/feast.dart';
import '../../core/models/fast_day.dart';
import '../../core/models/feast_calendar.dart';
import '../../core/models/lecturi.dart';
import '../../core/models/name_days.dart';
import '../fasting/fast_day_editor.dart';
import '../lecturi/lecturi_page.dart';
import '../map/churches_map_page.dart';
import 'day_row.dart';

/// One day of the calendar: commemorations, fasting, weddings, name days.
///
/// The long texts (the sinaxar, the Apostol and the Gospel) are read on the
/// Lecturi screen; the two buttons under the name days open it on this day.
///
/// Carries its own text-size control. The published calendars all have an
/// A+ / A− pair for a reason: this is long-form reading for an audience whose
/// eyesight varies, and sending them to Android's global font setting is worse
/// than giving them a control where they are reading.
class DayDetailPage extends StatefulWidget {
  const DayDetailPage({required this.date, super.key});

  final DateTime date;

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  DayEntry? _entry;
  List<String> _names = const <String>[];
  LecturaZi? _lectura;
  List<Church> _hramuri = const <Church>[];

  /// Multiplier on top of the system text scale, not a replacement for it.
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final AppState state = AppScope.of(context);
    final DayEntry entry =
        await state.days.entryFor(widget.date, withText: true);
    // A missing or broken asset must not cost the user the whole day.
    List<String> names = const <String>[];
    try {
      final NameDays nameDays = await state.nameDays.load();
      names = nameDays.namesOn(widget.date);
    } catch (_) {}
    LecturaZi? lectura;
    try {
      lectura = (await state.lecturi.lecturi()).on(widget.date);
    } catch (_) {}
    List<Church> hramuri = const <Church>[];
    try {
      hramuri = await state.repository.feastsOn(widget.date);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _names = names;
      _lectura = lectura;
      _hramuri = hramuri;
    });
  }

  /// The day as a short message: date, the commemorations, the fasting rule.
  ///
  /// Plain text through the system share sheet, so it reads the same in
  /// WhatsApp, an SMS or an email, and nothing of the user goes with it. The
  /// sinaxar itself is left out on purpose — pages of text are not a message.
  Future<void> _share(DayEntry entry) async {
    final String date = toBeginningOfSentenceCase(
          DateFormat('EEEE, d MMMM yyyy', 'ro').format(entry.date),
        ) ??
        '';
    final List<String> lines = <String>[
      date,
      if (entry.feasts.isNotEmpty)
        ...entry.feasts.take(3).map((Feast f) => f.name)
      else
        'Pomenirea zilei',
      if (entry.liturgical.isFasting) entry.liturgical.fastLevel.label,
      '',
      '— din calendarul Troița',
      // A link, not just a name: anyone can open the day on troita.ro, and on
      // a phone with the app it opens here (App Links).
      SiteLinks.day(entry.date),
    ];
    await AppScope.of(context).native.shareText(lines.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final DayEntry? entry = _entry;
    final String heading = toBeginningOfSentenceCase(
          DateFormat('EEEE, d MMMM yyyy', 'ro').format(widget.date),
        ) ??
        '';

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('d MMMM', 'ro').format(widget.date)),
        actions: <Widget>[
          IconButton(
            tooltip: 'Text mai mic',
            onPressed: _scale <= 0.85
                ? null
                : () => setState(() => _scale -= 0.15),
            icon: const Text('A−', style: TextStyle(fontSize: 15)),
          ),
          IconButton(
            tooltip: 'Text mai mare',
            onPressed: _scale >= 1.75
                ? null
                : () => setState(() => _scale += 0.15),
            icon: const Text('A+', style: TextStyle(fontSize: 19)),
          ),
          IconButton(
            tooltip: 'Trimite',
            onPressed: entry == null ? null : () => _share(entry),
            icon: const Icon(Icons.share_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: entry == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
              children: <Widget>[
                Text(heading, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),

                // Commemorations, largest first.
                ...entry.feasts.map((Feast f) => _Commemoration(
                      feast: f,
                      scale: _scale,
                    )),
                if (entry.feasts.isEmpty)
                  Text('Pomenirea zilei',
                      style: Theme.of(context).textTheme.headlineMedium),

                const SizedBox(height: 18),
                _LiturgicalCard(entry: entry),
                if (_names.isNotEmpty) _NameDaysCard(names: _names),
                _ReadingButtons(date: widget.date, lectura: _lectura),
                if (_hramuri.isNotEmpty) _HramuriAzi(churches: _hramuri),

                // Rating any past day, not just today — people fill these in
                // after the fact, and refusing that makes the journal useless
                // the first time someone forgets.
                if (AppScope.of(context).journalEnabled &&
                    entry.liturgical.isFasting &&
                    !widget.date.isAfter(DateTime.now()))
                  _DayRating(date: widget.date),

              ],
            ),
    );
  }
}

/// Mark a fast day from its detail page.
class _DayRating extends StatefulWidget {
  const _DayRating({required this.date});

  final DateTime date;

  @override
  State<_DayRating> createState() => _DayRatingState();
}

class _DayRatingState extends State<_DayRating> {
  FastDay? _day;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final FastDay? day =
        await AppScope.of(context).journal.forDate(widget.date);
    if (!mounted) return;
    setState(() {
      _day = day;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 8);
    final AppState state = AppScope.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(TroitaSpacing.card),
      decoration: TroitaTheme.cardDecoration(),
      child: FastDayEditor(
        day: _day,
        onKept: (bool k) async {
          await state.setFastKept(widget.date, k);
          await _reload();
        },
      ),
    );
  }
}

class _Commemoration extends StatelessWidget {
  const _Commemoration({required this.feast, required this.scale});

  final Feast feast;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final bool major = feast.rank == FeastRank.praznic ||
        feast.rank == FeastRank.cruceRosie;
    // Cruce neagră gets its cross and its label too. Showing nothing for it
    // meant a black-cross feast was indistinguishable from an ordinary day,
    // and left the red cross above it looking like it belonged to both.
    final bool ranked = feast.rank != FeastRank.simplu;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (ranked)
            Row(
              children: <Widget>[
                Icon(Icons.add, size: 16, color: feastRankColor(feast.rank)),
                const SizedBox(width: 6),
                Text(
                  feast.rank.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w700,
                    color: feastRankColor(feast.rank),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            feast.name,
            style: TroitaCalendarText.commemoration.copyWith(
              fontSize: (major ? 23 : 19) * scale,
              height: 1.3,
              fontWeight: major ? FontWeight.w700 : FontWeight.w600,
              color: feast.kind == 'romanesc'
                  ? TroitaColors.romanianSaint
                  : (major ? feastRankColor(feast.rank) : TroitaColors.calendarInk),
            ),
          ),
          if (feast.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(feast.note!,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _LiturgicalCard extends StatelessWidget {
  const _LiturgicalCard({required this.entry});

  final DayEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TroitaSpacing.card),
      decoration: TroitaTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FastPill(level: entry.liturgical.fastLevel),
          if (entry.liturgical.period != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(entry.liturgical.period!.label,
                style: Theme.of(context).textTheme.titleMedium),
          ],
          if (entry.liturgical.note != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(entry.liturgical.note!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const Divider(height: 22),
          _EventsNote(entry: entry),
          if (entry.liturgical.glas != null) ...<Widget>[
            const Divider(height: 22),
            Text(
              'Glasul ${entry.liturgical.glas}'
              '${entry.liturgical.voscreasna == null ? '' : ' · voscreasna ${entry.liturgical.voscreasna}'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (entry.computed) ...<Widget>[
            const Divider(height: 22),
            Text(
              'Calculat după rânduiala Bisericii; se confirmă când apare '
              'calendarul oficial pe ${entry.date.year}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Weddings and, when it matters, baptisms on this day.
///
/// People ask both ways ("se fac nunți?", "când nu se fac nunți?"), so the
/// line always says one or the other. Baptism has no forbidden days; it is
/// mentioned only when something changes: the party on a fast day, the
/// parish's programme in Holy Week and Bright Week. Same rules as troita.ro's
/// /nunti and /botez pages.
class _EventsNote extends StatelessWidget {
  const _EventsNote({required this.entry});

  final DayEntry entry;

  @override
  Widget build(BuildContext context) {
    final WeddingBar? bar = LiturgicalCalendar.cununie(entry.date);
    final DateTime p = FeastCalendar.pascha(entry.date.year);
    final int fromPascha = calendarDaysBetween(p, entry.date);
    final String? baptism = fromPascha >= -6 && fromPascha <= -1
        ? 'Botez: în Săptămâna Mare, întrebați la parohie.'
        : fromPascha >= 0 && fromPascha <= 6
            ? 'Botez: se poate face; programați din timp la parohie.'
            : entry.liturgical.isFasting
                ? 'Botez: se poate face; petrecerea, cu mâncare de post.'
                : null;
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          bar == null ? 'Se pot face nunți.' : 'Nu se fac nunți: ${bar.label}.',
          style: style,
        ),
        if (baptism != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(baptism, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// "Evanghelia" and "Sinaxar": open the reading screen on this day.
class _ReadingButtons extends StatelessWidget {
  const _ReadingButtons({required this.date, required this.lectura});

  final DateTime date;
  final LecturaZi? lectura;

  void _open(BuildContext context, ReadingTab tab) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LecturiPage(date: date, tab: tab),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final String? cite = lectura?.hasGospel == true ? lectura!.evanghelieCite : null;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _BigButton(
              icon: Icons.menu_book_outlined,
              label: 'Evanghelia',
              detail: cite ?? (lectura?.none != null ? 'fără Liturghie' : null),
              onTap: () => _open(context, ReadingTab.evanghelie),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BigButton(
              icon: Icons.auto_stories_outlined,
              label: 'Sinaxar',
              detail: 'Viețile sfinților zilei',
              onTap: () => _open(context, ReadingTab.sinaxar),
            ),
          ),
        ],
      ),
    );
  }
}

/// A large, two-line button: a 48dp target at any text size.
class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: TroitaRadius.mediumAll,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: TroitaTheme.cardDecoration(radius: TroitaRadius.medium),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(children: <Widget>[
                  Icon(icon, size: 20, color: TroitaColors.burgundy),
                  const SizedBox(width: 8),
                  Flexible(child: Text(label, style: text.titleMedium)),
                ]),
                if (detail != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(detail!, style: text.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Hramuri azi: 254 de biserici · Vezi pe hartă", only when there are some.
class _HramuriAzi extends StatelessWidget {
  const _HramuriAzi({required this.churches});

  final List<Church> churches;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final int n = churches.length;
    final String count = n == 1
        ? 'o biserică'
        : n < 20
            ? '$n biserici'
            : '$n de biserici';
    final List<String> names =
        churches.take(3).map((Church c) => c.name).toList();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(TroitaSpacing.card),
      decoration: TroitaTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Hramuri: $count', style: text.titleMedium),
          const SizedBox(height: 6),
          Text(
            names.join(', ') + (n > names.length ? ' și altele' : ''),
            style: text.bodyMedium,
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ChurchesMapPage()),
            ),
            icon: const Icon(TroitaIcons.map),
            label: const Text('Vezi pe hartă'),
          ),
        ],
      ),
    );
  }
}

/// "Zile de nume": the first names celebrated on the day.
class _NameDaysCard extends StatelessWidget {
  const _NameDaysCard({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(TroitaSpacing.card),
      decoration: TroitaTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Zile de nume', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(names.join(', '), style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
