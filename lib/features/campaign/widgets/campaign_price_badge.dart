import 'package:flutter/material.dart';

import '../data/models/campaign_public_models.dart';
import 'package:furtail_app/core/theme/furtail_design_tokens.dart';

class CampaignPriceBadge extends StatelessWidget {
  final PublicCampaign campaign;
  final bool compact;

  const CampaignPriceBadge({super.key, required this.campaign, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isFree = campaign.isFree;
    final bg = isFree
        ? Theme.of(context).colorScheme.primaryContainer
        : FurtailDesignTokens.accentGold.withValues(alpha: 0.15);
    final fg = isFree
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : FurtailDesignTokens.accentGold;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Text(
        campaign.displayPrice,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
