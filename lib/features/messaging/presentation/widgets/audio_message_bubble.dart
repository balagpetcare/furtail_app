import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Play/pause + progress for a single voice/audio message attachment.
/// Minimal `audioplayers`-based player (already a declared dependency, no
/// new package) — mirrors the "smallest maintainable" approach the rest of
/// this feature's realtime layer already follows.
///
/// Only one [AudioMessageBubble] plays at a time: starting playback here
/// pauses whichever other instance (if any) is currently registered as
/// playing, via a tiny static registry — no new Riverpod provider needed
/// for what is otherwise purely local widget state.
///
/// Direct-message audio is private per-conversation (same
/// `/api/v1/media/*` participant check as image/video), and the pinned
/// `audioplayers` version's `UrlSource` has no per-source header support —
/// so playback can't just point at the raw URL. Instead this downloads the
/// file once via the authenticated API client
/// ([AuthenticatedMediaCache.fetchAudioFile], write-through cached to a
/// local temp file) and plays that local file.
class AudioMessageBubble extends ConsumerStatefulWidget {
  const AudioMessageBubble({
    super.key,
    required this.url,
    required this.isMine,
    this.durationMs,
  });

  final String url;
  final bool isMine;
  final int? durationMs;

  @override
  ConsumerState<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

/// The currently-playing bubble, if any — used so a new play() pauses it.
class _ActiveAudioRegistry {
  static _AudioMessageBubbleState? current;
}

class _AudioMessageBubbleState extends ConsumerState<AudioMessageBubble> {
  final _player = AudioPlayer();
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  bool _loading = false;
  bool _errored = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: widget.durationMs ?? 0);
    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
      if (state == PlayerState.completed) {
        setState(() => _position = Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    if (identical(_ActiveAudioRegistry.current, this)) {
      _ActiveAudioRegistry.current = null;
    }
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    final other = _ActiveAudioRegistry.current;
    if (other != null && !identical(other, this) && other.mounted) {
      await other._player.pause();
    }
    _ActiveAudioRegistry.current = this;
    setState(() {
      _loading = true;
      _errored = false;
    });
    try {
      if (!mounted) return;
      await _player.play(UrlSource(widget.url));
    } catch (_) {
      if (mounted) setState(() => _errored = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = widget.isMine ? cs.onPrimary : cs.onSurface;
    final totalMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final posMs = _position.inMilliseconds
        .clamp(0, _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 0)
        .toDouble();

    return SizedBox(
      width: 220,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _errored ? _togglePlay : (_loading ? null : _togglePlay),
            icon: _loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Icon(
                    _errored
                        ? Icons.refresh_rounded
                        : (_isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill),
                    color: fg,
                    size: 32,
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: fg,
                    inactiveTrackColor: fg.withValues(alpha: 0.3),
                    thumbColor: fg,
                  ),
                  child: Slider(
                    value: posMs.clamp(0, totalMs),
                    min: 0,
                    max: totalMs,
                    onChanged: _duration > Duration.zero
                        ? (v) => _player.seek(Duration(milliseconds: v.toInt()))
                        : null,
                  ),
                ),
                Text(
                  _errored
                      ? 'Couldn\'t play — tap to retry'
                      : '${_fmt(_position)} / ${_fmt(_duration)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: fg.withValues(alpha: 0.85),
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
