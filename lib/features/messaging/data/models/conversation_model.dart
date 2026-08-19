import 'package:furtail_app/features/social/data/models/social_user_summary.dart';

class MessagePreview {
  final int id;
  final int senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? editedAt;

  /// Set when the last message has been deleted ("unsent") by its sender.
  /// [body] is already blanked server-side once this is set — the Inbox
  /// renders a fixed "This message was removed" copy instead.
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  const MessagePreview({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
  });

  factory MessagePreview.fromApi(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawSenderId = json['senderId'];
    return MessagePreview(
      id: rawId is num ? rawId.toInt() : 0,
      senderId: rawSenderId is num ? rawSenderId.toInt() : 0,
      body: (json['body'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      editedAt: DateTime.tryParse(
        json['editedAt']?.toString() ?? '',
      )?.toLocal(),
      deletedAt: DateTime.tryParse(
        json['deletedAt']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

/// One row in the Inbox — a conversation plus enough state to render it
/// without a follow-up request (`canSend`/`unreadCount` come straight from
/// the backend's batched `/messages/conversations` response, see
/// `messaging.service.ts` on the backend). [otherUser] is hydrated
/// separately (the backend list endpoint intentionally returns only
/// `otherUserId`, matching the same convention as the Social hub's lists).
class ConversationModel {
  final int conversationId;
  final int otherUserId;
  final SocialUserSummary? otherUser;
  final MessagePreview? lastMessage;
  final DateTime? lastMessageAt;
  final bool canSend;
  final int unreadCount;

  const ConversationModel({
    required this.conversationId,
    required this.otherUserId,
    required this.otherUser,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.canSend,
    required this.unreadCount,
  });

  factory ConversationModel.fromApi(
    Map<String, dynamic> json, {
    SocialUserSummary? otherUser,
  }) {
    final rawConversationId = json['conversationId'];
    final rawOtherUserId = json['otherUserId'];
    final lastMessageJson = json['lastMessage'];
    final rawUnread = json['unreadCount'];
    return ConversationModel(
      conversationId: rawConversationId is num ? rawConversationId.toInt() : 0,
      otherUserId: rawOtherUserId is num ? rawOtherUserId.toInt() : 0,
      otherUser: otherUser,
      lastMessage: lastMessageJson is Map
          ? MessagePreview.fromApi(lastMessageJson.cast<String, dynamic>())
          : null,
      lastMessageAt: DateTime.tryParse(
        json['lastMessageAt']?.toString() ?? '',
      )?.toLocal(),
      canSend: json['canSend'] == true,
      unreadCount: rawUnread is num ? rawUnread.toInt() : 0,
    );
  }

  ConversationModel copyWith({
    SocialUserSummary? otherUser,
    MessagePreview? lastMessage,
    DateTime? lastMessageAt,
    bool? canSend,
    int? unreadCount,
  }) {
    return ConversationModel(
      conversationId: conversationId,
      otherUserId: otherUserId,
      otherUser: otherUser ?? this.otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      canSend: canSend ?? this.canSend,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
