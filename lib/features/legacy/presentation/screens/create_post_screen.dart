import 'dart:io';

import 'package:furtail_app/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'package:furtail_app/features/posts/data/datasources/posts_remote_ds.dart';
import 'package:furtail_app/core/media/video_edit_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_compress/video_compress.dart';
import 'package:furtail_app/core/services/post_upload_manager.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_background_style.dart';

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
  String _privacy = 'PUBLIC';

  final List<File> _images = [];
  File? _video;
  int? _trimStartMs;
  int? _trimEndMs;
  bool _mute = false;
  double _volume = 1.0;
  final List<File> _files = []; // PDF/TXT/etc.
  File? _videoThumbnail;
  bool _generatingThumbnail = false;

  String? _userName;
  String? _avatarUrl;

  PostBackgroundStyle _selectedBackgroundStyle = PostBackgroundStyle.presets[0];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _captionCtrl.addListener(_onCaptionChanged);
  }

  void _onCaptionChanged() {
    setState(() {});
  }

  Future<void> _loadUser() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = sp.getString('userName') ?? 'Pet Lover';
      _avatarUrl = sp.getString('avatarUrl');
    });
  }

  IconData _getPrivacyIcon(String privacy) {
    switch (privacy) {
      case 'FOLLOWERS':
        return Icons.people_outline;
      case 'PRIVATE':
        return Icons.lock_outline;
      default:
        return Icons.public;
    }
  }

  String _getPrivacyLabel(String privacy) {
    switch (privacy) {
      case 'FOLLOWERS':
        return 'Followers Only';
      case 'PRIVATE':
        return 'Only Me';
      default:
        return 'Public';
    }
  }

  void _showAudienceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6E6E6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
               Padding(
                 padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                 child: Text(
                   'Select Audience',
                   style: AppTypography.sectionTitle(context).copyWith(fontWeight: FontWeight.bold),
                 ),
               ),
              ListTile(
                leading: const Icon(Icons.public, color: Colors.black87),
                title: Text('Public', style: AppTypography.cardTitle(context)),
                subtitle: const Text('Anyone on or off Furtail'),
                trailing: _privacy == 'PUBLIC'
                    ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  setState(() => _privacy = 'PUBLIC');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline, color: Colors.black87),
                title: Text('Followers Only', style: AppTypography.cardTitle(context)),
                subtitle: const Text('Your followers on Furtail'),
                trailing: _privacy == 'FOLLOWERS'
                    ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  setState(() => _privacy = 'FOLLOWERS');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline, color: Colors.black87),
                title: Text('Only Me', style: AppTypography.cardTitle(context)),
                subtitle: const Text('Only visible to you'),
                trailing: _privacy == 'PRIVATE'
                    ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  setState(() => _privacy = 'PRIVATE');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _captionCtrl.removeListener(_onCaptionChanged);
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final list = await _picker.pickMultiImage(imageQuality: 90);
    if (list.isEmpty) return;

    // Add all selected photos directly WITHOUT auto-cropping.
    // Each image in the grid has its own "Edit" (crop) button so the user
    // can choose which ones to crop, rather than being forced through the
    // crop screen for every photo in the selection.
    setState(() {
      _video = null;
      _files.clear();
      _type = 'IMAGE';
      _images
        ..clear()
        ..addAll(list.map((x) => File(x.path)));
    });
  }

  /// Opens the crop UI for the image at [index] in [_images].
  /// Called only when the user explicitly taps the Edit button on a thumbnail.
  Future<void> _cropSingleImage(int index) async {
    if (index < 0 || index >= _images.length) return;
    final original = _images[index];
    final cropped = await ImageCropper().cropImage(
      sourcePath: original.path,
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
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(title: 'Crop Photo'),
      ],
    );
    if (cropped == null) return; // User cancelled — keep original.
    if (!mounted) return;
    setState(() => _images[index] = File(cropped.path));
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
      _videoThumbnail = null;
      _generatingThumbnail = true;
      _trimStartMs = edited.trimStartMs;
      _trimEndMs = edited.trimEndMs;
      _mute = edited.mute;
      _volume = edited.volume;
      _type = reel ? 'REEL' : 'VIDEO';
    });

    try {
      final thumb = await VideoCompress.getFileThumbnail(edited.file.path, quality: 50);
      if (mounted) {
        setState(() {
          _videoThumbnail = thumb;
          _generatingThumbnail = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating video thumbnail: $e');
      if (mounted) {
        setState(() {
          _generatingThumbnail = false;
        });
      }
    }
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

    final caption = _captionCtrl.text.trim();
    final drafts = <PostUploadDraft>[];

    if (_type == 'IMAGE') {
      for (final f in _images) {
        drafts.add(PostUploadDraft(file: f, type: 'IMAGE'));
      }
      for (final f in _files) {
        drafts.add(PostUploadDraft(file: f, type: 'FILE'));
      }
    } else if (_type == 'VIDEO' || _type == 'REEL') {
      if (_video != null) {
        drafts.add(PostUploadDraft(file: _video, type: 'VIDEO'));
      }
    }

    final textLength = _captionCtrl.text.length;
    final isTextOnly = _type == 'TEXT' && _images.isEmpty && _video == null && _files.isEmpty;
    final isShortPost = textLength <= 160;
    final applyStyle = isTextOnly && isShortPost && _selectedBackgroundStyle.id != 'none';
    final backgroundStyleId = applyStyle ? _selectedBackgroundStyle.id : null;

    final task = PostUploadTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      caption: caption.isEmpty ? null : caption,
      drafts: drafts,
      trimStartMs: _trimStartMs,
      trimEndMs: _trimEndMs,
      mute: _mute,
      volume: _volume,
      privacy: _privacy,
      backgroundStyle: backgroundStyleId,
    );

    // Run task in background asynchronously
    PostUploadManager.instance.start(task).catchError((err) {
      debugPrint('[CreatePostScreen] background upload error: $err');
    });

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final canPost = !_submitting;
    final hasContent = _captionCtrl.text.trim().isNotEmpty || _images.isNotEmpty || _video != null || _files.isNotEmpty;

    final textLength = _captionCtrl.text.length;
    final isTextOnly = _type == 'TEXT' && _images.isEmpty && _video == null && _files.isEmpty;
    final isShortPost = textLength <= 160;
    final selectedStyle = _selectedBackgroundStyle;
    final applyStyle = isTextOnly && isShortPost && selectedStyle.id != 'none';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Post'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: (hasContent && !_submitting) ? _submit : null,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              disabledForegroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
            ),
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
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_submitting) return;
          if (!hasContent) {
            Navigator.pop(context);
            return;
          }
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Discard Post?'),
              content: const Text('Are you sure you want to discard this post?'),
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
          child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // User Avatar + Name + Compact Audience Selector
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFEFEFEF),
                        backgroundImage: (_avatarUrl ?? '').isEmpty ? null : NetworkImage(_avatarUrl!),
                        child: (_avatarUrl ?? '').isEmpty
                            ? const Icon(Icons.person, size: 22, color: Colors.black45)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName ?? 'Pet Lover',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            // Compact Audience Selector Badge
                            GestureDetector(
                              onTap: canPost ? _showAudienceSelector : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getPrivacyIcon(_privacy),
                                      size: 14,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getPrivacyLabel(_privacy),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    height: applyStyle ? 200 : null,
                    decoration: BoxDecoration(
                      color: applyStyle ? (selectedStyle.color ?? Colors.orange) : const Color(0xFFF0F2F5),
                      gradient: applyStyle ? selectedStyle.gradient : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: applyStyle ? 24 : 16,
                      vertical: applyStyle ? 24 : 12,
                    ),
                    alignment: applyStyle ? Alignment.center : Alignment.topLeft,
                    child: TextField(
                      controller: _captionCtrl,
                      maxLines: applyStyle ? 5 : null,
                      minLines: applyStyle ? 1 : 4,
                      textAlign: applyStyle ? TextAlign.center : TextAlign.start,
                      style: TextStyle(
                        fontSize: applyStyle ? 20 : 16,
                        fontWeight: applyStyle ? FontWeight.bold : FontWeight.normal,
                        color: applyStyle ? selectedStyle.textColor : Colors.black87,
                      ),
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: "What's on your mind regarding your pet?",
                        hintStyle: TextStyle(
                          color: applyStyle ? selectedStyle.textColor.withValues(alpha: 0.6) : Colors.black45,
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                  if (isTextOnly && isShortPost) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Background Style',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: PostBackgroundStyle.presets.length,
                        itemBuilder: (context, idx) {
                          final style = PostBackgroundStyle.presets[idx];
                          final isSelected = _selectedBackgroundStyle.id == style.id;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedBackgroundStyle = style;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: style.color,
                                gradient: style.gradient,
                                border: Border.all(
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                ],
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: style.textColor,
                                      size: 18,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Media preview: clean multi-media grid for photos
                  if (_images.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _images.length,
                      itemBuilder: (context, i) {
                        final f = _images[i];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(f, fit: BoxFit.cover),
                            ),
                            // ── Remove button (top-right) ─────────────────
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: _submitting
                                    ? null
                                    : () => setState(() {
                                          _images.removeAt(i);
                                          if (_images.isEmpty &&
                                              _files.isEmpty &&
                                              _video == null) {
                                            _type = 'TEXT';
                                          }
                                        }),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            // ── Edit/Crop button (bottom-left) ────────────
                            // Tap opens crop only for this one photo.
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: GestureDetector(
                                onTap: _submitting
                                    ? null
                                    : () => _cropSingleImage(i),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.crop,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
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
                              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                              color: Colors.grey.withValues(alpha: 0.06),
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
                                          if (_files.isEmpty && _images.isEmpty && _video == null) {
                                            _type = 'TEXT';
                                          }
                                        })
                                      : null,
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                  if (_video != null) ...[
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _videoThumbnail != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(_videoThumbnail!, fit: BoxFit.cover),
                                      Container(color: Colors.black26),
                                      const Center(
                                        child: Icon(
                                          Icons.play_circle_fill,
                                          size: 56,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                : _generatingThumbnail
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.play_circle_fill,
                                          size: 56,
                                          color: Colors.black54,
                                        ),
                                      ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: _submitting
                                ? null
                                : () => setState(() {
                                      _video = null;
                                      _videoThumbnail = null;
                                      _trimStartMs = null;
                                      _trimEndMs = null;
                                      if (_images.isEmpty && _files.isEmpty) {
                                        _type = 'TEXT';
                                      }
                                    }),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Actions panel pinned at the bottom
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6E6E6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add to your post',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _CompactActionButton(
                          icon: Icons.photo_library_outlined,
                          color: const Color(0xFF4CAF50),
                          label: 'Photos',
                          onTap: canPost ? _pickImages : null,
                        ),
                        _CompactActionButton(
                          icon: Icons.videocam_outlined,
                          color: const Color(0xFFE91E63),
                          label: 'Video',
                          onTap: canPost ? () => _pickVideo(reel: false) : null,
                        ),
                        _CompactActionButton(
                          icon: Icons.video_library_outlined,
                          color: const Color(0xFFFF9800),
                          label: 'Reel',
                          onTap: canPost ? () => _pickVideo(reel: true) : null,
                        ),
                        _CompactActionButton(
                          icon: Icons.attach_file_outlined,
                          color: const Color(0xFF2196F3),
                          label: 'Document',
                          onTap: canPost ? _pickFiles : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: Text(
                  'Selected type: $_type',
                  style: AppTypography.caption(context).copyWith(color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _CompactActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: disabled ? Colors.grey.shade100 : color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: disabled ? Colors.grey.shade400 : color,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.caption(context).copyWith(
                fontWeight: FontWeight.bold,
                color: disabled ? Colors.grey.shade400 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
