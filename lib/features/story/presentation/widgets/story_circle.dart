import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/theme/spacing.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';

import '../../domain/entities/story_entity.dart';

/// Single story circle avatar with:
/// - Gradient ring (unviewed) / grey ring (viewed)
/// - User avatar in center
/// - "+" badge for "Your Story"
/// - User name label below
class StoryCircle extends StatelessWidget {
  final StoryEntity? story; // null → "Your Story" placeholder
  final bool isOwnStory; // show "+" badge
  final bool isViewed;
  final VoidCallback onTap;

  const StoryCircle({
    super.key,
    this.story,
    this.isOwnStory = false,
    this.isViewed = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    const avatarSize = 56.0;
    const labelWidth = 72.0;

    final hasStory = story != null;
    final avatarUrl = hasStory
        ? (story!.userAvatarUrl ?? story!.mediaUrl)
        : null;
    final displayName = hasStory ? story!.userName : 'Your Story';
    final isUnviewed = hasStory && !story!.isViewedByMe;

    return SizedBox(
      width: labelWidth,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Gradient ring (unviewed) / grey ring (viewed)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUnviewed
                          ? cs.primary
                          : cs.outlineVariant,
                      width: isUnviewed ? 2.5 : 1.5,
                    ),
                  ),
                  child: FurtailNetworkAvatar(
                    imageUrl: avatarUrl,
                    displayName: displayName,
                    radius: avatarSize / 2 - 2,
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.primary,
                  ),
                ),
                // "+" badge for "Your Story"
                if (isOwnStory)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: Icon(
                        Icons.add,
                        color: cs.onPrimary,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}