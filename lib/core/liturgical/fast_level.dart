/// What is permitted on a given day, from most to least permissive.
///
/// The order matters: `index` is used to resolve conflicts when several rules
/// apply to the same date — a feast day's dezlegare wins over the base rule of
/// the period it falls in, so we take the more permissive of the two.
enum FastLevel {
  /// Harți — no fasting at all.
  none,

  /// Săptămâna Brânzei: dairy and eggs permitted, meat not.
  dairy,

  /// Dezlegare la pește (which implies oil and wine too).
  fish,

  /// Dezlegare la untdelemn și vin.
  wineOil,

  /// Post — no animal products, no oil, no wine.
  fast,

  /// Ajunare / post negru.
  strict;

  bool get isFasting => this != FastLevel.none;

  /// The more permissive of two levels. Feast dezlegări override period rules.
  static FastLevel looser(FastLevel a, FastLevel b) =>
      a.index <= b.index ? a : b;

  static FastLevel stricter(FastLevel a, FastLevel b) =>
      a.index >= b.index ? a : b;

  String get label => switch (this) {
        FastLevel.none => 'Zi fără post',
        FastLevel.dairy => 'Dezlegare la lactate',
        FastLevel.fish => 'Dezlegare la pește',
        FastLevel.wineOil => 'Dezlegare la untdelemn și vin',
        FastLevel.fast => 'Post',
        FastLevel.strict => 'Post aspru (ajunare)',
      };

  String get shortLabel => switch (this) {
        FastLevel.none => 'Fără post',
        FastLevel.dairy => 'Lactate',
        FastLevel.fish => 'Pește',
        FastLevel.wineOil => 'Ulei și vin',
        FastLevel.fast => 'Post',
        FastLevel.strict => 'Ajunare',
      };
}

/// Rank of a commemoration, matching the marks used in Romanian calendars.
enum FeastRank {
  /// Praznic Împărătesc — the twelve great feasts plus Pascha.
  praznic,

  /// Cruce roșie — major saints, polyeleos.
  cruceRosie,

  /// Cruce neagră — lesser commemoration with special hymns.
  cruceNeagra,

  /// Ordinary day.
  simplu;

  static FeastRank parse(String? value) => switch (value) {
        'praznic' => FeastRank.praznic,
        'cruce_rosie' => FeastRank.cruceRosie,
        'cruce_neagra' => FeastRank.cruceNeagra,
        _ => FeastRank.simplu,
      };

  String get id => switch (this) {
        FeastRank.praznic => 'praznic',
        FeastRank.cruceRosie => 'cruce_rosie',
        FeastRank.cruceNeagra => 'cruce_neagra',
        FeastRank.simplu => 'simplu',
      };

  String get label => switch (this) {
        FeastRank.praznic => 'Praznic Împărătesc',
        FeastRank.cruceRosie => 'Cruce Roșie',
        FeastRank.cruceNeagra => 'Cruce Neagră',
        FeastRank.simplu => 'Pomenire',
      };

  /// Drives notification channel, colour and whether we notify at all.
  int get weight => switch (this) {
        FeastRank.praznic => 3,
        FeastRank.cruceRosie => 2,
        FeastRank.cruceNeagra => 1,
        FeastRank.simplu => 0,
      };
}

/// The four great fasts, plus the states a day can be in outside them.
enum FastingPeriodKind {
  postulMare,
  postulApostolilor,
  postulAdormirii,
  postulCraciunului,
  harti,
  saptamanaBranzei,
  none;

  String get label => switch (this) {
        FastingPeriodKind.postulMare => 'Postul Mare',
        FastingPeriodKind.postulApostolilor =>
          'Postul Sfinților Apostoli Petru și Pavel',
        FastingPeriodKind.postulAdormirii =>
          'Postul Adormirii Maicii Domnului',
        FastingPeriodKind.postulCraciunului => 'Postul Nașterii Domnului',
        FastingPeriodKind.harti => 'Harți',
        FastingPeriodKind.saptamanaBranzei => 'Săptămâna Brânzei',
        FastingPeriodKind.none => '',
      };

  bool get isGreatFast => switch (this) {
        FastingPeriodKind.postulMare ||
        FastingPeriodKind.postulApostolilor ||
        FastingPeriodKind.postulAdormirii ||
        FastingPeriodKind.postulCraciunului =>
          true,
        _ => false,
      };
}
