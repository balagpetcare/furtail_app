import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageEditResult {
  final List<File> files;
  final int currentIndex;

  const ImageEditResult({
    required this.files,
    required this.currentIndex,
  });

  File get file => files[currentIndex];
}

enum _EditorTab { crop, draw, text, stickers, filters, adjust }

enum _OverlayKind { text, emoji, icon }

class _AspectRatioOption {
  final String id;
  final String label;
  final double? ratioX;
  final double? ratioY;

  const _AspectRatioOption(this.id, this.label, this.ratioX, this.ratioY);

  bool get isFree => ratioX == null || ratioY == null;
}

class _FilterPreset {
  final String id;
  final String label;
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;

  const _FilterPreset({
    required this.id,
    required this.label,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.warmth = 0,
  });
}

class _OverlayItem {
  final String id;
  final _OverlayKind kind;
  final String? text;
  final IconData? icon;
  final Color color;
  final double x;
  final double y;
  final double scale;
  final double rotation;

  const _OverlayItem({
    required this.id,
    required this.kind,
    required this.color,
    required this.x,
    required this.y,
    this.scale = 1,
    this.rotation = 0,
    this.text,
    this.icon,
  });

  _OverlayItem copyWith({
    String? text,
    IconData? icon,
    Color? color,
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) {
    return _OverlayItem(
      id: id,
      kind: kind,
      text: text ?? this.text,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }
}

class _StrokePoint {
  final Offset point;
  const _StrokePoint(this.point);
}

class _DrawStroke {
  final List<_StrokePoint> points;
  final Color color;
  final double width;
  final bool erase;

  const _DrawStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.erase,
  });

  _DrawStroke copyWith({
    List<_StrokePoint>? points,
    Color? color,
    double? width,
    bool? erase,
  }) {
    return _DrawStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      erase: erase ?? this.erase,
    );
  }
}

class _EditorSnapshot {
  final File baseFile;
  final String selectedAspectRatioId;
  final String filterPresetId;
  final double brightness;
  final double contrast;
  final double saturation;
  final List<_OverlayItem> overlays;
  final List<_DrawStroke> strokes;

  const _EditorSnapshot({
    required this.baseFile,
    required this.selectedAspectRatioId,
    required this.filterPresetId,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.overlays,
    required this.strokes,
  });

  _EditorSnapshot copyWith({
    File? baseFile,
    String? selectedAspectRatioId,
    String? filterPresetId,
    double? brightness,
    double? contrast,
    double? saturation,
    List<_OverlayItem>? overlays,
    List<_DrawStroke>? strokes,
  }) {
    return _EditorSnapshot(
      baseFile: baseFile ?? this.baseFile,
      selectedAspectRatioId: selectedAspectRatioId ?? this.selectedAspectRatioId,
      filterPresetId: filterPresetId ?? this.filterPresetId,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      overlays: overlays ??
          this.overlays.map((item) => item.copyWith()).toList(),
      strokes: strokes ??
          this.strokes
              .map((stroke) => stroke.copyWith(
                    points: List<_StrokePoint>.from(stroke.points),
                  ))
              .toList(),
    );
  }
}

const _aspectRatios = <_AspectRatioOption>[
  _AspectRatioOption('free', 'Free', null, null),
  _AspectRatioOption('1:1', '1:1', 1, 1),
  _AspectRatioOption('4:5', '4:5', 4, 5),
  _AspectRatioOption('9:16', '9:16', 9, 16),
  _AspectRatioOption('16:9', '16:9', 16, 9),
];

const _filterPresets = <_FilterPreset>[
  _FilterPreset(id: 'original', label: 'Original'),
  _FilterPreset(id: 'bright', label: 'Bright', brightness: 0.10, contrast: 1.05, saturation: 1.02),
  _FilterPreset(id: 'warm', label: 'Warm', brightness: 0.04, saturation: 1.08, warmth: 0.14),
  _FilterPreset(id: 'cool', label: 'Cool', contrast: 1.02, saturation: 0.96, warmth: -0.12),
  _FilterPreset(id: 'bw', label: 'B & W', saturation: 0, contrast: 1.06),
  _FilterPreset(id: 'high_contrast', label: 'High Contrast', contrast: 1.22, saturation: 1.06),
];

const _commonColors = <Color>[
  Colors.white,
  Colors.black,
  Color(0xFFFF5252),
  Color(0xFFFFC107),
  Color(0xFF4CAF50),
  Color(0xFF29B6F6),
  Color(0xFFAB47BC),
];

const _emojiStickers = <String>['🐶', '🐱', '🐾', '🦴', '❤️', '✨', '🎀', '🫶'];
const _iconStickers = <IconData>[
  Icons.pets_rounded,
  Icons.favorite_rounded,
  Icons.star_rounded,
  Icons.park_rounded,
  Icons.shield_rounded,
  Icons.local_hospital_rounded,
];

class ImageEditorScreen extends StatefulWidget {
  final List<File> files;
  final int initialIndex;

  const ImageEditorScreen({
    super.key,
    required this.files,
    this.initialIndex = 0,
  });

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final GlobalKey _compositionKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();
  final TransformationController _previewController = TransformationController();

  late List<_EditorSnapshot> _images;
  late List<List<_EditorSnapshot>> _history;
  late List<int> _historyIndex;
  late int _activeImageIndex;

  _EditorTab _activeTab = _EditorTab.crop;
  bool _processing = false;
  String? _selectedOverlayId;
  bool _drawErase = false;
  Color _drawColor = Colors.white;
  double _drawWidth = 8;
  Size _compositionSize = Size.zero;

  _EditorSnapshot get _state => _images[_activeImageIndex];

  @override
  void initState() {
    super.initState();
    _activeImageIndex = widget.initialIndex.clamp(0, widget.files.length - 1);
    _images = widget.files
        .map(
          (file) => _EditorSnapshot(
            baseFile: file,
            selectedAspectRatioId: _aspectRatios.first.id,
            filterPresetId: _filterPresets.first.id,
            brightness: 0,
            contrast: 1,
            saturation: 1,
            overlays: const [],
            strokes: const [],
          ),
        )
        .toList();
    _history = _images.map((snapshot) => [snapshot.copyWith()]).toList();
    _historyIndex = List<int>.filled(_images.length, 0);
  }

  @override
  void dispose() {
    _textController.dispose();
    _previewController.dispose();
    super.dispose();
  }

  bool get _canUndo => _historyIndex[_activeImageIndex] > 0;
  bool get _canRedo =>
      _historyIndex[_activeImageIndex] < _history[_activeImageIndex].length - 1;

  _FilterPreset get _currentPreset => _filterPresets.firstWhere(
        (preset) => preset.id == _state.filterPresetId,
        orElse: () => _filterPresets.first,
      );

  _AspectRatioOption get _currentAspect => _aspectRatios.firstWhere(
        (aspect) => aspect.id == _state.selectedAspectRatioId,
        orElse: () => _aspectRatios.first,
      );

  _OverlayItem? get _selectedOverlay {
    final id = _selectedOverlayId;
    if (id == null) return null;
    for (final item in _state.overlays) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _commitState(_EditorSnapshot next) {
    final index = _activeImageIndex;
    final trimmed = _history[index].take(_historyIndex[index] + 1).toList();
    final committed = next.copyWith();
    setState(() {
      _images[index] = committed;
      _history[index] = [...trimmed, committed];
      _historyIndex[index] = _history[index].length - 1;
    });
  }

  void _replaceStateWithoutHistory(_EditorSnapshot next) {
    setState(() {
      _images[_activeImageIndex] = next;
    });
  }

  Future<File> _exportCompositionToFile(String suffix) async {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final boundary =
        _compositionKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return _state.baseFile;
    final width = boundary.size.width <= 0 ? 1.0 : boundary.size.width;
    final image = await boundary.toImage(
      pixelRatio: (1080 / width).clamp(1.0, 4.0),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return _state.baseFile;
    final tempDir = await getTemporaryDirectory();
    final path = p.join(
      tempDir.path,
      '${p.basenameWithoutExtension(_state.baseFile.path)}_${suffix}_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    final file = File(path);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _flattenActiveImage() async {
    final exported = await _exportCompositionToFile('flattened');
    final resetState = _state.copyWith(
      baseFile: exported,
      filterPresetId: _filterPresets.first.id,
      brightness: 0,
      contrast: 1,
      saturation: 1,
      overlays: const [],
      strokes: const [],
    );
    _replaceStateWithoutHistory(resetState);
    final idx = _activeImageIndex;
    _history[idx] = [resetState.copyWith()];
    _historyIndex[idx] = 0;
    _selectedOverlayId = null;
  }

  Future<void> _switchImage(int newIndex) async {
    if (_processing || newIndex == _activeImageIndex) return;
    setState(() => _processing = true);
    try {
      await _flattenActiveImage();
      if (!mounted) return;
      setState(() {
        _activeImageIndex = newIndex;
        _selectedOverlayId = null;
        _previewController.value = Matrix4.identity();
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _cropImage() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final sourceFile = _state.baseFile;
      final path = sourceFile.path;

      // Validate source before handing to native cropper.
      if (path.isEmpty || !sourceFile.existsSync() || sourceFile.lengthSync() == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image not ready for crop. Please wait or re-select.')),
          );
        }
        return;
      }

      // Copy to app cache with a safe absolute .jpg path.
      // Passing content:// URIs or external storage paths directly to UCrop
      // can cause FileUriExposedException on Android 7+ which kills the process.
      final cacheDir = await getTemporaryDirectory();
      final safePath = p.join(
        cacheDir.path,
        'crop_src_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await sourceFile.copy(safePath);

      final aspect = _currentAspect;
      final cropped = await ImageCropper().cropImage(
        sourcePath: safePath,
        compressQuality: 92,
        aspectRatio: aspect.isFree
            ? null
            : CropAspectRatio(ratioX: aspect.ratioX!, ratioY: aspect.ratioY!),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: !aspect.isFree,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: !aspect.isFree,
          ),
        ],
      );

      // Clean up the temporary copy regardless of outcome.
      try {
        final tmp = File(safePath);
        if (tmp.existsSync()) tmp.deleteSync();
      } catch (_) {}

      if (cropped == null || !mounted) return;
      _commitState(_state.copyWith(baseFile: File(cropped.path)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Crop failed: ${e.toString().split('\n').first}')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _rotateSelectedOverlay() {
    final selected = _selectedOverlay;
    if (selected == null) return;
    _commitState(
      _state.copyWith(
        overlays: _state.overlays
            .map((item) => item.id == selected.id
                ? item.copyWith(rotation: item.rotation + 0.35)
                : item.copyWith())
            .toList(),
      ),
    );
  }

  Future<void> _flipImage() async {
    if (_processing) return;
    if (_state.baseFile.path.isEmpty || !_state.baseFile.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image file not found. Please select an image again.')),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final bytes = await _state.baseFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null || !mounted) return;
      final flipped = img.flipHorizontal(decoded);
      final tempDir = await getTemporaryDirectory();
      final path = p.join(
        tempDir.path,
        '${p.basenameWithoutExtension(_state.baseFile.path)}_flip_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      final outFile = File(path);
      await outFile.writeAsBytes(img.encodePng(flipped), flush: true);
      if (!mounted) return;
      _commitState(_state.copyWith(baseFile: outFile));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _deleteSelectedOverlay() {
    final selected = _selectedOverlay;
    if (selected == null) return;
    _selectedOverlayId = null;
    _commitState(
      _state.copyWith(
        overlays: _state.overlays.where((item) => item.id != selected.id).toList(),
      ),
    );
  }

  void _undo() {
    if (!_canUndo) return;
    final index = _activeImageIndex;
    setState(() {
      _historyIndex[index] -= 1;
      _images[index] = _history[index][_historyIndex[index]].copyWith();
      _selectedOverlayId = null;
    });
  }

  void _redo() {
    if (!_canRedo) return;
    final index = _activeImageIndex;
    setState(() {
      _historyIndex[index] += 1;
      _images[index] = _history[index][_historyIndex[index]].copyWith();
      _selectedOverlayId = null;
    });
  }

  void _reset() {
    final reset = _EditorSnapshot(
      baseFile: widget.files[_activeImageIndex],
      selectedAspectRatioId: _aspectRatios.first.id,
      filterPresetId: _filterPresets.first.id,
      brightness: 0,
      contrast: 1,
      saturation: 1,
      overlays: const [],
      strokes: const [],
    );
    setState(() {
      _images[_activeImageIndex] = reset;
      _history[_activeImageIndex] = [reset.copyWith()];
      _historyIndex[_activeImageIndex] = 0;
      _selectedOverlayId = null;
    });
  }

  Future<void> _addTextOverlay() async {
    _textController.clear();
    Color selectedColor = _commonColors.first;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add text', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter text',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _commonColors.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final color = _commonColors[index];
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedColor = color),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == selectedColor ? Colors.white : Colors.white24,
                                width: color == selectedColor ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final text = _textController.text.trim();
                        if (text.isEmpty) return;
                        Navigator.pop(ctx, {'text': text, 'color': selectedColor});
                      },
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result == null) return;
    final overlay = _OverlayItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: _OverlayKind.text,
      text: result['text'] as String,
      color: result['color'] as Color,
      x: 0.5,
      y: 0.5,
    );
    _selectedOverlayId = overlay.id;
    _commitState(_state.copyWith(overlays: [..._state.overlays, overlay]));
  }

  void _addSticker({String? emoji, IconData? icon}) {
    final overlay = _OverlayItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: emoji != null ? _OverlayKind.emoji : _OverlayKind.icon,
      text: emoji,
      icon: icon,
      color: Colors.white,
      x: 0.5,
      y: 0.5,
      scale: 1.2,
    );
    _selectedOverlayId = overlay.id;
    _commitState(_state.copyWith(overlays: [..._state.overlays, overlay]));
  }

  void _setFilter(String id) {
    _commitState(_state.copyWith(filterPresetId: id));
  }

  void _setAdjustments({
    double? brightness,
    double? contrast,
    double? saturation,
    bool commit = false,
  }) {
    final next = _state.copyWith(
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
    );
    if (commit) {
      _commitState(next);
    } else {
      _replaceStateWithoutHistory(next);
    }
  }

  List<double> _identity() => <double>[
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ];

  List<double> _multiply(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        double sum = 0;
        for (int i = 0; i < 4; i++) {
          sum += a[row * 5 + i] * b[i * 5 + col];
        }
        if (col == 4) sum += a[row * 5 + 4];
        out[row * 5 + col] = sum;
      }
    }
    return out;
  }

  List<double> _brightnessMatrix(double value) => <double>[
        1, 0, 0, 0, value * 255,
        0, 1, 0, 0, value * 255,
        0, 0, 1, 0, value * 255,
        0, 0, 0, 1, 0,
      ];

  List<double> _contrastMatrix(double value) {
    final t = (1 - value) * 128;
    return <double>[
      value, 0, 0, 0, t,
      0, value, 0, 0, t,
      0, 0, value, 0, t,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _saturationMatrix(double value) {
    const rw = 0.3086;
    const gw = 0.6094;
    const bw = 0.0820;
    final inv = 1 - value;
    final r = inv * rw;
    final g = inv * gw;
    final b = inv * bw;
    return <double>[
      r + value, g, b, 0, 0,
      r, g + value, b, 0, 0,
      r, g, b + value, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _warmMatrix(double value) => <double>[
        1 + (value * 0.18), 0, 0, 0, 0,
        0, 1 + (value * 0.05), 0, 0, 0,
        0, 0, 1 - (value * 0.18), 0, 0,
        0, 0, 0, 1, 0,
      ];

  List<double> _colorMatrix() {
    final preset = _currentPreset;
    var matrix = _identity();
    matrix = _multiply(matrix, _brightnessMatrix(preset.brightness + _state.brightness));
    matrix = _multiply(matrix, _contrastMatrix(preset.contrast * _state.contrast));
    matrix = _multiply(matrix, _saturationMatrix(preset.saturation * _state.saturation));
    if (preset.warmth != 0) {
      matrix = _multiply(matrix, _warmMatrix(preset.warmth));
    }
    return matrix;
  }

  Widget _overlayWidget(_OverlayItem item, double width, double height) {
    final selected = item.id == _selectedOverlayId;
    final baseSize = (width < height ? width : height) *
        (item.kind == _OverlayKind.text ? 0.11 : 0.14);
    final child = item.kind == _OverlayKind.text
        ? Text(
            item.text ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: item.color,
              fontSize: baseSize,
              fontWeight: FontWeight.w700,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
            ),
          )
        : item.kind == _OverlayKind.emoji
            ? Text(
                item.text ?? '',
                style: TextStyle(
                  fontSize: baseSize,
                  shadows: const [Shadow(color: Colors.black38, blurRadius: 8)],
                ),
              )
            : Icon(
                item.icon,
                size: baseSize,
                color: item.color,
                shadows: const [Shadow(color: Colors.black38, blurRadius: 8)],
              );

    return Positioned(
      left: item.x * width,
      top: item.y * height,
      child: GestureDetector(
        onTap: () => setState(() => _selectedOverlayId = item.id),
        onScaleUpdate: (details) {
          final dx = details.focalPointDelta.dx / width;
          final dy = details.focalPointDelta.dy / height;
          _replaceStateWithoutHistory(
            _state.copyWith(
              overlays: _state.overlays
                  .map((overlay) => overlay.id == item.id
                      ? overlay.copyWith(
                          x: (overlay.x + dx).clamp(0.06, 0.94),
                          y: (overlay.y + dy).clamp(0.06, 0.94),
                          scale: (overlay.scale * details.scale).clamp(0.5, 3.5),
                          rotation: overlay.rotation + details.rotation,
                        )
                      : overlay.copyWith())
                  .toList(),
            ),
          );
        },
        onScaleEnd: (_) => _commitState(_state),
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Transform.rotate(
            angle: item.rotation,
            child: Transform.scale(
              scale: item.scale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: selected
                        ? BoxDecoration(
                            border: Border.all(color: Colors.white70),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    child: child,
                  ),
                  if (selected)
                    Positioned(
                      right: -12,
                      top: -12,
                      child: GestureDetector(
                        onTap: _deleteSelectedOverlay,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (mounted && size != _compositionSize) {
            setState(() => _compositionSize = size);
          }
        });
        return RepaintBoundary(
          key: _compositionKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.matrix(_colorMatrix()),
                child: Image.file(_state.baseFile, fit: BoxFit.contain),
              ),
              CustomPaint(
                painter: _StrokePainter(_state.strokes),
                size: Size.infinite,
              ),
              ..._state.overlays.map(
                (item) => _overlayWidget(item, constraints.maxWidth, constraints.maxHeight),
              ),
              if (_activeTab == _EditorTab.draw)
                GestureDetector(
                  onPanStart: (details) {
                    final stroke = _DrawStroke(
                      points: [_StrokePoint(details.localPosition)],
                      color: _drawColor,
                      width: _drawWidth,
                      erase: _drawErase,
                    );
                    _replaceStateWithoutHistory(
                      _state.copyWith(strokes: [..._state.strokes, stroke]),
                    );
                  },
                  onPanUpdate: (details) {
                    final strokes = List<_DrawStroke>.from(_state.strokes);
                    if (strokes.isEmpty) return;
                    final last = strokes.removeLast();
                    strokes.add(
                      last.copyWith(points: [...last.points, _StrokePoint(details.localPosition)]),
                    );
                    _replaceStateWithoutHistory(_state.copyWith(strokes: strokes));
                  },
                  onPanEnd: (_) => _commitState(_state),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnailStrip() {
    if (_images.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == _activeImageIndex;
          return GestureDetector(
            onTap: () => _switchImage(index),
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? Theme.of(context).colorScheme.primary : Colors.white24,
                  width: selected ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Builder(builder: (ctx) {
                final f = _images[index].baseFile;
                if (f.path.isNotEmpty && f.existsSync()) {
                  return Image.file(f, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ThumbErrorBox());
                }
                return const _ThumbErrorBox();
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCropPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _aspectRatios.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = _aspectRatios[index];
              final selected = item.id == _state.selectedAspectRatioId;
              return ChoiceChip(
                selected: selected,
                label: Text(item.label),
                onSelected: (_) => _commitState(_state.copyWith(selectedAspectRatioId: item.id)),
                backgroundColor: Colors.white10,
                selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.24),
                labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ToolButton(icon: Icons.crop, label: 'Crop', onTap: _processing ? null : _cropImage),
            _ToolButton(icon: Icons.rotate_90_degrees_ccw, label: 'Rotate', onTap: _rotateSelectedOverlay),
            _ToolButton(icon: Icons.flip, label: 'Flip', onTap: _flipImage),
            _ToolButton(icon: Icons.refresh, label: 'Reset', onTap: _reset),
          ],
        ),
      ],
    );
  }

  Widget _buildDrawPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilterChip(
              selected: _drawErase,
              label: const Text('Eraser'),
              onSelected: (value) => setState(() => _drawErase = value),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Slider(
                value: _drawWidth,
                min: 2,
                max: 24,
                onChanged: (value) => setState(() => _drawWidth = value),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _commonColors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final color = _commonColors[index];
              final selected = color == _drawColor;
              return GestureDetector(
                onTap: () => setState(() => _drawColor = color),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.white : Colors.white24,
                      width: selected ? 3 : 1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextPanel() {
    return Row(
      children: [
        FilledButton.icon(
          onPressed: _addTextOverlay,
          icon: const Icon(Icons.text_fields),
          label: const Text('Add Text'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _selectedOverlay != null ? _deleteSelectedOverlay : null,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
        ),
      ],
    );
  }

  Widget _buildStickerPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _emojiStickers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => _addSticker(emoji: _emojiStickers[index]),
              child: Container(
                width: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_emojiStickers[index], style: const TextStyle(fontSize: 22)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _iconStickers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => _addSticker(icon: _iconStickers[index]),
              child: Container(
                width: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_iconStickers[index], color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel() {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filterPresets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _filterPresets[index];
          final selected = item.id == _state.filterPresetId;
          return GestureDetector(
            onTap: () => _setFilter(item.id),
            child: Container(
              width: 86,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.24)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdjustPanel() {
    return Column(
      children: [
        _AdjustRow(
          label: 'Brightness',
          value: _state.brightness,
          min: -0.35,
          max: 0.35,
          onChanged: (value) => _setAdjustments(brightness: value),
          onEnd: (value) => _setAdjustments(brightness: value, commit: true),
        ),
        _AdjustRow(
          label: 'Contrast',
          value: _state.contrast,
          min: 0.7,
          max: 1.5,
          onChanged: (value) => _setAdjustments(contrast: value),
          onEnd: (value) => _setAdjustments(contrast: value, commit: true),
        ),
        _AdjustRow(
          label: 'Saturation',
          value: _state.saturation,
          min: 0,
          max: 1.8,
          onChanged: (value) => _setAdjustments(saturation: value),
          onEnd: (value) => _setAdjustments(saturation: value, commit: true),
        ),
      ],
    );
  }

  Widget _buildPanel() {
    switch (_activeTab) {
      case _EditorTab.crop:
        return _buildCropPanel();
      case _EditorTab.draw:
        return _buildDrawPanel();
      case _EditorTab.text:
        return _buildTextPanel();
      case _EditorTab.stickers:
        return _buildStickerPanel();
      case _EditorTab.filters:
        return _buildFilterPanel();
      case _EditorTab.adjust:
        return _buildAdjustPanel();
    }
  }

  Widget _tabButton(_EditorTab tab, IconData icon, String label) {
    final selected = _activeTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = tab),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: selected ? Colors.white : Colors.white38),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.white : Colors.white38,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _done() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _selectedOverlayId = null;
    });
    final flattened = <File>[];
    try {
      for (int i = 0; i < _images.length; i++) {
        if (i != _activeImageIndex) {
          flattened.add(_images[i].baseFile);
          continue;
        }
        flattened.add(await _exportCompositionToFile('final'));
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        ImageEditResult(files: flattened, currentIndex: _activeImageIndex),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: _processing ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        leadingWidth: 80,
        title: const Text('Edit photo'),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _canUndo ? _undo : null, icon: const Icon(Icons.undo_rounded)),
          IconButton(onPressed: _canRedo ? _redo : null, icon: const Icon(Icons.redo_rounded)),
          TextButton(
            onPressed: _processing ? null : _done,
            child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_images.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _buildThumbnailStrip(),
            ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: InteractiveViewer(
                    transformationController: _previewController,
                    minScale: 0.8,
                    maxScale: 4,
                    child: _buildCanvas(),
                  ),
                ),
                if (_processing)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: const Color(0xFF121212),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 118),
                    child: SingleChildScrollView(child: _buildPanel()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _tabButton(_EditorTab.crop, Icons.crop, 'Crop'),
                      _tabButton(_EditorTab.draw, Icons.brush_outlined, 'Draw'),
                      _tabButton(_EditorTab.text, Icons.text_fields, 'Text'),
                      _tabButton(_EditorTab.stickers, Icons.emoji_emotions_outlined, 'Stickers'),
                      _tabButton(_EditorTab.filters, Icons.filter, 'Filters'),
                      _tabButton(_EditorTab.adjust, Icons.tune, 'Adjust'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<_DrawStroke> strokes;

  const _StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.erase ? Colors.black : stroke.color
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = stroke.erase ? BlendMode.clear : BlendMode.srcOver;
      final path = Path()..moveTo(stroke.points.first.point.dx, stroke.points.first.point.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.point.dx, point.point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: onTap == null ? Colors.white24 : Colors.white),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onTap == null ? Colors.white24 : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onEnd;

  const _AdjustRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: onEnd,
          ),
        ),
      ],
    );
  }
}

class _ThumbErrorBox extends StatelessWidget {
  const _ThumbErrorBox();
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white10,
        child: const Icon(Icons.broken_image_outlined, color: Colors.white30, size: 20),
      );
}
