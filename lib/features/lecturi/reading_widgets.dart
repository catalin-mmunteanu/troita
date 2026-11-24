import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/models/lecturi.dart';
import '../../core/models/sinaxar.dart';

// What is read: the sinaxar and the Liturgy readings. Shared by the Lecturi
// tab and the screen the day buttons open, so the text looks the same
// wherever it is read.

/// "Apostolul și Evanghelia": the Liturgy readings of the day, in full.
///
/// From assets/data/lecturi.json (which pericope) and biblia_nt.json (the
/// text of the 1988 Synodal edition), the same files troita.ro reads. Follows
/// the page's text-size control, like the sinaxar.
class ReadingsCard extends StatelessWidget {
  const ReadingsCard({
    super.key,
    required this.lectura,
    required this.biblia,
    required this.scale,
    this.gospelFirst = false,
  });

  final LecturaZi lectura;
  final BibliaNT biblia;
  final double scale;

  /// The Evanghelie tab reads the Gospel first; the Liturgy order is the
  /// Apostol first.
  final bool gospelFirst;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<Widget> readings = <Widget>[
      if (lectura.apostolCite != null)
        _reading(context, 'Apostolul', lectura.apostolCite!,
            biblia.text(lectura.apostol)),
      if (lectura.evanghelieCite != null)
        _reading(context, 'Evanghelia', lectura.evanghelieCite!,
            biblia.text(lectura.evanghelie)),
    ];
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
            ...(gospelFirst ? readings.reversed : readings),
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

/// The sinaxar of a day in full: icons, ornament, sections.
class SinaxarText extends StatelessWidget {
  const SinaxarText({super.key, required this.sinaxar, required this.scale});

  final Sinaxar sinaxar;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final List<String> parts =
        sinaxar.sections.isEmpty ? <String>[sinaxar.text] : sinaxar.sections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (sinaxar.images.isNotEmpty) ...<Widget>[
          SaintImages(names: sinaxar.images),
          const SizedBox(height: 20),
        ],
        const Ornament(),
        const SizedBox(height: 20),
        for (final String part in parts)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              part,
              textAlign: TextAlign.justify,
              style: TroitaCalendarText.commemoration.copyWith(
                fontSize: 16.5 * scale,
                // Generous leading: this is long-form reading, not a UI label.
                height: 1.65,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
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
class SaintImages extends StatelessWidget {
  const SaintImages({super.key, required this.names});

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
class Ornament extends StatelessWidget {
  const Ornament({super.key});

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
