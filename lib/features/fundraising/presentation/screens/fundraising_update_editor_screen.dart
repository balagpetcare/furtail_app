import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import '../../data/models/fundraising_models.dart';
import '../providers/fundraising_providers.dart';

class FundraisingUpdateEditorScreen extends ConsumerStatefulWidget {
  final int campaignId;
  final FundraisingUpdateItem? existing; // null => create
  const FundraisingUpdateEditorScreen({super.key, required this.campaignId, this.existing});

  @override
  ConsumerState<FundraisingUpdateEditorScreen> createState() =>
      _FundraisingUpdateEditorScreenState();
}

class _FundraisingUpdateEditorScreenState
    extends ConsumerState<FundraisingUpdateEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionCtrl = TextEditingController();

  final _picker = ImagePicker();
  final _postsDs = PostsRemoteDs();

  final List<File> _images = [];
  File? _video;
  final List<File> _files = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _captionCtrl.text = widget.existing?.caption?.toString() ?? '';
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<List<File>> _cropImagesOneByOne(List<XFile> picked) async {
    final out = <File>[];
    for (final x in picked) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: x.path,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop Photo'),
        ],
      );
      out.add(File(cropped?.path ?? x.path));
    }
    return out;
  }

  Future<void> _pickImages() async {
    final list = await _picker.pickMultiImage(imageQuality: 100);
    if (list.isEmpty) return;
    final cropped = await _cropImagesOneByOne(list);
    if (cropped.isEmpty) return;
    setState(() {
      _video = null;
      _files.clear();
      _images
        ..clear()
        ..addAll(cropped);
    });
  }

  Future<void> _pickVideo() async {
    final x = await _picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    setState(() {
      _images.clear();
      _files.clear();
      _video = File(x.path);
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt'],
    );
    final paths = result?.paths.whereType<String>().toList() ?? const [];
    if (paths.isEmpty) return;
    setState(() {
      _images.clear();
      _video = null;
      _files
        ..clear()
        ..addAll(paths.map((p) => File(p)));
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(fundraisingRepositoryProvider);

      final mediaIds = <int>[];
      for (final f in _images) {
        mediaIds.add(await _postsDs.uploadMedia(f));
      }
      if (_video != null) {
        mediaIds.add(await _postsDs.uploadMedia(_video!));
      }
      for (final f in _files) {
        mediaIds.add(await _postsDs.uploadMedia(f));
      }

      if (widget.existing == null) {
        await repo.createUpdate(
          campaignId: widget.campaignId,
          caption: _captionCtrl.text.trim(),
          mediaIds: mediaIds,
        );
      } else {
        await repo.updateUpdate(
          updateId: widget.existing!.id,
          caption: _captionCtrl.text.trim(),
          mediaIds: mediaIds.isEmpty ? null : mediaIds,
        );
      }

      ref.invalidate(fundraisingUpdatesProvider(widget.campaignId));
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.existing == null ? 'Update posted' : 'Update updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Update' : 'New Update'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _captionCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Update text',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                final hasExistingMedia = (widget.existing?.media.isNotEmpty ?? false);
                if (t.isEmpty && _images.isEmpty && _video == null && _files.isEmpty && !hasExistingMedia) {
                  return 'Add text or attach something';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo),
                  label: const Text('Photo'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Video'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('PDF/TXT'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_images.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _images
                    .map(
                      (f) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(f, width: 90, height: 90, fit: BoxFit.cover),
                      ),
                    )
                    .toList(),
              ),
            if (_video != null) ...[
              const SizedBox(height: 6),
              Text('Video selected: ${_video!.path.split('/').last}'),
            ],
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 6),
              ..._files.map((f) => Text('File: ${f.path.split('/').last}')),
            ],
            if (isEdit && widget.existing!.media.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Existing attachments (kept unless you add new ones)',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.existing!.media
                    .map((m) => ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(m.url, width: 90, height: 90, fit: BoxFit.cover),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
