import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:troita/core/models/name_days.dart';

void main() {
  final NameDays nd =
      NameDays.parse(File('assets/data/name_days.json').readAsStringSync());

  test('Andrei is on 30 November', () {
    expect(nd.namesOn(DateTime(2026, 11, 30)), contains('Andrei'));
    expect(nd.feastsFor('Andrei').single.dateIn(2027), DateTime(2027, 11, 30));
  });

  test('Maria has two days, 15 August first', () {
    final List<NameFeast> f = nd.feastsFor('Maria');
    expect(f.length, greaterThanOrEqualTo(2));
    expect(f.first.dateIn(2026), DateTime(2026, 8, 15));
    expect(nd.notes['Maria'], isNotNull);
  });

  test('Gheorghe moves with the feast out of Holy Week (2030)', () {
    expect(nd.namesOn(DateTime(2030, 4, 29)), contains('Gheorghe'));
    expect(nd.namesOn(DateTime(2030, 4, 23)), isNot(contains('Gheorghe')));
  });

  test('Florii names follow Pascha', () {
    // Pascha 2027 is 2 May, so Florii is 25 April.
    expect(nd.on(DateTime(2027, 4, 25)).any((NameFeast f) => f.feastDay == 'movable:palm_sunday'),
        isTrue);
  });

  test('no cedilla diacritics', () {
    for (final String n in nd.allNames) {
      expect(n.contains(RegExp('[şţŞŢ]')), isFalse, reason: n);
    }
  });
}
