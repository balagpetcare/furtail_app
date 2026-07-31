import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Environment-driven app endpoints (API, media, socket).
///
/// Recommended usage:
/// - Physical device: `flutter run --dart-define=FURTAIL_API_BASE_URL=http://<lan-ip>:7300/api/v1`
/// - Emulator: `flutter run --dart-define-from-file=env/new-api-emulator.json`
/// - Rollback: `flutter run --dart-define-from-file=env/rollback-7200.json`
///
/// FURTAIL_API_BASE_URL/FURTAIL_SOCKET_URL are preferred. Legacy
/// API_BASE_URL/SOCKET_URL remain supported for rollback-safe compatibility.
class AppConfig {
  static String get apiBaseUrl {
    const preferred = String.fromEnvironment(
      'FURTAIL_API_BASE_URL',
      defaultValue: '',
    );
    if (preferred.isNotEmpty) {
      return _resolveLocalhost(_stripApiV1(preferred));
    }

    const legacy = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (legacy.isNotEmpty) {
      return _resolveLocalhost(_stripApiV1(legacy));
    }

    if (kIsWeb) {
      return 'http://localhost:7200';
    } else if (Platform.isAndroid) {
      return 'http://192.168.10.111:7200';
    } else {
      return 'http://localhost:7200';
    }
  }

  static String get mediaBaseUrl {
    const preferred = String.fromEnvironment(
      'FURTAIL_MEDIA_BASE_URL',
      defaultValue: '',
    );
    if (preferred.isNotEmpty) {
      return _resolveLocalhost(preferred);
    }

    const legacy = String.fromEnvironment('MEDIA_BASE_URL', defaultValue: '');
    if (legacy.isNotEmpty) {
      return _resolveLocalhost(legacy);
    }
    return apiBaseUrl;
  }

  static String get socketUrl {
    const preferred = String.fromEnvironment(
      'FURTAIL_SOCKET_URL',
      defaultValue: '',
    );
    if (preferred.isNotEmpty) {
      return _resolveLocalhost(preferred);
    }

    const legacy = String.fromEnvironment('SOCKET_URL', defaultValue: '');
    if (legacy.isNotEmpty) {
      return _resolveLocalhost(legacy);
    }
    return apiBaseUrl;
  }

  /// Strip trailing /api/v1 so callers can pass the full URL or just the host.
  static String _stripApiV1(String url) {
    const suffix = '/api/v1';
    return url.endsWith(suffix)
        ? url.substring(0, url.length - suffix.length)
        : url;
  }

  static String _resolveLocalhost(String url) {
    if (!kIsWeb && Platform.isAndroid) {
      return url
          .replaceAll('localhost', '10.0.2.2')
          .replaceAll('127.0.0.1', '10.0.2.2');
    }
    return url;
  }

  /// Full /api/v1 prefix.
  static String get apiV1 => '$apiBaseUrl/api/v1';
}
