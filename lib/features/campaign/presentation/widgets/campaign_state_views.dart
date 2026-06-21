import 'package:flutter/material.dart';

/// Shared loading, empty, offline, and retry states for campaign UI.
class CampaignLoadingView extends StatelessWidget {
  final String? message;
  const CampaignLoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class CampaignEmptyView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  const CampaignEmptyView({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.event_busy_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CampaignOfflineView extends StatelessWidget {
  final VoidCallback? onRetry;
  final bool showStaleHint;
  const CampaignOfflineView({super.key, this.onRetry, this.showStaleHint = true});

  @override
  Widget build(BuildContext context) {
    return CampaignEmptyView(
      icon: Icons.cloud_off_outlined,
      title: showStaleHint ? 'Showing saved campaigns' : 'You are offline',
      subtitle: showStaleHint
          ? 'Connect to refresh the latest vaccination campaigns.'
          : 'Check your connection and try again.',
    );
  }
}

class CampaignErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const CampaignErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Responsive horizontal padding for phone vs tablet.
double campaignHorizontalPadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 900) return 32;
  if (w >= 600) return 24;
  return 16;
}

bool campaignIsTablet(BuildContext context) => MediaQuery.sizeOf(context).width >= 600;
