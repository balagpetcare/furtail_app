import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/pet_service.dart';

/// Edit pet profile photo (gallery pick + square crop + upload + update profilePicId)
/// UI text must be English.
class PetEditPhotoScreen extends StatefulWidget {
  final int petId;
  final String? currentPhotoUrl;

  const PetEditPhotoScreen({super.key, required this.petId, this.currentPhotoUrl});

  @override
  State<PetEditPhotoScreen> createState() => _PetEditPhotoScreenState();
}

class _PetEditPhotoScreenState extends State<PetEditPhotoScreen> {
  final _picker = ImagePicker();
  final _svc = PetService();

  File? _file;
  bool _saving = false;

  Future<void> _pick() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (x == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: x.path,
      compressQuality: 92,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
        IOSUiSettings(title: 'Crop Photo', aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null) return;

    setState(() => _file = File(cropped.path));
  }

  Future<void> _save() async {
    if (_file == null || _saving) return;
    setState(() => _saving = true);
    try {
      final mediaId = await _svc.uploadMedia(_file!);
      await _svc.updatePet(widget.petId, {"profilePicId": mediaId});
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _hasUnsavedChanges => _file != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Pet Photo'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_saving) return;
          if (!_hasUnsavedChanges) {
            Navigator.pop(context);
            return;
          }
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Discard Photo?'),
              content: const Text('Are you sure you want to discard the selected photo?'),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          children: [
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _preview(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _preview() {
    if (_file != null) {
      return Image.file(_file!, fit: BoxFit.cover, width: double.infinity);
    }
    final u = (widget.currentPhotoUrl ?? '').trim();
    if (u.isNotEmpty) {
      return Image.network(u, fit: BoxFit.cover, width: double.infinity);
    }
    return Container(
      color: const Color(0xFFF2F2F2),
      child: const Center(child: Text('No image selected')),
    );
  }
}
