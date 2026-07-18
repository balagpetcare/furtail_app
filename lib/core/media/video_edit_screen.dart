import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';

// ── Result model ───────────────────────────────────────────────────────────

class VideoEditResult {
  final File file;

  // Trim
  final int? trimStartMs;
  final int? trimEndMs;

  // Audio
  final bool mute;
  final double volume;

  /// Selected aspect ratio preset: "original", "1:1", "4:5", "9:16", "16:9".
  /// Stored as metadata only — actual crop is a future feature.
  final String? aspectRatio;

  /// Quality preset: "auto", "dataSaver", "hd".
  /// Stored locally for now; backend integration is a future feature.
  final String? quality;

  /// Timestamp (ms) from which the cover thumbnail was extracted.
  final int? coverTimestampMs;

  const VideoEditResult({
    required this.file,
    required this.trimStartMs,
    required this.trimEndMs,
    required this.mute,
    required this.volume,
    this.aspectRatio,
    this.quality,
    this.coverTimestampMs,
  });
}

// ── Aspect ratio presets ──────────────────────────────────────────────────

class _AspectRatioOption {
  final String id;
  final String label;
  final double? ratio; // null = original (keep source)
  const _AspectRatioOption(this.id, this.label, this.ratio);
}

const _kAspectRatios = [
  _AspectRatioOption('original', 'Original', null),
  _AspectRatioOption('1:1', '1:1', 1.0),
  _AspectRatioOption('4:5', '4:5', 0.8),
  _AspectRatioOption('9:16', '9:16', 9 / 16),
  _AspectRatioOption('16:9', '16:9', 16 / 9),
];

// ── Quality presets ──────────────────────────────────────────────────────

class _QualityOption {
  final String id;
  final String label;
  final String description;
  const _QualityOption(this.id, this.label, this.description);
}

const _kQualities = [
  _QualityOption('auto', 'Auto', 'Balanced quality & size'),
  _QualityOption('dataSaver', 'Data Saver', 'Smaller file size'),
  _QualityOption('hd', 'HD', 'Best quality'),
];

// ── Helpers ──────────────────────────────────────────────────────────────

String _formatMs(int ms) {
  final totalSeconds = ms ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

const _minTrimDurationMs = 1000; // 1 second minimum

// ── Screen ────────────────────────────────────────────────────────────────

/// Full-featured video editor for upload-time:
/// - preview + play/pause
/// - trim start/end with time labels and duration
/// - mute / volume control
/// - cover thumbnail selection
/// - aspect ratio preset (metadata only)
/// - quality preset (local only)
///
/// All processing is server-side. This screen only stores edit metadata.
class VideoEditScreen extends StatefulWidget {
  final File file;

  const VideoEditScreen({super.key, required this.file});

  @override
  State<VideoEditScreen> createState() => _VideoEditScreenState();
}

class _VideoEditScreenState extends State<VideoEditScreen> {
  // ── Controller lifecycle ──────────────────────────────────────────────
  VideoPlayerController? _c;
  Future<void>? _initFuture;
  int _token = 0;

  // ── Edit state ────────────────────────────────────────────────────────
  double _startMs = 0.0;
  double _endMs = 0;
  double _totalMs = 1.0;
  bool _mute = false;
  double _volume = 1.0;

  String _aspectRatio = 'original';
  String _quality = 'auto';

  // Cover selection
  bool _isGeneratingCover = false;
  int? _coverTimestampMs;
  File? _coverThumbnail;
  bool _showCoverPicker = false;

  // Video seek position for cover preview
  double _seekSliderMs = 0.0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    final int token = ++_token;
    final c = VideoPlayerController.file(widget.file);
    _c = c;
    _initFuture = c.initialize().then((_) {
      if (!mounted || token != _token) return;
      final durMs = c.value.duration.inMilliseconds.toDouble();
      _totalMs = durMs.clamp(1.0, double.infinity);
      _startMs = 0.0;
      _endMs = _totalMs;
      _seekSliderMs = _totalMs / 2; // middle as initial cover candidate
      c.setLooping(true);
      c.play();
      if (mounted) setState(() {});
    }).catchError((e) {
      debugPrint('[VideoEdit] init failed: $e');
    });
  }

  @override
  void dispose() {
    final c = _c;
    _c = null;
    try { c?.pause(); } catch (_) {}
    c?.dispose();
    super.dispose();
  }

  // ── Playback helpers ─────────────────────────────────────────────────

  void _togglePlay() {
    final c = _c;
    if (c == null) return;
    if (c.value.isPlaying) { c.pause(); } else { c.play(); }
    setState(() {});
  }

  void _applyPreviewVolume() {
    final c = _c;
    if (c == null) return;
    try { c.setVolume(_mute ? 0.0 : _volume.clamp(0.0, 2.0)); } catch (_) {}
  }

  void _seekToMs(double ms) {
    _c?.seekTo(Duration(milliseconds: ms.round()));
  }

  // ── Cover selection ──────────────────────────────────────────────────

  Future<void> _pickCoverAtCurrentPosition() async {
    if (_isGeneratingCover) return;
    setState(() => _isGeneratingCover = true);
    try {
      final ms = _seekSliderMs.round();
      final thumb = await VideoCompress.getFileThumbnail(
        widget.file.path,
        quality: 60,
        position: ms,
      );
      if (!mounted) return;
      setState(() {
        _coverTimestampMs = ms;
        _coverThumbnail = thumb;
        _isGeneratingCover = false;
      });
    } catch (e) {
      debugPrint('[VideoEdit] Cover generation error: $e');
      if (!mounted) return;
      setState(() => _isGeneratingCover = false);
    }
  }

  void _clearCover() {
    setState(() {
      _coverTimestampMs = null;
      _coverThumbnail = null;
    });
  }

  // ── Done ──────────────────────────────────────────────────────────────

  void _onDone() {
    final startMs = _startMs.round();
    final endMs = _endMs.round();
    final result = VideoEditResult(
      file: widget.file,
      trimStartMs: startMs <= 0 ? null : startMs,
      trimEndMs: endMs <= 0 ? null : endMs,
      mute: _mute,
      volume: _volume,
      aspectRatio: _aspectRatio,
      quality: _quality,
      coverTimestampMs: _coverTimestampMs,
    );
    Navigator.pop(context, result);
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Video'),
        actions: [
          TextButton(
            onPressed: _initFuture == null ? null : _onDone,
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: c == null || _initFuture == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : FutureBuilder<void>(
              future: _initFuture,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final playing = c.value.isPlaying;
                final dur = c.value.duration;
                final durMs = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);

                return Column(
                  children: [
                    // ── Video preview ─────────────────────────────────
                    Expanded(
                      child: GestureDetector(
                        onTap: _togglePlay,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: c.value.aspectRatio == 0
                                ? 16 / 9
                                : c.value.aspectRatio,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                VideoPlayer(c),
                                if (!playing)
                                  const Center(
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      color: Colors.white,
                                      size: 72,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Bottom controls panel ─────────────────────────
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Section: Trim ─────────────────────────
                            _buildTrimSection(durMs),

                            const SizedBox(height: 4),
                            const Divider(color: Colors.white12, height: 20),

                            // ── Section: Cover ────────────────────────
                            _buildCoverSection(),

                            const SizedBox(height: 4),
                            const Divider(color: Colors.white12, height: 20),

                            // ── Section: Aspect Ratio ──────────────────
                            _buildAspectRatioSection(),

                            const SizedBox(height: 4),
                            const Divider(color: Colors.white12, height: 20),

                            // ── Section: Quality ──────────────────────
                            _buildQualitySection(),

                            const SizedBox(height: 4),
                            const Divider(color: Colors.white12, height: 20),

                            // ── Section: Audio ────────────────────────
                            _buildAudioSection(),

                            const SizedBox(height: 12),

                            // ── Footer note ────────────────────────────
                            Text(
                              'Trim, mute, volume, aspect ratio, and quality '
                              'may be processed during upload.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ── Trim section ────────────────────────────────────────────────────────

  Widget _buildTrimSection(double durMs) {
    final currentStart = _startMs.clamp(0.0, durMs);
    final currentEnd = _endMs.clamp(0.0, durMs);
    final durationMs = (currentEnd - currentStart).clamp(0.0, durMs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.content_cut_rounded, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            const Text(
              'Trim',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            _TimeChip(label: _formatMs(currentStart.round())),
            const Text(' — ', style: TextStyle(color: Colors.white38, fontSize: 12)),
            _TimeChip(label: _formatMs(currentEnd.round())),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatMs(durationMs.round()),
                style: const TextStyle(
                  color: Color(0xFF66BB6A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RangeSlider(
          values: RangeValues(currentStart, currentEnd),
          min: 0.0,
          max: durMs,
          divisions: durMs > 100 ? (durMs ~/ 100).toInt() : null,
          labels: RangeLabels(
            _formatMs(currentStart.round()),
            _formatMs(currentEnd.round()),
          ),
          activeColor: Colors.white,
          inactiveColor: Colors.white24,
          overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.15)),
          onChanged: (r) {
            // Enforce minimum 1-second duration
            final minEnd = r.start + _minTrimDurationMs;
            final maxStart = r.end - _minTrimDurationMs;
            setState(() {
              _startMs = r.start.clamp(0.0, maxStart);
              _endMs = r.end.clamp(minEnd, durMs);
            });
          },
        ),
      ],
    );
  }

  // ── Cover section ────────────────────────────────────────────────────────

  Widget _buildCoverSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _showCoverPicker = !_showCoverPicker),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.image_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Cover Thumbnail',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  _coverTimestampMs != null
                      ? _formatMs(_coverTimestampMs!)
                      : 'Auto',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showCoverPicker ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white38,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (_showCoverPicker) ...[
          const SizedBox(height: 8),
          // Current cover preview
          if (_coverThumbnail != null)
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black,
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _coverThumbnail!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                  // Clear cover button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _clearCover,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                  // Timestamp badge
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatMs(_coverTimestampMs ?? 0),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white12),
              ),
              child: const Center(
                child: Text(
                  'No custom cover selected — will use auto-generated thumbnail',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          const SizedBox(height: 10),

          // Seek slider to pick cover frame
          Row(
            children: [
              Text(
                _formatMs(_seekSliderMs.round()),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: _seekSliderMs.clamp(0.0, _totalMs),
                  min: 0.0,
                  max: _totalMs,
                  activeColor: Colors.amber,
                  inactiveColor: Colors.white24,
                  onChanged: (v) {
                    setState(() => _seekSliderMs = v);
                    _seekToMs(v);
                  },
                ),
              ),
              Text(
                _formatMs(_totalMs.round()),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),

          // Capture cover button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isGeneratingCover ? null : _pickCoverAtCurrentPosition,
              icon: _isGeneratingCover
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt_outlined, size: 16),
              label: Text(
                _isGeneratingCover
                    ? 'Extracting…'
                    : _coverThumbnail != null
                        ? 'Update Cover'
                        : 'Set Cover from Current Frame',
                style: const TextStyle(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          // TODO: Once the server supports receiving a custom cover frame,
          // upload the selected frame via media/upload and pass the mediaId
          // as part of the createPost payload.
        ],
      ],
    );
  }

  // ── Aspect Ratio section ─────────────────────────────────────────────────

  Widget _buildAspectRatioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.aspect_ratio_rounded, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            const Text(
              'Aspect Ratio',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Metadata only',
                style: TextStyle(color: Colors.amber, fontSize: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kAspectRatios.map((opt) {
            final selected = _aspectRatio == opt.id;
            return GestureDetector(
              onTap: () => setState(() => _aspectRatio = opt.id),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white12,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildRatioIcon(opt),
                    const SizedBox(height: 4),
                    Text(
                      opt.label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white54,
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        // TODO: When the backend supports canvas cropping, send the aspectRatio
        // as a server-side crop instruction. For now it is stored client-side only.
      ],
    );
  }

  Widget _buildRatioIcon(_AspectRatioOption opt) {
    final double w;
    final double h;
    if (opt.ratio == null) {
      w = 20; h = 16; // original — slightly wider
    } else if (opt.ratio! >= 1.0) {
      w = 20; h = 20 / opt.ratio!;
    } else {
      w = 20 * opt.ratio!; h = 20;
    }
    return Container(
      width: w.clamp(8, 24),
      height: h.clamp(8, 24),
      decoration: BoxDecoration(
        color: _aspectRatio == opt.id ? Colors.white : Colors.white38,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ── Quality section ─────────────────────────────────────────────────────

  Widget _buildQualitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.high_quality_rounded, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            const Text(
              'Quality',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Local only',
                style: TextStyle(color: Colors.amber, fontSize: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kQualities.map((opt) {
            final selected = _quality == opt.id;
            return GestureDetector(
              onTap: () => setState(() => _quality = opt.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white12,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      opt.label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      opt.description,
                      style: TextStyle(
                        color: selected ? Colors.white54 : Colors.white30,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        // TODO: When the backend supports a quality parameter, send 'quality'
        // in the upload request (e.g. as a query param or multipart field).
      ],
    );
  }

  // ── Audio section ────────────────────────────────────────────────────────

  Widget _buildAudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.volume_up_outlined, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            const Text(
              'Audio',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                setState(() {
                  _mute = !_mute;
                  _applyPreviewVolume();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _mute
                      ? Colors.red.withValues(alpha: 0.20)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _mute
                        ? Colors.red.withValues(alpha: 0.4)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _mute ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      size: 14,
                      color: _mute ? Colors.red.shade300 : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _mute ? 'Muted' : 'Mute',
                      style: TextStyle(
                        color: _mute ? Colors.red.shade300 : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (!_mute) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.volume_down_rounded, color: Colors.white38, size: 14),
              Expanded(
                child: Slider(
                  value: _volume.clamp(0.0, 2.0),
                  min: 0.0,
                  max: 2.0,
                  divisions: 20,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white24,
                  onChanged: (v) {
                    setState(() => _volume = v);
                    _applyPreviewVolume();
                  },
                ),
              ),
              const Icon(Icons.volume_up_rounded, color: Colors.white38, size: 14),
              SizedBox(
                width: 36,
                child: Text(
                  '${(_volume * 100).round()}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Time chip widget ──────────────────────────────────────────────────────

class _TimeChip extends StatelessWidget {
  final String label;
  const _TimeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
