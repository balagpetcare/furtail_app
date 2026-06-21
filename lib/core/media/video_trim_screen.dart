import 'dart:io';

import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Lightweight video preview screen.
///
/// Real trimming usually relies on FFmpeg native libraries which can greatly increase
/// the APK size. To keep the app lightweight, this screen only previews the selected
/// video and returns the original file when the user taps Done.
class VideoTrimScreen extends StatefulWidget {
  final File file;
  const VideoTrimScreen({super.key, required this.file});

  @override
  State<VideoTrimScreen> createState() => _VideoTrimScreenState();
}

class _VideoTrimScreenState extends State<VideoTrimScreen> {
  late final VideoPlayerController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    Navigator.pop<File?>(context, widget.file);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Preview'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _done,
            child: Text(
              'Done',
              style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _controller.value.isPlaying
                                ? _controller.pause()
                                : _controller.play();
                          });
                        },
                        icon: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Lite build: trimming disabled to keep the app small.',
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
