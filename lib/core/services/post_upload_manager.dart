import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/posts/data/datasources/posts_remote_ds.dart';
import '../analytics/analytics_service.dart';

enum PostUploadStatus {
  idle,
  preparing,
  compressing,
  uploading,
  processing,
  posted,
  failed,
}

class PostUploadState {
  final bool inProgress;
  /// Weighted overall progress shown in UI (0..1).
  final double overallProgress;
  /// Progress within the current phase (0..1), not shown directly in UI.
  final double phaseProgress;
  /// Phase label without a percentage, e.g. "Preparing video…"
  final String message;
  final bool done;
  final String? error;
  final PostUploadStatus status;
  /// ID returned by createPost/updatePost — available when status == posted.
  final int? createdPostId;
  /// Server timestamp of the created post.
  final DateTime? createdAt;

  const PostUploadState({
    required this.inProgress,
    required this.overallProgress,
    required this.phaseProgress,
    required this.message,
    required this.done,
    required this.status,
    this.error,
    this.createdPostId,
    this.createdAt,
  });

  factory PostUploadState.idle() => const PostUploadState(
    inProgress: false,
    overallProgress: 0,
    phaseProgress: 0,
    message: '',
    done: false,
    status: PostUploadStatus.idle,
  );

  PostUploadState copyWith({
    bool? inProgress,
    double? overallProgress,
    double? phaseProgress,
    String? message,
    bool? done,
    PostUploadStatus? status,
    String? error,
    int? createdPostId,
    DateTime? createdAt,
  }) {
    return PostUploadState(
      inProgress: inProgress ?? this.inProgress,
      overallProgress: overallProgress ?? this.overallProgress,
      phaseProgress: phaseProgress ?? this.phaseProgress,
      message: message ?? this.message,
      done: done ?? this.done,
      status: status ?? this.status,
      error: error,
      createdPostId: createdPostId ?? this.createdPostId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class PostUploadDraft {
  final int? existingId;
  final File? file;
  final String type; // IMAGE / VIDEO / FILE

  PostUploadDraft({
    this.existingId,
    this.file,
    required this.type,
  });
}

class PostUploadTask {
  final String id;
  final String type; // TEXT / IMAGE / VIDEO / REEL
  final String? caption;
  final List<PostUploadDraft> drafts;
  final int? trimStartMs;
  final int? trimEndMs;
  final bool? mute;
  final double? volume;
  final String? privacy;
  final int? editPostId;
  final String? backgroundStyle; // Style metadata for text posts

  PostUploadTask({
    required this.id,
    required this.type,
    this.caption,
    this.drafts = const [],
    this.trimStartMs,
    this.trimEndMs,
    this.mute,
    this.volume,
    this.privacy,
    this.editPostId,
    this.backgroundStyle,
  });
}

// ── Upload size limits ────────────────────────────────────────────────────────
// These must match MAX_UPLOAD_BYTES on the backend (appConfig.mediaPolicy).
const int _maxImageBytes = 15 * 1024 * 1024;  // 15 MB
const int _maxVideoBytes = 200 * 1024 * 1024; // 200 MB

/// Human-readable file size: KB below 1 MB, MB below 1 GB, GB otherwise.
String _formatFileSize(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  } else if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  } else {
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)}GB';
  }
}

// ── Overall progress weights per phase ───────────────────────────────────────
//   preparing:   0.00 → 0.05
//   uploading:   0.25 → 0.90
//   processing:  0.90 → 0.98
//   posted:      1.00
double _uploadingOverall(double queueProgress) => 0.25 + queueProgress * 0.65;

class PostUploadManager {
  PostUploadManager._();
  static final PostUploadManager instance = PostUploadManager._();

  final ValueNotifier<PostUploadState> state = ValueNotifier(
    PostUploadState.idle(),
  );

  final PostsRemoteDs _ds = PostsRemoteDs();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const int _notificationId = 8888;
  static const String _channelId = 'bpa_GENERAL';
  static const String _channelName = 'General';

  PostUploadTask? _currentTask;
  Future<void>? _running;

  bool get isBusy => state.value.inProgress;
  PostUploadTask? get currentTask => _currentTask;

  // Tracks media IDs successfully uploaded in the current run, keyed by draft
  // index.  Used by retry() to skip re-uploading files that already succeeded.
  final Map<int, int> _uploadedDraftMediaIds = {};

  // Throttle state/notification updates to ≤10/sec during compression and upload.
  DateTime? _lastProgressUpdate;

  bool _shouldEmitProgress() {
    final now = DateTime.now();
    if (_lastProgressUpdate == null ||
        now.difference(_lastProgressUpdate!).inMilliseconds >= 100) {
      _lastProgressUpdate = now;
      return true;
    }
    return false;
  }

  bool _hasPendingRetry = false;
  bool get hasPendingRetry => _hasPendingRetry;

  void setPendingRetry(bool value) {
    _hasPendingRetry = value;
    if (value) {
      _checkAndProcessPendingRetry();
    }
  }

  void checkAndProcessPendingRetry() {
    _checkAndProcessPendingRetry();
  }

  void _checkAndProcessPendingRetry() {
    if (_hasPendingRetry) {
      final task = _currentTask;
      if (task == null) {
        // No active task — notification tap arrived after user cancelled.
        // Clear the flag so it doesn't interfere with the next upload.
        _hasPendingRetry = false;
        return;
      }
      if (_running == null) {
        _hasPendingRetry = false;
        retry().catchError((e) {
          debugPrint('[PostUploadManager] Failed to run pending retry: $e');
        });
      }
    }
  }

  /// Dismisses the upload notification from the Android system tray.
  /// Call this when the user explicitly cancels a failed upload so the
  /// "Tap to retry" notification no longer appears.
  Future<void> cancelNotification() async {
    try {
      await _localNotifications.cancel(_notificationId);
    } catch (e) {
      debugPrint('[PostUploadManager] Failed to cancel notification: $e');
    }
  }

  void reset() {
    state.value = PostUploadState.idle();
    _currentTask = null;
    _hasPendingRetry = false;
    _lastProgressUpdate = null;
    _uploadedDraftMediaIds.clear();
    // video_compress 3.1.4 has a MethodChannel bug: deleteAllCache() returns
    // kotlin.Unit which the Android MethodChannel serializer cannot encode,
    // causing an IllegalArgumentException in Android logs.  Catch it explicitly
    // so the error is visible in Dart debug output instead of being swallowed.
    // The underlying temp-file cleanup is handled by clearStaleTempFiles() on
    // startup, so this call is best-effort only.
    VideoCompress.deleteAllCache().catchError((Object e) {
      debugPrint('[PostUploadManager] VideoCompress.deleteAllCache error (plugin bug, safe to ignore): $e');
      return false; // required: deleteAllCache() returns Future<bool>
    }).ignore();
  }

  /// Shows Android progress notification.
  /// [title] appears as the notification title; [phaseMessage] is the body.
  Future<void> _showProgressNotification(
    int overallPercent,
    String phaseMessage, {
    String title = 'Uploading post…',
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Post upload status',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: 100,
        progress: overallPercent,
        ongoing: true,
        onlyAlertOnce: true,
        icon: '@mipmap/launcher_icon',
      );
      final notificationDetails = NotificationDetails(android: androidDetails);
      await _localNotifications.show(
        _notificationId,
        title,
        '$phaseMessage ($overallPercent%)',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('[PostUploadManager] Failed to show progress notification: $e');
    }
  }

  Future<void> _showSuccessNotification(int? postId) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Post upload status',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
      );
      const notificationDetails = NotificationDetails(android: androidDetails);
      // Payload format: "post:<postId>" — handled in notification_service.dart.
      // When postId is null (e.g., edit flow) we pass null so no navigation happens.
      final payload = postId != null ? 'post:$postId' : null;
      await _localNotifications.show(
        _notificationId,
        'Post uploaded',
        'Tap to view',
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[PostUploadManager] Failed to show success notification: $e');
    }
  }

  Future<void> _showFailedNotification({bool isSizeError = false}) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Post upload status',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
      );
      const notificationDetails = NotificationDetails(android: androidDetails);
      // Size errors cannot be fixed by retrying the same file — omit retry payload
      // so tapping the notification does not re-queue a doomed upload.
      final body = isSizeError
          ? 'File is too large. Please choose a smaller file.'
          : 'Tap to retry';
      final payload = isSizeError ? null : 'retry_post_upload';
      await _localNotifications.show(
        _notificationId,
        'Upload failed',
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[PostUploadManager] Failed to show failed notification: $e');
    }
  }

  Future<void> start(PostUploadTask task) async {
    if (_running != null) {
      throw Exception('Another post upload is already running');
    }

    _currentTask = task;
    final isVideo = task.type == 'VIDEO' || task.type == 'REEL';
    final prepMsg = isVideo ? 'Preparing video…' : 'Preparing post…';
    final notifTitle = isVideo ? 'Uploading video…' : 'Uploading post…';

    state.value = PostUploadState(
      inProgress: true,
      overallProgress: 0.02,
      phaseProgress: 0,
      message: prepMsg,
      done: false,
      status: PostUploadStatus.preparing,
    );
    await _showProgressNotification(2, prepMsg, title: notifTitle);

    _running = _run(task).whenComplete(() {
      _running = null;
    });

    return _running!;
  }

  Future<void> retry() async {
    final task = _currentTask;
    if (task == null) return;
    if (_running != null) return;

    // Rebuild drafts: any draft whose media upload already succeeded in the
    // previous attempt is kept with its existingId so we don't re-upload it.
    // Media IDs recorded here belong to the current user (they were uploaded
    // by this session), so ownership is guaranteed.
    if (_uploadedDraftMediaIds.isNotEmpty) {
      final newDrafts = List<PostUploadDraft>.from(task.drafts);
      for (final entry in _uploadedDraftMediaIds.entries) {
        final i = entry.key;
        if (i < newDrafts.length && newDrafts[i].existingId == null) {
          newDrafts[i] = PostUploadDraft(
            existingId: entry.value,
            file: newDrafts[i].file,
            type: newDrafts[i].type,
          );
        }
      }
      _currentTask = PostUploadTask(
        id: task.id,
        type: task.type,
        caption: task.caption,
        drafts: newDrafts,
        trimStartMs: task.trimStartMs,
        trimEndMs: task.trimEndMs,
        mute: task.mute,
        volume: task.volume,
        privacy: task.privacy,
        editPostId: task.editPostId,
        backgroundStyle: task.backgroundStyle,
      );
    }

    await start(_currentTask!);
  }

  Future<void> _run(PostUploadTask task) async {
    // Clear any stale draft-upload records from a previous attempt of this task.
    _uploadedDraftMediaIds.clear();
    final isVideoTask = task.type == 'VIDEO' || task.type == 'REEL';
    final notifTitle = isVideoTask ? 'Uploading video…' : 'Uploading post…';
    try {
      final mediaIds = <int>[];
      final newLocalDrafts =
          task.drafts.where((x) => x.existingId == null).toList();

      for (int i = 0; i < task.drafts.length; i++) {
        final d = task.drafts[i];
        if (d.existingId != null) {
          mediaIds.add(d.existingId!);
          continue;
        }

        final file = d.file;
        if (file == null) continue;

        File uploadFile = file;

        final size = await file.length();
        final maxBytes = (d.type == 'VIDEO' || d.type == 'REEL')
            ? _maxVideoBytes
            : _maxImageBytes;
        debugPrint(
          '[PostUploadManager] Pre-upload validation — '
          'path=${file.path} '
          'sizeBytes=$size sizeFormatted=${_formatFileSize(size)} '
          'maxBytes=$maxBytes maxFormatted=${_formatFileSize(maxBytes)} '
          'mediaType=${d.type}',
        );
        if (size > maxBytes) {
          final mediaLabel =
              (d.type == 'VIDEO' || d.type == 'REEL') ? 'video' : 'image';
          throw Exception(
            'FILE_TOO_LARGE: This $mediaLabel is ${_formatFileSize(size)}. '
            'Maximum allowed size is ${_formatFileSize(maxBytes)}.',
          );
        }

        if (d.type == 'VIDEO') {
          uploadFile = await _prepareVideoForUpload(file);
        }

        // Full pre-upload diagnostics — logged to Dart console before any bytes
        // are sent so the developer can verify the exact file and size used.
        final finalUploadSize = await uploadFile.length();
        final compressionAttempted = d.type == 'VIDEO';
        final compressionSucceeded =
            compressionAttempted && uploadFile.path != file.path;
        debugPrint(
          '[PostUploadManager] Pre-upload diagnostics:\n'
          '  originalFilePath: ${file.path}\n'
          '  originalSizeBytes: $size\n'
          '  originalSizeFormatted: ${_formatFileSize(size)}\n'
          '  compressionAttempted: $compressionAttempted\n'
          '  compressionSucceeded: $compressionSucceeded\n'
          '  compressedFilePath: ${compressionSucceeded ? uploadFile.path : 'n/a'}\n'
          '  compressedSizeBytes: ${compressionSucceeded ? finalUploadSize : 'n/a'}\n'
          '  finalUploadFilePath: ${uploadFile.path}\n'
          '  finalUploadSizeBytes: $finalUploadSize\n'
          '  finalUploadSizeFormatted: ${_formatFileSize(finalUploadSize)}\n'
          '  maxBytes: $maxBytes\n'
          '  maxFormatted: ${_formatFileSize(maxBytes)}\n'
          '  withinLimit: ${finalUploadSize <= maxBytes}',
        );
        // Second guard: compressed file could in theory be larger than original.
        if (finalUploadSize > maxBytes) {
          final mediaLabel =
              (d.type == 'VIDEO' || d.type == 'REEL') ? 'video' : 'image';
          throw Exception(
            'FILE_TOO_LARGE: This $mediaLabel is ${_formatFileSize(finalUploadSize)}. '
            'Maximum allowed size is ${_formatFileSize(maxBytes)}.',
          );
        }

        final localIndex = newLocalDrafts.indexOf(d);
        final label =
            newLocalDrafts.length > 1
                ? 'Uploading ${localIndex + 1}/${newLocalDrafts.length}…'
                : (d.type == 'VIDEO' ? 'Uploading video…' : 'Uploading post…');
        const uploadOverallStart = 0.25;
        state.value = state.value.copyWith(
          status: PostUploadStatus.uploading,
          message: label,
          overallProgress: uploadOverallStart,
          phaseProgress: 0,
        );
        await _showProgressNotification(
          (uploadOverallStart * 100).toInt(),
          label,
          title: notifTitle,
        );

        final uploadStartTime = DateTime.now();
        final id = await _ds.uploadMediaWithProgress(
          uploadFile,
          trimStartMs: d.type == 'VIDEO' ? task.trimStartMs : null,
          trimEndMs: d.type == 'VIDEO' ? task.trimEndMs : null,
          mute: d.type == 'VIDEO' ? task.mute : null,
          volume: d.type == 'VIDEO' ? task.volume : null,
          onProgress: (sent, total) {
            if (!_shouldEmitProgress()) return;
            final stepProgress = sent / total;
            final queueProgress =
                (localIndex + stepProgress) / newLocalDrafts.length;
            final overall = _uploadingOverall(queueProgress);
            state.value = state.value.copyWith(
              overallProgress: overall,
              phaseProgress: stepProgress,
              message: label,
            );
            _showProgressNotification(
              (overall * 100).toInt(),
              label,
              title: notifTitle,
            );
          },
        );
        final uploadDuration = DateTime.now().difference(uploadStartTime);
        debugPrint(
          '[PostUploadManager] Upload duration: ${uploadDuration.inMilliseconds}ms',
        );
        // Record this draft's media ID so retry() can skip re-uploading it.
        _uploadedDraftMediaIds[i] = id;
        mediaIds.add(id);
      }

      const processingOverallStart = 0.90;
      final isVideoPost = task.type == 'VIDEO' || task.type == 'REEL';
      final processingLabel = isVideoPost ? 'Server processing…' : 'Processing…';
      state.value = state.value.copyWith(
        status: PostUploadStatus.processing,
        message: processingLabel,
        overallProgress: processingOverallStart,
        phaseProgress: 0,
      );
      await _showProgressNotification(
        (processingOverallStart * 100).toInt(),
        processingLabel,
        title: notifTitle,
      );

      final apiStart = DateTime.now();
      int? createdPostId;
      DateTime? createdAt;

      if (task.editPostId != null) {
        await _ds.updatePost(
          postId: task.editPostId!,
          caption: task.caption,
          mediaIds: mediaIds,
        );
        createdPostId = task.editPostId;
      } else {
        final created = await _ds.createPost(
          type: task.type,
          caption: task.caption,
          mediaIds: mediaIds,
          privacy: task.privacy,
          backgroundStyle: task.backgroundStyle,
        );
        debugPrint(
          '[PostUploadManager] API response time: ${DateTime.now().difference(apiStart).inMilliseconds}ms',
        );
        createdPostId = created.id;
        createdAt = created.createdAt;

        try {
          await AnalyticsService.instance.logPostCreated(
            postType: task.type,
            postId: created.id,
          );
        } catch (_) {}
      }

      state.value = state.value.copyWith(
        inProgress: false,
        overallProgress: 1.0,
        phaseProgress: 1.0,
        message: 'Posted',
        done: true,
        status: PostUploadStatus.posted,
        error: null,
        createdPostId: createdPostId,
        createdAt: createdAt,
      );
      debugPrint(
        '[PostUploadManager] Upload complete. mediaIds=$mediaIds createdPostId=$createdPostId',
      );
      await _showSuccessNotification(createdPostId);
      Future.delayed(const Duration(seconds: 3), () {
        if (state.value.status == PostUploadStatus.posted) {
          reset();
        }
      });
    } catch (e) {
      debugPrint('[PostUploadManager] Error: $e');
      String errMsg = e.toString().replaceFirst('Exception: ', '');
      bool isSizeError = false;

      if (errMsg.startsWith('FILE_TOO_LARGE: ')) {
        // Local pre-validation — message is already user-readable.
        isSizeError = true;
        errMsg = errMsg.replaceFirst('FILE_TOO_LARGE: ', '');
      } else if (errMsg.contains('FILE_TOO_LARGE')) {
        // Backend rejected the upload — try to parse max size from response JSON.
        isSizeError = true;
        int? backendMaxMb;
        try {
          final jsonStart = errMsg.indexOf('{');
          if (jsonStart >= 0) {
            final data =
                jsonDecode(errMsg.substring(jsonStart)) as Map<String, dynamic>;
            backendMaxMb = (data['meta']?['maxSizeMb'] as num?)?.toInt();
          }
        } catch (_) {}
        final maxStr = backendMaxMb != null ? '${backendMaxMb}MB' : '200MB';
        errMsg = 'This file is too large. Maximum allowed size is $maxStr.';
      } else if (errMsg.contains('401') || errMsg.contains('Unauthorized')) {
        errMsg = 'You are not allowed to upload this media. Please log in again.';
      } else if (errMsg.contains('network') || errMsg.contains('Connection') ||
                 errMsg.contains('SocketException') || errMsg.contains('timeout')) {
        errMsg = 'Network problem. Please check your connection.';
      } else if (errMsg.contains('500') || errMsg.startsWith('Upload failed (5')) {
        errMsg = 'Upload failed due to a server issue. Please try again.';
      } else if (errMsg.contains('Cannot find module') ||
                 errMsg.contains('require stack') ||
                 errMsg.contains('.ts') && errMsg.contains('common/queue')) {
        errMsg = 'Upload failed due to a server issue. Please try again.';
      }

      state.value = state.value.copyWith(
        inProgress: false,
        done: true,
        error: errMsg,
        message: 'Failed',
        status: PostUploadStatus.failed,
      );
      await _showFailedNotification(isSizeError: isSizeError);
    }
  }

  /// Prepares the video file for upload (no client-side compression).
  /// The original file is uploaded as-is; the server worker handles transcoding.
  Future<File> _prepareVideoForUpload(File file) async {
    final originalSize = await file.length();
    debugPrint(
      '[PostUploadManager] Video size: ${(originalSize / 1024 / 1024).toStringAsFixed(1)} MB — uploading original.',
    );
    state.value = state.value.copyWith(
      status: PostUploadStatus.compressing,
      message: 'Preparing video…',
      overallProgress: 0.25,
      phaseProgress: 1.0,
    );
    await _showProgressNotification(
      25,
      'Preparing video…',
      title: 'Uploading video…',
    );
    return file;
  }
}
