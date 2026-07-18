import 'package:flutter/material.dart';

import 'package:furtail_app/core/auth/central_auth_api.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

/// A single social/enterprise/passwordless sign-in option, computed once
/// from the live `GET /auth/bootstrap` response — never a hardcoded list.
class ProviderOption {
  const ProviderOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.isWired,
  });

  /// Matches the `provider` id `CentralAuthApi.identityLogin`/`loginWithProvider`
  /// expects (e.g. `google`, `facebook`, `apple`, `microsoft`, or an
  /// enterprise org slug).
  final String id;
  final String label;
  final IconData icon;

  /// Whether tapping this option performs a real sign-in. Social providers
  /// are wired via the system-browser OAuth flow (flutter_web_auth_2 against
  /// Central Auth's `/auth/social/:provider/start`) — no provider secrets in
  /// the app, no WebView. Enterprise organizations remain unwired (they
  /// need a native OIDC id_token flow) and render an honest
  /// disabled/"coming soon" state, never a silent no-op.
  final bool isWired;
}

/// Renders the enabled-provider grid computed once from
/// [CentralAuthBootstrap] (never a hardcoded provider list): known
/// providers (Google/Facebook/Apple/Microsoft) plus enterprise
/// organizations and passwordless/OTP, with less-common ones collapsed
/// under a "More" affordance — mirrors BPA User App's grid+overflow
/// structure without copying its branding.
///
/// Used identically by both the login and register screens so there is a
/// single source of truth for "what sign-in options exist right now".
class ProviderButtonGrid extends StatefulWidget {
  const ProviderButtonGrid({
    super.key,
    required this.bootstrap,
    this.onOtpRequested,
    this.onProviderSelected,
    this.maxVisible = 4,
  });

  final CentralAuthBootstrap? bootstrap;
  final VoidCallback? onOtpRequested;

  /// Invoked with the provider id (e.g. `google`) when a wired social
  /// button is tapped. The returned future keeps the button in its loading
  /// state (and blocks double-taps) until the flow completes or is
  /// cancelled. When null, social buttons render as not-yet-available.
  final Future<void> Function(String providerId)? onProviderSelected;
  final int maxVisible;

  /// Builds the full [ProviderOption] list from bootstrap data. Exposed
  /// statically so tests/other callers can compute the same list without
  /// building the widget.
  static List<ProviderOption> optionsFrom(CentralAuthBootstrap? bootstrap) {
    if (bootstrap == null) return const [];
    final options = <ProviderOption>[];

    const knownIcons = <String, IconData>{
      'google': Icons.g_mobiledata_rounded,
      'facebook': Icons.facebook_rounded,
      'apple': Icons.apple_rounded,
      'microsoft': Icons.window_rounded,
    };

    for (final provider in bootstrap.providers) {
      if (!provider.enabled) continue;
      options.add(
        ProviderOption(
          id: provider.id,
          label: provider.displayName,
          icon: knownIcons[provider.id.toLowerCase()] ?? Icons.login_rounded,
          // Wired via the system-browser OAuth flow — the tap handler is
          // supplied by the host screen through [onProviderSelected].
          isWired: true,
        ),
      );
    }

    if (bootstrap.enterpriseOrgDetails.isNotEmpty) {
      for (final org in bootstrap.enterpriseOrgDetails) {
        options.add(
          ProviderOption(
            id: 'enterprise:${org.orgSlug}',
            label: org.displayName,
            icon: Icons.apartment_rounded,
            // OIDC orgs use the system-browser code+PKCE flow; SAML orgs
            // stay honestly disabled (server returns
            // ENTERPRISE_PROVIDER_UNSUPPORTED — no fake SAML support).
            isWired: org.isOidc,
          ),
        );
      }
    } else {
      for (final org in bootstrap.enterpriseOrganizations) {
        options.add(
          ProviderOption(
            id: 'enterprise:$org',
            label: org,
            icon: Icons.apartment_rounded,
            isWired: false,
          ),
        );
      }
    }

    if (bootstrap.loginMethods.emailOtp ||
        bootstrap.loginMethods.phoneOtp ||
        bootstrap.loginMethods.whatsappOtp) {
      options.add(
        const ProviderOption(
          id: 'otp',
          label: 'OTP',
          icon: Icons.sms_outlined,
          // OTP request/verify ARE wired end-to-end via
          // AuthController.requestOtp/verifyOtp — real, not pending.
          isWired: true,
        ),
      );
    }

    return options;
  }

  @override
  State<ProviderButtonGrid> createState() => _ProviderButtonGridState();
}

class _ProviderButtonGridState extends State<ProviderButtonGrid> {
  bool _showAll = false;
  String? _loadingId;

  @override
  Widget build(BuildContext context) {
    final options = ProviderButtonGrid.optionsFrom(widget.bootstrap);
    if (options.isEmpty) return const SizedBox.shrink();

    final visible = _showAll
        ? options
        : options.take(widget.maxVisible).toList();
    final hasMore = options.length > widget.maxVisible && !_showAll;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          alignment: WrapAlignment.center,
          children: [
            for (final option in visible)
              _ProviderButton(
                option: option,
                loading: _loadingId == option.id,
                onPressed: () => _handleTap(context, option),
              ),
            if (hasMore)
              _MoreButton(onPressed: () => setState(() => _showAll = true)),
          ],
        ),
      ],
    );
  }

  Future<void> _handleTap(BuildContext context, ProviderOption option) async {
    final t = AppLocalizations.of(context)!;
    if (option.id == 'otp') {
      widget.onOtpRequested?.call();
      return;
    }
    final handler = widget.onProviderSelected;
    if (option.isWired && handler != null) {
      if (_loadingId != null) return; // one provider flow at a time
      setState(() => _loadingId = option.id);
      try {
        await handler(option.id);
      } finally {
        if (mounted) setState(() => _loadingId = null);
      }
      return;
    }
    // Honest "not yet available" feedback — never a silent no-op and never
    // a fake call into loginWithProvider without a real provider token.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.authProviderPending(option.label))),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.option,
    required this.loading,
    required this.onPressed,
  });

  final ProviderOption option;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = option.isWired;
    final borderColor = enabled
        ? context.colorScheme.outline
        : context.colorScheme.outlineVariant.withValues(alpha: 0.4);

    return Semantics(
      button: true,
      label: enabled ? option.label : '${option.label} (coming soon)',
      child: Tooltip(
        message: enabled ? option.label : '${option.label} — coming soon',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: OutlinedButton.icon(
            onPressed: loading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              side: BorderSide(color: borderColor),
              foregroundColor: enabled
                  ? context.colorScheme.onSurface
                  : context.mutedTextColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(option.icon, size: 20),
            label: Text(
              enabled ? option.label : '${option.label} • soon',
              style: TextStyle(
                color: enabled
                    ? context.colorScheme.onSurface
                    : context.mutedTextColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final t = AppLocalizations.of(context)!;
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: OutlinedButton.icon(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.more_horiz_rounded, size: 20),
            label: Text(t.authMore),
          ),
        );
      },
    );
  }
}
