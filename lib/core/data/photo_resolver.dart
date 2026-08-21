import 'package:flutter/widgets.dart';

/// Turns a stored `photo_ref` into an [ImageProvider].
///
/// The indirection is the point: today every reference is `asset://…` because
/// the images ship in the APK; once there is a CDN they become `https://…` and
/// nothing outside this file changes.
class PhotoResolver {
  const PhotoResolver._();

  static ImageProvider? resolve(String? photoRef) {
    if (photoRef == null || photoRef.isEmpty) return null;
    if (photoRef.startsWith('asset://')) {
      return AssetImage('assets/${photoRef.substring(8)}');
    }
    if (photoRef.startsWith('http://') || photoRef.startsWith('https://')) {
      return NetworkImage(photoRef);
    }
    return null;
  }
}
