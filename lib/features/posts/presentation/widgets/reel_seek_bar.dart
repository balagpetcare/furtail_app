import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Bottom seek bar for the reels player.
///
/// Shows current position, a draggable slider, and duration.
class ReelSeekBar extends StatelessWidget {
  final VideoPlayerController controller;

  const ReelSeekBar({
    super.key,
    required this.controller,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (_, v, _) {
            final durMs = v.duration.inMilliseconds;
            final posMs = v.position.inMilliseconds;
            final sliderVal = durMs <= 0
                ? 0.0
                : (posMs / durMs).clamp(0.0, 1.0).toDouble();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Text(
                        _fmt(v.position),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _fmt(v.duration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12.0,
                    ),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    value: sliderVal,
                    min: 0.0,
                    max: 1.0,
                    onChanged: durMs > 0
                        ? (val) {
                            controller.seekTo(
                              Duration(
                                milliseconds: (val * durMs).round(),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
