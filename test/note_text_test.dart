import 'package:flutter_test/flutter_test.dart';
import 'package:troita/core/data/note_text.dart';

void main() {
  test('drops the scraped page JavaScript, keeps the Romanian notes', () {
    expect(
      cleanNote('Sâmbăta Sf. Teodor - Pomenirea morților; "copyBtn"; '
          "window.location.href; 'text'; !isOpen; a,m; hs"),
      'Sâmbăta Sf. Teodor - Pomenirea morților',
    );
    expect(cleanNote('"copyBtn"; window.location.href'), isNull);
    expect(cleanNote(null), isNull);
  });

  test('a fixed date keeps only the notes that hold every year', () {
    expect(dateInvariantNote('Tedeum - Anul Nou; Harți. Nu se fac nunți'),
        'Tedeum - Anul Nou');
    expect(dateInvariantNote('Post. Nu se fac nunți'), isNull);
    expect(dateInvariantNote('Sâmbăta a IV-a din Post - Pomenirea morților'),
        isNull);
  });
}
