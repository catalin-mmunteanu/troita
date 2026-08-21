import 'package:flutter_test/flutter_test.dart';
import 'package:troita/core/models/feast_calendar.dart';

void main() {
  group('Orthodox Pascha', () {
    // Independently known dates. If this ever fails, every movable hram in the
    // app is wrong — Sfânta Treime, Izvorul Tămăduirii and Înălțarea Domnului
    // are all computed from here.
    const Map<int, String> known = <int, String>{
      2024: '2024-05-05',
      2025: '2025-04-20',
      2026: '2026-04-12',
      2027: '2027-05-02',
      2028: '2028-04-16',
      2030: '2030-04-28',
    };

    known.forEach((int year, String expected) {
      test('$year falls on $expected', () {
        final DateTime p = FeastCalendar.pascha(year);
        expect(
          '${p.year}-${p.month.toString().padLeft(2, '0')}-'
          '${p.day.toString().padLeft(2, '0')}',
          expected,
        );
      });
    });

    test('always lands on a Sunday', () {
      for (int y = 2024; y <= 2040; y++) {
        expect(FeastCalendar.pascha(y).weekday, DateTime.sunday,
            reason: 'Pascha $y');
      }
    });
  });

  group('movable feasts', () {
    test('Înălțarea Domnului is 39 days after Pascha, on a Thursday', () {
      final DateTime? d =
          FeastCalendar.resolve('movable:ascension', year: 2026);
      expect(d, DateTime(2026, 5, 21));
      expect(d!.weekday, DateTime.thursday);
    });

    test('Sfânta Treime is the Monday after Pentecost', () {
      final DateTime? d =
          FeastCalendar.resolve('movable:pentecost_monday', year: 2026);
      expect(d!.weekday, DateTime.monday);
      expect(d, DateTime(2026, 6, 1));
    });

    test('Izvorul Tămăduirii is Bright Friday', () {
      final DateTime? d =
          FeastCalendar.resolve('movable:bright_friday', year: 2026);
      expect(d!.weekday, DateTime.friday);
    });

    test('unknown movable key resolves to null rather than throwing', () {
      expect(FeastCalendar.resolve('movable:nonsense'), isNull);
    });
  });

  group('fixed feasts', () {
    test('parses MM-DD', () {
      expect(FeastCalendar.resolve('12-06', year: 2026), DateTime(2026, 12, 6));
    });

    test('rolls into next year once passed', () {
      final DateTime from = DateTime(2026, 12, 20);
      expect(FeastCalendar.next('12-06', from: from), DateTime(2027, 12, 6));
    });

    test('today counts as not yet passed', () {
      final DateTime from = DateTime(2026, 12, 6);
      expect(FeastCalendar.next('12-06', from: from), DateTime(2026, 12, 6));
      expect(FeastCalendar.isToday('12-06', from: from), isTrue);
      expect(FeastCalendar.daysUntil('12-06', from: from), 0);
    });

    test('garbage in, null out', () {
      expect(FeastCalendar.resolve(null), isNull);
      expect(FeastCalendar.resolve(''), isNull);
      expect(FeastCalendar.resolve('decembrie'), isNull);
      expect(FeastCalendar.resolve('13-99'), isNotNull); // DateTime normalises
    });
  });
}
