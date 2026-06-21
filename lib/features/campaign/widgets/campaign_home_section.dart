import 'package:furtail_app/core/analytics/analytics_events.dart';
import 'package:furtail_app/core/analytics/analytics_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../presentation/providers/campaign_discovery_providers.dart';
import '../presentation/providers/smart_campaign_providers.dart';
import '../presentation/screens/campaign_booking_page.dart';
import '../presentation/screens/campaign_details_page.dart';
import '../presentation/widgets/campaign_state_views.dart';
import 'campaign_carousel.dart';
import 'campaign_hero_banner_smart.dart';

/// Home screen campaign section — below app bar, above stories.
class CampaignHomeSection extends ConsumerWidget {
  const CampaignHomeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeCampaignsProvider);
    final padding = campaignHorizontalPadding(context);

    return async.when(
      loading: () => Padding(
        padding: EdgeInsets.fromLTRB(padding, 8, padding, 0),
        child: const SizedBox(
          height: 200,
          child: CampaignLoadingView(message: 'Loading campaigns…'),
        ),
      ),
      error: (e, _) => Padding(
        padding: EdgeInsets.fromLTRB(padding, 8, padding, 0),
        child: CampaignErrorView(
          message: 'Could not load vaccination campaigns.',
          onRetry: () => ref.read(homeCampaignsProvider.notifier).refresh(),
        ),
      ),
      data: (state) {
        if (state.campaigns.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.fromLTRB(padding, 8, padding, 12),
          child: VisibilityDetector(
            key: const Key('campaign_home_banner'),
            onVisibilityChanged: (info) {
              if (info.visibleFraction >= 0.5) {
                for (final c in state.campaigns) {
                  ref.read(campaignPerformanceTrackerProvider).recordView(
                        c.slug,
                        abVariant: c.abVariant?.variant,
                      );
                  ref.read(analyticsServiceProvider).logEvent(
                    AnalyticsEvents.campaignBannerImpression,
                    parameters: {
                      AnalyticsEvents.campaignId: c.id,
                      'campaign_slug': c.slug,
                      AnalyticsEvents.source: 'home',
                      if (c.abVariant != null) ...c.abVariant!.analyticsParams(),
                    },
                  );
                }
              }
            },
            child: state.campaigns.length == 1
                ? CampaignHeroBannerSmart(
                    campaign: state.campaigns.first,
                    showStaleBadge: state.isStale,
                    onTap: (c, {bookNow = false}) =>
                        _openCampaign(context, ref, c, bookNow: bookNow),
                    onBookNow: (c, {bookNow = false}) =>
                        _openCampaign(context, ref, c, bookNow: true),
                  )
                : CampaignCarousel(
                    campaigns: state.campaigns,
                    showStaleBadge: state.isStale,
                    useSmartBanner: true,
                    onTap: (c, {bookNow = false}) =>
                        _openCampaign(context, ref, c, bookNow: bookNow),
                    onBookNow: (c, {bookNow = false}) =>
                        _openCampaign(context, ref, c, bookNow: true),
                  ),
          ),
        );
      },
    );
  }

  void _openCampaign(
    BuildContext context,
    WidgetRef ref,
    campaign, {
    required bool bookNow,
  }) {
    ref.read(campaignPerformanceTrackerProvider).recordClick(
          campaign.slug,
          abVariant: campaign.abVariant?.variant,
        );
    ref.read(analyticsServiceProvider).logEvent(
      AnalyticsEvents.campaignBannerClick,
      parameters: {
        AnalyticsEvents.campaignId: campaign.id,
        'campaign_slug': campaign.slug,
        'target': bookNow ? 'book' : 'detail',
        if (campaign.abVariant != null) ...campaign.abVariant!.analyticsParams(),
      },
    );

    if (bookNow) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CampaignBookingPage(slug: campaign.slug),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CampaignDetailsPage(slug: campaign.slug),
        ),
      );
    }
  }
}

/// Sliver wrapper for [CampaignHomeSection].
class CampaignHomeSliver extends StatelessWidget {
  const CampaignHomeSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(child: CampaignHomeSection());
  }
}
