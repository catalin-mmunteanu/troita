import '../models/feast_calendar.dart';
import 'calendar_days.dart';
import 'fast_level.dart';
import 'fasting_period.dart';

/// Everything about a single day that can be derived from the date alone.
class LiturgicalDay {
  const LiturgicalDay({
    required this.date,
    required this.fastLevel,
    required this.period,
    required this.isPeriodStart,
    required this.isPeriodEnd,
    required this.glas,
    required this.voscreasna,
    this.note,
  });

  final DateTime date;
  final FastLevel fastLevel;

  /// Null outside any named period (an ordinary week).
  final FastingPeriod? period;

  final bool isPeriodStart;
  final bool isPeriodEnd;

  /// 1–8, or null on days the octoechos doesn't apply.
  final int? glas;

  /// The resurrection gospel, 1–11.
  final int? voscreasna;

  /// Why this day differs from the period's base rule, when it does.
  final String? note;

  bool get isFasting => fastLevel.isFasting;

  /// Shown in the header banner: "Astăzi: Post cu dezlegare la untdelemn și vin".
  String get summary {
    if (fastLevel == FastLevel.none) return 'Zi fără post';
    if (fastLevel == FastLevel.fast) return 'Post';
    if (fastLevel == FastLevel.strict) return 'Post aspru (ajunare)';
    return 'Post cu ${fastLevel.label.toLowerCase()}';
  }
}

/// Derives fasting state, periods and glas from the date.
///
/// Everything here is a pure function of the calendar — no data source, no
/// network, no table. The whole engine hangs off [FeastCalendar.pascha].
///
/// The rules encode common Romanian parish practice. Usage varies between
/// monastic and parish typika (and between parishes), so treat the output as
/// guidance and let a priest review it before it ships.
///
/// Two other copies exist and must stay in step: tool/engine_port.py and the
/// website's src/lib/liturgical.ts. All three are tested against
/// test/golden/engine-2026-2030.json (`python3 tool/engine_golden.py --write`
/// regenerates it). Backtested against the published 2026 and 2027 calendars
/// with the published values switched off: 97% of days identical
/// (`--backtest`). That is what a computed year (2028–2030) is worth until its
/// official calendar appears.
class LiturgicalCalendar {
  const LiturgicalCalendar._();

  // ------------------------------------------------------------------ periods

  static DateTime _d(int y, int m, int day) => DateTime(y, m, day);

  static DateTime _offset(DateTime from, int days) =>
      DateTime(from.year, from.month, from.day + days);

  /// Postul Mare: Clean Monday (Pascha − 48) through Great Saturday.
  static FastingPeriod postulMare(int year) {
    final DateTime pascha = FeastCalendar.pascha(year);
    return FastingPeriod(
      kind: FastingPeriodKind.postulMare,
      start: _offset(pascha, -48),
      end: _offset(pascha, -1),
      note: 'Cel mai aspru post din an.',
    );
  }

  /// Shorter than this, the Apostles' fast starts the Tuesday after Rusalii.
  static const int minApostlesDays = 7;

  /// Postul Sfinților Apostoli: Monday after Duminica Tuturor Sfinților
  /// (Pascha + 57) through 28 June.
  ///
  /// In late-Pascha years that Monday leaves less than a week — or nothing.
  /// The Romanian Church then starts the fast on the Tuesday after Rusalii,
  /// after the Monday of the Holy Trinity (2027: 22–28 June, as published;
  /// 2024: 25–28 June). With that rule the fast never disappears before 2100,
  /// but the return stays nullable for safety.
  static FastingPeriod? postulApostolilor(int year) {
    final DateTime pascha = FeastCalendar.pascha(year);
    DateTime start = _offset(pascha, 57);
    final DateTime end = _d(year, 6, 28);
    if (calendarDaysBetween(start, end) + 1 < minApostlesDays) {
      start = _offset(pascha, 51);
    }
    if (start.isAfter(end)) return null;
    return FastingPeriod(
      kind: FastingPeriodKind.postulApostolilor,
      start: start,
      end: end,
      note: 'Durata variază în funcție de data Paștelui.',
    );
  }

  static FastingPeriod postulAdormirii(int year) => FastingPeriod(
        kind: FastingPeriodKind.postulAdormirii,
        start: _d(year, 8, 1),
        end: _d(year, 8, 14),
        note: 'Post aspru de două săptămâni.',
      );

  static FastingPeriod postulCraciunului(int year) => FastingPeriod(
        kind: FastingPeriodKind.postulCraciunului,
        start: _d(year, 11, 15),
        end: _d(year, 12, 24),
        note: 'Dezlegare la pește până în 20 decembrie.',
      );

  /// The four great fasts that touch [year], in calendar order.
  static List<FastingPeriod> greatFasts(int year) => <FastingPeriod>[
        postulMare(year),
        if (postulApostolilor(year) != null) postulApostolilor(year)!,
        postulAdormirii(year),
        postulCraciunului(year),
      ]..sort((FastingPeriod a, FastingPeriod b) => a.start.compareTo(b.start));

  /// Fast-free weeks. All Pascha-relative except the Nativity–Theophany one.
  static List<FastingPeriod> harti(int year) {
    final DateTime pascha = FeastCalendar.pascha(year);
    // The week after Rusalii ends early when the Apostles' fast starts inside
    // it (late-Pascha years).
    DateTime afterRusaliiEnd = _offset(pascha, 56);
    final FastingPeriod? apostles = postulApostolilor(year);
    if (apostles != null && !apostles.start.isAfter(afterRusaliiEnd)) {
      afterRusaliiEnd = _offset(apostles.start, -1);
    }
    return <FastingPeriod>[
      // Crăciun → Bobotează. Split across the year boundary, so both halves
      // are emitted and the lookup below checks the neighbouring years too.
      FastingPeriod(
        kind: FastingPeriodKind.harti,
        start: _d(year, 12, 25),
        end: _d(year + 1, 1, 4),
        note: 'De la Nașterea Domnului până la Bobotează.',
      ),
      // Week after Duminica Vameșului și a Fariseului.
      FastingPeriod(
        kind: FastingPeriodKind.harti,
        start: _offset(pascha, -69),
        end: _offset(pascha, -64),
        note: 'Săptămâna de după Duminica Vameșului și a Fariseului.',
      ),
      // Săptămâna Luminată.
      FastingPeriod(
        kind: FastingPeriodKind.harti,
        start: pascha,
        end: _offset(pascha, 6),
        note: 'Săptămâna Luminată.',
      ),
      // Week after Pentecost.
      FastingPeriod(
        kind: FastingPeriodKind.harti,
        start: _offset(pascha, 50),
        end: afterRusaliiEnd,
        note: 'Săptămâna de după Rusalii.',
      ),
    ];
  }

  /// Săptămâna Brânzei (Săptămâna Albă), before Postul Mare. Shown as a week
  /// without fast, like the website.
  static FastingPeriod saptamanaBranzei(int year) {
    final DateTime pascha = FeastCalendar.pascha(year);
    return FastingPeriod(
      kind: FastingPeriodKind.saptamanaBranzei,
      start: _offset(pascha, -55),
      end: _offset(pascha, -49),
      note: 'Săptămâna Albă, înaintea Postului Mare.',
    );
  }

  // --------------------------------------------------------------------- day

  /// The full picture for [date].
  ///
  /// [rank] is the day's commemoration rank, looked up from the feasts table by
  /// the caller. It matters because a Praznic Împărătesc falling on a Wednesday
  /// or Friday brings a dezlegare that the period rules alone wouldn't produce.
  /// [dezlegare] is an explicit override carried by a feast row — Sf. Nicolae
  /// brings fish even though it falls inside the Nativity fast. It wins over
  /// the period rule, but never over a strict day: Ajunul Crăciunului stays a
  /// fast whatever else is commemorated.
  static LiturgicalDay dayFor(
    DateTime date, {
    FeastRank rank = FeastRank.simplu,
    FastLevel? dezlegare,
  }) {
    final DateTime d = DateTime(date.year, date.month, date.day);

    final FastingPeriod? harta = _findHarti(d);
    final FastingPeriod branza = saptamanaBranzei(d.year);
    final FastingPeriod? great = _findGreatFast(d);

    FastLevel level;
    String? note;
    FastingPeriod? period;

    if (harta != null) {
      period = harta;
      level = FastLevel.none;
      note = harta.note;
    } else if (branza.contains(d)) {
      period = branza;
      level = FastLevel.none;
      note = branza.note;
    } else if (great != null) {
      period = great;
      final (FastLevel l, String? n) = _levelInGreatFast(d, great, rank);
      level = l;
      note = n;
    } else {
      period = null;
      level = _levelOutsideFasts(d, rank);
    }

    if (dezlegare != null && level.isFasting) {
      level = FastLevel.looser(level, dezlegare);
    }

    // Fixed days override whatever the surrounding rule produced, including a
    // feast's dezlegare. Ajunul Bobotezei is at least strict; Tăierea Capului
    // and Înălțarea Sfintei Cruci are exactly "post, cu dezlegare la untdelemn
    // și vin" — they used to be forced to a plain fast, which made them
    // stricter than every Romanian calendar prints them.
    final FastLevel? fixed = _fixedDay(d);
    if (fixed != null) {
      level = fixed == FastLevel.strict
          ? FastLevel.stricter(level, fixed)
          : fixed;
      note = _fixedDayNote(d) ?? note;
    }

    return LiturgicalDay(
      date: d,
      fastLevel: level,
      period: period,
      isPeriodStart: period?.isFirstDay(d) ?? false,
      isPeriodEnd: period?.isLastDay(d) ?? false,
      glas: glasFor(d),
      voscreasna: voscreasnaFor(d),
      note: note,
    );
  }

  static FastingPeriod? _findHarti(DateTime d) {
    for (final int y in <int>[d.year - 1, d.year]) {
      for (final FastingPeriod p in harti(y)) {
        if (p.contains(d)) return p;
      }
    }
    return null;
  }

  static FastingPeriod? _findGreatFast(DateTime d) {
    for (final FastingPeriod p in greatFasts(d.year)) {
      if (p.contains(d)) return p;
    }
    return null;
  }

  // --------------------------------------------------------------- fast rules

  static (FastLevel, String?) _levelInGreatFast(
    DateTime d,
    FastingPeriod period,
    FeastRank rank,
  ) {
    final DateTime pascha = FeastCalendar.pascha(d.year);
    final bool weekend =
        d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
    final bool wedFri =
        d.weekday == DateTime.wednesday || d.weekday == DateTime.friday;
    final bool tueThu =
        d.weekday == DateTime.tuesday || d.weekday == DateTime.thursday;
    // A saint marked with a cross (red or blue) relaxes the fast a step.
    final bool cross =
        rank == FeastRank.cruceRosie || rank == FeastRank.cruceAlbastra;

    switch (period.kind) {
      case FastingPeriodKind.postulMare:
        // Clean Monday and Tuesday are kept as ajunare, as published.
        if (d == _offset(pascha, -48) || d == _offset(pascha, -47)) {
          return (FastLevel.strict, 'Primele zile ale Postului Mare.');
        }
        if (d == _offset(pascha, -2)) {
          return (FastLevel.strict, 'Vinerea Mare.');
        }
        // Holy Monday, Tuesday and Wednesday: bread and water in the evening.
        if (!d.isBefore(_offset(pascha, -6)) &&
            !d.isAfter(_offset(pascha, -4))) {
          return (FastLevel.strict, 'Săptămâna Patimilor.');
        }
        if (d.month == 3 && d.day == 25) {
          return (FastLevel.fish, 'Buna Vestire.');
        }
        if (d == _offset(pascha, -7)) {
          return (FastLevel.fish, 'Duminica Floriilor.');
        }
        if (d == _offset(pascha, -8)) {
          return (FastLevel.wineOil, 'Sâmbăta lui Lazăr — dezlegare la icre.');
        }
        if (d == _offset(pascha, -3)) {
          return (FastLevel.wineOil, 'Joia Mare.');
        }
        if (d == _offset(pascha, -17)) {
          return (FastLevel.wineOil, 'Joia Canonului cel Mare.');
        }
        // Înainte-prăznuirea and Odovania of the Annunciation (24 and 26
        // March) carry oil and wine on a Lenten weekday — not on Wednesday or
        // Friday (2027: 26 March, a Friday, published as a plain fast).
        if (d.month == 3 &&
            (d.day == 24 || d.day == 26) &&
            !weekend &&
            !wedFri) {
          return (FastLevel.wineOil, null);
        }
        if (cross && !weekend) return (FastLevel.wineOil, null);
        return weekend
            ? (FastLevel.wineOil, null)
            : (FastLevel.fast, null);

      case FastingPeriodKind.postulAdormirii:
        if (d.month == 8 && d.day == 6) {
          return (FastLevel.fish, 'Schimbarea la Față.');
        }
        // Oil and wine at the weekend only. Tuesday and Thursday used to get
        // them too; the published calendar keeps both as plain fast days.
        if (weekend) return (FastLevel.wineOil, null);
        return (FastLevel.fast, null);

      case FastingPeriodKind.postulApostolilor:
        if (wedFri) {
          // A Praznic Împărătesc brings fish (Nașterea Sf. Ioan, 24 June); a
          // saint with a cross brings oil and wine.
          if (rank == FeastRank.praznic) return (FastLevel.fish, null);
          return cross ? (FastLevel.wineOil, null) : (FastLevel.fast, null);
        }
        // On the other days a saint with a cross brings fish.
        if (cross || rank == FeastRank.praznic) return (FastLevel.fish, null);
        // Tuesday and Thursday: oil and wine. Monday, Saturday and Sunday:
        // fish. These were the other way round before; fitted to the 2026
        // published calendar, where all three Mondays carry fish.
        if (tueThu) return (FastLevel.wineOil, null);
        return (FastLevel.fish, null);

      case FastingPeriodKind.postulCraciunului:
        if (d.month == 12 && d.day == 24) {
          return (FastLevel.strict, 'Ajunul Nașterii Domnului.');
        }
        // Named feasts inside the fast carry a dezlegare la pește — and say
        // which feast, so a screen explaining the dezlegare can name it rather
        // than attribute it to whatever weekday it fell on.
        if (d.month == 11 && d.day == 21) {
          return (FastLevel.fish, 'Intrarea în Biserică a Maicii Domnului.');
        }
        if (d.month == 11 && d.day == 30) {
          return (FastLevel.fish, 'Sfântul Apostol Andrei.');
        }
        if (d.month == 12 && d.day == 6) {
          return (FastLevel.fish, 'Sfântul Ierarh Nicolae.');
        }
        // Three stretches. Until Intrarea în Biserică (15–20 November) fish
        // is not yet given: the weekend has oil and wine, weekdays are fast.
        // From 21 November to 20 December: fish at the weekend, oil and wine
        // on Tuesday and Thursday, fast on Monday, Wednesday and Friday.
        // From 21 to 23 December: no fish again.
        //
        // The middle stretch used to give fish on Tuesday and Thursday and oil
        // on the other weekdays — one step too lenient everywhere, which is
        // why this fast was only half right before published data won.
        final bool beforeIntrarea = d.month == 11 && d.day < 21;
        final bool lastDays = d.month == 12 && d.day > 20;
        if (beforeIntrarea || lastDays) {
          return weekend ? (FastLevel.wineOil, null) : (FastLevel.fast, null);
        }
        if (weekend) return (FastLevel.fish, null);
        // A saint with a cross: oil and wine on Wednesday and Friday, fish on
        // the other weekdays.
        if (wedFri) {
          return cross ? (FastLevel.wineOil, null) : (FastLevel.fast, null);
        }
        if (cross) return (FastLevel.fish, null);
        if (tueThu) return (FastLevel.wineOil, null);
        return (FastLevel.fast, null);

      default:
        return (FastLevel.fast, null);
    }
  }

  static FastLevel _levelOutsideFasts(DateTime d, FeastRank rank) {
    if (d.weekday != DateTime.wednesday && d.weekday != DateTime.friday) {
      return FastLevel.none;
    }
    // Between Duminica Tomii and Pentecost the weekly fast is kept with fish:
    // the Paschal season is not a time of strict fasting. Săptămâna Luminată
    // before it is already harți.
    final DateTime pascha = FeastCalendar.pascha(d.year);
    if (!d.isBefore(_offset(pascha, 8)) && !d.isAfter(_offset(pascha, 48))) {
      return FastLevel.fish;
    }
    // A great feast landing on Wednesday or Friday relaxes the weekly fast.
    return switch (rank) {
      FeastRank.praznic => FastLevel.fish,
      FeastRank.cruceRosie => FastLevel.wineOil,
      _ => FastLevel.fast,
    };
  }

  /// Days that stand outside the period rules entirely. Botezul Domnului has
  /// no fast whatever the weekday (2027: a Wednesday, published without fast).
  static FastLevel? _fixedDay(DateTime d) {
    if (d.month == 1 && d.day == 5) return FastLevel.strict;
    if (d.month == 1 && d.day == 6) return FastLevel.none;
    if (d.month == 8 && d.day == 29) return FastLevel.wineOil;
    if (d.month == 9 && d.day == 14) return FastLevel.wineOil;
    return null;
  }

  static String? _fixedDayNote(DateTime d) {
    if (d.month == 1 && d.day == 5) return 'Ajunul Bobotezei.';
    if (d.month == 1 && d.day == 6) return 'Botezul Domnului.';
    if (d.month == 8 && d.day == 29) {
      return 'Tăierea Capului Sfântului Ioan Botezătorul.';
    }
    if (d.month == 9 && d.day == 14) return 'Înălțarea Sfintei Cruci.';
    return null;
  }

  // -------------------------------------------------------------------- glas

  /// The eothinon — the resurrection gospel — cycling 1–11 weekly.
  ///
  /// The phase is fitted to a published calendar: 4 January 2026 is voscreasna
  /// 8, and the three Sundays after it are 9, 10 and 11. That pins the offset
  /// against the same Duminica Tomii anchor the glas uses. Verified for four
  /// consecutive weeks; if you import another month and it disagrees, the
  /// offset is what to adjust.
  static int? voscreasnaFor(DateTime date) {
    final int? weeks = _weeksSinceThomas(date);
    if (weeks == null) return null;
    return ((weeks + 4) % 11) + 1;
  }

  /// The octoechos tone, 1–8, cycling weekly from Duminica Tomii (Pascha + 7).
  static int? glasFor(DateTime date) {
    final int? weeks = _weeksSinceThomas(date);
    if (weeks == null) return null;
    return (weeks % 8) + 1;
  }

  /// Weeks elapsed since Duminica Tomii, the anchor both tone cycles hang off.
  static int? _weeksSinceThomas(DateTime date) {
    final DateTime d = DateTime(date.year, date.month, date.day);
    DateTime anchor = _offset(FeastCalendar.pascha(d.year), 7);
    if (d.isBefore(anchor)) {
      anchor = _offset(FeastCalendar.pascha(d.year - 1), 7);
    }
    // Calendar days, not elapsed time. The anchor is always after the March
    // clock change so this happened to come out right, but only by luck of
    // where Pascha falls; a Sunday is exactly when ~/7 cannot afford to be
    // an hour short.
    final int weeks = calendarDaysBetween(anchor, d) ~/ 7;
    return weeks < 0 ? null : weeks;
  }

  // ------------------------------------------------------------- weddings

  /// Fixed feasts whose eve and day have no weddings, as month * 100 + day.
  static const Set<int> _noWeddingDays = <int>{
    201, 202, // Întâmpinarea Domnului
    324, 325, // Buna Vestire
    815, // Adormirea (its eve is in the Dormition fast)
    829, // Tăierea capului Sf. Ioan
    907, 908, // Nașterea Maicii Domnului
    914, // Înălțarea Sfintei Cruci
    1120, 1121, // Intrarea în Biserică (inside the Nativity fast)
  };

  /// Null when the Church celebrates weddings on [date], else why it does not.
  ///
  /// Checked against the published 2027 calendar ("Nu se fac nunți"): 363 of
  /// 365 days identical, and the two others are errors in the source. Same
  /// rules in tool/engine_port.py and troita-web's liturgical.ts, all three
  /// tested against test/golden/engine-2026-2030.json. A civil wedding is not
  /// affected.
  static WeddingBar? cununie(DateTime date) {
    final DateTime d = DateTime(date.year, date.month, date.day);
    final int y = d.year;
    final DateTime pascha = FeastCalendar.pascha(y);
    for (final FastingPeriod p in greatFasts(y)) {
      if (p.contains(d)) return WeddingBar.post;
    }
    if (saptamanaBranzei(y).contains(d)) return WeddingBar.saptamanaBranzei;
    if (!d.isAfter(_d(y, 1, 6)) || !d.isBefore(_d(y, 12, 25))) {
      return WeddingBar.craciunBoboteaza;
    }
    if (!d.isBefore(pascha) && !d.isAfter(_offset(pascha, 6))) {
      return WeddingBar.saptamanaLuminata;
    }
    if (_noWeddingDays.contains(d.month * 100 + d.day)) {
      return WeddingBar.praznic;
    }
    // Înălțarea and Rusaliile with their eves, and the Monday of Rusalii.
    for (final int offset in const <int>[38, 39, 48, 49, 50]) {
      if (d == _offset(pascha, offset)) return WeddingBar.praznic;
    }
    if (d.weekday == DateTime.wednesday || d.weekday == DateTime.friday) {
      final bool inHarti = <FastingPeriod>[...harti(y - 1), ...harti(y)]
          .any((FastingPeriod p) => p.contains(d));
      if (!inHarti) return WeddingBar.miercuriVineri;
    }
    return null;
  }
}

/// Why the Church does not celebrate weddings on a day.
enum WeddingBar {
  post,
  saptamanaBranzei,
  craciunBoboteaza,
  saptamanaLuminata,
  praznic,
  miercuriVineri;

  /// Short reason, for the day screen: "Nu se fac nunți: {label}."
  String get label => switch (this) {
        WeddingBar.post => 'post',
        WeddingBar.saptamanaBranzei => 'Săptămâna Brânzei',
        WeddingBar.craciunBoboteaza => 'între Crăciun și Bobotează',
        WeddingBar.saptamanaLuminata => 'Săptămâna Luminată',
        WeddingBar.praznic => 'praznic sau ajunul lui',
        WeddingBar.miercuriVineri => 'zi de post (miercuri sau vineri)',
      };
}
