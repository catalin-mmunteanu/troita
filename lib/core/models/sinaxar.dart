import 'dart:convert';

/// The full commemoration text for a fixed date, bundled from the scrape.
class Sinaxar {
  const Sinaxar({
    required this.monthDay,
    required this.text,
    this.sections = const <String>[],
    this.images = const <String>[],
    this.sourceUrl,
    this.attribution,
  });

  final String monthDay;

  /// The whole day as plain text.
  final String text;

  /// One entry per commemoration — the source separates them with
  /// "Tot în această zi, pomenirea…", which makes for natural paragraphs.
  final List<String> sections;

  /// Asset filenames under `assets/sinaxar/<MM-DD>/`.
  final List<String> images;

  final String? sourceUrl;
  final String? attribution;

  bool get isEmpty => text.trim().isEmpty;

  /// First paragraph, for a preview line in the day list.
  String get lead {
    final String first = sections.isNotEmpty ? sections.first : text;
    final int stop = first.indexOf('\n');
    return (stop == -1 ? first : first.substring(0, stop)).trim();
  }

  static List<String> _decodeList(Object? raw) {
    if (raw == null) return const <String>[];
    final Object? decoded = jsonDecode(raw as String);
    if (decoded is! List) return const <String>[];
    return decoded.map((Object? e) => '$e').toList(growable: false);
  }

  factory Sinaxar.fromRow(Map<String, Object?> row) => Sinaxar(
        monthDay: row['month_day']! as String,
        text: (row['text'] as String?) ?? '',
        sections: _decodeList(row['sections']),
        images: _decodeList(row['images']),
        sourceUrl: row['source_url'] as String?,
        attribution: row['attribution'] as String?,
      );
}

/// A published per-day override, keyed by year because it moves with Pascha.
class DayOverride {
  const DayOverride({
    required this.monthDay,
    this.fastLevel,
    this.notes,
    this.glas,
    this.voscreasna,
    this.sundayTitle,
    this.sundaySubtitle,
    this.apostol,
    this.evanghelie,
  });

  final String monthDay;

  /// Raw level name as published — `fish`, `wineOil`, `fast`…
  final String? fastLevel;
  final String? notes;
  final int? glas;
  final int? voscreasna;
  final String? sundayTitle;
  final String? sundaySubtitle;
  final String? apostol;
  final String? evanghelie;

  factory DayOverride.fromRow(Map<String, Object?> row) => DayOverride(
        monthDay: row['month_day']! as String,
        fastLevel: row['fast_level'] as String?,
        notes: row['notes'] as String?,
        glas: (row['glas'] as num?)?.toInt(),
        voscreasna: (row['voscreasna'] as num?)?.toInt(),
        sundayTitle: row['sunday_title'] as String?,
        sundaySubtitle: row['sunday_subtitle'] as String?,
        apostol: row['apostol'] as String?,
        evanghelie: row['evanghelie'] as String?,
      );
}
