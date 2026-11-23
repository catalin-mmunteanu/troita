import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:troita/core/models/lecturi.dart';

void main() {
  final Lecturi lecturi =
      Lecturi.parse(File('assets/data/lecturi.json').readAsStringSync());
  final BibliaNT biblia =
      BibliaNT.parse(File('assets/data/biblia_nt.json').readAsStringSync());

  test('a Sunday after Pentecost carries its number and both readings', () {
    final LecturaZi day = lecturi.on(DateTime(2026, 11, 29))!;
    expect(day.title, 'Duminica a XXX-a după Rusalii');
    expect(day.evanghelieCite, 'Luca 18, 18-27');
    expect(day.apostolCite, 'Coloseni 3, 12-16');
  });

  test('Great Lent weekdays have no Liturgy readings', () {
    final LecturaZi day = lecturi.on(DateTime(2027, 3, 17))!;
    expect(day.hasGospel, isFalse);
    expect(day.none, contains('Postul Mare'));
  });

  test('Buna Vestire has its readings even in Great Lent', () {
    final LecturaZi day = lecturi.on(DateTime(2026, 3, 25))!;
    expect(day.evanghelieCite, 'Luca 1, 24-38');
  });

  test('the text of a pericope comes verse by verse from the 1988 edition', () {
    final LecturaZi day = lecturi.on(DateTime(2026, 11, 23))!;
    final List<Verse> verses = biblia.text(day.evanghelie);
    expect(day.evanghelieCite, 'Luca 17, 20-25');
    expect(verses.length, 6);
    expect(verses.first.chapter, 17);
    expect(verses.first.number, 20);
    expect(biblia.source, contains('1988'));
  });

  test('every day 2026-2030 is there, with a Gospel unless marked', () {
    for (DateTime d = DateTime(2026, 1, 1);
        d.isBefore(DateTime(2031, 1, 1));
        d = DateTime(d.year, d.month, d.day + 1)) {
      final LecturaZi? day = lecturi.on(d);
      expect(day, isNotNull, reason: '$d');
      expect(day!.hasGospel || day.none != null, isTrue, reason: '$d');
      if (day.hasGospel) {
        expect(biblia.text(day.evanghelie), isNotEmpty, reason: '$d');
      }
    }
  });
}
