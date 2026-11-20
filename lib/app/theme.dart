import 'package:material_ui/material_ui.dart';

import '../core/liturgical/fast_level.dart';
import 'design_tokens.dart';

/// The app's palette, named for what each colour does here.
///
/// Every value comes from the tokens shared with the website (DESIGN.MD,
/// troita-web/design/tokens.json → design_tokens.dart). Change a colour there,
/// not here. Screens reference these names, never a hex literal.
abstract final class TroitaColors {
  /// Page background — Parchment Light.
  static const Color paper = TroitaTokens.parchment;

  /// Cards, bottom nav, input fields — Parchment Surface.
  static const Color surface = TroitaTokens.surface;

  /// Halfway between [paper] and [surface], for inactive date badges.
  static const Color surfaceSubtle = Color(0xFFF9F5F1);

  /// Hairline borders around every card and the top of the bottom nav — Carved Oak.
  static const Color border = TroitaTokens.oak;

  /// Highlighted surface — feast days, the fasting banner, active date badges.
  static const Color accentSurface = TroitaTokens.bNoneBg;

  /// Gold, used only as a border or a marker. Never as a text colour (2.0:1
  /// on parchment).
  static const Color gold = TroitaTokens.gold;

  /// Byzantine burgundy. Primary, and the fill behind today's date. App-only:
  /// kept distinct from the liturgical red so red means one thing.
  static const Color burgundy = TroitaAppTokens.today;

  /// Body text — Deep Charcoal.
  static const Color ink = TroitaTokens.ink;

  /// Secondary text, inactive nav labels, days outside the current month —
  /// Muted Umber.
  static const Color muted = TroitaTokens.umber;

  static const Color onBurgundy = TroitaAppTokens.onToday;

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
  static const Color feastRed = TroitaTokens.red;

  /// Ordinary weekday numerals.
  static const Color calendarInk = TroitaTokens.ink;

  /// Cruce albastră. Printed black in some calendars and blue in others; it is
  /// the same rank, so this is purely which convention we follow. Switch it to
  /// [calendarInk] to print black instead.
  static const Color feastBlue = TroitaTokens.blue;

  /// Fasting states, the text colours of the website's fasting badges, so a
  /// day reads the same in the app and on troita.ro. All pass 4.5:1.
  ///
  /// Dezlegare la pește — teal, never confused with a blue-cross day.
  static const Color fishBlue = TroitaTokens.bFishFg;

  /// Dezlegare la ulei și vin — olive. The gold marker cannot carry text.
  static const Color wineOil = TroitaTokens.bOilFg;

  /// Zi de post — the purple of Lent.
  static const Color fastPurple = TroitaTokens.bPostFg;

  /// Ajunare. Near-black, so the hardest days are visibly harder than the
  /// fast around them.
  static const Color strictInk = TroitaTokens.ink;

  /// Romanian saints. The source markup singles them out with `class="rom"`,
  /// and printed calendars usually set them apart too.
  static const Color romanianSaint = TroitaTokens.red;
}

/// DESIGN.MD §5: 4px by default, 8px at most. No 16px+ rounded cards.
abstract final class TroitaRadius {
  /// Day cells, icon buttons, date badges.
  static const double small = TroitaTokenRadius.sm;

  /// Feast cards, list rows.
  static const double medium = TroitaTokenRadius.sm;

  /// The calendar card.
  static const double large = TroitaTokenRadius.md;

  /// Sheets.
  static const double xlarge = TroitaTokenRadius.max;

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

/// Font families, the same four as the website (DESIGN.MD §3), bundled in
/// assets/fonts (OFL, all with ă â î ș ț).
abstract final class TroitaFonts {
  /// Headings, and the calendar itself — Literata.
  static const String display = TroitaTokenFonts.display;

  /// Body text, saints' names, settings — Plus Jakarta Sans.
  static const String text = TroitaTokenFonts.text;

  /// Buttons, navigation labels — Alegreya Sans.
  static const String ui = TroitaTokenFonts.ui;

  /// Rubrics: small uppercase labels and liturgical notes — JetBrains Mono.
  static const String mono = TroitaTokenFonts.mono;

  /// If a glyph is missing, the platform serif (Noto Serif on Android).
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
/// One colour per level, all five distinct.
///
/// These used to collapse: fish and wine-and-oil were all the same gold,
/// which is fine on a single day's badge next to its written label and useless
/// the moment a whole fast is drawn as a grid — the dezlegări are the thing a
/// reader is looking for, and they were indistinguishable from each other.
///
/// Read as a scale from relief to severity: umber is no fast at all, teal is
/// fish (the fullest relief inside a fast), olive is oil and wine, purple is
/// the fast itself, near-black is ajunare. Same hues as the website's badges.
Color fastLevelColor(FastLevel level) => switch (level) {
      FastLevel.none => TroitaColors.muted,
      FastLevel.fish => TroitaColors.fishBlue,
      FastLevel.wineOil => TroitaColors.wineOil,
      FastLevel.fast => TroitaColors.fastPurple,
      FastLevel.strict => TroitaColors.strictInk,
    };

/// Icon for a day's fasting state.
///
/// Paired with a written label everywhere it appears. An icon alone is not
/// enough for the audience this app is for — the published calendars use a
/// small fish glyph, but they also spell out "Dezlegare la pește" next to it,
/// and so should we.
IconData fastLevelIcon(FastLevel level) => switch (level) {
      FastLevel.none => Icons.restaurant_outlined,
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
        // Literata — screen titles, "Noiembrie 2026".
        headlineMedium: TextStyle(
          fontFamily: TroitaFonts.display,
          fontFamilyFallback: TroitaFonts.serifFallback,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: TroitaColors.burgundy,
        ),
        // Literata — section headers, "Sărbători următoare".
        titleLarge: TextStyle(
          fontFamily: TroitaFonts.display,
          fontFamilyFallback: TroitaFonts.serifFallback,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: TroitaColors.ink,
        ),
        // Plus Jakarta Sans SemiBold — feast names, list row titles.
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: TroitaColors.ink,
        ),
        // Plus Jakarta Sans SemiBold 13 — the fasting banner.
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: TroitaColors.ink,
        ),
        // Plus Jakarta Sans Medium 14 — day numbers, body.
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: TroitaColors.ink,
        ),
        // Plus Jakarta Sans 12 — secondary text.
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: TroitaColors.muted,
        ),
        // JetBrains Mono 12 uppercase, the website's rubric — "CALENDAR
        // ORTODOX", "PRAZNIC ÎMPĂRĂTESC".
        labelLarge: TextStyle(
          fontFamily: TroitaFonts.mono,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
          color: TroitaColors.muted,
        ),
        // Alegreya Sans 12 — bottom nav labels.
        labelMedium: TextStyle(
          fontFamily: TroitaFonts.ui,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: TroitaColors.muted,
        ),
        // Alegreya Sans 11 — the month in a date badge.
        labelSmall: TextStyle(
          fontFamily: TroitaFonts.ui,
          fontSize: 11,
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
            fontFamily: TroitaFonts.ui,
            fontSize: 12,
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
            fontFamily: TroitaFonts.ui,
            fontSize: 16,
            fontWeight: FontWeight.w700,
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
