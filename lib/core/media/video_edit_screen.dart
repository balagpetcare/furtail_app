import 'package:furtail_app/core/theme/typography.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoEditResult {
  final File file;
  final int? trimStartMs;
  final int? trimEndMs;
  final bool mute;
  final double volume;

  const VideoEditResult({
    required this.file,
    required this.trimStartMs,
    required this.trimEndMs,
    required this.mute,
    required this.volume,
  });
}

/// Lightweight, premium UX video editor for upload-time:
/// - preview
/// - trim start/end (server-side processing)
/// - mute / volume gain (server-side)
class VideoEditScreen extends StatefulWidget {
  final File file;

  const VideoEditScreen({super.key, required this.file});

  @override
  State<VideoEditScreen> createState() => _VideoEditScreenState();
}

class _VideoEditScreenState extends State<VideoEditScreen> {
  VideoPlayerController? _c;
  Future<void>? _init;
  int _token = 0;

  double _start = 0.0;
  double _end = 0;
  bool _mute = false;
  double _volume = 1.0; // 1.0 normal, >1 amplifies

  @override
  void initState() {
    super.initState();
    final int token = ++_token;
    final c = VideoPlayerController.file(widget.file);
    _c = c;
    _init = c.initialize().then((_) {
      if (!mounted || token != _token) return;
      final durMs = c.value.duration.inMilliseconds.toDouble();
      _start = 0.0;
      _end = durMs;
      c.setLooping(true);
      c.play();
      if (mounted) setState(() {});
    }).catchError((e) {
      debugPrint('Video edit init failed: $e');
    });
  }

  @override
  void dispose() {
    final c = _c;
    _c = null;
    try {
      c?.pause();
    } catch (_) {}
    c?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _c;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  void _applyPreviewVolume() {
    final c = _c;
    if (c == null) return;
    try {
      c.setVolume(_mute ? 0.0 : _volume.clamp(0.0, 2.0).toDouble());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Edit Video'),
        actions: [
          TextButton(
            onPressed: () {
              final startMs = _start.round();
              final endMs = _end.round();
              final result = VideoEditResult(
                file: widget.file,
                trimStartMs: startMs <= 0 ? null : startMs,
                trimEndMs: endMs <= 0 ? null : endMs,
                mute: _mute,
                volume: _volume,
              );
              Navigator.pop(context, result);
            },
            child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          )
        ],
      ),
      body: c == null || _init == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<void>(
              future: _init,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final dur = c.value.duration;
                final durMs = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity).toDouble();
                final playing = c.value.isPlaying;
                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                          child: GestureDetector(
                            onTap: _togglePlay,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                VideoPlayer(c),
                                if (!playing)
                                  const Center(
                                    child: Icon(Icons.play_circle_fill, color: Colors.white, size: 72),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Trim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          RangeSlider(
                            values: RangeValues(_start.clamp(0.0, durMs).toDouble(), _end.clamp(0.0, durMs).toDouble()),
                            min: 0.0,
                            max: durMs,
                            onChanged: (r) {
                              setState(() {
                                _start = r.start;
                                _end = r.end;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Checkbox(
                                value: _mute,
                                onChanged: (v) {
                                  setState(() => _mute = v ?? false);
                                  _applyPreviewVolume();
                                },
                              ),
                              const Text('Mute', style: TextStyle(color: Colors.white)),
                              const Spacer(),
                              IconButton(
                                onPressed: () {
                                  setState(() => _volume = 1.0);
                                  _applyPreviewVolume();
                                },
                                icon: const Icon(Icons.refresh, color: Colors.white),
                              )
                            ],
                          ),
                          const Text('Volume', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          Slider(
                            value: _volume.clamp(0.0, 2.0).toDouble(),
                            min: 0.0,
                            max: 2.0,
                            onChanged: (v) {
                              setState(() => _volume = v);
                              _applyPreviewVolume();
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Note: Trim/Volume will be processed during upload (server-side compression pipeline).',
                            style: context.appText.bodySmall!.copyWith(color: Colors.white70, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
