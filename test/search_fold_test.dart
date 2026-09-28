import 'package:flutter_test/flutter_test.dart';
import 'package:troita/core/data/local_church_repository.dart';

/// Guards the one rule that exists twice.
///
/// `search_fold` is written by `hram._fold` in tool/build_seed.py and queried
/// with `LocalChurchRepository.foldForSearch`. If the two drift apart, search
/// simply stops matching — no exception, no log, just a search box that finds
/// nothing. These cases are the same ones the Python side is checked against.
void main() {
  group('foldForSearch', () {
    test('strips Romanian diacritics', () {
      expect(LocalChurchRepository.foldForSearch('Voroneț'), 'voronet');
      expect(LocalChurchRepository.foldForSearch('Mănăstirea Putna'),
          'manastirea putna');
      expect(LocalChurchRepository.foldForSearch('Sfântul Nicolae'),
          'sfantul nicolae');
      expect(LocalChurchRepository.foldForSearch('Ţepeş-Vodă'), 'tepes voda');
      expect(LocalChurchRepository.foldForSearch('Sfânta Cuvioasă Parascheva'),
          'sfanta cuvioasa parascheva');
    });

    test('is case insensitive', () {
      expect(LocalChurchRepository.foldForSearch('VORONET'), 'voronet');
      expect(LocalChurchRepository.foldForSearch('Voronet'),
          LocalChurchRepository.foldForSearch('voroneț'));
    });

    test('replaces punctuation with a single space', () {
      expect(LocalChurchRepository.foldForSearch('Biserica „Sf. Gheorghe"'),
          'biserica sf gheorghe');
      expect(LocalChurchRepository.foldForSearch('  spatii   multiple  '),
          'spatii multiple');
    });

    test('keeps digits', () {
      expect(LocalChurchRepository.foldForSearch('Aluniş 2'), 'alunis 2');
    });

    test('falls back to the original when nothing survives folding', () {
      // Cyrillic names come in with the border margin of the country extract.
      // Folding empties them, and an empty needle would match every row, so
      // both sides fall back to the lowercased original instead.
      expect(LocalChurchRepository.foldForSearch('Манастир'), 'манастир');
      expect(LocalChurchRepository.foldForSearch('   '), '');
    });
  });
}
