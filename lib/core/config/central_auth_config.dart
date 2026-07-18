import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../network/base_url_validator.dart';

/// Environment-driven configuration for the WPA Central Authentication REST
/// API (wpa_auth_api). Furtail authenticates natively in-app via
/// `/api/v1/auth/*` endpoints — no browser, WebView, or hosted login page
/// is involved.
///
/// Mirrors `ApiConfig`'s resolution pattern exactly (same dart-define /
/// localhost-rewrite behavior) so there is a single environment-override
/// convention across both API clients, not two parallel ones.
///
/// Recommended usage:
/// - Emulator:  `--dart-define=CENTRAL_AUTH_API_BASE_URL=http://10.0.2.2:5010`
/// - Physical device / LAN: `--dart-define=CENTRAL_AUTH_API_BASE_URL=http://192.168.x.x:5010`
class CentralAuthConfig {
  /// Central Auth API base host (without /api/v1), e.g. `http://10.0.2.2:5010`.
  static String get host {
    const fromBase = String.fromEnvironment(
      'CENTRAL_AUTH_API_BASE_URL',
      defaultValue: '',
    );
    if (fromBase.isNotEmpty) {
      return _resolveLocalhost(_stripApiV1(fromBase));
    }

    const fromHost = String.fromEnvironment(
      'CENTRAL_AUTH_API_HOST',
      defaultValue: '',
    );
    if (fromHost.isNotEmpty) {
      return _resolveLocalhost(_stripApiV1(fromHost));
    }

    // Default fallback when no dart-define is set. Never defaults to an
    // emulator-only address (10.0.2.2) in production — that value is only
    // reached via the explicit localhost-rewrite below, which requires the
    // caller to have opted in with a `localhost`/`127.0.0.1` dart-define.
    if (kIsWeb) {
      return 'http://localhost:5010';
    } else if (Platform.isAndroid) {
      return 'http://192.168.10.108:5010';
    } else {
      return 'http://localhost:5010';
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

  /// WPA Central Auth client identifier for this app (matches
  /// wpa_auth_api's AuthClient.clientId / CENTRAL_AUTH_CLIENT_ID and
  /// furtail_api's CENTRAL_AUTH_CLIENT_ID). Sent on forgot-password so the
  /// reset email deep-links back into Furtail (PASSWORD_RESET_URL_BY_CLIENT
  /// on the auth server), and available for bootstrap client scoping.
  /// Override with --dart-define=CENTRAL_AUTH_CLIENT_ID=... if needed.
  static const String clientId = String.fromEnvironment(
    'CENTRAL_AUTH_CLIENT_ID',
    defaultValue: 'furtail-mobile',
  );

  /// Custom scheme the system-browser OAuth flow (flutter_web_auth_2)
  /// returns on. Must match an entry in this client's registered
  /// `redirectUris` on the auth server (AuthClient seed:
  /// `furtailapp://oauth-callback`) and the Android intent-filter.
  static const String oauthCallbackScheme = 'furtailapp';

  /// Full custom-scheme redirect URI passed to `/auth/social/:provider/start`.
  static const String oauthCallbackUri =
      '$oauthCallbackScheme://oauth-callback';

  /// Full /api/v1 prefix, e.g. http://10.0.2.2:5010/api/v1
  static String get apiV1 => '$host/api/v1';

  /// Base URL passed to [CentralAuthApi]'s Dio instance.
  static String get apiBaseUrl => apiV1;

  /// Fail-fast startup check — see `ApiConfig.assertValid` for rationale.
  static void assertValid() {
    assertValidBaseUrl(
      label: 'Central Auth API',
      url: host,
      hint:
          'Pass --dart-define=CENTRAL_AUTH_API_BASE_URL=http://<host>:5010 '
          'when running the app.',
    );
  }
}
