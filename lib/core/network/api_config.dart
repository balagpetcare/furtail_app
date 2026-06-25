import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Environment-driven API configuration.
///
/// Recommended usage:
/// - Physical device: `flutter run --dart-define-from-file=env/mobile-dev.json`
/// - Emulator:        `flutter run --dart-define-from-file=env/emulator-dev.json`
/// - Or override:     `--dart-define=API_BASE_URL=http://192.168.10.108:7200/api/v1`
///
/// API_BASE_URL may include or omit the /api/v1 suffix — both forms are handled.
class ApiConfig {
  /// API base host (without /api/v1), e.g. `http://192.168.10.108:7200`
  static String get host {
    const fromBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromBase.isNotEmpty) {
      return _resolveLocalhost(_stripApiV1(fromBase));
    }

    const fromHost = String.fromEnvironment('API_HOST', defaultValue: '');
    if (fromHost.isNotEmpty) {
      return _resolveLocalhost(_stripApiV1(fromHost));
    }

    // Default fallback when no dart-define is set
    if (kIsWeb) {
      return 'http://localhost:7200';
    } else if (Platform.isAndroid) {
      return 'http://192.168.10.108:7200';
    } else {
      return 'http://localhost:7200';
    }
  }

  /// Strip trailing /api/v1 so callers can pass the full URL or just the host.
  static String _stripApiV1(String url) {
    const suffix = '/api/v1';
    return url.endsWith(suffix) ? url.substring(0, url.length - suffix.length) : url;
  }

  static String _resolveLocalhost(String url) {
    if (!kIsWeb && Platform.isAndroid) {
      return url
          .replaceAll('localhost', '10.0.2.2')
          .replaceAll('127.0.0.1', '10.0.2.2');
    }
    return url;
  }

  /// Full /api/v1 prefix, e.g. http://192.168.10.108:7200/api/v1
  static String get apiV1 => '$host/api/v1';

  /// User scoped base
  static String get userApi => '$apiV1/user';
}
