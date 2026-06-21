import 'dart:io';

import 'package:furtail_app/core/media/video_trim_screen.dart';
import 'package:furtail_app/core/utils/app_snackbar.dart';
import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// Edit post:
/// - Update caption
/// - Keep/remove/reorder existing attachments
/// - Add new photos/videos/files
/// - Edit (crop) images and (trim) videos (both existing and new)
class EditPostScreen extends StatefulWidget {
  final PostModel post;

  /// Optional hook for callers that want an immediate callback with the updated post.
  /// The screen still pops with `PostModel?` as the result.
  final ValueChanged<PostModel>? onSave;

  const EditPostScreen({super.key, required this.post, this.onSave});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _captionCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _ds = PostsRemoteDs();

  bool _saving = false;
  bool _processingMedia = false;

  late final List<_AttachmentDraft> _drafts;

  bool get _busy => _saving || _processingMedia;

  @override
  void initState() {
    super.initState();
    _captionCtrl.text = widget.post.caption ?? '';
    _drafts = (widget.post.media)
        .map(
          (m) => _AttachmentDraft.existing(id: m.id, url: m.url, type: m.type),
        )
        .toList();
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final caption = _captionCtrl.text.trim();

      final mediaIds = <int>[];
      for (final d in _drafts) {
        if (d.existingId != null) {
          mediaIds.add(d.existingId!);
          continue;
        }
        if (d.file == null) continue;
        final id = await _ds.uploadMedia(d.file!);
        mediaIds.add(id);
      }

      final updated = await _ds.updatePost(
        postId: widget.post.id,
        caption: caption,
        mediaIds: mediaIds,
      );

      if (!mounted) return;
      widget.onSave?.call(updated);
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // -----------------------
  // Add media
  // -----------------------

  Future<void> _addPhotos() async {
    if (_busy) return;
    final picked = await _picker.pickMultiImage(imageQuality: 92);
    if (picked.isEmpty) return;
    setState(() {
      for (final x in picked) {
        _drafts.add(_AttachmentDraft.local(file: File(x.path), type: 'IMAGE'));
      }
    });
  }

  Future<void> _addVideo() async {
    if (_busy) return;
    final x = await _picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;

    // Optional trim right away (nice UX)
    if (!mounted) return;
    final trimmed = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => VideoTrimScreen(file: File(x.path))),
    );

    if (!mounted) return;
    setState(() {
      _drafts.add(
        _AttachmentDraft.local(file: trimmed ?? File(x.path), type: 'VIDEO'),
      );
    });
  }

  Future<void> _addFiles() async {
    if (_busy) return;
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt'],
    );
    if (res == null || res.files.isEmpty) return;
    setState(() {
      for (final f in res.files) {
        if (f.path == null) continue;
        _drafts.add(_AttachmentDraft.local(file: File(f.path!), type: 'FILE'));
      }
    });
  }

  // -----------------------
  // Edit / remove / reorder
  // -----------------------

  Future<void> _editImage(int index) async {
    if (_busy) return;
    final d = _drafts[index];
    setState(() => _processingMedia = true);
    try {
      final file = d.file ?? await _downloadToTemp(d.existingUrl!);
      final cropped = await _cropImage(file.path);
      if (cropped == null) return;

      if (!mounted) return;
      setState(() {
        _drafts[index] = _AttachmentDraft.local(file: cropped, type: 'IMAGE');
      });
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _processingMedia = false);
    }
  }

  Future<void> _editVideo(int index) async {
    if (_busy) return;
    final d = _drafts[index];
    setState(() => _processingMedia = true);
    try {
      final file = d.file ?? await _downloadToTemp(d.existingUrl!);
      if (!mounted) return;
      final trimmed = await Navigator.push<File?>(
        context,
        MaterialPageRoute(builder: (_) => VideoTrimScreen(file: file)),
      );
      if (trimmed == null || !mounted) return;

      setState(() {
        _drafts[index] = _AttachmentDraft.local(file: trimmed, type: 'VIDEO');
      });
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _processingMedia = false);
    }
  }

  void _removeAt(int index) {
    if (_busy) return;
    setState(() => _drafts.removeAt(index));
  }

  // -----------------------
  // Helpers
  // -----------------------

  Future<File> _downloadToTemp(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Download failed (${res.statusCode})');
    }
    final dir = await Directory.systemTemp.createTemp('bpa_edit_');
    final ext = p.extension(Uri.parse(url).path);
    final f = File(p.join(dir.path, 'media${ext.isNotEmpty ? ext : ''}'));
    await f.writeAsBytes(res.bodyBytes);
    return f;
  }

  Future<File?> _cropImage(String path) async {
    final out = await ImageCropper().cropImage(
      sourcePath: path,
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Edit Image',
          toolbarWidgetColor: Colors.white,
          toolbarColor: Colors.black,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Edit Image'),
      ],
    );
    if (out == null) return null;
    return File(out.path);
  }

  Widget _fullWidthMedia({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 1, // nice feed-style full width
        child: child,
      ),
    );
  }

  Widget _iconPill({required IconData icon, required VoidCallback? onTap}) {
    return Material(
      color: Colors.black.withOpacity(0.55),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? Colors.white30 : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(int index) {
    final d = _drafts[index];
    final t = d.type.toUpperCase();
    final isVideo = t == 'VIDEO';
    final isFile = t == 'FILE';

    if (!isVideo && !isFile) {
      // IMAGE
      final img = d.file != null
          ? Image.file(d.file!, fit: BoxFit.cover)
          : CachedNetworkImage(imageUrl: d.existingUrl!, fit: BoxFit.cover);

      return Padding(
        key: ValueKey(d.key),
        padding: const EdgeInsets.only(bottom: 10),
        child: Stack(
          children: [
            _fullWidthMedia(child: img),
            Positioned(
              right: 8,
              top: 8,
              child: Row(
                children: [
                  _iconPill(
                    icon: Icons.crop,
                    onTap: _busy ? null : () => _editImage(index),
                  ),
                  const SizedBox(width: 8),
                  _iconPill(
                    icon: Icons.delete_outline,
                    onTap: _busy ? null : () => _removeAt(index),
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 8,
              top: 8,
              child: Icon(Icons.drag_handle, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (isVideo) {
      return Padding(
        key: ValueKey(d.key),
        padding: const EdgeInsets.only(bottom: 10),
        child: Stack(
          children: [
            _fullWidthMedia(
              child: Container(
                color: Colors.black12,
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 64,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Row(
                children: [
                  _iconPill(
                    icon: Icons.content_cut,
                    onTap: _busy ? null : () => _editVideo(index),
                  ),
                  const SizedBox(width: 8),
                  _iconPill(
                    icon: Icons.delete_outline,
                    onTap: _busy ? null : () => _removeAt(index),
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 8,
              top: 8,
              child: Icon(Icons.drag_handle, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    // FILE
    return Container(
      key: ValueKey(d.key),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        color: Colors.grey.withOpacity(0.06),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              d.file != null
                  ? p.basename(d.file!.path)
                  : 'FILE #${d.existingId ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.drag_handle, size: 18, color: Colors.black45),
          IconButton(
            onPressed: _busy ? null : () => _removeAt(index),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _captionCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Update your post...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              if (_drafts.isNotEmpty) ...[
                const Text(
                  'Attachments (drag to reorder)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _drafts.removeAt(oldIndex);
                      _drafts.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (int i = 0; i < _drafts.length; i++)
                      _buildAttachmentItem(i),
                  ],
                ),
                const SizedBox(height: 6),
              ],

              const Divider(height: 24),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _pillButton(
                    label: 'Add Photos',
                    icon: Icons.photo_library_outlined,
                    onTap: _busy ? null : _addPhotos,
                  ),
                  _pillButton(
                    label: 'Add Video',
                    icon: Icons.videocam_outlined,
                    onTap: _busy ? null : _addVideo,
                  ),
                  _pillButton(
                    label: 'Add PDF/TXT',
                    icon: Icons.picture_as_pdf_outlined,
                    onTap: _busy ? null : _addFiles,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),

          if (_processingMedia)
            Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black.withOpacity(0.12)),
          color: Colors.white,
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

class _AttachmentDraft {
  final int? existingId;
  final String? existingUrl;
  final File? file;
  final String type;
  final String _key;

  _AttachmentDraft._({
    required this.existingId,
    required this.existingUrl,
    required this.file,
    required this.type,
    required String key,
  }) : _key = key;

  factory _AttachmentDraft.existing({
    required int id,
    required String url,
    required String type,
  }) => _AttachmentDraft._(
    existingId: id,
    existingUrl: url,
    file: null,
    type: type,
    key: 'ex_$id',
  );

  factory _AttachmentDraft.local({required File file, required String type}) =>
      _AttachmentDraft._(
        existingId: null,
        existingUrl: null,
        file: file,
        type: type,
        key: 'lo_${DateTime.now().microsecondsSinceEpoch}',
      );

  String get key => _key;
}
