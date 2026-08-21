import '../models/feast_calendar.dart';
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

  /// Why this day differs from the period's base rule, when it does.
  final String? note;

  bool get isFasting => fastLevel.isFasting;

  /// Shown in the header banner: "Astăzi: Post cu dezlegare la untdelemn și vin".
  String get summary {
    if (fastLevel == FastLevel.none) return 'Zi fără post';
    if (fastLevel == FastLevel.dairy) return 'Dezlegare la lactate';
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

  /// Postul Sfinților Apostoli: Monday after Duminica Tuturor Sfinților
  /// (Pascha + 57) through 28 June.
  ///
  /// Its length depends on Pascha and **collapses to nothing in late-Pascha
  /// years** — hence the nullable return rather than a fixed range.
  static FastingPeriod? postulApostolilor(int year) {
    final DateTime pascha = FeastCalendar.pascha(year);
    final DateTime start = _offset(pascha, 57);
    final DateTime end = _d(year, 6, 28);
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
        end: _offset(pascha, 56),
        note: 'Săptămâna de după Rusalii.',
      ),
    ];
  }

  /// Săptămâna Brânzei — dairy and eggs all week, meat not.
  static FastingPeriod saptamanaBranzei(int year) {
    final DateTime pascha = FeastCalendar.pascha(year);
    return FastingPeriod(
      kind: FastingPeriodKind.saptamanaBranzei,
      start: _offset(pascha, -55),
      end: _offset(pascha, -49),
      note: 'Se dezleagă la lactate și ouă în toate zilele.',
    );
  }

  // --------------------------------------------------------------------- day

  /// The full picture for [date].
  ///
  /// [rank] is the day's commemoration rank, looked up from the feasts table by
  /// the caller. It matters because a Praznic Împărătesc falling on a Wednesday
  /// or Friday brings a dezlegare that the period rules alone wouldn't produce.
  static LiturgicalDay dayFor(
    DateTime date, {
    FeastRank rank = FeastRank.simplu,
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
      level = FastLevel.dairy;
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

    // Fixed strict days override whatever the surrounding rule produced.
    final FastLevel? fixed = _fixedStrictDay(d);
    if (fixed != null) {
      level = FastLevel.stricter(level, fixed);
      note = _fixedStrictNote(d) ?? note;
    }

    return LiturgicalDay(
      date: d,
      fastLevel: level,
      period: period,
      isPeriodStart: period?.isFirstDay(d) ?? false,
      isPeriodEnd: period?.isLastDay(d) ?? false,
      glas: glasFor(d),
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

    switch (period.kind) {
      case FastingPeriodKind.postulMare:
        if (d == _offset(pascha, -48)) {
          return (FastLevel.strict, 'Prima zi a Postului Mare.');
        }
        if (d == _offset(pascha, -2)) {
          return (FastLevel.strict, 'Vinerea Mare.');
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
        return weekend
            ? (FastLevel.wineOil, null)
            : (FastLevel.fast, null);

      case FastingPeriodKind.postulAdormirii:
        if (d.month == 8 && d.day == 6) {
          return (FastLevel.fish, 'Schimbarea la Față.');
        }
        if (weekend ||
            d.weekday == DateTime.tuesday ||
            d.weekday == DateTime.thursday) {
          return (FastLevel.wineOil, null);
        }
        return (FastLevel.fast, null);

      case FastingPeriodKind.postulApostolilor:
        if (d.weekday == DateTime.wednesday || d.weekday == DateTime.friday) {
          return rank.weight >= FeastRank.cruceRosie.weight
              ? (FastLevel.wineOil, null)
              : (FastLevel.fast, null);
        }
        if (d.weekday == DateTime.monday) return (FastLevel.wineOil, null);
        return (FastLevel.fish, null);

      case FastingPeriodKind.postulCraciunului:
        if (d.month == 12 && d.day == 24) {
          return (FastLevel.strict, 'Ajunul Nașterii Domnului.');
        }
        // Named feasts inside the fast carry a dezlegare la pește.
        if ((d.month == 11 && (d.day == 21 || d.day == 30)) ||
            (d.month == 12 && d.day == 6)) {
          return (FastLevel.fish, null);
        }
        final bool beforeThe20th = d.month == 11 || d.day <= 20;
        if (beforeThe20th) {
          if (weekend ||
              d.weekday == DateTime.tuesday ||
              d.weekday == DateTime.thursday) {
            return (FastLevel.fish, null);
          }
          return (FastLevel.wineOil, null);
        }
        // 21–23 December: no fish, regardless of weekday.
        return weekend ? (FastLevel.wineOil, null) : (FastLevel.fast, null);

      default:
        return (FastLevel.fast, null);
    }
  }

  static FastLevel _levelOutsideFasts(DateTime d, FeastRank rank) {
    if (d.weekday != DateTime.wednesday && d.weekday != DateTime.friday) {
      return FastLevel.none;
    }
    // A great feast landing on Wednesday or Friday relaxes the weekly fast.
    return switch (rank) {
      FeastRank.praznic => FastLevel.fish,
      FeastRank.cruceRosie => FastLevel.wineOil,
      _ => FastLevel.fast,
    };
  }

  /// Days of strict fasting that stand outside the period rules entirely.
  static FastLevel? _fixedStrictDay(DateTime d) {
    if (d.month == 1 && d.day == 5) return FastLevel.strict;
    if (d.month == 8 && d.day == 29) return FastLevel.fast;
    if (d.month == 9 && d.day == 14) return FastLevel.fast;
    return null;
  }

  static String? _fixedStrictNote(DateTime d) {
    if (d.month == 1 && d.day == 5) return 'Ajunul Bobotezei.';
    if (d.month == 8 && d.day == 29) {
      return 'Tăierea Capului Sfântului Ioan Botezătorul.';
    }
    if (d.month == 9 && d.day == 14) return 'Înălțarea Sfintei Cruci.';
    return null;
  }

  // -------------------------------------------------------------------- glas

  /// The octoechos tone, 1–8, cycling weekly from Duminica Tomii (Pascha + 7).
  static int? glasFor(DateTime date) {
    final DateTime d = DateTime(date.year, date.month, date.day);
    DateTime anchor = _offset(FeastCalendar.pascha(d.year), 7);
    if (d.isBefore(anchor)) {
      anchor = _offset(FeastCalendar.pascha(d.year - 1), 7);
    }
    final int weeks = d.difference(anchor).inDays ~/ 7;
    if (weeks < 0) return null;
    return (weeks % 8) + 1;
  }
}
