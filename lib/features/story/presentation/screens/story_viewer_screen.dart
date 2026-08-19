import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:furtail_app/core/media/furtail_cache_manager.dart';
import 'package:furtail_app/core/widgets/furtail_network_image.dart';

import '../../domain/entities/story_entity.dart';
import '../providers/story_providers.dart';
import 'package:furtail_app/core/navigation/profile_navigation.dart';

/// Full-screen story viewer with:
/// - Animated per-story progress bar (fixed duration for images, real video
///   duration/position for videos)
/// - Image and video playback with loading/error/retry states — never a bare
///   black screen
/// - Preloads the next item's media while the current one is showing
/// - Tap left/right to navigate, hold to pause, swipe down to close
/// - Owner avatar, name, time; mute toggle for video
/// - Delete option for own stories (wired to [storyFeedProvider])
/// - Mark viewed on each story show (idempotent within the session)
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _imageDuration = Duration(seconds: 5);
  static const _maxVideoProgressDuration = Duration(seconds: 60);
  static const _fallbackVideoProgressDuration = Duration(seconds: 15);

  late int _currentIndex;
  late PageController _pageCtrl;
  late AnimationController _progressCtrl;
  final Set<int> _locallyMarkedViewed = {};
  VideoPlayerController? _activeVideoController;
  bool _deleting = false;
  bool _paused = false;
  bool _muted = false;

  StoryEntity get _currentStory => widget.stories[_currentIndex];
  bool get _currentIsVideo => _currentStory.mediaType == 'video';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _currentIndex);
    _progressCtrl = AnimationController(vsync: this, duration: _imageDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) _next();
      });
    if (!_currentIsVideo) _startImageProgress();
    _markViewed(_currentIndex);
    // precacheImage() needs an inherited-widget-ready context, which isn't
    // available yet mid-initState — defer to just after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _preloadNext(_currentIndex);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _setPaused(true);
    } else if (state == AppLifecycleState.resumed) {
      _setPaused(false);
    }
  }

  void _setPaused(bool paused) {
    if (_paused == paused) return;
    _paused = paused;
    if (paused) {
      _progressCtrl.stop();
      _activeVideoController?.pause();
    } else {
      if (_currentIsVideo) {
        _activeVideoController?.play();
      } else {
        _progressCtrl.forward();
      }
    }
  }

  void _startImageProgress() {
    _progressCtrl
      ..duration = _imageDuration
      ..reset()
      ..forward();
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
    setState(() {
      _currentIndex = index;
      _activeVideoController = null;
    });
    _progressCtrl.stop();
    _progressCtrl.value = 0;
    if (!_currentIsVideo) _startImageProgress();
    _markViewed(index);
    _preloadNext(index);
  }

  void _preloadNext(int index) {
    final nextIndex = index + 1;
    if (nextIndex >= widget.stories.length) return;
    final next = widget.stories[nextIndex];
    final url = next.mediaUrl;
    if (url == null || url.isEmpty) return;
    if (next.mediaType == 'video') {
      unawaited(VideoCacheService.instance.prefetchVideo(url));
    } else {
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(
            url,
            cacheManager: FurtailImageCacheManager(),
          ),
          context,
        ),
      );
    }
  }

  void _markViewed(int index) {
    final story = widget.stories[index];
    if (story.isViewedByMe || _locallyMarkedViewed.contains(story.id)) return;
    _locallyMarkedViewed.add(story.id);
    ref.read(storyFeedProvider.notifier).markViewed(story.id);
  }

  void _onVideoReady(int index, VideoPlayerController controller) {
    if (!mounted || index != _currentIndex) return;
    setState(() => _activeVideoController = controller);
    final duration = controller.value.duration;
    final capped = duration <= Duration.zero
        ? _fallbackVideoProgressDuration
        : (duration > _maxVideoProgressDuration
              ? _maxVideoProgressDuration
              : duration);
    _progressCtrl
      ..duration = capped
      ..reset();
    if (!_paused) {
      _progressCtrl.forward();
      controller.play();
    }
  }

  void _onVideoCompleted(int index) {
    if (!mounted || index != _currentIndex) return;
    _next();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _activeVideoController?.setVolume(_muted ? 0 : 1);
  }

  Future<void> _deleteCurrentStory() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    _setPaused(true);
    try {
      await ref
          .read(storyFeedProvider.notifier)
          .deleteStory(widget.stories[_currentIndex].id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        _setPaused(false);
      }
    }
  }

  void _navigateToProfile() async {
    _setPaused(true);
    final story = widget.stories[_currentIndex];
    final targetUserId = int.tryParse(story.userId) ?? 0;

    await ProfileNavigation.openUserProfile(context, targetUserId);

    if (mounted) {
      _setPaused(false);
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
        // Hold to pause, release to resume
        onLongPressStart: (_) => _setPaused(true),
        onLongPressEnd: (_) => _setPaused(false),
        onLongPressCancel: () => _setPaused(false),
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
                return _StoryMedia(
                  key: ValueKey('story_media_${s.id}'),
                  story: s,
                  isActive: index == _currentIndex,
                  muted: _muted,
                  onVideoReady: (controller) =>
                      _onVideoReady(index, controller),
                  onVideoCompleted: () => _onVideoCompleted(index),
                );
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
                              margin: const EdgeInsets.symmetric(horizontal: 2),
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
                                                    Colors.white,
                                                  ),
                                            ),
                                      )
                                    : const ColoredBox(color: Colors.white30),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Close / mute / delete row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.40),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const Spacer(),
                          if (_currentIsVideo && _activeVideoController != null)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.40),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _muted ? Icons.volume_off : Icons.volume_up,
                                  color: Colors.white,
                                ),
                                onPressed: _toggleMute,
                              ),
                            ),
                          if (widget.stories[_currentIndex].isOwnStory)
                            _deleting
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.40,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                      ),
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

class _StoryMedia extends StatefulWidget {
  final StoryEntity story;
  final bool isActive;
  final bool muted;
  final ValueChanged<VideoPlayerController> onVideoReady;
  final VoidCallback onVideoCompleted;

  const _StoryMedia({
    super.key,
    required this.story,
    required this.isActive,
    required this.muted,
    required this.onVideoReady,
    required this.onVideoCompleted,
  });

  @override
  State<_StoryMedia> createState() => _StoryMediaState();
}

class _StoryMediaState extends State<_StoryMedia> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _errored = false;
  int _retryToken = 0;

  bool get _isVideo => widget.story.mediaType == 'video';

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _initVideo();
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(covariant _StoryMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.isActive && !oldWidget.isActive) {
      controller.seekTo(Duration.zero);
      controller.play();
    } else if (!widget.isActive && oldWidget.isActive) {
      controller.pause();
    }
    if (widget.muted != oldWidget.muted) {
      controller.setVolume(widget.muted ? 0 : 1);
    }
  }

  Future<void> _initVideo() async {
    final url = widget.story.mediaUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errored = true;
        });
      }
      return;
    }

    final token = ++_retryToken;
    VideoPlayerController? controller;
    try {
      final file = await VideoCacheService.instance.getVideoFile(url);
      controller = VideoPlayerController.file(file);
      await controller.initialize();
    } catch (_) {
      try {
        controller?.dispose();
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
        await controller.initialize();
      } catch (_) {
        controller?.dispose();
        if (mounted && token == _retryToken) {
          setState(() {
            _loading = false;
            _errored = true;
          });
        }
        return;
      }
    }

    if (!mounted || token != _retryToken) {
      controller.dispose();
      return;
    }

    controller.setLooping(false);
    controller.setVolume(widget.muted ? 0 : 1);
    controller.addListener(_onVideoTick);
    setState(() {
      _controller = controller;
      _loading = false;
      _errored = false;
    });
    widget.onVideoReady(controller);
  }

  void _onVideoTick() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    if (value.duration > Duration.zero && value.position >= value.duration) {
      widget.onVideoCompleted();
    }
  }

  void _retry() {
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    setState(() {
      _controller = null;
      _loading = true;
      _errored = false;
    });
    _initVideo();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.story.mediaUrl;
    if (url == null || url.isEmpty) {
      return const _StoryMediaError(message: 'This story is unavailable.');
    }

    if (_isVideo) {
      if (_errored) {
        return _StoryMediaError(
          message: "Couldn't load this video.",
          onRetry: _retry,
        );
      }
      final controller = _controller;
      if (_loading || controller == null || !controller.value.isInitialized) {
        return const _StoryMediaLoading();
      }
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
    }

    return CachedNetworkImage(
      key: ValueKey('story_image_${widget.story.id}_$_retryToken'),
      imageUrl: url,
      cacheManager: FurtailImageCacheManager(),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, _) => const _StoryMediaLoading(),
      errorWidget: (_, _, _) => _StoryMediaError(
        message: "Couldn't load this image.",
        onRetry: () => setState(() => _retryToken++),
      ),
    );
  }
}

class _StoryMediaLoading extends StatelessWidget {
  const _StoryMediaLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(child: CircularProgressIndicator(color: Colors.white54)),
    );
  }
}

class _StoryMediaError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _StoryMediaError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image, color: Colors.white54, size: 64),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              child: const Text('Retry'),
            ),
          ],
        ],
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
                style: const TextStyle(color: Colors.white60, fontSize: 11),
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
