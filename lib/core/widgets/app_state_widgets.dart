import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/l10n/app_localizations.dart';

/// Full-screen centered loading spinner.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Skeleton card placeholder for feed/profile loading.
class AppSkeletonCard extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius borderRadius;

  const AppSkeletonCard({
    super.key,
    this.height = 80,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<AppSkeletonCard> createState() => _AppSkeletonCardState();
}

class _AppSkeletonCardState extends State<AppSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          color: Color.lerp(base, base.withValues(alpha: 0.4), _anim.value),
        ),
      ),
    );
  }
}

/// Skeleton feed post placeholder — 3 lines.
class AppPostSkeleton extends StatelessWidget {
  const AppPostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorScheme.outline),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSkeletonCard(height: 40, width: 40, borderRadius: BorderRadius.all(Radius.circular(20))),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonCard(height: 12, width: 120),
                    SizedBox(height: 6),
                    AppSkeletonCard(height: 10, width: 80),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          AppSkeletonCard(height: 14),
          SizedBox(height: 6),
          AppSkeletonCard(height: 14),
          SizedBox(height: 6),
          AppSkeletonCard(height: 200),
        ],
      ),
    );
  }
}

/// Full-screen empty state with icon, message, and optional action.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen error state with retry button.
class AppErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorState({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = context.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: cs.error),
            const SizedBox(height: 16),
            Text(
              message ?? t.somethingWentWrong,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(t.tryAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact inline offline banner.
class AppOfflineBanner extends StatelessWidget {
  const AppOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      color: Colors.orange.shade700,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.youAreOffline,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header for settings/profile pages.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const AppSectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Inline retry button for partial failures.
class AppRetryButton extends StatelessWidget {
  final VoidCallback onRetry;
  final String? label;

  const AppRetryButton({super.key, required this.onRetry, this.label});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Center(
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(label ?? t.tryAgain),
      ),
    );
  }
}
