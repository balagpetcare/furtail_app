import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/campaign_performance_metrics.dart';
import '../providers/campaign_discovery_providers.dart';
import '../providers/smart_campaign_providers.dart';
import '../widgets/campaign_state_views.dart';

/// Campaign funnel metrics dashboard (local + live stats).
class CampaignPerformanceDashboardPage extends ConsumerWidget {
  const CampaignPerformanceDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfAsync = ref.watch(allCampaignPerformanceProvider);
    final campaignsAsync = ref.watch(homeCampaignsProvider);
    final padding = campaignHorizontalPadding(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Campaign Performance')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allCampaignPerformanceProvider);
          await ref.read(homeCampaignsProvider.notifier).refresh();
        },
        child: ListView(
          padding: EdgeInsets.all(padding),
          children: [
            Text(
              'Smart Campaign Engine',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tracks banner views, clicks, bookings, and revenue. A/B variants included.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            perfAsync.when(
              loading: () => const CampaignLoadingView(),
              error: (e, _) => CampaignErrorView(message: '$e'),
              data: (metrics) {
                if (metrics.isEmpty) {
                  return const CampaignEmptyView(
                    title: 'No metrics yet',
                    subtitle: 'Open the home banner or complete a booking to collect data.',
                  );
                }
                return Column(
                  children: metrics.map((m) => _MetricCard(metrics: m)).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            campaignsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (state) {
                if (state.campaigns.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active campaigns', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...state.campaigns.map(
                      (c) => ListTile(
                        title: Text(c.name),
                        subtitle: Text(
                          '${c.smartConfig.priority.code} · ${c.smartConfig.campaignType.label}'
                          '${c.abVariant != null ? ' · variant ${c.abVariant!.variant}' : ''}',
                        ),
                        trailing: Text(c.displayPrice),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final CampaignPerformanceMetrics metrics;
  const _MetricCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(metrics.slug, style: Theme.of(context).textTheme.titleMedium),
            if (metrics.abVariant != null)
              Text('Variant ${metrics.abVariant}', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 12),
            _row('Views', '${metrics.views}'),
            _row('Clicks', '${metrics.clicks}'),
            _row('Bookings', '${metrics.bookings}'),
            _row('Revenue', '৳${metrics.revenue}'),
            const Divider(height: 20),
            _row('Banner CTR', '${(metrics.clickThroughRate * 100).toStringAsFixed(1)}%'),
            _row('Booking rate', '${(metrics.bookingRate * 100).toStringAsFixed(1)}%'),
            _row('Conversion', '${(metrics.conversionRate * 100).toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
