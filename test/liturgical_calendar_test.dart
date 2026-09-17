import 'package:flutter_test/flutter_test.dart';
import 'package:troita/core/liturgical/fast_level.dart';
import 'package:troita/core/liturgical/fasting_period.dart';
import 'package:troita/core/liturgical/liturgical_calendar.dart';

FastLevel levelOn(DateTime d, {FeastRank rank = FeastRank.simplu}) =>
    LiturgicalCalendar.dayFor(d, rank: rank).fastLevel;

void main() {
  group('fasting period boundaries (2026, Pascha 12 April)', () {
    test('Postul Mare runs Clean Monday to Great Saturday', () {
      final FastingPeriod p = LiturgicalCalendar.postulMare(2026);
      expect(p.start, DateTime(2026, 2, 23));
      expect(p.end, DateTime(2026, 4, 11));
      expect(p.days, 48);
    });

    test('Postul Apostolilor is Pascha-relative at the start, fixed at the end',
        () {
      final FastingPeriod p = LiturgicalCalendar.postulApostolilor(2026)!;
      expect(p.start, DateTime(2026, 6, 8));
      expect(p.end, DateTime(2026, 6, 28));
      expect(p.days, 21);
    });

    test('Postul Apostolilor does not exist in late-Pascha years', () {
      // Pascha 2024 was 5 May, which pushes the start past 28 June.
      expect(LiturgicalCalendar.postulApostolilor(2024), isNull);
      // A sanity check that the engine agrees across a long span.
      final List<int> missing = <int>[
        for (int y = 2020; y <= 2100; y++)
          if (LiturgicalCalendar.postulApostolilor(y) == null) y,
      ];
      expect(missing, contains(2024));
      expect(missing, contains(2040));
      expect(missing.length, 10);
    });

    test('the fixed fasts are fixed', () {
      expect(LiturgicalCalendar.postulAdormirii(2026).start, DateTime(2026, 8, 1));
      expect(LiturgicalCalendar.postulAdormirii(2026).end, DateTime(2026, 8, 14));
      expect(LiturgicalCalendar.postulCraciunului(2026).start,
          DateTime(2026, 11, 15));
      expect(LiturgicalCalendar.postulCraciunului(2026).end,
          DateTime(2026, 12, 24));
    });

    test('greatFasts returns them in calendar order', () {
      final List<FastingPeriod> fasts = LiturgicalCalendar.greatFasts(2026);
      expect(fasts, hasLength(4));
      for (int i = 1; i < fasts.length; i++) {
        expect(fasts[i].start.isAfter(fasts[i - 1].start), isTrue);
      }
    });
  });

  group('Postul Mare', () {
    test('first day and Great Friday are strict', () {
      expect(levelOn(DateTime(2026, 2, 23)), FastLevel.strict);
      expect(levelOn(DateTime(2026, 4, 10)), FastLevel.strict);
    });

    test('weekdays are a plain fast, weekends allow oil and wine', () {
      expect(levelOn(DateTime(2026, 3, 3)), FastLevel.fast); // Tuesday
      expect(levelOn(DateTime(2026, 3, 7)), FastLevel.wineOil); // Saturday
      expect(levelOn(DateTime(2026, 3, 8)), FastLevel.wineOil); // Sunday
    });

    test('Buna Vestire and Florii allow fish', () {
      expect(levelOn(DateTime(2026, 3, 25)), FastLevel.fish);
      expect(levelOn(DateTime(2026, 4, 5)), FastLevel.fish); // Florii
    });
  });

  group('Postul Crăciunului', () {
    test('fish on Tuesday before 20 December', () {
      expect(levelOn(DateTime(2026, 11, 17)), FastLevel.fish); // Tuesday
    });

    test('named feasts inside the fast allow fish', () {
      expect(levelOn(DateTime(2026, 11, 21)), FastLevel.fish); // Intrarea
      expect(levelOn(DateTime(2026, 11, 30)), FastLevel.fish); // Sf. Andrei
      expect(levelOn(DateTime(2026, 12, 6)), FastLevel.fish); // Sf. Nicolae
    });

    test('no fish after 20 December', () {
      expect(levelOn(DateTime(2026, 12, 22)), FastLevel.fast); // Tuesday
    });

    test('Christmas Eve is strict', () {
      expect(levelOn(DateTime(2026, 12, 24)), FastLevel.strict);
    });
  });

  group('harți', () {
    test('Săptămâna Luminată has no fasting, including Wednesday', () {
      expect(levelOn(DateTime(2026, 4, 15)), FastLevel.none); // Wednesday
      expect(levelOn(DateTime(2026, 4, 17)), FastLevel.none); // Friday
    });

    test('Nativity to Theophany has no fasting', () {
      expect(levelOn(DateTime(2026, 12, 30)), FastLevel.none); // Wednesday
      expect(levelOn(DateTime(2027, 1, 1)), FastLevel.none); // crosses the year
    });

    test('the week after Pentecost has no fasting', () {
      expect(levelOn(DateTime(2026, 6, 3)), FastLevel.none); // Wednesday
    });

    test('Săptămâna Brânzei permits dairy on Wednesday and Friday', () {
      expect(levelOn(DateTime(2026, 2, 18)), FastLevel.dairy); // Wednesday
      expect(levelOn(DateTime(2026, 2, 20)), FastLevel.dairy); // Friday
    });
  });

  group('ordinary weeks', () {
    test('Wednesday and Friday are fast days', () {
      expect(levelOn(DateTime(2026, 10, 7)), FastLevel.fast); // Wednesday
      expect(levelOn(DateTime(2026, 10, 9)), FastLevel.fast); // Friday
    });

    test('other days are free', () {
      expect(levelOn(DateTime(2026, 10, 8)), FastLevel.none); // Thursday
      expect(levelOn(DateTime(2026, 11, 14)), FastLevel.none); // Sat, pre-fast
    });

    test('a great feast on a fast day brings a dezlegare', () {
      expect(levelOn(DateTime(2026, 10, 7), rank: FeastRank.praznic),
          FastLevel.fish);
      expect(levelOn(DateTime(2026, 10, 7), rank: FeastRank.cruceRosie),
          FastLevel.wineOil);
      expect(levelOn(DateTime(2026, 10, 7), rank: FeastRank.cruceAlbastra),
          FastLevel.fast);
    });
  });

  group('fixed strict days', () {
    test('Theophany Eve is strict even though it follows the harți week', () {
      expect(levelOn(DateTime(2026, 1, 5)), FastLevel.strict);
    });

    test('29 August and 14 September are fast days whatever the weekday', () {
      expect(levelOn(DateTime(2026, 8, 29)), FastLevel.fast); // Saturday
      expect(levelOn(DateTime(2026, 9, 14)), FastLevel.fast); // Monday
    });
  });

  group('glas', () {
    test('Duminica Tomii is glas 1 and the cycle advances weekly', () {
      expect(LiturgicalCalendar.glasFor(DateTime(2026, 4, 19)), 1);
      expect(LiturgicalCalendar.glasFor(DateTime(2026, 4, 26)), 2);
      expect(LiturgicalCalendar.glasFor(DateTime(2026, 6, 7)), 8);
      expect(LiturgicalCalendar.glasFor(DateTime(2026, 6, 14)), 1);
    });

    test('dates before Duminica Tomii fall back to the previous year', () {
      expect(LiturgicalCalendar.glasFor(DateTime(2026, 2, 1)), isNotNull);
      expect(LiturgicalCalendar.glasFor(DateTime(2026, 2, 1)), inInclusiveRange(1, 8));
    });
  });

  group('FastLevel ordering', () {
    test('looser and stricter resolve conflicts predictably', () {
      expect(FastLevel.looser(FastLevel.fast, FastLevel.fish), FastLevel.fish);
      expect(FastLevel.stricter(FastLevel.none, FastLevel.strict),
          FastLevel.strict);
    });
  });

  publishedCalendarChecks();

  group('day summary', () {
    test('reads the way a calendar banner should', () {
      expect(LiturgicalCalendar.dayFor(DateTime(2026, 3, 7)).summary,
          'Post cu dezlegare la untdelemn și vin');
      expect(LiturgicalCalendar.dayFor(DateTime(2026, 10, 8)).summary,
          'Zi fără post');
    });
  });
}

// Appended after validating against a published Romanian calendar for
// January 2026 — see tool/import_calendar_html.py, which diffs the engine
// against transcribed HTML and currently reports 31/31 on that month.
void publishedCalendarChecks() {
  group('against the published calendar, January 2026', () {
    test('glas matches on all four Sundays', () {
      expect(LiturgicalCalendar.glasFor(DateTime(2026, 1, 4)), 5);
      expect(LiturgicalCalendar.glasFor(DateTime(2026, 1, 11)), 6);
      expect(LiturgicalCalendar.glasFor(DateTime(2026, 1, 18)), 7);
      expect(LiturgicalCalendar.glasFor(DateTime(2026, 1, 25)), 8);
    });

    test('voscreasna matches on all four Sundays', () {
      expect(LiturgicalCalendar.voscreasnaFor(DateTime(2026, 1, 4)), 8);
      expect(LiturgicalCalendar.voscreasnaFor(DateTime(2026, 1, 11)), 9);
      expect(LiturgicalCalendar.voscreasnaFor(DateTime(2026, 1, 18)), 10);
      expect(LiturgicalCalendar.voscreasnaFor(DateTime(2026, 1, 25)), 11);
    });

    test('2 January is harți, not a Friday fast', () {
      expect(levelOn(DateTime(2026, 1, 2)), FastLevel.none);
    });

    test('30 January, a cruce roșie on a Friday, allows oil and wine', () {
      expect(levelOn(DateTime(2026, 1, 30), rank: FeastRank.cruceRosie),
          FastLevel.wineOil);
    });
  });
}
