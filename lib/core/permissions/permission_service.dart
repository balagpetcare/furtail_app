import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

enum AppPermission {
  locationWhenInUse,
  microphone,
  camera,
  contacts,
  photos, // iOS photos / Android media images
  storage, // legacy; generally avoid using directly
}

class PermissionService {
  /// One API to request any permission
  Future<bool> ensure(AppPermission p) async {
    switch (p) {
      case AppPermission.locationWhenInUse:
        return _ensureLocation();
      case AppPermission.microphone:
        return _ensurePermission(Permission.microphone);
      case AppPermission.camera:
        return _ensurePermission(Permission.camera);
      case AppPermission.contacts:
        return _ensurePermission(Permission.contacts);
      case AppPermission.photos:
        // Android 13+ uses photos; older uses storage (read external)
        return _ensurePermission(Permission.photos);
      case AppPermission.storage:
        return _ensurePermission(Permission.storage);
    }
  }

  /// Location needs extra check: service enabled + permission
  Future<bool> _ensureLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // user must enable GPS manually
      return false;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied) return false;
    if (perm == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<bool> _ensurePermission(Permission permission) async {
    var status = await permission.status;

    if (status.isGranted) return true;

    if (status.isDenied || status.isRestricted || status.isLimited) {
      status = await permission.request();
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      // Must open settings
      return false;
    }

    return false;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}
