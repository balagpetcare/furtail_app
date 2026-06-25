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
  final bool enableAutoplay;
  final double aspectRatio;
  final BoxFit fit;
  final VoidCallback? onFullscreenPressed;

  const FeedVideoPlayer({
    super.key,
    required this.url,
    required this.visibilityKey,
    this.startMuted = false,
    this.enableAutoplay = true,
    this.aspectRatio = 16 / 9,
    this.fit = BoxFit.cover,
    this.onFullscreenPressed,
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
    _muted = widget.startMuted || _media.isMuted.value;

    _onMuteChanged = () {
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

    _media.isMuted.addListener(_onMuteChanged);
    _media.volume.addListener(_onVolChanged);
    // Lazy init: don't create/initialize video controller until the item becomes visible.
  }

  @override
  void dispose() {
    _media.isMuted.removeListener(_onMuteChanged);
    _media.volume.removeListener(_onVolChanged);
    _hideTimer?.cancel();
    _autoHideTimer?.cancel();
    _visDebounce?.cancel();
    _disposeController();
    super.dispose();
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

  void _setup() {
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
        debugPrint('[FeedPlayer] Cache load failed, unlinking key and falling back to network: $e');
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

      if (!mounted || token != _setupToken || controller == null) {
        controller?.dispose();
        return;
      }

      controller.setLooping(true);
      controller.setVolume((_muted ? 0.0 : _media.volume.value).clamp(0.0, 1.0).toDouble());

      final allowed = await _shouldAutoplay();
      if (allowed && widget.enableAutoplay) {
        try {
          await controller.play();
        } catch (_) {}
      }

      if (mounted) setState(() {});
    });
  }

  void _showControls({Duration autoHideAfter = const Duration(seconds: 3)}) {
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(autoHideAfter, () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    if (!mounted) return;
    final next = !_controlsVisible;
    setState(() => _controlsVisible = next);
    _hideTimer?.cancel();
    if (next) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _controlsVisible = false);
      });
    }
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
    _showControls();
  }

  void _toggleMute() {
    final c = _c;
    if (c == null) return;
    _media.toggleMute();
    if (mounted) setState(() => _muted = _media.isMuted.value);
    _applyVolume();
    _showControls();
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
    return VisibilityDetector(
      key: Key('feed-video-${widget.visibilityKey}'),
      onVisibilityChanged: (info) => _handleVisibility(info.visibleFraction),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black12),
              if (_c == null || _init == null)
                const Center(
                  child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 52),
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
                  onTap: _toggleControls,
                  onDoubleTap: widget.onFullscreenPressed ?? _openFullscreen,
                ),
              ),

              // Controls
              if (_c != null)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _controlsVisible ? 1 : 0,
                    child: _FeedControls(
                      controller: _c!,
                      muted: _muted,
                      onToggleMute: _toggleMute,
                      onFullscreen: widget.onFullscreenPressed ?? _openFullscreen,
                    ),
                  ),
                ),

              // Big play icon when paused
              if (_c != null)
                Center(
                  child: AnimatedOpacity(
                    opacity: _controlsVisible || !(_c!.value.isPlaying) ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: Icon(
                        _c!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        color: Colors.white,
                        size: 64,
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

  const _FeedControls({
    required this.controller,
    required this.muted,
    required this.onToggleMute,
    required this.onFullscreen,
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
        final maxMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
        final curMs = pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Text(_fmt(pos), style: context.appText.bodySmall!.copyWith(color: Colors.white)),
              const SizedBox(width: 10),
              Expanded(
                child: Slider(
                  value: curMs,
                  min: 0.0,
                  max: maxMs,
                  onChanged: (val) {
                    controller.seekTo(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
              const SizedBox(width: 6),
              Text(_fmt(dur), style: context.appText.bodySmall!.copyWith(color: Colors.white)),
              IconButton(
                onPressed: onToggleMute,
                icon: Icon(
                  muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              IconButton(
                onPressed: onFullscreen,
                icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
        );
      },
    );
  }
}

