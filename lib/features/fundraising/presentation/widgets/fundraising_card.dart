import 'package:flutter/material.dart';

import 'package:furtail_app/core/constants/app_colors.dart';
import 'package:furtail_app/core/theme/app_typography.dart';
import 'package:furtail_app/core/widgets/fit_width_media.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/screens/reels_player_screen.dart';

import '../../data/models/fundraising_models.dart';
import '../utils/fundraising_formatters.dart';

class FundraisingCard extends StatelessWidget {
  const FundraisingCard({super.key, required this.campaign, this.onTap});

  final FundraisingCampaign campaign;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canonicalTarget = campaign.targetAmountMinor ?? campaign.targetAmount;
    final canDonate = campaign.isDonationEligible;
    final statusLabel = _statusLabel(campaign.status);

    return Semantics(
      button: true,
      label: '${campaign.title}. ${campaign.stats.donorsCount} donors.',
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.075),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (campaign.media.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _CampaignMediaPreview(campaign: campaign),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.46),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          top: 14,
                          child: _StatusPill(
                            icon:
                                campaign.status.trim().toUpperCase() ==
                                    'PENDING_REVIEW'
                                ? Icons.fact_check_outlined
                                : Icons.volunteer_activism_outlined,
                            label: statusLabel,
                            foreground: Colors.white,
                            background: Colors.black.withValues(alpha: 0.58),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 14,
                          child: Text(
                            fundraisingDeadlineText(
                              context,
                              campaign.endsAt ?? campaign.deadline,
                            ),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FurtailNetworkAvatar(
                            imageUrl: campaign.author.avatarUrl,
                            displayName: campaign.author.displayName,
                            radius: 19,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            foregroundColor: colorScheme.primary,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  campaign.author.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  campaign.isAccountVerified
                                      ? 'Verified fundraiser account'
                                      : 'Fundraiser account',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (campaign.isAccountVerified)
                            Icon(
                              Icons.verified_rounded,
                              size: 21,
                              color: colorScheme.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        campaign.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cardTitle(
                          context,
                        ).copyWith(fontWeight: FontWeight.w900, height: 1.22),
                      ),
                      if ((campaign.caption ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          campaign.caption!.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                      if ((campaign.category ?? '').trim().isNotEmpty ||
                          (campaign.locationText ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 13),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if ((campaign.category ?? '').trim().isNotEmpty)
                              _MetaChip(
                                icon: Icons.category_outlined,
                                label: campaign.category!.trim(),
                              ),
                            if ((campaign.locationText ?? '').trim().isNotEmpty)
                              _MetaChip(
                                icon: Icons.location_on_outlined,
                                label: campaign.locationText!.trim(),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatFundraisingMoney(
                                context,
                                campaign.stats.raisedAmount,
                              ),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          Text(
                            '${(campaign.progress * 100).round().clamp(0, 999)}%',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'raised of ${formatFundraisingMoney(context, canonicalTarget)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: campaign.progress,
                          minHeight: 10,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${campaign.stats.donorsCount} ${campaign.stats.donorsCount == 1 ? 'donor' : 'donors'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (campaign.last3Donors.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LastDonorsRow(
                                donors: campaign.last3Donors,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: onTap,
                          icon: Icon(
                            canDonate
                                ? Icons.volunteer_activism_outlined
                                : Icons.visibility_outlined,
                          ),
                          label: Text(
                            canDonate
                                ? 'Support this fundraiser'
                                : 'View details',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: canDonate
                                ? AppColors.donateBlue
                                : colorScheme.secondary,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _statusLabel(String raw) {
  final values = raw.trim().toLowerCase().split('_').where((e) => e.isNotEmpty);
  return values
      .map((value) => '${value[0].toUpperCase()}${value.substring(1)}')
      .join(' ');
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LastDonorsRow extends StatelessWidget {
  const _LastDonorsRow({required this.donors});

  final List<FundraisingDonor> donors;

  @override
  Widget build(BuildContext context) {
    final visible = donors.take(3).toList();
    return Text(
      visible.map((donor) => donor.name).join(', '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CampaignMediaPreview extends StatelessWidget {
  const _CampaignMediaPreview({required this.campaign});

  final FundraisingCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final first = campaign.media.first;
    final isVideo = first.type.toUpperCase() == 'VIDEO';

    if (isVideo) {
      return InkWell(
        onTap: () {
          final post = PostModel(
            id: -campaign.id,
            type: 'VIDEO',
            category: 'FUNDRAISING',
            fundraisingCampaignId: campaign.id,
            caption: campaign.caption,
            context: campaign.context,
            createdAt: campaign.createdAt,
            author: PostAuthorModel(
              id: campaign.author.id,
              name: campaign.author.displayName,
              avatarUrl: campaign.author.avatarUrl,
            ),
            media: [
              PostMediaModel(id: first.id, url: first.url, type: 'VIDEO'),
            ],
            likeCount: 0,
            commentCount: 0,
            isLikedByMe: false,
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReelsPlayerScreen(reels: [post], initialIndex: 0),
            ),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black87),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return FitWidthNetworkImage(url: first.url);
  }
}
