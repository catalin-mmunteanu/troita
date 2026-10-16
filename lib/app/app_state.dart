import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/data/church_marks_repository.dart';
import '../core/data/church_repository.dart';
import '../core/data/day_repository.dart';
import '../core/data/fast_journal_repository.dart';
import '../core/data/feast_repository.dart';
import '../core/data/local_church_repository.dart';
import '../core/models/church.dart';
import '../core/models/fast_day.dart';
import '../core/native/troita_native.dart';
import '../core/notifications/notification_planner.dart';
import '../core/notifications/notification_prefs.dart';
import '../core/notifications/notification_service.dart';
import '../core/permissions/permission_service.dart';
import 'widget_feed.dart';

/// Single app-wide store. Deliberately a plain [ChangeNotifier]: the app has
/// one screen's worth of state and adding a DI framework for it would be noise.
///
/// This will need splitting once favourites and visits land — it is already the
/// widest thing in the app.
class AppState extends ChangeNotifier {
  AppState({
    TroitaNative? native,
    PermissionService permissions = const PermissionService(),
  })  : _native = native ?? TroitaNative.instance,
        _permissions = permissions;

  final TroitaNative _native;
  final PermissionService _permissions;

  ChurchRepository? _repository;
  FeastRepository? _feasts;
  DayRepository? _days;
  FastJournalRepository? _journal;
  ChurchMarksRepository? _marks;
  StreamSubscription<String>? _openedSub;

  ChurchRepository get repository {
    final ChurchRepository? repo = _repository;
    if (repo == null) throw StateError('AppState.initialize() not awaited');
    return repo;
  }

  /// Curated commemorations, read from the same SQLite file as the churches.
  FeastRepository get feasts {
    final FeastRepository? repo = _feasts;
    if (repo == null) throw StateError('AppState.initialize() not awaited');
    return repo;
  }

  /// The calendar's view of a day: feasts, computed liturgics, published
  /// overrides and the bundled sinaxar text, assembled together.
  DayRepository get days {
    final DayRepository? repo = _days;
    if (repo == null) throw StateError('AppState.initialize() not awaited');
    return repo;
  }

  /// The user's record of kept fast days. Lives in its own database, so a
  /// content update never destroys it.
  FastJournalRepository get journal {
    final FastJournalRepository? repo = _journal;
    if (repo == null) throw StateError('AppState.initialize() not awaited');
    return repo;
  }

  /// Favourites and visits. Same database as the journal, for the same reason.
  ChurchMarksRepository get marks {
    final ChurchMarksRepository? repo = _marks;
    if (repo == null) throw StateError('AppState.initialize() not awaited');
    return repo;
  }

  PermissionService get permissions => _permissions;
  TroitaNative get native => _native;

  NativeStatus status = NativeStatus.unknown;
  NotificationPrefs notificationPrefs = const NotificationPrefs();
  PlanResult? lastPlan;
  Map<String, String> seed = <String, String>{};
  bool ready = false;
  String? error;

  /// Church id from a notification tap that still needs routing.
  String? pendingChurchId;

  /// Date from a calendar notification tap that still needs routing.
  DateTime? pendingDate;

  Future<void> initialize() async {
    try {
      _native.listen();
      final InitResult init = await _native.initialize();
      _repository = await LocalChurchRepository.open(init.databasePath);
      // Same file, same read-only connection pool — sqflite hands back the one
      // instance, so this costs nothing beyond the query surface.
      final Database shared = await _openShared(init.databasePath);
      _feasts = FeastRepository(shared);
      _days = DayRepository(shared, _feasts!);
      _journal = await FastJournalRepository.open();
      _marks = await ChurchMarksRepository.open();
      seed = init.seed;
      status = init.status;
      pendingChurchId = await _native.consumePendingChurchId();

      _openedSub = _native.openedChurch.listen((String id) {
        pendingChurchId = id;
        notifyListeners();
      });

      await _initNotifications();

      ready = true;
    } catch (e, st) {
      error = '$e';
      debugPrint('AppState.initialize failed: $e\n$st');
    }
    notifyListeners();
  }

  Future<void> _initNotifications() async {
    final TroitaNotifications notifications = TroitaNotifications.instance;
    await notifications.initialize();
    notifications.onOpenDay = _openDay;

    // A tap that cold-started the app arrives here rather than through the
    // callback, because the callback is registered after the fact.
    _openDay(await notifications.launchPayload());

    notificationPrefs = await NotificationPrefs.load();
    // Fire and forget: scheduling 60 days walks the database, and the first
    // frame should not wait for it.
    unawaited(rescheduleNotifications());
  }

  void _openDay(String? iso) {
    if (iso == null || iso.isEmpty) return;
    final DateTime? parsed = DateTime.tryParse(iso);
    if (parsed == null) return;
    pendingDate = DateTime(parsed.year, parsed.month, parsed.day);
    notifyListeners();
  }

  void consumePendingDate() {
    pendingDate = null;
    notifyListeners();
  }

  DateTime? _lastPlannedAt;

  /// Rebuilds the rolling notification window.
  ///
  /// Not as cheap as it was once described: it cancels every pending
  /// notification, reads sixty days through the repository and makes sixty
  /// platform calls. That is fine at launch and after a settings change, and
  /// wasteful every time someone glances at the app — so a resume only
  /// rebuilds when the day has changed or a few hours have passed. A 60-day
  /// window does not need refreshing more often than that to stay full.
  Future<void> rescheduleNotifications({bool force = true}) async {
    if (_days == null) return;
    final DateTime now = DateTime.now();
    final DateTime? last = _lastPlannedAt;
    if (!force &&
        last != null &&
        last.year == now.year &&
        last.month == now.month &&
        last.day == now.day &&
        now.difference(last) < const Duration(hours: 6)) {
      return;
    }
    _lastPlannedAt = now;
    lastPlan = await NotificationPlanner(
      days,
      TroitaNotifications.instance,
      churches: _repository,
      marks: _marks,
    ).reschedule(notificationPrefs);
    notifyListeners();
    await _refreshWidget();
  }

  /// Hands the home-screen widget its next sixty days. Rides on the same
  /// throttle as the notification window, which needs the same refresh rhythm.
  /// A failure here only means a stale widget, never a broken app.
  Future<void> _refreshWidget() async {
    try {
      await _native.updateWidget(await WidgetFeed.build(days));
    } catch (e) {
      debugPrint('widget refresh failed: $e');
    }
  }

  Future<void> setNotificationPrefs(NotificationPrefs prefs) async {
    notificationPrefs = prefs;
    await prefs.save();
    await rescheduleNotifications();
  }

  Future<bool> requestNotificationPermission() async {
    final bool granted =
        await TroitaNotifications.instance.requestPermission();
    if (granted) await rescheduleNotifications();
    return granted;
  }

  /// Bumped whenever a day is marked, so every screen showing the journal
  /// rebuilds without each one holding its own subscription.
  int journalRevision = 0;

  /// "Ați ținut postul?" — the required answer.
  Future<void> setFastKept(DateTime date, bool kept) async {
    await journal.toggleKept(date, kept);
    journalRevision++;
    notifyListeners();
  }

  /// Bumped whenever a church is marked, so the church page, the Profile list
  /// and the map all pick it up without holding their own subscriptions.
  int marksRevision = 0;

  Future<ChurchMark> setFavourite(String churchId, bool on) async {
    final ChurchMark mark = await marks.setFavourite(churchId, on);
    marksRevision++;
    notifyListeners();
    // Hram reminders are scheduled for favourites, so the window changes too.
    unawaited(rescheduleNotifications());
    return mark;
  }

  Future<ChurchMark> setVisited(String churchId, bool on) async {
    final ChurchMark mark = await marks.setVisited(churchId, on);
    marksRevision++;
    notifyListeners();
    return mark;
  }

  Future<void> refreshStatus() async {
    status = await _native.status();
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await _native.setOnboarded();
    await refreshStatus();
  }

  Future<Church?> church(String id) => repository.byId(id);

  Future<Database> _openShared(String path) =>
      openDatabase(path, readOnly: true);

  void consumePending() {
    pendingChurchId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_openedSub?.cancel());
    super.dispose();
  }
}
