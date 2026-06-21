import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/posts/data/datasources/posts_remote_ds.dart';

class PostUploadState {
  final bool inProgress;
  final double progress; // 0..1
  final String message;
  final bool done;
  final String? error;

  const PostUploadState({
    required this.inProgress,
    required this.progress,
    required this.message,
    required this.done,
    this.error,
  });

  factory PostUploadState.idle() => const PostUploadState(
    inProgress: false,
    progress: 0,
    message: '',
    done: false,
  );

  PostUploadState copyWith({
    bool? inProgress,
    double? progress,
    String? message,
    bool? done,
    String? error,
  }) {
    return PostUploadState(
      inProgress: inProgress ?? this.inProgress,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      done: done ?? this.done,
      error: error,
    );
  }
}

/// A lightweight global uploader so the user can leave the Create screen
/// and still see progress on the Home screen.
class PostUploadManager {
  PostUploadManager._();
  static final PostUploadManager instance = PostUploadManager._();

  final ValueNotifier<PostUploadState> state = ValueNotifier(
    PostUploadState.idle(),
  );

  final PostsRemoteDs _ds = PostsRemoteDs();
  Future<void>? _running;

  bool get isBusy => state.value.inProgress;

  void reset() {
    state.value = PostUploadState.idle();
  }

  /// Starts an upload+post flow in background (within the app process).
  /// If another upload is running, it will throw.
  Future<void> start({
    required String type,
    String? caption,
    List<File> images = const [],
    List<File> files = const [],
    File? video,
    int? trimStartMs,
    int? trimEndMs,
    bool? mute,
    double? volume,
  }) async {
    if (_running != null) {
      throw Exception('Another post upload is already running');
    }

    state.value = const PostUploadState(
      inProgress: true,
      progress: 0,
      message: 'Uploading…',
      done: false,
    );

    _running =
        _run(
          type: type,
          caption: caption,
          images: images,
          files: files,
          video: video,
          trimStartMs: trimStartMs,
          trimEndMs: trimEndMs,
          mute: mute,
          volume: volume,
        ).whenComplete(() {
          _running = null;
        });

    return _running!;
  }

  Future<void> _run({
    required String type,
    String? caption,
    required List<File> images,
    required List<File> files,
    File? video,
    int? trimStartMs,
    int? trimEndMs,
    bool? mute,
    double? volume,
  }) async {
    try {
      final mediaIds = <int>[];

      // Build upload queue
      final queue = <File>[];
      if (type == 'IMAGE') {
        queue.addAll(images);
        queue.addAll(files);
      } else if (type == 'VIDEO' || type == 'REEL') {
        if (video != null) queue.add(video);
      }

      final totalSteps = queue.isEmpty
          ? 1
          : (queue.length + 1); // +1 for createPost
      int completedSteps = 0;

      void setOverallProgress(double stepProgress, {String? msg}) {
        final overall =
            ((completedSteps + stepProgress).clamp(0, totalSteps.toDouble())) /
            totalSteps;
        state.value = state.value.copyWith(
          progress: overall.clamp(0, 1),
          message: msg ?? state.value.message,
        );
      }

      for (int i = 0; i < queue.length; i++) {
        final f = queue[i];
        final label = 'Uploading ${i + 1}/${queue.length}…';
        state.value = state.value.copyWith(message: label);

        final id = await _ds.uploadMediaWithProgress(
          f,
          trimStartMs: (type == 'VIDEO' || type == 'REEL') ? trimStartMs : null,
          trimEndMs: (type == 'VIDEO' || type == 'REEL') ? trimEndMs : null,
          mute: (type == 'VIDEO' || type == 'REEL') ? mute : null,
          volume: (type == 'VIDEO' || type == 'REEL') ? volume : null,
        );
        mediaIds.add(id);
        completedSteps++;
        setOverallProgress(0, msg: label);
      }

      // Create post
      state.value = state.value.copyWith(message: 'Publishing…');
      setOverallProgress(0.2, msg: 'Publishing…');
      await _ds.createPost(type: type, caption: caption, mediaIds: mediaIds);
      completedSteps++;
      setOverallProgress(1, msg: 'Done');

      state.value = state.value.copyWith(
        inProgress: false,
        progress: 1,
        message: 'Posted successfully',
        done: true,
        error: null,
      );
    } catch (e) {
      state.value = state.value.copyWith(
        inProgress: false,
        done: true,
        error: e.toString().replaceFirst('Exception: ', ''),
        message: 'Failed',
      );
      rethrow;
    }
  }
}
