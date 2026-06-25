import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';

import '../providers/story_providers.dart';

// ── Overlay data models ───────────────────────────────────────────────────────

class _TextOverlay {
  final UniqueKey key;
  String text;
  Offset position;
  Color color;
  double fontSize;

  _TextOverlay({
    required this.key,
    required this.text,
    required this.position,
    this.color = Colors.white,
    this.fontSize = 28.0,
  });
}

class _StickerOverlay {
  final UniqueKey key;
  String emoji;
  Offset position;
  double size = 52.0;

  _StickerOverlay({
    required this.key,
    required this.emoji,
    required this.position,
  });
}

// ── Emoji sticker list ────────────────────────────────────────────────────────

const _kStickers = [
  '❤️', '😍', '🐾', '🐶', '🐱', '🐰', '🐹', '🦊',
  '🐻', '🐼', '🐸', '🦁', '🐯', '🐮', '🐷', '🐔',
  '🌟', '✨', '🎉', '🎊', '🔥', '💯', '😂', '😎',
  '🥺', '🥰', '😊', '😄', '🤩', '🙌', '👍', '💪',
];

// ── Drawing canvas ────────────────────────────────────────────────────────────

class _DrawCanvas extends StatelessWidget {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color color;
  final double strokeWidth;
  final bool isActive;
  final void Function(Offset) onStrokeStart;
  final void Function(Offset) onStrokeUpdate;
  final VoidCallback onStrokeEnd;

  const _DrawCanvas({
    required this.strokes,
    required this.currentStroke,
    required this.color,
    required this.strokeWidth,
    required this.isActive,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final canvas = CustomPaint(
      painter: _StrokePainter(
        strokes: strokes,
        currentStroke: currentStroke,
        color: color,
        strokeWidth: strokeWidth,
      ),
      child: const SizedBox.expand(),
    );

    if (!isActive) return IgnorePointer(child: canvas);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => onStrokeStart(d.localPosition),
      onPanUpdate: (d) => onStrokeUpdate(d.localPosition),
      onPanEnd: (_) => onStrokeEnd(),
      child: canvas,
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color color;
  final double strokeWidth;

  const _StrokePainter({
    required this.strokes,
    required this.currentStroke,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }
    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(points.first, strokeWidth / 2,
          paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StrokePainter _) => true;
}

// ── Main screen ───────────────────────────────────────────────────────────────

/// Story editor shown after selecting a file from [CreateStoryScreen].
///
/// Functional tools:
/// - Text overlay: add, drag, tap-to-edit, long-press-to-delete
/// - Sticker overlay: emoji picker, drag, long-press-to-delete
/// - Draw: freehand painting, color/width picker, clear
/// - Crop: image cropper (image only)
///
/// On publish (image with overlays): the composite is captured as PNG via
/// RepaintBoundary and uploaded instead of the original file, burning all
/// overlays into the image.
///
/// On publish (video): original video is uploaded; overlay metadata is
/// appended to caption. Full video overlay rendering is a future TODO.
class StoryEditorScreen extends ConsumerStatefulWidget {
  final String filePath;
  final bool isVideo;

  const StoryEditorScreen({
    super.key,
    required this.filePath,
    required this.isVideo,
  });

  @override
  ConsumerState<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends ConsumerState<StoryEditorScreen> {
  late String _currentFilePath;
  final _captionCtrl = TextEditingController();
  final _compositeKey = GlobalKey();
  final _stackKey = GlobalKey();

  // Overlays
  final List<_TextOverlay> _textOverlays = [];
  final List<_StickerOverlay> _stickerOverlays = [];

  // Drawing
  final List<List<Offset>> _drawStrokes = [];
  List<Offset> _currentStroke = [];
  bool _isDrawMode = false;
  Color _drawColor = Colors.white;
  double _strokeWidth = 5.0;

  // Upload
  bool _isUploading = false;
  bool _isCropping = false;
  String _uploadStatus = '';

  // Stack size for centering new overlays
  Size _stackSize = Size.zero;
  bool _isCoverFit = true;

  @override
  void initState() {
    super.initState();
    _currentFilePath = widget.filePath;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshStackSize());
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  void _refreshStackSize() {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && mounted) setState(() => _stackSize = box.size);
  }

  Offset get _centerPosition => _stackSize != Size.zero
      ? Offset(_stackSize.width / 2 - 50, _stackSize.height / 2 - 20)
      : const Offset(80, 160);

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              SafeArea(bottom: false, child: _buildTopBar()),
              Expanded(child: _buildComposite()),
              SafeArea(
                top: false,
                child: _isDrawMode ? _buildDrawControls() : _buildBottomControls(),
              ),
            ],
          ),
          if (_isUploading) _buildProgressOverlay(),
        ],
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: _isUploading ? null : () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Story Editor',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          if (!widget.isVideo) ...[
            IconButton(
              icon: Icon(
                _isCoverFit ? Icons.fit_screen_outlined : Icons.fullscreen_rounded,
                color: Colors.white,
              ),
              tooltip: _isCoverFit ? 'Fit to Canvas' : 'Fill Canvas',
              onPressed: () => setState(() => _isCoverFit = !_isCoverFit),
            ),
            IconButton(
              icon: const Icon(Icons.crop_rounded, color: Colors.white),
              tooltip: 'Crop',
              onPressed: (_isUploading || _isCropping) ? null : _cropImage,
            ),
          ]
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ── Composite area ────────────────────────────────────────────────────────────

  Widget _buildComposite() {
    return Center(
      child: RepaintBoundary(
        key: _compositeKey,
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Stack(
            key: _stackKey,
            fit: StackFit.expand,
            children: [
              _buildMediaPreview(),
              ..._textOverlays.map(_buildTextOverlay),
              ..._stickerOverlays.map(_buildStickerOverlay),
              if (_drawStrokes.isNotEmpty ||
                  _currentStroke.isNotEmpty ||
                  _isDrawMode)
                _DrawCanvas(
                  strokes: _drawStrokes,
                  currentStroke: _currentStroke,
                  color: _drawColor,
                  strokeWidth: _strokeWidth,
                  isActive: _isDrawMode,
                  onStrokeStart: (p) =>
                      setState(() => _currentStroke = [p]),
                  onStrokeUpdate: (p) =>
                      setState(() => _currentStroke.add(p)),
                  onStrokeEnd: () => setState(() {
                    if (_currentStroke.isNotEmpty) {
                      _drawStrokes.add(List.from(_currentStroke));
                    }
                    _currentStroke = [];
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (widget.isVideo) {
      return Container(
        color: Colors.black,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, size: 72, color: Colors.white54),
            SizedBox(height: 12),
            Text('Video selected',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      );
    }
    return Image.file(
      File(_currentFilePath),
      fit: _isCoverFit ? BoxFit.cover : BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, e1, e2) => Container(
        color: Colors.grey[900],
        child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 64)),
      ),
    );
  }

  // ── Overlay widgets ───────────────────────────────────────────────────────────

  Widget _buildTextOverlay(_TextOverlay overlay) {
    return Positioned(
      left: overlay.position.dx,
      top: overlay.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate:
            _isDrawMode ? null : (d) => setState(() => overlay.position += d.delta),
        onTap: _isDrawMode ? null : () => _editText(overlay),
        onLongPress: _isDrawMode ? null : () => _deleteText(overlay),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            overlay.text,
            style: TextStyle(
              color: overlay.color,
              fontSize: overlay.fontSize,
              fontWeight: FontWeight.bold,
              shadows: const [
                Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(1, 1))
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerOverlay(_StickerOverlay overlay) {
    return Positioned(
      left: overlay.position.dx,
      top: overlay.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate:
            _isDrawMode ? null : (d) => setState(() => overlay.position += d.delta),
        onLongPress: _isDrawMode ? null : () => _deleteSticker(overlay),
        child: Text(overlay.emoji, style: TextStyle(fontSize: overlay.size)),
      ),
    );
  }

  // ── Bottom controls ───────────────────────────────────────────────────────────

  Widget _buildBottomControls() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ToolBtn(icon: Icons.text_fields_rounded, label: 'Text', onTap: _addText),
              const SizedBox(width: 20),
              _ToolBtn(icon: Icons.emoji_emotions_outlined, label: 'Sticker', onTap: _addSticker),
              const SizedBox(width: 20),
              _ToolBtn(
                icon: Icons.brush_outlined,
                label: 'Draw',
                onTap: () => setState(() => _isDrawMode = true),
              ),
              if (_drawStrokes.isNotEmpty) ...[
                const SizedBox(width: 20),
                _ToolBtn(
                  icon: Icons.delete_sweep_outlined,
                  label: 'Clear',
                  onTap: () => setState(() {
                    _drawStrokes.clear();
                    _currentStroke = [];
                  }),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captionCtrl,
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a caption…',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _isUploading ? null : _publish,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isUploading ? _uploadStatus : 'Share to My Day',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawControls() {
    const drawColors = [
      Colors.white,
      Colors.red,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.black,
    ];
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Color:',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 8),
              ...drawColors.map(
                (c) => GestureDetector(
                  onTap: () => setState(() => _drawColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _drawColor == c ? Colors.white : Colors.white24,
                        width: _drawColor == c ? 2.5 : 1,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _drawStrokes.clear();
                  _currentStroke = [];
                }),
                child: const Text('Clear', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.line_weight, color: Colors.white54, size: 18),
              Expanded(
                child: Slider(
                  value: _strokeWidth,
                  min: 2,
                  max: 16,
                  divisions: 7,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white24,
                  onChanged: (v) => setState(() => _strokeWidth = v),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isDrawMode = false),
                child: const Text('Done',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  _uploadStatus,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tool actions ──────────────────────────────────────────────────────────────

  Future<void> _addText() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _TextDialog(),
    );
    if (result == null || !mounted) return;
    final text = (result['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) return;
    setState(() {
      _textOverlays.add(_TextOverlay(
        key: UniqueKey(),
        text: text,
        position: _centerPosition,
        color: result['color'] as Color? ?? Colors.white,
        fontSize: result['fontSize'] as double? ?? 28.0,
      ));
    });
    _refreshStackSize();
  }

  Future<void> _editText(_TextOverlay overlay) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TextDialog(
        initialText: overlay.text,
        initialColor: overlay.color,
        initialFontSize: overlay.fontSize,
      ),
    );
    if (result == null || !mounted) return;
    if (result['delete'] == true) {
      _deleteText(overlay);
      return;
    }
    final text = (result['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) {
      _deleteText(overlay);
      return;
    }
    setState(() {
      overlay.text = text;
      overlay.color = result['color'] as Color? ?? overlay.color;
      overlay.fontSize = result['fontSize'] as double? ?? overlay.fontSize;
    });
  }

  void _deleteText(_TextOverlay overlay) => setState(() => _textOverlays.remove(overlay));

  Future<void> _addSticker() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _StickerSheet(),
    );
    if (emoji == null || !mounted) return;
    setState(() {
      _stickerOverlays.add(_StickerOverlay(
        key: UniqueKey(),
        emoji: emoji,
        position: _centerPosition,
      ));
    });
    _refreshStackSize();
  }

  void _deleteSticker(_StickerOverlay overlay) =>
      setState(() => _stickerOverlays.remove(overlay));

  Future<void> _cropImage() async {
    if (_isCropping || widget.isVideo) return;
    setState(() => _isCropping = true);
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _currentFilePath,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Story',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
            aspectRatioPresets: const [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.square,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Story',
            aspectRatioPresets: const [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.square,
            ],
          ),
        ],
      );
      if (cropped != null && mounted) {
        setState(() => _currentFilePath = cropped.path);
      }
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  // ── Publish ───────────────────────────────────────────────────────────────────

  Future<void> _publish() async {
    if (_isUploading) return;
    _setStatus(true, 'Uploading story…');

    try {
      String fileToUpload = _currentFilePath;

      // For images with any overlay: capture composite as PNG
      final hasOverlays = _textOverlays.isNotEmpty ||
          _stickerOverlays.isNotEmpty ||
          _drawStrokes.isNotEmpty;

      if (!widget.isVideo && hasOverlays) {
        _setStatus(true, 'Processing story…');
        fileToUpload = await _captureComposite();
      }

      if (!mounted) return;

      final caption = _captionCtrl.text.trim();

      // For video with overlays, prefix caption with overlay text summary
      // TODO: server-side video overlay rendering with ffmpeg
      String? finalCaption = caption.isNotEmpty ? caption : null;
      if (widget.isVideo && _textOverlays.isNotEmpty) {
        final texts = _textOverlays.map((t) => t.text).join(' · ');
        finalCaption = caption.isNotEmpty ? '$texts — $caption' : texts;
      }

      await ref.read(storyFeedProvider.notifier).createStory(
            mediaPath: fileToUpload,
            caption: finalCaption,
          );

      if (!mounted) return;
      _setStatus(false, '');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story added to My Day!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _setStatus(false, '');
      debugPrint('[StoryEditor] publish error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Upload failed. Please try again.'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<String> _captureComposite() async {
    // Let any pending setState paint before capture
    await Future.delayed(const Duration(milliseconds: 80));

    final boundary =
        _compositeKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return _currentFilePath;

    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    final tempDir = Directory.systemTemp.createTempSync('furtail_composite_');
    final file = File('${tempDir.path}/composite_story.png');
    await file.writeAsBytes(pngBytes);
    return file.path;
  }

  void _setStatus(bool uploading, String status) {
    if (!mounted) return;
    setState(() {
      _isUploading = uploading;
      _uploadStatus = status;
    });
  }
}

// ── Tool button ────────────────────────────────────────────────────────────────

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white30),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Text overlay dialog ────────────────────────────────────────────────────────

class _TextDialog extends StatefulWidget {
  final String? initialText;
  final Color? initialColor;
  final double? initialFontSize;

  const _TextDialog(
      {this.initialText, this.initialColor, this.initialFontSize});

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _ctrl;
  late Color _color;
  late double _fontSize;

  static const _colors = [
    Colors.white,
    Colors.yellow,
    Colors.red,
    Colors.green,
    Colors.cyan,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText ?? '');
    _color = widget.initialColor ?? Colors.white;
    _fontSize = widget.initialFontSize ?? 28.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initialText != null ? 'Edit Text' : 'Add Text',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 3,
              style: TextStyle(color: _color, fontSize: _fontSize),
              decoration: const InputDecoration(
                hintText: 'Enter text…',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white12,
                border:
                    OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Color:',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(width: 8),
                ..._colors.map((c) => GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c
                                ? Colors.white
                                : Colors.white24,
                            width: _color == c ? 2.5 : 1,
                          ),
                        ),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Size:',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 12)),
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
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.initialText != null)
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                      onPressed: () =>
                          Navigator.pop(context, {'delete': true}),
                    ),
                  ),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, {
                      'text': _ctrl.text,
                      'color': _color,
                      'fontSize': _fontSize,
                    }),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sticker picker sheet ───────────────────────────────────────────────────────

class _StickerSheet extends StatelessWidget {
  const _StickerSheet();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 8),
        const Text('Choose a Sticker',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _kStickers.length,
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () => Navigator.pop(ctx, _kStickers[i]),
              child: Center(
                child: Text(_kStickers[i],
                    style: const TextStyle(fontSize: 28)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
