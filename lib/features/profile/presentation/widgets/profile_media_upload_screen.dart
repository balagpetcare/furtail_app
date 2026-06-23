import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:furtail_app/core/theme/typography.dart';
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

/// Gallery/camera pick + crop + upload (used by cover + avatar buttons).
/// Returns [ProfileMediaUploadResult] so caller can instantly update UI.
class ProfileMediaUploadScreen extends StatefulWidget {
  final String title;
  final ProfileCropStyle cropStyle;
  /// When set, auto-opens the picker for this source on screen open.
  final ImageSource? initialSource;

  const ProfileMediaUploadScreen({
    super.key,
    required this.title,
    required this.cropStyle,
    this.initialSource,
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

  @override
  void initState() {
    super.initState();
    if (widget.initialSource != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickFromSource(widget.initialSource!);
      });
    }
  }

  Future<void> _pickFromSource(ImageSource source) async {
    if (source == ImageSource.camera) {
      await _pickFromCamera();
    } else {
      await _pickFromGallery();
    }
  }

  Future<void> _pickFromCamera() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    if (picked == null) return;

    _originalPickedPath = picked.path;
    final cropped = await _cropImage(picked.path);
    if (cropped == null) return;
    await _setCroppedFile(File(cropped.path));
  }

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

  Widget _buildUploadPlaceholder() {
    final isAvatar = widget.cropStyle == ProfileCropStyle.avatar;
    return GestureDetector(
      onTap: _isUploading ? null : _pickFromGallery,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAvatar
                    ? Icons.account_circle_outlined
                    : Icons.image_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isAvatar ? 'Select profile photo' : 'Select cover photo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                isAvatar
                    ? 'Choose a photo from your gallery. It will be cropped to a square.'
                    : 'Choose a wide image for your cover header. You can crop it before uploading.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final file = _selectedCroppedFile;
    if (file == null) {
      return Container(
        color: const Color(0xFFF2F2F2),
        child: const Center(
          child: Text('No image selected'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final ar = _croppedAspectRatio;
        final maxW = constraints.maxWidth;

        if (ar == null || ar <= 0) {
          return Image.file(
            file,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          );
        }

        final computedHeight = maxW / ar;

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_hasImage) ...[
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE6E6E6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _buildPreview(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploading ? null : _reCrop,
                        icon: const Icon(Icons.crop_outlined),
                        label: const Text('Adjust Crop'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Theme.of(context).colorScheme.primary),
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploading ? null : _reset,
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('Remove'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _upload,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text('Upload & Apply', style: AppTypography.menuTitle(context).copyWith(fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else ...[
                Expanded(child: _buildUploadPlaceholder()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
