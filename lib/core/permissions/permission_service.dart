import 'package:permission_handler/permission_handler.dart';

/// Two permissions, both foreground.
///
/// Background location went away with journey mode and passive geofencing, and
/// with it the strict request ordering, the settings-page redirect on API 30+,
/// the Play Console declaration and the review video. What is left is ordinary.
class PermissionService {
  const PermissionService();

  Future<bool> hasLocation() async =>
      await Permission.locationWhenInUse.isGranted;

  /// Enough to centre the map on the user. Nothing in the app needs more.
  Future<bool> requestLocation() async =>
      (await Permission.locationWhenInUse.request()).isGranted;

  Future<bool> locationPermanentlyDenied() async =>
      await Permission.locationWhenInUse.isPermanentlyDenied;

  Future<bool> hasNotifications() async =>
      await Permission.notification.isGranted;

  Future<bool> requestNotifications() async =>
      (await Permission.notification.request()).isGranted;

  Future<void> openSettings() => openAppSettings();
}
