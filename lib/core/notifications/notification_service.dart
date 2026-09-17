import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../liturgical/fast_level.dart';
import 'local_timezone.dart';
import 'notification_prefs.dart';

/// Everything scheduled by the app, and the channels they land in.
///
/// Four channels rather than one, because Android only lets the user tune
/// interruption per channel. Somebody who wants to know about Sfântul Nicolae
/// but not about every ordinary commemoration needs two switches in system
/// settings, and one channel cannot give them that.
///
/// Channel ids are versioned: their settings are immutable once created, so
/// changing a vibration pattern means shipping a new id, never editing the old.
class TroitaNotifications {
  TroitaNotifications._();

  static final TroitaNotifications instance = TroitaNotifications._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  static const String channelPraznic = 'troita_praznic_v1';
  static const String channelFeast = 'troita_feast_v1';
  static const String channelDaily = 'troita_daily_v1';
  static const String channelFast = 'troita_fast_v1';

  /// Notification id ranges, so cancelling one kind never touches another.
  static const int _dailyBase = 100000;
  static const int _fastBase = 200000;

  /// Called when the user taps a notification; carries an ISO date.
  ValueChanged<String>? onOpenDay;

  Future<void> initialize() async {
    if (_ready) return;

    tzdata.initializeTimeZones();
    // Romania observes DST, so a fixed UTC offset would drift by an hour twice
    // a year and deliver the morning notification at the wrong time. Resolving
    // to a real IANA zone keeps the wall-clock time stable across the change.
    LocalTimezone.apply();

    await _plugin.initialize(
      settings: const InitializationSettings(
        // Bare resource name, no '@drawable/' prefix. The plugin passes this
        // straight to getIdentifier(name, "drawable", packageName); with the
        // prefix it resolves to 0 and every notification fails silently — no
        // crash, no log at the Dart layer, simply nothing appears.
        android: AndroidInitializationSettings('ic_troita_notification'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? payload = r.payload;
        if (payload != null && payload.isNotEmpty) onOpenDay?.call(payload);
      },
    );

    _ready = true;
  }

  /// The tap that cold-started the app, if any.
  Future<String?> launchPayload() async {
    final NotificationAppLaunchDetails? details =
        await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }

  Future<bool> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<bool> areEnabled() async {
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? false;
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Fires immediately, for checking the pipeline end to end.
  ///
  /// Worth having permanently: the daily notification is scheduled for tomorrow
  /// morning, so without this there is no way to distinguish "working, nothing
  /// due yet" from "silently broken" — which is exactly the state this feature
  /// shipped in.
  Future<void> showTest() async {
    await _plugin.show(
      id: 999999,
      title: 'Troița funcționează',
      body: 'Notificările sunt configurate corect. '
          'Cea zilnică va veni la ora stabilită.',
      notificationDetails: NotificationDetails(
        android: _details(
          channelId: channelFeast,
          channelName: 'Sărbători cu cruce roșie',
          importance: Importance.defaultImportance,
          sound: true,
        ),
      ),
    );
  }

  /// The next scheduled notification, for showing in settings.
  Future<({DateTime? when, String? title, int total})> nextScheduled() async {
    final List<PendingNotificationRequest> queue = await pending();
    // The plugin does not expose scheduled times, but our ids encode the date:
    // base + (yy * 10000 + mm * 100 + dd).
    DateTime? soonest;
    String? title;
    for (final PendingNotificationRequest r in queue) {
      final int key = r.id % 100000;
      final int year = 2000 + key ~/ 10000;
      final int month = (key % 10000) ~/ 100;
      final int day = key % 100;
      if (month < 1 || month > 12 || day < 1 || day > 31) continue;
      final DateTime when = DateTime(year, month, day);
      if (soonest == null || when.isBefore(soonest)) {
        soonest = when;
        title = r.title;
      }
    }
    return (when: soonest, title: title, total: queue.length);
  }

  Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();

  // ------------------------------------------------------------- scheduling

  AndroidNotificationDetails _details({
    required String channelId,
    required String channelName,
    required Importance importance,
    required bool sound,
    String? bigText,
  }) =>
      AndroidNotificationDetails(
        channelId,
        channelName,
        importance: importance,
        priority: importance == Importance.high
            ? Priority.high
            : Priority.defaultPriority,
        playSound: sound,
        enableVibration: importance != Importance.low,
        vibrationPattern: importance == Importance.low
            ? null
            : Int64List.fromList(<int>[0, 110, 90, 110]),
        styleInformation:
            bigText == null ? null : BigTextStyleInformation(bigText),
        // Ordinary commemorations shouldn't put a badge on the launcher every
        // single day — that trains people to ignore it.
        channelShowBadge: importance != Importance.low,
      );

  /// A day's commemoration. [rank] decides how loudly it arrives.
  Future<void> scheduleDaily({
    required DateTime date,
    required FeastRank rank,
    required String title,
    required String body,
    required NotificationPrefs prefs,
  }) async {
    final tz.TZDateTime when = _at(date, prefs.hour, prefs.minute);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;

    final bool major = rank == FeastRank.praznic || rank == FeastRank.cruceRosie;
    final AndroidNotificationDetails android = switch (rank) {
      FeastRank.praznic => _details(
          channelId: channelPraznic,
          channelName: 'Praznice împărătești',
          importance: Importance.high,
          sound: prefs.sound,
          bigText: body,
        ),
      FeastRank.cruceRosie => _details(
          channelId: channelFeast,
          channelName: 'Sărbători cu cruce roșie',
          importance: Importance.defaultImportance,
          sound: prefs.sound,
          bigText: body,
        ),
      _ => _details(
          channelId: channelDaily,
          channelName: 'Pomeniri zilnice',
          importance: Importance.low,
          sound: false,
          bigText: body,
        ),
    };

    await _plugin.zonedSchedule(
      id: _dailyBase + _key(date),
      title: major ? title : 'Sfântul zilei',
      body: major ? body : title,
      scheduledDate: when,
      notificationDetails: NotificationDetails(android: android),
      // Inexact on purpose. Exact alarms need SCHEDULE_EXACT_ALARM on Android
      // 12+, which the user must grant in system settings and which Play
      // scrutinises. A morning reminder that may arrive a few minutes late is
      // not worth that friction.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _iso(date),
    );
  }

  /// The evening before a great fast begins.
  Future<void> scheduleFastReminder({
    required DateTime eveningBefore,
    required DateTime fastStart,
    required String periodLabel,
    required String body,
  }) async {
    final tz.TZDateTime when = _at(eveningBefore, 18, 0);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id: _fastBase + _key(fastStart),
      title: 'Mâine începe $periodLabel',
      body: body,
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        android: _details(
          channelId: channelFast,
          channelName: 'Începutul posturilor',
          importance: Importance.defaultImportance,
          sound: true,
          bigText: body,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _iso(fastStart),
    );
  }

  // ------------------------------------------------------------------ utils

  static tz.TZDateTime _at(DateTime day, int hour, int minute) =>
      tz.TZDateTime(tz.local, day.year, day.month, day.day, hour, minute);

  /// Stable per-date id so rescheduling replaces rather than duplicates.
  static int _key(DateTime d) =>
      (d.year % 100) * 10000 + d.month * 100 + d.day;

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
