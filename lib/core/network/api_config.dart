import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'base_url_validator.dart';

/// Environment-driven API configuration.
///
/// Recommended usage:
/// - Physical device: `flutter run --dart-define=FURTAIL_API_BASE_URL=http://<lan-ip>:7300/api/v1`
/// - Emulator:        `flutter run --dart-define-from-file=env/new-api-emulator.json`
/// - Rollback:        `flutter run --dart-define-from-file=env/rollback-7200.json`
///
/// FURTAIL_API_BASE_URL is preferred. Legacy API_BASE_URL/API_HOST remain
/// supported for rollback-safe compatibility.
class ApiConfig {
  /// API base host (without /api/v1), e.g. `http://192.168.10.111:7200`
  static String get host {
    const fromBase = String.fromEnvironment(
      'FURTAIL_API_BASE_URL',
      defaultValue: '',
    );
    if (fromBase.isNotEmpty) {
      return _resolveLocalhost(_stripApiV1(fromBase));
    }

    const fromHost = String.fromEnvironment(
      'FURTAIL_API_HOST',
      defaultValue: '',
    );
    if (fromHost.isNotEmpty) {
      return _resolveLocalhost(_stripApiV1(fromHost));
    }

    const legacyBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (legacyBase.isNotEmpty) {
      return _resolveLocalhost(_stripApiV1(legacyBase));
    }

    const legacyHost = String.fromEnvironment('API_HOST', defaultValue: '');
    if (legacyHost.isNotEmpty) {
      return _resolveLocalhost(_stripApiV1(legacyHost));
    }

    // Default fallback when no dart-define is set.
    if (kIsWeb) {
      return 'http://localhost:7300';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:7300';
    } else {
      return 'http://localhost:7300';
    }
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

  /// Full /api/v1 prefix, e.g. http://192.168.10.111:7200/api/v1
  static String get apiV1 => '$host/api/v1';

  /// User scoped base
  static String get userApi => '$apiV1/user';

  /// Fail-fast startup check: [ApiClient] never sets a Dio `baseUrl` — every
  /// call site is required to build a full absolute URL from [apiV1]/[host]
  /// (see `ApiClient`'s doc comment). If [host] were ever empty or missing
  /// a scheme/authority, those calls would silently become relative paths
  /// and Dio would throw `No host specified in URI` deep inside a request
  /// instead of at startup. Throws a [StateError] with a clear message
  /// instead of letting that happen.
  static void assertValid() {
    assertValidBaseUrl(
      label: 'Furtail API',
      url: host,
      hint:
          'Pass --dart-define=FURTAIL_API_BASE_URL=http://<host>:7300 '
          '(or the legacy API_BASE_URL/API_HOST aliases) when running the app.',
    );
  }
}
