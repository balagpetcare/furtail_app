import 'dart:convert';

enum MediaDraftType { image, video, document }

enum MediaDraftState {
  local,
  preparing,
  uploading,
  uploaded,
  processing,
  ready,
  failed,
  cancelled,
}

class MediaDraftItem {
  const MediaDraftItem({
    required this.id,
    required this.type,
    required this.fileName,
    required this.originalSizeBytes,
    this.localPath,
    this.remoteMediaId,
    this.remoteUrl,
    this.remoteHlsUrl,
    this.remoteThumbnailUrl,
    this.remoteStatus,
    this.mimeType,
    this.thumbnailPath,
    this.trimStartMs,
    this.trimEndMs,
    this.mute = false,
    this.volume = 1.0,
    this.aspectRatio,
    this.quality,
    this.coverTimestampMs,
    this.state = MediaDraftState.local,
    this.progress = 0,
    this.errorMessage,
    this.isCover = false,
  });

  final String id;
  final MediaDraftType type;
  final String fileName;
  final int originalSizeBytes;
  final String? localPath;
  final int? remoteMediaId;
  final String? remoteUrl;
  final String? remoteHlsUrl;
  final String? remoteThumbnailUrl;
  final String? remoteStatus;
  final String? mimeType;
  final String? thumbnailPath;
  final int? trimStartMs;
  final int? trimEndMs;
  final bool mute;
  final double volume;
  final String? aspectRatio;
  final String? quality;
  final int? coverTimestampMs;
  final MediaDraftState state;
  final double progress;
  final String? errorMessage;
  final bool isCover;

  factory MediaDraftItem.image({
    required String id,
    required String localPath,
    required String fileName,
    required int originalSizeBytes,
    bool isCover = false,
  }) {
    return MediaDraftItem(
      id: id,
      type: MediaDraftType.image,
      localPath: localPath,
      fileName: fileName,
      originalSizeBytes: originalSizeBytes,
      isCover: isCover,
    );
  }

  factory MediaDraftItem.video({
    required String id,
    required String localPath,
    required String fileName,
    required int originalSizeBytes,
    String? thumbnailPath,
    int? trimStartMs,
    int? trimEndMs,
    bool mute = false,
    double volume = 1.0,
    String? aspectRatio,
    String? quality,
    int? coverTimestampMs,
    bool isCover = false,
  }) {
    return MediaDraftItem(
      id: id,
      type: MediaDraftType.video,
      localPath: localPath,
      fileName: fileName,
      originalSizeBytes: originalSizeBytes,
      thumbnailPath: thumbnailPath,
      trimStartMs: trimStartMs,
      trimEndMs: trimEndMs,
      mute: mute,
      volume: volume,
      aspectRatio: aspectRatio,
      quality: quality,
      coverTimestampMs: coverTimestampMs,
      isCover: isCover,
    );
  }

  factory MediaDraftItem.document({
    required String id,
    required String localPath,
    required String fileName,
    required int originalSizeBytes,
    String? mimeType,
    bool isCover = false,
  }) {
    return MediaDraftItem(
      id: id,
      type: MediaDraftType.document,
      localPath: localPath,
      fileName: fileName,
      originalSizeBytes: originalSizeBytes,
      mimeType: mimeType,
      isCover: isCover,
    );
  }

  bool get isImage => type == MediaDraftType.image;
  bool get isVideo => type == MediaDraftType.video;
  bool get isDocument => type == MediaDraftType.document;
  bool get isUploading => state == MediaDraftState.uploading;
  bool get isPreparing => state == MediaDraftState.preparing;
  bool get hasFailed => state == MediaDraftState.failed;
  bool get isCancelled => state == MediaDraftState.cancelled;
  bool get isReadyForSubmit =>
      remoteMediaId != null &&
      (state == MediaDraftState.ready || state == MediaDraftState.uploaded);
  bool get blocksSubmission =>
      state == MediaDraftState.failed ||
      state == MediaDraftState.cancelled ||
      state == MediaDraftState.preparing ||
      state == MediaDraftState.uploading ||
      state == MediaDraftState.processing;

  String? get previewUrl {
    final hls = remoteHlsUrl?.trim();
    if (hls != null && hls.isNotEmpty) return hls;
    final url = remoteUrl?.trim();
    if (url != null && url.isNotEmpty) return url;
    return null;
  }

  MediaDraftItem copyWith({
    String? localPath,
    int? remoteMediaId,
    bool clearRemoteMediaId = false,
    String? remoteUrl,
    String? remoteHlsUrl,
    String? remoteThumbnailUrl,
    String? remoteStatus,
    String? mimeType,
    String? thumbnailPath,
    int? trimStartMs,
    int? trimEndMs,
    bool? mute,
    double? volume,
    String? aspectRatio,
    String? quality,
    int? coverTimestampMs,
    MediaDraftState? state,
    double? progress,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isCover,
  }) {
    return MediaDraftItem(
      id: id,
      type: type,
      fileName: fileName,
      originalSizeBytes: originalSizeBytes,
      localPath: localPath ?? this.localPath,
      remoteMediaId: clearRemoteMediaId
          ? null
          : (remoteMediaId ?? this.remoteMediaId),
      remoteUrl: remoteUrl ?? this.remoteUrl,
      remoteHlsUrl: remoteHlsUrl ?? this.remoteHlsUrl,
      remoteThumbnailUrl: remoteThumbnailUrl ?? this.remoteThumbnailUrl,
      remoteStatus: remoteStatus ?? this.remoteStatus,
      mimeType: mimeType ?? this.mimeType,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      trimStartMs: trimStartMs ?? this.trimStartMs,
      trimEndMs: trimEndMs ?? this.trimEndMs,
      mute: mute ?? this.mute,
      volume: volume ?? this.volume,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      quality: quality ?? this.quality,
      coverTimestampMs: coverTimestampMs ?? this.coverTimestampMs,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      isCover: isCover ?? this.isCover,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'fileName': fileName,
      'originalSizeBytes': originalSizeBytes,
      'localPath': localPath,
      'remoteMediaId': remoteMediaId,
      'remoteUrl': remoteUrl,
      'remoteHlsUrl': remoteHlsUrl,
      'remoteThumbnailUrl': remoteThumbnailUrl,
      'remoteStatus': remoteStatus,
      'mimeType': mimeType,
      'thumbnailPath': thumbnailPath,
      'trimStartMs': trimStartMs,
      'trimEndMs': trimEndMs,
      'mute': mute,
      'volume': volume,
      'aspectRatio': aspectRatio,
      'quality': quality,
      'coverTimestampMs': coverTimestampMs,
      'state': state.name,
      'progress': progress,
      'errorMessage': errorMessage,
      'isCover': isCover,
    };
  }

  factory MediaDraftItem.fromJson(Map<String, dynamic> json) {
    return MediaDraftItem(
      id: json['id']?.toString() ?? '',
      type: MediaDraftType.values.byName(json['type']?.toString() ?? 'image'),
      fileName: json['fileName']?.toString() ?? '',
      originalSizeBytes: (json['originalSizeBytes'] as num?)?.toInt() ?? 0,
      localPath: json['localPath']?.toString(),
      remoteMediaId: (json['remoteMediaId'] as num?)?.toInt(),
      remoteUrl: json['remoteUrl']?.toString(),
      remoteHlsUrl: json['remoteHlsUrl']?.toString(),
      remoteThumbnailUrl: json['remoteThumbnailUrl']?.toString(),
      remoteStatus: json['remoteStatus']?.toString(),
      mimeType: json['mimeType']?.toString(),
      thumbnailPath: json['thumbnailPath']?.toString(),
      trimStartMs: (json['trimStartMs'] as num?)?.toInt(),
      trimEndMs: (json['trimEndMs'] as num?)?.toInt(),
      mute: json['mute'] == true,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      aspectRatio: json['aspectRatio']?.toString(),
      quality: json['quality']?.toString(),
      coverTimestampMs: (json['coverTimestampMs'] as num?)?.toInt(),
      state: MediaDraftState.values.byName(
        json['state']?.toString() ?? MediaDraftState.local.name,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      errorMessage: json['errorMessage']?.toString(),
      isCover: json['isCover'] == true,
    );
  }

  static String encodeList(List<MediaDraftItem> items) =>
      jsonEncode(items.map((item) => item.toJson()).toList());

  static List<MediaDraftItem> decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const <MediaDraftItem>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <MediaDraftItem>[];
    return decoded
        .whereType<Map>()
        .map(
          (entry) => MediaDraftItem.fromJson(Map<String, dynamic>.from(entry)),
        )
        .toList();
  }
}
