import 'package:shared_preferences/shared_preferences.dart';

/// How often the daily commemoration should interrupt.
enum DailyNotificationMode {
  /// No daily notification at all.
  off,

  /// Only Praznice Împărătești and cruce roșie — roughly 90 days a year.
  majorOnly,

  /// Every day of the year.
  everyDay;

  String get label => switch (this) {
        DailyNotificationMode.off => 'Dezactivat',
        DailyNotificationMode.majorOnly => 'Doar sărbătorile mari',
        DailyNotificationMode.everyDay => 'În fiecare zi',
      };

  String get description => switch (this) {
        DailyNotificationMode.off => 'Nicio notificare zilnică.',
        DailyNotificationMode.majorOnly =>
          'Praznice împărătești și sfinți cu cruce roșie.',
        DailyNotificationMode.everyDay =>
          'Sfântul zilei.',
      };
}

/// Notification settings, on the device.
///
/// `shared_preferences` rather than the method channel: this is four values the
/// UI reads and writes constantly, and widening the Dart↔Kotlin boundary for
/// settings would undo the point of keeping it narrow.
class NotificationPrefs {
  const NotificationPrefs({
    this.mode = DailyNotificationMode.majorOnly,
    this.hour = 8,
    this.minute = 0,
    this.fastReminders = true,
    this.hramReminders = true,
    this.sound = true,
    this.gospel = false,
    this.gospelHour = 7,
    this.gospelMinute = 0,
  });

  final DailyNotificationMode mode;

  /// Local time the daily notification fires.
  final int hour;
  final int minute;

  /// The evening before each great fast begins. Never for Wednesday/Friday.
  final bool fastReminders;

  /// The evening before the hram of each favourite church.
  final bool hramReminders;

  /// Sound on major feasts. Ordinary days stay silent regardless.
  final bool sound;

  /// Evanghelia zilei, a notification of its own: off until the user turns it
  /// on, at its own hour. No notification on days without Liturgy (Great Lent
  /// weekdays, Holy Friday).
  final bool gospel;
  final int gospelHour;
  final int gospelMinute;

  static const String _kMode = 'notif_mode';
  static const String _kHour = 'notif_hour';
  static const String _kMinute = 'notif_minute';
  static const String _kFast = 'notif_fast_reminders';
  static const String _kHram = 'notif_hram_reminders';
  static const String _kSound = 'notif_sound';
  static const String _kGospel = 'notif_gospel';
  static const String _kGospelHour = 'notif_gospel_hour';
  static const String _kGospelMinute = 'notif_gospel_minute';

  NotificationPrefs copyWith({
    DailyNotificationMode? mode,
    int? hour,
    int? minute,
    bool? fastReminders,
    bool? hramReminders,
    bool? sound,
    bool? gospel,
    int? gospelHour,
    int? gospelMinute,
  }) =>
      NotificationPrefs(
        mode: mode ?? this.mode,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        fastReminders: fastReminders ?? this.fastReminders,
        hramReminders: hramReminders ?? this.hramReminders,
        sound: sound ?? this.sound,
        gospel: gospel ?? this.gospel,
        gospelHour: gospelHour ?? this.gospelHour,
        gospelMinute: gospelMinute ?? this.gospelMinute,
      );

  static Future<NotificationPrefs> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return NotificationPrefs(
      mode: DailyNotificationMode.values[
          (p.getInt(_kMode) ?? DailyNotificationMode.majorOnly.index)
              .clamp(0, DailyNotificationMode.values.length - 1)],
      hour: (p.getInt(_kHour) ?? 8).clamp(0, 23),
      minute: (p.getInt(_kMinute) ?? 0).clamp(0, 59),
      fastReminders: p.getBool(_kFast) ?? true,
      hramReminders: p.getBool(_kHram) ?? true,
      sound: p.getBool(_kSound) ?? true,
      gospel: p.getBool(_kGospel) ?? false,
      gospelHour: (p.getInt(_kGospelHour) ?? 7).clamp(0, 23),
      gospelMinute: (p.getInt(_kGospelMinute) ?? 0).clamp(0, 59),
    );
  }

  Future<void> save() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setInt(_kMode, mode.index);
    await p.setInt(_kHour, hour);
    await p.setInt(_kMinute, minute);
    await p.setBool(_kFast, fastReminders);
    await p.setBool(_kHram, hramReminders);
    await p.setBool(_kSound, sound);
    await p.setBool(_kGospel, gospel);
    await p.setInt(_kGospelHour, gospelHour);
    await p.setInt(_kGospelMinute, gospelMinute);
  }

  String get timeLabel => _hhmm(hour, minute);

  String get gospelTimeLabel => _hhmm(gospelHour, gospelMinute);

  static String _hhmm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}
