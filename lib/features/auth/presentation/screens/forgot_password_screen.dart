import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';
import 'reset_password_screen.dart';

/// Step 1 of password reset: `POST /auth/forgot-password` with the
/// account's email. The Central Auth API has no phone/OTP variant of this
/// endpoint and always responds 200 (even for an unregistered email) so it
/// can't be used to enumerate accounts — the success message below is
/// worded to match that.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(value.trim()))
      return 'Enter a valid email address';
    return null;
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
          .requestPasswordReset(email: _emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } on CentralAuthException catch (e) {
      setState(() {
        _errorMessage = e.isNetworkError
            ? 'Could not reach the server. Check your connection and try again.'
            : (e.message.isNotEmpty
                  ? e.message
                  : 'Something went wrong. Please try again.');
      });
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primary),
        title: const Text(
          'Forgot Password',
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_reset, size: 40, color: primary),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter the email associated with your account and we\'ll send you a link to reset your password.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                AuthTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  prefixIcon: Icons.email_outlined,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 24),
                AuthButton(
                  text: _sent ? 'Link sent' : 'Send reset link',
                  color: primary,
                  loading: _isSubmitting,
                  onPressed: _sent ? null : _submit,
                ),
                if (_sent) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'If that email exists, a reset link has been sent. Check your inbox.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ResetPasswordScreen(),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.resetPasswordTitle,
                        style: TextStyle(color: primary),
                      ),
                    ),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
