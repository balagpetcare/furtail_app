import 'package:flutter/material.dart';

import '../data/models/campaign_public_models.dart';
import 'campaign_hero_banner.dart';
import 'campaign_hero_banner_smart.dart';

/// Horizontal carousel for multiple home campaigns.
class CampaignCarousel extends StatefulWidget {
  final List<PublicCampaign> campaigns;
  final CampaignTapCallback? onTap;
  final CampaignTapCallback? onBookNow;
  final bool showStaleBadge;
  final bool useSmartBanner;

  const CampaignCarousel({
    super.key,
    required this.campaigns,
    this.onTap,
    this.onBookNow,
    this.showStaleBadge = false,
    this.useSmartBanner = false,
  });

  @override
  State<CampaignCarousel> createState() => _CampaignCarouselState();
}

class _CampaignCarouselState extends State<CampaignCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.campaigns.isEmpty) return const SizedBox.shrink();
    if (widget.campaigns.length == 1) {
      final banner = widget.useSmartBanner
          ? CampaignHeroBannerSmart(
              campaign: widget.campaigns.first,
              onTap: widget.onTap,
              onBookNow: widget.onBookNow,
              showStaleBadge: widget.showStaleBadge,
            )
          : CampaignHeroBanner(
              campaign: widget.campaigns.first,
              onTap: widget.onTap,
              onBookNow: widget.onBookNow,
              showStaleBadge: widget.showStaleBadge,
            );
      return banner;
    }

    return Column(
      children: [
        SizedBox(
          height: _carouselHeight(context),
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.campaigns.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: widget.useSmartBanner
                    ? CampaignHeroBannerSmart(
                        campaign: widget.campaigns[i],
                        onTap: widget.onTap,
                        onBookNow: widget.onBookNow,
                        showStaleBadge: widget.showStaleBadge,
                      )
                    : CampaignHeroBanner(
                        campaign: widget.campaigns[i],
                        onTap: widget.onTap,
                        onBookNow: widget.onBookNow,
                        showStaleBadge: widget.showStaleBadge,
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.campaigns.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ],
    );
  }

  double _carouselHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return 420;
    if (w >= 600) return 380;
    return 340;
  }
}
