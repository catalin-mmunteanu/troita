import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/data/church_repository.dart';
import '../core/data/day_repository.dart';
import '../core/data/feast_repository.dart';
import '../core/data/local_church_repository.dart';
import '../core/models/church.dart';
import '../core/native/troita_native.dart';
import '../core/notifications/notification_planner.dart';
import '../core/notifications/notification_prefs.dart';
import '../core/notifications/notification_service.dart';
import '../core/permissions/permission_service.dart';

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

  /// Rebuilds the rolling notification window. Cheap enough to call on every
  /// resume, and that is what keeps the window from running out.
  Future<void> rescheduleNotifications() async {
    if (_days == null) return;
    lastPlan = await NotificationPlanner(days, TroitaNotifications.instance)
        .reschedule(notificationPrefs);
    notifyListeners();
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
