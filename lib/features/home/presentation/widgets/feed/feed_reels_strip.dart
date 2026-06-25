import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';

import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/screens/reels_player_screen.dart';

class ReelsStrip extends StatelessWidget {
  final List<PostModel> reels;
  const ReelsStrip({super.key, required this.reels});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: context.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              'Reels',
              style: context.appText.bodyLarge!.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              itemCount: reels.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final r = reels[i];
                final videoMedia = r.media
                    .where(
                      (m) =>
                          m.type.toUpperCase() == 'VIDEO' ||
                          m.type.toUpperCase() == 'REEL',
                    )
                    .fold<PostMediaModel?>(null, (prev, m) => prev ?? m);
                final rawStatus = (videoMedia?.status ?? 'READY').toUpperCase();
                final hasUrl = (videoMedia?.url ?? '').isNotEmpty;
                // Show as READY when video is playable even while HD processing
                final status = (rawStatus == 'PENDING' || rawStatus == 'PROCESSING') && hasUrl
                    ? 'READY'
                    : rawStatus;
                final thumb = videoMedia?.thumbnailUrl?.isNotEmpty == true
                    ? videoMedia!.thumbnailUrl
                    : null;

                return ReelTile(
                  key: ValueKey(r.id),
                  title: r.author.name,
                  thumbUrl: thumb,
                  status: status,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReelsPlayerScreen(reels: reels, initialIndex: i),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(thickness: 1, color: Color(0xFFEEEEEE), height: 1),
        ],
      ),
    );
  }
}

/// Thumbnail-only reel tile.
///
/// Previously this widget initialized a [VideoPlayerController] in initState
/// for each tile, creating up to 12 live controllers on the Home screen even
/// before the user tapped a single reel. That caused significant memory
/// pressure and scroll jank on mid-range devices.
///
/// Now it shows a static thumbnail with a play-icon overlay. The real video
/// controller is created only inside [ReelsPlayerScreen] when the user taps.
class ReelTile extends StatelessWidget {
  final String title;
  final String? thumbUrl;
  final String status;
  final VoidCallback onTap;

  const ReelTile({
    super.key,
    required this.title,
    required this.thumbUrl,
    this.status = 'READY',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tileSize = MediaQuery.sizeOf(context).width < 360 ? 84.0 : 92.0;
    final isProcessing = status == 'PENDING' || status == 'PROCESSING';
    final isFailed = status == 'FAILED';

    final Widget thumbnail = thumbUrl != null && thumbUrl!.isNotEmpty
        ? FurtailCachedImage(
            imageUrl: thumbUrl!,
            width: tileSize,
            height: tileSize,
            fit: BoxFit.cover,
          )
        : ColoredBox(
            color: cs.surfaceContainerHighest,
            child: Center(
              child: Icon(
                isFailed
                    ? Icons.error_outline_rounded
                    : isProcessing
                    ? Icons.hourglass_empty_rounded
                    : Icons.play_circle_fill,
                size: 34,
                color: isFailed ? cs.error : cs.onSurfaceVariant,
              ),
            ),
          );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      child: SizedBox(
        width: tileSize,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.lg),
              child: Stack(
                children: [
                  SizedBox(height: tileSize, width: tileSize, child: thumbnail),
                  if (!isProcessing && !isFailed)
                    const Positioned.fill(
                      child: Align(
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 34,
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black45),
                          ],
                        ),
                      ),
                    ),
                  if (isProcessing || isFailed)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.42),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          isFailed ? 'Failed' : 'Processing...',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.appText.bodySmall!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appText.bodySmall!,
            ),
          ],
        ),
      ),
    );
  }
}
