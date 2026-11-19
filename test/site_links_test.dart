import 'package:flutter_test/flutter_test.dart';
import 'package:troita/app/site_links.dart';

void main() {
  test('a day has the address of its place on its month page', () {
    expect(SiteLinks.day(DateTime(2026, 11, 21)),
        'https://www.troita.ro/calendar-ortodox/2026/noiembrie#ziua-21');
  });

  test('links back to a day, a month and today', () {
    expect(
      SiteLinks.dateOf(Uri.parse(
          'https://www.troita.ro/calendar-ortodox/2026/noiembrie#ziua-21')),
      DateTime(2026, 11, 21),
    );
    expect(
      SiteLinks.dateOf(
          Uri.parse('https://troita.ro/calendar-ortodox/2028/aprilie')),
      DateTime(2028, 4, 1),
    );
    expect(
      SiteLinks.dateOf(Uri.parse('https://www.troita.ro/azi'),
          now: DateTime(2026, 11, 19, 15)),
      DateTime(2026, 11, 19),
    );
  });

  test('anything else is not a day', () {
    expect(SiteLinks.dateOf(Uri.parse('https://www.troita.ro/posturi')), isNull);
    expect(
        SiteLinks.dateOf(
            Uri.parse('https://www.troita.ro/calendar-ortodox/2026/brumar')),
        isNull);
    expect(
        SiteLinks.dateOf(Uri.parse(
            'https://www.troita.ro/calendar-ortodox/2026/februarie#ziua-30')),
        isNull);
    expect(
        SiteLinks.dateOf(
            Uri.parse('https://example.com/calendar-ortodox/2026/mai')),
        isNull);
  });
}
