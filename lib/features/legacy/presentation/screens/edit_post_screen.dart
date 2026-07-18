import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:video_compress/video_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:furtail_app/core/media/image_editor_screen.dart';
import 'package:furtail_app/core/media/video_edit_screen.dart';
import 'package:furtail_app/core/media/furtail_cache_manager.dart';
import 'package:furtail_app/core/services/post_upload_manager.dart';
import 'package:furtail_app/features/pets/data/datasources/pet_remote_ds.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_background_style.dart';
import 'package:furtail_app/features/posts/data/models/feeling_activity_model.dart';
import 'package:furtail_app/features/posts/data/models/post_model.dart';
import 'package:furtail_app/features/posts/presentation/widgets/feeling_activity_picker.dart';
import 'package:furtail_app/features/posts/data/datasources/feeling_activity_remote_ds.dart';
import 'package:furtail_app/features/location/presentation/location_picker_screen.dart';

/// Professional edit post screen matching Create Post UX.
///
/// Supports editing: caption, background style, feeling, activity, location,
/// media (add/remove), and tagged pets. Sends a compact update payload with
/// separate metadata fields (never appended to caption).
class EditPostScreen extends StatefulWidget {
  final PostModel post;

  /// Optional hook for callers that want an immediate callback.
  /// The screen still pops with [PostModel] as the result.
  final ValueChanged<PostModel>? onSave;

  const EditPostScreen({super.key, required this.post, this.onSave});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

/// Unified media item — existing remote media or newly picked local file.
class _EditMediaItem {
  final UniqueKey key;
  final String type; // IMAGE / VIDEO / FILE
  final int? existingId;
  final String? existingUrl;
  final File? file;
  File? thumbnail;
  int? trimStartMs;
  int? trimEndMs;
  bool mute;
  double volume;
  String? aspectRatio;
  String? quality;
  int? coverTimestampMs;

  _EditMediaItem._({
    required this.key,
    required this.type,
    this.existingId,
    this.existingUrl,
    this.file,
    this.thumbnail,
    this.trimStartMs,
    this.trimEndMs,
    this.mute = false,
    this.volume = 1.0,
    this.aspectRatio,
    this.quality,
    this.coverTimestampMs,
  });

  factory _EditMediaItem.existing({
    required int id,
    required String url,
    required String type,
  }) =>
      _EditMediaItem._(key: UniqueKey(), type: type, existingId: id, existingUrl: url);

  factory _EditMediaItem.local({
    required File file,
    required String type,
    File? thumbnail,
    int? trimStartMs,
    int? trimEndMs,
    bool mute = false,
    double volume = 1.0,
    String? aspectRatio,
    String? quality,
    int? coverTimestampMs,
  }) =>
      _EditMediaItem._(
        key: UniqueKey(),
        file: file,
        type: type,
        thumbnail: thumbnail,
        trimStartMs: trimStartMs,
        trimEndMs: trimEndMs,
        mute: mute,
        volume: volume,
        aspectRatio: aspectRatio,
        quality: quality,
        coverTimestampMs: coverTimestampMs,
      );

  bool get isExisting => existingId != null;
  bool get isNew => file != null && existingId == null;

  static _EditMediaItem image(File file) =>
      _EditMediaItem.local(file: file, type: 'IMAGE');

  static _EditMediaItem video({
    required File file,
    File? thumbnail,
    int? trimStartMs,
    int? trimEndMs,
    bool mute = false,
    double volume = 1.0,
    String? aspectRatio,
    String? quality,
    int? coverTimestampMs,
  }) =>
      _EditMediaItem.local(
        file: file,
        type: 'VIDEO',
        thumbnail: thumbnail,
        trimStartMs: trimStartMs,
        trimEndMs: trimEndMs,
        mute: mute,
        volume: volume,
        aspectRatio: aspectRatio,
        quality: quality,
        coverTimestampMs: coverTimestampMs,
      );

  static _EditMediaItem document(File file) =>
      _EditMediaItem.local(file: file, type: 'FILE');
}

class _PetPickerItem {
  final int id;
  final String name;
  final String? photoUrl;
  const _PetPickerItem({required this.id, required this.name, this.photoUrl});
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _captionCtrl = TextEditingController();
  final _captionFocusNode = FocusNode();
  final _composerScrollController = ScrollController();
  final _composerEditorKey = GlobalKey();
  final _picker = ImagePicker();

  bool _saving = false;

  /// Original values for dirty-state detection
  late final String _originalCaption;
  late final String? _originalBackgroundStyleId;
  late final String? _originalFeelingId;
  late final String? _originalActivityId;
  late final String? _originalLocationName;
  late final List<_EditMediaItem> _mediaItems;
  int _originalMediaCount = 0;

  String? _userName;
  String? _avatarUrl;

  PostBackgroundStyle _selectedBackgroundStyle = PostBackgroundStyle.presets[0];

  // Metadata state
  String? _selectedLocationName;
  FeelingActivityItem? _selectedFeeling;
  FeelingActivityItem? _selectedActivity;

  // Tagged pet
  final List<_PetPickerItem> _petList = [];
  bool _petsLoading = false;
  int? _taggedPetId;
  String? _taggedPetName;
  String? _postType;

  @override
  void initState() {
    super.initState();
    _loadUser();

    final post = widget.post;
    _captionCtrl.text = post.caption ?? '';
    _originalCaption = post.caption ?? '';

    // Background style
    final bgId = post.backgroundStyle;
    _selectedBackgroundStyle = PostBackgroundStyle.find(bgId);
    _originalBackgroundStyleId = bgId;

    // Feeling
    if (post.feelingId != null && post.feelingLabel != null) {
      _selectedFeeling = FeelingActivityItem.byId(post.feelingId) ??
          FeelingActivityItem(
            id: post.feelingId!,
            label: post.feelingLabel ?? '',
            emoji: post.feelingEmoji ?? '',
            category: 'Feelings',
            type: 'feeling',
          );
    }
    _originalFeelingId = post.feelingId;

    // Activity
    if (post.activityId != null && post.activityLabel != null) {
      _selectedActivity = FeelingActivityItem.byId(post.activityId) ??
          FeelingActivityItem(
            id: post.activityId!,
            label: post.activityLabel ?? '',
            emoji: post.activityEmoji ?? '',
            category: 'Activities',
            type: 'activity',
          );
    }
    _originalActivityId = post.activityId;

    // Location
    _selectedLocationName = post.locationTag;
    _originalLocationName = post.locationTag;

    // Tagged pet
    final pets = post.taggedPets;
    if (pets.isNotEmpty) {
      _taggedPetId = pets.first.id;
      _taggedPetName = pets.first.name;
    }

    // Post type
    _postType = post.postType;

    // Media
    _mediaItems = post.media
        .map((m) => _EditMediaItem.existing(id: m.id, url: m.url, type: m.type))
        .toList();
    _originalMediaCount = _mediaItems.length;

    _captionCtrl.addListener(_onCaptionChanged);
    _captionFocusNode.addListener(() {
      if (_captionFocusNode.hasFocus) {
        _scrollEditorIntoView();
      }
    });
  }

  @override
  void dispose() {
    _captionCtrl.removeListener(_onCaptionChanged);
    _captionCtrl.dispose();
    _captionFocusNode.dispose();
    _composerScrollController.dispose();
    super.dispose();
  }

  // ── Dirty-state detection ──────────────────────────────────────────────

  bool get _hasUnsavedChanges {
    if (_captionCtrl.text != _originalCaption) {
      return true;
    }
    if (_selectedBackgroundStyle.id !=
        PostBackgroundStyle.find(_originalBackgroundStyleId).id) {
      return true;
    }
    if (_selectedFeeling?.id != _originalFeelingId) {
      return true;
    }
    if (_selectedActivity?.id != _originalActivityId) {
      return true;
    }
    if (_selectedLocationName != _originalLocationName) {
      return true;
    }
    if (_mediaItems.length != _originalMediaCount) {
      return true;
    }
    for (int i = 0; i < _mediaItems.length; i++) {
      final item = _mediaItems[i];
      if (item.isNew) {
        return true;
      }
      if (i < widget.post.media.length) {
        if (item.existingId != widget.post.media[i].id) {
          return true;
        }
      } else {
        return true;
      }
    }
    if (_mediaItems.length < _originalMediaCount) {
      return true;
    }
    return false;
  }

  bool get _canUpdate => _hasUnsavedChanges && !_saving;

  // ── User loading ───────────────────────────────────────────────────────

  Future<void> _loadUser() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = sp.getString('userName') ?? 'Pet Lover';
      _avatarUrl = sp.getString('avatarUrl');
    });
  }

  void _onCaptionChanged() {
    setState(() {});
  }

  void _scrollEditorIntoView() {
    final editorContext = _composerEditorKey.currentContext;
    final renderObject = editorContext?.findRenderObject();
    if (renderObject is! RenderBox) return;
    final scrollController = _composerScrollController;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted || !scrollController.hasClients) return;
      final viewport = RenderAbstractViewport.of(renderObject);
      final target = viewport.getOffsetToReveal(renderObject, 0.05).offset;
      final clamped = target.clamp(
        scrollController.position.minScrollExtent,
        scrollController.position.maxScrollExtent,
      );
      await scrollController.animateTo(
        clamped.toDouble(),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  bool get _canShowBackgroundPicker => _mediaItems.isEmpty;

  String _formatLocation(LatLng latLng) {
    final latDiff = (latLng.latitude - 23.8103).abs();
    final lngDiff = (latLng.longitude - 90.4125).abs();
    if (latDiff < 0.05 && lngDiff < 0.05) {
      return "Dhaka, Bangladesh";
    }
    return "${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
  }

  // ── Metadata pickers ──────────────────────────────────────────────────

  Future<void> _showLocationPicker() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedLocationName = _formatLocation(result);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location selected: $_selectedLocationName'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showFeelingPicker() async {
    List<FeelingActivityItem> items;
    try {
      items = await FeelingActivityRemoteDs().fetch(type: 'FEELING');
    } catch (_) {
      items =
          FeelingActivityItem.all.where((i) => i.type == 'FEELING').toList();
    }
    if (!mounted) return;

    final result = await showFeelingActivityPicker(
      context,
      title: 'How are you feeling?',
      type: 'feeling',
      items: items,
    );
    if (result != null && mounted) {
      setState(() {
        _selectedFeeling = result;
        _selectedActivity = null;
      });
    }
  }

  Future<void> _showActivityPicker() async {
    List<FeelingActivityItem> items;
    try {
      items = await FeelingActivityRemoteDs().fetch(type: 'ACTIVITY');
    } catch (_) {
      items =
          FeelingActivityItem.all.where((i) => i.type == 'ACTIVITY').toList();
    }
    if (!mounted) return;

    final result = await showFeelingActivityPicker(
      context,
      title: 'What are you doing?',
      type: 'activity',
      items: items,
    );
    if (result != null && mounted) {
      setState(() {
        _selectedActivity = result;
        _selectedFeeling = null;
      });
    }
  }

  Future<void> _showBackgroundPicker() async {
    if (!_canShowBackgroundPicker || !mounted) return;

    final selected = await showModalBottomSheet<PostBackgroundStyle>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 16),
                Text(
                  'Background',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Applies to short text-only posts.',
                  style: Theme.of(ctx)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: PostBackgroundStyle.presets.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, idx) {
                    final style = PostBackgroundStyle.presets[idx];
                    final isSelectedStyle =
                        _selectedBackgroundStyle.id == style.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(ctx, style),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BackgroundStylePreviewCircle(
                            style: style,
                            isSelected: isSelectedStyle,
                            size: 48,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            style.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelectedStyle
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelectedStyle
                                  ? colorScheme.primary
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedBackgroundStyle = selected;
      });
    }
  }

  Future<void> _showPetPicker() async {
    if (_petsLoading) return;

    if (_petList.isEmpty) {
      setState(() => _petsLoading = true);
      try {
        final petDs = PetRemoteDs();
        final rawPets = await petDs.getAllPets();
        if (!mounted) return;
        setState(() {
          _petList.addAll(
            rawPets.map(
              (p) => _PetPickerItem(
                id: (p['id'] as num).toInt(),
                name: (p['name'] ?? p['petName'] ?? 'Pet').toString(),
                photoUrl:
                    (p['photo'] is Map ? (p['photo'] as Map)['url'] : null)
                        ?.toString(),
              ),
            ),
          );
          _petsLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _petsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not load pets: ${e.toString().replaceFirst("Exception: ", "")}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (_petList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pets found. Add a pet first to tag them.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                'Tag a Pet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ..._petList.map(
              (pet) => ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFEFEFEF),
                  backgroundImage: pet.photoUrl != null
                      ? NetworkImage(pet.photoUrl!)
                      : null,
                  child: pet.photoUrl == null
                      ? const Icon(Icons.pets, size: 20, color: Colors.black45)
                      : null,
                ),
                title: Text(pet.name),
                trailing: _taggedPetId == pet.id
                    ? Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, pet.id),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        if (_taggedPetId == selected) {
          _taggedPetId = null;
          _taggedPetName = null;
        } else {
          _taggedPetId = selected;
          _taggedPetName = _petList.firstWhere((p) => p.id == selected).name;
        }
      });
    }
  }

  // ── Media pickers ─────────────────────────────────────────────────────

  static const int _maxImageBytes = 15 * 1024 * 1024;
  static const int _maxVideoBytes = 200 * 1024 * 1024;

  String _formatFileSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
  }

  Future<void> _addPhotos() async {
    if (_saving) return;
    final list = await _picker.pickMultiImage(imageQuality: 90);
    if (list.isEmpty) return;

    setState(() {
      for (final x in list) {
        _mediaItems.add(_EditMediaItem.image(File(x.path)));
      }
    });

    if (list.length == 1) {
      final newIndex = _mediaItems.length - 1;
      await _editImageAtIndex(newIndex);
    }
  }

  Future<void> _addVideo({bool reel = false}) async {
    if (_saving) return;
    final x = await _picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    if (!mounted) return;

    final edited = await Navigator.of(context).push<VideoEditResult>(
      MaterialPageRoute(builder: (_) => VideoEditScreen(file: File(x.path))),
    );
    if (edited == null) return;

    setState(() {
      _mediaItems.add(
        _EditMediaItem.video(
          file: edited.file,
          trimStartMs: edited.trimStartMs,
          trimEndMs: edited.trimEndMs,
          mute: edited.mute,
          volume: edited.volume,
          aspectRatio: edited.aspectRatio,
          quality: edited.quality,
          coverTimestampMs: edited.coverTimestampMs,
        ),
      );
    });

    try {
      final thumb = edited.coverTimestampMs != null
          ? await VideoCompress.getFileThumbnail(
              edited.file.path,
              quality: 60,
              position: edited.coverTimestampMs!,
            )
          : await VideoCompress.getFileThumbnail(edited.file.path, quality: 50);
      if (!mounted) return;
      final idx = _mediaItems.indexWhere((m) => m.key == _mediaItems.last.key);
      if (idx >= 0) {
        setState(() => _mediaItems[idx].thumbnail = thumb);
      }
    } catch (e) {
      debugPrint('Error generating video thumbnail: $e');
    }
  }

  Future<void> _addFiles() async {
    if (_saving) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt'],
    );
    final paths = result?.paths.whereType<String>().toList() ?? const [];
    if (paths.isEmpty) return;

    setState(() {
      _mediaItems.addAll(paths.map((p) => _EditMediaItem.document(File(p))));
    });
  }

  Future<void> _editImageAtIndex(int index) async {
    if (index < 0 || index >= _mediaItems.length) return;
    final item = _mediaItems[index];
    if (item.type != 'IMAGE') return;

    final imageItemIndexes = <int>[];
    final imageFiles = <File>[];
    for (int i = 0; i < _mediaItems.length; i++) {
      if (_mediaItems[i].type == 'IMAGE' && _mediaItems[i].isNew) {
        imageItemIndexes.add(i);
        imageFiles.add(_mediaItems[i].file!);
      }
    }
    final imageIndex = imageItemIndexes.indexOf(index);
    if (imageIndex < 0) return;

    final edited = await Navigator.of(context).push<ImageEditResult>(
      MaterialPageRoute(
        builder: (_) =>
            ImageEditorScreen(files: imageFiles, initialIndex: imageIndex),
      ),
    );
    if (edited == null) return;
    if (!mounted) return;
    setState(() {
      for (int i = 0;
          i < imageItemIndexes.length && i < edited.files.length;
          i++) {
        _mediaItems[imageItemIndexes[i]] =
            _EditMediaItem.image(edited.files[i]);
      }
    });
  }

  void _removeMedia(int index) {
    if (index < 0 || index >= _mediaItems.length) return;
    setState(() {
      _mediaItems.removeAt(index);
    });
  }

  // ── Save / Update ─────────────────────────────────────────────────────

  Future<void> _update() async {
    if (_saving) return;
    if (!_hasUnsavedChanges) return;

    setState(() => _saving = true);

    try {
      final caption = _captionCtrl.text.trim();

      // ── Build drafts: include ALL media items ─────────────────────────
      // PostUploadManager._run() builds the final mediaIds list from
      // task.drafts. Existing items must carry their existingId so they
      // are PRESERVED. New items carry a File so they get UPLOADED.
      final drafts = <PostUploadDraft>[];
      int existingCount = 0;
      int newCount = 0;
      for (final item in _mediaItems) {
        if (item.existingId != null) {
          drafts.add(PostUploadDraft(
            existingId: item.existingId,
            type: item.type,
          ));
          existingCount++;
          debugPrint(
            '[EditPostScreen] draft[${drafts.length - 1}] '
            'KEEP existing media id=${item.existingId} type=${item.type}',
          );
        } else if (item.isNew && item.file != null) {
          final fileExists = await item.file!.exists();
          final fileSize = await item.file!.length();
          drafts.add(PostUploadDraft(
            file: item.file,
            type: item.type,
          ));
          newCount++;
          debugPrint(
            '[EditPostScreen] draft[${drafts.length - 1}] '
            'ADD new media file="${item.file!.path}" '
            'exists=$fileExists '
            'size=$fileSize '
            'type=${item.type}',
          );
        }
      }
      debugPrint(
        '[EditPostScreen] Total drafts=$existingCount existing + $newCount new = ${drafts.length}',
      );

      // Validate media sizes
      for (final draft in drafts) {
        if (draft.file == null) continue;
        final size = await draft.file!.length();
        final maxBytes =
            draft.type == 'VIDEO' ? _maxVideoBytes : _maxImageBytes;
        if (size > maxBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${draft.type == 'VIDEO' ? 'Video' : 'Image'} is ${_formatFileSize(size)}. '
                'Maximum allowed size is ${_formatFileSize(maxBytes)}.',
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
          setState(() => _saving = false);
          return;
        }
      }

      // Determine background style
      final textLength = _captionCtrl.text.length;
      final isTextOnly = _mediaItems.isEmpty;
      final isShortPost = textLength <= 160;
      final applyStyle =
          isTextOnly && isShortPost && _selectedBackgroundStyle.id != 'none';
      final backgroundStyleId = applyStyle ? _selectedBackgroundStyle.id : null;

      // Gather tagged pet IDs
      final taggedPetIds = <int>[];
      if (_taggedPetId != null) taggedPetIds.add(_taggedPetId!);

      final task = PostUploadTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: widget.post.type,
        caption: caption.isEmpty ? null : caption,
        drafts: drafts,
        editPostId: widget.post.id,
        backgroundStyle: backgroundStyleId,
        postType: _postType,
        taggedPetIds: taggedPetIds,
        locationText: _selectedLocationName,
        feelingId: _selectedFeeling?.id,
        feelingLabel: _selectedFeeling?.label,
        feelingEmoji: _selectedFeeling?.emoji,
        activityId: _selectedActivity?.id,
        activityLabel: _selectedActivity?.label,
        activityEmoji: _selectedActivity?.emoji,
      );

      // ── Run the upload task and WAIT for completion ───────────────
      debugPrint('[EditPostScreen] Calling PostUploadManager.start()...');
      debugPrint(
        '[EditPostScreen] Task details: '
        'editPostId=${task.editPostId} '
        'drafts=${task.drafts.length} '
        'existingIds=[${task.drafts.where((d) => d.existingId != null).map((d) => d.existingId).join(',')}] '
        'newFiles=[${task.drafts.where((d) => d.file != null).length}]',
      );
      await PostUploadManager.instance.start(task);
      debugPrint('[EditPostScreen] PostUploadManager.start() completed');

      if (!mounted) return;

      // ── Check result ──────────────────────────────────────────────
      final uploadState = PostUploadManager.instance.state.value;
      debugPrint(
        '[EditPostScreen] Upload result: '
        'status=${uploadState.status} '
        'error=${uploadState.error}',
      );
      if (uploadState.status == PostUploadStatus.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uploadState.error ?? 'Update failed'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _saving = false);
        return;
      }

      // Build optimistic post for return
      final optimisticPost = widget.post.copyWith(
        caption: caption,
        backgroundStyle: backgroundStyleId,
        feelingId: _selectedFeeling?.id,
        feelingLabel: _selectedFeeling?.label,
        feelingEmoji: _selectedFeeling?.emoji,
        activityId: _selectedActivity?.id,
        activityLabel: _selectedActivity?.label,
        activityEmoji: _selectedActivity?.emoji,
        locationTag: _selectedLocationName,
        taggedPetIds: taggedPetIds,
      );

      widget.onSave?.call(optimisticPost);
      if (mounted) Navigator.pop(context, optimisticPost);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Update failed: ${e.toString().replaceFirst("Exception: ", "")}',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _saving = false);
    }
  }

  // ── Build: Header compact chip ────────────────────────────────────────

  Widget _buildCompactChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    VoidCallback? onRemove,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 3),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close, size: 10, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final textLength = _captionCtrl.text.length;
    final isTextOnly = _mediaItems.isEmpty;
    final isShortPost = textLength <= 160;
    final selectedStyle = _selectedBackgroundStyle;
    final applyStyle =
        isTextOnly && isShortPost && selectedStyle.id != 'none';

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Edit Post',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0.5,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.black87,
            size: 24,
          ),
          onPressed: _onBack,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: FilledButton(
              onPressed: _canUpdate ? _update : null,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                disabledBackgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade500,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                minimumSize: const Size(72, 40),
                maximumSize: const Size(120, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Update'),
            ),
          ),
        ],
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
              title: const Text('Discard Changes?'),
              content: const Text(
                'Are you sure you want to discard your changes?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Continue Editing'),
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _composerScrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── User header with compact metadata chips ──────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFEFEFEF),
                          backgroundImage: (_avatarUrl ?? '').isEmpty
                              ? null
                              : NetworkImage(_avatarUrl!),
                          child: (_avatarUrl ?? '').isEmpty
                              ? const Icon(Icons.person,
                                  size: 22, color: Colors.black45)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName ?? 'Pet Lover',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              // Compact metadata chips row
                              Wrap(
                                spacing: 5,
                                runSpacing: 5,
                                children: [
                                  // Feeling chip
                                  if (_selectedFeeling != null)
                                    _buildCompactChip(
                                      icon:
                                          Icons.sentiment_satisfied_alt_outlined,
                                      label: _selectedFeeling!.chipLabel,
                                      color: Colors.purple.shade700,
                                      backgroundColor: Colors.purple.shade50,
                                      onRemove: () => setState(
                                          () => _selectedFeeling = null),
                                    ),
                                  // Activity chip
                                  if (_selectedActivity != null)
                                    _buildCompactChip(
                                      icon: Icons.emoji_events_outlined,
                                      label: _selectedActivity!.chipLabel,
                                      color: Colors.orange.shade700,
                                      backgroundColor: Colors.orange.shade50,
                                      onRemove: () => setState(
                                          () => _selectedActivity = null),
                                    ),
                                  // Location chip
                                  if (_selectedLocationName != null)
                                    _buildCompactChip(
                                      icon: Icons.location_on_outlined,
                                      label: _selectedLocationName!,
                                      color: Colors.red.shade700,
                                      backgroundColor: Colors.red.shade50,
                                      onRemove: () => setState(
                                          () => _selectedLocationName = null),
                                    ),
                                  // Tagged pet chip
                                  if (_taggedPetName != null)
                                    _buildCompactChip(
                                      icon: Icons.pets_rounded,
                                      label: _taggedPetName!,
                                      color: Colors.orange.shade700,
                                      backgroundColor: Colors.orange.shade50,
                                      onRemove: () => setState(() {
                                        _taggedPetId = null;
                                        _taggedPetName = null;
                                      }),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Caption editor with background style ────────────
                    KeyedSubtree(
                      key: _composerEditorKey,
                      child: applyStyle
                          ? Container(
                              constraints:
                                  const BoxConstraints(minHeight: 180),
                              width: double.infinity,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selectedStyle.color ?? Colors.orange,
                                gradient: selectedStyle.gradient,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 32,
                              ),
                              child: Stack(
                                children: [
                                  if (selectedStyle.type ==
                                          BackgroundStyleType.pattern &&
                                      selectedStyle.patternBuilder != null)
                                    Positioned.fill(
                                      child: RepaintBoundary(
                                        child: CustomPaint(
                                          painter:
                                              selectedStyle.patternBuilder!(),
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                    ),
                                  TextField(
                                    focusNode: _captionFocusNode,
                                    controller: _captionCtrl,
                                    maxLines: null,
                                    minLines: 1,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: selectedStyle.textColor,
                                    ),
                                    keyboardType: TextInputType.multiline,
                                    cursorColor: selectedStyle.textColor,
                                    decoration: InputDecoration(
                                      hintText:
                                          "What's on your mind regarding your pet?",
                                      hintStyle: TextStyle(
                                        color: selectedStyle.textColor
                                            .withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      filled: false,
                                      isCollapsed: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : TextField(
                              focusNode: _captionFocusNode,
                              controller: _captionCtrl,
                              maxLines: null,
                              minLines: 5,
                              textAlign: TextAlign.start,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                              keyboardType: TextInputType.multiline,
                              decoration: const InputDecoration(
                                hintText:
                                    "What's on your mind regarding your pet?",
                                hintStyle: TextStyle(color: Colors.black54),
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                filled: false,
                                isCollapsed: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                    ),

                    // ── Media preview section ──────────────────────────
                    if (_mediaItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildMediaPreview(),
                    ],
                  ],
                ),
              ),
            ),

            // ── Bottom Add-to-post panel ────────────────────────────────
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  // ── Media preview ────────────────────────────────────────────────────

  Widget _buildMediaPreview() {
    return _buildFacebookGrid();
  }

  Widget _buildFacebookGrid() {
    final items = _mediaItems;
    final count = items.length;
    if (count == 0) return const SizedBox.shrink();

    return Column(
      children: [
        if (count == 1)
          _buildSinglePreview(items[0], 0)
        else if (count == 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildGridCell(items[0], 0)),
                const SizedBox(width: 4),
                Expanded(child: _buildGridCell(items[1], 1)),
              ],
            ),
          )
        else if (count == 3)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: _buildGridCell(items[0], 0)),
                const SizedBox(width: 4),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(child: _buildGridCell(items[1], 1)),
                      const SizedBox(height: 4),
                      Expanded(child: _buildGridCell(items[2], 2)),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildGridCell(items[0], 0)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildGridCell(items[1], 1)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: _buildGridCell(items[2], 2)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildGridCellWithOverlay(items, 3)),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSinglePreview(_EditMediaItem item, int index) {
    if (item.type == 'VIDEO') {
      return SizedBox(
        width: double.infinity,
        child: _buildVideoCell(item, index),
      );
    }
    if (item.type == 'FILE') {
      return _buildFileCell(item, index);
    }

    // IMAGE
    Widget img;
    if (item.existingUrl != null) {
      img = CachedNetworkImage(
        imageUrl: item.existingUrl!,
        cacheManager: FurtailImageCacheManager(),
        fit: BoxFit.contain,
        width: double.infinity,
      );
    } else if (item.file != null) {
      img = Image.file(item.file!, fit: BoxFit.contain, width: double.infinity);
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            img,
            Positioned(
              top: 8,
              right: 8,
              child: _MediaIconButton(
                icon: Icons.close,
                onTap: _saving ? null : () => _removeMedia(index),
              ),
            ),
            if (item.isNew && item.file != null)
              Positioned(
                top: 8,
                right: 44,
                child: _MediaIconButton(
                  icon: Icons.crop,
                  onTap: _saving ? null : () => _editImageAtIndex(index),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCell(_EditMediaItem item, int index) {
    if (item.type == 'VIDEO') return _buildVideoCell(item, index);
    if (item.type == 'FILE') return _buildFileCell(item, index);

    // IMAGE grid cell
    Widget img;
    if (item.existingUrl != null) {
      img = CachedNetworkImage(
        imageUrl: item.existingUrl!,
        cacheManager: FurtailImageCacheManager(),
        fit: BoxFit.cover,
      );
    } else if (item.file != null) {
      img = Image.file(item.file!, fit: BoxFit.cover);
    } else {
      return const SizedBox.shrink();
    }

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            img,
            Positioned(
              top: 4,
              right: 4,
              child: _MediaIconButton(
                icon: Icons.close,
                size: 16,
                padding: 4,
                onTap: _saving ? null : () => _removeMedia(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCell(_EditMediaItem item, int index) {
    Widget? thumbnail;
    if (item.thumbnail != null) {
      thumbnail = Image.file(item.thumbnail!, fit: BoxFit.cover);
    } else if (item.existingUrl != null) {
      thumbnail = CachedNetworkImage(
        imageUrl: item.existingUrl!,
        cacheManager: FurtailImageCacheManager(),
        fit: BoxFit.cover,
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            thumbnail ?? Container(color: Colors.black12),
            Container(color: Colors.black.withValues(alpha: 0.20)),
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                size: 48,
                color: Colors.white,
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: _MediaIconButton(
                icon: Icons.close,
                size: 14,
                padding: 4,
                onTap: _saving ? null : () => _removeMedia(index),
              ),
            ),
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'VIDEO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCell(_EditMediaItem item, int index) {
    final name = item.file != null
        ? item.file!.path.split('/').last
        : (item.existingUrl ?? 'FILE').split('/').last;
    final ext = name.contains('.')
        ? name.split('.').last.toUpperCase()
        : 'FILE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        color: Colors.grey.withValues(alpha: 0.06),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 16,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '$ext file',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!_saving)
            GestureDetector(
              onTap: () => _removeMedia(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridCellWithOverlay(List<_EditMediaItem> items, int index) {
    final remaining = items.length - 4;
    final item = items[index];

    Widget? thumbnail;
    if (item.type == 'VIDEO') {
      if (item.thumbnail != null) {
        thumbnail = Image.file(item.thumbnail!, fit: BoxFit.cover);
      } else if (item.existingUrl != null) {
        thumbnail = CachedNetworkImage(
          imageUrl: item.existingUrl!,
          cacheManager: FurtailImageCacheManager(),
          fit: BoxFit.cover,
        );
      }
    } else if (item.file != null) {
      thumbnail = Image.file(item.file!, fit: BoxFit.cover);
    } else if (item.existingUrl != null) {
      thumbnail = CachedNetworkImage(
        imageUrl: item.existingUrl!,
        cacheManager: FurtailImageCacheManager(),
        fit: BoxFit.cover,
      );
    }

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.type == 'VIDEO')
              Stack(
                fit: StackFit.expand,
                children: [
                  thumbnail ?? Container(color: Colors.black12),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            else
              thumbnail ?? Container(color: Colors.grey.shade200),
            if (remaining > 0)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                alignment: Alignment.center,
                child: Text(
                  '+$remaining',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: _MediaIconButton(
                icon: Icons.close,
                size: 14,
                padding: 3,
                onTap: _saving ? null : () => _removeMedia(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom panel ─────────────────────────────────────────────────────

  Widget _buildBottomPanel() {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    final row1 = [
      _ActionChip(
        icon: Icons.photo_library_outlined,
        color: const Color(0xFF4CAF50),
        label: 'Photos',
        onTap: _saving ? null : _addPhotos,
      ),
      _ActionChip(
        icon: Icons.videocam_outlined,
        color: const Color(0xFFE91E63),
        label: 'Video',
        onTap: _saving ? null : () => _addVideo(reel: false),
      ),
      _ActionChip(
        icon: Icons.video_library_outlined,
        color: const Color(0xFFFF9800),
        label: 'Reel',
        onTap: _saving ? null : () => _addVideo(reel: true),
      ),
      _ActionChip(
        icon: Icons.attach_file_outlined,
        color: const Color(0xFF2196F3),
        label: 'Document',
        onTap: _saving ? null : _addFiles,
      ),
    ];

    final row2 = [
      _ActionChip(
        icon: Icons.location_on_outlined,
        color: const Color(0xFFF44336),
        label: 'Location',
        onTap: _saving ? null : _showLocationPicker,
      ),
      _ActionChip(
        icon: Icons.sentiment_satisfied_alt_outlined,
        color: const Color(0xFFFFC107),
        label: 'Feeling',
        onTap: _saving ? null : _showFeelingPicker,
      ),
      _ActionChip(
        icon: Icons.emoji_events_outlined,
        color: const Color(0xFFE91E63),
        label: 'Activity',
        onTap: _saving ? null : _showActivityPicker,
      ),
      _ActionChip(
        icon: Icons.pets_rounded,
        color: const Color(0xFFFF9800),
        label: 'Pet',
        onTap: _saving ? null : _showPetPicker,
      ),
      _ActionChip(
        icon: Icons.palette_outlined,
        color: const Color(0xFF9C27B0),
        label: 'Background',
        onTap: _saving ? null : _showBackgroundPicker,
      ),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: safeBottom),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add to your post',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: row1),
                      const SizedBox(height: 6),
                      Row(children: row2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Back handler ─────────────────────────────────────────────────────

  Future<void> _onBack() async {
    if (_saving) return;
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'Are you sure you want to discard your changes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continue Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context);
    }
  }
}

// ── Shared media overlay icon button ────────────────────────────────────

class _MediaIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final double padding;
  final VoidCallback? onTap;

  const _MediaIconButton({
    required this.icon,
    this.size = 16,
    this.padding = 6,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size, color: Colors.white),
      ),
    );
  }
}

// ── Compact action chip for "Add to your post" panel ────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: disabled
                ? Colors.grey.shade100
                : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: disabled
                  ? Colors.grey.shade200
                  : color.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: disabled ? Colors.grey.shade400 : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: disabled ? Colors.grey.shade400 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
