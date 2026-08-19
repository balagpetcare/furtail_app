import 'package:furtail_app/core/media/media_url.dart';

/// Adapted from the pre-phase3 snapshot's `resolveMediaUrl` (which assumed
/// an authenticated media-fetch layer that no longer exists) onto this
/// branch's plain URL normalization (`MediaUrl.normalize`).
String? resolveMediaUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return MediaUrl.normalize(raw);
}

/// Best-effort MIME type from a filename's extension — used only to render
/// a sensible *local* preview (image thumbnail vs. video vs. audio icon)
/// for an attachment that hasn't finished uploading yet, before the
/// server has ever seen it. Never used for validation/authorization —
/// that's the server's job (see COMMAND 01's independent MIME sniffing),
/// this is purely a client-side rendering hint that a wrong/unknown
/// extension degrades safely to `null` (generic file rendering).
String? guessMimeTypeFromFilename(String filename) {
  final ext = filename.toLowerCase().split('.').last;
  const byExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
  };
  return byExtension[ext];
}

/// Client-local send lifecycle for a message. `sent` covers every message
/// that has a real server id (whether it arrived via the send response, a
/// REST page fetch, or a realtime `message.created` event) — there is no
/// separate "delivered"/"read" per-message status in this phase (read
/// state is conversation-level, see `ConversationModel.unreadCount`).
enum MessageSendStatus { sent, pending, failed }

/// A single text message. While [status] is [MessageSendStatus.pending] or
/// [MessageSendStatus.failed], [id] is null — the row exists only on the
/// client until the server confirms it (or a retry succeeds), matching
/// [clientMessageId] to the eventual server row for de-duplication.
class MessageModel {
  final int? id;
  final int conversationId;
  final int senderId;
  final String body;
  final DateTime createdAt;
  final String clientMessageId;
  final MessageSendStatus status;

  /// Set once the message has been edited (see `editMessage` on the
  /// backend). Null for never-edited messages.
  final DateTime? editedAt;

  /// Set once the sender has deleted ("unsent") the message. The row stays
  /// in the thread as a tombstone — [body] is blanked server-side once this
  /// is set, so the UI renders a fixed "This message was removed" copy
  /// rather than any stored text.
  final DateTime? deletedAt;

  final List<MessageAttachmentModel> attachments;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.clientMessageId,
    required this.status,
    this.editedAt,
    this.deletedAt,
    this.attachments = const [],
  });

  bool get isPending => status == MessageSendStatus.pending;
  bool get isFailed => status == MessageSendStatus.failed;
  bool get isSent => status == MessageSendStatus.sent;
  bool get isEdited => editedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get hasAttachments => attachments.isNotEmpty;

  factory MessageModel.fromApi(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawConversationId = json['conversationId'];
    final rawSenderId = json['senderId'];

    final attachmentsList =
        (json['attachments'] as List?)
            ?.whereType<Map>()
            .map(
              (a) => MessageAttachmentModel.fromApi(a.cast<String, dynamic>()),
            )
            .toList() ??
        [];

    return MessageModel(
      id: rawId is num ? rawId.toInt() : null,
      conversationId: rawConversationId is num ? rawConversationId.toInt() : 0,
      senderId: rawSenderId is num ? rawSenderId.toInt() : 0,
      body: (json['body'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      clientMessageId: (json['clientMessageId'] ?? '').toString(),
      status: MessageSendStatus.sent,
      editedAt: DateTime.tryParse(
        json['editedAt']?.toString() ?? '',
      )?.toLocal(),
      deletedAt: DateTime.tryParse(
        json['deletedAt']?.toString() ?? '',
      )?.toLocal(),
      attachments: attachmentsList,
    );
  }

  factory MessageModel.optimistic({
    required int conversationId,
    required int senderId,
    required String body,
    required String clientMessageId,
    List<MessageAttachmentModel> attachments = const [],
  }) {
    return MessageModel(
      id: null,
      conversationId: conversationId,
      senderId: senderId,
      body: body,
      createdAt: DateTime.now(),
      clientMessageId: clientMessageId,
      status: MessageSendStatus.pending,
      attachments: attachments,
    );
  }

  MessageModel copyWith({
    int? id,
    MessageSendStatus? status,
    DateTime? createdAt,
    String? body,
    DateTime? editedAt,
    DateTime? deletedAt,
    List<MessageAttachmentModel>? attachments,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      clientMessageId: clientMessageId,
      status: status ?? this.status,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      attachments: attachments ?? this.attachments,
    );
  }

  /// Identity for de-duplication in a thread: a real message is identified
  /// by its server [id]; a not-yet-acknowledged one by [clientMessageId].
  /// Two [MessageModel]s represent the "same" logical message if either
  /// matches.
  bool sameLogicalMessage(MessageModel other) {
    if (id != null && other.id != null) return id == other.id;
    return clientMessageId == other.clientMessageId;
  }
}

class MessageAttachmentModel {
  final int id;
  final int mediaId;
  final String? url;
  final String? hlsUrl;
  final String? thumbnailUrl;
  final String? mimeType;
  final int? size;
  final String? filename;

  /// Source media dimensions — null until the async image/video pipeline
  /// finishes, or for audio. Used to preserve the real aspect ratio in the
  /// bubble instead of forcing a square crop.
  final int? width;
  final int? height;

  /// Source duration in milliseconds — video/audio only, null for images
  /// and while still processing.
  final int? durationMs;

  // Local state for uploads
  final String? localPath;
  final bool isUploading;
  final double uploadProgress;
  final bool isFailed;

  const MessageAttachmentModel({
    required this.id,
    required this.mediaId,
    this.url,
    this.hlsUrl,
    this.thumbnailUrl,
    this.mimeType,
    this.size,
    this.filename,
    this.width,
    this.height,
    this.durationMs,
    this.localPath,
    this.isUploading = false,
    this.uploadProgress = 0,
    this.isFailed = false,
  });

  bool get isImage => mimeType?.startsWith('image/') == true;
  bool get isVideo => mimeType?.startsWith('video/') == true;
  bool get isAudio => mimeType?.startsWith('audio/') == true;

  /// Real aspect ratio (width / height) when known, else null — callers
  /// must fall back to a sane default rather than assume 1:1.
  double? get aspectRatio =>
      (width != null && height != null && width! > 0 && height! > 0)
      ? width! / height!
      : null;

  factory MessageAttachmentModel.fromApi(Map<String, dynamic> json) {
    final media = (json['media'] as Map?) ?? json;
    // Single canonical resolver (Part 3) — every consumer (bubble,
    // fullscreen viewer, video/audio players) reads an already-normalized,
    // already-absolute URL from here on, instead of each widget rewriting
    // localhost/127.0.0.1/10.0.2.2/relative paths itself. This is the ONE
    // place message attachment URLs get resolved, whether the row came
    // from the send response, a `message.created` SSE event, or a REST
    // history page — all three flow through this same factory.
    // Part 8/13 fallback: the client already produces an upload-ready
    // original (compressed JPEG for images, direct source for video/audio —
    // see MessageMediaPreparationService), and `media.url` always points at
    // that validated READY original regardless of whether the optional
    // background worker has produced any derivative yet. Never reads a
    // derivative URL that might not exist — `url` is always the one
    // guaranteed-present canonical source.
    final resolvedUrl = resolveMediaUrl(media['url']?.toString());
    return MessageAttachmentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      mediaId:
          (json['mediaId'] as num?)?.toInt() ??
          (media['id'] as num?)?.toInt() ??
          0,
      url: resolvedUrl,
      hlsUrl: resolveMediaUrl(media['hlsUrl']?.toString()),
      thumbnailUrl: resolveMediaUrl(media['thumbnailUrl']?.toString()),
      mimeType: media['mimeType']?.toString() ?? media['mimetype']?.toString(),
      size: (media['size'] as num?)?.toInt(),
      filename: media['filename']?.toString(),
      width: (media['width'] as num?)?.toInt(),
      height: (media['height'] as num?)?.toInt(),
      durationMs: (media['durationMs'] as num?)?.toInt(),
    );
  }

  factory MessageAttachmentModel.local({
    required String localPath,
    required String filename,
    int? size,
    String? mimeType,
  }) {
    return MessageAttachmentModel(
      id: 0,
      mediaId: 0,
      localPath: localPath,
      filename: filename,
      size: size,
      mimeType: mimeType ?? guessMimeTypeFromFilename(filename),
      isUploading: true,
      uploadProgress: 0,
      isFailed: false,
    );
  }

  MessageAttachmentModel copyWith({
    int? mediaId,
    String? url,
    String? hlsUrl,
    String? thumbnailUrl,
    String? mimeType,
    int? size,
    String? filename,
    int? width,
    int? height,
    int? durationMs,
    bool? isUploading,
    double? uploadProgress,
    bool? isFailed,
  }) {
    return MessageAttachmentModel(
      id: id,
      mediaId: mediaId ?? this.mediaId,
      url: url ?? this.url,
      hlsUrl: hlsUrl ?? this.hlsUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      filename: filename ?? this.filename,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
      localPath: localPath,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isFailed: isFailed ?? this.isFailed,
    );
  }
}
