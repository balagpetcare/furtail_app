import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cross-cutting SSE/FCM dedup + foreground-visibility policy for direct
/// messages — the same canonical message can arrive via two independent
/// transports (the shared `message.created` SSE stream, and an FCM
/// foreground data message), and this coordinator is the single source of
/// truth both `MessageThreadController` (SSE path) and
/// `NotificationController` (FCM path) consult before doing anything
/// user-visible (bubble, sound, system notification) for a given
/// `messageId`.
///
/// Deliberately a plain mutable service object behind a `Provider`, not
/// Riverpod state — nothing in the UI tree needs to rebuild when a message
/// is claimed; the mutation is pure bookkeeping for other controllers to
/// consult synchronously.
class MessageNotificationCoordinator {
  /// Bounded so a long-lived app session can never grow this unboundedly —
  /// only recent messages matter for dedup purposes (an old message can
  /// never legitimately arrive "again" from a second transport more than a
  /// few seconds after the first).
  static const int _maxTracked = 200;

  final List<int> _seenOrder = [];
  final Set<int> _seenIds = {};

  /// The conversationId of the currently-visible ChatScreen, or null. Set
  /// by ChatScreen on mount, cleared on dispose — lets the coordinator
  /// suppress an intrusive system notification for a conversation the user
  /// is already looking at (the realtime bubble is enough).
  int? activeConversationId;

  /// First transport to see a given [messageId] wins: returns true (and
  /// marks it seen) the first time, false on every subsequent call for the
  /// same id — so whichever of SSE/FCM/REST-backfill arrives first is the
  /// one that gets to trigger a sound/bubble/notification, and the rest are
  /// silently absorbed as confirmations rather than duplicates.
  bool claimMessage(int messageId) {
    if (_seenIds.contains(messageId)) {
      if (kDebugMode) {
        debugPrint('[Thread] event deduped $messageId');
      }
      return false;
    }
    _seenIds.add(messageId);
    _seenOrder.add(messageId);
    if (_seenOrder.length > _maxTracked) {
      final evicted = _seenOrder.removeAt(0);
      _seenIds.remove(evicted);
    }
    return true;
  }

  bool isConversationActive(int conversationId) =>
      activeConversationId == conversationId;

  void setActiveConversation(int conversationId) {
    activeConversationId = conversationId;
  }

  void clearActiveConversation(int conversationId) {
    if (activeConversationId == conversationId) {
      activeConversationId = null;
    }
  }

  /// Called on logout (see `resetSessionScopedState`) so neither the
  /// outgoing user's claimed-message dedup state nor their
  /// `activeConversationId` can leak into the next account that logs in on
  /// this device. Also used directly by tests.
  void reset() {
    _seenOrder.clear();
    _seenIds.clear();
    activeConversationId = null;
  }
}

final messageNotificationCoordinatorProvider =
    Provider<MessageNotificationCoordinator>((ref) {
      return MessageNotificationCoordinator();
    });
