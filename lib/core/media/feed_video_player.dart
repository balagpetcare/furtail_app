import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'fullscreen_video_player_screen.dart';
import 'media_playback_controller.dart';
import 'furtail_cache_manager.dart';

/// Premium feed video player:
/// - Auto play when >=70% visible
/// - Pause when offscreen
/// - Scrubbable progress bar
/// - Mute toggle
/// - Fullscreen
class FeedVideoPlayer extends StatefulWidget {
  final String url;
  final String visibilityKey;
  final bool startMuted;
  final bool syncMuteWithGlobal;
  final bool enableAutoplay;
  final double aspectRatio;
  final BoxFit fit;
  final VoidCallback? onFullscreenPressed;

  /// When true: hides all controls; tap navigates to the detail screen instead
  /// of toggling play/pause. Designed for in-feed card usage.
  final bool feedMode;

  /// When true: shows a persistent volume button at top-right (always visible,
  /// not part of the transient controls overlay). Intended for the single-media
  /// detail viewer where mute must remain accessible without showing controls.
  final bool isDetailViewer;

  const FeedVideoPlayer({
    super.key,
    required this.url,
    required this.visibilityKey,
    this.startMuted = false,
    this.syncMuteWithGlobal = true,
    this.enableAutoplay = true,
    this.aspectRatio = 16 / 9,
    this.fit = BoxFit.cover,
    this.onFullscreenPressed,
    this.feedMode = false,
    this.isDetailViewer = false,
  });

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> {
  final _media = MediaPlaybackController.instance;
  VideoPlayerController? _c;
  Future<void>? _init;
  bool _muted = false;
  late final VoidCallback _onMuteChanged;
  late final VoidCallback _onVolChanged;
  bool _controlsVisible = false;
  Timer? _hideTimer;
  Timer? _autoHideTimer;
  Timer? _visDebounce;
  int _setupToken = 0;
  bool _wakelockHeld = false;
  String? _activeFilePath;
  bool _isScrubbing = false;
  double _lastVisibilityFraction = 0.0;

  Future<bool> _shouldAutoplay() async {
    if (!widget.enableAutoplay) return false;
    if (_media.playOneByOneWifiOnly.value) {
      try {
        final connectivityList = await Connectivity().checkConnectivity();
        if (connectivityList.contains(ConnectivityResult.mobile)) {
          return false;
        }
      } catch (_) {}
    }
    return true;
  }

  void _applyVolume() {
    final c = _c;
    if (c == null) return;
    final v = (_muted ? 0.0 : _media.volume.value).clamp(0.0, 1.0).toDouble();
    c.setVolume(v);
  }

  @override
  void initState() {
    super.initState();
    _media.ensureInitialized();
    _muted =
        widget.startMuted ||
        (widget.syncMuteWithGlobal && _media.isMuted.value);

    _onMuteChanged = () {
      if (!widget.syncMuteWithGlobal) return;
      final c = _c;
      if (c == null) return;
      if (!mounted) return;
      setState(() => _muted = _media.isMuted.value);
      _applyVolume();
    };
    _onVolChanged = () {
      if (!mounted) return;
      _applyVolume();
    };

    if (widget.syncMuteWithGlobal) {
      _media.isMuted.addListener(_onMuteChanged);
    }
    _media.volume.addListener(_onVolChanged);
    // Lazy init: don't create/initialize video controller until the item becomes visible.
  }

  @override
  void dispose() {
    if (widget.syncMuteWithGlobal) {
      _media.isMuted.removeListener(_onMuteChanged);
    }
    _media.volume.removeListener(_onVolChanged);
    _hideTimer?.cancel();
    _autoHideTimer?.cancel();
    _visDebounce?.cancel();
    _disposeController();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FeedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final urlChanged = oldWidget.url != widget.url;
    final autoplayChanged = oldWidget.enableAutoplay != widget.enableAutoplay;
    final mutedChanged =
        oldWidget.startMuted != widget.startMuted ||
        oldWidget.syncMuteWithGlobal != widget.syncMuteWithGlobal;
    if (!urlChanged && !autoplayChanged && !mutedChanged) return;

    final resumePosition = _c?.value.position ?? Duration.zero;
    final resumePlaying = _c?.value.isPlaying ?? false;
    final isVisible = _lastVisibilityFraction >= 0.70;

    _disposeController();
    _muted =
        widget.startMuted ||
        (widget.syncMuteWithGlobal && _media.isMuted.value);

    if (isVisible) {
      _setup(resumePosition: resumePosition, resumePlaying: resumePlaying);
    } else if (mounted) {
      setState(() {});
    }
  }

  void _disposeController() {
    final c = _c;
    _c = null;
    _init = null;
    if (_activeFilePath != null) {
      VideoCacheService.instance.unregisterActivePath(_activeFilePath!);
      _activeFilePath = null;
    }
    try {
      c?.pause();
    } catch (_) {}
    c?.dispose();
    if (_wakelockHeld) {
      _wakelockHeld = false;
      WakelockPlus.disable();
    }
  }

  void _setup({
    Duration resumePosition = Duration.zero,
    bool resumePlaying = false,
  }) {
    final int token = ++_setupToken;
    _init = Future(() async {
      VideoPlayerController? controller;
      try {
        final file = await VideoCacheService.instance.getVideoFile(widget.url);
        if (!mounted || token != _setupToken) return;

        if (_activeFilePath != null && _activeFilePath != file.path) {
          VideoCacheService.instance.unregisterActivePath(_activeFilePath!);
        }
        _activeFilePath = file.path;
        VideoCacheService.instance.registerActivePath(_activeFilePath!);

        controller = VideoPlayerController.file(file);
        _c = controller;
        await controller.initialize();
      } catch (e) {
        debugPrint(
          '[FeedPlayer] Cache load failed, unlinking key and falling back to network: $e',
        );
        if (_activeFilePath != null) {
          VideoCacheService.instance.unregisterActivePath(_activeFilePath!);
          _activeFilePath = null;
        }
        try {
          await VideoCacheService.instance.removeFile(widget.url);
        } catch (_) {}

        if (!mounted || token != _setupToken) return;

        controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
        _c = controller;
        await controller.initialize();
      }

      if (!mounted || token != _setupToken) {
        controller.dispose();
        return;
      }

      controller.setLooping(true);
      controller.setVolume(
        (_muted ? 0.0 : _media.volume.value).clamp(0.0, 1.0).toDouble(),
      );

      if (resumePosition > Duration.zero) {
        try {
          await controller.seekTo(resumePosition);
        } catch (_) {}
      }

      final allowed = await _shouldAutoplay();
      if ((allowed && widget.enableAutoplay) || resumePlaying) {
        try {
          await controller.play();
        } catch (_) {}
      }

      if (mounted) setState(() {});
    });

    if (mounted) {
      setState(() {});
    }
  }

  void _showControls({Duration autoHideAfter = const Duration(seconds: 3)}) {
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _restartAutoHide(autoHideAfter: autoHideAfter);
  }

  void _toggleControls() {
    if (!mounted) return;
    final next = !_controlsVisible;
    setState(() => _controlsVisible = next);
    _hideTimer?.cancel();
    final c = _c;
    if (next && c != null && c.value.isPlaying) {
      _restartAutoHide();
    }
  }

  void _restartAutoHide({Duration autoHideAfter = const Duration(seconds: 3)}) {
    _hideTimer?.cancel();
    final c = _c;
    if (c == null || !c.value.isPlaying || _isScrubbing) return;
    _hideTimer = Timer(autoHideAfter, () {
      if (!mounted) return;
      final active = _c;
      if (active == null || !active.value.isPlaying || _isScrubbing) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _handleControlInteraction() {
    if (!mounted) return;
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _restartAutoHide();
  }

  void _togglePlayPause() {
    final c = _c;
    if (c == null) {
      _setup();
      _showControls();
      return;
    }
    if (c.value.isPlaying) {
      c.pause();
      if (_wakelockHeld) {
        _wakelockHeld = false;
        WakelockPlus.disable();
      }
    } else {
      c.play();
      if (!_wakelockHeld) {
        _wakelockHeld = true;
        WakelockPlus.enable();
      }
    }
    _showControls(
      autoHideAfter: c.value.isPlaying
          ? const Duration(seconds: 3)
          : const Duration(days: 1),
    );
  }

  void _toggleMute() {
    final c = _c;
    if (c == null) return;
    if (widget.syncMuteWithGlobal) {
      _media.toggleMute();
      if (mounted) setState(() => _muted = _media.isMuted.value);
    } else {
      if (mounted) setState(() => _muted = !_muted);
    }
    _applyVolume();
    _handleControlInteraction();
  }

  void _seekRelative(Duration delta) {
    final c = _c;
    if (c == null) return;
    final duration = c.value.duration;
    final target = c.value.position + delta;
    final bounded = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);
    c.seekTo(bounded);
    _handleControlInteraction();
  }

  Future<void> _openFullscreen() async {
    final c = _c;
    if (c == null) return;
    final pos = c.value.position;
    final wasPlaying = c.value.isPlaying;
    c.pause();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenVideoPlayerScreen(
          url: widget.url,
          startAt: pos,
          startMuted: _muted,
          autoplay: wasPlaying,
        ),
      ),
    );
    // Keep feed player in sync after return
    if (!mounted) return;
    if (pos > Duration.zero) {
      await c.seekTo(pos);
    }
    _applyVolume();
    if (wasPlaying) c.play();
  }

  void _handleVisibility(double fraction) {
    if (!widget.enableAutoplay) return;
    _lastVisibilityFraction = fraction;

    // Debounce rapid visibility updates (prevents churn and rare race conditions).
    _visDebounce?.cancel();
    _visDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;

      // Create controller only when it becomes meaningfully visible.
      if (fraction >= 0.70) {
        if (_c == null) {
          _setup();
          return;
        }
        final c = _c;
        if (c == null) return;
        if (!c.value.isPlaying) {
          _shouldAutoplay().then((allowed) {
            if (allowed && mounted && !c.value.isPlaying) {
              try {
                c.play();
              } catch (_) {}
              if (!_wakelockHeld) {
                _wakelockHeld = true;
                WakelockPlus.enable();
              }
            }
          });
        }
      } else {
        final c = _c;
        if (c != null && c.value.isPlaying) {
          try {
            c.pause();
          } catch (_) {}
        }
        if (_wakelockHeld) {
          _wakelockHeld = false;
          WakelockPlus.disable();
        }

        // Aggressively free memory when the widget is mostly offscreen.
        if (fraction <= 0.05) {
          _disposeController();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final effectiveAspectRatio =
        c != null && c.value.isInitialized && c.value.aspectRatio > 0
        ? c.value.aspectRatio
        : widget.aspectRatio;

    return VisibilityDetector(
      key: Key('feed-video-${widget.visibilityKey}'),
      onVisibilityChanged: (info) => _handleVisibility(info.visibleFraction),
      child: AspectRatio(
        aspectRatio: effectiveAspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black12),
              if (_c == null || _init == null)
                const Center(
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.black87,
                        size: 42,
                      ),
                    ),
                  ),
                )
              else
                FutureBuilder<void>(
                  future: _init,
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final c = _c!;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        FittedBox(
                          fit: widget.fit,
                          child: SizedBox(
                            width: c.value.size.width,
                            height: c.value.size.height,
                            child: VideoPlayer(c),
                          ),
                        ),
                        if (c.value.isBuffering)
                          const Center(
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    );
                  },
                ),

              // Tap layer
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.feedMode
                      ? (widget.onFullscreenPressed ?? _openFullscreen)
                      // When controller not yet initialized, first tap starts setup+playback.
                      // Once initialized, tap toggles controls overlay.
                      : (_c == null ? _togglePlayPause : _toggleControls),
                  onDoubleTap: widget.onFullscreenPressed ?? _openFullscreen,
                ),
              ),

              // Controls — hidden in feed mode
              if (!widget.feedMode && _c != null)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _controlsVisible ? 1 : 0,
                      child: _FeedControls(
                        controller: _c!,
                        muted: _muted,
                        onToggleMute: _toggleMute,
                        onFullscreen:
                            widget.onFullscreenPressed ?? _openFullscreen,
                        onSeekBack: () =>
                            _seekRelative(const Duration(seconds: -10)),
                        onSeekForward: () =>
                            _seekRelative(const Duration(seconds: 10)),
                        onInteraction: _handleControlInteraction,
                        onScrubStart: () {
                          _isScrubbing = true;
                          _handleControlInteraction();
                        },
                        onScrubEnd: () {
                          _isScrubbing = false;
                          _handleControlInteraction();
                        },
                        // In detail mode the volume button lives in its own
                        // persistent layer below, so hide it from the overlay.
                        showVolume: !widget.isDetailViewer,
                      ),
                    ),
                  ),
                ),

              // Persistent mute toggle — detail viewer only.
              // Lives outside the transient controls overlay so it stays
              // visible and tappable at all times.
              if (widget.isDetailViewer && !widget.feedMode && _c != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _ControlBubble(
                    diameter: 40,
                    onTap: _toggleMute,
                    child: Icon(
                      _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),

              // Play icon overlay
              if (widget.feedMode)
                // Feed mode: static non-tappable play icon, disappears when playing
                IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: (_c == null || !_c!.value.isPlaying) ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 64,
                        shadows: [
                          Shadow(blurRadius: 10, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_c != null)
                // Full player mode: tappable play/pause toggle
                Center(
                  child: AnimatedOpacity(
                    opacity: _controlsVisible || !(_c!.value.isPlaying) ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: _ControlBubble(
                      diameter: 72,
                      backgroundColor: Colors.white,
                      onTap: _togglePlayPause,
                      child: Icon(
                        _c!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black87,
                        size: 42,
                      ),
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

class _FeedControls extends StatelessWidget {
  final VideoPlayerController controller;
  final bool muted;
  final VoidCallback onToggleMute;
  final VoidCallback onFullscreen;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback onInteraction;
  final VoidCallback onScrubStart;
  final VoidCallback onScrubEnd;
  // When false the volume button is omitted (caller renders it as a persistent
  // always-visible overlay instead of inside this transient controls layer).
  final bool showVolume;

  const _FeedControls({
    required this.controller,
    required this.muted,
    required this.onToggleMute,
    required this.onFullscreen,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onInteraction,
    required this.onScrubStart,
    required this.onScrubEnd,
    this.showVolume = true,
  });

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (_, v, _) {
        final dur = v.duration;
        final pos = v.position;
        final maxMs = dur.inMilliseconds > 0
            ? dur.inMilliseconds.toDouble()
            : 1.0;
        final curMs = pos.inMilliseconds
            .clamp(0, dur.inMilliseconds)
            .toDouble();

        return Stack(
          children: [
            if (showVolume)
              Positioned(
                top: 12,
                right: 12,
                child: _ControlBubble(
                  onTap: () {
                    onToggleMute();
                    onInteraction();
                  },
                  child: Icon(
                    muted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            // Seek buttons flank the standalone play/pause button (rendered in
            // the parent Stack above this overlay). The 96-wide gap keeps the
            // seek buttons visually clear of the 72-diameter play button.
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ControlBubble(
                    onTap: onSeekBack,
                    child: const Icon(
                      Icons.replay_10,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 96),
                  _ControlBubble(
                    onTap: onSeekForward,
                    child: const Icon(
                      Icons.forward_10,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _fmt(pos),
                          style: context.appText.bodySmall!.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _fmt(dur),
                          style: context.appText.bodySmall!.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () {
                            onFullscreen();
                            onInteraction();
                          },
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                      ),
                      child: Slider(
                        value: curMs,
                        min: 0.0,
                        max: maxMs,
                        onChangeStart: (_) => onScrubStart(),
                        onChanged: (val) {
                          onInteraction();
                          controller.seekTo(
                            Duration(milliseconds: val.toInt()),
                          );
                        },
                        onChangeEnd: (_) => onScrubEnd(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ControlBubble extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double diameter;
  final Color? backgroundColor;

  const _ControlBubble({
    required this.child,
    required this.onTap,
    this.diameter = 56,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.black.withValues(alpha: 0.42),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
