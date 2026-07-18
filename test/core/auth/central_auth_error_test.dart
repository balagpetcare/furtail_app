import 'package:flutter_test/flutter_test.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/central_auth_error.dart';

void main() {
  group('CentralAuthException.typed', () {
    test('network error (no response) maps to CentralAuthNetworkError', () {
      final e = CentralAuthException(
        message: 'timeout',
        dioExceptionType: 'connectionTimeout',
      );
      expect(e.typed, isA<CentralAuthNetworkError>());
      expect(e.typed.isDefinitiveSessionFailure, isFalse);
    });

    test('INVALID_CREDENTIALS maps to CentralAuthInvalidCredentials', () {
      final e = CentralAuthException(
        message: 'bad creds',
        statusCode: 401,
        code: 'INVALID_CREDENTIALS',
      );
      expect(e.typed, isA<CentralAuthInvalidCredentials>());
    });

    test('REFRESH_TOKEN_REUSED is a definitive session failure', () {
      final e = CentralAuthException(
        message: 'reused',
        statusCode: 401,
        code: 'REFRESH_TOKEN_REUSED',
      );
      expect(e.typed, isA<CentralAuthRefreshTokenReused>());
      expect(e.typed.isDefinitiveSessionFailure, isTrue);
    });

    test('REFRESH_TOKEN_EXPIRED is a definitive session failure', () {
      final e = CentralAuthException(
        message: 'expired',
        statusCode: 401,
        code: 'REFRESH_TOKEN_EXPIRED',
      );
      expect(e.typed.isDefinitiveSessionFailure, isTrue);
    });

    test('PROVIDER_DISABLED maps distinctly (not a session failure)', () {
      final e = CentralAuthException(
        message: 'disabled',
        statusCode: 400,
        code: 'PROVIDER_DISABLED',
      );
      expect(e.typed, isA<CentralAuthProviderDisabled>());
      expect(e.typed.isDefinitiveSessionFailure, isFalse);
    });

    test('NEEDS_PROFILE_COMPLETION maps to its own type', () {
      final e = CentralAuthException(
        message: 'incomplete',
        statusCode: 409,
        code: 'NEEDS_PROFILE_COMPLETION',
      );
      expect(e.typed, isA<CentralAuthNeedsProfileCompletion>());
    });

    test('OTP error codes each map distinctly', () {
      expect(
        CentralAuthException(message: 'x', code: 'OTP_EXPIRED').typed,
        isA<CentralAuthOtpExpired>(),
      );
      expect(
        CentralAuthException(message: 'x', code: 'OTP_INVALID').typed,
        isA<CentralAuthOtpInvalid>(),
      );
      expect(
        CentralAuthException(message: 'x', code: 'OTP_MAX_ATTEMPTS').typed,
        isA<CentralAuthOtpMaxAttempts>(),
      );
      expect(
        CentralAuthException(message: 'x', code: 'OTP_RESEND_COOLDOWN').typed,
        isA<CentralAuthOtpResendCooldown>(),
      );
    });

    test('unrecognized code falls back to CentralAuthUnknownError', () {
      final e = CentralAuthException(
        message: 'weird',
        statusCode: 418,
        code: 'SOMETHING_NEW',
      );
      final typed = e.typed;
      expect(typed, isA<CentralAuthUnknownError>());
      expect(typed.rawCode, 'SOMETHING_NEW');
    });

    test(
      'OTP_RESEND_COOLDOWN carries retryAfterSeconds when details are present',
      () {
        final e = CentralAuthException(
          message: 'wait',
          code: 'OTP_RESEND_COOLDOWN',
          details: {'retryAfterSeconds': 42},
        );
        final typed = e.typed as CentralAuthOtpResendCooldown;
        expect(typed.retryAfterSeconds, 42);
      },
    );

    test('OTP_RESEND_COOLDOWN has a null retryAfterSeconds with no details '
        '(the real backend response today never includes them)', () {
      final e = CentralAuthException(
        message: 'wait',
        code: 'OTP_RESEND_COOLDOWN',
      );
      final typed = e.typed as CentralAuthOtpResendCooldown;
      expect(typed.retryAfterSeconds, isNull);
    });
  });

  group('CentralAuthProviderCancelled', () {
    test('is a distinct client-side case, not a session failure', () {
      const cancelled = CentralAuthProviderCancelled('user cancelled');
      expect(cancelled.rawCode, isNull);
      expect(cancelled.isDefinitiveSessionFailure, isFalse);
    });
  });
}
