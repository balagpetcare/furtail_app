import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../location/presentation/widgets/location_selector_widget.dart';
import '../../../media/composer/media_composer_controller.dart';
import '../../../media/composer/media_composer_policy.dart';
import '../../../media/composer/media_composer_widgets.dart';
import '../../../media/composer/media_draft_item.dart';
import '../../../media/composer/media_preparation_service.dart';
import '../../../media/data/authenticated_media_uploader.dart';
import '../utils/fundraising_media_session.dart';
import '../../../posts/data/datasources/posts_remote_ds.dart';
import '../../data/fundraising_error_mapper.dart';
import '../../data/models/fundraising_models.dart';
import '../providers/fundraising_providers.dart';

class FundraisingEditScreen extends ConsumerStatefulWidget {
  const FundraisingEditScreen({super.key, required this.campaign});

  final FundraisingCampaign campaign;

  @override
  ConsumerState<FundraisingEditScreen> createState() =>
      _FundraisingEditScreenState();
}

class _FundraisingEditScreenState extends ConsumerState<FundraisingEditScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _documentExtensions = <String>[
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  late final TabController _tab;
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _postsDs = PostsRemoteDs();
  final _mediaPreparation = const MediaPreparationService();
  late final FundraisingMediaSession _mediaSession;

  late final MediaComposerController _mediaController;

  int? _divisionId;
  int? _districtId;
  LocationAddressMode? _addressMode;
  int? _cityCorporationId;
  int? _zoneId;
  int? _wardId;
  int? _upazilaId;
  int? _unionId;
  int? _areaId;
  String? _divisionName;
  String? _districtName;
  String? _cityCorporationName;
  String? _zoneName;
  String? _wardName;
  String? _upazilaName;
  String? _unionName;
  String? _areaName;
  String _category = 'Treatment';
  DateTime? _deadline;
  String _status = 'ACTIVE';
  bool _saving = false;
  bool _pickingMedia = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _mediaSession = FundraisingMediaSession.forCampaign(
      campaignId: widget.campaign.id,
    );
    _mediaController = MediaComposerController(
      policy: MediaComposerPolicy.fundraising,
      draftStorageKey: 'fundraising:campaign:${widget.campaign.id}',
      uploadMedia:
          (
            item, {
            void Function(int sentBytes, int totalBytes)? onProgress,
            CancelToken? cancelToken,
          }) {
            return _postsDs.uploadMediaDetailedWithProgress(
              fundraisingMultipartSourceFor(item),
              onProgress: onProgress,
              cancelToken: cancelToken,
              contentType: _mediaSession.contentType,
              contentId: _mediaSession.contentId,
              idempotencyKey: _mediaSession.idempotencyKeyFor(item.id),
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

    final campaign = widget.campaign;
    _titleCtrl.text = campaign.title;
    _captionCtrl.text = campaign.caption ?? '';
    _amountCtrl.text = campaign.targetAmount.toString();
    _locationCtrl.text = campaign.locationText ?? '';
    _category = (campaign.category?.trim().isNotEmpty ?? false)
        ? campaign.category!.trim()
        : 'Treatment';
    _deadline = campaign.deadline;
    _status = campaign.status;

    _mediaController.seedItemsIfEmpty(
      campaign.media.map(_draftFromRemoteMedia).toList(),
    );
  }

  @override
  void dispose() {
    _mediaController
      ..removeListener(_handleMediaChanged)
      ..dispose();
    _tab.dispose();
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

  MediaDraftItem _draftFromRemoteMedia(FundraisingMediaItem media) {
    final normalizedType = media.type.trim().toUpperCase();
    final isVideo = normalizedType.contains('VIDEO');
    final isDocument =
        normalizedType.contains('DOC') ||
        normalizedType.contains('PDF') ||
        normalizedType.contains('FILE');
    return MediaDraftItem(
      id: media.id.toString(),
      type: isDocument
          ? MediaDraftType.document
          : (isVideo ? MediaDraftType.video : MediaDraftType.image),
      fileName: media.url.split('/').last,
      originalSizeBytes: 0,
      remoteMediaId: media.id,
      remoteUrl: media.url,
      remoteThumbnailUrl: isVideo ? media.url : null,
      state: MediaDraftState.ready,
      progress: 1,
    );
  }

  void _syncLocationText() {
    final parts = <String>[
      if (_addressMode == LocationAddressMode.urban) ...[
        if ((_areaName ?? '').trim().isNotEmpty) _areaName!.trim(),
        if ((_wardName ?? '').trim().isNotEmpty) _wardName!.trim(),
        if ((_zoneName ?? '').trim().isNotEmpty) _zoneName!.trim(),
        if ((_cityCorporationName ?? '').trim().isNotEmpty)
          _cityCorporationName!.trim(),
      ] else ...[
        if ((_areaName ?? '').trim().isNotEmpty) _areaName!.trim(),
        if ((_unionName ?? '').trim().isNotEmpty) _unionName!.trim(),
        if ((_upazilaName ?? '').trim().isNotEmpty) _upazilaName!.trim(),
      ],
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
        await _mediaPreparation.prepareDocuments(
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
          await _mediaPreparation.prepareReplacementDocument(
            File(path),
            existingId: item.id,
            isCover: item.isCover,
          ),
        );
        return;
      }

      if (item.isVideo) {
        final file = await _picker.pickVideo(source: ImageSource.gallery);
        if (file == null || !mounted) return;
        final replacement = await _mediaPreparation.prepareVideo(
          context,
          File(file.path),
          existingId: item.id,
          isCover: item.isCover,
        );
        if (replacement == null) return;
        await _mediaController.replaceItem(item.id, replacement);
        return;
      }

      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final replacement = await _mediaPreparation.prepareReplacementImage(
        context,
        File(file.path),
        existingId: item.id,
        isCover: item.isCover,
      );
      if (replacement == null) return;
      await _mediaController.replaceItem(item.id, replacement);
    } on MediaUploadException catch (error) {
      _showSnack(error.userMessage);
    }
  }

  Future<void> _deleteCampaign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete fundraiser?'),
          content: const Text('This will delete the post and fundraiser.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      final repo = ref.read(fundraisingRepositoryProvider);
      await repo.deleteCampaign(campaignId: widget.campaign.id);
      ref.invalidate(fundraisingFeedProvider);
      if (!mounted) return;
      Navigator.pop(context, true);
      Navigator.pop(context, true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final target = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (target <= 0) {
      _showSnack('Target amount must be greater than 0.');
      return;
    }
    if (_deadline == null) {
      _showSnack('Please select a deadline.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(fundraisingRepositoryProvider);
      final mediaIds = await _mediaController.ensureUploaded();

      await repo.updateCampaign(
        campaignId: widget.campaign.id,
        title: _titleCtrl.text.trim(),
        caption: _captionCtrl.text.trim(),
        category: _category,
        locationText: _locationCtrl.text.trim(),
        targetAmount: target,
        deadline: _deadline,
        status: _status,
        mediaIds: mediaIds,
      );

      await _mediaController.clearPersistedDraft();
      ref.invalidate(fundraisingCampaignProvider(widget.campaign.id));
      ref.invalidate(fundraisingFeedProvider);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Updated')));
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is MediaUploadException) {
      return error.userMessage;
    }

    return mapFundraisingError(error);
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Fundraiser'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Post'),
            Tab(text: 'Fundraising'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _saving ? null : _deleteCampaign,
          ),
          TextButton(
            onPressed: _saving || _mediaController.isPreparing ? null : _save,
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
        child: TabBarView(
          controller: _tab,
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _captionCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Post caption',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickImages,
                      icon: const Icon(Icons.photo),
                      label: const Text('Photo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickVideo,
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Video'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickDocuments,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Document'),
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
                    'Retry or remove failed uploads before saving.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Title required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target amount',
                    border: OutlineInputBorder(),
                  ),
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
                    DropdownMenuItem(value: 'Rescue', child: Text('Rescue')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setState(() => _category = value ?? 'Treatment');
                  },
                ),
                const SizedBox(height: 12),
                LocationSelectorWidget(
                  divisionId: _divisionId,
                  districtId: _districtId,
                  addressMode: _addressMode,
                  cityCorporationId: _cityCorporationId,
                  zoneId: _zoneId,
                  wardId: _wardId,
                  upazilaId: _upazilaId,
                  unionId: _unionId,
                  areaId: _areaId,
                  divisionName: _divisionName,
                  districtName: _districtName,
                  cityCorporationName: _cityCorporationName,
                  zoneName: _zoneName,
                  wardName: _wardName,
                  upazilaName: _upazilaName,
                  unionName: _unionName,
                  areaName: _areaName,
                  onAddressModeChanged: (mode) {
                    setState(() {
                      _addressMode = mode;
                      _cityCorporationId = null;
                      _cityCorporationName = null;
                      _zoneId = null;
                      _zoneName = null;
                      _wardId = null;
                      _wardName = null;
                      _upazilaId = null;
                      _upazilaName = null;
                      _unionId = null;
                      _unionName = null;
                      _areaId = null;
                      _areaName = null;
                      _syncLocationText();
                    });
                  },
                  onCityCorporationChanged: (id, name) {
                    setState(() {
                      _addressMode = LocationAddressMode.urban;
                      _cityCorporationId = id;
                      _cityCorporationName = name;
                      _zoneId = null;
                      _zoneName = null;
                      _wardId = null;
                      _wardName = null;
                      _upazilaId = null;
                      _upazilaName = null;
                      _unionId = null;
                      _unionName = null;
                      _areaId = null;
                      _areaName = null;
                      _syncLocationText();
                    });
                  },
                  onZoneChanged: (id, name) {
                    setState(() {
                      _addressMode = LocationAddressMode.urban;
                      _zoneId = id;
                      _zoneName = name;
                      _wardId = null;
                      _wardName = null;
                      _areaId = null;
                      _areaName = null;
                      _syncLocationText();
                    });
                  },
                  onWardChanged: (id, name) {
                    setState(() {
                      _addressMode = LocationAddressMode.urban;
                      _wardId = id;
                      _wardName = name;
                      _areaId = null;
                      _areaName = null;
                      _syncLocationText();
                    });
                  },
                  onDivisionChanged: (id, name) {
                    setState(() {
                      _divisionId = id;
                      _divisionName = name;
                      _districtId = null;
                      _districtName = null;
                      _addressMode = null;
                      _cityCorporationId = null;
                      _cityCorporationName = null;
                      _zoneId = null;
                      _zoneName = null;
                      _wardId = null;
                      _wardName = null;
                      _upazilaId = null;
                      _upazilaName = null;
                      _unionId = null;
                      _unionName = null;
                      _areaId = null;
                      _areaName = null;
                      _syncLocationText();
                    });
                  },
                  onDistrictChanged: (id, name) {
                    setState(() {
                      _districtId = id;
                      _districtName = name;
                      _addressMode = null;
                      _cityCorporationId = null;
                      _cityCorporationName = null;
                      _zoneId = null;
                      _zoneName = null;
                      _wardId = null;
                      _wardName = null;
                      _upazilaId = null;
                      _upazilaName = null;
                      _unionId = null;
                      _unionName = null;
                      _areaId = null;
                      _areaName = null;
                      _syncLocationText();
                    });
                  },
                  onUpazilaChanged: (id, name) {
                    setState(() {
                      _addressMode = LocationAddressMode.rural;
                      _upazilaId = id;
                      _upazilaName = name;
                      _cityCorporationId = null;
                      _cityCorporationName = null;
                      _zoneId = null;
                      _zoneName = null;
                      _wardId = null;
                      _wardName = null;
                      _unionId = null;
                      _unionName = null;
                      _areaId = null;
                      _areaName = null;
                      _syncLocationText();
                    });
                  },
                  onUnionChanged: (id, name) {
                    setState(() {
                      _addressMode = LocationAddressMode.rural;
                      _unionId = id;
                      _unionName = name;
                      _cityCorporationId = null;
                      _cityCorporationName = null;
                      _zoneId = null;
                      _zoneName = null;
                      _wardId = null;
                      _wardName = null;
                      _areaId = null;
                      _areaName = name;
                      _syncLocationText();
                    });
                  },
                  onAreaChanged: (_, name) {
                    final details = (name ?? '').trim();
                    setState(() {
                      _areaId = null;
                      _areaName = details.isEmpty ? null : details;
                      _syncLocationText();
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Location (auto from dropdowns)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDeadline,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _deadline == null
                        ? 'Select deadline'
                        : 'Deadline: ${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                    DropdownMenuItem(value: 'PAUSED', child: Text('PAUSED')),
                    DropdownMenuItem(value: 'ENDED', child: Text('ENDED')),
                  ],
                  onChanged: (value) {
                    setState(() => _status = value ?? 'ACTIVE');
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Tip: Save to update both post and fundraising details.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
