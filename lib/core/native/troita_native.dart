import 'dart:async';

import 'package:flutter/services.dart';

/// Thin, typed wrapper over the only Dart↔Kotlin boundary in the app.
///
/// Four jobs since the geofencing came out: install the seed database, create
/// the notification channels, hand back a location fix for the map, and pass on
/// the church id from a notification tap. Everything else — church queries,
/// favourites, visits — is Dart against SQLite.
class TroitaNative {
  TroitaNative._();

  static final TroitaNative instance = TroitaNative._();

  static const MethodChannel _channel = MethodChannel('ro.troita/native');

  final StreamController<String> _openedChurch =
      StreamController<String>.broadcast();

  /// Church ids arriving from a notification tap while the app is running.
  Stream<String> get openedChurch => _openedChurch.stream;

  void listen() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onChurchOpened' && call.arguments is String) {
        _openedChurch.add(call.arguments as String);
      }
      return null;
    });
  }

  /// Copies the bundled seed if needed and returns the database path plus the
  /// current permission state. Call once, early.
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

  Future<NativeStatus> status() async => NativeStatus.fromMap(
        Map<String, Object?>.from(
          await _channel.invokeMethod<Map<Object?, Object?>>('status') ??
              <Object?, Object?>{},
        ),
      );

  /// Most recent fused position, or null if unavailable or not permitted.
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

  Future<void> setOnboarded({bool value = true}) => _channel.invokeMethod<void>(
        'setOnboarded',
        <String, Object?>{'value': value},
      );

  /// Church id from the notification that cold-started the app, if any.
  Future<String?> consumePendingChurchId() =>
      _channel.invokeMethod<String>('consumePendingChurchId');
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
    required this.location,
    required this.onboarded,
  });

  /// Foreground location. Optional — only the map needs it.
  final bool location;

  /// Distinct from [location] on purpose: declining location must not send the
  /// user back through onboarding on every launch.
  final bool onboarded;

  static const NativeStatus unknown =
      NativeStatus(location: false, onboarded: false);

  factory NativeStatus.fromMap(Map<String, Object?> map) => NativeStatus(
        location: map['location'] as bool? ?? false,
        onboarded: map['onboarded'] as bool? ?? false,
      );
}

class Position {
  const Position({required this.lat, required this.lon, this.accuracyM = 0});

  final double lat;
  final double lon;
  final double accuracyM;
}
