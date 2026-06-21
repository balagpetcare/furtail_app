import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/profile_service.dart';

enum ProfileCropStyle { avatar, cover }

class ProfileMediaUploadResult {
  final int mediaId;
  final String previewUrl; // file:// path for instant preview
  const ProfileMediaUploadResult({
    required this.mediaId,
    required this.previewUrl,
  });
}

/// Gallery pick + crop + upload (used by cover + avatar buttons).
/// Returns [ProfileMediaUploadResult] so caller can instantly update UI.
class ProfileMediaUploadScreen extends StatefulWidget {
  final String title;
  final ProfileCropStyle cropStyle;

  const ProfileMediaUploadScreen({
    super.key,
    required this.title,
    required this.cropStyle,
  });

  @override
  State<ProfileMediaUploadScreen> createState() =>
      _ProfileMediaUploadScreenState();
}

class _ProfileMediaUploadScreenState extends State<ProfileMediaUploadScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final ProfileService _profileService = ProfileService();

  File? _selectedCroppedFile;
  String? _originalPickedPath; // used for re-crop
  double? _croppedAspectRatio; // width/height of cropped image
  bool _isUploading = false;

  bool get _hasImage => _selectedCroppedFile != null;

  Future<void> _pickFromGallery() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null) return;

    _originalPickedPath = picked.path;

    final cropped = await _cropImage(picked.path);
    if (cropped == null) return;

    await _setCroppedFile(File(cropped.path));
  }

  Future<void> _reCrop() async {
    final sourcePath = _originalPickedPath;
    if (sourcePath == null) return;

    final cropped = await _cropImage(sourcePath);
    if (cropped == null) return;

    await _setCroppedFile(File(cropped.path));
  }

  Future<void> _setCroppedFile(File file) async {
    final ratio = await _readAspectRatio(file);
    if (!mounted) return;
    setState(() {
      _selectedCroppedFile = file;
      _croppedAspectRatio = ratio;
    });
  }

  void _reset() {
    setState(() {
      _selectedCroppedFile = null;
      _originalPickedPath = null;
      _croppedAspectRatio = null;
    });
  }

  Future<double?> _readAspectRatio(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();

      final w = frame.image.width.toDouble();
      final h = frame.image.height.toDouble();
      if (w <= 0 || h <= 0) return null;

      return w / h;
    } catch (_) {
      return null;
    }
  }

  /// Unified cropper settings (same spirit as post-image cropper):
  /// - keep original ratio available
  /// - allow re-editing before upload
  Future<CroppedFile?> _cropImage(String path) {
    final isAvatar = widget.cropStyle == ProfileCropStyle.avatar;

    return ImageCropper().cropImage(
      sourcePath: path,
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: isAvatar
              ? CropAspectRatioPreset.square
              : CropAspectRatioPreset.original,
          // ✅ Requirement: profile picture must ALWAYS be square.
          lockAspectRatio: isAvatar,
          aspectRatioPresets: isAvatar
              ? const [
                  CropAspectRatioPreset.square,
                ]
              : const [
                  CropAspectRatioPreset.original,
                  CropAspectRatioPreset.ratio16x9,
                  CropAspectRatioPreset.ratio4x3,
                  CropAspectRatioPreset.ratio3x2,
                ],
        ),
        IOSUiSettings(title: 'Crop Photo'),
      ],
    );
  }

  Future<void> _upload() async {
    final file = _selectedCroppedFile;
    if (file == null || _isUploading) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await file.readAsBytes();
      final mediaId = await _profileService.uploadMedia(
        bytes: bytes,
        filename: file.path.split('/').last,
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        ProfileMediaUploadResult(
          mediaId: mediaId,
          previewUrl: 'file://${file.path}',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().replaceAll('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.isEmpty
                ? 'Upload failed / আপলোড ব্যর্থ হয়েছে'
                : '$msg / সমস্যা হয়েছে',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildPreview() {
    final file = _selectedCroppedFile;
    if (file == null) {
      return Container(
        color: const Color(0xFFF2F2F2),
        child: const Center(
          child: Text('No image selected / কোনো ছবি সিলেক্ট করা হয়নি'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final ar = _croppedAspectRatio;
        final maxW = constraints.maxWidth;

        // If we can't read dimensions, fallback to fitWidth without forcing a square.
        if (ar == null || ar <= 0) {
          return Image.file(
            file,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          );
        }

        final computedHeight = maxW / ar;

        // Real aspect ratio preview:
        // width = 100% screen, height = based on cropped dimensions
        return SingleChildScrollView(
          child: SizedBox(
            width: double.infinity,
            height: computedHeight,
            child: Image.file(
              file,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
            ),
            if (_hasImage) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _reCrop,
                      icon: const Icon(Icons.crop),
                      label: const Text('Re-crop'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildPreview(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _upload,
                child: _isUploading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Upload'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
