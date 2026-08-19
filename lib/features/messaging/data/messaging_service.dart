import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/services/api_client.dart';

import 'models/conversation_model.dart';
import 'models/message_model.dart';

/// Server-enforced text length cap, mirrored client-side purely for instant
/// feedback (`MAX_MESSAGE_LENGTH` in messaging.service.ts on the backend) —
/// the server remains the source of truth and re-validates regardless.
const int kMaxMessageLength = 4000;

class MessagePage {
  final List<MessageModel> items;
  final String? nextCursor;
  final bool hasMore;

  /// The other participant's current read cursor — bootstraps the
  /// Messenger-style "seen" avatar on conversation open (see
  /// `MessageThreadController`). `0` means "nothing read yet". Only
  /// meaningful on the *first* (cursor-less) page; older pages loaded via
  /// `loadOlder()` don't repeat it (still 0 there, harmless — the
  /// controller only reads this off the initial page).
  final int otherLastReadMessageId;

  const MessagePage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    this.otherLastReadMessageId = 0,
  });
}

/// Client-safe subset of the backend's admin-configurable messaging media
/// policy (see `media-settings.service.ts` / COMMAND 01) — never the
/// admin-only compression/quality tuning fields, only what a client needs
/// to precheck a selection before spending an upload round trip. Server
/// processing remains authoritative regardless of what this reports.
class MessagingMediaSettings {
  final bool mediaMessagingEnabled;
  final int maxSourceFileBytes;
  final int imageMaxSourceBytes;
  final int videoMaxSourceBytes;
  final int audioMaxSourceBytes;
  final List<String> allowedImageMimeTypes;
  final List<String> allowedVideoMimeTypes;
  final List<String> allowedAudioMimeTypes;

  const MessagingMediaSettings({
    required this.mediaMessagingEnabled,
    required this.maxSourceFileBytes,
    required this.imageMaxSourceBytes,
    required this.videoMaxSourceBytes,
    required this.audioMaxSourceBytes,
    required this.allowedImageMimeTypes,
    required this.allowedVideoMimeTypes,
    required this.allowedAudioMimeTypes,
  });

  /// Safe fallback if the settings fetch fails/hasn't completed yet —
  /// deliberately mirrors the backend's own defaults
  /// (`DEFAULT_MESSAGING_MEDIA_SETTINGS` in media-settings.service.ts) so a
  /// client precheck before the real settings arrive is still meaningful,
  /// not just "allow everything." The server remains authoritative either
  /// way — this only ever makes the client precheck stricter or looser by
  /// a few seconds at worst.
  static const fallback = MessagingMediaSettings(
    mediaMessagingEnabled: true,
    maxSourceFileBytes: 100 * 1024 * 1024,
    imageMaxSourceBytes: 100 * 1024 * 1024,
    videoMaxSourceBytes: 100 * 1024 * 1024,
    audioMaxSourceBytes: 100 * 1024 * 1024,
    allowedImageMimeTypes: [
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
    ],
    allowedVideoMimeTypes: ['video/mp4', 'video/quicktime', 'video/webm'],
    allowedAudioMimeTypes: [
      'audio/mpeg',
      'audio/mp4',
      'audio/x-m4a',
      'audio/aac',
      'audio/wav',
      'audio/x-wav',
      'audio/webm',
      'audio/ogg',
    ],
  );

  factory MessagingMediaSettings.fromApi(Map<String, dynamic> json) {
    List<String> strings(dynamic raw) =>
        (raw as List?)?.whereType<String>().toList() ?? const [];
    int bytes(dynamic raw, int fallbackValue) =>
        raw is num ? raw.toInt() : fallbackValue;
    return MessagingMediaSettings(
      mediaMessagingEnabled: json['mediaMessagingEnabled'] != false,
      maxSourceFileBytes: bytes(
        json['maxSourceFileBytes'],
        fallback.maxSourceFileBytes,
      ),
      imageMaxSourceBytes: bytes(
        json['imageMaxSourceBytes'],
        fallback.imageMaxSourceBytes,
      ),
      videoMaxSourceBytes: bytes(
        json['videoMaxSourceBytes'],
        fallback.videoMaxSourceBytes,
      ),
      audioMaxSourceBytes: bytes(
        json['audioMaxSourceBytes'],
        fallback.audioMaxSourceBytes,
      ),
      allowedImageMimeTypes: strings(json['allowedImageMimeTypes']),
      allowedVideoMimeTypes: strings(json['allowedVideoMimeTypes']),
      allowedAudioMimeTypes: strings(json['allowedAudioMimeTypes']),
    );
  }

  /// Max source bytes for a picked file, based on its MIME type — falls
  /// back to the general [maxSourceFileBytes] for a type this client
  /// doesn't recognize (the server independently re-validates the MIME
  /// type itself regardless).
  int maxBytesForMimeType(String mimeType) {
    if (allowedVideoMimeTypes.contains(mimeType)) return videoMaxSourceBytes;
    if (allowedAudioMimeTypes.contains(mimeType)) return audioMaxSourceBytes;
    if (allowedImageMimeTypes.contains(mimeType)) return imageMaxSourceBytes;
    return maxSourceFileBytes;
  }
}

class ConversationPage {
  final List<ConversationModel> items;
  final String? nextCursor;
  final bool hasMore;
  const ConversationPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });
}

class UnreadSummary {
  final int totalUnreadMessages;
  final int unreadConversationCount;
  final Map<int, int> perConversation;

  const UnreadSummary({
    required this.totalUnreadMessages,
    required this.unreadConversationCount,
    required this.perConversation,
  });

  static const empty = UnreadSummary(
    totalUnreadMessages: 0,
    unreadConversationCount: 0,
    perConversation: {},
  );

  factory UnreadSummary.fromApi(Map<String, dynamic> json) {
    final rows = (json['perConversation'] as List?) ?? const [];
    final map = <int, int>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final r = row.cast<String, dynamic>();
      final id = r['conversationId'];
      final count = r['unreadCount'];
      if (id is num && count is num) {
        map[id.toInt()] = count.toInt();
      }
    }
    return UnreadSummary(
      totalUnreadMessages: (json['totalUnreadMessages'] as num?)?.toInt() ?? 0,
      unreadConversationCount:
          (json['unreadConversationCount'] as num?)?.toInt() ?? 0,
      perConversation: map,
    );
  }
}

/// Thin dio wrapper for the direct-messaging REST API, following the same
/// shape as `SocialService` (see `services/social_service.dart`) — no
/// caching or business logic here, that lives in `MessagingRepository`.
class MessagingService {
  MessagingService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Map<String, dynamic> _asMap(dynamic decoded) =>
      (decoded as Map).cast<String, dynamic>();

  Map<String, dynamic> _data(dynamic decoded) {
    final map = _asMap(decoded);
    return (map['data'] as Map?)?.cast<String, dynamic>() ?? map;
  }

  Future<int> startConversation(int otherUserId) async {
    final decoded = await _client.post(
      ApiEndpoints.messagingStartConversation(),
      {'userId': otherUserId},
    );
    final data = _data(decoded);
    final id = data['conversationId'];
    if (id is! num) {
      throw Exception('Malformed start-conversation response');
    }
    return id.toInt();
  }

  Future<ConversationPage> listConversations({
    int limit = 20,
    String? cursor,
  }) async {
    final decoded = await _client.get(
      ApiEndpoints.messagingConversations(limit: limit, cursor: cursor),
    );
    final data = _data(decoded);
    final rawItems = (data['items'] as List?) ?? const [];
    return ConversationPage(
      items: rawItems
          .whereType<Map>()
          .map((e) => ConversationModel.fromApi(e.cast<String, dynamic>()))
          .toList(),
      nextCursor: data['nextCursor']?.toString(),
      hasMore: data['hasMore'] == true,
    );
  }

  Future<MessagePage> listMessages(
    int conversationId, {
    int limit = 30,
    String? cursor,
  }) async {
    final decoded = await _client.get(
      ApiEndpoints.messagingMessages(
        conversationId,
        limit: limit,
        cursor: cursor,
      ),
    );
    final data = _data(decoded);
    final rawItems = (data['items'] as List?) ?? const [];
    final otherLastRead = data['otherLastReadMessageId'];
    return MessagePage(
      items: rawItems
          .whereType<Map>()
          .map((e) => MessageModel.fromApi(e.cast<String, dynamic>()))
          .toList(),
      nextCursor: data['nextCursor']?.toString(),
      hasMore: data['hasMore'] == true,
      otherLastReadMessageId: otherLastRead is num ? otherLastRead.toInt() : 0,
    );
  }

  Future<MessagingMediaSettings> getMediaSettings() async {
    final decoded = await _client.get(ApiEndpoints.messagingMediaSettings());
    return MessagingMediaSettings.fromApi(_data(decoded));
  }

  Future<MessageModel> sendMessage(
    int conversationId, {
    required String clientMessageId,
    required String body,
    List<int> mediaIds = const [],
  }) async {
    final decoded = await _client
        .post(ApiEndpoints.messagingSend(conversationId), {
          'clientMessageId': clientMessageId,
          'body': body,
          if (mediaIds.isNotEmpty) 'mediaIds': mediaIds,
        });
    return MessageModel.fromApi(_data(decoded));
  }

  Future<MessageModel> editMessage(
    int conversationId,
    int messageId,
    String body,
  ) async {
    final decoded = await _client.patch(
      ApiEndpoints.messagingMessage(conversationId, messageId),
      {'body': body},
    );
    return MessageModel.fromApi(_data(decoded));
  }

  /// Soft-deletes ("unsends") the caller's own message. Returns the id and
  /// `deletedAt` timestamp — callers already hold the rest of the message
  /// locally and just need to flip it into the deleted/tombstone state.
  Future<DateTime> deleteMessage(int conversationId, int messageId) async {
    final decoded = await _client.delete(
      ApiEndpoints.messagingMessage(conversationId, messageId),
    );
    final data = _data(decoded);
    return DateTime.tryParse(data['deletedAt']?.toString() ?? '')?.toLocal() ??
        DateTime.now();
  }

  Future<int> markRead(int conversationId, {int? upToMessageId}) async {
    final decoded = await _client.post(
      ApiEndpoints.messagingMarkRead(conversationId),
      {if (upToMessageId != null) 'upToMessageId': upToMessageId},
    );
    final data = _data(decoded);
    final id = data['lastReadMessageId'];
    return id is num ? id.toInt() : 0;
  }

  Future<UnreadSummary> getUnread() async {
    final decoded = await _client.get(ApiEndpoints.messagingUnread());
    return UnreadSummary.fromApi(_data(decoded));
  }

  /// Publishes this user's typing state for a conversation. Ephemeral —
  /// nothing is persisted server-side, so there's no response payload
  /// worth returning. Callers must treat failures as non-fatal (typing is
  /// a non-critical feature that must never block sending a real
  /// message) — see `TypingController`.
  Future<void> sendTyping(int conversationId, {required bool isTyping}) async {
    await _client.post(ApiEndpoints.messagingTyping(conversationId), {
      'isTyping': isTyping,
    });
  }
}
