import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../core/data/day_repository.dart';
import '../../core/liturgical/fast_level.dart';
import '../../core/models/feast.dart';
import '../../core/models/sinaxar.dart';
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

  /// Multiplier on top of the system text scale, not a replacement for it.
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final DayEntry entry =
        await AppScope.of(context).days.entryFor(widget.date, withText: true);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _missing = entry.sinaxar == null;
    });
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

                if (entry.sinaxar != null && !entry.sinaxar!.isEmpty) ...<Widget>[
                  const SizedBox(height: 24),
                  const _Ornament(),
                  const SizedBox(height: 20),
                  if (entry.sinaxar!.images.isNotEmpty) ...<Widget>[
                    _SaintImages(names: entry.sinaxar!.images),
                    const SizedBox(height: 20),
                  ],
                  ..._sections(entry.sinaxar!),
                  const SizedBox(height: 28),
                  _Attribution(sinaxar: entry.sinaxar!),
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

class _Commemoration extends StatelessWidget {
  const _Commemoration({required this.feast, required this.scale});

  final Feast feast;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final bool major = feast.rank == FeastRank.praznic ||
        feast.rank == FeastRank.cruceRosie;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (major)
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
          if (entry.liturgical.glas != null) ...<Widget>[
            const Divider(height: 22),
            Text(
              'Glasul ${entry.liturgical.glas}'
              '${entry.liturgical.voscreasna == null ? '' : ' · voscreasna ${entry.liturgical.voscreasna}'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (entry.override?.apostol != null ||
              entry.override?.evanghelie != null) ...<Widget>[
            const SizedBox(height: 6),
            if (entry.override?.apostol != null)
              Text('Ap. ${entry.override!.apostol}',
                  style: Theme.of(context).textTheme.bodySmall),
            if (entry.override?.evanghelie != null)
              Text('Ev. ${entry.override!.evanghelie}',
                  style: Theme.of(context).textTheme.bodySmall),
          ],
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

class _Attribution extends StatelessWidget {
  const _Attribution({required this.sinaxar});

  final Sinaxar sinaxar;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(TroitaSpacing.card),
        decoration: TroitaTheme.cardDecoration(
          color: TroitaColors.surfaceSubtle,
        ),
        child: Text(
          'Text preluat de pe ${sinaxar.attribution ?? 'calendar-ortodox.ro'}.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}
