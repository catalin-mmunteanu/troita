import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troita/app/theme.dart';
import 'package:troita/core/liturgical/fast_level.dart';

/// The numeral describes the day; the cross describes the commemoration.
/// They are separate signals and a Sunday can carry a black cross.
void main() {
  Color colour(FeastRank rank, {bool sunday = false, bool inMonth = true}) =>
      calendarDayColor(rank: rank, isSunday: sunday, inMonth: inMonth);

  group('day numeral', () {
    test('red-cross ranks are red on any weekday', () {
      expect(colour(FeastRank.praznic), TroitaColors.feastRed);
      expect(colour(FeastRank.cruceRosie), TroitaColors.feastRed);
    });

    test('black cross and ordinary days are black on a weekday', () {
      expect(colour(FeastRank.cruceAlbastra), TroitaColors.feastBlue);
      expect(colour(FeastRank.simplu), TroitaColors.calendarInk);
    });

    test('every Sunday is red, whatever it commemorates', () {
      for (final FeastRank rank in FeastRank.values) {
        expect(colour(rank, sunday: true), TroitaColors.feastRed,
            reason: 'Sunday with rank $rank');
      }
    });

    test('a Sunday carrying a black cross still has a red numeral', () {
      // 11 January 2026 — Sf. Cuv. Teodosie, cruce neagră, on a Sunday.
      // Red digits because it is Sunday; the commemoration keeps its black
      // cross. Four such Sundays fall in 2026.
      expect(colour(FeastRank.cruceAlbastra, sunday: true),
          TroitaColors.feastRed);
      // ...while the cross itself stays black.
      expect(feastRankColor(FeastRank.cruceAlbastra), TroitaColors.feastBlue);
    });

    test('a red-cross Sunday is red for both reasons', () {
      // 6 December 2026 — Sf. Ier. Nicolae falls on a Sunday.
      expect(colour(FeastRank.cruceRosie, sunday: true),
          TroitaColors.feastRed);
      expect(feastRankColor(FeastRank.cruceRosie), TroitaColors.feastRed);
    });
  });

  group('cross colour follows rank, never the weekday', () {
    test('the two red ranks share the print red', () {
      expect(feastRankColor(FeastRank.praznic), TroitaColors.feastRed);
      expect(feastRankColor(FeastRank.cruceRosie), TroitaColors.feastRed);
    });

    test('cruce neagră is black — the name is the colour', () {
      expect(feastRankColor(FeastRank.cruceAlbastra), TroitaColors.feastBlue);
    });

    test('labels read as the printed calendar names them', () {
      expect(FeastRank.praznic.label, 'Praznic Împărătesc');
      expect(FeastRank.cruceRosie.label, 'Cruce Roșie');
      expect(FeastRank.cruceAlbastra.label, 'Cruce Albastră');
    });
  });

  test('days outside the shown month are muted regardless', () {
    expect(colour(FeastRank.praznic, sunday: true, inMonth: false),
        TroitaColors.muted);
  });
}
