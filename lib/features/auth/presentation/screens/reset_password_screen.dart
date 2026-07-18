import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';

/// Step 2 of password reset: `POST /auth/reset-password` with the opaque
/// `token` from the emailed reset link, plus a new password.
///
/// Reachability (final hardening pass): the Central Auth reset email now
/// routes per-client via `PASSWORD_RESET_URL_BY_CLIENT` on wpa_auth_api
/// (`buildPasswordResetLink()` in auth.service.ts), and Furtail's forgot-
/// password request sends `clientId: furtail-mobile`. Configure that env to
/// `furtail://reset-password` (or `https://app.furtail.global/reset-password`)
/// and the emailed link deep-links straight here: `DeepLinkKind.resetPassword`
/// is now registered (see `core/deep_link/deep_link_parser.dart` +
/// `deep_link_navigator.dart`), extracting the opaque `token` query param and
/// pushing this screen with `initialToken`. The manual token field remains as
/// a fallback for users who copy the token by hand.
///
/// `POST /auth/reset-password` returns no session (`resetPasswordSchema`'s
/// handler just replies with a confirmation message) — so on success this
/// screen always routes back to the login screen; there is no auto-login
/// branch to build because the backend never returns one.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  bool _done = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) {
      _tokenController.text = widget.initialToken!;
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  CentralAuthPasswordPolicy? get _policy =>
      ref.read(authControllerProvider).bootstrap?.passwordPolicy;

  String? _validatePassword(String? value) {
    final t = AppLocalizations.of(context)!;
    final raw = value ?? '';
    final policy = _policy;
    if (policy == null) {
      if (raw.length < 8) return t.authPasswordTooShort(8);
      return null;
    }
    final violations = policy.violations(raw);
    if (violations.isEmpty) return null;
    if (violations.contains('minLength')) {
      return t.authPasswordTooShort(policy.minLength);
    }
    return t.authFieldRequired;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resetPassword(
            token: _tokenController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) setState(() => _done = true);
    } on CentralAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.isNetworkError
            ? 'Could not reach the server. Check your connection and try again.'
            : (e.message.isNotEmpty
                  ? e.message
                  : 'Something went wrong. Please try again.');
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final primary = context.colorScheme.primary;
    final policy = _policy;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primary),
        title: Text(
          t.resetPasswordTitle,
          style: const TextStyle(color: Colors.black87),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: _done
              ? _buildDoneState(t, primary)
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        t.resetPasswordTokenExplainer,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.mutedTextColor),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AuthTextField(
                        controller: _tokenController,
                        hintText: t.resetPasswordTokenHint,
                        prefixIcon: Icons.vpn_key_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? t.authFieldRequired
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AuthTextField(
                        controller: _passwordController,
                        hintText: t.resetPasswordNewPasswordHint,
                        prefixIcon: Icons.lock_outline,
                        isPassword: true,
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (policy != null) _buildPolicyHints(t, policy),
                      const SizedBox(height: AppSpacing.md),
                      AuthTextField(
                        controller: _confirmController,
                        hintText: t.resetPasswordConfirmHint,
                        prefixIcon: Icons.lock_outline,
                        isPassword: true,
                        validator: (v) => v != _passwordController.text
                            ? t.authPasswordMismatch
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AuthButton(
                        text: t.resetPasswordSubmit,
                        color: primary,
                        loading: _isSubmitting,
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
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPolicyHints(
    AppLocalizations t,
    CentralAuthPasswordPolicy policy,
  ) {
    final current = _passwordController.text;
    final violations = policy.violations(current);
    final rows = <(String, bool)>[
      (
        t.resetPasswordPolicyMinLength(policy.minLength),
        !violations.contains('minLength'),
      ),
      if (policy.requiresUppercase)
        (t.resetPasswordPolicyUppercase, !violations.contains('uppercase')),
      if (policy.requiresNumber)
        (t.resetPasswordPolicyNumber, !violations.contains('number')),
      if (policy.requiresSymbol)
        (t.resetPasswordPolicySymbol, !violations.contains('symbol')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, satisfied) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  satisfied ? Icons.check_circle : Icons.circle_outlined,
                  size: 16,
                  color: satisfied ? Colors.green : context.mutedTextColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: satisfied ? Colors.green : context.mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDoneState(AppLocalizations t, Color primary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: Icon(Icons.check_circle_outline, size: 64, color: primary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          t.resetPasswordSuccess,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedTextColor),
        ),
        const SizedBox(height: AppSpacing.xl),
        AuthButton(
          text: t.authLogin,
          color: primary,
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ],
    );
  }
}
