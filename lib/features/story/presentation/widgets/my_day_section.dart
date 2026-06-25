import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/core/theme/spacing.dart';

import '../../domain/entities/story_entity.dart';
import '../providers/story_providers.dart';
import 'story_circle.dart';
import '../screens/create_story_screen.dart';
import '../screens/story_viewer_screen.dart';

/// Horizontal story strip.
/// - "Your Story" (index 0): opens CreateStoryScreen if no story, else bottom sheet
/// - Other users (index 1+): own story is filtered out to prevent double display
/// - Client-side 24h expiry filter
class MyDaySection extends ConsumerWidget {
  const MyDaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storyFeedProvider);

    return SizedBox(
      height: 100,
      child: async.when(
        loading: () => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, _) => _buildPlaceholder(context, ref),
        data: (stories) {
          final now = DateTime.now();
          final active = stories
              .where((s) => now.difference(s.createdAt).inHours < 24)
              .toList();
          return _buildStoryList(context, ref, active);
        },
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, WidgetRef ref) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: AppSpacing.lg),
      children: [
        StoryCircle(
          isOwnStory: true,
          isViewed: false,
          onTap: () => _openCreateStory(context, ref),
        ),
      ],
    );
  }

  Widget _buildStoryList(
    BuildContext context,
    WidgetRef ref,
    List<StoryEntity> active,
  ) {
    final myStory = active.cast<StoryEntity?>().firstWhere(
          (s) => s != null && s.isOwnStory,
          orElse: () => null,
        );

    // Exclude own story from the "others" list so it only shows at position 0
    final otherStories = active.where((s) => !s.isOwnStory).toList();

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: AppSpacing.lg),
      itemCount: otherStories.length + 1,
      separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index == 0) {
          return StoryCircle(
            story: myStory,
            isOwnStory: true,
            isViewed: myStory?.isViewedByMe ?? false,
            onTap: () {
              if (myStory != null) {
                _showYourStorySheet(context, ref, myStory, otherStories);
              } else {
                _openCreateStory(context, ref);
              }
            },
          );
        }
        final story = otherStories[index - 1];
        return StoryCircle(
          story: story,
          isOwnStory: false,
          isViewed: story.isViewedByMe,
          onTap: () => _openViewer(context, otherStories, index - 1),
        );
      },
    );
  }

  void _showYourStorySheet(
    BuildContext context,
    WidgetRef ref,
    StoryEntity myStory,
    List<StoryEntity> otherStories,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('View My Story'),
              onTap: () {
                Navigator.pop(sheetCtx);
                // Pass only own story to viewer
                _openViewer(context, [myStory], 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Add to My Story'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _openCreateStory(context, ref);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(sheetCtx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openCreateStory(BuildContext context, WidgetRef ref) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
    ).then((created) {
      if (created == true) {
        // Notifier already updated optimistically; force full refresh for
        // authoritative isOwnStory from the server.
        ref.read(storyFeedProvider.notifier).refresh();
      }
    });
  }

  void _openViewer(
    BuildContext context,
    List<StoryEntity> stories,
    int initialIndex,
  ) {
    if (stories.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(
          stories: stories,
          initialIndex: initialIndex.clamp(0, stories.length - 1),
        ),
      ),
    );
  }
}
