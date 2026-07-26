import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:furtail_app/features/media/composer/fundraising_media_validation.dart';
import 'package:furtail_app/features/media/composer/media_composer_policy.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';
import 'package:furtail_app/features/media/data/authenticated_media_uploader.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef MediaDraftUploadCallback =
    Future<UploadedMediaResult> Function(
      MediaDraftItem item, {
      void Function(int sentBytes, int totalBytes)? onProgress,
      CancelToken? cancelToken,
    });

class MediaComposerController extends ChangeNotifier {
  MediaComposerController({
    required this.policy,
    required this.draftStorageKey,
    required this.uploadMedia,
    this.maxConcurrentUploads = 2,
  });

  final MediaComposerPolicy policy;
  final String draftStorageKey;
  final MediaDraftUploadCallback uploadMedia;
  final int maxConcurrentUploads;

  final List<MediaDraftItem> _items = <MediaDraftItem>[];
  final Map<String, CancelToken> _cancelTokens = <String, CancelToken>{};

  bool _restored = false;
  bool _disposed = false;
  Future<List<int>>? _ensureUploadedInFlight;

  List<MediaDraftItem> get items => List<MediaDraftItem>.unmodifiable(_items);
  bool get hasItems => _items.isNotEmpty;
  bool get hasFailedItems => mediaValidation.hasFailedItems;
  bool get hasBlockingItems => _items.any((item) => item.blocksSubmission);
  bool get hasPendingItems => mediaValidation.hasPendingItems;
  int get activeUploadCount =>
      _items.where((item) => item.isUploading || item.isPreparing).length;
  FundraisingMediaValidationResult get mediaValidation =>
      evaluateFundraisingMedia(_items);
  bool get allItemsReady =>
      _items.isNotEmpty &&
      _items.every(
        (item) =>
            item.remoteMediaId != null &&
            (item.state == MediaDraftState.ready ||
                item.state == MediaDraftState.uploaded),
      );
  MediaDraftItem? get firstFailedItem {
    for (final item in _items) {
      if (item.hasFailed) return item;
    }
    return null;
  }

  bool get isUploading => _items.any((item) => item.isUploading);
  bool get isPreparing => _items.any((item) => item.isPreparing);

  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    final prefs = await SharedPreferences.getInstance();
    final stored = MediaDraftItem.decodeList(
      prefs.getString(_storageKey),
    ).where(_canRestoreItem).toList();
    _items
      ..clear()
      ..addAll(_normalizeCover(stored));
    notifyListeners();
  }

  Future<void> addItems(List<MediaDraftItem> items) async {
    await restore();
    final updated = List<MediaDraftItem>.from(_items);
    var currentPhotos = updated.where((item) => item.isImage).length;
    var currentVideos = updated.where((item) => item.isVideo).length;
    var currentDocuments = updated.where((item) => item.isDocument).length;

    for (final item in items) {
      final error = policy.validateAddition(
        item.type,
        currentPhotos: currentPhotos,
        currentVideos: currentVideos,
        currentDocuments: currentDocuments,
        fileName: item.fileName,
      );
      if (error != null) {
        throw MediaUploadException(
          kind: MediaUploadErrorKind.invalidPayload,
          userMessage: error,
        );
      }
      updated.add(item);
      if (item.isImage) currentPhotos++;
      if (item.isVideo) currentVideos++;
      if (item.isDocument) currentDocuments++;
    }

    _replaceItems(updated);
  }

  Future<void> seedItemsIfEmpty(List<MediaDraftItem> items) async {
    await restore();
    if (_items.isNotEmpty) return;
    _replaceItems(items);
  }

  Future<void> clearPersistedDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> replaceItem(String itemId, MediaDraftItem replacement) async {
    await restore();
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index < 0) return;
    final wasCover = _items[index].isCover;
    _items[index] = replacement.copyWith(
      isCover: wasCover,
      state: MediaDraftState.local,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> removeItem(String itemId) async {
    await restore();
    await cancelItem(itemId, persistCancelledState: false);
    _items.removeWhere((item) => item.id == itemId);
    _replaceItems(List<MediaDraftItem>.from(_items));
  }

  Future<void> cancelItem(
    String itemId, {
    bool persistCancelledState = true,
  }) async {
    final token = _cancelTokens.remove(itemId);
    token?.cancel('cancelled');
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index < 0) return;
    final current = _items[index];
    if (current.isUploading || current.isPreparing) {
      _items[index] = current.copyWith(
        state: MediaDraftState.cancelled,
        progress: 0,
        errorMessage: 'Upload cancelled.',
      );
      if (persistCancelledState) {
        await _persist();
      }
      notifyListeners();
    }
  }

  Future<void> retryItem(String itemId) async {
    await restore();
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(
      state: MediaDraftState.local,
      progress: 0,
      clearErrorMessage: true,
      clearRemoteMediaId: true,
      remoteUrl: null,
      remoteHlsUrl: null,
      remoteThumbnailUrl: null,
      remoteStatus: null,
    );
    await _persist();
    notifyListeners();
    await ensureUploaded();
  }

  Future<List<int>> ensureUploaded() async {
    final existing = _ensureUploadedInFlight;
    if (existing != null) return existing;
    final future = _ensureUploaded().whenComplete(() {
      _ensureUploadedInFlight = null;
    });
    _ensureUploadedInFlight = future;
    return future;
  }

  Future<List<int>> _ensureUploaded() async {
    await restore();
    final queued = _items
        .where((item) => item.remoteMediaId == null)
        .where(
          (item) =>
              item.state == MediaDraftState.local ||
              item.state == MediaDraftState.failed ||
              item.state == MediaDraftState.cancelled,
        )
        .map((item) => item.id)
        .toList();

    if (queued.isNotEmpty) {
      var nextIndex = 0;
      final workers = List<Future<void>>.generate(maxConcurrentUploads, (
        _,
      ) async {
        while (true) {
          String? nextId;
          if (nextIndex < queued.length) {
            nextId = queued[nextIndex];
            nextIndex += 1;
          }
          if (nextId == null) return;
          await _uploadSingle(nextId);
        }
      });
      await Future.wait(workers);
    }

    final blocking = _items.where((item) => item.blocksSubmission).toList();
    if (blocking.isNotEmpty) {
      throw MediaUploadException(
        kind: MediaUploadErrorKind.unknown,
        userMessage:
            blocking.first.errorMessage ??
            'Retry or remove failed uploads before continuing.',
      );
    }

    return _items
        .where((item) => item.remoteMediaId != null)
        .map((item) => item.remoteMediaId!)
        .toList();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    await restore();
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    if (newIndex < 0 || newIndex > _items.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final list = List<MediaDraftItem>.from(_items);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _replaceItems(list);
  }

  Future<void> setCover(String itemId) async {
    await restore();
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index < 0) return;
    final list = List<MediaDraftItem>.from(_items);
    final item = list.removeAt(index);
    list.insert(0, item);
    _replaceItems(list);
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final token in _cancelTokens.values) {
      token.cancel('disposed');
    }
    _cancelTokens.clear();
    super.dispose();
  }

  String get _storageKey => 'media_composer.$draftStorageKey';

  Future<void> _uploadSingle(String itemId) async {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index < 0) return;
    final current = _items[index];
    if (current.remoteMediaId != null ||
        current.isUploading ||
        current.isPreparing) {
      return;
    }
    if (current.localPath == null || current.localPath!.isEmpty) {
      _items[index] = current.copyWith(
        state: MediaDraftState.failed,
        errorMessage: 'The local file is missing. Please add it again.',
      );
      await _persist();
      notifyListeners();
      return;
    }
    if (!File(current.localPath!).existsSync()) {
      _items[index] = current.copyWith(
        state: MediaDraftState.failed,
        errorMessage: 'The local file is missing. Please add it again.',
      );
      await _persist();
      notifyListeners();
      return;
    }

    _items[index] = current.copyWith(
      state: MediaDraftState.preparing,
      progress: 0,
      clearErrorMessage: true,
    );
    notifyListeners();

    final cancelToken = CancelToken();
    _cancelTokens[itemId] = cancelToken;
    _items[index] = _items[index].copyWith(state: MediaDraftState.uploading);
    await _persist();
    notifyListeners();

    try {
      final result = await uploadMedia(
        _items[index],
        cancelToken: cancelToken,
        onProgress: (sent, total) {
          final uploadIndex = _items.indexWhere((item) => item.id == itemId);
          if (uploadIndex < 0 || total <= 0) return;
          _items[uploadIndex] = _items[uploadIndex].copyWith(
            state: MediaDraftState.uploading,
            progress: (sent / total).clamp(0, 1).toDouble(),
            clearErrorMessage: true,
          );
          notifyListeners();
        },
      );

      final nextState = switch ((result.status ?? '').trim().toUpperCase()) {
        'PENDING' || 'PROCESSING' => MediaDraftState.processing,
        _ => MediaDraftState.ready,
      };

      final uploadIndex = _items.indexWhere((item) => item.id == itemId);
      if (uploadIndex < 0) return;
      _items[uploadIndex] = _items[uploadIndex].copyWith(
        remoteMediaId: result.id,
        remoteUrl: result.url,
        remoteHlsUrl: result.hlsUrl,
        remoteThumbnailUrl: result.thumbnailUrl,
        remoteStatus: result.status,
        mimeType: result.mimeType,
        state: nextState,
        progress: 1,
        clearErrorMessage: true,
      );
      await _persist();
      notifyListeners();
    } on MediaUploadException catch (error) {
      final uploadIndex = _items.indexWhere((item) => item.id == itemId);
      if (uploadIndex >= 0) {
        _items[uploadIndex] = _items[uploadIndex].copyWith(
          state: error.kind == MediaUploadErrorKind.requestCancelled
              ? MediaDraftState.cancelled
              : MediaDraftState.failed,
          progress: 0,
          errorMessage: error.userMessage,
          clearRemoteMediaId: true,
          remoteUrl: null,
          remoteHlsUrl: null,
          remoteThumbnailUrl: null,
          remoteStatus: null,
        );
        await _persist();
        notifyListeners();
      }
    } catch (error) {
      final uploadIndex = _items.indexWhere((item) => item.id == itemId);
      if (uploadIndex >= 0) {
        _items[uploadIndex] = _items[uploadIndex].copyWith(
          state: MediaDraftState.failed,
          progress: 0,
          errorMessage: MediaUploadException.from(error).userMessage,
          clearRemoteMediaId: true,
          remoteUrl: null,
          remoteHlsUrl: null,
          remoteThumbnailUrl: null,
          remoteStatus: null,
        );
        await _persist();
        notifyListeners();
      }
    } finally {
      _cancelTokens.remove(itemId);
    }
  }

  bool _canRestoreItem(MediaDraftItem item) {
    if (item.remoteMediaId != null) return true;
    final localPath = item.localPath;
    if (localPath == null || localPath.isEmpty) return false;
    return File(localPath).existsSync();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, MediaDraftItem.encodeList(_items));
  }

  void _replaceItems(List<MediaDraftItem> nextItems) {
    _items
      ..clear()
      ..addAll(_normalizeCover(nextItems));
    unawaited(_persist());
    notifyListeners();
  }

  List<MediaDraftItem> _normalizeCover(List<MediaDraftItem> source) {
    var marked = false;
    return source.asMap().entries.map((entry) {
      final shouldBeCover = !marked && (entry.value.isCover || entry.key == 0);
      if (shouldBeCover) marked = true;
      return entry.value.copyWith(isCover: shouldBeCover);
    }).toList();
  }
}
