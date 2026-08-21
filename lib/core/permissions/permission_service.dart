import 'package:permission_handler/permission_handler.dart';

enum LocationGrant { denied, foreground, background, permanentlyDenied }

/// The Android location permission sequence is rigid and the order is not
/// optional:
///
///  1. Ask for fine+coarse location. It must be **granted** first.
///  2. Only then ask for background location. On API 30+ this cannot be a
///     dialog — the OS opens Settings and the user has to pick
///     "Allow all the time" themselves. `permission_handler` returns
///     `permanentlyDenied` for the second request in that situation, which is
///     not actually a permanent denial; it means "go to Settings".
///  3. POST_NOTIFICATIONS separately on API 33+, or the whole app is silent.
///
/// Asking out of order gets you an instant denial with no prompt shown.
class PermissionService {
  const PermissionService();

  Future<bool> hasNotifications() async =>
      await Permission.notification.isGranted;

  Future<bool> requestNotifications() async =>
      (await Permission.notification.request()).isGranted;

  Future<LocationGrant> current() async {
    if (!await Permission.locationWhenInUse.isGranted) {
      return await Permission.locationWhenInUse.isPermanentlyDenied
          ? LocationGrant.permanentlyDenied
          : LocationGrant.denied;
    }
    return await Permission.locationAlways.isGranted
        ? LocationGrant.background
        : LocationGrant.foreground;
  }

  /// Step 1. Enough for journey mode on its own — no background permission,
  /// no Play Console declaration, no OEM battery-manager exposure.
  Future<LocationGrant> requestForeground() async {
    final PermissionStatus status = await Permission.locationWhenInUse.request();
    if (status.isGranted) return LocationGrant.foreground;
    if (status.isPermanentlyDenied) return LocationGrant.permanentlyDenied;
    return LocationGrant.denied;
  }

  /// Step 2. Only call this after [requestForeground] has succeeded and after
  /// showing the prominent disclosure — Play requires the disclosure *before*
  /// the runtime prompt, not after.
  Future<LocationGrant> requestBackground() async {
    if (!await Permission.locationWhenInUse.isGranted) {
      return LocationGrant.denied;
    }
    final PermissionStatus status = await Permission.locationAlways.request();
    if (status.isGranted) return LocationGrant.background;
    // On API 30+ this is the normal outcome: the user must flip the switch in
    // Settings. Treat it as "send them there", not as a dead end.
    return LocationGrant.foreground;
  }

  Future<void> openSettings() => openAppSettings();
}
