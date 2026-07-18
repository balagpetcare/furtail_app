/// Typed, sealed mapping of Central Auth API error codes (see
/// `wpa_auth_api/src/lib/errors.ts` `ErrorCodes`, plus the ad hoc codes used
/// by the auth/identity/OTP routes) into user-presentable errors. Nothing
/// downstream of [CentralAuthApi] should branch on a raw backend `code`
/// string directly — match on this hierarchy instead.
sealed class CentralAuthError {
  const CentralAuthError(this.message, {this.statusCode, this.rawCode});

  final String message;
  final int? statusCode;
  final String? rawCode;

  /// Maps a raw backend `code` (already upper-cased/trimmed) + HTTP status
  /// + fallback message into the matching typed error. Unrecognized codes
  /// fall back to [CentralAuthUnknownError] (network/timeout cases with no
  /// code at all should use [CentralAuthNetworkError] instead — callers
  /// decide that before reaching here).
  factory CentralAuthError.fromCode({
    required String? code,
    required int? statusCode,
    required String message,
    Map<String, dynamic>? details,
  }) {
    switch (code) {
      case 'INVALID_CREDENTIALS':
        return CentralAuthInvalidCredentials(message, statusCode: statusCode);
      case 'PROVIDER_DISABLED':
        return CentralAuthProviderDisabled(message, statusCode: statusCode);
      case 'TOKEN_EXPIRED':
      case 'CENTRAL_TOKEN_EXPIRED':
        return CentralAuthTokenExpired(message, statusCode: statusCode);
      case 'TOKEN_INVALID':
      case 'CENTRAL_TOKEN_INVALID':
        return CentralAuthTokenInvalid(message, statusCode: statusCode);
      case 'IDENTITY_ALREADY_LINKED':
        return CentralAuthIdentityAlreadyLinked(
          message,
          statusCode: statusCode,
        );
      case 'ACCOUNT_CONFLICT':
      case 'IDENTITY_CONFLICT':
        return CentralAuthIdentityConflict(message, statusCode: statusCode);
      case 'ACCOUNT_LINK_REQUIRED':
        return CentralAuthAccountLinkRequired(message, statusCode: statusCode);
      case 'NEEDS_PROFILE_COMPLETION':
        return CentralAuthNeedsProfileCompletion(
          message,
          statusCode: statusCode,
        );
      case 'OTP_EXPIRED':
        return CentralAuthOtpExpired(message, statusCode: statusCode);
      case 'OTP_INVALID':
        return CentralAuthOtpInvalid(message, statusCode: statusCode);
      case 'OTP_MAX_ATTEMPTS':
        return CentralAuthOtpMaxAttempts(message, statusCode: statusCode);
      case 'OTP_RESEND_COOLDOWN':
        // `retryAfterSeconds` is attached server-side (`otp.service.ts`) but,
        // as of this pass, `wpa_auth_api`'s error middleware never forwards
        // `AppError.details` to the JSON response body — so this will be
        // null in practice today. Parsed anyway so the UI picks it up for
        // free the moment the backend starts including it; never fabricate
        // a fallback number here (callers fall back to the bootstrap OTP
        // config's cooldown value instead, which IS real).
        return CentralAuthOtpResendCooldown(
          message,
          statusCode: statusCode,
          retryAfterSeconds: (details?['retryAfterSeconds'] as num?)?.toInt(),
        );
      case 'SESSION_REVOKED':
        return CentralAuthSessionRevoked(message, statusCode: statusCode);
      case 'REFRESH_TOKEN_REUSED':
        return CentralAuthRefreshTokenReused(message, statusCode: statusCode);
      case 'REFRESH_TOKEN_EXPIRED':
        return CentralAuthRefreshTokenExpired(message, statusCode: statusCode);
      case 'VALIDATION_ERROR':
        return CentralAuthValidationError(message, statusCode: statusCode);
      default:
        return CentralAuthUnknownError(
          message,
          statusCode: statusCode,
          rawCode: code,
        );
    }
  }

  /// A definitive session failure: the refresh token itself is dead (reused,
  /// revoked, or expired) — this, and only this category, should trigger a
  /// forced local logout when encountered from the *refresh* call. A network
  /// error/timeout while attempting refresh must never be classified here.
  bool get isDefinitiveSessionFailure =>
      this is CentralAuthRefreshTokenReused ||
      this is CentralAuthRefreshTokenExpired ||
      this is CentralAuthSessionRevoked ||
      this is CentralAuthTokenInvalid;
}

final class CentralAuthInvalidCredentials extends CentralAuthError {
  const CentralAuthInvalidCredentials(super.message, {super.statusCode})
    : super(rawCode: 'INVALID_CREDENTIALS');
}

final class CentralAuthProviderDisabled extends CentralAuthError {
  const CentralAuthProviderDisabled(super.message, {super.statusCode})
    : super(rawCode: 'PROVIDER_DISABLED');
}

final class CentralAuthTokenExpired extends CentralAuthError {
  const CentralAuthTokenExpired(super.message, {super.statusCode})
    : super(rawCode: 'TOKEN_EXPIRED');
}

final class CentralAuthTokenInvalid extends CentralAuthError {
  const CentralAuthTokenInvalid(super.message, {super.statusCode})
    : super(rawCode: 'TOKEN_INVALID');
}

final class CentralAuthIdentityAlreadyLinked extends CentralAuthError {
  const CentralAuthIdentityAlreadyLinked(super.message, {super.statusCode})
    : super(rawCode: 'IDENTITY_ALREADY_LINKED');
}

final class CentralAuthIdentityConflict extends CentralAuthError {
  const CentralAuthIdentityConflict(super.message, {super.statusCode})
    : super(rawCode: 'ACCOUNT_CONFLICT');
}

final class CentralAuthAccountLinkRequired extends CentralAuthError {
  const CentralAuthAccountLinkRequired(super.message, {super.statusCode})
    : super(rawCode: 'ACCOUNT_LINK_REQUIRED');
}

final class CentralAuthNeedsProfileCompletion extends CentralAuthError {
  const CentralAuthNeedsProfileCompletion(super.message, {super.statusCode})
    : super(rawCode: 'NEEDS_PROFILE_COMPLETION');
}

final class CentralAuthOtpExpired extends CentralAuthError {
  const CentralAuthOtpExpired(super.message, {super.statusCode})
    : super(rawCode: 'OTP_EXPIRED');
}

final class CentralAuthOtpInvalid extends CentralAuthError {
  const CentralAuthOtpInvalid(super.message, {super.statusCode})
    : super(rawCode: 'OTP_INVALID');
}

final class CentralAuthOtpMaxAttempts extends CentralAuthError {
  const CentralAuthOtpMaxAttempts(super.message, {super.statusCode})
    : super(rawCode: 'OTP_MAX_ATTEMPTS');
}

final class CentralAuthOtpResendCooldown extends CentralAuthError {
  const CentralAuthOtpResendCooldown(
    super.message, {
    super.statusCode,
    this.retryAfterSeconds,
  }) : super(rawCode: 'OTP_RESEND_COOLDOWN');

  /// Seconds until resend is allowed again, if the backend sent one — see
  /// the note on `CentralAuthError.fromCode`'s `OTP_RESEND_COOLDOWN` case:
  /// this is null in practice today because the error middleware drops it.
  final int? retryAfterSeconds;
}

/// User-initiated cancellation of a native provider flow (e.g. closed the
/// Google account picker, backed out of the Apple sheet). This is a
/// client-side condition only — no backend error code exists for it, and
/// none should be invented. Modeled here so provider-login call sites can
/// treat "user cancelled" distinctly from a real failure (no error banner,
/// just quietly return to the idle state).
final class CentralAuthProviderCancelled extends CentralAuthError {
  const CentralAuthProviderCancelled(super.message) : super(rawCode: null);
}

final class CentralAuthSessionRevoked extends CentralAuthError {
  const CentralAuthSessionRevoked(super.message, {super.statusCode})
    : super(rawCode: 'SESSION_REVOKED');
}

final class CentralAuthRefreshTokenReused extends CentralAuthError {
  const CentralAuthRefreshTokenReused(super.message, {super.statusCode})
    : super(rawCode: 'REFRESH_TOKEN_REUSED');
}

final class CentralAuthRefreshTokenExpired extends CentralAuthError {
  const CentralAuthRefreshTokenExpired(super.message, {super.statusCode})
    : super(rawCode: 'REFRESH_TOKEN_EXPIRED');
}

final class CentralAuthValidationError extends CentralAuthError {
  const CentralAuthValidationError(super.message, {super.statusCode})
    : super(rawCode: 'VALIDATION_ERROR');
}

/// No HTTP response was received at all (DNS/timeout/connection-refused).
/// Never a reason to clear a saved session.
final class CentralAuthNetworkError extends CentralAuthError {
  const CentralAuthNetworkError(super.message) : super(rawCode: null);
}

final class CentralAuthUnknownError extends CentralAuthError {
  const CentralAuthUnknownError(
    super.message, {
    super.statusCode,
    super.rawCode,
  });
}
