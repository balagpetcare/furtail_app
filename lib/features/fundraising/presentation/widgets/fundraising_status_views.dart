import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/furtail_design_tokens.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

/// Branded centered loading state — never an empty white page.
class FundraisingLoadingView extends StatelessWidget {
  const FundraisingLoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: FurtailDesignTokens.textSecondary(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly, safe error state for network/server/unknown failures.
///
/// Never render `error.toString()`/`DioException`/`SocketException` text —
/// callers must pass an already-mapped, human-readable [message].
class FundraisingErrorView extends StatefulWidget {
  const FundraisingErrorView({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.onBack,
    this.icon = Icons.wifi_off_rounded,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback? onBack;
  final IconData icon;

  @override
  State<FundraisingErrorView> createState() => _FundraisingErrorViewState();
}

class _FundraisingErrorViewState extends State<FundraisingErrorView> {
  bool _retrying = false;

  Future<void> _handleRetry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } catch (_) {
      // The retry target controls whether the view can recover; keep the
      // current error state visible and let the caller decide what to show.
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              size: 48,
              color: FurtailDesignTokens.textMuted(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: FurtailDesignTokens.textSecondary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _retrying ? null : _handleRetry,
                icon: _retrying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(t.tryAgain),
              ),
            ),
            if (widget.onBack != null) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  child: Text(t.fundraisingBack),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state (e.g. no documents yet) with a prominent primary action.
class FundraisingEmptyState extends StatelessWidget {
  const FundraisingEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.arrow_forward_rounded,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: FurtailDesignTokens.textMuted(context)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: FurtailDesignTokens.textSecondary(context),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon),
                  label: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum FundraisingEligibilityStatus {
  ready,
  actionRequired,
  pendingReview,
  verified,
  rejected,
}

extension FundraisingEligibilityStatusLabel on FundraisingEligibilityStatus {
  String label(AppLocalizations t) {
    switch (this) {
      case FundraisingEligibilityStatus.ready:
        return t.fundraisingStatusReady;
      case FundraisingEligibilityStatus.actionRequired:
        return t.fundraisingStatusActionRequired;
      case FundraisingEligibilityStatus.pendingReview:
        return t.fundraisingEligibilityPending;
      case FundraisingEligibilityStatus.verified:
        return t.fundraisingEligibilityVerified;
      case FundraisingEligibilityStatus.rejected:
        return t.fundraisingEligibilityRejected;
    }
  }

  IconData get icon {
    switch (this) {
      case FundraisingEligibilityStatus.ready:
        return Icons.check_circle_rounded;
      case FundraisingEligibilityStatus.actionRequired:
        return Icons.error_outline_rounded;
      case FundraisingEligibilityStatus.pendingReview:
        return Icons.hourglass_top_rounded;
      case FundraisingEligibilityStatus.verified:
        return Icons.verified_rounded;
      case FundraisingEligibilityStatus.rejected:
        return Icons.cancel_rounded;
    }
  }

  Color foreground(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (this) {
      case FundraisingEligibilityStatus.ready:
      case FundraisingEligibilityStatus.verified:
        return FurtailDesignTokens.success;
      case FundraisingEligibilityStatus.actionRequired:
        return FurtailDesignTokens.warning;
      case FundraisingEligibilityStatus.pendingReview:
        return scheme.primary;
      case FundraisingEligibilityStatus.rejected:
        return FurtailDesignTokens.error;
    }
  }
}

/// Compact status chip used for the eligibility summary and requirement rows.
class FundraisingStatusChip extends StatelessWidget {
  const FundraisingStatusChip({super.key, required this.status});

  final FundraisingEligibilityStatus status;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final color = status.foreground(context);
    return Semantics(
      label: status.label(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              status.label(t),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum FundraisingRequirementState { completed, incomplete, pending }

/// Width below which [FundraisingRequirementRow] switches to a stacked,
/// vertical layout so the action button never competes with a wrapping
/// title/description on narrow screens (~320-360dp).
const double kFundraisingRequirementRowNarrowBreakpoint = 400;

/// A single scannable requirement row (e.g. "Fundraising profile").
///
/// [actionLabel] must already reflect the current state (e.g. "Complete" vs
/// "Edit", "Upload" vs "View documents") — callers choose the label, this
/// widget only lays it out.
class FundraisingRequirementRow extends StatelessWidget {
  const FundraisingRequirementRow({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.state,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final FundraisingRequirementState state;
  final String actionLabel;
  final VoidCallback onAction;

  Color _color(BuildContext context) => switch (state) {
    FundraisingRequirementState.completed => FurtailDesignTokens.success,
    FundraisingRequirementState.incomplete => FurtailDesignTokens.warning,
    FundraisingRequirementState.pending => Theme.of(
      context,
    ).colorScheme.primary,
  };

  String _stateLabel(AppLocalizations t) => switch (state) {
    FundraisingRequirementState.completed => t.fundraisingStateCompleted,
    FundraisingRequirementState.incomplete => t.fundraisingStateIncomplete,
    FundraisingRequirementState.pending => t.fundraisingStatePending,
  };

  Widget _icon(Color color) => Container(
    width: 36,
    height: 36,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 18, color: color),
  );

  Widget _stateChip(BuildContext context, Color color) {
    final t = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _stateLabel(t),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, {required bool stretched}) {
    final button = OutlinedButton(
      onPressed: onAction,
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
      child: Text(actionLabel),
    );
    return stretched
        ? SizedBox(width: double.infinity, height: 48, child: button)
        : SizedBox(height: 48, child: button);
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FurtailDesignTokens.cardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FurtailDesignTokens.border(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow =
              constraints.maxWidth < kFundraisingRequirementRowNarrowBreakpoint;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _icon(color),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _stateChip(context, color),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FurtailDesignTokens.textSecondary(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                _actionButton(context, stretched: true),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _icon(color),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: FurtailDesignTokens.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _stateChip(context, color),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _actionButton(context, stretched: false),
            ],
          );
        },
      ),
    );
  }
}
