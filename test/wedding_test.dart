import 'package:flutter_test/flutter_test.dart';
import 'package:troita/core/liturgical/liturgical_calendar.dart';

/// Readable examples of the wedding rule; the golden file covers every day.
void main() {
  WeddingBar? on(int y, int m, int d) => LiturgicalCalendar.cununie(DateTime(y, m, d));

  test('the four fasts', () {
    expect(on(2026, 12, 1), WeddingBar.post); // Postul Crăciunului
    expect(on(2026, 8, 10), WeddingBar.post); // Postul Adormirii
  });

  test('Christmas to Theophany, both ends of the year', () {
    expect(on(2026, 12, 25), WeddingBar.craciunBoboteaza);
    expect(on(2027, 1, 6), WeddingBar.craciunBoboteaza);
    expect(on(2027, 1, 9), isNull); // first Saturday after
  });

  test('Bright Week and the Cheese Week (Pascha 2027: 2 May)', () {
    expect(on(2027, 5, 8), WeddingBar.saptamanaLuminata);
    expect(on(2027, 3, 13), WeddingBar.saptamanaBranzei);
  });

  test('praznice and their eves', () {
    expect(on(2027, 9, 7), WeddingBar.praznic); // ajunul Nașterii Maicii Domnului
    expect(on(2027, 6, 10), WeddingBar.praznic); // Înălțarea (P+39)
  });

  test('Wednesday and Friday, except in harți', () {
    expect(on(2026, 10, 14), WeddingBar.miercuriVineri); // Wednesday
    expect(on(2027, 6, 23), WeddingBar.post); // inside the Apostles' fast
    expect(on(2026, 10, 17), isNull); // a Saturday in October
  });
}
