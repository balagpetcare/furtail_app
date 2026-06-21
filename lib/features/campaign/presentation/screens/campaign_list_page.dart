import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/campaign_public_models.dart';
import '../providers/campaign_discovery_providers.dart';
import '../widgets/campaign_state_views.dart';
import '../../widgets/campaign_mini_card.dart';
import 'campaign_details_page.dart';

/// Lists all active public vaccination campaigns.
class CampaignListPage extends ConsumerWidget {
  const CampaignListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeCampaignsProvider);
    final padding = campaignHorizontalPadding(context);
    final isTablet = campaignIsTablet(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Vaccination Campaigns')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(homeCampaignsProvider.notifier).refresh(),
        child: async.when(
          loading: () => const CampaignLoadingView(message: 'Loading campaigns…'),
          error: (e, _) => CampaignErrorView(
            message: 'Could not load campaigns.',
            onRetry: () => ref.read(homeCampaignsProvider.notifier).refresh(),
          ),
          data: (state) {
            final campaigns = state.campaigns;
            if (campaigns.isEmpty) {
              return const CampaignEmptyView(
                title: 'No active campaigns',
                subtitle: 'Check back soon for vaccination drives near you.',
              );
            }

            if (state.isStale) {
              return ListView(
                padding: EdgeInsets.all(padding),
                children: [
                  const CampaignOfflineView(showStaleHint: true),
                  const SizedBox(height: 12),
                  _grid(context, campaigns, isTablet),
                ],
              );
            }

            return ListView(
              padding: EdgeInsets.all(padding),
              children: [_grid(context, campaigns, isTablet)],
            );
          },
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, List<PublicCampaign> campaigns, bool isTablet) {
    final crossAxisCount = isTablet ? 3 : 1;
    if (crossAxisCount == 1) {
      return Column(
        children: [
          for (final c in campaigns) ...[
            CampaignMiniCard(
              campaign: c,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CampaignDetailsPage(slug: c.slug)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: campaigns.length,
      itemBuilder: (context, i) {
        final c = campaigns[i];
        return CampaignMiniCard(
          campaign: c,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CampaignDetailsPage(slug: c.slug)),
          ),
        );
      },
    );
  }
}
