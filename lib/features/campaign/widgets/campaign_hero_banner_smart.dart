import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/campaign_public_models.dart';
import '../presentation/providers/smart_campaign_providers.dart';
import 'campaign_hero_banner.dart';

/// Hero banner with live countdown from Smart Campaign Engine.
class CampaignHeroBannerSmart extends ConsumerWidget {
  final PublicCampaign campaign;
  final CampaignTapCallback? onTap;
  final CampaignTapCallback? onBookNow;
  final bool showStaleBadge;

  const CampaignHeroBannerSmart({
    super.key,
    required this.campaign,
    this.onTap,
    this.onBookNow,
    this.showStaleBadge = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdownAsync = ref.watch(campaignCountdownProvider(campaign.slug));

    return countdownAsync.when(
      loading: () => CampaignHeroBanner(
        campaign: campaign,
        onTap: onTap,
        onBookNow: onBookNow,
        showStaleBadge: showStaleBadge,
      ),
      error: (_, __) => CampaignHeroBanner(
        campaign: campaign,
        onTap: onTap,
        onBookNow: onBookNow,
        showStaleBadge: showStaleBadge,
      ),
      data: (countdown) => CampaignHeroBanner(
        campaign: campaign,
        onTap: onTap,
        onBookNow: onBookNow,
        showStaleBadge: showStaleBadge,
        countdown: countdown,
      ),
    );
  }
}
