/// Romanian number agreement.
///
/// Romanian inserts "de" before a noun when the number's last two digits fall
/// outside 1–19: "12 zile" but "20 de zile", "101 zile" but "120 de zile".
/// Getting this wrong is immediately obvious to a native reader, and this app
/// counts days constantly.
String plural(int n, String singular, String plural_) {
  if (n == 1) return '1 $singular';
  final int lastTwo = n % 100;
  final bool needsDe = lastTwo == 0 || lastTwo > 19;
  return needsDe ? '$n de $plural_' : '$n $plural_';
}

String days(int n) => plural(n, 'zi', 'zile');

/// "peste 12 zile" / "mâine" / "astăzi"
String inDays(int n) => switch (n) {
      0 => 'astăzi',
      1 => 'mâine',
      2 => 'poimâine',
      _ => 'peste ${days(n)}',
    };

/// "mai este o zi" / "mai sunt 20 de zile"
String remaining(int n) => switch (n) {
      0 => 'ultima zi',
      1 => 'mai este o zi',
      _ => 'mai sunt ${days(n)}',
    };
