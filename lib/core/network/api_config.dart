/// Environment-driven API configuration.
///
/// Recommended usage:
/// - Dev (emulator/real device): `flutter run --dart-define-from-file=env/dev.json`
/// - Release APK: `flutter build apk --release --split-per-abi --dart-define-from-file=env/dev.json`
///
/// You may also override with:
/// - `--dart-define=API_BASE_URL=http://<IP>:3000`
class ApiConfig {
  // Defaults (only used when no dart-defines are provided)
  static const String _lanHost = 'http://192.168.10.111:3000';

  /// API base URL (without trailing slash), e.g. `http://192.168.10.111:3000`
  static String get host {
    const fromBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromBase.isNotEmpty) return fromBase;

    const fromHost = String.fromEnvironment('API_HOST', defaultValue: '');
    if (fromHost.isNotEmpty) return fromHost;

    return _lanHost;
  }

  /// Common base
  static String get apiV1 => '$host/api/v1';

  /// ✅ User scoped base
  static String get userApi => '$apiV1/user';
}
