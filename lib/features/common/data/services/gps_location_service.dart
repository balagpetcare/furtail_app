import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// All possible outcomes of a GPS capture attempt. Keeping these as a closed
/// set (rather than a raw exception message) is what lets the UI show a
/// specific, actionable state instead of leaking exception text.
enum GpsResultStatus {
  success,
  notRequested,
  denied,
  deniedForever,
  serviceDisabled,
  timeout,
  failure,
}

class GpsResult {
  const GpsResult._(this.status, {this.latitude, this.longitude, this.message});

  final GpsResultStatus status;
  final double? latitude;
  final double? longitude;
  final String? message;

  bool get isSuccess => status == GpsResultStatus.success;

  factory GpsResult.success(double latitude, double longitude) => GpsResult._(
    GpsResultStatus.success,
    latitude: latitude,
    longitude: longitude,
  );

  factory GpsResult.denied() => const GpsResult._(
    GpsResultStatus.denied,
    message: 'Location permission was denied.',
  );

  factory GpsResult.deniedForever() => const GpsResult._(
    GpsResultStatus.deniedForever,
    message:
        'Location permission is permanently denied. Enable it in Settings.',
  );

  factory GpsResult.serviceDisabled() => const GpsResult._(
    GpsResultStatus.serviceDisabled,
    message: 'Location services are turned off on this device.',
  );

  factory GpsResult.timeout() => const GpsResult._(
    GpsResultStatus.timeout,
    message:
        'Could not get a GPS fix in time. You can try again or enter the location manually.',
  );

  factory GpsResult.failure([String? reason]) => GpsResult._(
    GpsResultStatus.failure,
    message:
        reason ?? 'Could not capture your location. You can enter it manually.',
  );
}

/// GPS capture is always optional relative to the rest of the form — every
/// caller must be able to proceed (submit, pick location manually) whether
/// or not this succeeds. The timeout is configurable (not a fixed ~6s) and
/// failures never leak a raw exception/TimeoutException string to the UI;
/// they're mapped to a closed [GpsResultStatus] with a human-readable
/// [GpsResult.message].
class GpsLocationService {
  const GpsLocationService({
    this.timeout = const Duration(seconds: 15),
    this.accuracy = LocationAccuracy.medium,
  });

  final Duration timeout;
  final LocationAccuracy accuracy;

  Future<GpsResult> captureCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return GpsResult.serviceDisabled();

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return GpsResult.denied();
      }
      if (permission == LocationPermission.deniedForever) {
        return GpsResult.deniedForever();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy),
      ).timeout(timeout);

      return GpsResult.success(position.latitude, position.longitude);
    } on TimeoutException {
      return GpsResult.timeout();
    } catch (_) {
      // Never surface the raw exception (e.g. platform channel error text)
      // to the user — GPS is optional, so a generic retryable failure is
      // always the right fallback.
      return GpsResult.failure();
    }
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
