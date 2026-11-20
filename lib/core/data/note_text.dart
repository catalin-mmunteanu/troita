/// Clean-up for notes scraped from a published calendar.
///
/// The same rules run in the data pipeline (tool/build_seed.py: clean_notes,
/// date_invariant_note) and in the website's export. They run here too so a
/// seed built before the pipeline learned them still reads correctly.
library;

// Code-like characters: the last day of each month once carried the source
// page's JavaScript (analytics snippets, button handlers) in its notes.
// \x22 and \x27 are the two quote characters.
final RegExp _junk = RegExp(
  r'[\x22\x27\[\]{}=|\\/<>]|window|script|\bpdf',
  caseSensitive: false,
);

/// Drops the segments of [raw] that are not Romanian text. Real notes start
/// with a capital ("Post", "Zi aliturgică"); leftovers like "!isOpen" or "a,m"
/// never do.
String? cleanNote(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final List<String> keep = raw
      .split(';')
      .map((String p) => p.trim())
      .where((String p) =>
          p.length > 2 &&
          p[0] == p[0].toUpperCase() &&
          p[0] != p[0].toLowerCase() &&
          !_junk.hasMatch(p))
      .toList();
  return keep.isEmpty ? null : keep.join('; ');
}

/// The part of a fixed-date feast's scraped note that is true every year.
///
/// The note was read off one particular year: "Post", "Dezlegare la pește",
/// "Nu se fac nunți", "Sâmbăta a IV-a din Post" depend on where the date fell
/// that year, and live per year in day_overrides. Only the Tedeum notes (Anul
/// Nou, Ziua Națională…) belong to the date itself.
String? dateInvariantNote(String? raw) {
  final String? cleaned = cleanNote(raw);
  if (cleaned == null) return null;
  final List<String> keep = cleaned
      .split('; ')
      .where((String p) => p.startsWith('Tedeum'))
      .toList();
  return keep.isEmpty ? null : keep.join('; ');
}
