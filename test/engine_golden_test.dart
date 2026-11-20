import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:troita/core/liturgical/fast_level.dart';
import 'package:troita/core/liturgical/liturgical_calendar.dart';
import 'package:troita/core/models/feast_calendar.dart';

/// The engine against test/golden/engine-2026-2030.json.
///
/// The same file is asserted by tool/engine_port.py (which writes it) and by
/// the website's TypeScript port (troita-web, `npm test`). A rule changed in
/// one engine and not the others fails here or there. Regenerate with
/// `python3 tool/engine_golden.py --write` after a deliberate rule change.
void main() {
  final Map<String, Object?> golden = jsonDecode(
    File('test/golden/engine-2026-2030.json').readAsStringSync(),
  ) as Map<String, Object?>;

  FastLevel? level(String? s) => switch (s) {
        'none' => FastLevel.none,
        'fish' => FastLevel.fish,
        'wineOil' => FastLevel.wineOil,
        'fast' => FastLevel.fast,
        'strict' => FastLevel.strict,
        _ => null,
      };

  test('Pascha 2026–2030', () {
    final Map<String, Object?> pascha =
        golden['pascha']! as Map<String, Object?>;
    pascha.forEach((String year, Object? iso) {
      final DateTime p = FeastCalendar.pascha(int.parse(year));
      final DateTime want = DateTime.parse(iso! as String);
      expect(DateTime(p.year, p.month, p.day), want, reason: year);
    });
  });

  test('every day 2026–2030: fast level, period, glas, voscreasna', () {
    final List<String> misses = <String>[];
    for (final Object? raw in golden['days']! as List<Object?>) {
      final List<Object?> row = raw! as List<Object?>;
      final DateTime date = DateTime.parse(row[0]! as String);
      final LiturgicalDay day = LiturgicalCalendar.dayFor(
        date,
        rank: FeastRank.parse(row[1] as String?),
        dezlegare: level(row[2] as String?),
      );
      final String got = <Object?>[
        day.fastLevel.name,
        day.period?.kind.name,
        day.glas,
        day.voscreasna,
      ].join('|');
      final String want = <Object?>[row[3], row[4], row[5], row[6]].join('|');
      if (got != want) misses.add('${row[0]}: got $got, want $want');
    }
    expect(misses, isEmpty, reason: misses.take(20).join('\n'));
  });
}
