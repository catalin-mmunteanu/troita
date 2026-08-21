import 'dart:async';

import 'package:flutter/services.dart';

/// Thin, typed wrapper over the only Dart↔Kotlin boundary in the app.
///
/// Everything here is *control plane*: enable passive mode, start a journey,
/// ask what the OS thinks our permissions are. The data plane — geofence
/// transitions, church lookups, notifications — never crosses this channel.
/// That is the whole point: if the Flutter engine is dead, notifications still
/// work, because nothing on that path needs Dart.
class TroitaNative {
  TroitaNative._();

  static final TroitaNative instance = TroitaNative._();

  static const MethodChannel _channel = MethodChannel('ro.troita/native');
  static const EventChannel _journeyEvents = EventChannel('ro.troita/journey');

  final StreamController<String> _openedChurch =
      StreamController<String>.broadcast();

  /// Church ids arriving from a notification tap while the app is running.
  Stream<String> get openedChurch => _openedChurch.stream;

  Stream<JourneyState> get journey =>
      _journeyEvents.receiveBroadcastStream().map(
            (dynamic e) =>
                JourneyState.fromMap(Map<String, Object?>.from(e as Map)),
          );

  void listen() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onChurchOpened' && call.arguments is String) {
        _openedChurch.add(call.arguments as String);
      }
      return null;
    });
  }

  /// Copies the bundled seed if needed and returns the database path plus the
  /// current permission/window state. Call once, early.
  Future<InitResult> initialize() async {
    final Map<Object?, Object?> raw =
        await _channel.invokeMethod<Map<Object?, Object?>>('initialize') ??
            <Object?, Object?>{};
    return InitResult(
      databasePath: raw['database_path']! as String,
      seed: Map<String, String>.from(raw['seed'] as Map),
      status:
          NativeStatus.fromMap(Map<String, Object?>.from(raw['status'] as Map)),
    );
  }

  /// Last/most recent fused position, or null if unavailable or not permitted.
  Future<Position?> currentLocation() async {
    final Map<Object?, Object?>? raw =
        await _channel.invokeMethod<Map<Object?, Object?>>('currentLocation');
    if (raw == null) return null;
    return Position(
      lat: (raw['lat']! as num).toDouble(),
      lon: (raw['lon']! as num).toDouble(),
      accuracyM: (raw['accuracy_m'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<NativeStatus> status() async => NativeStatus.fromMap(
        Map<String, Object?>.from(
          await _channel.invokeMethod<Map<Object?, Object?>>('status') ??
              <Object?, Object?>{},
        ),
      );

  /// Rebuilds the geofence window around the current position.
  Future<WindowResult> refreshWindow() async => WindowResult.fromMap(
        Map<String, Object?>.from(
          await _channel.invokeMethod<Map<Object?, Object?>>('refreshWindow') ??
              <Object?, Object?>{},
        ),
      );

  Future<WindowResult> setPassiveEnabled(bool enabled) async =>
      WindowResult.fromMap(
        Map<String, Object?>.from(
          await _channel.invokeMethod<Map<Object?, Object?>>(
                'setPassiveEnabled',
                <String, Object?>{'enabled': enabled},
              ) ??
              <Object?, Object?>{},
        ),
      );

  Future<void> setSoundEnabled(bool enabled) => _channel.invokeMethod<void>(
        'setSoundEnabled',
        <String, Object?>{'enabled': enabled},
      );

  Future<void> startJourney() => _channel.invokeMethod<void>('startJourney');

  Future<void> stopJourney() => _channel.invokeMethod<void>('stopJourney');

  /// Church id from the notification that cold-started the app, if any.
  Future<String?> consumePendingChurchId() =>
      _channel.invokeMethod<String>('consumePendingChurchId');

  Future<void> markOpened(String id) =>
      _channel.invokeMethod<void>('markOpened', <String, Object?>{'id': id});

  Future<List<Map<String, Object?>>> recentEncounters() async {
    final List<Object?> rows =
        await _channel.invokeMethod<List<Object?>>('recentEncounters') ??
            <Object?>[];
    return rows
        .map((dynamic r) => Map<String, Object?>.from(r as Map))
        .toList(growable: false);
  }

  Future<OemInfo> oemVendor() async => OemInfo.fromMap(
        Map<String, Object?>.from(
          await _channel.invokeMethod<Map<Object?, Object?>>('oemVendor') ??
              <Object?, Object?>{},
        ),
      );

  Future<bool> openAutostartSettings() async =>
      await _channel.invokeMethod<bool>('openAutostartSettings') ?? false;

  Future<bool> openBatterySettings() async =>
      await _channel.invokeMethod<bool>('openBatterySettings') ?? false;

  Future<bool> openAppDetails() async =>
      await _channel.invokeMethod<bool>('openAppDetails') ?? false;

  Future<bool> openLocationSettings() async =>
      await _channel.invokeMethod<bool>('openLocationSettings') ?? false;

  Future<bool> openNotificationSettings(String channel) async =>
      await _channel.invokeMethod<bool>(
        'openNotificationSettings',
        <String, Object?>{'channel': channel},
      ) ??
      false;
}

class InitResult {
  const InitResult({
    required this.databasePath,
    required this.seed,
    required this.status,
  });

  final String databasePath;
  final Map<String, String> seed;
  final NativeStatus status;
}

class NativeStatus {
  const NativeStatus({
    required this.foregroundLocation,
    required this.backgroundLocation,
    required this.passiveEnabled,
    required this.soundEnabled,
    required this.journeyActive,
    required this.batteryOptimised,
    required this.windowCount,
    required this.windowRadiusM,
    required this.windowUpdatedAt,
    required this.windowDirty,
  });

  final bool foregroundLocation;
  final bool backgroundLocation;
  final bool passiveEnabled;
  final bool soundEnabled;
  final bool journeyActive;

  /// True when the OS may still throttle us. Not fatal, but the main cause of
  /// "it stopped working after a few days" reports on Samsung and Xiaomi.
  final bool batteryOptimised;

  final int windowCount;
  final double windowRadiusM;
  final DateTime? windowUpdatedAt;
  final bool windowDirty;

  static const NativeStatus unknown = NativeStatus(
    foregroundLocation: false,
    backgroundLocation: false,
    passiveEnabled: false,
    soundEnabled: false,
    journeyActive: false,
    batteryOptimised: false,
    windowCount: 0,
    windowRadiusM: 0,
    windowUpdatedAt: null,
    windowDirty: false,
  );

  factory NativeStatus.fromMap(Map<String, Object?> map) {
    final Map<String, Object?> window = Map<String, Object?>.from(
      (map['window'] as Map?) ?? <String, Object?>{},
    );
    final int updated = (window['updated_at'] as num?)?.toInt() ?? 0;
    return NativeStatus(
      foregroundLocation: map['foreground_location'] as bool? ?? false,
      backgroundLocation: map['background_location'] as bool? ?? false,
      passiveEnabled: map['passive_enabled'] as bool? ?? false,
      soundEnabled: map['sound_enabled'] as bool? ?? false,
      journeyActive: map['journey_active'] as bool? ?? false,
      batteryOptimised: map['battery_optimised'] as bool? ?? false,
      windowCount: (window['count'] as num?)?.toInt() ?? 0,
      windowRadiusM: (window['radius_m'] as num?)?.toDouble() ?? 0,
      windowUpdatedAt:
          updated == 0 ? null : DateTime.fromMillisecondsSinceEpoch(updated),
      windowDirty: window['dirty'] as bool? ?? false,
    );
  }
}

class WindowResult {
  const WindowResult({required this.ok, this.registered = 0, this.reason});

  final bool ok;
  final int registered;

  /// One of `permission`, `location`, `no_churches`, or a raw Play services error.
  final String? reason;

  factory WindowResult.fromMap(Map<String, Object?> map) => WindowResult(
        ok: map['ok'] as bool? ?? false,
        registered: (map['registered'] as num?)?.toInt() ?? 0,
        reason: map['reason'] as String?,
      );
}

class JourneyState {
  const JourneyState({
    required this.active,
    this.notified = 0,
    this.candidates = 0,
  });

  final bool active;
  final int notified;
  final int candidates;

  static const JourneyState idle = JourneyState(active: false);

  factory JourneyState.fromMap(Map<String, Object?> map) => JourneyState(
        active: map['active'] as bool? ?? false,
        notified: (map['notified'] as num?)?.toInt() ?? 0,
        candidates: (map['candidates'] as num?)?.toInt() ?? 0,
      );
}

class OemInfo {
  const OemInfo({
    required this.id,
    required this.label,
    required this.needsAutostart,
    required this.batteryOptimised,
  });

  final String id;
  final String label;
  final bool needsAutostart;
  final bool batteryOptimised;

  bool get isAggressive => needsAutostart || id == 'samsung';

  factory OemInfo.fromMap(Map<String, Object?> map) => OemInfo(
        id: map['id'] as String? ?? 'generic',
        label: map['label'] as String? ?? '',
        needsAutostart: map['needs_autostart'] as bool? ?? false,
        batteryOptimised: map['battery_optimised'] as bool? ?? false,
      );
}

class Position {
  const Position({required this.lat, required this.lon, this.accuracyM = 0});

  final double lat;
  final double lon;
  final double accuracyM;
}
