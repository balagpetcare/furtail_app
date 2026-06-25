import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Result returned from [PetCoverEditScreen] — the cropped file.
class PetCoverEditResult {
  final File file;
  const PetCoverEditResult({required this.file});
}

/// Cover photo crop/edit screen.
///
/// Flow:
/// 1. "Choose from Gallery" button (guarded against duplicate taps)
/// 2. Opens ImageCropper with 3:1 / 16:9 widescreen presets
/// 3. Shows preview with Change / Use This Photo buttons
class PetCoverEditScreen extends StatefulWidget {
  const PetCoverEditScreen({super.key});

  @override
  State<PetCoverEditScreen> createState() => _PetCoverEditScreenState();
}

class _PetCoverEditScreenState extends State<PetCoverEditScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _isPickingImage = false;
  File? _croppedFile;
  String? _originalPath;

  bool get _hasImage => _croppedFile != null;

  // ── Pick from gallery (guarded against duplicate opens) ──────────────────

  Future<void> _pickFromGallery() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (x == null) return;
      _originalPath = x.path;
      await _cropAndSet(x.path);
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  // ── Crop with widescreen cover ratio ─────────────────────────────────────

  Future<void> _cropAndSet(String path) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: path,
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Cover',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
          aspectRatioPresets: const [
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
          ],
        ),
        IOSUiSettings(
          title: 'Adjust Cover',
          aspectRatioPresets: const [
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
          ],
        ),
      ],
    );
    if (cropped == null) return;
    if (!mounted) return;
    setState(() => _croppedFile = File(cropped.path));
  }

  // ── Re-crop ──────────────────────────────────────────────────────────────

  Future<void> _reCrop() async {
    final path = _originalPath;
    if (path == null || _isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      await _cropAndSet(path);
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cover Photo'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_isPickingImage) return;
          if (!_hasImage) {
            Navigator.pop(context);
            return;
          }
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Discard Cover Photo?'),
              content: const Text('Are you sure you want to discard the selected cover photo?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep Editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            Navigator.pop(context);
          }
        },
        child: SafeArea(
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_hasImage)
                Expanded(child: _buildPreview(context))
              else
                Expanded(child: _buildEmptyState(context)),
              const SizedBox(height: 16),
              if (_hasImage) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _isPickingImage ? null : _reCrop,
                        icon: const Icon(Icons.crop_outlined),
                        label: const Text('Adjust'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: cs.primary),
                          foregroundColor: cs.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _isPickingImage ? null : _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Change'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.orange),
                          foregroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      PetCoverEditResult(file: _croppedFile!),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      'Use This Photo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isPickingImage ? null : _pickFromGallery,
                    icon: _isPickingImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _isPickingImage ? 'Opening gallery…' : 'Choose from Gallery',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.image_outlined, size: 56, color: cs.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Select a cover photo',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Choose a wide image for your pet\'s cover.\n'
              'Crop to widescreen before applying.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    const previewHeight = 240.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: previewHeight,
            width: double.infinity,
            child: Image.file(_croppedFile!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.check_circle,
                size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Photo ready — tap Use This Photo to continue',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.black54),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
