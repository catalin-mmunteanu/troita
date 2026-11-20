// GENERATED from troita-web/design/tokens.json by
// `node scripts/tokens.mjs --dart <this file>`. Do not edit by hand:
// change tokens.json in troita-web, regenerate, commit both.

import 'package:flutter/painting.dart';

/// Colours shared with the website (DESIGN.MD §4–§6). `…Dark` is the dark-mode value.
abstract final class TroitaTokens {
  static const Color parchment = Color(0xFFFDFBF7);
  static const Color parchmentDark = Color(0xFF141211);
  static const Color surface = Color(0xFFF5F0EB);
  static const Color surfaceDark = Color(0xFF1E1B18);
  static const Color ink = Color(0xFF1A1817);
  static const Color inkDark = Color(0xFFEDE6DA);
  static const Color umber = Color(0xFF574F4A);
  static const Color umberDark = Color(0xFFB5AA9C);
  static const Color oak = Color(0xFFE2D8C8);
  static const Color oakDark = Color(0xFF322A22);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFD4AF37);
  static const Color red = Color(0xFF8B1E1E);
  static const Color redDark = Color(0xFFE07B72);
  static const Color blue = Color(0xFF1A365D);
  static const Color blueDark = Color(0xFF8EB1DE);
  static const Color green = Color(0xFF1E4D2B);
  static const Color greenDark = Color(0xFF7DBE8E);
  static const Color purple = Color(0xFF3B0764);
  static const Color purpleDark = Color(0xFFC2A3E8);
  static const Color rosieBg = Color(0xFFFFF8F8);
  static const Color rosieBgDark = Color(0xFF2A1A18);
  static const Color rosieBorder = Color(0xFFF0C8C8);
  static const Color rosieBorderDark = Color(0xFF4A2A26);
  static const Color rosieTitle = Color(0xFF8B1E1E);
  static const Color rosieTitleDark = Color(0xFFF08C82);
  static const Color albastraBg = Color(0xFFF4F6FA);
  static const Color albastraBgDark = Color(0xFF19202B);
  static const Color albastraBorder = Color(0xFFC9D4E6);
  static const Color albastraBorderDark = Color(0xFF2C3A50);
  static const Color albastraTitle = Color(0xFF1A365D);
  static const Color albastraTitleDark = Color(0xFF8EB1DE);
  static const Color bPostBg = Color(0xFFEFE5EC);
  static const Color bPostBgDark = Color(0xFF2A1E2C);
  static const Color bPostFg = Color(0xFF3B0764);
  static const Color bPostFgDark = Color(0xFFD2B6E6);
  static const Color bFishBg = Color(0xFFE2ECEC);
  static const Color bFishBgDark = Color(0xFF17262A);
  static const Color bFishFg = Color(0xFF1D5468);
  static const Color bFishFgDark = Color(0xFF8EC3D2);
  static const Color bOilBg = Color(0xFFECE8CF);
  static const Color bOilBgDark = Color(0xFF25241A);
  static const Color bOilFg = Color(0xFF55500F);
  static const Color bOilFgDark = Color(0xFFCFC88A);
  static const Color bStrictBg = Color(0xFF3B0764);
  static const Color bStrictBgDark = Color(0xFFD2B6E6);
  static const Color bStrictFg = Color(0xFFFDFBF7);
  static const Color bStrictFgDark = Color(0xFF141211);
  static const Color bNoneBg = Color(0xFFF5EACB);
  static const Color bNoneBgDark = Color(0xFF2C2314);
  static const Color bNoneFg = Color(0xFF7A3B0C);
  static const Color bNoneFgDark = Color(0xFFE8C27E);
  static const Color onRed = Color(0xFFFDFBF7);
  static const Color onRedDark = Color(0xFF141211);
}

/// App-only colours (no web counterpart).
abstract final class TroitaAppTokens {
  static const Color today = Color(0xFF5C1321);
  static const Color todayDark = Color(0xFFE07B72);
  static const Color onToday = Color(0xFFFDFBF7);
  static const Color onTodayDark = Color(0xFF141211);
}

/// Font families (DESIGN.MD §3). The first entry is the bundled font; the rest
/// are fallbacks.
abstract final class TroitaTokenFonts {
  static const String display = 'Literata';
  static const String ui = 'Alegreya Sans';
  static const String text = 'Plus Jakarta Sans';
  static const String mono = 'JetBrains Mono';
}

/// Corner radii (DESIGN.MD §5: 4px by default, 8px at most).
abstract final class TroitaTokenRadius {
  static const double xs = 2.0;
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double max = 8.0;

  /// The liturgical-colour bar on the left of a commemoration card.
  static const double liturgicalBar = 3.0;
}
