import 'package:furtail_app/core/theme/typography.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/widgets/comments_sheet.dart';
import 'package:furtail_app/features/posts/presentation/widgets/report_bottom_sheet.dart';
import 'package:furtail_app/core/media/media_playback_controller.dart';
import 'package:furtail_app/core/media/media_url.dart';
import 'package:furtail_app/app/router/app_routes.dart';
import 'package:furtail_app/core/services/share_service.dart';

class ReelsPlayerScreen extends StatefulWidget {
  final List<PostModel> reels;
  final int initialIndex;

  const ReelsPlayerScreen({
    super.key,
    required this.reels,
    this.initialIndex = 0,
  });

  @override
  State<ReelsPlayerScreen> createState() => _ReelsPlayerScreenState();
}

class _ReelsPlayerScreenState extends State<ReelsPlayerScreen>
    with WidgetsBindingObserver {
  // Reels: caption/text overlay is handled per-page. We keep this screen lean
  // to avoid rebuild-driven controller churn.
  final _ds = PostsRemoteDs();
  final media = MediaPlaybackController.instance;
  late final PageController _page;

  int _index = 0;
  VideoPlayerController? _vc;
  Future<void>? _init;

  int _prepareToken = 0;
  VoidCallback? _playbackListener;
  bool _wakelockHeld = false;
  int _loopCount = 0;
  // _endGate = false;
  bool _endGate = false;

  // Token to protect against async callbacks from a disposed/old controller.
  // int _prepareToken = 0;

  late List<PostModel> _reels;

  VoidCallback? _muteListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    media.ensureInitialized().then((_) {
      // Premium reels UX: start muted by default.
      if (mounted) {
        media.isMuted.value = true;
      }
    });
    _muteListener = () {
      final vc = _vc;
      if (vc == null) return;
      try {
        vc.setVolume(media.isMuted.value ? 0.0 : media.volume.value);
      } catch (_) {
        // In rare cases the controller can be disposed while the listener fires.
      }
    };
    media.isMuted.addListener(_muteListener!);
    _reels = List<PostModel>.from(widget.reels);
    _index = widget.initialIndex.clamp(
      0,
      (widget.reels.length - 1).clamp(0, 999),
    );
    _page = PageController(initialPage: _index);
    _prepare(_index);
  }

  void _syncWakelock(bool shouldHold) {
    // Keep screen awake while a reel is actively playing.
    if (shouldHold == _wakelockHeld) return;
    _wakelockHeld = shouldHold;
    if (shouldHold) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    if (_muteListener != null) {
      media.isMuted.removeListener(_muteListener!);
    }
    WidgetsBinding.instance.removeObserver(this);
    final c = _vc;
    _vc = null;
    try {
      c?.pause();
    } catch (_) {}
    c?.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _vc;
    if (c == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      try {
        c.pause();
      } catch (_) {}
    }
  }

  void _prepare(int idx) {
    final int token = ++_prepareToken;

    final old = _vc;
    if (old != null) {
      old.removeListener(_playbackListener ?? () {});
      old.pause();
      old.dispose();
    }
    _vc = null;
    _init = null;
    _loopCount = 0;
    _endGate = false;
    _syncWakelock(false);

    final post = _reels[idx];
    final m = post.media.isEmpty
        ? null
        : post.media.firstWhere(
            (x) => x.type.toUpperCase() == 'VIDEO',
            orElse: () => post.media.first,
          );
    final url = MediaUrl.normalize(m?.url ?? '');
    if (url.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _vc = controller;

    // Playback listener: wakelock + 5x looping.
    _playbackListener = () {
      final c = _vc;
      if (c == null || c != controller) return;

      final v = c.value;
      // Wakelock while playing
      _syncWakelock(v.isPlaying);

      // Loop max 5 times
      final dur = v.duration;
      final pos = v.position;
      if (dur.inMilliseconds > 0 &&
          pos.inMilliseconds >= dur.inMilliseconds - 200) {
        if (_loopCount < 5) {
          _loopCount++;
          // Avoid triggering multiple times at end boundary.
          c.seekTo(Duration.zero).then((_) {
            if (!mounted || token != _prepareToken) return;
            c.play();
          });
        } else {
          // Stop after 5 loops (Premium requirement)
          c.pause();
        }
      }
    };
    controller.addListener(_playbackListener!);

    _init = controller
        .initialize()
        .then((_) async {
          if (!mounted || token != _prepareToken) return;

          controller.setLooping(false);
          controller.setVolume(media.isMuted.value ? 0.0 : media.volume.value);

          // Start playing immediately
          await controller.play();
          if (!mounted || token != _prepareToken) return;

          setState(() {});
        })
        .catchError((e) {
          debugPrint('Reels init failed: $e');
        });

    if (mounted) setState(() {});
  }

  Future<void> _toggleLike(int postId, bool currentlyLiked) async {
    final i = _reels.indexWhere((p) => p.id == postId);
    if (i >= 0) {
      final p = _reels[i];
      // Inside _toggleLike
      final next = PostModel(
        id: p.id,
        type: p.type,
        caption: p.caption,
        context: p.context,
        createdAt: p.createdAt,
        author: p.author,
        media: p.media,
        likeCount: (p.likeCount + (currentlyLiked ? -1 : 1)).clamp(0, 1 << 30),
        commentCount: p.commentCount,
        isLikedByMe: !currentlyLiked,
        category: p.category, // ADD THIS LINE
      );
      _reels[i] = next;
      if (mounted) setState(() {});
    }
    try {
      if (currentlyLiked) {
        final res = await _ds.unlikePost(postId);
        _applyCounts(postId, res);
      } else {
        final res = await _ds.likePost(postId);
        _applyCounts(postId, res);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Like failed: ${e.toString()}')));
    }
  }

  void _applyCounts(int postId, Map<String, dynamic> data) {
    final i = _reels.indexWhere((p) => p.id == postId);
    if (i < 0) return;
    final p = _reels[i];
    final likeCount = (data['likeCount'] as num?)?.toInt() ?? p.likeCount;
    final commentCount =
        (data['commentCount'] as num?)?.toInt() ?? p.commentCount;
    final isLikedByMe = (data['isLikedByMe'] as bool?) ?? p.isLikedByMe;
    _reels[i] = PostModel(
      id: p.id,
      type: p.type,
      caption: p.caption,
      context: p.context,
      createdAt: p.createdAt,
      author: p.author,
      media: p.media,
      likeCount: likeCount,
      commentCount: commentCount,
      isLikedByMe: isLikedByMe,
      category: p.category, // Pass the category from the original object 'p'
    );
    if (mounted) setState(() {});
  }

  void _openComments(PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: CommentsSheet(
          postId: post.id,
          onCountChanged: (n) {
            final i = _reels.indexWhere((p) => p.id == post.id);
            if (i < 0) return;
            final p = _reels[i];
            _reels[i] = PostModel(
              id: p.id,
              type: p.type,
              caption: p.caption,
              context: p.context,
              createdAt: p.createdAt,
              author: p.author,
              media: p.media,
              likeCount: p.likeCount,
              commentCount: n,
              isLikedByMe: p.isLikedByMe,
              category: p.category,
              fundraisingCampaignId: p.fundraisingCampaignId,
            );
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reels = _reels;
    if (reels.isEmpty) {
      return const Scaffold(body: Center(child: Text('No reels')));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            onPageChanged: (i) {
              _index = i;
              _prepare(i);
            },
            itemBuilder: (_, i) {
              final post = reels[i];
              final isCurrent = i == _index;
              final vc = isCurrent ? _vc : null;
              final init = isCurrent ? _init : null;

              return _ReelPage(
                post: post,
                controller: vc,
                init: init,
                onLike: () => _toggleLike(post.id, post.isLikedByMe),
                onComment: () => _openComments(post),
                onToggleMute: media.toggleMute,
                onShare: () {
                  final fundraisingId = post.fundraisingCampaignId;
                  if (fundraisingId != null) {
                    ShareService.share(context, type: 'fundraising', id: fundraisingId);
                  } else {
                    ShareService.share(context, type: 'post', id: post.id);
                  }
                },
                onReport: () => ReportBottomSheet.showPost(context, postId: post.id),
              );
            },
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelPage extends StatefulWidget {
  final PostModel post;
  final VideoPlayerController? controller;
  final Future<void>? init;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback onToggleMute;

  const _ReelPage({
    required this.post,
    required this.controller,
    required this.init,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onReport,
    required this.onToggleMute,
  });

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  bool _captionVisible = true;
  bool _uiVisible = true;
  Timer? _uiHideTimer;
  double _lastTapDx = 0;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    // First reel: schedule auto-hide once initialized.
    widget.init?.then((_) {
      if (!mounted) return;
      _scheduleAutoHide();
    });
  }

  @override
  void didUpdateWidget(covariant _ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _autoHideTimer?.cancel();
      _captionVisible = true;
      // When the new reel is ready, hide text after a few seconds.
      widget.init?.then((_) {
        if (!mounted) return;
        _scheduleAutoHide();
      });
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _uiHideTimer?.cancel();
    super.dispose();
  }

  void _scheduleUiAutoHide() {
    _uiHideTimer?.cancel();
    _uiHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _uiVisible = false);
    });
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    setState(() {
      _captionVisible = true;
      _uiVisible = true;
    });
    _scheduleUiAutoHide();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      // Only hide if still playing.
      final c = widget.controller;
      if (c != null && c.value.isPlaying) {
        setState(() => _captionVisible = false);
      }
    });
  }

  Future<void> _showVolumePopup(BuildContext context) async {
    final media = MediaPlaybackController.instance;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: ValueListenableBuilder<double>(
              valueListenable: media.volume,
              builder: (_, vol, __) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sound',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: vol.clamp(0.0, 1.0).toDouble(),
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) {
                        media.setVolume(v);
                        // If user drags volume up, auto unmute.
                        if (media.isMuted.value && v > 0) {
                          media.isMuted.value = false;
                        }
                        final c = widget.controller;
                        if (c != null) {
                          c.setVolume(
                            media.isMuted.value ? 0.0 : media.volume.value,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      media.isMuted.value ? 'Muted' : 'On',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final controller = widget.controller;
    final init = widget.init;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _lastTapDx = d.localPosition.dx,
          onTap: () {
            // One tap: show/hide UI (caption + controls).
            setState(() {
              final next = !_uiVisible;
              _uiVisible = next;
              _captionVisible = next;
            });
            if (_uiVisible) {
              _scheduleUiAutoHide();
            }
          },
          onDoubleTap: widget.onLike, // double tap = like (Premium UX)
          onLongPressStart: (_) {
            // Long press on the RIGHT side = 1.5x speed.
            if (_lastTapDx >= w * 0.65) {
              controller?.setPlaybackSpeed(1.5);
            }
          },
          onLongPressEnd: (_) {
            controller?.setPlaybackSpeed(1.0);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (controller == null || init == null)
                const Center(child: CircularProgressIndicator())
              else
                FutureBuilder<void>(
                  future: init,
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    );
                  },
                ),

              // Gradient for legibility
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      // Search for the Gradient section in _ReelPage
                      colors: [
                        Colors.black.withValues(
                          alpha: 0.25,
                        ), // Changed from withOpacity
                        Colors.transparent,
                        Colors.black.withValues(
                          alpha: 0.6,
                        ), // Changed from withOpacity
                      ],
                    ),
                  ),
                ),
              ),

              // Right side actions (always visible)
              Positioned(
                right: 12,
                bottom: 90,
                child: Column(
                  children: [
                    _ReelActionButton(
                      icon: post.isLikedByMe
                          ? Icons.favorite
                          : Icons.favorite_border,
                      label: '${post.likeCount}',
                      onTap: widget.onLike,
                    ),
                    const SizedBox(height: 16),
                    _ReelActionButton(
                      icon: Icons.comment_outlined,
                      label: '${post.commentCount}',
                      onTap: widget.onComment,
                    ),
                    const SizedBox(height: 16),
                    _ReelActionButton(
                      icon: Icons.share_rounded,
                      label: 'Share',
                      onTap: widget.onShare,
                    ),
                    const SizedBox(height: 16),
                    _ReelActionButton(
                      icon: Icons.flag_outlined,
                      label: 'Report',
                      onTap: widget.onReport,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        widget.onToggleMute();
                        final c = controller;
                        if (c != null) {
                          final media = MediaPlaybackController.instance;
                          c.setVolume(
                            media.isMuted.value ? 0.0 : media.volume.value,
                          );
                        }
                      },
                      onLongPress: () => _showVolumePopup(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: ValueListenableBuilder<bool>(
                          valueListenable:
                              MediaPlaybackController.instance.isMuted,
                          builder: (_, isMuted, __) {
                            return Column(
                              children: [
                                Icon(
                                  isMuted
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isMuted ? 'Muted' : 'Sound',
                                  style: context.appText.bodySmall!.copyWith(color: Colors.white),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Play/Pause overlay (single tap shows UI; tap icon toggles)
              if (controller != null && _uiVisible)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: false,
                    child: Center(
                      child: ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (_, v, __) {
                          final show = !v.isPlaying;
                          if (!show) return const SizedBox.shrink();
                          return InkWell(
                            onTap: () {
                              if (v.isPlaying) {
                                controller.pause();
                              } else {
                                controller.play();
                                _scheduleUiAutoHide();
                              }
                              setState(() {
                                _uiVisible = true;
                                _captionVisible = true;
                              });
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 46,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

              // Caption/Text area (auto hides after 3-4 seconds)
              if (_captionVisible)
                Positioned(
                  left: 12,
                  right: 72,
                  bottom: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.visitorProfile,
                            arguments: {'userId': post.author.id},
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.white10,
                              backgroundImage:
                                  (post.author.avatarUrl ?? '').isNotEmpty
                                  ? NetworkImage(post.author.avatarUrl!)
                                  : null,
                              child: (post.author.avatarUrl ?? '').isNotEmpty
                                  ? null
                                  : const Icon(
                                      Icons.person,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                post.author.name,
                                style: context.appText.bodyLarge!.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      if ((post.caption ?? '').isNotEmpty)
                        Text(
                          post.caption!,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

              // Bottom progress line only (no player icons)
              if (controller != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: controller,
                      builder: (_, v, __) {
                        final durMs = v.duration.inMilliseconds;
                        final posMs = v.position.inMilliseconds;
                        final value = durMs <= 0
                            ? 0.0
                            : (posMs / durMs).clamp(0.0, 1.0).toDouble();
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 2,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Subtle buffering hint
              if (controller != null && controller.value.isBuffering)
                const Center(
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReelActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ReelActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 4),
            Text(
              label,
              style: context.appText.bodySmall!.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
