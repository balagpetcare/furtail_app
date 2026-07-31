import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:furtail_app/features/common/data/services/gps_location_service.dart';

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.always;
  LocationPermission? requestResult;
  Position? position;
  Duration? positionDelay;
  Object? positionError;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async =>
      requestResult ?? permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (positionDelay != null) await Future.delayed(positionDelay!);
    if (positionError != null) throw positionError!;
    return position!;
  }

  @override
  Future<bool> openAppSettings() async => true;
}

Position _pos(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.now(),
  accuracy: 1,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);

void main() {
  late _FakeGeolocatorPlatform fake;

  setUp(() {
    fake = _FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fake;
  });

  group('GpsLocationService permission/service states', () {
    test(
      'service disabled -> serviceDisabled result, no exception text leaked',
      () async {
        fake.serviceEnabled = false;
        final result = await const GpsLocationService()
            .captureCurrentPosition();
        expect(result.status, GpsResultStatus.serviceDisabled);
        expect(result.isSuccess, isFalse);
        expect(result.message, isNot(contains('Exception')));
      },
    );

    test(
      'permission denied (stays denied after request) -> denied result',
      () async {
        fake.permission = LocationPermission.denied;
        fake.requestResult = LocationPermission.denied;
        final result = await const GpsLocationService()
            .captureCurrentPosition();
        expect(result.status, GpsResultStatus.denied);
      },
    );

    test(
      'permission denied forever -> deniedForever result with settings guidance',
      () async {
        fake.permission = LocationPermission.deniedForever;
        final result = await const GpsLocationService()
            .captureCurrentPosition();
        expect(result.status, GpsResultStatus.deniedForever);
        expect(result.message, contains('Settings'));
      },
    );

    test(
      'not requested (denied) then granted on request -> proceeds to capture',
      () async {
        fake.permission = LocationPermission.denied;
        fake.requestResult = LocationPermission.always;
        fake.position = _pos(23.8, 90.4);
        final result = await const GpsLocationService()
            .captureCurrentPosition();
        expect(result.status, GpsResultStatus.success);
        expect(result.latitude, 23.8);
        expect(result.longitude, 90.4);
      },
    );

    test('successful capture returns coordinates', () async {
      fake.position = _pos(23.81, 90.41);
      final result = await const GpsLocationService().captureCurrentPosition();
      expect(result.isSuccess, isTrue);
      expect(result.latitude, 23.81);
      expect(result.longitude, 90.41);
    });

    test(
      'timeout maps to a friendly retryable message, never raw TimeoutException text',
      () async {
        fake.positionDelay = const Duration(milliseconds: 50);
        fake.position = _pos(1, 1);
        final service = GpsLocationService(
          timeout: const Duration(milliseconds: 5),
        );
        final result = await service.captureCurrentPosition();
        expect(result.status, GpsResultStatus.timeout);
        expect(result.message, isNot(contains('TimeoutException')));
        expect(result.message, contains('try again'));
      },
    );

    test('unexpected platform error never leaks raw exception text', () async {
      fake.positionError = StateError(
        'some raw platform channel failure detail',
      );
      final result = await const GpsLocationService().captureCurrentPosition();
      expect(result.status, GpsResultStatus.failure);
      expect(result.message, isNot(contains('platform channel')));
    });

    test(
      'default timeout is configurable and reasonable (not the old hard ~6s)',
      () {
        const service = GpsLocationService();
        expect(service.timeout, greaterThan(const Duration(seconds: 6)));
      },
    );
  });
}
