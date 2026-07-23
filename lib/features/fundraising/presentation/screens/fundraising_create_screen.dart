import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:furtail_app/core/theme/typography.dart';
import 'package:furtail_app/features/fundraising/presentation/screens/fundraising_account_setup_screen.dart';
import 'package:image_picker/image_picker.dart';

import '../../../location/presentation/widgets/location_selector_widget.dart';
import '../../../media/composer/media_composer_controller.dart';
import '../../../media/composer/media_composer_policy.dart';
import '../../../media/composer/media_composer_widgets.dart';
import '../../../media/composer/media_draft_item.dart';
import '../../../media/composer/media_preparation_service.dart';
import '../../../media/data/authenticated_media_uploader.dart';
import '../../../posts/data/datasources/posts_remote_ds.dart';
import '../providers/fundraising_providers.dart';

class FundraisingCreateScreen extends ConsumerStatefulWidget {
  const FundraisingCreateScreen({super.key});

  @override
  ConsumerState<FundraisingCreateScreen> createState() =>
      _FundraisingCreateScreenState();
}

class _FundraisingCreateScreenState
    extends ConsumerState<FundraisingCreateScreen> {
  static const List<String> _documentExtensions = <String>[
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _postsDs = PostsRemoteDs();
  final _mediaPreparation = const MediaPreparationService();

  final _titleCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  late final MediaComposerController _mediaController;

  String _category = 'Treatment';
  int? _divisionId;
  int? _districtId;
  int? _upazilaId;
  int? _unionId;
  String? _divisionName;
  String? _districtName;
  String? _upazilaName;
  String? _unionName;
  String? _areaName;
  DateTime? _deadline;
  bool _submitting = false;
  bool _pickingMedia = false;

  @override
  void initState() {
    super.initState();
    _mediaController = MediaComposerController(
      policy: MediaComposerPolicy.fundraising,
      draftStorageKey: 'fundraising:create',
      uploadMedia:
          (
            item, {
            void Function(int sentBytes, int totalBytes)? onProgress,
            CancelToken? cancelToken,
          }) {
            return _postsDs.uploadMediaDetailedWithProgress(
              File(item.localPath!),
              onProgress: onProgress,
              cancelToken: cancelToken,
              draftId: item.id,
              uploadContext: MediaComposerPolicy.fundraising.uploadContext,
              folder: MediaComposerPolicy.fundraising.folder,
              trimStartMs: item.isVideo ? item.trimStartMs : null,
              trimEndMs: item.isVideo ? item.trimEndMs : null,
              mute: item.isVideo ? item.mute : null,
              volume: item.isVideo ? item.volume : null,
              coverTimestampMs: item.isVideo ? item.coverTimestampMs : null,
              aspectRatio: item.isVideo ? item.aspectRatio : null,
              quality: item.isVideo ? item.quality : null,
            );
          },
    );
    _mediaController.addListener(_handleMediaChanged);
  }

  @override
  void dispose() {
    _mediaController
      ..removeListener(_handleMediaChanged)
      ..dispose();
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    _amountCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _handleMediaChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _syncLocationText() {
    final parts = <String>[
      if ((_areaName ?? '').trim().isNotEmpty) _areaName!.trim(),
      if ((_unionName ?? '').trim().isNotEmpty) _unionName!.trim(),
      if ((_upazilaName ?? '').trim().isNotEmpty) _upazilaName!.trim(),
      if ((_districtName ?? '').trim().isNotEmpty) _districtName!.trim(),
      if ((_divisionName ?? '').trim().isNotEmpty) _divisionName!.trim(),
    ];
    _locationCtrl.text = parts.join(', ');
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = _deadline ?? now.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDate: initial,
    );
    if (picked == null) return;
    setState(
      () => _deadline = DateTime(picked.year, picked.month, picked.day, 23, 59),
    );
  }

  Future<void> _pickImages() async {
    if (_pickingMedia) return;
    _pickingMedia = true;
    try {
      final files = await _picker.pickMultiImage(imageQuality: 100);
      if (files.isEmpty || !mounted) return;
      final items = await _mediaPreparation.prepareImages(
        context,
        files.map((file) => File(file.path)).toList(),
      );
      if (items.isEmpty) return;
      await _mediaController.addItems(items);
    } on MediaUploadException catch (error) {
      _showSnack(error.userMessage);
    } finally {
      _pickingMedia = false;
    }
  }

  Future<void> _pickVideo() async {
    if (_pickingMedia) return;
    _pickingMedia = true;
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final item = await _mediaPreparation.prepareVideo(
        context,
        File(file.path),
      );
      if (item == null) return;
      await _mediaController.addItems(<MediaDraftItem>[item]);
    } on MediaUploadException catch (error) {
      _showSnack(error.userMessage);
    } finally {
      _pickingMedia = false;
    }
  }

  Future<void> _pickDocuments() async {
    if (_pickingMedia) return;
    _pickingMedia = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _documentExtensions,
      );
      final paths =
          result?.paths.whereType<String>().toList() ?? const <String>[];
      if (paths.isEmpty) return;
      await _mediaController.addItems(
        _mediaPreparation.prepareDocuments(
          paths.map((path) => File(path)).toList(),
        ),
      );
    } on MediaUploadException catch (error) {
      _showSnack(error.userMessage);
    } finally {
      _pickingMedia = false;
    }
  }

  Future<void> _editMediaItem(MediaDraftItem item) async {
    if (item.isUploading || item.isPreparing) return;
    try {
      if (item.isDocument) {
        final replacement = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.custom,
          allowedExtensions: _documentExtensions,
        );
        final path = replacement?.files.single.path;
        if (path == null) return;
        await _mediaController.replaceItem(
          item.id,
          _mediaPreparation.prepareReplacementDocument(
            File(path),
            existingId: item.id,
            isCover: item.isCover,
          ),
        );
        return;
      }

      final localPath = item.localPath;
      if (localPath == null ||
          localPath.isEmpty ||
          !File(localPath).existsSync()) {
        _showSnack('That file is no longer available. Please add it again.');
        return;
      }

      if (item.isVideo) {
        final replacement = await _mediaPreparation.prepareVideo(
          context,
          File(localPath),
          existingId: item.id,
          isCover: item.isCover,
        );
        if (replacement == null) return;
        await _mediaController.replaceItem(item.id, replacement);
        return;
      }

      final replacement = await _mediaPreparation.prepareReplacementImage(
        context,
        File(localPath),
        existingId: item.id,
        isCover: item.isCover,
      );
      if (replacement == null) return;
      await _mediaController.replaceItem(item.id, replacement);
    } on MediaUploadException catch (error) {
      _showSnack(error.userMessage);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_deadline == null) {
      _showSnack('Please select a deadline.');
      return;
    }

    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _showSnack('Target amount must be greater than 0.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(fundraisingRepositoryProvider);
      final mediaIds = await _mediaController.ensureUploaded();

      await repo.createCampaign(
        title: _titleCtrl.text.trim(),
        caption: _captionCtrl.text.trim(),
        category: _category,
        locationText: _locationCtrl.text.trim(),
        targetAmount: amount,
        deadline: _deadline!,
        mediaIds: mediaIds,
      );

      await _mediaController.clearPersistedDraft();
      ref.invalidate(fundraisingFeedProvider);

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fundraiser created successfully')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = _friendlyError(error);
      if (message.contains('(403)')) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Verification info required'),
              content: const Text(
                'To create a fundraising campaign, complete your verification profile and upload the required documents first.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FundraisingAccountSetupScreen(),
                      ),
                    );
                  },
                  child: const Text('Open Verification'),
                ),
              ],
            );
          },
        );
      } else {
        _showSnack(message);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is MediaUploadException) {
      return error.userMessage;
    }

    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.startsWith('{') || raw.startsWith('[') || raw.isEmpty) {
      return 'Could not complete that request right now. Please try again.';
    }
    return raw;
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final deadlineText = _deadline == null
        ? 'Select deadline'
        : '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Start Fund Raising')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Title is required';
                    if (text.length < 6) {
                      return 'Please write a more descriptive title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _captionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 4,
                  maxLines: 8,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Description is required';
                    if (text.length < 20) {
                      return 'Please add more details (min 20 characters)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Target Amount (BDT)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    final amount = int.tryParse(text);
                    if (amount == null) return 'Enter a valid number';
                    if (amount <= 0) return 'Must be greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Treatment',
                      child: Text('Treatment'),
                    ),
                    DropdownMenuItem(value: 'Food', child: Text('Food')),
                    DropdownMenuItem(value: 'Shelter', child: Text('Shelter')),
                    DropdownMenuItem(
                      value: 'Vaccination',
                      child: Text('Vaccination'),
                    ),
                    DropdownMenuItem(value: 'Rescue', child: Text('Rescue')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: _submitting
                      ? null
                      : (value) =>
                            setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 12),
                LocationSelectorWidget(
                  divisionId: _divisionId,
                  districtId: _districtId,
                  upazilaId: _upazilaId,
                  unionId: _unionId,
                  divisionName: _divisionName,
                  districtName: _districtName,
                  upazilaName: _upazilaName,
                  unionName: _unionName,
                  disabled: _submitting,
                  required: true,
                  onDivisionChanged: (id, name) {
                    setState(() {
                      _divisionId = id;
                      _divisionName = name;
                      _districtId = null;
                      _districtName = null;
                      _upazilaId = null;
                      _upazilaName = null;
                      _unionId = null;
                      _unionName = null;
                      _areaName = null;
                      _syncLocationText();
                    });
                  },
                  onDistrictChanged: (id, name) {
                    setState(() {
                      _districtId = id;
                      _districtName = name;
                      _upazilaId = null;
                      _upazilaName = null;
                      _unionId = null;
                      _unionName = null;
                      _areaName = null;
                      _syncLocationText();
                    });
                  },
                  onUpazilaChanged: (id, name) {
                    setState(() {
                      _upazilaId = id;
                      _upazilaName = name;
                      _unionId = null;
                      _unionName = null;
                      _areaName = null;
                      _syncLocationText();
                    });
                  },
                  onUnionChanged: (id, name) {
                    setState(() {
                      _unionId = id;
                      _unionName = name;
                      _areaName = name;
                      _syncLocationText();
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _locationCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Location (auto)',
                    border: OutlineInputBorder(),
                    helperText:
                        'Select Division -> District -> Upazila -> Union',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Location is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Campaign Media',
                  style: context.appText.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add up to 8 photos, 2 videos, and 6 supporting documents. Failed uploads must be retried or removed before publishing.',
                  style: context.appText.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ActionChip(
                      icon: Icons.photo,
                      label: 'Add Photos',
                      onTap: _submitting ? null : _pickImages,
                    ),
                    _ActionChip(
                      icon: Icons.videocam,
                      label: 'Add Video',
                      onTap: _submitting ? null : _pickVideo,
                    ),
                    _ActionChip(
                      icon: Icons.description_outlined,
                      label: 'Add Documents',
                      onTap: _submitting ? null : _pickDocuments,
                    ),
                  ],
                ),
                if (_mediaController.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  MediaComposerList(
                    controller: _mediaController,
                    onEditItem: _editMediaItem,
                  ),
                ],
                if (_mediaController.hasFailedItems) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Retry or remove failed uploads before creating the fundraiser.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDeadline,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(deadlineText),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submitting || _mediaController.isPreparing
                      ? null
                      : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Fundraiser'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Note: Payment gateway is not enabled yet (Phase B).\nDonations are recorded as SUCCESS for now.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
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
