/// Environment-driven app endpoints (API, media, socket).
///
/// Recommended usage:
/// - Dev (emulator/real device): `flutter run --dart-define-from-file=env/dev.json`
/// - Release APK: `flutter build apk --release --split-per-abi --dart-define-from-file=env/dev.json`
class AppConfig {
  static const String _lanApi = 'http://192.168.10.111:3000';
  static const String _lanMedia = 'http://192.168.10.111:9000';

  static String get apiBaseUrl {
    const v = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (v.isNotEmpty) return v;
    return _lanApi;
  }

  static String get mediaBaseUrl {
    const v = String.fromEnvironment('MEDIA_BASE_URL', defaultValue: '');
    if (v.isNotEmpty) return v;
    return _lanMedia;
  }

  static String get socketUrl {
    const v = String.fromEnvironment('SOCKET_URL', defaultValue: '');
    if (v.isNotEmpty) return v;
    return apiBaseUrl;
  }

  /// API prefix for v1
  static String get apiV1 => '$apiBaseUrl/api/v1';
}
