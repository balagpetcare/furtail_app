import 'package:flutter/material.dart';

import 'package:furtail_app/core/constants/app_colors.dart';
import 'package:furtail_app/core/theme/app_typography.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/widgets/fit_width_media.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/screens/reels_player_screen.dart';

import '../../data/models/fundraising_models.dart';
import '../utils/fundraising_formatters.dart';

class FundraisingCard extends StatelessWidget {
  const FundraisingCard({
    super.key,
    required this.campaign,
    this.onTap,
  });

  final FundraisingCampaign campaign;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canonicalTarget = campaign.targetAmountMinor ?? campaign.targetAmount;
    final ended = _isEnded(campaign);

    return Semantics(
      button: true,
      label: '${campaign.title}. ${campaign.stats.donorsCount} donors.',
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.75),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (campaign.media.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _CampaignMediaPreview(campaign: campaign),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FurtailNetworkAvatar(
                          imageUrl: campaign.author.avatarUrl,
                          displayName: campaign.author.displayName,
                          radius: 18,
                          backgroundColor:
                              colorScheme.surfaceContainerHighest,
                          foregroundColor: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                campaign.author.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                fundraisingDeadlineText(
                                  context,
                                  campaign.deadline,
                                ),
                                style: AppTypography.caption(context),
                              ),
                            ],
                          ),
                        ),
                        if (campaign.isAccountVerified)
                          _StatusPill(
                            icon: Icons.verified_rounded,
                            label: 'Verified',
                            foreground: colorScheme.primary,
                            background: colorScheme.primaryContainer,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      campaign.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle(context).copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    if ((campaign.caption ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        campaign.caption!.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if ((campaign.category ?? '').trim().isNotEmpty ||
                        (campaign.locationText ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
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
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: campaign.progress,
                        minHeight: 9,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatFundraisingMoney(
                                  context,
                                  campaign.stats.raisedAmount,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              Text(
                                'raised of ${formatFundraisingMoney(context, canonicalTarget)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${campaign.stats.donorsCount}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              campaign.stats.donorsCount == 1
                                  ? 'donor'
                                  : 'donors',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (campaign.last3Donors.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _LastDonorsRow(donors: campaign.last3Donors),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: onTap,
                        icon: Icon(
                          ended
                              ? Icons.visibility_outlined
                              : Icons.volunteer_activism_outlined,
                        ),
                        label: Text(
                          ended ? 'View fundraiser' : 'Donate now',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: ended
                              ? colorScheme.secondary
                              : AppColors.donateBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
    );
  }

  bool _isEnded(FundraisingCampaign value) {
    final status = value.status.trim().toUpperCase();
    if (const {'COMPLETED', 'CLOSED', 'CANCELLED', 'REJECTED'}.contains(status)) {
      return true;
    }
    final deadline = value.deadline;
    return deadline != null && deadline.isBefore(DateTime.now());
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
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
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
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
    final colorScheme = Theme.of(context).colorScheme;
    final visible = donors.take(3).toList();
    return Row(
      children: [
        Icon(Icons.favorite_rounded, size: 17, color: colorScheme.error),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            visible.map((donor) => donor.name).join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
