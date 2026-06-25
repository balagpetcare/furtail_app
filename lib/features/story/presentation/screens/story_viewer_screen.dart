import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:furtail_app/core/media/furtail_cache_manager.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';

import '../../domain/entities/story_entity.dart';
import '../providers/story_providers.dart';
import 'package:furtail_app/core/navigation/profile_navigation.dart';

/// Full-screen story viewer with:
/// - Animated per-story progress bar (5 s auto-advance)
/// - Tap left/right to navigate, swipe down to close
/// - Owner avatar, name, time
/// - Delete option for own stories (wired to [storyFeedProvider])
/// - Mark viewed on each story show
class StoryViewerScreen extends ConsumerStatefulWidget {
  final List<StoryEntity> stories;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  static const _storyDuration = Duration(seconds: 5);

  late int _currentIndex;
  late PageController _pageCtrl;
  late AnimationController _progressCtrl;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _currentIndex);
    _progressCtrl = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) _next();
      });
    _startProgress();
    _markViewed(_currentIndex);
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startProgress() {
    _progressCtrl.reset();
    _progressCtrl.forward();
  }

  void _next() {
    if (_currentIndex < widget.stories.length - 1) {
      _pageCtrl.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      _pageCtrl.animateToPage(
        _currentIndex - 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _startProgress();
    _markViewed(index);
  }

  void _markViewed(int index) {
    final story = widget.stories[index];
    if (!story.isViewedByMe) {
      ref.read(storyFeedProvider.notifier).markViewed(story.id);
    }
  }

  Future<void> _deleteCurrentStory() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    _progressCtrl.stop();
    try {
      await ref
          .read(storyFeedProvider.notifier)
          .deleteStory(widget.stories[_currentIndex].id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        _progressCtrl.forward();
      }
    }
  }

  void _navigateToProfile() async {
    _progressCtrl.stop();
    final story = widget.stories[_currentIndex];
    final targetUserId = int.tryParse(story.userId) ?? 0;

    await ProfileNavigation.openUserProfile(context, targetUserId);

    if (mounted) {
      _progressCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.stories.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Swipe down to close
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 250) {
            Navigator.pop(context);
          }
        },
        // Tap left / right to navigate
        onTapUp: (details) {
          final w = MediaQuery.sizeOf(context).width;
          if (details.localPosition.dx < w / 3) {
            _prev();
          } else if (details.localPosition.dx > w * 2 / 3) {
            _next();
          }
        },
        child: Stack(
          children: [
            // ── Media pages ───────────────────────────────────────────────
            PageView.builder(
              controller: _pageCtrl,
              itemCount: total,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final s = widget.stories[index];
                return _StoryMedia(story: s);
              },
            ),

            // ── Top overlay: progress bars + close/delete + user info ─────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress bars
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: List.generate(total, (i) {
                          return Expanded(
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              height: 2.5,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: i < _currentIndex
                                    ? const ColoredBox(color: Colors.white)
                                    : i == _currentIndex
                                        ? AnimatedBuilder(
                                            animation: _progressCtrl,
                                            builder: (_, _) =>
                                                LinearProgressIndicator(
                                              value: _progressCtrl.value,
                                              backgroundColor: Colors.white30,
                                              valueColor:
                                                  const AlwaysStoppedAnimation(
                                                      Colors.white),
                                            ),
                                          )
                                        : const ColoredBox(
                                            color: Colors.white30),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Close / delete row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 0),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.40),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const Spacer(),
                          if (widget.stories[_currentIndex].isOwnStory)
                            _deleting
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.40),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.white),
                                      onPressed: _deleteCurrentStory,
                                    ),
                                  ),
                        ],
                      ),
                    ),

                    // User info
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _UserInfoRow(
                        story: widget.stories[_currentIndex],
                        onTap: _navigateToProfile,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom caption ────────────────────────────────────────────
            if (_currentIndex < widget.stories.length)
              _BottomCaption(story: widget.stories[_currentIndex]),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _StoryMedia extends StatelessWidget {
  final StoryEntity story;
  const _StoryMedia({required this.story});

  @override
  Widget build(BuildContext context) {
    if (story.mediaUrl == null || story.mediaUrl!.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }
    return CachedNetworkImage(
      imageUrl: story.mediaUrl!,
      cacheManager: FurtailImageCacheManager(),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, _) => const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      ),
      errorWidget: (_, _, _) => Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
        ),
      ),
    );
  }
}

class _UserInfoRow extends StatelessWidget {
  final StoryEntity story;
  final VoidCallback onTap;
  const _UserInfoRow({required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FurtailNetworkAvatar(
            imageUrl: story.userAvatarUrl,
            displayName: story.userName,
            radius: 18,
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                story.userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                _timeAgo(story.createdAt),
                style:
                    const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _BottomCaption extends StatelessWidget {
  final StoryEntity story;
  const _BottomCaption({required this.story});

  @override
  Widget build(BuildContext context) {
    final caption = story.caption;
    if (caption == null || caption.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 20),
          child: Text(
            caption,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
