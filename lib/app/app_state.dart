import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/data/church_repository.dart';
import '../core/data/local_church_repository.dart';
import '../core/models/church.dart';
import '../core/native/troita_native.dart';
import '../core/permissions/permission_service.dart';

/// Single app-wide store. Deliberately a plain [ChangeNotifier]: the app has
/// one screen's worth of state and adding a DI framework for it would be noise.
class AppState extends ChangeNotifier {
  AppState({
    TroitaNative? native,
    PermissionService permissions = const PermissionService(),
  })  : _native = native ?? TroitaNative.instance,
        _permissions = permissions;

  final TroitaNative _native;
  final PermissionService _permissions;

  ChurchRepository? _repository;
  StreamSubscription<JourneyState>? _journeySub;
  StreamSubscription<String>? _openedSub;

  ChurchRepository get repository {
    final ChurchRepository? repo = _repository;
    if (repo == null) throw StateError('AppState.initialize() not awaited');
    return repo;
  }

  PermissionService get permissions => _permissions;
  TroitaNative get native => _native;

  NativeStatus status = NativeStatus.unknown;
  JourneyState journey = JourneyState.idle;
  OemInfo? oem;
  Map<String, String> seed = <String, String>{};
  bool ready = false;
  String? error;

  /// Church id from a notification tap that still needs routing.
  String? pendingChurchId;

  Future<void> initialize() async {
    try {
      _native.listen();
      final InitResult init = await _native.initialize();
      _repository = await LocalChurchRepository.open(init.databasePath);
      seed = init.seed;
      status = init.status;
      oem = await _native.oemVendor();
      pendingChurchId = await _native.consumePendingChurchId();

      _openedSub = _native.openedChurch.listen((String id) {
        pendingChurchId = id;
        notifyListeners();
      });
      _journeySub = _native.journey.listen((JourneyState s) {
        journey = s;
        notifyListeners();
      });

      ready = true;
    } catch (e, st) {
      error = '$e';
      debugPrint('AppState.initialize failed: $e\n$st');
    }
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    status = await _native.status();
    oem = await _native.oemVendor();
    notifyListeners();
  }

  Future<void> startJourney() async {
    await _native.startJourney();
    await refreshStatus();
  }

  Future<void> stopJourney() async {
    await _native.stopJourney();
    journey = JourneyState.idle;
    await refreshStatus();
  }

  Future<WindowResult> setPassive(bool enabled) async {
    final WindowResult result = await _native.setPassiveEnabled(enabled);
    await refreshStatus();
    return result;
  }

  Future<void> setSound(bool enabled) async {
    await _native.setSoundEnabled(enabled);
    await refreshStatus();
  }

  Future<Church?> church(String id) => repository.byId(id);

  void consumePending() {
    pendingChurchId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_journeySub?.cancel());
    unawaited(_openedSub?.cancel());
    super.dispose();
  }
}
