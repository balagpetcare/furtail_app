import 'dart:async';

import 'package:bpa_app/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class FullscreenVideoPlayerScreen extends StatefulWidget {
  final String url;
  final Duration startAt;
  final bool startMuted;
  final bool autoplay;

  const FullscreenVideoPlayerScreen({
    super.key,
    required this.url,
    this.startAt = Duration.zero,
    this.startMuted = false,
    this.autoplay = true,
  });

  @override
  State<FullscreenVideoPlayerScreen> createState() =>
      _FullscreenVideoPlayerScreenState();
}

class _FullscreenVideoPlayerScreenState extends State<FullscreenVideoPlayerScreen> {
  VideoPlayerController? _c;
  Future<void>? _init;
  bool _muted = false;
  bool _show = true;
  Timer? _hide;
  int _token = 0;
  bool _wakelockHeld = false;

  @override
  void initState() {
    super.initState();
    final int token = ++_token;
    _muted = widget.startMuted;
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;
    _init = c.initialize().then((_) async {
      if (!mounted || token != _token) return;
      if (widget.startAt > Duration.zero) {
        try {
          await c.seekTo(widget.startAt);
        } catch (_) {}
      }
      c.setLooping(true);
      try {
        c.setVolume(_muted ? 0.0 : 1.0);
      } catch (_) {}
      if (widget.autoplay) {
        try {
          await c.play();
        } catch (_) {}
        if (!_wakelockHeld) {
          _wakelockHeld = true;
          WakelockPlus.enable();
        }
      }
      if (!mounted || token != _token) return;
      setState(() {});
    }).catchError((e) {
      debugPrint('Fullscreen video init failed: $e');
    });
    _autoHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    final c = _c;
    _c = null;
    try {
      c?.pause();
    } catch (_) {}
    c?.dispose();
    if (_wakelockHeld) {
      _wakelockHeld = false;
      WakelockPlus.disable();
    }
    super.dispose();
  }

  void _autoHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _show = false);
    });
  }

  void _togglePlay() {
    final c = _c;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
      if (_wakelockHeld) {
        _wakelockHeld = false;
        WakelockPlus.disable();
      }
      setState(() => _show = true);
    } else {
      c.play();
      if (!_wakelockHeld) {
        _wakelockHeld = true;
        WakelockPlus.enable();
      }
      _autoHide();
    }
  }

  void _toggleMute() {
    final c = _c;
    if (c == null) return;
    setState(() => _muted = !_muted);
    c.setVolume(_muted ? 0.0 : 1.0);
    _autoHide();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _show = !_show);
            if (_show) _autoHide();
          },
          onDoubleTap: _togglePlay,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (c == null || _init == null)
                const Center(child: CircularProgressIndicator())
              else
                FutureBuilder<void>(
                  future: _init,
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Center(
                      child: AspectRatio(
                        aspectRatio: c.value.aspectRatio == 0
                            ? 16 / 9
                            : c.value.aspectRatio,
                        child: VideoPlayer(c),
                      ),
                    );
                  },
                ),

              if (_show && c != null)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: c,
                    builder: (_, v, __) {
                      final dur = v.duration;
                      final pos = v.position;
                      final maxMs = dur.inMilliseconds > 0
                          ? dur.inMilliseconds.toDouble()
                          : 1.0;
                      final curMs = pos.inMilliseconds
                          .clamp(0, dur.inMilliseconds)
                          .toDouble();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _togglePlay,
                              icon: Icon(
                                v.isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            Text(_fmt(pos),
                                style: context.appText.bodySmall!.copyWith(color: Colors.white)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Slider(
                                value: curMs,
                                min: 0,
                                max: maxMs,
                                onChanged: (val) {
                                  c.seekTo(
                                      Duration(milliseconds: val.toInt()));
                                },
                              ),
                            ),
                            Text(_fmt(dur),
                                style: context.appText.bodySmall!.copyWith(color: Colors.white)),
                            IconButton(
                              onPressed: _toggleMute,
                              icon: Icon(
                                _muted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.fullscreen_exit_rounded,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              if (_show)
                Positioned(
                  top: 6,
                  left: 6,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
