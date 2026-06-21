import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/vaccination_platform/campaign_analytics.dart';
import '../providers/campaign_booking_location_providers.dart';
import '../widgets/campaign_state_views.dart';

/// Server-backed campaign analytics (bookings, vaccinated, slots, area stats).
class CampaignAnalyticsPage extends ConsumerWidget {
  final String slug;

  const CampaignAnalyticsPage({super.key, this.slug = 'cat-flu-rabies-2026'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(campaignLiveAnalyticsProvider(slug));
    final padding = campaignHorizontalPadding(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Campaign Analytics')),
      body: analyticsAsync.when(
        loading: () => const CampaignLoadingView(),
        error: (e, _) => CampaignErrorView(
          message: 'Could not load analytics.',
          onRetry: () => ref.invalidate(campaignLiveAnalyticsProvider(slug)),
        ),
        data: (stats) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(campaignLiveAnalyticsProvider(slug)),
            child: ListView(
              padding: EdgeInsets.all(padding),
              children: [
                _metricGrid(context, stats),
                const SizedBox(height: 20),
                Text('Area-wise statistics', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (stats.areaStats.isEmpty)
                  const Text('No area data yet.')
                else
                  ...stats.areaStats.map(
                    (a) => Card(
                      child: ListTile(
                        title: Text(a.bookingArea),
                        subtitle: Text('${a.totalBookings} bookings · ${a.totalCats} cats'),
                        trailing: Text('${a.vaccinatedCats} done'),
                      ),
                    ),
                  ),
                if (stats.updatedAt != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Updated ${stats.updatedAt!.toLocal()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metricGrid(BuildContext context, CampaignLiveAnalytics stats) {
    final items = [
      ('Total bookings', '${stats.totalBookings}'),
      ('Vaccinated cats', '${stats.vaccinatedCats}'),
      ('Remaining slots', '${stats.remainingSlotCapacity}'),
      ('Centers', '${stats.participatingClinics}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: items
          .map(
            (e) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(e.$1, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                      e.$2,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
