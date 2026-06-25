import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:furtail_app/core/media/furtail_cache_manager.dart';
import 'package:intl/intl.dart';

import '../data/models/campaign_countdown.dart';
import '../data/models/campaign_public_models.dart';
import 'campaign_countdown_strip.dart';
import 'campaign_price_badge.dart';

typedef CampaignTapCallback = void Function(PublicCampaign campaign, {bool bookNow});

/// Premium full-width campaign card for the home screen.
class CampaignHeroBanner extends StatelessWidget {
  final PublicCampaign campaign;
  final CampaignTapCallback? onTap;
  final CampaignTapCallback? onBookNow;
  final bool showStaleBadge;
  final CampaignCountdownSnapshot? countdown;

  const CampaignHeroBanner({
    super.key,
    required this.campaign,
    this.onTap,
    this.onBookNow,
    this.showStaleBadge = false,
    this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('d MMM yyyy');
    final dateRange =
        '${dateFmt.format(campaign.startDate)} – ${dateFmt.format(campaign.endDate)}';
    final location = campaign.primaryLocationLabel ?? 'Multiple locations';
    final showSlots = campaign.config?.showRemainingSlots != false &&
        campaign.remainingSlots != null &&
        campaign.remainingSlots! > 0;

    return Semantics(
      label: 'Vaccination campaign ${campaign.name}. Book now.',
      button: true,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap?.call(campaign),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroImage(campaign: campaign),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showStaleBadge)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Offline · saved copy',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: cs.outline,
                              ),
                        ),
                      ),
                    Text(
                      campaign.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (campaign.description != null && campaign.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        campaign.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    CampaignCountdownStrip(
                      countdown: countdown,
                      remainingSlots: campaign.remainingSlots,
                      showSlots: campaign.config?.showRemainingSlots != false,
                    ),
                    _MetaRow(icon: Icons.calendar_today_outlined, label: dateRange),
                    const SizedBox(height: 4),
                    _MetaRow(icon: Icons.location_on_outlined, label: location),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CampaignPriceBadge(campaign: campaign),
                        if (campaign.smartConfig.priority.code == 'HIGH') ...[
                          const SizedBox(width: 8),
                          _PriorityPill(label: 'Featured'),
                        ],
                        const Spacer(),
                        FilledButton(
                          onPressed: () =>
                              (onBookNow ?? onTap)?.call(campaign, bookNow: true),
                          child: const Text('Book Now'),
                        ),
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
}

class _HeroImage extends StatelessWidget {
  final PublicCampaign campaign;
  const _HeroImage({required this.campaign});

  @override
  Widget build(BuildContext context) {
    const fallback = 'assets/images/doctor.png';
    final url = campaign.imageUrl;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            CachedNetworkImage(
              imageUrl: url,
              cacheManager: FurtailImageCacheManager(),
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Image.asset(fallback, fit: BoxFit.cover),
            )
          else
            Image.asset(fallback, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _CircleBadge(
              icon: Icons.medical_services_outlined,
              label: 'Vaccination',
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Furtail Official',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CircleBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  final String label;
  const _PriorityPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

