import 'package:flutter/material.dart';
import 'package:bpa_app/core/constants/app_colors.dart';
import 'package:bpa_app/core/theme/app_typography.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/widgets/bpa_network_image.dart';
import 'package:bpa_app/core/widgets/fit_width_media.dart';
import 'package:bpa_app/features/posts/presentation/screens/reels_player_screen.dart';
import 'package:bpa_app/features/posts/data/models/post_model.dart';
import '../../data/models/fundraising_models.dart';

class FundraisingCard extends StatelessWidget {
  final FundraisingCampaign campaign;
  final VoidCallback? onTap;

  const FundraisingCard({super.key, required this.campaign, this.onTap});

  @override
  Widget build(BuildContext context) {
    final deadline = campaign.deadline;
    final deadlineText = deadline == null
        ? null
        : '${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')}';
    final remainingDays = campaign.remainingDays;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media preview (image/video) if exists (single place)
              if (campaign.media.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _CampaignMediaPreview(campaign: campaign),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  BpaNetworkAvatar(
                    imageUrl: campaign.author.avatarUrl,
                    displayName: campaign.author.displayName,
                    radius: 16,
                    backgroundColor: context.colorScheme.surfaceContainerHighest,
                    foregroundColor: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cardTitle(context),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          campaign.author.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(context),
                        ),
                      ],
                    ),
                  ),
                  if (campaign.isAccountVerified)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(
                        label: const Text('Verified'),
                        labelStyle: Theme.of(context).textTheme.labelSmall,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              if ((campaign.caption ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  campaign.caption!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // (removed duplicate media preview)
              const SizedBox(height: 12),
              LinearProgressIndicator(value: campaign.progress, minHeight: 8),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Raised: ${campaign.stats.raisedAmount} / ${campaign.targetAmount}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    'Remaining: ${campaign.remainingAmount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (deadlineText != null) ...[
                const SizedBox(height: 6),
                Text(
                  remainingDays == null
                      ? 'Deadline: $deadlineText'
                      : 'Deadline: $deadlineText • $remainingDays days left',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],

              if ((campaign.category ?? '').trim().isNotEmpty || (campaign.locationText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  [
                    if ((campaign.category ?? '').trim().isNotEmpty) 'Category: ${campaign.category}',
                    if ((campaign.locationText ?? '').trim().isNotEmpty) 'Location: ${campaign.locationText}',
                  ].join(' • '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],

              if (campaign.last3Donors.isNotEmpty) ...[
                const SizedBox(height: 8),
                _LastDonorsRow(donors: campaign.last3Donors),
              ],

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.volunteer_activism_outlined),
                  label: const Text('Donate Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.donateBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastDonorsRow extends StatelessWidget {
  final List<FundraisingDonor> donors;
  const _LastDonorsRow({required this.donors});

  @override
  Widget build(BuildContext context) {
    final show = donors.take(3).toList();
    return Row(
      children: [
        const Icon(Icons.favorite, size: 16, color: Colors.redAccent),
        const SizedBox(width: 6),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: show.map((d) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.grey.withOpacity(0.10),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Text(
                  d.amount == null ? d.name : '${d.name} (${d.amount})',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _CampaignMediaPreview extends StatelessWidget {
  final FundraisingCampaign campaign;
  const _CampaignMediaPreview({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final first = campaign.media.first;
    final isVideo = first.type.toUpperCase() == 'VIDEO';

    if (isVideo) {
      return InkWell(
        onTap: () {
          // We don't have a full PostModel here, but ReelsPlayerScreen expects PostModel.
          // Best effort: create a minimal PostModel instance with the media url.
          final p = PostModel(
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
              builder: (_) => ReelsPlayerScreen(reels: [p], initialIndex: 0),
            ),
          );
        },
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black12),
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FitWidthNetworkImage(url: first.url);
  }
}
