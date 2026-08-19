import 'package:furtail_app/features/social/data/models/social_user_summary.dart';
import 'package:furtail_app/services/social_service.dart';

import 'messaging_service.dart';
import 'models/message_model.dart';

export 'messaging_service.dart'
    show
        MessagePage,
        ConversationPage,
        UnreadSummary,
        MessagingMediaSettings,
        kMaxMessageLength;

/// Adds display-info hydration on top of [MessagingService] — the backend's
/// conversation list only returns `otherUserId`, so each row's name/avatar
/// is resolved via the same `GET /api/v1/user/:id` lookup the Social hub
/// uses (reusing `SocialUserSummary`, not a second parallel user model).
class MessagingRepository {
  MessagingRepository({MessagingService? service, SocialService? socialService})
    : _service = service ?? MessagingService(),
      _socialService = socialService ?? SocialService();

  final MessagingService _service;
  final SocialService _socialService;

  Future<SocialUserSummary> _hydrate(int userId) async {
    try {
      final raw = await _socialService.getVisitorProfile(userId);
      return SocialUserSummary.fromVisitorProfileJson(raw, fallbackId: userId);
    } catch (_) {
      return SocialUserSummary.placeholder(userId);
    }
  }

  Future<int> startConversation(int otherUserId) =>
      _service.startConversation(otherUserId);

  Future<ConversationPage> listConversations({
    int limit = 20,
    String? cursor,
  }) async {
    final page = await _service.listConversations(limit: limit, cursor: cursor);
    final hydrated = await Future.wait(
      page.items.map(
        (c) async => c.copyWith(otherUser: await _hydrate(c.otherUserId)),
      ),
    );
    return ConversationPage(
      items: hydrated,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<SocialUserSummary> otherUserFor(int otherUserId) =>
      _hydrate(otherUserId);

  Future<MessagePage> listMessages(
    int conversationId, {
    int limit = 30,
    String? cursor,
  }) => _service.listMessages(conversationId, limit: limit, cursor: cursor);

  Future<MessageModel> sendMessage(
    int conversationId, {
    required String clientMessageId,
    required String body,
    List<int> mediaIds = const [],
  }) => _service.sendMessage(
    conversationId,
    clientMessageId: clientMessageId,
    body: body,
    mediaIds: mediaIds,
  );

  Future<MessageModel> editMessage(
    int conversationId,
    int messageId,
    String body,
  ) => _service.editMessage(conversationId, messageId, body);

  Future<DateTime> deleteMessage(int conversationId, int messageId) =>
      _service.deleteMessage(conversationId, messageId);

  Future<int> markRead(int conversationId, {int? upToMessageId}) =>
      _service.markRead(conversationId, upToMessageId: upToMessageId);

  Future<UnreadSummary> getUnread() => _service.getUnread();

  Future<void> sendTyping(int conversationId, {required bool isTyping}) =>
      _service.sendTyping(conversationId, isTyping: isTyping);

  Future<MessagingMediaSettings> getMediaSettings() =>
      _service.getMediaSettings();
}
