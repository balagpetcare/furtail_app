import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';

import 'package:furtail_app/core/media/image_editor_screen.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/core/media/video_edit_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_compress/video_compress.dart';
import 'package:furtail_app/core/services/post_upload_manager.dart';
import 'package:furtail_app/features/pets/data/datasources/pet_remote_ds.dart';
import 'package:furtail_app/features/posts/presentation/widgets/post_background_style.dart';
import 'package:furtail_app/features/posts/data/models/feeling_activity_model.dart';
import 'package:furtail_app/features/posts/presentation/widgets/feeling_activity_picker.dart';
import 'package:furtail_app/features/posts/data/datasources/feeling_activity_remote_ds.dart';
import 'package:furtail_app/features/location/presentation/location_picker_screen.dart';

class CreatePostScreen extends StatefulWidget {
  /// If set to 'VIDEO' or 'REEL', the screen auto-opens the video/reel picker
  /// on load so the user goes straight into recording/selecting.
  final String? autoMediaType;

  const CreatePostScreen({super.key, this.autoMediaType});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

// â”€â”€ Unified media item model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// TODO: Support mixing IMAGE + VIDEO items in the same post. Currently the
//       backend task accepts only one type (IMAGE/VIDEO/REEL/TEXT).  Once the
//       backend supports mixed-media posts, merge the type logic below.
class _MediaItem {
  final UniqueKey key;
  final File file;
  final String type; // IMAGE / VIDEO / FILE
  File? thumbnail;
  int? trimStartMs;
  int? trimEndMs;
  bool mute;
  double volume;
  String? aspectRatio; // metadata only
  String? quality; // local only
  int? coverTimestampMs;

  _MediaItem({
    required this.key,
    required this.file,
    required this.type,
    this.thumbnail,
    this.trimStartMs,
    this.trimEndMs,
    this.mute = false,
    this.volume = 1.0,
    this.aspectRatio,
    this.quality,
    this.coverTimestampMs,
  });

  static _MediaItem image(File file) =>
      _MediaItem(key: UniqueKey(), file: file, type: 'IMAGE');

  static _MediaItem video({
    required File file,
    File? thumbnail,
    int? trimStartMs,
    int? trimEndMs,
    bool mute = false,
    double volume = 1.0,
    String? aspectRatio,
    String? quality,
    int? coverTimestampMs,
  }) => _MediaItem(
    key: UniqueKey(),
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

  static _MediaItem document(File file) =>
      _MediaItem(key: UniqueKey(), file: file, type: 'FILE');
}

class SystemAudioItem {
  final String id;
  final String title;
  final String source;
  final Duration duration;
  final IconData icon;

  const SystemAudioItem({
    required this.id,
    required this.title,
    required this.source,
    required this.duration,
    this.icon = Icons.play_circle_outline,
  });

  String get durationLabel {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

// â”€â”€ Pet-focused post type â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

enum _PostType {
  general('General Post', Icons.article_outlined),
  healthUpdate('Health Update', Icons.favorite_outline),
  vaccination('Vaccination', Icons.vaccines_outlined),
  lostPet('Lost Pet Alert', Icons.report_problem_rounded),
  adoption('Adoption', Icons.pets_rounded),
  serviceReview('Service Review', Icons.star_outline);

  final String label;
  final IconData icon;
  const _PostType(this.label, this.icon);
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionCtrl = TextEditingController();
  final _captionFocusNode = FocusNode();
  final _composerScrollController = ScrollController();
  final _composerEditorKey = GlobalKey();
  final _picker = ImagePicker();

  bool _submitting = false;
  bool _autoPickerTriggered = false;
  String _type = 'TEXT'; // TEXT / IMAGE / VIDEO / REEL
  String _privacy = 'PUBLIC';

  /// Unified list of selected media items.
  /// Images and videos are mutually exclusive per the current backend contract.
  /// Files may be mixed with images.
  final List<_MediaItem> _mediaItems = [];

  String? _userName;
  String? _avatarUrl;

  PostBackgroundStyle _selectedBackgroundStyle = PostBackgroundStyle.presets[0];

  // â”€â”€ Pet-focused post type â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  _PostType _postType = _PostType.general;

  // Tag Pet â€” loaded from PetRemoteDs.getAllPets()
  final List<_PetPickerItem> _petList = [];
  bool _petsLoading = false;

  // Tagged pet (placeholder â€” pet list not yet implemented)
  int? _taggedPetId;
  String? _taggedPetName;

  // Lost pet alert extra fields (shown only when _postType == lostPet)
  final _lostPetLocationCtrl = TextEditingController();
  bool _lostPetContactVisible = false;
  String? _lostPetName;

  // UI-only Location and Feeling/Activity selections
  String? _selectedLocationName;
  FeelingActivityItem? _selectedFeeling;
  FeelingActivityItem? _selectedActivity;
  SystemAudioItem? _selectedAudio;
  bool _slideshowEnabled = false;

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

  String _formatLocation(LatLng latLng) {
    final latDiff = (latLng.latitude - 23.8103).abs();
    final lngDiff = (latLng.longitude - 90.4125).abs();
    if (latDiff < 0.05 && lngDiff < 0.05) {
      return "Dhaka, Bangladesh";
    }
    return "${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
  }

  Future<void> _showLocationPicker() async {
    final LatLng? result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedLocationName = _formatLocation(result);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location selected: $_selectedLocationName'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showFeelingPicker() async {
    // Fetch from API, fall back to hardcoded list
    List<FeelingActivityItem> items;
    try {
      items = await FeelingActivityRemoteDs().fetch(type: 'FEELING');
    } catch (_) {
      items = FeelingActivityItem.all
          .where((i) => i.type == 'FEELING')
          .toList();
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
      items = FeelingActivityItem.all
          .where((i) => i.type == 'ACTIVITY')
          .toList();
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

  static const List<SystemAudioItem> _systemAudioItems = [
    SystemAudioItem(
      id: 'trending-1',
      title: 'Happy Tails',
      source: 'Trending Sounds',
      duration: Duration(seconds: 18),
      icon: Icons.trending_up_rounded,
    ),
    SystemAudioItem(
      id: 'pet-funny-1',
      title: 'Silly Likes',
      source: 'Pet Funny',
      duration: Duration(seconds: 24),
      icon: Icons.pets_rounded,
    ),
    SystemAudioItem(
      id: 'mood-1',
      title: 'Soft Smile',
      source: 'Happy Mood',
      duration: Duration(seconds: 21),
      icon: Icons.emoji_emotions_outlined,
    ),
    SystemAudioItem(
      id: 'calm-1',
      title: 'Morning Breeze',
      source: 'Calm Music',
      duration: Duration(seconds: 30),
      icon: Icons.spa_outlined,
    ),
    SystemAudioItem(
      id: 'birthday-1',
      title: 'Birthday Wishes',
      source: 'Birthday',
      duration: Duration(seconds: 17),
      icon: Icons.cake_outlined,
    ),
    SystemAudioItem(
      id: 'clinic-1',
      title: 'Health Update',
      source: 'Clinic Awareness',
      duration: Duration(seconds: 28),
      icon: Icons.health_and_safety_outlined,
    ),
  ];

  Future<void> _showMusicPicker() async {
    final selected = await showModalBottomSheet<SystemAudioItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6E6E6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select Sound',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose a system audio option for your post.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _systemAudioItems.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _systemAudioItems[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(
                              item.icon,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item.source} • ${item.durationLabel}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.play_circle_outline),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, item),
                                child: const Text('Select'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() => _selectedAudio = selected);
  }

  bool get _canShowBackgroundPicker => _type == 'TEXT' && _mediaItems.isEmpty;

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
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Applies to short text-only posts.',
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
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

  Widget _buildHeaderChip({
    required IconData icon,
    required String label,
    required bool hasDropdown,
    required VoidCallback? onTap,
    required Color color,
    required Color backgroundColor,
    VoidCallback? onRemove,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (hasDropdown) ...[
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down, size: 14, color: color),
            ],
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close, size: 12, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // â”€â”€ Draft storage (text + metadata only; media not persisted) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const String _draftKey = 'draft_post_v1';

  Future<void> _saveDraft() async {
    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty && _mediaItems.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    final data = {
      'caption': caption,
      'type': _type,
      'privacy': _privacy,
      'backgroundStyleId': _selectedBackgroundStyle.id,
      'postType': _postType.name,
      'taggedPetId': _taggedPetId,
      'taggedPetName': _taggedPetName,
      'lostPetName': _lostPetName,
      'lostPetLocation': _lostPetLocationCtrl.text,
      'lostPetContactVisible': _lostPetContactVisible,
      'feelingId': _selectedFeeling?.id,
      'feelingLabel': _selectedFeeling?.label,
      'feelingEmoji': _selectedFeeling?.emoji,
      'activityId': _selectedActivity?.id,
      'activityLabel': _selectedActivity?.label,
      'activityEmoji': _selectedActivity?.emoji,
      'locationText': _selectedLocationName,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await sp.setString(_draftKey, jsonEncode(data));
  }

  Future<void> _clearDraft() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_draftKey);
  }

  Future<Map<String, dynamic>?> _loadDraft() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return decoded.cast<String, dynamic>();
    } catch (_) {
      await sp.remove(_draftKey);
      return null;
    }
  }

  int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  String? _parseNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  // â”€â”€ File size limits (must match PostUploadManager) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static const int _maxImageBytes = 15 * 1024 * 1024; // 15 MB
  static const int _maxVideoBytes = 200 * 1024 * 1024; // 200 MB

  @override
  void initState() {
    super.initState();
    _loadUser();
    _captionCtrl.addListener(_onCaptionChanged);
    _captionFocusNode.addListener(() {
      if (_captionFocusNode.hasFocus) {
        _scrollEditorIntoView();
      }
    });
    // Check for saved draft on next frame so the UI is ready for dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkForDraft();
    });
    // Auto-trigger media picker if caller specified autoMediaType
    if (widget.autoMediaType == 'VIDEO' || widget.autoMediaType == 'REEL') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoPickerTriggered) return;
        _autoPickerTriggered = true;
        _pickVideo(reel: widget.autoMediaType == 'REEL');
      });
    }
  }

  Future<void> _checkForDraft() async {
    if (!mounted) return;
    final draft = await _loadDraft();
    if (draft == null || !mounted) return;
    final caption = (draft['caption'] ?? '').toString();
    if (caption.isEmpty) return;

    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Draft?'),
        content: Text(
          'You have a saved draft from earlier:\n\n'
          '"${caption.length > 80 ? '${caption.substring(0, 80)}â€¦' : caption}"\n\n'
          'Would you like to restore it?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearDraft();
              Navigator.pop(ctx, false);
            },
            child: const Text('Start New'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Draft'),
          ),
        ],
      ),
    );

    if (restore == true && mounted) {
      setState(() {
        _captionCtrl.text = caption;
        _type = _parseNullableString(draft['type']) ?? 'TEXT';
        _privacy = _parseNullableString(draft['privacy']) ?? 'PUBLIC';
        final styleId =
            _parseNullableString(draft['backgroundStyleId']) ?? 'none';
        final found = PostBackgroundStyle.presets.where((s) => s.id == styleId);
        if (found.isNotEmpty) _selectedBackgroundStyle = found.first;
        final ptName = _parseNullableString(draft['postType']) ?? '';
        if (ptName.isNotEmpty) {
          final pt = _PostType.values.where((t) => t.name == ptName);
          if (pt.isNotEmpty) _postType = pt.first;
        }
        _taggedPetId = _parseNullableInt(draft['taggedPetId']);
        _taggedPetName = _parseNullableString(draft['taggedPetName']);
        _lostPetName = _parseNullableString(draft['lostPetName']);
        _lostPetLocationCtrl.text =
            _parseNullableString(draft['lostPetLocation']) ?? '';
        _lostPetContactVisible =
            draft['lostPetContactVisible'] == true ||
            draft['lostPetContactVisible'] == 'true';
        final feelingId = _parseNullableString(draft['feelingId']);
        if (feelingId != null)
          _selectedFeeling = FeelingActivityItem.byId(feelingId);
        if (_selectedFeeling == null) {
          final feelingLabel = _parseNullableString(draft['feelingLabel']);
          final feelingEmoji = _parseNullableString(draft['feelingEmoji']);
          if (feelingLabel != null && feelingEmoji != null) {
            _selectedFeeling = FeelingActivityItem(
              id: feelingId ?? feelingLabel.toLowerCase(),
              label: feelingLabel,
              emoji: feelingEmoji,
              category: 'Feelings',
              type: 'feeling',
            );
          }
        }
        final activityId = _parseNullableString(draft['activityId']);
        if (activityId != null)
          _selectedActivity = FeelingActivityItem.byId(activityId);
        if (_selectedActivity == null) {
          final activityLabel = _parseNullableString(draft['activityLabel']);
          final activityEmoji = _parseNullableString(draft['activityEmoji']);
          if (activityLabel != null && activityEmoji != null) {
            _selectedActivity = FeelingActivityItem(
              id: activityId ?? activityLabel.toLowerCase(),
              label: activityLabel,
              emoji: activityEmoji,
              category: 'Activities',
              type: 'activity',
            );
          }
        }
        _selectedLocationName = _parseNullableString(draft['locationText']);
      });
    }
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

  void _showPostTypeSelector() {
    showModalBottomSheet<_PostType>(
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
                'Post Type',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ..._PostType.values.map(
              (t) => ListTile(
                leading: Icon(
                  t.icon,
                  color: t == _postType
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black54,
                ),
                title: Text(t.label),
                trailing: t == _postType
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(ctx, t),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((selected) {
      if (selected != null && mounted) {
        setState(() => _postType = selected);
      }
    });
  }

  Future<void> _showPetPicker() async {
    if (_petsLoading) return;

    // Load pets if not already loaded
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

    // Show pet picker bottom sheet
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
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
          // Toggle off
          _taggedPetId = null;
          _taggedPetName = null;
        } else {
          _taggedPetId = selected;
          _taggedPetName = _petList.firstWhere((p) => p.id == selected).name;
        }
      });
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
                  style: AppTypography.sectionTitle(
                    context,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.public, color: Colors.black87),
                title: Text('Public', style: AppTypography.cardTitle(context)),
                subtitle: const Text('Anyone on or off Furtail'),
                trailing: _privacy == 'PUBLIC'
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  setState(() => _privacy = 'PUBLIC');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.people_outline,
                  color: Colors.black87,
                ),
                title: Text(
                  'Followers Only',
                  style: AppTypography.cardTitle(context),
                ),
                subtitle: const Text('Your followers on Furtail'),
                trailing: _privacy == 'FOLLOWERS'
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
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
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
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
    _captionFocusNode.dispose();
    _composerScrollController.dispose();
    _lostPetLocationCtrl.dispose();
    super.dispose();
  }

  // â”€â”€ Human-readable file size â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _formatFileSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
  }

  // â”€â”€ Validation helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  /// Returns null if valid, or an error message string if invalid.
  Future<String?> _validateMediaItem(_MediaItem item) async {
    try {
      final size = await item.file.length();
      if (item.type == 'IMAGE' && size > _maxImageBytes) {
        return 'Image "${item.file.path.split('/').last}" is ${_formatFileSize(size)}. '
            'Maximum allowed size is 15 MB.';
      }
      if (item.type == 'VIDEO' && size > _maxVideoBytes) {
        return 'Video "${item.file.path.split('/').last}" is ${_formatFileSize(size)}. '
            'Maximum allowed size is 200 MB.';
      }
      // Files: allow up to image limit for now
      if (item.type == 'FILE' && size > _maxImageBytes) {
        return 'File "${item.file.path.split('/').last}" is ${_formatFileSize(size)}. '
            'Maximum allowed size is 15 MB.';
      }
    } catch (e) {
      return 'Could not read file size for "${item.file.path.split('/').last}".';
    }
    return null;
  }

  /// Validates all media items. Returns first error, or null if all pass.
  Future<String?> _validateAllMedia() async {
    for (final item in _mediaItems) {
      final err = await _validateMediaItem(item);
      if (err != null) return err;
    }
    return null;
  }

  // â”€â”€ Media pickers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _pickImages() async {
    final list = await _picker.pickMultiImage(imageQuality: 90);
    if (list.isEmpty) return;

    final pickedItems = list
        .map((x) => _MediaItem.image(File(x.path)))
        .toList();

    setState(() {
      _mediaItems
        ..clear()
        ..addAll(pickedItems);
      _type = 'IMAGE';
      _slideshowEnabled = pickedItems.length > 1 ? _slideshowEnabled : false;
      _selectedBackgroundStyle = PostBackgroundStyle.presets[0]; // reset bg
    });

    if (pickedItems.length == 1) {
      await _editImageAtIndex(0);
    }
  }

  /// Opens the crop UI for the media item at [index].
  Future<void> _editImageAtIndex(int index) async {
    if (index < 0 || index >= _mediaItems.length) return;
    final item = _mediaItems[index];
    if (item.type != 'IMAGE') return;

    final imageItemIndexes = <int>[];
    final imageFiles = <File>[];
    for (int i = 0; i < _mediaItems.length; i++) {
      if (_mediaItems[i].type == 'IMAGE') {
        imageItemIndexes.add(i);
        imageFiles.add(_mediaItems[i].file);
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
      for (
        int i = 0;
        i < imageItemIndexes.length && i < edited.files.length;
        i++
      ) {
        _mediaItems[imageItemIndexes[i]] = _MediaItem.image(edited.files[i]);
      }
    });
  }

  Future<void> _pickVideo({bool reel = false}) async {
    final x = await _picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    if (!mounted) return;
    final edited = await Navigator.of(context).push<VideoEditResult>(
      MaterialPageRoute(builder: (_) => VideoEditScreen(file: File(x.path))),
    );
    if (edited == null) return;

    setState(() {
      _mediaItems
        ..clear()
        ..add(
          _MediaItem.video(
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
      _type = reel ? 'REEL' : 'VIDEO';
      _slideshowEnabled = false;
      _selectedBackgroundStyle = PostBackgroundStyle.presets[0]; // reset bg
    });

    // Generate thumbnail in background
    try {
      // Use editor-selected cover frame if available, otherwise auto-generate
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

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt'],
    );
    final paths = result?.paths.whereType<String>().toList() ?? const [];
    if (paths.isEmpty) return;

    setState(() {
      _mediaItems
        ..clear()
        ..addAll(paths.map((p) => _MediaItem.document(File(p))));
      _type = 'IMAGE'; // treat as media post (attachments)
      _slideshowEnabled = false;
      _selectedBackgroundStyle = PostBackgroundStyle.presets[0]; // reset bg
    });
  }

  // â”€â”€ Submit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _submit() async {
    if (_submitting) return;

    // Validate media sizes before submitting
    final validationError = await _validateAllMedia();
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final caption = _captionCtrl.text.trim();
    final drafts = <PostUploadDraft>[];

    for (final item in _mediaItems) {
      drafts.add(PostUploadDraft(file: item.file, type: item.type));
    }

    // Extract video metadata from the first VIDEO item (backend supports one video)
    final videoItems = _mediaItems.where((m) => m.type == 'VIDEO').toList();
    final firstVideo = videoItems.isNotEmpty ? videoItems.first : null;

    final textLength = _captionCtrl.text.length;
    final isTextOnly = _type == 'TEXT' && _mediaItems.isEmpty;
    final isShortPost = textLength <= 160;
    final applyStyle =
        isTextOnly && isShortPost && _selectedBackgroundStyle.id != 'none';
    final backgroundStyleId = applyStyle ? _selectedBackgroundStyle.id : null;

    // Map Flutter post type to backend enum
    String? backendPostType;
    switch (_postType) {
      case _PostType.general:
        backendPostType = 'GENERAL';
        break;
      case _PostType.healthUpdate:
        backendPostType = 'HEALTH_UPDATE';
        break;
      case _PostType.vaccination:
        backendPostType = 'VACCINATION';
        break;
      case _PostType.lostPet:
        backendPostType = 'LOST_PET';
        break;
      case _PostType.adoption:
        backendPostType = 'ADOPTION';
        break;
      case _PostType.serviceReview:
        backendPostType = 'SERVICE_REVIEW';
        break;
    }

    // Gather tagged pet IDs
    final taggedPetIds = <int>[];
    if (_taggedPetId != null) taggedPetIds.add(_taggedPetId!);

    final task = PostUploadTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      caption: caption.isEmpty ? null : caption,
      drafts: drafts,
      trimStartMs: firstVideo?.trimStartMs,
      trimEndMs: firstVideo?.trimEndMs,
      mute: firstVideo?.mute,
      volume: firstVideo?.volume,
      privacy: _privacy,
      backgroundStyle: backgroundStyleId,
      postType: backendPostType,
      lostPetName: _postType == _PostType.lostPet ? _lostPetName : null,
      lostPetLocation: _postType == _PostType.lostPet
          ? _lostPetLocationCtrl.text.trim()
          : null,
      lostPetContactVisible: _postType == _PostType.lostPet
          ? _lostPetContactVisible
          : false,
      taggedPetIds: taggedPetIds,
      locationText: _selectedLocationName,
      feelingId: _selectedFeeling?.id,
      feelingLabel: _selectedFeeling?.label,
      feelingEmoji: _selectedFeeling?.emoji,
      activityId: _selectedActivity?.id,
      activityLabel: _selectedActivity?.label,
      activityEmoji: _selectedActivity?.emoji,
      coverTimestampMs: firstVideo?.coverTimestampMs,
      aspectRatio: firstVideo?.aspectRatio,
      quality: firstVideo?.quality,
    );

    // Run task in background asynchronously
    PostUploadManager.instance.start(task).catchError((err) {
      debugPrint('[CreatePostScreen] background upload error: $err');
    });

    // Clear draft after successful post submission
    await _clearDraft();

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final canPost = !_submitting;
    final hasText = _captionCtrl.text.trim().isNotEmpty;
    final hasMedia = _mediaItems.isNotEmpty;
    final hasBackgroundContent =
        _type == 'TEXT' && _selectedBackgroundStyle.id != 'none';
    final hasContent = hasText || hasMedia || hasBackgroundContent;

    final textLength = _captionCtrl.text.length;
    final isTextOnly = _type == 'TEXT' && _mediaItems.isEmpty;
    final isShortPost = textLength <= 160;
    final selectedStyle = _selectedBackgroundStyle;
    final applyStyle = isTextOnly && isShortPost && selectedStyle.id != 'none';

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'New post',
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
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: FilledButton(
              onPressed: (hasContent && !_submitting) ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                disabledBackgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade500,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                minimumSize: const Size(64, 40),
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
              child: _submitting
                  ? SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: hasContent
                            ? Colors.white
                            : Colors.grey.shade400,
                      ),
                    )
                  : const Text('Post'),
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
          // 3-way dialog: Save Draft / Discard / Continue Editing
          final action = await showDialog<_BackAction>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Unsaved Changes'),
              content: const Text(
                'You have unsaved content. What would you like to do?',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, _BackAction.continueEditing),
                  child: const Text('Continue Editing'),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx, _BackAction.saveDraft),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save Draft & Exit'),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx, _BackAction.discard),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Discard'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          );
          if (action == _BackAction.saveDraft && context.mounted) {
            await _saveDraft();
            if (context.mounted) Navigator.pop(context);
          } else if (action == _BackAction.discard && context.mounted) {
            await _clearDraft();
            if (context.mounted) Navigator.pop(context);
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
                    // Facebook-style User Header with Wrap of Chips
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFEFEFEF),
                          backgroundImage: (_avatarUrl ?? '').isEmpty
                              ? null
                              : NetworkImage(_avatarUrl!),
                          child: (_avatarUrl ?? '').isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 24,
                                  color: Colors.black45,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName ?? 'Pet Lover',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  // Privacy Chip
                                  _buildHeaderChip(
                                    icon: _getPrivacyIcon(_privacy),
                                    label: _getPrivacyLabel(_privacy),
                                    hasDropdown: true,
                                    onTap: canPost
                                        ? _showAudienceSelector
                                        : null,
                                    color: Colors.grey.shade600,
                                    backgroundColor: Colors.grey.shade100,
                                  ),
                                  // Post Type Chip
                                  _buildHeaderChip(
                                    icon: _postType.icon,
                                    label: _postType.label,
                                    hasDropdown: true,
                                    onTap: canPost
                                        ? _showPostTypeSelector
                                        : null,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.08),
                                  ),
                                  // Tag Pet Chip
                                  _buildHeaderChip(
                                    icon: Icons.pets_rounded,
                                    label: _taggedPetName ?? 'Tag Pet',
                                    hasDropdown: false,
                                    onTap: canPost ? _showPetPicker : null,
                                    color: Colors.orange.shade700,
                                    backgroundColor: Colors.orange.shade50,
                                  ),
                                  // Location Chip
                                  if (_selectedLocationName != null)
                                    _buildHeaderChip(
                                      icon: Icons.location_on_outlined,
                                      label: _selectedLocationName!,
                                      hasDropdown: false,
                                      onTap: null,
                                      color: Colors.red.shade700,
                                      backgroundColor: Colors.red.shade50,
                                      onRemove: () {
                                        setState(() {
                                          _selectedLocationName = null;
                                        });
                                      },
                                    ),
                                  // Feeling Chip
                                  if (_selectedFeeling != null)
                                    _buildHeaderChip(
                                      icon: Icons
                                          .sentiment_satisfied_alt_outlined,
                                      label: _selectedFeeling!.chipLabel,
                                      hasDropdown: false,
                                      onTap: null,
                                      color: Colors.purple.shade700,
                                      backgroundColor: Colors.purple.shade50,
                                      onRemove: () {
                                        setState(() {
                                          _selectedFeeling = null;
                                        });
                                      },
                                    ),
                                  // Activity Chip
                                  if (_selectedActivity != null)
                                    _buildHeaderChip(
                                      icon: Icons.emoji_events_outlined,
                                      label: _selectedActivity!.chipLabel,
                                      hasDropdown: false,
                                      onTap: null,
                                      color: Colors.orange.shade700,
                                      backgroundColor: Colors.orange.shade50,
                                      onRemove: () {
                                        setState(() {
                                          _selectedActivity = null;
                                        });
                                      },
                                    ),
                                  if (_selectedAudio != null)
                                    _buildHeaderChip(
                                      icon: Icons.music_note_rounded,
                                      label:
                                          '${_selectedAudio!.title} • ${_selectedAudio!.source}',
                                      hasDropdown: false,
                                      onTap: canPost ? _showMusicPicker : null,
                                      color: Colors.indigo.shade700,
                                      backgroundColor: Colors.indigo.shade50,
                                      onRemove: () {
                                        setState(() {
                                          _selectedAudio = null;
                                        });
                                      },
                                    ),
                                  if (_mediaItems
                                          .where((item) => item.type == 'IMAGE')
                                          .length >
                                      1)
                                    _buildHeaderChip(
                                      icon: Icons.slideshow_rounded,
                                      label: _slideshowEnabled
                                          ? 'Slideshow On'
                                          : 'Slideshow Off',
                                      hasDropdown: false,
                                      onTap: canPost
                                          ? () => setState(
                                              () => _slideshowEnabled =
                                                  !_slideshowEnabled,
                                            )
                                          : null,
                                      color: Colors.teal.shade700,
                                      backgroundColor: Colors.teal.shade50,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // â”€â”€ Lost Pet Alert extra fields â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    if (_postType == _PostType.lostPet) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.report_problem_rounded,
                                  size: 16,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Lost Pet Details',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Pet name (optional)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 14),
                              onChanged: (v) => _lostPetName = v,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _lostPetLocationCtrl,
                              decoration: InputDecoration(
                                hintText: 'Last seen location',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 14),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Checkbox(
                                  value: _lostPetContactVisible,
                                  onChanged: (v) => setState(
                                    () => _lostPetContactVisible = v ?? false,
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                Expanded(
                                  child: Text(
                                    'Show my contact info',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Caption text field â€” dynamic height, unified with media
                    KeyedSubtree(
                      key: _composerEditorKey,
                      child: applyStyle
                          // Styled text-only post: gradient/color/pattern background, centered
                          ? Container(
                              constraints: const BoxConstraints(minHeight: 180),
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
                                  // Pattern overlay (only for pattern type)
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
                                  // Text field
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
                          : // Non-styled: clean, transparent, large area
                            TextField(
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
                              decoration: InputDecoration(
                                hintText:
                                    "What's on your mind regarding your pet?",
                                hintStyle: const TextStyle(
                                  color: Colors.black54,
                                ),
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                filled: false,
                                isCollapsed: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                    ),
                    // â”€â”€ Background Style Selector (text-only short posts) â”€â”€

                    // â”€â”€ Media preview section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    if (_mediaItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildMediaPreview(),
                    ],
                  ],
                ),
              ),
            ),

            // Actions panel pinned at the bottom, stays above keyboard
            _buildBottomPanel(canPost),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool canPost) {
    // resizeToAvoidBottomInset:true already shifts the Scaffold body up by the
    // keyboard height, so we must NOT add keyboardInset here again — that would
    // double-count it and cause the "BOTTOM OVERFLOWED" error.
    // We only need the device's safe area bottom padding (home indicator bar).
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    // Row 1: Photos, Video, Reel, Document
    final row1 = <_ActionChip>[
      _ActionChip(
        icon: Icons.photo_library_outlined,
        color: const Color(0xFF4CAF50),
        label: 'Photos',
        onTap: canPost ? _pickImages : null,
      ),
      _ActionChip(
        icon: Icons.videocam_outlined,
        color: const Color(0xFFE91E63),
        label: 'Video',
        onTap: canPost ? () => _pickVideo(reel: false) : null,
      ),
      _ActionChip(
        icon: Icons.video_library_outlined,
        color: const Color(0xFFFF9800),
        label: 'Reel',
        onTap: canPost ? () => _pickVideo(reel: true) : null,
      ),
      _ActionChip(
        icon: Icons.attach_file_outlined,
        color: const Color(0xFF2196F3),
        label: 'Document',
        onTap: canPost ? _pickFiles : null,
      ),
    ];

    // Row 2: Location, Feeling, Activity, Background
    final row2 = <_ActionChip>[
      _ActionChip(
        icon: Icons.location_on_outlined,
        color: const Color(0xFFF44336),
        label: 'Location',
        onTap: canPost ? _showLocationPicker : null,
      ),
      _ActionChip(
        icon: Icons.sentiment_satisfied_alt_outlined,
        color: const Color(0xFFFFC107),
        label: 'Feeling',
        onTap: canPost ? _showFeelingPicker : null,
      ),
      _ActionChip(
        icon: Icons.emoji_events_outlined,
        color: const Color(0xFFE91E63),
        label: 'Activity',
        onTap: canPost ? _showActivityPicker : null,
      ),
      _ActionChip(
        icon: Icons.palette_outlined,
        color: const Color(0xFF9C27B0),
        label: 'Background',
        onTap: canPost && _canShowBackgroundPicker
            ? _showBackgroundPicker
            : null,
      ),
    ];

    return Padding(
      // Only add safe-area bottom padding — keyboard is already handled by Scaffold.
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

  // â”€â”€ Media preview builder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //
  // Layout logic:
  //   â€¢ Single item â†’ full-width, aspect-ratio-aware preview
  //   â€¢ Multiple items â†’ grid layout with ReorderableListView
  //   â€¢ Video items â†’ play icon overlay
  //   â€¢ File items   â†’ file icon, filename, size

  // â”€â”€ Facebook-style media preview grid â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //
  // Layout rules:
  //   1 media  â†’ full-width, natural aspect ratio
  //   2 media  â†’ two equal columns
  //   3 media  â†’ left large (2/3 width) + right stacked (1/3 width)
  //   4+ media â†’ 2Ã—2 grid; 4th cell shows "+N" overlay for overflow
  //   Video    â†’ thumbnail + play icon overlay
  //   Document â†’ file card icon + name + remove

  Widget _buildMediaPreview() {
    return _buildFacebookGrid();
  }

  Widget _buildFacebookGrid() {
    final items = _mediaItems;
    final count = items.length;
    if (count == 0) return const SizedBox.shrink();

    // Wrap in a Column so the preview stays in the scrollable area
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
          // 4+ media: 2Ã—2 grid
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

  /// Builds a single full-width preview (1 media case).
  Widget _buildSinglePreview(_MediaItem item, int index) {
    final isVideo = item.type == 'VIDEO';
    final isFile = item.type == 'FILE';

    if (isVideo) {
      return SizedBox(
        width: double.infinity,
        child: _buildVideoCell(item, index),
      );
    }
    if (isFile) {
      return _buildFileCell(item, index);
    }

    // Single image â€” full-width, preserve aspect ratio
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Image.file(item.file, width: double.infinity, fit: BoxFit.contain),
            // Crop button
            Positioned(
              top: 8,
              right: 44,
              child: _MediaIconButton(
                icon: Icons.crop,
                onTap: _submitting ? null : () => _editImageAtIndex(index),
              ),
            ),
            // Remove button
            Positioned(
              top: 8,
              right: 8,
              child: _MediaIconButton(
                icon: Icons.close,
                onTap: _submitting ? null : () => _removeMedia(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a grid cell (used for 2/3/4+ layouts).
  Widget _buildGridCell(_MediaItem item, int index) {
    final isVideo = item.type == 'VIDEO';
    final isFile = item.type == 'FILE';

    if (isVideo) return _buildVideoCell(item, index);
    if (isFile) return _buildFileCell(item, index);

    // Image grid cell â€” fill the square, BoxFit.cover with crop button
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(item.file, fit: BoxFit.cover),
            Positioned(
              top: 4,
              right: 4,
              child: _MediaIconButton(
                icon: Icons.close,
                size: 16,
                padding: 4,
                onTap: _submitting ? null : () => _removeMedia(index),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: GestureDetector(
                onTap: _submitting ? null : () => _editImageAtIndex(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.crop, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Video cell with thumbnail + play overlay + remove + type badge.
  Widget _buildVideoCell(_MediaItem item, int index) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.thumbnail != null)
              Image.file(item.thumbnail!, fit: BoxFit.cover)
            else
              Container(color: Colors.black12),
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
                onTap: _submitting ? null : () => _removeMedia(index),
              ),
            ),
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _type == 'REEL' ? 'REEL' : 'VIDEO',
                  style: const TextStyle(
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

  /// File card cell with icon, name, remove.
  Widget _buildFileCell(_MediaItem item, int index) {
    final name = item.file.path.split('/').last;
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
          if (!_submitting)
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

  /// 4th cell with "+N" overlay when count > 4.
  Widget _buildGridCellWithOverlay(List<_MediaItem> items, int index) {
    final remaining = items.length - 4;
    final item = items[index];

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
                  if (item.thumbnail != null)
                    Image.file(item.thumbnail!, fit: BoxFit.cover)
                  else
                    Container(color: Colors.black12),
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
              Image.file(item.file, fit: BoxFit.cover),
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
                onTap: _submitting ? null : () => _removeMedia(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeMedia(int index) {
    if (index < 0 || index >= _mediaItems.length) return;
    setState(() {
      _mediaItems.removeAt(index);
      if (_mediaItems.isEmpty) {
        _type = 'TEXT';
      }
    });
  }
}

// â”€â”€ Pet picker item model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PetPickerItem {
  final int id;
  final String name;
  final String? photoUrl;
  const _PetPickerItem({required this.id, required this.name, this.photoUrl});
}

// â”€â”€ Discard dialog result â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

enum _BackAction { saveDraft, discard, continueEditing }

// â”€â”€ Shared icon button for media overlays â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

/// Compact horizontal action chip for the "Add to your post" row.
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
