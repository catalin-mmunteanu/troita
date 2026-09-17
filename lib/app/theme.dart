import 'package:flutter/material.dart';

import '../core/liturgical/fast_level.dart';

/// Design tokens, taken from the Figma file rather than invented.
///
/// The file defines no Figma variables, so these are the raw fills lifted from
/// `acasa-calendar` (2:112). Everything that follows is derived from them —
/// screens should reference these names, never a hex literal.
abstract final class TroitaColors {
  /// Page background — warm off-white paper.
  static const Color paper = Color(0xFFFCFAF2);

  /// Cards, bottom nav, input fields.
  static const Color surface = Color(0xFFF6F1E5);

  /// A slightly lighter surface, used for inactive date badges.
  static const Color surfaceSubtle = Color(0xFFFAF7EF);

  /// Hairline borders around every card and the top of the bottom nav.
  static const Color border = Color(0xFFEADFC9);

  /// Highlighted surface — feast days, the fasting banner, active date badges.
  static const Color accentSurface = Color(0xFFF5EFCF);

  /// Gold, used only as a border or a marker. Never as a text colour.
  static const Color gold = Color(0xFFC59B27);

  /// Byzantine burgundy. Primary, and the fill behind today's date.
  static const Color burgundy = Color(0xFF5C1321);

  /// Body text.
  static const Color ink = Color(0xFF261E14);

  /// Secondary text, inactive nav labels, days outside the current month.
  static const Color muted = Color(0xFF6B5E4F);

  static const Color onBurgundy = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------- calendar
  //
  // Romanian printed calendars use a colour convention people have read their
  // whole lives, and it is not decorative — the rank names *are* the colours.
  // "Cruce roșie" and "cruce neagră" mean red cross and black cross. Rendering
  // both in the brand burgundy destroys the only distinction between them.
  //
  // So the calendar keeps its own semantic palette, separate from the brand
  // chrome: red for feasts and Sundays, black for ordinary days.

  /// Feasts with a red cross, and every Sunday. The red of a printed calendar —
  /// deeper and less orange than a UI alert red.
  static const Color feastRed = Color(0xFFC1272D);

  /// Ordinary weekday numerals.
  static const Color calendarInk = Color(0xFF1B1B1B);

  /// Cruce albastră. Printed black in some calendars and blue in others; it is
  /// the same rank, so this is purely which convention we follow. Switch it to
  /// [calendarInk] to print black instead.
  static const Color feastBlue = Color(0xFF1F4E8C);

  /// Romanian saints. The source markup singles them out with `class="rom"`,
  /// and printed calendars usually set them apart too.
  static const Color romanianSaint = Color(0xFF8C2F2A);
}

abstract final class TroitaRadius {
  /// Day cells, icon buttons, date badges.
  static const double small = 12;

  /// Feast cards, list rows.
  static const double medium = 16;

  /// The calendar card.
  static const double large = 20;

  /// Sheets and the phone frame itself.
  static const double xlarge = 32;

  static const BorderRadius smallAll = BorderRadius.all(Radius.circular(small));
  static const BorderRadius mediumAll =
      BorderRadius.all(Radius.circular(medium));
  static const BorderRadius largeAll = BorderRadius.all(Radius.circular(large));
}

abstract final class TroitaSpacing {
  /// Horizontal page padding.
  static const double page = 20;
  static const double card = 16;
  static const double gap = 12;
  static const double listGap = 8;
  static const double gridGap = 6;
}

/// Font families as named in Figma.
///
/// Both are OFL and available from Google Fonts. They are **not yet declared in
/// pubspec.yaml** — see `assets/fonts/README.md`. Referencing an undeclared
/// family is safe: Flutter falls back to the platform default and logs a
/// warning rather than failing, so the app runs today and upgrades the moment
/// the files are dropped in.
abstract final class TroitaFonts {
  /// Headings, and the calendar itself. Variable font, drawn in Figma with
  /// SOFT 0 / WONK 1.
  static const String display = 'Fraunces';

  /// UI chrome — buttons, labels, settings, anything that reads as software.
  static const String text = 'Geist';

  /// Generic serif, resolved by the platform (Noto Serif on Android).
  ///
  /// This is what makes the serif calendar visible *today*, before anyone
  /// downloads Fraunces: the family falls through to the platform serif rather
  /// than to the default sans, and upgrades silently once the .ttf lands.
  static const List<String> serifFallback = <String>['serif', 'Georgia'];
}

/// Type for the calendar grid and the commemorations.
///
/// Romanian church calendars are set in serif, and that is most of what makes
/// one *look* like a church calendar rather than an app screen. The chrome
/// around it stays sans — the distinction is deliberate, not an inconsistency.
abstract final class TroitaCalendarText {
  /// Day numerals in the month grid.
  static const TextStyle numeral = TextStyle(
    fontFamily: TroitaFonts.display,
    fontFamilyFallback: TroitaFonts.serifFallback,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.0,
  );

  /// Lu / Ma / Mi column headers.
  static const TextStyle weekday = TextStyle(
    fontFamily: TroitaFonts.display,
    fontFamilyFallback: TroitaFonts.serifFallback,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  /// Saint and feast names.
  static const TextStyle commemoration = TextStyle(
    fontFamily: TroitaFonts.display,
    fontFamilyFallback: TroitaFonts.serifFallback,
    fontSize: 14.5,
    height: 1.4,
    color: TroitaColors.calendarInk,
  );

  /// The date on a feast card badge.
  static const TextStyle badgeDay = TextStyle(
    fontFamily: TroitaFonts.display,
    fontFamilyFallback: TroitaFonts.serifFallback,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.0,
  );
}

/// Semantic colour for a day's fasting state — the calendar dots, the banner,
/// and the Posturi rows all read from here so they cannot drift apart.
Color fastLevelColor(FastLevel level) => switch (level) {
      FastLevel.none => TroitaColors.muted,
      FastLevel.dairy => TroitaColors.gold,
      FastLevel.fish => TroitaColors.gold,
      FastLevel.wineOil => TroitaColors.gold,
      FastLevel.fast => TroitaColors.burgundy,
      FastLevel.strict => TroitaColors.burgundy,
    };

/// Icon for a day's fasting state.
///
/// Paired with a written label everywhere it appears. An icon alone is not
/// enough for the audience this app is for — the published calendars use a
/// small fish glyph, but they also spell out "Dezlegare la pește" next to it,
/// and so should we.
IconData fastLevelIcon(FastLevel level) => switch (level) {
      FastLevel.none => Icons.restaurant_outlined,
      FastLevel.dairy => Icons.egg_outlined,
      FastLevel.fish => Icons.set_meal_outlined,
      FastLevel.wineOil => Icons.wine_bar_outlined,
      FastLevel.fast => Icons.spa_outlined,
      FastLevel.strict => Icons.do_not_disturb_alt_outlined,
    };

/// Rank drives the calendar marker and the notification style, so the two stay
/// consistent — a Praznic Împărătesc looks the same wherever the user meets it.
///
/// Red and black here are the convention, not a choice: a red cross and a black
/// cross are what the two ranks are called.
Color feastRankColor(FeastRank rank) => switch (rank) {
      FeastRank.praznic => TroitaColors.feastRed,
      FeastRank.cruceRosie => TroitaColors.feastRed,
      FeastRank.cruceAlbastra => TroitaColors.feastBlue,
      FeastRank.simplu => TroitaColors.muted,
    };

/// The colour a day's numeral takes.
///
/// Two independent reasons for red, and they add rather than compete:
///
///  * the day carries a red cross — praznic or cruce roșie
///  * the day is a Sunday, red even when nothing is commemorated, because that
///    is how a printed calendar reads and it is the fastest way to find your
///    place in the month
///
/// In 2026, 11 Sundays are also red-cross days and get red digits for both
/// reasons; 4 Sundays carry a *black* cross, where the numeral is still red
/// (it is a Sunday) while the commemoration keeps its black cross and its
/// "Cruce Neagră" label. That combination is correct, not a conflict — the
/// numeral describes the day, the cross describes the commemoration.
Color calendarDayColor({
  required FeastRank rank,
  required bool isSunday,
  required bool inMonth,
}) {
  if (!inMonth) return TroitaColors.muted;
  final bool redCross =
      rank == FeastRank.praznic || rank == FeastRank.cruceRosie;
  // Red wins over blue when both apply — a red-letter feast that falls on a
  // Sunday is still printed red.
  if (redCross || isSunday) return TroitaColors.feastRed;
  if (rank == FeastRank.cruceAlbastra) return TroitaColors.feastBlue;
  return TroitaColors.calendarInk;
}

class TroitaTheme {
  const TroitaTheme._();

  // Legacy aliases. Six screens already reference these; keeping them means the
  // palette swap needs no edits outside this file.
  static const Color ink = TroitaColors.ink;
  static const Color paper = TroitaColors.paper;
  static const Color red = TroitaColors.burgundy;
  static const Color gold = TroitaColors.gold;
  static const Color muted = TroitaColors.muted;

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: TroitaColors.burgundy,
      brightness: Brightness.light,
    ).copyWith(
      primary: TroitaColors.burgundy,
      onPrimary: TroitaColors.onBurgundy,
      secondary: TroitaColors.gold,
      surface: TroitaColors.paper,
      onSurface: TroitaColors.ink,
      surfaceContainer: TroitaColors.surface,
      outlineVariant: TroitaColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: TroitaColors.paper,
      fontFamily: TroitaFonts.text,

      appBarTheme: const AppBarTheme(
        backgroundColor: TroitaColors.paper,
        foregroundColor: TroitaColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: TroitaFonts.display,
          fontFamilyFallback: TroitaFonts.serifFallback,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: TroitaColors.burgundy,
        ),
      ),

      textTheme: const TextTheme(
        // Fraunces — screen titles, "Noiembrie 2026".
        headlineMedium: TextStyle(
          fontFamily: TroitaFonts.display,
          fontFamilyFallback: TroitaFonts.serifFallback,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: TroitaColors.burgundy,
        ),
        // Fraunces — section headers, "Sărbători următoare".
        titleLarge: TextStyle(
          fontFamily: TroitaFonts.display,
          fontFamilyFallback: TroitaFonts.serifFallback,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: TroitaColors.ink,
        ),
        // Geist SemiBold — feast names, list row titles.
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: TroitaColors.ink,
        ),
        // Geist SemiBold 13 — the fasting banner.
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: TroitaColors.ink,
        ),
        // Geist Medium 14 — day numbers, body.
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: TroitaColors.ink,
        ),
        // Geist 12 — secondary text.
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: TroitaColors.muted,
        ),
        // Geist Bold 12 uppercase — "CALENDAR ORTODOX", "PRAZNIC ÎMPĂRĂTESC".
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: TroitaColors.muted,
        ),
        // Geist 11 — bottom nav labels.
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: TroitaColors.muted,
        ),
        // Geist 10 — the month in a date badge.
        labelSmall: TextStyle(
          fontSize: 10,
          color: TroitaColors.muted,
        ),
      ),

      cardTheme: CardThemeData(
        color: TroitaColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: TroitaRadius.mediumAll,
          side: const BorderSide(color: TroitaColors.border),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: TroitaColors.surface,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 84,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? TroitaColors.burgundy
                : TroitaColors.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? TroitaColors.burgundy
                : TroitaColors.muted,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TroitaColors.burgundy,
          foregroundColor: TroitaColors.onBurgundy,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: TroitaRadius.smallAll,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TroitaColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: TroitaRadius.smallAll,
          borderSide: const BorderSide(color: TroitaColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: TroitaRadius.smallAll,
          borderSide: const BorderSide(color: TroitaColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TroitaRadius.smallAll,
          borderSide: const BorderSide(color: TroitaColors.gold),
        ),
        hintStyle: const TextStyle(color: TroitaColors.muted, fontSize: 14),
        labelStyle: const TextStyle(
          color: TroitaColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      dividerTheme: const DividerThemeData(
        space: 1,
        thickness: 1,
        color: TroitaColors.border,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? TroitaColors.onBurgundy
              : TroitaColors.surfaceSubtle,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? TroitaColors.burgundy
              : TroitaColors.border,
        ),
      ),
    );
  }

  /// The card treatment used everywhere: surface fill, hairline border, no
  /// shadow. Material's Card adds elevation semantics we don't want.
  static BoxDecoration cardDecoration({
    Color? color,
    Color? borderColor,
    double radius = TroitaRadius.medium,
  }) =>
      BoxDecoration(
        color: color ?? TroitaColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? TroitaColors.border),
      );
}
