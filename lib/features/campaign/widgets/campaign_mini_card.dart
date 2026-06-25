import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:furtail_app/core/media/furtail_cache_manager.dart';

import '../data/models/campaign_public_models.dart';
import 'campaign_price_badge.dart';

/// Compact campaign card for lists and grids.
class CampaignMiniCard extends StatelessWidget {
  final PublicCampaign campaign;
  final VoidCallback? onTap;

  const CampaignMiniCard({super.key, required this.campaign, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: '${campaign.name}. ${campaign.displayPrice}',
      button: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: _thumb(campaign),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CampaignPriceBadge(campaign: campaign, compact: true),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios, size: 14, color: cs.outline),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(PublicCampaign campaign) {
    const fallback = 'assets/images/doctor.png';
    final url = campaign.imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        cacheManager: FurtailImageCacheManager(),
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Image.asset(fallback, fit: BoxFit.cover),
      );
    }
    return Image.asset(fallback, fit: BoxFit.cover);
  }
}
