import 'package:flutter/material.dart';

import 'package:furtail_app/core/theme/theme_extensions.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';

import '../../domain/entities/story_entity.dart';

/// Facebook-style rectangular story card: cover media with a bottom
/// gradient for legibility, a small avatar-ring identity chip, and a name
/// label. The "Create story" card (index 0, [story] == null) instead shows
/// the current user's own avatar as the cover with a centered "+" affordance.
class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    this.story,
    this.isOwnStory = false,
    this.isViewed = false,
    this.ownAvatarUrl,
    this.ownDisplayName,
    required this.onTap,
  });

  /// null → the "Create story" card.
  final StoryEntity? story;
  final bool isOwnStory;
  final bool isViewed;

  /// Only used for the "Create story" card, when the user has no active
  /// story yet — shows their own profile photo as the cover.
  final String? ownAvatarUrl;
  final String? ownDisplayName;

  final VoidCallback onTap;

  static const double cardWidth = 104;
  static const double cardHeight = 168;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final hasStory = story != null;
    final isCreateCard = isOwnStory && !hasStory;

    // Prefer the real poster/thumbnail (always populated for images; for
    // video it's the extracted frame once the async pipeline finishes) over
    // the raw media file — feeding a .mp4 URL to an image widget always fails.
    final coverUrl = hasStory
        ? (story!.thumbnailUrl ?? story!.mediaUrl ?? story!.userAvatarUrl)
        : ownAvatarUrl;
    final name = hasStory ? story!.userName : (ownDisplayName ?? 'Your Story');
    final isUnviewed = hasStory && !story!.isViewedByMe;

    return Semantics(
      button: true,
      label: isCreateCard
          ? 'Create story'
          : hasStory
          ? "$name's story${isUnviewed ? ', unviewed' : ''}"
          : 'Your story',
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: Material(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FurtailCachedImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    color: cs.primaryContainer,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.pets_rounded,
                      color: cs.onPrimaryContainer,
                      size: 32,
                    ),
                  ),
                ),
                // Bottom gradient for label legibility.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: isCreateCard ? 56 : 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isCreateCard)
                  _CreateStoryFooter(cs: cs)
                else ...[
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isUnviewed ? cs.primary : cs.outlineVariant,
                          width: isUnviewed ? 2.5 : 1.5,
                        ),
                        color: cs.surface,
                      ),
                      child: FurtailNetworkAvatar(
                        imageUrl: hasStory ? story!.userAvatarUrl : null,
                        displayName: name,
                        radius: 14,
                        backgroundColor: cs.surfaceContainerHighest,
                        foregroundColor: cs.primary,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateStoryFooter extends StatelessWidget {
  const _CreateStoryFooter({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(Icons.add_rounded, color: cs.onPrimary, size: 20),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Create story',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
