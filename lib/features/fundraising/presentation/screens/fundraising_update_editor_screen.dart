import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../media/composer/media_composer_controller.dart';
import '../../../media/composer/media_composer_policy.dart';
import '../../../media/composer/media_composer_widgets.dart';
import '../../../media/composer/media_draft_item.dart';
import '../../../media/composer/media_preparation_service.dart';
import '../../../media/data/authenticated_media_uploader.dart';
import '../../../posts/data/datasources/posts_remote_ds.dart';
import '../../data/models/fundraising_models.dart';
import '../providers/fundraising_providers.dart';

class FundraisingUpdateEditorScreen extends ConsumerStatefulWidget {
  const FundraisingUpdateEditorScreen({
    super.key,
    required this.campaignId,
    this.existing,
  });

  final int campaignId;
  final FundraisingUpdateItem? existing;

  @override
  ConsumerState<FundraisingUpdateEditorScreen> createState() =>
      _FundraisingUpdateEditorScreenState();
}

class _FundraisingUpdateEditorScreenState
    extends ConsumerState<FundraisingUpdateEditorScreen> {
  static const List<String> _documentExtensions = <String>[
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  final _formKey = GlobalKey<FormState>();
  final _captionCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _postsDs = PostsRemoteDs();
  final _mediaPreparation = const MediaPreparationService();

  late final MediaComposerController _mediaController;

  bool _saving = false;
  bool _pickingMedia = false;

  @override
  void initState() {
    super.initState();
    _captionCtrl.text = widget.existing?.caption ?? '';
    _mediaController = MediaComposerController(
      policy: MediaComposerPolicy.fundraising,
      draftStorageKey:
          'fundraising:update:${widget.existing?.id ?? 'new-${widget.campaignId}'}',
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
    _mediaController.seedItemsIfEmpty(
      (widget.existing?.media ?? const <FundraisingMediaItem>[])
          .map(_draftFromRemoteMedia)
          .toList(),
    );
  }

  @override
  void dispose() {
    _mediaController
      ..removeListener(_handleMediaChanged)
      ..dispose();
    _captionCtrl.dispose();
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

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(fundraisingRepositoryProvider);
      final mediaIds = await _mediaController.ensureUploaded();

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
          mediaIds: mediaIds,
        );
      }

      await _mediaController.clearPersistedDraft();
      ref.invalidate(fundraisingUpdatesProvider(widget.campaignId));
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existing == null ? 'Update posted' : 'Update updated',
          ),
        ),
      );
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
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Update' : 'New Update'),
        actions: [
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
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty && _mediaController.items.isEmpty) {
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
      ),
    );
  }
}
