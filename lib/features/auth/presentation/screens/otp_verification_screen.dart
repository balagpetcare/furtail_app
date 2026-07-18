import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/core/auth/auth_identifier_normalizer.dart';
import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/auth/central_auth_error.dart';
import 'package:furtail_app/core/auth/otp_destination_masking.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';

/// One shared OTP screen for the Central Auth passwordless-login flow
/// (`/auth/otp/request` + `/auth/otp/verify`). This is currently the ONLY
/// OTP context the backend actually supports: `/auth/forgot-password` has
/// no OTP variant (email-link only — confirmed in `auth.routes.ts`'s
/// `forgotPasswordSchema`, which takes `email` only), and there is no
/// separate "register via OTP" endpoint (OTP always resolves to an existing
/// account or creates one via `oidcLoginOrCreate`-style login, not
/// registration). The screen is still written to take a `channel`/
/// `recipient` seed rather than hardcoding a purpose, so it can be reused
/// if a second OTP context is added later without a rewrite.
///
/// Two steps in one screen:
///  1. Pick a channel (whichever of email/phone/WhatsApp bootstrap reports
///     enabled) and enter the recipient, then request a code.
///  2. Enter the code; on success `AuthController.verifyOtp` saves the
///     session and `AuthGate` reacts to `AuthStatus.authenticated` on its
///     own — this screen does not navigate anywhere on success.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, this.initialRecipient});

  /// Optional prefill (e.g. carried over from the login screen's identifier
  /// field) so the user doesn't have to retype it.
  final String? initialRecipient;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _recipientController = TextEditingController();
  final _codeController = TextEditingController();
  final _requestFormKey = GlobalKey<FormState>();
  final _verifyFormKey = GlobalKey<FormState>();

  String _channel = 'email';
  bool _requesting = false;
  bool _resending = false;
  bool _verifying = false;
  String? _requestError;
  String? _verifyError;

  /// Locally tracked once a request succeeds so this screen can show step 2
  /// immediately (rather than waiting a frame for `ref.watch` to reflect
  /// the controller's new state) and so "use a different email/phone" can
  /// step back without depending on controller-state plumbing.
  String? _activeChannel;
  String? _activeRecipient;

  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialRecipient != null) {
      _recipientController.text = widget.initialRecipient!;
      try {
        final normalized = AuthIdentifierNormalizer.normalizeForLogin(
          widget.initialRecipient!,
        );
        _channel = normalized.type == AuthIdentifierType.email
            ? 'email'
            : 'phone';
      } catch (_) {
        // Leave default channel; validation on submit will catch it.
      }
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _recipientController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  List<String> _enabledChannels(CentralAuthBootstrap? bootstrap) {
    if (bootstrap == null) return const [];
    final methods = bootstrap.loginMethods;
    return [
      if (methods.emailOtp) 'email',
      if (methods.phoneOtp) 'phone',
      if (methods.whatsappOtp) 'whatsapp',
    ];
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownRemaining = seconds);
    if (seconds <= 0) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownRemaining -= 1;
        if (_cooldownRemaining <= 0) timer.cancel();
      });
    });
  }

  Future<void> _submitRequest({bool isResend = false}) async {
    if (!isResend && !_requestFormKey.currentState!.validate()) return;
    final recipient = _recipientController.text.trim();
    setState(() {
      if (isResend) {
        _resending = true;
      } else {
        _requesting = true;
      }
      _requestError = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestOtp(channel: _channel, recipient: recipient);
      if (!mounted) return;
      final bootstrap = ref.read(authControllerProvider).bootstrap;
      setState(() {
        _activeChannel = _channel;
        _activeRecipient = recipient;
        _verifyError = null;
        _codeController.clear();
      });
      _startCooldown(bootstrap?.otpResendCooldownSeconds ?? 60);
    } on CentralAuthException catch (e) {
      setState(() => _requestError = _messageForRequestError(e.typed));
    } catch (_) {
      if (mounted) {
        setState(
          () => _requestError = 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _requesting = false;
          _resending = false;
        });
      }
    }
  }

  Future<void> _submitVerify() async {
    if (!_verifyFormKey.currentState!.validate()) return;
    setState(() {
      _verifying = true;
      _verifyError = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(
            channel: _activeChannel!,
            recipient: _activeRecipient!,
            code: _codeController.text.trim(),
          );
      // AuthGate reacts to AuthStatus.authenticated /
      // requiresProfileCompletion on its own; nothing further to do here.
    } on CentralAuthException catch (e) {
      setState(() => _verifyError = _messageForVerifyError(e.typed));
    } catch (_) {
      if (mounted) {
        setState(
          () => _verifyError = 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _changeRecipient() {
    _cooldownTimer?.cancel();
    setState(() {
      _activeChannel = null;
      _activeRecipient = null;
      _cooldownRemaining = 0;
      _verifyError = null;
      _codeController.clear();
    });
  }

  String _messageForRequestError(CentralAuthError error) {
    final t = AppLocalizations.of(context)!;
    return switch (error) {
      CentralAuthNetworkError() =>
        'Could not reach the server. Check your connection and try again.',
      CentralAuthOtpResendCooldown() => t.otpErrorCooldown,
      CentralAuthValidationError(:final message) => message,
      _ =>
        error.message.isNotEmpty
            ? error.message
            : 'Could not send the code. Please try again.',
    };
  }

  String _messageForVerifyError(CentralAuthError error) {
    final t = AppLocalizations.of(context)!;
    return switch (error) {
      CentralAuthNetworkError() =>
        'Could not reach the server. Check your connection and try again.',
      CentralAuthOtpExpired() => t.otpErrorExpired,
      CentralAuthOtpMaxAttempts() => t.otpErrorMaxAttempts,
      CentralAuthOtpInvalid() => t.otpErrorInvalid,
      CentralAuthInvalidCredentials() => t.otpErrorInvalid,
      _ =>
        error.message.isNotEmpty
            ? error.message
            : 'Verification failed. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final primary = context.colorScheme.primary;
    final bootstrap = ref.watch(
      authControllerProvider.select((s) => s.bootstrap),
    );
    final showVerifyStep = _activeChannel != null && _activeRecipient != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primary),
        title: Text(t.otpTitle, style: const TextStyle(color: Colors.black87)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: showVerifyStep
              ? _buildVerifyStep(t, primary)
              : _buildRequestStep(t, primary, bootstrap),
        ),
      ),
    );
  }

  Widget _buildRequestStep(
    AppLocalizations t,
    Color primary,
    CentralAuthBootstrap? bootstrap,
  ) {
    final channels = _enabledChannels(bootstrap);
    if (channels.isNotEmpty && !channels.contains(_channel)) {
      _channel = channels.first;
    }
    return Form(
      key: _requestFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          if (channels.length > 1) ...[
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final channel in channels)
                  ChoiceChip(
                    label: Text(_channelLabel(t, channel)),
                    selected: _channel == channel,
                    onSelected: (_) => setState(() => _channel = channel),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AuthTextField(
            controller: _recipientController,
            hintText: t.otpRecipientHint,
            prefixIcon: _channel == 'email'
                ? Icons.email_outlined
                : Icons.phone_outlined,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return t.authFieldRequired;
              try {
                final normalized = AuthIdentifierNormalizer.normalizeForLogin(
                  v,
                );
                if (_channel == 'email' &&
                    normalized.type != AuthIdentifierType.email) {
                  return t.authInvalidEmail;
                }
              } on BangladeshPhoneNormalizationException catch (e) {
                if (_channel != 'email') return e.message;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthButton(
            text: t.otpSendCode,
            color: primary,
            loading: _requesting,
            onPressed: () => _submitRequest(),
          ),
          if (_requestError != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              _requestError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildVerifyStep(AppLocalizations t, Color primary) {
    final masked = OtpDestinationMasking.mask(
      _activeChannel!,
      _activeRecipient!,
    );
    return Form(
      key: _verifyFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            t.otpEnterCodeSentTo(masked),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedTextColor),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: t.otpCodeHint,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? t.authFieldRequired : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthButton(
            text: t.otpVerify,
            color: primary,
            loading: _verifying,
            onPressed: _submitVerify,
          ),
          if (_verifyError != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              _verifyError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TextButton(
              onPressed: (_cooldownRemaining > 0 || _resending)
                  ? null
                  : () => _submitRequest(isResend: true),
              child: _resending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _cooldownRemaining > 0
                          ? t.otpResendIn(_cooldownRemaining)
                          : t.otpResend,
                    ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: _changeRecipient,
              child: Text(t.otpChangeRecipient),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  String _channelLabel(AppLocalizations t, String channel) {
    return switch (channel) {
      'email' => t.otpChannelEmail,
      'phone' => t.otpChannelPhone,
      'whatsapp' => t.otpChannelWhatsapp,
      _ => channel,
    };
  }
}
