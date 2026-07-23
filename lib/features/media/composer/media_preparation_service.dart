import 'dart:io';

import 'package:flutter/material.dart';
import 'package:furtail_app/core/media/image_editor_screen.dart';
import 'package:furtail_app/core/media/video_edit_screen.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';
import 'package:video_compress/video_compress.dart';

class MediaPreparationService {
  const MediaPreparationService();

  Future<List<MediaDraftItem>> prepareImages(
    BuildContext context,
    List<File> files, {
    int initialIndex = 0,
  }) async {
    final edited = await Navigator.of(context).push<ImageEditResult>(
      MaterialPageRoute(
        builder: (_) =>
            ImageEditorScreen(files: files, initialIndex: initialIndex),
      ),
    );
    if (edited == null || edited.files.isEmpty) return const <MediaDraftItem>[];
    return edited.files.map((file) {
      return MediaDraftItem.image(
        id: _draftId(),
        localPath: file.path,
        fileName: _fileName(file.path),
        originalSizeBytes: file.existsSync() ? file.lengthSync() : 0,
      );
    }).toList();
  }

  Future<MediaDraftItem?> prepareReplacementImage(
    BuildContext context,
    File file, {
    required String existingId,
    required bool isCover,
  }) async {
    final results = await prepareImages(context, <File>[file]);
    if (results.isEmpty) return null;
    final result = results.first;
    return MediaDraftItem.image(
      id: existingId,
      localPath: result.localPath ?? file.path,
      fileName: result.fileName,
      originalSizeBytes: result.originalSizeBytes,
      isCover: isCover,
    );
  }

  Future<MediaDraftItem?> prepareVideo(
    BuildContext context,
    File file, {
    String? existingId,
    bool isCover = false,
  }) async {
    final edited = await Navigator.of(context).push<VideoEditResult>(
      MaterialPageRoute(builder: (_) => VideoEditScreen(file: file)),
    );
    if (edited == null) return null;

    File? thumb;
    try {
      thumb = edited.coverTimestampMs != null
          ? await VideoCompress.getFileThumbnail(
              edited.file.path,
              quality: 60,
              position: edited.coverTimestampMs!,
            )
          : await VideoCompress.getFileThumbnail(edited.file.path, quality: 50);
    } catch (_) {
      thumb = null;
    }

    return MediaDraftItem.video(
      id: existingId ?? _draftId(),
      localPath: edited.file.path,
      fileName: _fileName(edited.file.path),
      originalSizeBytes: edited.file.existsSync()
          ? edited.file.lengthSync()
          : 0,
      thumbnailPath: thumb?.path,
      trimStartMs: edited.trimStartMs,
      trimEndMs: edited.trimEndMs,
      mute: edited.mute,
      volume: edited.volume,
      aspectRatio: edited.aspectRatio,
      quality: edited.quality,
      coverTimestampMs: edited.coverTimestampMs,
      isCover: isCover,
    );
  }

  List<MediaDraftItem> prepareDocuments(List<File> files) {
    return files.map((file) {
      return MediaDraftItem.document(
        id: _draftId(),
        localPath: file.path,
        fileName: _fileName(file.path),
        originalSizeBytes: file.existsSync() ? file.lengthSync() : 0,
      );
    }).toList();
  }

  MediaDraftItem prepareReplacementDocument(
    File file, {
    required String existingId,
    required bool isCover,
  }) {
    return MediaDraftItem.document(
      id: existingId,
      localPath: file.path,
      fileName: _fileName(file.path),
      originalSizeBytes: file.existsSync() ? file.lengthSync() : 0,
      isCover: isCover,
    );
  }

  String _draftId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _fileName(String path) => path.split(Platform.pathSeparator).last;
}
