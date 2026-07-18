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
import 'otp_verification_screen.dart';

/// Native, in-app registration form — talks directly to the Central Auth
/// REST API (`/auth/register`). The backend returns no session on
/// register, so success sends the user back to the login screen.
///
/// Email and phone are always separate fields here (unlike login's single
/// combined identifier field) since `/auth/register` takes them as distinct
/// optional parameters, not one ambiguous string.
///
/// NOTE on password policy: the current `CentralAuthBootstrap` shape (see
/// `central_auth_api.dart`) does not include a `passwordPolicy` field at
/// all — only `registrationOpen`, `requiredProfileFields`, `loginMethods`,
/// `providers`, `enterpriseOrganizations`, and OTP settings. There is
/// nothing "live" to render here yet, so the minimum-length hint below is a
/// client-side floor matching the pre-existing validation (8 characters),
/// not a fabricated live policy. If/when the backend adds a
/// `passwordPolicy` object to bootstrap, wire it in here.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const int _minPasswordLength = 8;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final raw = (value ?? '').trim();
    final phone = _phoneController.text.trim();
    final t = AppLocalizations.of(context)!;
    if (raw.isEmpty && phone.isEmpty) return t.authFieldRequired;
    if (raw.isEmpty) return null;
    if (!AuthIdentifierNormalizer.isValidEmail(raw)) {
      return t.authInvalidEmail;
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final raw = (value ?? '').trim();
    final email = _emailController.text.trim();
    final t = AppLocalizations.of(context)!;
    if (raw.isEmpty && email.isEmpty) return t.authFieldRequired;
    if (raw.isEmpty) return null;
    try {
      AuthIdentifierNormalizer.normalizeBangladeshPhone(raw);
    } on BangladeshPhoneNormalizationException catch (e) {
      return e.message;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final t = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) return t.authFieldRequired;
    if (value.length < _minPasswordLength) {
      return t.authPasswordTooShort(_minPasswordLength);
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final t = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) return t.authFieldRequired;
    if (value != _passwordController.text) return t.authPasswordMismatch;
    return null;
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final rawEmail = _emailController.text.trim();
      final rawPhone = _phoneController.text.trim();
      final email = rawEmail.isEmpty ? null : rawEmail.toLowerCase();
      final phone = rawPhone.isEmpty
          ? null
          : AuthIdentifierNormalizer.normalizeBangladeshPhone(rawPhone);

      await ref
          .read(authControllerProvider.notifier)
          .register(
            displayName: _nameController.text.trim(),
            email: email,
            phone: phone,
            password: _passwordController.text,
          );
      if (!mounted) return;
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.authRegisteredSuccess)));
      Navigator.pop(context);
    } on BangladeshPhoneNormalizationException catch (e) {
      setState(() => _errorMessage = e.message);
    } on CentralAuthException catch (e) {
      setState(() => _errorMessage = _messageForError(e.typed));
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Social sign-up shares the exact login flow: Central Auth creates the
  /// account on first provider sign-in and JIT-links the Furtail profile.
  Future<void> _socialRegister(String providerId) async {
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
            content: Text('Sign-up did not complete. Please try again.'),
          ),
        );
      }
    }
  }

  String _messageForError(CentralAuthError error) {
    return switch (error) {
      CentralAuthNetworkError() =>
        'Could not reach the server. Check your connection and try again.',
      CentralAuthValidationError(:final message) => message,
      _ when error.rawCode == 'ALREADY_EXISTS' =>
        'An account with those credentials already exists.',
      _ when (error.statusCode ?? 0) >= 500 =>
        'The server is temporarily unavailable. Please try again shortly.',
      _ =>
        error.message.isNotEmpty
            ? error.message
            : 'Sign up failed. Please try again.',
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthHeader(
                  title: t.authCreateAccountTitle,
                  subtitle: t.authCreateAccountSubtitle,
                  titleColor: primary,
                  logoHeight: 84,
                ),
                const SizedBox(height: AppSpacing.xl),
                AuthTextField(
                  controller: _nameController,
                  hintText: t.authFullNameHint,
                  prefixIcon: Icons.badge_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? t.authFieldRequired
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  controller: _emailController,
                  hintText: t.authEmailHint,
                  prefixIcon: Icons.alternate_email,
                  validator: _validateEmail,
                ),
                const SizedBox(height: AppSpacing.lg),
                // Bangladesh-only phone handling to match the existing
                // AuthIdentifierNormalizer (no country-code picker package
                // exists anywhere in this repo today, so one was not added
                // just for this field — see final report).
                AuthTextField(
                  controller: _phoneController,
                  hintText: t.authPhoneHint,
                  prefixIcon: Icons.phone_outlined,
                  validator: _validatePhone,
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  controller: _passwordController,
                  hintText:
                      '${t.authPasswordHint} (min $_minPasswordLength chars)',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  controller: _confirmPasswordController,
                  hintText: t.authConfirmPasswordHint,
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: AppSpacing.xl),
                AuthButton(
                  text: t.authCreateAccountButton,
                  color: primary,
                  loading: _loading,
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
                    Text(t.authHaveAccount),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        t.authLoginLink,
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
                    onProviderSelected: _socialRegister,
                    onOtpRequested: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OtpVerificationScreen(),
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
    );
  }
}
