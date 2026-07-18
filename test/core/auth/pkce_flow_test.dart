import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/pkce.dart';
import 'package:furtail_app/features/auth/social_login_launcher.dart';

void main() {
  group('PkceFlow', () {
    test('generates RFC 7636-compliant material', () {
      final flow = PkceFlow.generate();
      expect(flow.codeVerifier.length, inInclusiveRange(43, 128));
      expect(flow.codeVerifier, isNot(contains('=')));
      // Challenge must equal base64url(sha256(verifier)) without padding.
      final expected = base64UrlEncode(
        sha256.convert(ascii.encode(flow.codeVerifier)).bytes,
      ).replaceAll('=', '');
      expect(flow.codeChallenge, expected);
      expect(flow.state, isNotEmpty);
    });

    test('every attempt gets fresh verifier/state', () {
      final a = PkceFlow.generate();
      final b = PkceFlow.generate();
      expect(a.codeVerifier, isNot(b.codeVerifier));
      expect(a.state, isNot(b.state));
    });
  });

  group('parseSocialCallback', () {
    test('accepts matching state and returns the code', () {
      final params = parseSocialCallback(
        'furtailapp://oauth-callback?code=abc123&state=s1',
        expectedState: 's1',
      );
      expect(params.code, 'abc123');
    });

    test('rejects mismatched state — code is never exchanged', () {
      expect(
        () => parseSocialCallback(
          'furtailapp://oauth-callback?code=abc123&state=WRONG',
          expectedState: 's1',
        ),
        throwsA(isA<SocialLoginFailure>()),
      );
    });

    test('rejects missing state', () {
      expect(
        () => parseSocialCallback(
          'furtailapp://oauth-callback?code=abc123',
          expectedState: 's1',
        ),
        throwsA(isA<SocialLoginFailure>()),
      );
    });

    test('surfaces typed server errors before state validation', () {
      expect(
        () => parseSocialCallback(
          'furtailapp://oauth-callback?error=SOCIAL_EMAIL_REQUIRED&state=s1',
          expectedState: 's1',
        ),
        throwsA(
          isA<SocialLoginFailure>().having(
            (e) => e.message,
            'message',
            contains('email'),
          ),
        ),
      );
    });

    test('rejects a callback with neither code nor error', () {
      expect(
        () => parseSocialCallback(
          'furtailapp://oauth-callback?state=s1',
          expectedState: 's1',
        ),
        throwsA(isA<SocialLoginFailure>()),
      );
    });
  });
}
