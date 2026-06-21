import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class PetPhotoPicker extends StatelessWidget {
  final File? file;
  final ValueChanged<File?> onChanged;
  final ValueChanged<XFile> onXFileSelected;
  final VoidCallback? onRemove;

  const PetPhotoPicker({
    super.key,
    required this.file,
    required this.onChanged,
    required this.onXFileSelected,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            width: double.infinity,
            color: Colors.black12,
            child: file == null
                ? const Center(child: Icon(Icons.pets, size: 48))
                : Image.file(file!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickAndCrop(context),
                icon: const Icon(Icons.photo_camera_back),
                label: Text(file == null ? "Add Photo" : "Change Photo"),
              ),
            ),
            if (file != null && onRemove != null) ...[
              const SizedBox(width: 12),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _pickAndCrop(BuildContext context) async {
    final source = await _chooseSource(context);
    if (source == null) return;

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    final CroppedFile? cropped = await _cropImage(context, picked.path);
    if (cropped == null) return;

    final xfile = XFile(cropped.path);
    onXFileSelected(xfile);
    onChanged(File(cropped.path));
  }

  Future<ImageSource?> _chooseSource(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Gallery"),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text("Camera"),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<CroppedFile?> _cropImage(BuildContext context, String path) async {
    return ImageCropper().cropImage(
      sourcePath: path,
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop',
          toolbarWidgetColor: Colors.white,
          toolbarColor: Colors.black,
          hideBottomControls: false,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop'),
      ],
    );
  }
}
