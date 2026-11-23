import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/site_links.dart';
import '../../app/theme.dart';
import '../../core/data/day_repository.dart';
import '../../core/liturgical/calendar_days.dart';
import '../../core/liturgical/fast_level.dart';
import '../../core/liturgical/liturgical_calendar.dart';
import '../../core/models/feast.dart';
import '../../core/models/fast_day.dart';
import '../../core/models/feast_calendar.dart';
import '../../core/models/lecturi.dart';
import '../../core/models/name_days.dart';
import '../../core/models/sinaxar.dart';
import '../fasting/fast_day_editor.dart';
import 'day_row.dart';

/// The saint of the day, at length.
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
  bool _missing = false;
  List<String> _names = const <String>[];
  LecturaZi? _lectura;
  BibliaNT? _biblia;

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
    BibliaNT? biblia;
    try {
      lectura = (await state.lecturi.lecturi()).on(widget.date);
      biblia = await state.lecturi.biblia();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _names = names;
      _lectura = lectura;
      _biblia = biblia;
      _missing = entry.sinaxar == null;
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
                if (_lectura != null && _biblia != null)
                  _ReadingsCard(
                      lectura: _lectura!, biblia: _biblia!, scale: _scale),

                // Rating any past day, not just today — people fill these in
                // after the fact, and refusing that makes the journal useless
                // the first time someone forgets.
                if (AppScope.of(context).journalEnabled &&
                    entry.liturgical.isFasting &&
                    !widget.date.isAfter(DateTime.now()))
                  _DayRating(date: widget.date),

                if (entry.sinaxar != null && !entry.sinaxar!.isEmpty) ...<Widget>[
                  const SizedBox(height: 24),
                  const _Ornament(),
                  const SizedBox(height: 20),
                  if (entry.sinaxar!.images.isNotEmpty) ...<Widget>[
                    _SaintImages(names: entry.sinaxar!.images),
                    const SizedBox(height: 20),
                  ],
                  ..._sections(entry.sinaxar!),
                  const SizedBox(height: 12),
                ] else if (_missing) ...<Widget>[
                  const SizedBox(height: 24),
                  const _Ornament(),
                  const SizedBox(height: 20),
                  Text(
                    'Sinaxarul pentru această zi nu este încă inclus.\n\n'
                    'Rulați scriptul de colectare (tool/scrape_calendar.py) '
                    'pentru a adăuga textele pentru tot anul.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 15 * _scale, height: 1.6),
                  ),
                ],
              ],
            ),
    );
  }

  List<Widget> _sections(Sinaxar sinaxar) {
    final List<String> parts =
        sinaxar.sections.isEmpty ? <String>[sinaxar.text] : sinaxar.sections;
    return <Widget>[
      for (final String part in parts)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            part,
            textAlign: TextAlign.justify,
            style: TroitaCalendarText.commemoration.copyWith(
              fontSize: 16.5 * _scale,
              // Generous leading: this is long-form reading, not a UI label.
              height: 1.65,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
    ];
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

/// "Apostolul și Evanghelia": the Liturgy readings of the day, in full.
///
/// From assets/data/lecturi.json (which pericope) and biblia_nt.json (the
/// text of the 1988 Synodal edition), the same files troita.ro reads. Follows
/// the page's text-size control, like the sinaxar.
class _ReadingsCard extends StatelessWidget {
  const _ReadingsCard({
    required this.lectura,
    required this.biblia,
    required this.scale,
  });

  final LecturaZi lectura;
  final BibliaNT biblia;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(TroitaSpacing.card),
      decoration: TroitaTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Apostolul și Evanghelia', style: text.titleMedium),
          if (lectura.title != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(lectura.title!, style: text.bodySmall),
          ],
          if (lectura.none != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(lectura.none!, style: text.bodyMedium),
          ] else ...<Widget>[
            if (lectura.apostolCite != null)
              _reading(context, 'Apostolul', lectura.apostolCite!,
                  biblia.text(lectura.apostol)),
            if (lectura.evanghelieCite != null)
              _reading(context, 'Evanghelia', lectura.evanghelieCite!,
                  biblia.text(lectura.evanghelie)),
            const SizedBox(height: 4),
            Text(biblia.source, style: text.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _reading(
      BuildContext context, String label, String cite, List<Verse> verses) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$label · $cite',
              style: text.titleSmall?.copyWith(color: TroitaColors.burgundy)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(children: <InlineSpan>[
              for (final Verse v in verses) ...<InlineSpan>[
                TextSpan(
                  text: '${v.number} ',
                  style: TextStyle(
                      fontSize: 12 * scale, color: TroitaColors.muted),
                ),
                TextSpan(text: '${v.text} '),
              ],
            ]),
            style: TroitaCalendarText.commemoration.copyWith(
              fontSize: 16.5 * scale,
              height: 1.65,
              fontWeight: FontWeight.w400,
            ),
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

/// Saint icons bundled from the sinaxar scrape.
///
/// Sized to their natural aspect ratio rather than cropped to a fixed box —
/// these are icons, and cutting a saint's head off to fit a 16:9 card is not a
/// design choice anyone should make. One image fills the column; several
/// scroll horizontally.
///
/// [errorBuilder] matters more than usual here: 293 of 366 days have images,
/// the filenames come from a scrape, and a missing file must degrade to blank
/// space rather than a red error box in the middle of someone's morning
/// reading.
class _SaintImages extends StatelessWidget {
  const _SaintImages({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    if (names.length == 1) {
      return Center(child: _SaintImage(name: names.first, maxHeight: 320));
    }
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: names.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int i) =>
            _SaintImage(name: names[i], maxHeight: 240),
      ),
    );
  }
}

class _SaintImage extends StatelessWidget {
  const _SaintImage({required this.name, required this.maxHeight});

  final String name;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: TroitaRadius.mediumAll,
      child: Container(
        decoration: TroitaTheme.cardDecoration(radius: TroitaRadius.medium),
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Image.asset(
          'assets/sinaxar/$name',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The little rule-dot-rule from `byzantine-ornament` (2:275).
class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(width: 40, height: 1, color: TroitaColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.add, size: 14, color: TroitaColors.gold),
          ),
          Container(width: 40, height: 1, color: TroitaColors.border),
        ],
      );
}

