import 'package:shared_preferences/shared_preferences.dart';

/// How much of one kind of notification to send. The same three steps on
/// every row of Setări → Notificări, each with its own meaning per kind
/// ([NotifKind.describe]).
enum NotifLevel {
  all,
  important,
  off;

  String get label => switch (this) {
        NotifLevel.all => 'Toate',
        NotifLevel.important => 'Doar importante',
        NotifLevel.off => 'Oprit',
      };
}

/// Every kind of notification the app sends. The order is the order of the
/// rows in Setări.
enum NotifKind {
  saint,
  gospel,
  dezlegari,
  nameDays,
  hram,
  fasts,
  ajun,
  mosi,
  legale,
  jurnal;

  String get title => switch (this) {
        NotifKind.saint => 'Sfântul zilei',
        NotifKind.gospel => 'Evanghelia zilei',
        NotifKind.dezlegari => 'Dezlegări în post',
        NotifKind.nameDays => 'Zile de nume',
        NotifKind.hram => 'Hramul bisericilor favorite',
        NotifKind.fasts => 'Începutul posturilor',
        NotifKind.ajun => 'Ajunuri și praznice',
        NotifKind.mosi => 'Moșii și pomenirea morților',
        NotifKind.legale => 'Sărbători legale',
        NotifKind.jurnal => '„Ați ținut postul azi?”',
      };

  /// What [level] means for this kind. Null for [NotifLevel.off].
  String? describe(NotifLevel level) => switch ((this, level)) {
        (_, NotifLevel.off) => null,
        (NotifKind.saint, NotifLevel.all) => 'În fiecare dimineață.',
        (NotifKind.saint, _) =>
          'Praznicele împărătești și sfinții cu cruce roșie.',
        (NotifKind.gospel, NotifLevel.all) =>
          'În fiecare zi cu Liturghie, la ora ei.',
        (NotifKind.gospel, _) => 'Duminicile și sărbătorile mari.',
        (NotifKind.dezlegari, NotifLevel.all) =>
          'Dimineața, în zilele de post cu dezlegare la pește sau la '
              'untdelemn și vin.',
        (NotifKind.dezlegari, _) => 'Doar zilele cu dezlegare la pește.',
        (NotifKind.nameDays, NotifLevel.all) =>
          'Pentru numele salvate: cu o seară înainte și în ziua respectivă.',
        (NotifKind.nameDays, _) =>
          'Pentru numele salvate: doar în ziua respectivă.',
        (NotifKind.hram, NotifLevel.all) =>
          'Cu o seară înainte și în ziua hramului.',
        (NotifKind.hram, _) => 'Cu o seară înainte.',
        (NotifKind.fasts, NotifLevel.all) =>
          'Cu o seară înainte: cele patru posturi mari și zilele de post '
              'de 5 ianuarie, 29 august și 14 septembrie.',
        (NotifKind.fasts, _) =>
          'Cu o seară înainte, pentru cele patru posturi mari.',
        (NotifKind.ajun, NotifLevel.all) =>
          'Ajunul Crăciunului, al Bobotezei și Sâmbăta Mare, plus seara '
              'dinaintea fiecărui praznic împărătesc.',
        (NotifKind.ajun, _) =>
          'Ajunul Crăciunului, al Bobotezei și Sâmbăta Mare.',
        (NotifKind.mosi, NotifLevel.all) =>
          'Cu o seară înainte: Moșii și toate sâmbetele morților.',
        (NotifKind.mosi, _) => 'Cu o seară înainte, doar Moșii.',
        (NotifKind.legale, NotifLevel.all) =>
          'Cu o seară înainte, toate zilele libere legale.',
        (NotifKind.legale, _) =>
          'Cu o seară înainte, doar cele care cad într-o zi lucrătoare.',
        (NotifKind.jurnal, NotifLevel.all) =>
          'Seara, în fiecare zi de post, miercurea și vinerea incluse.',
        (NotifKind.jurnal, _) => 'Seara, doar în cele patru posturi mari.',
      };

  /// For a new install.
  NotifLevel get defaultLevel => switch (this) {
        NotifKind.saint => NotifLevel.important,
        // Adding a name is already the opt-in.
        NotifKind.nameDays => NotifLevel.all,
        NotifKind.fasts => NotifLevel.important,
        NotifKind.hram => NotifLevel.important,
        _ => NotifLevel.off,
      };
}

/// Notification settings, on the device.
///
/// `shared_preferences` rather than the method channel: a handful of values
/// the UI reads and writes constantly, and widening the Dart↔Kotlin boundary
/// for settings would undo the point of keeping it narrow.
class NotificationPrefs {
  const NotificationPrefs({
    this.levels = const <NotifKind, NotifLevel>{},
    this.hour = 8,
    this.minute = 0,
    this.eveningHour = 19,
    this.eveningMinute = 0,
    this.sound = true,
    this.gospelHour = 7,
    this.gospelMinute = 0,
  });

  /// Only the kinds set by the user; the rest use [NotifKind.defaultLevel].
  final Map<NotifKind, NotifLevel> levels;

  /// Morning: what happens today (saint, dezlegări, name days, hram, ajun).
  final int hour;
  final int minute;

  /// Evening: what happens tomorrow (fasts, hram, name days, Moși, legale)
  /// and the journal question.
  final int eveningHour;
  final int eveningMinute;

  /// Sound on major feasts. Ordinary days stay silent regardless.
  final bool sound;

  /// Evanghelia zilei keeps an hour of its own.
  final int gospelHour;
  final int gospelMinute;

  NotifLevel level(NotifKind kind) => levels[kind] ?? kind.defaultLevel;

  bool on(NotifKind kind) => level(kind) != NotifLevel.off;

  /// The level every kind shares, or null when they differ.
  NotifLevel? get common {
    final Set<NotifLevel> used = NotifKind.values.map(level).toSet();
    return used.length == 1 ? used.first : null;
  }

  NotificationPrefs withLevel(NotifKind kind, NotifLevel value) =>
      copyWith(levels: <NotifKind, NotifLevel>{...levels, kind: value});

  NotificationPrefs withAll(NotifLevel value) => copyWith(
      levels: <NotifKind, NotifLevel>{
        for (final NotifKind k in NotifKind.values) k: value,
      });

  static const String _kHour = 'notif_hour';
  static const String _kMinute = 'notif_minute';
  static const String _kEveningHour = 'notif_evening_hour';
  static const String _kEveningMinute = 'notif_evening_minute';
  static const String _kSound = 'notif_sound';
  static const String _kGospelHour = 'notif_gospel_hour';
  static const String _kGospelMinute = 'notif_gospel_minute';
  static String _kLevel(NotifKind k) => 'notif_level_${k.name}';

  // Before the levels: read once, to carry an old install's choices over.
  static const String _kOldMode = 'notif_mode';
  static const String _kOldFast = 'notif_fast_reminders';
  static const String _kOldHram = 'notif_hram_reminders';
  static const String _kOldGospel = 'notif_gospel';

  NotificationPrefs copyWith({
    Map<NotifKind, NotifLevel>? levels,
    int? hour,
    int? minute,
    int? eveningHour,
    int? eveningMinute,
    bool? sound,
    int? gospelHour,
    int? gospelMinute,
  }) =>
      NotificationPrefs(
        levels: levels ?? this.levels,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        eveningHour: eveningHour ?? this.eveningHour,
        eveningMinute: eveningMinute ?? this.eveningMinute,
        sound: sound ?? this.sound,
        gospelHour: gospelHour ?? this.gospelHour,
        gospelMinute: gospelMinute ?? this.gospelMinute,
      );

  static Future<NotificationPrefs> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return fromStore(
      getInt: p.getInt,
      getBool: p.getBool,
      getString: p.getString,
    );
  }

  /// [load] without the plugin, for tests.
  static NotificationPrefs fromStore({
    required int? Function(String) getInt,
    required bool? Function(String) getBool,
    required String? Function(String) getString,
  }) {
    final Map<NotifKind, NotifLevel> levels = <NotifKind, NotifLevel>{};
    for (final NotifKind k in NotifKind.values) {
      final NotifLevel? chosen =
          _parse(getString(_kLevel(k))) ?? _old(k, getInt, getBool);
      if (chosen != null) levels[k] = chosen;
    }
    return NotificationPrefs(
      levels: levels,
      hour: (getInt(_kHour) ?? 8).clamp(0, 23),
      minute: (getInt(_kMinute) ?? 0).clamp(0, 59),
      eveningHour: (getInt(_kEveningHour) ?? 19).clamp(0, 23),
      eveningMinute: (getInt(_kEveningMinute) ?? 0).clamp(0, 59),
      sound: getBool(_kSound) ?? true,
      gospelHour: (getInt(_kGospelHour) ?? 7).clamp(0, 23),
      gospelMinute: (getInt(_kGospelMinute) ?? 0).clamp(0, 59),
    );
  }

  static NotifLevel? _parse(String? raw) {
    for (final NotifLevel l in NotifLevel.values) {
      if (l.name == raw) return l;
    }
    return null;
  }

  /// The settings of the version before the levels.
  static NotifLevel? _old(NotifKind k, int? Function(String) getInt,
      bool? Function(String) getBool) {
    NotifLevel? fromSwitch(bool? on) =>
        on == null ? null : (on ? NotifLevel.important : NotifLevel.off);
    return switch (k) {
      // off · majorOnly · everyDay, by index.
      NotifKind.saint => switch (getInt(_kOldMode)) {
          0 => NotifLevel.off,
          1 => NotifLevel.important,
          2 => NotifLevel.all,
          _ => null,
        },
      NotifKind.gospel => switch (getBool(_kOldGospel)) {
          true => NotifLevel.all,
          false => NotifLevel.off,
          null => null,
        },
      NotifKind.fasts => fromSwitch(getBool(_kOldFast)),
      NotifKind.hram => fromSwitch(getBool(_kOldHram)),
      _ => null,
    };
  }

  Future<void> save() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    for (final NotifKind k in NotifKind.values) {
      await p.setString(_kLevel(k), level(k).name);
    }
    await p.setInt(_kHour, hour);
    await p.setInt(_kMinute, minute);
    await p.setInt(_kEveningHour, eveningHour);
    await p.setInt(_kEveningMinute, eveningMinute);
    await p.setBool(_kSound, sound);
    await p.setInt(_kGospelHour, gospelHour);
    await p.setInt(_kGospelMinute, gospelMinute);
  }

  String get timeLabel => _hhmm(hour, minute);

  String get eveningTimeLabel => _hhmm(eveningHour, eveningMinute);

  String get gospelTimeLabel => _hhmm(gospelHour, gospelMinute);

  static String _hhmm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}
