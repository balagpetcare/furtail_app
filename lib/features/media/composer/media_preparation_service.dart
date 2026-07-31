import 'dart:io';

import 'package:flutter/material.dart';
import 'package:furtail_app/core/media/image_editor_screen.dart';
import 'package:furtail_app/core/media/media_policy.dart';
import 'package:furtail_app/core/media/video_edit_screen.dart';
import 'package:furtail_app/features/media/composer/media_draft_item.dart';
import 'package:furtail_app/features/media/data/authenticated_media_uploader.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
    return Future.wait(
      edited.files.map((file) async {
        final materialized = await _materializeMediaFile(
          file,
          maxBytes: MediaPolicy.maxImageBytes,
        );
        return MediaDraftItem.image(
          id: _draftId(),
          localPath: materialized.path,
          fileName: _fileName(materialized.path),
          originalSizeBytes: await materialized.length(),
        );
      }),
    );
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
    File? materializedThumb;
    if (thumb != null) {
      try {
        materializedThumb = await _materializeMediaFile(
          thumb,
          maxBytes: MediaPolicy.maxImageBytes,
        );
      } catch (_) {
        materializedThumb = null;
      }
    }

    final materialized = await _materializeMediaFile(
      edited.file,
      maxBytes: MediaPolicy.maxVideoBytes,
    );

    return MediaDraftItem.video(
      id: existingId ?? _draftId(),
      localPath: materialized.path,
      fileName: _fileName(materialized.path),
      originalSizeBytes: await materialized.length(),
      thumbnailPath: materializedThumb?.path,
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

  Future<List<MediaDraftItem>> prepareDocuments(List<File> files) {
    return Future.wait(
      files.map((file) async {
        final materialized = await _materializeMediaFile(
          file,
          maxBytes: MediaPolicy.maxFileBytes,
        );
        return MediaDraftItem.document(
          id: _draftId(),
          localPath: materialized.path,
          fileName: _fileName(materialized.path),
          originalSizeBytes: await materialized.length(),
        );
      }),
    );
  }

  Future<MediaDraftItem> prepareReplacementDocument(
    File file, {
    required String existingId,
    required bool isCover,
  }) async {
    final materialized = await _materializeMediaFile(
      file,
      maxBytes: MediaPolicy.maxFileBytes,
    );
    return MediaDraftItem.document(
      id: existingId,
      localPath: materialized.path,
      fileName: _fileName(materialized.path),
      originalSizeBytes: await materialized.length(),
      isCover: isCover,
    );
  }

  String _draftId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<File> _materializeMediaFile(
    File source, {
    required int maxBytes,
  }) async {
    if (!await source.exists()) {
      throw const MediaUploadException(
        kind: MediaUploadErrorKind.invalidPayload,
        userMessage:
            'The selected file could not be found. Please choose it again.',
      );
    }

    final size = await source.length();
    if (size <= 0) {
      throw const MediaUploadException(
        kind: MediaUploadErrorKind.invalidPayload,
        userMessage:
            'The selected file is empty. Please choose a different file.',
      );
    }
    if (size > maxBytes) {
      final limitMb = (maxBytes / (1024 * 1024)).round();
      throw MediaUploadException(
        kind: MediaUploadErrorKind.fileTooLarge,
        userMessage:
            'The selected file is too large. Please choose a file under $limitMb MB.',
      );
    }

    final safeName = _sanitizeFileName(_fileName(source.path));
    final tempDir = await getTemporaryDirectory();
    final targetDir = Directory(p.join(tempDir.path, 'furtail-media'));
    await targetDir.create(recursive: true);

    final target = File(
      p.join(
        targetDir.path,
        '${DateTime.now().microsecondsSinceEpoch}-$safeName',
      ),
    );
    await source.copy(target.path);
    return target;
  }

  String _fileName(String path) => p.basename(path);

  String _sanitizeFileName(String name) {
    final trimmed = name.trim();
    final normalized = trimmed.replaceAll(
      RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
      '_',
    );
    if (normalized.isEmpty) return 'upload.bin';
    if (normalized.length <= 120) return normalized;
    final ext = p.extension(normalized);
    final stem = normalized.substring(0, normalized.length - ext.length);
    final allowedStemLength = 120 - ext.length;
    if (allowedStemLength <= 0) return normalized.substring(0, 120);
    return '${stem.substring(0, allowedStemLength)}$ext';
  }
}
