import 'dart:async';

import 'package:flutter/services.dart';

/// Thin, typed wrapper over the only Dart↔Kotlin boundary in the app.
///
/// Three jobs: install the seed database, report onboarding status, and pass
/// on the church id from a notification tap. Everything else — church queries,
/// favourites, visits — is Dart against SQLite.
///
/// The location call that used to live here served only a screen nothing
/// navigated to, while onboarding asked every user for location "for the map".
/// It is gone along with the permission. If the map ever needs a position,
/// MapLibre's own location component asks for it at the moment it is used.
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
  const NativeStatus({required this.onboarded});

  /// Whether the user has been through onboarding. Gated on this rather than on
  /// any permission, so declining one never sends them back through it.
  final bool onboarded;

  static const NativeStatus unknown = NativeStatus(onboarded: false);

  factory NativeStatus.fromMap(Map<String, Object?> map) => NativeStatus(
        onboarded: map['onboarded'] as bool? ?? false,
      );
}
