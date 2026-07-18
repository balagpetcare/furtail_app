import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/core/auth/auth_identifier_normalizer.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/central_auth_error.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

import '../../social_login_launcher.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/provider_button_grid.dart';
import 'forgot_password_screen.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';

/// Native, in-app login form — talks directly to the Central Auth REST API
/// (`/auth/login`) via [AuthController]. No browser, Custom Tab, or WebView
/// is ever launched.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateIdentifier(String? value) {
    final raw = value ?? '';
    final t = AppLocalizations.of(context)!;
    if (raw.trim().isEmpty) return t.authFieldRequired;
    try {
      AuthIdentifierNormalizer.normalizeForLogin(raw);
    } on BangladeshPhoneNormalizationException catch (e) {
      return e.message;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final normalized = AuthIdentifierNormalizer.normalizeForLogin(
        _identifierController.text,
      );
      await ref
          .read(authControllerProvider.notifier)
          .login(
            identifier: normalized.value,
            password: _passwordController.text,
            identifierType: normalized.type,
          );
      // AuthGate reacts to AuthStatus.authenticated automatically; nothing
      // further to navigate here.
    } on BangladeshPhoneNormalizationException catch (e) {
      setState(() => _errorMessage = e.message);
    } on CentralAuthException catch (e) {
      setState(() => _errorMessage = _messageForError(e.typed));
    } on FurtailProfileException catch (_) {
      // Central Auth login genuinely succeeded — AuthController already
      // moved AuthState to bootstrapFailed with a specific message, and
      // AuthGate will swap this screen out for BootstrapRetryScreen on its
      // own. Nothing to show here; don't report this as a login failure.
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// System-browser social sign-in for a wired provider button. Cancellation
  /// is silent; typed failures show a snackbar; a non-recoverable Furtail
  /// profile failure is handled by AuthGate's retry screen (same contract
  /// as [_submit]).
  Future<void> _socialLogin(String providerId) async {
    try {
      await launchSocialLogin(ref, providerId);
      // AuthGate reacts to AuthStatus.authenticated automatically.
    } on SocialLoginCancelled {
      // User closed the browser — not an error.
    } on SocialLoginFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on FurtailProfileException catch (_) {
      // AuthGate shows BootstrapRetryScreen; nothing to do here.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-in did not complete. Please try again.'),
          ),
        );
      }
    }
  }

  /// Maps a [CentralAuthError] typed case to friendly copy — never surfaces
  /// a raw backend error string directly.
  String _messageForError(CentralAuthError error) {
    return switch (error) {
      CentralAuthNetworkError() =>
        'Could not reach the server. Check your connection and try again.',
      CentralAuthInvalidCredentials() => 'Incorrect email/phone or password.',
      CentralAuthProviderDisabled() =>
        'That sign-in method is currently disabled.',
      CentralAuthTokenExpired() || CentralAuthTokenInvalid() =>
        'Your session has expired. Please sign in again.',
      CentralAuthValidationError(:final message) => message,
      _ when (error.statusCode ?? 0) >= 500 =>
        'The server is temporarily unavailable. Please try again shortly.',
      _ =>
        error.message.isNotEmpty
            ? error.message
            : 'Sign in failed. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    final t = AppLocalizations.of(context)!;
    final bootstrap = ref.watch(
      authControllerProvider.select((s) => s.bootstrap),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  AuthHeader(
                    title: t.authWelcomeTitle,
                    subtitle: t.authSignInSubtitle,
                    titleColor: primary,
                    logoHeight: 96,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AuthTextField(
                    controller: _identifierController,
                    hintText: t.authIdentifierHint,
                    prefixIcon: Icons.person_outline,
                    validator: _validateIdentifier,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AuthTextField(
                    controller: _passwordController,
                    hintText: t.authPasswordHint,
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? t.authFieldRequired : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      ),
                      child: Text(
                        t.authForgotPassword,
                        style: TextStyle(color: primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AuthButton(
                    text: t.authLogin,
                    color: primary,
                    loading: _isLoading,
                    onPressed: _submit,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.authNoAccount),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                        child: Text(
                          t.authRegister,
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (ProviderButtonGrid.optionsFrom(bootstrap).isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text(
                            t.authOrContinueWith,
                            style: TextStyle(color: context.mutedTextColor),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ProviderButtonGrid(
                      bootstrap: bootstrap,
                      onProviderSelected: _socialLogin,
                      onOtpRequested: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OtpVerificationScreen(
                            initialRecipient:
                                _identifierController.text.trim().isEmpty
                                ? null
                                : _identifierController.text.trim(),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
