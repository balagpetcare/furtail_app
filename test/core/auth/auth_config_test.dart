import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/config/central_auth_config.dart';
import 'package:furtail_app/core/network/api_config.dart';
import 'package:furtail_app/core/network/base_url_validator.dart';

void main() {
  group('assertValidBaseUrl', () {
    test('rejects an empty base URL before any request would be sent', () {
      expect(
        () => assertValidBaseUrl(label: 'Test API', url: '', hint: 'set it'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects a bare path with no host (the exact prior failure mode)', () {
      // This is the literal string that caused the runtime crash: a
      // relative path used where an absolute base URL was required.
      expect(isValidHttpBaseUrl('/api/v1/auth/me'), isFalse);
    });

    test('rejects a non-http(s) scheme', () {
      expect(isValidHttpBaseUrl('ftp://example.com'), isFalse);
    });

    test('accepts a well-formed absolute http URL', () {
      expect(isValidHttpBaseUrl('http://10.0.2.2:7200'), isTrue);
    });
  });

  group('ApiConfig', () {
    test('host is an absolute http(s) URL with a real host', () {
      final uri = Uri.parse(ApiConfig.host);
      expect(uri.scheme, anyOf('http', 'https'));
      expect(uri.host, isNotEmpty);
    });

    test('apiV1 builds an absolute URL, never a bare path', () {
      // This is the exact bug that produced "No host specified in URI
      // /api/v1/auth/me": a caller building a relative path instead of
      // going through ApiConfig.apiV1/host. Every Furtail API call site
      // (including AuthController's /auth/me fetch) must produce a URL
      // Uri.parse() reports as absolute.
      final uri = Uri.parse(ApiConfig.apiV1);
      expect(uri.hasAuthority, isTrue);
      expect(uri.host, isNotEmpty);
      expect(ApiConfig.apiV1, endsWith('/api/v1'));
    });

    test('assertValid does not throw for the default configuration', () {
      expect(ApiConfig.assertValid, returnsNormally);
    });
  });

  group('CentralAuthConfig', () {
    test('apiV1 builds an absolute URL, never a bare path', () {
      final uri = Uri.parse(CentralAuthConfig.apiV1);
      expect(uri.hasAuthority, isTrue);
      expect(uri.host, isNotEmpty);
    });

    test('assertValid does not throw for the default configuration', () {
      expect(CentralAuthConfig.assertValid, returnsNormally);
    });
  });

  group('ApiConfig vs CentralAuthConfig', () {
    test(
      'the Furtail API and Central Auth API resolve to different base URLs',
      () {
        // Central Auth handles login/register/refresh/logout/password-reset;
        // the Furtail API handles /auth/me and all Furtail domain endpoints.
        // These must never collapse onto the same base URL/port, or a
        // profile-resolution call could accidentally be sent to Central Auth
        // (or vice versa).
        expect(ApiConfig.apiV1, isNot(equals(CentralAuthConfig.apiV1)));
        expect(
          Uri.parse(ApiConfig.host).port,
          isNot(equals(Uri.parse(CentralAuthConfig.host).port)),
        );
      },
    );
  });
}
