import 'package:permission_handler/permission_handler.dart';

/// One permission: notifications.
///
/// Location used to be here too, requested at onboarding "to centre the map".
/// The map never asked for a position — the only caller was a screen nothing
/// navigated to — so every user was being asked for location for nothing. An
/// unused location permission is a Play review question and, more to the
/// point, a request people are right to be wary of. It goes back only with a
/// feature that uses it, asked for at the moment that feature needs it.
class PermissionService {
  const PermissionService();

  Future<bool> hasNotifications() async =>
      await Permission.notification.isGranted;

  Future<bool> requestNotifications() async =>
      (await Permission.notification.request()).isGranted;

  Future<void> openSettings() => openAppSettings();
}
