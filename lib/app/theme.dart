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
  /// Headings. Variable font, drawn in Figma with SOFT 0 / WONK 1.
  static const String display = 'Fraunces';

  /// Everything else.
  static const String text = 'Geist';
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

/// Rank drives both the calendar marker and the notification style, so the two
/// stay visually consistent — a Praznic Împărătesc looks the same wherever the
/// user meets it.
Color feastRankColor(FeastRank rank) => switch (rank) {
      FeastRank.praznic => TroitaColors.burgundy,
      FeastRank.cruceRosie => TroitaColors.burgundy,
      FeastRank.cruceNeagra => TroitaColors.ink,
      FeastRank.simplu => TroitaColors.muted,
    };

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
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: TroitaColors.burgundy,
        ),
      ),

      textTheme: const TextTheme(
        // Fraunces — screen titles, "Noiembrie 2026".
        headlineMedium: TextStyle(
          fontFamily: TroitaFonts.display,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: TroitaColors.burgundy,
        ),
        // Fraunces — section headers, "Sărbători următoare".
        titleLarge: TextStyle(
          fontFamily: TroitaFonts.display,
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
