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
              style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              itemCount: reels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final r = reels[i];
                final thumb = r.media
                    .where((m) => m.type.toUpperCase() == 'IMAGE')
                    .map((m) => m.url)
                    .cast<String?>()
                    .firstWhere(
                      (u) => (u ?? '').isNotEmpty,
                      orElse: () => null,
                    );

                return ReelTile(
                  title: r.author.name,
                  thumbUrl: thumb,
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

class ReelTile extends StatelessWidget {
  final String title;
  final String? thumbUrl;
  final VoidCallback onTap;
  const ReelTile({
    super.key,
    required this.title,
    required this.thumbUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tileSize = MediaQuery.sizeOf(context).width < 360 ? 84.0 : 92.0;
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
                  SizedBox(
                    height: tileSize,
                    width: tileSize,
                    child: thumbUrl == null
                        ? ColoredBox(
                            color: context.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.play_circle_fill,
                              size: 34,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : FurtailCachedImage(
                            imageUrl: thumbUrl,
                            width: tileSize,
                            height: tileSize,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 34,
                        color: Colors.white,
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
