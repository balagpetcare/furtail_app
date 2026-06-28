import 'dart:io';

import 'package:furtail_app/core/media/media_url.dart';

class AdoptionDraftMediaItem {
  final String id;
  final File file;
  final String type;
  final File? thumbnail;
  final int? trimStartMs;
  final int? trimEndMs;
  final bool mute;
  final double volume;
  final String? aspectRatio;
  final String? quality;
  final int? coverTimestampMs;
  final String? url;

  const AdoptionDraftMediaItem({
    required this.id,
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
    this.url,
  });

  factory AdoptionDraftMediaItem.image(File file) {
    return AdoptionDraftMediaItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      file: file,
      type: 'IMAGE',
    );
  }

  factory AdoptionDraftMediaItem.video({
    required File file,
    File? thumbnail,
    int? trimStartMs,
    int? trimEndMs,
    bool mute = false,
    double volume = 1.0,
    String? aspectRatio,
    String? quality,
    int? coverTimestampMs,
  }) {
    return AdoptionDraftMediaItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
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
  }

  AdoptionDraftMediaItem copyWith({
    File? file,
    String? type,
    File? thumbnail,
    int? trimStartMs,
    int? trimEndMs,
    bool? mute,
    double? volume,
    String? aspectRatio,
    String? quality,
    int? coverTimestampMs,
    String? url,
  }) {
    return AdoptionDraftMediaItem(
      id: id,
      file: file ?? this.file,
      type: type ?? this.type,
      thumbnail: thumbnail ?? this.thumbnail,
      trimStartMs: trimStartMs ?? this.trimStartMs,
      trimEndMs: trimEndMs ?? this.trimEndMs,
      mute: mute ?? this.mute,
      volume: volume ?? this.volume,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      quality: quality ?? this.quality,
      coverTimestampMs: coverTimestampMs ?? this.coverTimestampMs,
      url: url ?? this.url,
    );
  }

  bool get isVideo => type.toUpperCase() == 'VIDEO';
  bool get isImage => type.toUpperCase() == 'IMAGE';
}

class AdoptionMediaUiModel {
  final int? id;
  final String url;
  final String? hlsUrl;
  final String? thumbnailUrl;
  final String type;
  final String? status;
  final String? mimeType;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? localFilePath;

  const AdoptionMediaUiModel({
    required this.id,
    required this.url,
    required this.type,
    this.hlsUrl,
    this.thumbnailUrl,
    this.status,
    this.mimeType,
    this.width,
    this.height,
    this.durationMs,
    this.localFilePath,
  });

  bool get isVideo {
    final normalizedType = type.toUpperCase();
    final normalizedMime = (mimeType ?? '').toLowerCase();
    return normalizedType == 'VIDEO' || normalizedMime.startsWith('video/');
  }

  bool get isImage {
    final normalizedType = type.toUpperCase();
    final normalizedMime = (mimeType ?? '').toLowerCase();
    return normalizedType == 'IMAGE' || normalizedMime.startsWith('image/');
  }

  bool get hasThumbnail => (thumbnailUrl ?? '').trim().isNotEmpty;

  String get displayUrl => url.trim();
  String get playbackUrl {
    final hls = hlsUrl?.trim() ?? '';
    if (hls.isNotEmpty) return hls;
    return displayUrl;
  }

  String? get previewImageUrl {
    final thumb = thumbnailUrl?.trim() ?? '';
    if (thumb.isNotEmpty) return thumb;
    final display = displayUrl;
    if (isImage && display.isNotEmpty) return display;
    return null;
  }

  factory AdoptionMediaUiModel.fromApiJson(dynamic raw) {
    final json = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    final media = (json['media'] is Map)
        ? Map<String, dynamic>.from(json['media'] as Map)
        : json;

    final rawType = _asString(media['type'] ?? json['type']);
    final mimeType = _asString(media['mimeType'] ?? media['mimetype'] ?? json['mimeType'] ?? json['mimetype']);
    final url = MediaUrl.normalize(
      _asString(media['url'] ?? media['videoUrl'] ?? json['url'] ?? json['videoUrl']),
    );
    final hlsUrl = MediaUrl.normalize(
      _asString(media['hlsUrl'] ?? media['hls_url'] ?? json['hlsUrl'] ?? json['hls_url']),
    );
    final thumbnailUrl = MediaUrl.normalize(_asString(
      media['thumbnailUrl'] ?? media['thumbUrl'] ?? json['thumbnailUrl'] ?? json['thumbUrl'],
    ));
    final type = _normalizeType(rawType, mimeType, hlsUrl.isNotEmpty ? hlsUrl : url);

    return AdoptionMediaUiModel(
      id: _asIntOrNull(media['id'] ?? json['id'] ?? media['mediaId'] ?? json['mediaId']),
      url: url,
      hlsUrl: hlsUrl.isNotEmpty ? hlsUrl : null,
      thumbnailUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : null,
      type: type,
      status: _asString(media['status'] ?? json['status']).isNotEmpty
          ? _asString(media['status'] ?? json['status'])
          : null,
      mimeType: mimeType.isNotEmpty ? mimeType : null,
      width: _asIntOrNull(media['width'] ?? json['width']),
      height: _asIntOrNull(media['height'] ?? json['height']),
      durationMs: _asIntOrNull(
        media['durationMs'] ??
            media['duration'] ??
            media['durationSeconds'] ??
            json['durationMs'] ??
            json['duration'] ??
            json['durationSeconds'],
      ),
      localFilePath: _asString(media['localFilePath'] ?? media['localPath'] ?? json['localFilePath'] ?? json['localPath'])
          .trim()
          .isNotEmpty
          ? _asString(
              media['localFilePath'] ?? media['localPath'] ?? json['localFilePath'] ?? json['localPath'],
            )
          : null,
    );
  }

  static String _normalizeType(String rawType, String mimeType, String url) {
    final type = rawType.trim().toUpperCase();
    final mime = mimeType.trim().toLowerCase();
    if (type == 'VIDEO' || mime.startsWith('video/')) return 'VIDEO';
    if (type == 'IMAGE' || mime.startsWith('image/')) return 'IMAGE';
    final lowerUrl = url.toLowerCase();
    if (RegExp(r'\.(mp4|mov|m4v|webm|mkv|avi)(\?|$)').hasMatch(lowerUrl)) return 'VIDEO';
    if (RegExp(r'\.(png|jpe?g|gif|webp)(\?|$)').hasMatch(lowerUrl)) return 'IMAGE';
    return type.isNotEmpty ? type : 'IMAGE';
  }

  static String _asString(dynamic value) => value?.toString().trim() ?? '';
  static int? _asIntOrNull(dynamic value) => int.tryParse(value?.toString() ?? '');
}
