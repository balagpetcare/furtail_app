import 'dart:io';

import 'package:bpa_app/core/theme/typography.dart';
import 'package:bpa_app/core/analytics/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'package:bpa_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:bpa_app/core/utils/app_snackbar.dart';
import 'package:bpa_app/core/media/video_edit_screen.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _ds = PostsRemoteDs();

  bool _submitting = false;
  String _type = 'TEXT'; // TEXT / IMAGE / VIDEO / REEL

  final List<File> _images = [];
  File? _video;
  int? _trimStartMs;
  int? _trimEndMs;
  bool _mute = false;
  double _volume = 1.0;
  final List<File> _files = []; // PDF/TXT/etc.

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    // v6 premium: keep good preview, but reduce upload size early.
    final list = await _picker.pickMultiImage(imageQuality: 85);
    if (list.isEmpty) return;

    // Crop one by one, keep EXACT preview.
    final cropped = await _cropImagesOneByOne(list);
    if (cropped.isEmpty) return;

    setState(() {
      _video = null;
      _files.clear();
      _type = 'IMAGE';
      _images
        ..clear()
        ..addAll(cropped);
    });
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
            aspectRatioPresets: const [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2, // Use 3x2 or 4x3 instead of 4x5
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(title: 'Crop Photo'),
        ],
      );
      // If user cancels crop, keep original.
      out.add(File((cropped?.path ?? x.path)));
    }
    return out;
  }

  Future<void> _pickVideo({bool reel = false}) async {
    final x = await _picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    final edited = await Navigator.of(context).push<VideoEditResult>(
      MaterialPageRoute(builder: (_) => VideoEditScreen(file: File(x.path))),
    );
    if (edited == null) return;
    setState(() {
      _images.clear();
      _files.clear();
      _video = edited.file;
      _trimStartMs = edited.trimStartMs;
      _trimEndMs = edited.trimEndMs;
      _mute = edited.mute;
      _volume = edited.volume;
      _type = reel ? 'REEL' : 'VIDEO';
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
      _type = 'IMAGE'; // treat as media post (attachments)
      _files
        ..clear()
        ..addAll(paths.map((p) => File(p)));
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final caption = _captionCtrl.text.trim();

      final List<int> mediaIds = [];
      if (_type == 'IMAGE') {
        for (final f in _images) {
          final id = await _ds.uploadMedia(f);
          mediaIds.add(id);
        }
        for (final f in _files) {
          final id = await _ds.uploadMedia(f);
          mediaIds.add(id);
        }
      } else if (_type == 'VIDEO' || _type == 'REEL') {
        if (_video != null) {
          final id = await _ds.uploadMedia(
            _video!,
            trimStartMs: _trimStartMs,
            trimEndMs: _trimEndMs,
            mute: _mute,
            volume: _volume,
          );
          mediaIds.add(id);
        }
      }

      final created = await _ds.createPost(
        type: _type,
        caption: caption.isEmpty ? null : caption,
        mediaIds: mediaIds,
      );
      await AnalyticsService.instance.logPostCreated(
        postType: _type,
        postId: created.id,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPost = !_submitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Post'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: canPost ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Post',
                    style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _captionCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: "What's on your mind regarding your pet?",
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 12),

          // Media preview (full-width like feed)
          if (_images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 240,
                width: double.infinity,
                child: PageView.builder(
                  itemCount: _images.length,
                  itemBuilder: (_, i) {
                    final f = _images[i];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(f, fit: BoxFit.cover),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.35),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _submitting
                                ? null
                                : () => setState(() => _images.removeAt(i)),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ),
                        if (_images.length > 1)
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${i + 1}/${_images.length}',
                                style: context.appText.labelMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._files
                .take(6)
                .map(
                  (f) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.08)),
                      color: Colors.grey.withOpacity(0.06),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_file,
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f.path.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.appText.bodyMedium!,
                          ),
                        ),
                        IconButton(
                          onPressed: canPost
                              ? () => setState(() {
                                  _files.remove(f);
                                  if (_files.isEmpty && _images.isEmpty)
                                    _type = 'TEXT';
                                })
                              : null,
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          if (_video != null)
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 56,
                  color: Colors.black54,
                ),
              ),
            ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Actions
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionChip(
                icon: Icons.photo,
                label: 'Add Photos',
                onTap: canPost ? _pickImages : null,
              ),
              _ActionChip(
                icon: Icons.videocam,
                label: 'Add Video',
                onTap: canPost ? () => _pickVideo(reel: false) : null,
              ),
              _ActionChip(
                icon: Icons.video_library,
                label: 'Add Reel',
                onTap: canPost ? () => _pickVideo(reel: true) : null,
              ),
              _ActionChip(
                icon: Icons.text_fields,
                label: 'Text Only',
                onTap: canPost
                    ? () {
                        setState(() {
                          _type = 'TEXT';
                          _images.clear();
                          _files.clear();
                          _video = null;
                        });
                      }
                    : null,
              ),
              _ActionChip(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Add PDF/TXT',
                onTap: canPost ? _pickFiles : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Selected type: $_type',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: onTap == null ? Colors.black26 : Colors.black54,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.black26 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
