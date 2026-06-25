import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/core/utils/app_snackbar.dart';

import '../providers/story_providers.dart';

// Background presets: each entry is [topColor, bottomColor]
const _kGradients = <List<Color>>[
  [Color(0xFF6A11CB), Color(0xFF2575FC)], // Indigo → Blue
  [Color(0xFFf953c6), Color(0xFFb91d73)], // Pink → Magenta
  [Color(0xFF11998e), Color(0xFF38ef7d)], // Teal → Green
  [Color(0xFFFC466B), Color(0xFF3F5EFB)], // Red → Blue
  [Color(0xFFf7971e), Color(0xFFffd200)], // Orange → Yellow
  [Color(0xFF1a1a2e), Color(0xFF16213e)], // Dark Navy
  [Color(0xFF200122), Color(0xFF6f0000)], // Dark Purple → Red
  [Color(0xFF000000), Color(0xFF434343)], // Black → Dark Grey
];

const _kTextColors = <Color>[
  Colors.white,
  Colors.yellow,
  Color(0xFFFFD700),
  Color(0xFF00FFFF),
  Color(0xFFFF69B4),
  Colors.black,
];

/// Full-screen text-only story composer.
/// - Choose background gradient
/// - Type text
/// - Choose text color and size
/// - Captures as PNG and uploads via [storyFeedProvider]
class StoryTextComposerScreen extends ConsumerStatefulWidget {
  const StoryTextComposerScreen({super.key});

  @override
  ConsumerState<StoryTextComposerScreen> createState() =>
      _StoryTextComposerScreenState();
}

class _StoryTextComposerScreenState
    extends ConsumerState<StoryTextComposerScreen> {
  final _textCtrl = TextEditingController();
  final _previewKey = GlobalKey();

  int _gradientIndex = 0;
  int _textColorIndex = 0;
  double _fontSize = 28;
  bool _isUploading = false;

  List<Color> get _gradient => _kGradients[_gradientIndex];
  Color get _textColor => _kTextColors[_textColorIndex];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title:
            const Text('Text Story', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _submit,
            child: _isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Share',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Story preview ─────────────────────────────────────────────
            Expanded(
              child: Center(
                child: _buildPreview(),
              ),
            ),

            // ── Text input ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _textCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Type something…',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // ── Font size slider ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.text_fields, color: Colors.white54, size: 16),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 16,
                      max: 56,
                      divisions: 10,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white24,
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                  const Icon(Icons.text_fields, color: Colors.white, size: 24),
                ],
              ),
            ),

            // ── Text color picker ─────────────────────────────────────────
            _buildColorRow(
              label: 'Text',
              colors: _kTextColors,
              selectedIndex: _textColorIndex,
              onSelect: (i) => setState(() => _textColorIndex = i),
              isCircle: true,
            ),

            // ── Background gradient picker ────────────────────────────────
            _buildGradientRow(),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final previewWidth = screenWidth * 0.55;
    final previewHeight = previewWidth * (16 / 9);

    return RepaintBoundary(
      key: _previewKey,
      child: Container(
        width: previewWidth,
        height: previewHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradient,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _textCtrl.text.isEmpty ? 'Your text here' : _textCtrl.text,
              style: TextStyle(
                color: _textCtrl.text.isEmpty
                    ? _textColor.withValues(alpha: 0.4)
                    : _textColor,
                fontSize: _fontSize,
                fontWeight: FontWeight.bold,
                height: 1.3,
                shadows: const [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.black38,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorRow({
    required String label,
    required List<Color> colors,
    required int selectedIndex,
    required void Function(int) onSelect,
    required bool isCircle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 8),
          ...List.generate(colors.length, (i) {
            final selected = i == selectedIndex;
            return GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isCircle ? null : BorderRadius.circular(6),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGradientRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text('BG',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 8),
          ...List.generate(_kGradients.length, (i) {
            final selected = i == _gradientIndex;
            return GestureDetector(
              onTap: () => setState(() => _gradientIndex = i),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _kGradients[i],
                  ),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      showAppSnackBar(context, 'Please enter some text first.', isError: true);
      return;
    }

    setState(() => _isUploading = true);

    try {
      final file = await _capturePreviewAsPng();
      if (!mounted) return;

      await ref.read(storyFeedProvider.notifier).createStory(
            mediaPath: file.path,
            caption: text,
          );

      if (mounted) {
        showAppSnackBar(context, 'Text story added to My Day! ✅');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        showAppSnackBar(
          context,
          'Failed to upload: ${e.toString().replaceAll('Exception: ', '')}',
          isError: true,
        );
      }
    }
  }

  /// Renders the preview widget to a high-res PNG file in the system temp dir.
  Future<File> _capturePreviewAsPng() async {
    final boundary = _previewKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    final tempDir = Directory.systemTemp.createTempSync('furtail_story_');
    final file = File('${tempDir.path}/text_story.png');
    await file.writeAsBytes(pngBytes);
    return file;
  }
}
