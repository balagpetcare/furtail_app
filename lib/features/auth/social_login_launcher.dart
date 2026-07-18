import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/central_auth_error.dart';
import 'package:furtail_app/core/auth/pkce.dart';
import 'package:furtail_app/core/config/central_auth_config.dart';

/// The user closed the browser/sheet without completing sign-in. Callers
/// should treat this as a non-error (no snackbar needed, or a gentle one).
class SocialLoginCancelled implements Exception {
  const SocialLoginCancelled();
}

/// The flow completed abnormally — a user-presentable [message] is always
/// set. Never contains tokens or raw server payloads.
class SocialLoginFailure implements Exception {
  const SocialLoginFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Runs the full system-browser social login for [providerId] as an
/// authorization-code + PKCE flow:
///
/// 1. Generates a fresh code_verifier / S256 code_challenge / state.
/// 2. Opens Central Auth `/auth/social/:provider/start` with
///    `app_client_id`, the registered custom-scheme `redirect_uri`, `state`,
///    and the code challenge.
/// 3. The callback redirect carries ONLY `code` + `state` (or a typed
///    error) — never tokens.
/// 4. Validates `state`, then exchanges the single-use code at
///    `POST /auth/social/mobile/token` with the code verifier.
/// 5. Persists the session and resolves the Furtail profile via
///    [AuthController.completeSocialLogin].
///
/// Throws [SocialLoginCancelled] on user cancellation (an existing session,
/// if any, is untouched), [SocialLoginFailure] on a typed flow error, and
/// rethrows [AuthController]'s FurtailProfileException for non-recoverable
/// profile failures (which AuthGate surfaces via the retry screen).
Future<void> launchSocialLogin(WidgetRef ref, String providerId) {
  // Enterprise orgs come through the same grid with an `enterprise:` prefix
  // and use the mirrored /auth/enterprise/:org/start endpoint.
  if (providerId.startsWith('enterprise:')) {
    final orgSlug = providerId.substring('enterprise:'.length);
    return _runCodeFlow(
      ref,
      (state, challenge) => CentralAuthApi.enterpriseStartUrl(
        orgSlug,
        state: state,
        codeChallenge: challenge,
      ),
    );
  }
  return _runCodeFlow(
    ref,
    (state, challenge) => CentralAuthApi.socialStartUrl(
      providerId,
      state: state,
      codeChallenge: challenge,
    ),
  );
}

Future<void> _runCodeFlow(
  WidgetRef ref,
  Uri Function(String state, String codeChallenge) buildStartUrl,
) async {
  final pkce = PkceFlow.generate();
  final startUrl = buildStartUrl(pkce.state, pkce.codeChallenge);

  final String callbackUrl;
  try {
    callbackUrl = await FlutterWebAuth2.authenticate(
      url: startUrl.toString(),
      callbackUrlScheme: CentralAuthConfig.oauthCallbackScheme,
    );
  } on PlatformException catch (e) {
    if (e.code == 'CANCELED') throw const SocialLoginCancelled();
    throw const SocialLoginFailure(
      'Could not open the sign-in page. Please try again.',
    );
  }

  final params = parseSocialCallback(callbackUrl, expectedState: pkce.state);

  final CentralAuthTokenResult tokens;
  try {
    tokens = await ref
        .read(centralAuthApiProvider)
        .exchangeMobileCode(code: params.code, codeVerifier: pkce.codeVerifier);
  } on CentralAuthException catch (e) {
    // Typed exchange failures: reused/expired code, PKCE mismatch, wrong
    // client/redirect. All mean "this attempt is dead — start over".
    throw SocialLoginFailure(
      e.typed is CentralAuthNetworkError
          ? 'Could not reach the server. Check your connection and try again.'
          : 'Sign-in could not be completed. Please try again.',
    );
  }
  final refreshToken = tokens.refreshToken;
  if (refreshToken == null || refreshToken.isEmpty) {
    throw const SocialLoginFailure(
      'Sign-in did not complete. Please try again.',
    );
  }

  await ref
      .read(authControllerProvider.notifier)
      .completeSocialLogin(
        accessToken: tokens.accessToken,
        refreshToken: refreshToken,
      );
}

/// Parsed successful callback: the single-use authorization code.
class SocialCallbackParams {
  const SocialCallbackParams(this.code);
  final String code;
}

/// Validates the callback URI: typed errors first, then a strict state
/// check (a mismatched or missing state means the callback does not belong
/// to the flow this app started — treated as an attack/misfire, never
/// exchanged), then the code. Exposed for tests.
SocialCallbackParams parseSocialCallback(
  String callbackUrl, {
  required String expectedState,
}) {
  final uri = Uri.parse(callbackUrl);
  final params = uri.queryParameters;

  final error = params['error'];
  if (error != null && error.isNotEmpty) {
    if (error == 'NEEDS_PROFILE_COMPLETION') {
      throw const SocialLoginFailure(
        'Your organization account needs additional profile details. '
        'Please contact your administrator or sign up with email.',
      );
    }
    if (error == 'SOCIAL_EMAIL_REQUIRED') {
      throw const SocialLoginFailure(
        'This provider did not share an email address. '
        'Please sign up with your email first, then link this provider '
        'from Settings.',
      );
    }
    throw SocialLoginFailure('Sign-in failed ($error). Please try again.');
  }

  if (params['state'] != expectedState) {
    throw const SocialLoginFailure(
      'Sign-in could not be verified. Please try again.',
    );
  }

  final code = params['code'];
  if (code == null || code.isEmpty) {
    throw const SocialLoginFailure(
      'Sign-in did not complete. Please try again.',
    );
  }
  return SocialCallbackParams(code);
}
