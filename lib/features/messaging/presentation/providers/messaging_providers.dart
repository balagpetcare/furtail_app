import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show SystemSound, SystemSoundType;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/core/providers/current_user_provider.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:furtail_app/services/social_service.dart';

import '../../data/messaging_repository.dart';
import '../../data/messaging_service.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/message_model.dart';
import '../../data/realtime_client.dart';
import '../../data/typing_constants.dart';
import 'message_notification_coordinator.dart';
import 'package:furtail_app/features/media/data/authenticated_media_uploader.dart';

final socialServiceProvider = Provider<SocialService>(
  (ref) => SocialService(client: ref.watch(apiClientProvider)),
);

final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => MessagingRepository(
    service: MessagingService(client: ref.watch(apiClientProvider)),
    socialService: ref.watch(socialServiceProvider),
  ),
);

/// One shared, app-lifetime SSE connection (see `realtime_client.dart` for
/// why SSE and not a socket library). Deliberately not autoDispose — the
/// Inbox and any open chat thread both subscribe to the same stream, and
/// tearing the connection down between screens would defeat the point.
final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final client = RealtimeClient();
  ref.onDispose(client.dispose);
  return client;
});

String _generateClientMessageId() {
  final rand = Random();
  final suffix = List.generate(
    8,
    (_) => rand.nextInt(36).toRadixString(36),
  ).join();
  return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
}

String _friendlyError(Object e) {
  if (e is ApiClientException) return e.message;
  return e.toString().replaceAll('Exception: ', '');
}

// ---------------------------------------------------------------------------
// Inbox (conversation list)
// ---------------------------------------------------------------------------

class InboxState {
  final List<ConversationModel> items;
  final bool initialLoading;
  final bool refreshing;
  final bool loadingMore;
  final String? error;
  final String? nextCursor;
  final bool hasMore;

  const InboxState({
    required this.items,
    required this.initialLoading,
    required this.refreshing,
    required this.loadingMore,
    required this.error,
    required this.nextCursor,
    required this.hasMore,
  });

  factory InboxState.initial() => const InboxState(
    items: [],
    initialLoading: true,
    refreshing: false,
    loadingMore: false,
    error: null,
    nextCursor: null,
    hasMore: false,
  );

  int get totalUnread => items.fold(0, (sum, c) => sum + c.unreadCount);

  InboxState copyWith({
    List<ConversationModel>? items,
    bool? initialLoading,
    bool? refreshing,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
  }) {
    return InboxState(
      items: items ?? this.items,
      initialLoading: initialLoading ?? this.initialLoading,
      refreshing: refreshing ?? this.refreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final conversationsListProvider =
    AutoDisposeNotifierProvider<ConversationsListController, InboxState>(
      ConversationsListController.new,
    );

/// Total unread message count across all conversations, for badge display
/// (e.g. the Messages icon in the Home top bar). Uses a plain one-shot REST
/// fetch rather than `conversationsListProvider` so rendering the badge
/// never has the side effect of opening the persistent realtime/SSE stream.
final messagesUnreadCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final summary = await ref.watch(messagingRepositoryProvider).getUnread();
  return summary.totalUnreadMessages;
});

/// Client-safe messaging media policy (COMMAND 01's admin-configurable
/// settings — see `MessagingMediaSettings`), fetched once and cached for
/// this provider's lifetime rather than hardcoding a second policy that
/// can drift from the real one. Not autoDispose: cheap to hold, and
/// re-fetching on every composer open would just be wasted latency for a
/// value that changes rarely. Falls back to
/// `MessagingMediaSettings.fallback` on failure so a precheck can still
/// run — the server remains authoritative regardless.
final messagingMediaSettingsProvider = FutureProvider<MessagingMediaSettings>((
  ref,
) async {
  try {
    return await ref.read(messagingRepositoryProvider).getMediaSettings();
  } catch (_) {
    return MessagingMediaSettings.fallback;
  }
});

class ConversationsListController extends AutoDisposeNotifier<InboxState> {
  StreamSubscription<RealtimeMessageEvent>? _sub;

  MessagingRepository get _repo => ref.read(messagingRepositoryProvider);

  @override
  InboxState build() {
    ref.onDispose(() => _sub?.cancel());
    final hub = ref.read(realtimeClientProvider);
    hub.start();
    _sub = hub.events.listen(_onRealtimeEvent);
    scheduleMicrotask(refresh);
    return InboxState.initial();
  }

  Future<void> refresh() async {
    final hadItems = state.items.isNotEmpty;
    state = state.copyWith(
      initialLoading: !hadItems,
      refreshing: hadItems,
      clearError: true,
    );
    try {
      final page = await _repo.listConversations();
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        hasMore: page.hasMore,
        initialLoading: false,
        refreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        initialLoading: false,
        refreshing: false,
        error: _friendlyError(e),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore ||
        state.refreshing ||
        !state.hasMore ||
        state.nextCursor == null) {
      return;
    }
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await _repo.listConversations(cursor: state.nextCursor);
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        hasMore: page.hasMore,
        loadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: _friendlyError(e));
    }
  }

  /// Called by an open chat thread right after it successfully marks itself
  /// read, so the Inbox badge clears immediately rather than waiting for
  /// the `message.read` realtime echo (which may be delayed or dropped).
  void clearUnreadLocally(int conversationId) {
    final idx = state.items.indexWhere(
      (c) => c.conversationId == conversationId,
    );
    if (idx == -1 || state.items[idx].unreadCount == 0) return;
    final next = [...state.items];
    next[idx] = next[idx].copyWith(unreadCount: 0);
    state = state.copyWith(items: next);
  }

  /// Called directly by a chat thread right after it successfully sends a
  /// message — updates the Inbox's cached preview/ordering immediately
  /// rather than waiting for the `message.created` realtime echo (which,
  /// same as everywhere else in this feature, is treated as best-effort:
  /// this keeps the Inbox correct even if the SSE stream never connects).
  void applyOutgoingMessage(
    int conversationId, {
    required int senderId,
    required String body,
    required DateTime createdAt,
  }) {
    _bumpConversation(
      conversationId,
      senderId: senderId,
      body: body,
      createdAt: createdAt,
    );
  }

  void _onRealtimeEvent(RealtimeMessageEvent event) {
    final conversationId = (event.data['conversationId'] as num?)?.toInt();
    if (conversationId == null) return;
    switch (event.type) {
      case 'message.created':
        _bumpConversation(
          conversationId,
          senderId: (event.data['senderId'] as num?)?.toInt(),
          body: event.data['body']?.toString(),
          createdAt: DateTime.tryParse(
            event.data['createdAt']?.toString() ?? '',
          )?.toLocal(),
        );
      case 'message.read':
        final readerId = (event.data['readerId'] as num?)?.toInt();
        final myId = ref.read(currentUserProvider).userId;
        if (readerId != null && readerId == myId) {
          clearUnreadLocally(conversationId);
        }
      case 'message.updated':
        _updateLastMessageIfMatches(
          conversationId,
          (event.data['messageId'] as num?)?.toInt(),
          body: event.data['body']?.toString(),
          editedAt: DateTime.tryParse(
            event.data['editedAt']?.toString() ?? '',
          )?.toLocal(),
        );
      case 'message.deleted':
        _updateLastMessageIfMatches(
          conversationId,
          (event.data['messageId'] as num?)?.toInt(),
          body: '',
          deletedAt: DateTime.now(),
        );
    }
  }

  /// Applies an edit/delete to a conversation's cached last-message preview,
  /// but only when the edited/deleted message actually *is* that
  /// conversation's last message — an edit to an older message never
  /// changes what the Inbox shows.
  void _updateLastMessageIfMatches(
    int conversationId,
    int? messageId, {
    String? body,
    DateTime? editedAt,
    DateTime? deletedAt,
  }) {
    if (messageId == null) return;
    final idx = state.items.indexWhere(
      (c) => c.conversationId == conversationId,
    );
    if (idx == -1) return;
    final existing = state.items[idx];
    final last = existing.lastMessage;
    if (last == null || last.id != messageId) return;
    final next = [...state.items];
    next[idx] = existing.copyWith(
      lastMessage: MessagePreview(
        id: last.id,
        senderId: last.senderId,
        body: body ?? last.body,
        createdAt: last.createdAt,
        editedAt: editedAt ?? last.editedAt,
        deletedAt: deletedAt ?? last.deletedAt,
      ),
    );
    state = state.copyWith(items: next);
  }

  void _bumpConversation(
    int conversationId, {
    int? senderId,
    String? body,
    DateTime? createdAt,
  }) {
    final idx = state.items.indexWhere(
      (c) => c.conversationId == conversationId,
    );
    if (idx == -1) {
      // A brand new (or not-yet-loaded) conversation just got a message —
      // simplest correct move is a full refresh rather than fabricating a
      // partially-hydrated row.
      refresh();
      return;
    }
    final myId = ref.read(currentUserProvider).userId;
    final isMine = senderId != null && senderId == myId;
    final existing = state.items[idx];
    final updated = existing.copyWith(
      lastMessage: (senderId != null && body != null)
          ? MessagePreview(
              id: existing.lastMessage?.id ?? 0,
              senderId: senderId,
              body: body,
              createdAt: createdAt ?? DateTime.now(),
            )
          : null,
      lastMessageAt: createdAt ?? existing.lastMessageAt,
      unreadCount: isMine ? existing.unreadCount : existing.unreadCount + 1,
    );
    final next = [...state.items]..removeAt(idx);
    next.insert(0, updated);
    state = state.copyWith(items: next);
  }
}

// ---------------------------------------------------------------------------
// Message thread
// ---------------------------------------------------------------------------

/// Family key for a chat thread. [otherUserId] is carried alongside
/// [conversationId] because the thread needs it for the proactive
/// friendship/block eligibility check (`SocialService.getStatus`) — the
/// conversation-list/message endpoints alone don't repeat it on every call.
typedef ThreadKey = ({int conversationId, int otherUserId});

class ThreadState {
  final List<MessageModel>
  messages; // newest-first, matches the backend's page order
  final bool initialLoading;
  final bool loadingOlder;
  final bool hasMoreOlder;
  final String? nextCursor;
  final String? error;
  final bool checkingEligibility;
  final bool canSend;
  final String? disabledReason;

  /// Whether the *other* participant is currently typing, per the realtime
  /// `typing.started`/`typing.stopped` protocol with local expiry (see
  /// `TypingConstants.remoteExpiry`). Purely a header-subtitle signal —
  /// never affects [canSend]/message delivery.
  final bool remoteTyping;

  /// The other participant's current read cursor — the newest message id
  /// they've actually seen. `0` means nothing read yet. Server-authoritative:
  /// set once from `listMessages`'s `otherLastReadMessageId` on initial
  /// load, then advanced live by `message.read` realtime events (never
  /// inferred from delivery/FCM/inbox-open — see COMMAND 02 Part 5). Used
  /// by `ChatScreen` to place the Messenger-style "seen" avatar under the
  /// single latest own outgoing message whose id is `<=` this value.
  final int otherLastReadMessageId;

  const ThreadState({
    required this.messages,
    required this.initialLoading,
    required this.loadingOlder,
    required this.hasMoreOlder,
    required this.nextCursor,
    required this.error,
    required this.checkingEligibility,
    required this.canSend,
    required this.disabledReason,
    this.remoteTyping = false,
    this.otherLastReadMessageId = 0,
  });

  factory ThreadState.initial() => const ThreadState(
    messages: [],
    initialLoading: true,
    loadingOlder: false,
    hasMoreOlder: false,
    nextCursor: null,
    error: null,
    checkingEligibility: true,
    canSend: false,
    disabledReason: null,
    remoteTyping: false,
    otherLastReadMessageId: 0,
  );

  /// The id of the single latest of the *caller's own* outgoing, sent
  /// messages that the other participant has read, or null if none have
  /// been (yet). Messenger-style: only ever one message shows the seen
  /// avatar, never every read message.
  int? latestSeenOwnMessageId(int myUserId) {
    if (otherLastReadMessageId <= 0) return null;
    for (final m in messages) {
      if (m.senderId == myUserId &&
          m.isSent &&
          m.id != null &&
          m.id! <= otherLastReadMessageId) {
        return m.id;
      }
    }
    return null;
  }

  ThreadState copyWith({
    List<MessageModel>? messages,
    bool? initialLoading,
    bool? loadingOlder,
    bool? hasMoreOlder,
    String? nextCursor,
    bool clearNextCursor = false,
    String? error,
    bool clearError = false,
    bool? checkingEligibility,
    bool? canSend,
    String? disabledReason,
    bool clearDisabledReason = false,
    bool? remoteTyping,
    int? otherLastReadMessageId,
  }) {
    return ThreadState(
      messages: messages ?? this.messages,
      initialLoading: initialLoading ?? this.initialLoading,
      loadingOlder: loadingOlder ?? this.loadingOlder,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      error: clearError ? null : (error ?? this.error),
      checkingEligibility: checkingEligibility ?? this.checkingEligibility,
      canSend: canSend ?? this.canSend,
      disabledReason: clearDisabledReason
          ? null
          : (disabledReason ?? this.disabledReason),
      remoteTyping: remoteTyping ?? this.remoteTyping,
      otherLastReadMessageId:
          otherLastReadMessageId ?? this.otherLastReadMessageId,
    );
  }
}

final messageThreadProvider =
    AutoDisposeNotifierProviderFamily<
      MessageThreadController,
      ThreadState,
      ThreadKey
    >(MessageThreadController.new);

class MessageThreadController
    extends AutoDisposeFamilyNotifier<ThreadState, ThreadKey> {
  late final ThreadKey _key;
  StreamSubscription<RealtimeMessageEvent>? _sub;

  /// Message ids with an in-flight edit/delete — blocks a second tap on the
  /// same message from firing a duplicate mutation.
  final Set<int> _pendingMutationIds = {};

  // --- Local (outgoing) typing publication ---------------------------------
  /// Whether this client currently believes it has an active
  /// `typing.started` published for this conversation — used to avoid
  /// re-publishing start on every keystroke (only the first keystroke of a
  /// burst, plus the periodic heartbeat below, actually hit the network).
  bool _isTypingLocally = false;

  /// Fires `TypingConstants.stopDebounce` after the last keystroke; publishes
  /// `typing.stopped` if it's never cancelled by another keystroke first.
  Timer? _typingStopTimer;

  /// While actively typing, keeps re-publishing `typing.started` on
  /// `TypingConstants.heartbeatInterval` so the *remote* client's expiry
  /// timer never lapses during one long typing session, without generating
  /// one request per keystroke.
  Timer? _typingHeartbeatTimer;

  // --- Remote (incoming) typing display -------------------------------------
  /// Clears `state.remoteTyping` if no follow-up typing signal arrives
  /// within `TypingConstants.remoteExpiry` — the safety net for a
  /// `typing.stopped` lost to a dropped connection or killed app.
  Timer? _remoteTypingExpiryTimer;

  MessagingRepository get _repo => ref.read(messagingRepositoryProvider);
  SocialService get _social => ref.read(socialServiceProvider);

  @override
  ThreadState build(ThreadKey key) {
    _key = key;
    // Captured up front — `ref.read` is not usable from inside the
    // `ref.onDispose` callback below (the container is already tearing
    // down by the time it runs), so the repository reference this cleanup
    // needs has to be grabbed while `ref` is still live.
    final repoForCleanup = _repo;
    ref.onDispose(() {
      _sub?.cancel();
      _typingStopTimer?.cancel();
      _typingHeartbeatTimer?.cancel();
      _remoteTypingExpiryTimer?.cancel();
      // Best-effort: let the other participant's "Typing…" clear promptly
      // rather than waiting out their local expiry timer. Fire-and-forget —
      // a disposed notifier can't await, and this must never throw.
      if (_isTypingLocally) {
        unawaited(
          repoForCleanup
              .sendTyping(_key.conversationId, isTyping: false)
              .catchError((_) {}),
        );
      }
    });
    final hub = ref.read(realtimeClientProvider);
    hub.start();
    _sub = hub.events.listen(_onRealtimeEvent);
    scheduleMicrotask(_init);
    return ThreadState.initial();
  }

  Future<void> _init() async {
    state = state.copyWith(
      initialLoading: true,
      checkingEligibility: true,
      clearError: true,
    );
    try {
      // The realtime listener is already attached (see `build()`, which
      // subscribes synchronously before this microtask ever runs), so a
      // `message.created` event can legitimately land in `state.messages`
      // *while* this REST history fetch is still in flight — the classic
      // subscribe-then-backfill race. If the history response below simply
      // overwrote `state.messages` with `page.items`, that live message
      // would vanish (the DB row exists, but this particular GET may have
      // been issued/served before it committed) until the thread was torn
      // down and reopened, which is exactly the real-device symptom this
      // fixes: merge by identity instead of replacing wholesale.
      final page = await _repo.listMessages(_key.conversationId, limit: 30);
      final merged = _mergeHistoryPage(page.items);
      state = state.copyWith(
        messages: merged,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        hasMoreOlder: page.hasMore,
        initialLoading: false,
        // Same subscribe-before-history race as the message merge above:
        // a `message.read` event may have already advanced
        // `state.otherLastReadMessageId` past what this (possibly stale)
        // REST snapshot reports — never regress it.
        otherLastReadMessageId: max(
          state.otherLastReadMessageId,
          page.otherLastReadMessageId,
        ),
      );
      unawaited(_checkEligibility());
      unawaited(_markRead());
    } catch (e) {
      state = state.copyWith(
        initialLoading: false,
        checkingEligibility: false,
        error: _friendlyError(e),
      );
    }
  }

  /// Merges a freshly-fetched history page with whatever's already in
  /// [state.messages] (only ever populated pre-`_init()` by a realtime
  /// event or optimistic send that raced ahead of this fetch — the state
  /// starts empty otherwise). The page is authoritative for anything it
  /// contains; any pre-existing row it doesn't contain (the race case) is
  /// kept, deduped by [MessageModel.sameLogicalMessage], and the combined
  /// list is re-sorted newest-first to match the page's own order
  /// convention.
  List<MessageModel> _mergeHistoryPage(List<MessageModel> page) {
    final preRace = state.messages
        .where((m) => !page.any((p) => p.sameLogicalMessage(m)))
        .toList();
    if (preRace.isEmpty) return page;
    final merged = [...page, ...preRace]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<void> _checkEligibility() async {
    try {
      final status = await _social.getStatus(_key.otherUserId);
      final blocked = status.isBlocked;
      final friends = status.isFriend;
      state = state.copyWith(
        checkingEligibility: false,
        canSend: friends && !blocked,
        disabledReason: blocked
            ? 'You can\'t message this user.'
            : !friends
            ? 'You can only message accepted friends. This conversation is read-only until you\'re friends again.'
            : null,
        clearDisabledReason: friends && !blocked,
      );
    } catch (_) {
      // Best-effort — leave whatever the last known eligibility was; the
      // send call itself still enforces this server-side regardless.
      state = state.copyWith(checkingEligibility: false);
    }
  }

  /// Reconciles from REST — call on realtime reconnect, app resume, or
  /// connectivity restore, so a dropped stream can never silently lose a
  /// message. Only ever adds messages this thread doesn't already have.
  Future<void> reconcile() async {
    if (kDebugMode) {
      debugPrint(
        '[Thread] reconnect backfill conversation=${_key.conversationId}',
      );
    }
    try {
      final page = await _repo.listMessages(_key.conversationId, limit: 30);
      // Route every fetched row through the same identity-based upsert as
      // the realtime/optimistic paths — a page overlapping an in-flight
      // optimistic send (matched by clientMessageId) or an already-merged
      // message (matched by id) must reconcile in place, never append.
      for (final item in page.items.reversed) {
        _upsertMessage(item);
      }
      state = state.copyWith(
        otherLastReadMessageId: max(
          state.otherLastReadMessageId,
          page.otherLastReadMessageId,
        ),
      );
      if (kDebugMode) {
        debugPrint('[Thread] state updated ${state.messages.length}');
      }
      unawaited(_markRead());
    } catch (_) {
      // Silent — the periodic/next reconcile attempt will catch up.
    }
  }

  Future<void> loadOlder() async {
    if (state.loadingOlder || !state.hasMoreOlder || state.nextCursor == null) {
      return;
    }
    state = state.copyWith(loadingOlder: true, clearError: true);
    try {
      final page = await _repo.listMessages(
        _key.conversationId,
        limit: 30,
        cursor: state.nextCursor,
      );
      state = state.copyWith(
        messages: [...state.messages, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        hasMoreOlder: page.hasMore,
        loadingOlder: false,
      );
    } catch (e) {
      state = state.copyWith(loadingOlder: false, error: _friendlyError(e));
    }
  }

  Future<void> send(String rawBody, {List<File> attachments = const []}) async {
    final body = rawBody.trim();
    if (body.isEmpty && attachments.isEmpty) return;
    if (body.length > kMaxMessageLength) return;

    final myId = ref.read(currentUserProvider).userId;
    if (myId == null) return;

    final localAttachments = attachments.map((file) {
      return MessageAttachmentModel.local(
        localPath: file.path,
        filename: file.path.split('/').last,
      );
    }).toList();

    final optimistic = MessageModel.optimistic(
      conversationId: _key.conversationId,
      senderId: myId,
      body: body,
      clientMessageId: _generateClientMessageId(),
      attachments: localAttachments,
    );
    state = state.copyWith(messages: [optimistic, ...state.messages]);
    // A message just got submitted — the composer is about to clear (see
    // `MessageComposer._submit`), so there's nothing left to be "typing".
    // Stop immediately rather than waiting for the debounce timer.
    _stopTypingNow();
    await _attemptSend(optimistic);
  }

  // ---------------------------------------------------------------------------
  // Typing indicator
  // ---------------------------------------------------------------------------

  /// Call on every composer text change. Debounced/throttled so this is
  /// nowhere near one network request per keystroke: the first keystroke of
  /// a burst publishes `typing.started` immediately, a periodic heartbeat
  /// keeps it alive on `TypingConstants.heartbeatInterval` while typing
  /// continues, and a `TypingConstants.stopDebounce` pause (or an emptied
  /// composer) publishes `typing.stopped`.
  void onComposerTextChanged(String text) {
    if (text.trim().isEmpty) {
      _stopTypingNow();
      return;
    }
    if (!_isTypingLocally) {
      _isTypingLocally = true;
      _publishTyping(true);
      _typingHeartbeatTimer?.cancel();
      _typingHeartbeatTimer = Timer.periodic(
        TypingConstants.heartbeatInterval,
        (_) => _publishTyping(true),
      );
    }
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(TypingConstants.stopDebounce, _stopTypingNow);
  }

  /// Public wrapper for lifecycle-driven stops (app backgrounded/inactive) —
  /// see `ChatScreen.didChangeAppLifecycleState`.
  void stopTypingForBackground() => _stopTypingNow();

  /// Publishes `typing.stopped` (if this client currently believes it's
  /// typing) and cancels both local timers. Idempotent — safe to call
  /// unconditionally from `send()`, composer-empty, dispose, etc.
  void _stopTypingNow() {
    _typingStopTimer?.cancel();
    _typingHeartbeatTimer?.cancel();
    if (!_isTypingLocally) return;
    _isTypingLocally = false;
    _publishTyping(false);
  }

  /// Fire-and-forget by design — per the task spec, a typing publish
  /// failure (offline, timeout, server hiccup) must never surface as an
  /// error or block a real message send. Worst case the remote side's own
  /// expiry timer (`TypingConstants.remoteExpiry`) clears a stale
  /// indicator on its own.
  void _publishTyping(bool isTyping) {
    unawaited(
      _repo
          .sendTyping(_key.conversationId, isTyping: isTyping)
          .catchError((_) {}),
    );
  }

  /// Re-sends a message that previously failed, reusing its original
  /// `clientMessageId` — if the earlier attempt actually reached the server
  /// despite the client-side failure (e.g. the response was lost), the
  /// backend's idempotency key returns the same message instead of a
  /// duplicate.
  Future<void> retry(MessageModel failed) async {
    if (!failed.isFailed) return;
    final resetAttachments = [
      for (final a in failed.attachments)
        if (a.isFailed) a.copyWith(isFailed: false) else a,
    ];
    final pending = failed.copyWith(
      status: MessageSendStatus.pending,
      attachments: resetAttachments,
    );
    _upsertMessage(pending);
    await _attemptSend(pending);
  }

  /// Applies [updater] to the attachment at [localPath] within the current
  /// (possibly-since-superseded) message identified by [clientMessageId],
  /// and pushes the result through the same canonical `_upsertMessage`
  /// path everything else uses — so upload-progress ticks render exactly
  /// like any other state change, no separate rebuild path.
  void _updateAttachmentByLocalPath(
    String clientMessageId,
    String localPath,
    MessageAttachmentModel Function(MessageAttachmentModel) updater,
  ) {
    final current = state.messages
        .where((m) => m.clientMessageId == clientMessageId)
        .firstOrNull;
    if (current == null) return;
    _upsertMessage(
      current.copyWith(
        attachments: [
          for (final a in current.attachments)
            if (a.localPath == localPath) updater(a) else a,
        ],
      ),
    );
  }

  Future<void> _attemptSend(MessageModel optimistic) async {
    // Tracks per-attachment upload outcome across the loop below — needed
    // because `optimistic.attachments` (the snapshot this function was
    // called with) never mutates itself; the catch block below must know
    // exactly which attachments actually finished uploading before the
    // failure (partial-attachment-failure in a multi-attachment send)
    // rather than marking every attachment failed indiscriminately.
    var workingAttachments = optimistic.attachments;
    try {
      List<int> mediaIds = [];

      // Upload any local attachments
      if (optimistic.attachments.isNotEmpty) {
        final uploader = AuthenticatedMediaUploader(
          client: ref.read(apiClientProvider),
        );

        for (int i = 0; i < optimistic.attachments.length; i++) {
          final attachment = optimistic.attachments[i];
          if (attachment.localPath != null && attachment.mediaId == 0) {
            final localPath = attachment.localPath!;
            final file = File(localPath);
            if (kDebugMode) {
              final size = await file.exists() ? await file.length() : -1;
              debugPrint('[MediaUpload] request started size=$size');
            }
            final result = await uploader.upload(
              file: file,
              // Routes this upload through the backend's message-specific
              // media policy (image/video/audio only, independently
              // admin-configurable) instead of the generic upload path's
              // defaults — see media-settings.service.ts on the backend.
              fields: const {'purpose': 'message'},
              onProgress: (sent, total) {
                if (total <= 0) return;
                final progress = (sent / total).clamp(0.0, 1.0);
                _updateAttachmentByLocalPath(
                  optimistic.clientMessageId,
                  localPath,
                  (a) =>
                      a.copyWith(isUploading: true, uploadProgress: progress),
                );
              },
            );
            if (kDebugMode) {
              debugPrint(
                '[MediaUpload] mediaId=${result.id} state=${result.status}',
              );
            }
            // The upload HTTP call can return 200 even though the server's
            // own inline (no-Redis dev fallback) processing already marked
            // the Media row FAILED before responding — trusting the HTTP
            // status alone would silently attach broken media to the
            // message. Treat a server-reported FAILED status exactly like
            // an upload exception so retry (Part 14) behaves correctly.
            if (result.status?.toUpperCase() == 'FAILED') {
              throw MediaUploadException(
                kind: MediaUploadErrorKind.storageFailure,
                userMessage:
                    'This file could not be processed. Please try again.',
              );
            }
            mediaIds.add(result.id);
            workingAttachments = [
              for (final a in workingAttachments)
                if (a.localPath == localPath)
                  a.copyWith(
                    mediaId: result.id,
                    url: result.url,
                    isUploading: false,
                    uploadProgress: 1,
                  )
                else
                  a,
            ];
            // Reflects the just-finished attachment (still "Processing…"
            // server-side until its Media row reaches READY — the message
            // is sent regardless, per this feature's existing PROCESSING-
            // is-allowed contract; see media-image-processor.ts).
            _updateAttachmentByLocalPath(
              optimistic.clientMessageId,
              localPath,
              (a) => a.copyWith(
                mediaId: result.id,
                url: result.url,
                isUploading: false,
                uploadProgress: 1,
              ),
            );
          } else if (attachment.mediaId != 0) {
            mediaIds.add(attachment.mediaId); // For retries
          }
        }
      }

      if (kDebugMode) {
        debugPrint('[MediaUpload] message send started');
      }
      final sent = await _repo.sendMessage(
        _key.conversationId,
        clientMessageId: optimistic.clientMessageId,
        body: optimistic.body,
        mediaIds: mediaIds,
      );
      if (kDebugMode) {
        debugPrint('[MediaUpload] message send complete');
      }
      _upsertMessage(sent);
      // Only touch the Inbox controller if it's already alive (e.g. this
      // chat was opened from it and it's still mounted underneath) — using
      // `ref.exists` instead of a bare `ref.read` avoids waking/fetching an
      // Inbox the user never opened just to update a cache nothing is
      // watching.
      if (ref.exists(conversationsListProvider)) {
        ref
            .read(conversationsListProvider.notifier)
            .applyOutgoingMessage(
              _key.conversationId,
              senderId: sent.senderId,
              body: sent.body,
              createdAt: sent.createdAt,
            );
      }
    } catch (e) {
      // Never leave an attachment stuck showing an indefinite "uploading"
      // spinner after the send actually failed (Part 20) — every
      // attachment that never finished uploading (still `mediaId == 0`)
      // flips to its explicit failed state; one that already finished
      // (e.g. attachment 1 of 2 uploaded fine, then `sendMessage` itself
      // failed) keeps its successful, already-uploaded state instead of
      // being falsely marked failed too.
      final failedAttachments = [
        for (final a in workingAttachments)
          if (a.mediaId == 0)
            a.copyWith(isUploading: false, isFailed: true)
          else
            a,
      ];
      _upsertMessage(
        optimistic.copyWith(
          status: MessageSendStatus.failed,
          attachments: failedAttachments,
        ),
      );
      if (e is ApiClientException) {
        if (e.code == 'CONVERSATION_READ_ONLY') {
          state = state.copyWith(
            canSend: false,
            disabledReason:
                'This conversation is read-only until you\'re friends again.',
          );
        } else if (e.code == 'RELATIONSHIP_BLOCKED') {
          state = state.copyWith(
            canSend: false,
            disabledReason: 'You can\'t message this user.',
          );
        }
      }
    }
  }

  bool isMutating(int messageId) => _pendingMutationIds.contains(messageId);

  /// Edits one of the caller's own sent messages. Server-authorized (the
  /// backend re-verifies authorship/conversation-membership regardless of
  /// what this client believes); this just guards against a duplicate
  /// request from a second tap and reconciles local state on success.
  Future<bool> editMessage(MessageModel message, String newBody) async {
    final id = message.id;
    if (id == null || _pendingMutationIds.contains(id)) return false;
    final body = newBody.trim();
    if (body.isEmpty || body == message.body) return false;

    _pendingMutationIds.add(id);
    state = state.copyWith(clearError: true);
    try {
      final updated = await _repo.editMessage(_key.conversationId, id, body);
      // Keep the local row's `clientMessageId` — the edit response doesn't
      // carry it (it's not needed for edit's own idempotency), only the
      // body/editedAt actually changed server-side.
      _replaceById(
        id,
        message.copyWith(body: updated.body, editedAt: updated.editedAt),
      );
      if (ref.exists(conversationsListProvider)) {
        // Best-effort local refresh so the Inbox preview doesn't show stale
        // text if this was the conversation's last message — the realtime
        // `message.updated` echo (see `_onRealtimeEvent` below and the
        // matching handler in `ConversationsListController`) does the same,
        // this just doesn't wait for it.
        ref.read(conversationsListProvider.notifier).refresh();
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    } finally {
      _pendingMutationIds.remove(id);
    }
  }

  /// Deletes ("unsends") one of the caller's own sent messages. Soft
  /// delete — the row stays in the thread as a tombstone (see
  /// `MessageModel.isDeleted`), it isn't removed from [state.messages].
  Future<bool> deleteMessage(MessageModel message) async {
    final id = message.id;
    if (id == null || _pendingMutationIds.contains(id)) return false;

    _pendingMutationIds.add(id);
    state = state.copyWith(clearError: true);
    try {
      final deletedAt = await _repo.deleteMessage(_key.conversationId, id);
      _replaceById(id, message.copyWith(body: '', deletedAt: deletedAt));
      if (ref.exists(conversationsListProvider)) {
        ref.read(conversationsListProvider.notifier).refresh();
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: _friendlyError(e));
      return false;
    } finally {
      _pendingMutationIds.remove(id);
    }
  }

  void _replaceById(int id, MessageModel replacement) {
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id == id) replacement else m,
      ],
    );
  }

  /// Canonical reconciliation entry point — every message source (optimistic
  /// send, HTTP response, realtime `message.created`, reconnect reconcile)
  /// routes through this instead of independently appending. Identity is
  /// [MessageModel.sameLogicalMessage]: server [MessageModel.id] once known,
  /// [MessageModel.clientMessageId] while still optimistic — so the
  /// optimistic placeholder, the HTTP response, and a same-message realtime
  /// echo all resolve to exactly one row no matter what order they arrive
  /// in, while two genuinely separate sends (different clientMessageId)
  /// never collapse into one.
  void _upsertMessage(MessageModel incoming) {
    final idx = state.messages.indexWhere(
      (m) => m.sameLogicalMessage(incoming),
    );
    if (idx == -1) {
      state = state.copyWith(messages: [incoming, ...state.messages]);
    } else {
      final next = [...state.messages];
      next[idx] = incoming;
      state = state.copyWith(messages: next);
    }
  }

  /// Whether this thread's ChatScreen is currently foregrounded/visible —
  /// gates `_markRead()` so a message is only ever marked read while the
  /// user is actually looking at the conversation (see COMMAND 02 Part 6:
  /// never advance the read marker just because the provider/realtime
  /// listener happens to be alive while the app is backgrounded). Defaults
  /// true — the controller is only ever built while its screen is mounted,
  /// which starts foregrounded by definition.
  bool _isForeground = true;

  /// Called from `ChatScreen.didChangeAppLifecycleState` — see
  /// `stopTypingForBackground` for the equivalent typing-side lifecycle
  /// hook this mirrors.
  void setForeground(bool isForeground) {
    _isForeground = isForeground;
  }

  Future<void> _markRead() async {
    if (!_isForeground) return;
    try {
      await _repo.markRead(_key.conversationId);
      // Same `ref.exists` guard as `applyOutgoingMessage` — don't wake/fetch
      // an Inbox the user never opened just to clear a badge nothing is
      // displaying yet.
      if (ref.exists(conversationsListProvider)) {
        ref
            .read(conversationsListProvider.notifier)
            .clearUnreadLocally(_key.conversationId);
      }
      // Home top-bar badge is a separate one-shot fetch (see
      // `messagesUnreadCountProvider`'s doc comment) — invalidate it too so
      // it reflects the just-read conversation next time it's watched.
      ref.invalidate(messagesUnreadCountProvider);
    } catch (_) {
      // Best-effort — an unread badge staying stale briefly is harmless.
    }
  }

  void _onRealtimeEvent(RealtimeMessageEvent event) {
    final conversationId = (event.data['conversationId'] as num?)?.toInt();
    if (event.type == 'message.created' && kDebugMode) {
      final rawId = event.data['messageId'] ?? event.data['id'];
      debugPrint('[Realtime] event=message.created');
      debugPrint('[Realtime] messageId=$rawId');
      debugPrint('[Realtime] conversationId=$conversationId');
      debugPrint('[Thread] controllerConversationId=${_key.conversationId}');
      debugPrint('[Thread] eventConversationId=$conversationId');
    }
    if (conversationId != _key.conversationId) {
      if (kDebugMode && event.type == 'message.created') {
        debugPrint('[Thread] accepted=false');
        debugPrint('[Thread] reason=conversation mismatch');
      }
      return;
    }

    switch (event.type) {
      case 'message.created':
        // Tolerate either field name: the backend's `message.created`
        // realtime payload historically only carried `id` (matching the
        // REST response shape) while `message.updated`/`message.deleted`
        // carry `messageId` — the backend now sends `messageId` here too
        // (see `messaging.service.ts`), but falling back to `id` keeps this
        // client correct even against an older/rolled-back API build.
        final rawId = event.data['messageId'] ?? event.data['id'];
        final rawSenderId = event.data['senderId'];
        if (rawId is! num || rawSenderId is! num) {
          if (kDebugMode) {
            debugPrint('[Thread] accepted=false');
            debugPrint('[Thread] reason=invalid payload');
          }
          return;
        }
        final messageId = rawId.toInt();
        final eventSenderId = rawSenderId.toInt();
        final beforeCount = state.messages.length;
        final isGenuinelyNew = ref
            .read(messageNotificationCoordinatorProvider)
            .claimMessage(messageId);
        if (kDebugMode) {
          debugPrint('[Thread] accepted=true');
          debugPrint(
            '[Thread] reason=${isGenuinelyNew ? 'new message' : 'duplicate (already claimed by another transport)'}',
          );
          debugPrint('[Thread] beforeCount=$beforeCount');
        }
        // Subtle foreground sound: only for a genuinely new incoming
        // message from the OTHER participant, while this exact
        // conversation is the one currently open — never for the sender's
        // own echo, a duplicate/already-claimed delivery, or history load
        // (this branch only ever runs for a live realtime event, never the
        // initial REST page fetch in _init()).
        final myId = ref.read(currentUserProvider).userId;
        if (isGenuinelyNew && myId != null && eventSenderId != myId) {
          unawaited(_playIncomingMessageSound());
        }
        // `event.data` carries the exact same shape as the REST/send-
        // response payload (`messagePayload` in messaging.service.ts is
        // spread directly into the SSE event) — including `attachments`.
        // Parsing it through the same `MessageModel.fromApi` used for REST
        // history keeps realtime and REST media rendering identical (Part
        // 11): building this by hand field-by-field previously dropped
        // `attachments` entirely, so a media message delivered via SSE
        // rendered with no attachment at all until the thread next
        // reconciled from REST.
        final incoming = MessageModel.fromApi(
          event.data,
        ).copyWith(id: messageId);
        _mergeIncoming(incoming);
      case 'message.updated':
        final id = (event.data['messageId'] as num?)?.toInt();
        if (id == null) return;
        final existing = state.messages.where((m) => m.id == id).firstOrNull;
        if (existing == null) return;
        _replaceById(
          id,
          existing.copyWith(
            body: event.data['body']?.toString() ?? existing.body,
            editedAt:
                DateTime.tryParse(
                  event.data['editedAt']?.toString() ?? '',
                )?.toLocal() ??
                existing.editedAt,
          ),
        );
      case 'message.deleted':
        final id = (event.data['messageId'] as num?)?.toInt();
        if (id == null) return;
        final existing = state.messages.where((m) => m.id == id).firstOrNull;
        if (existing == null) return;
        _replaceById(
          id,
          existing.copyWith(body: '', deletedAt: DateTime.now()),
        );
      case 'message.read':
        // Advances the Messenger-style "seen" marker — server-authoritative,
        // conversation-scoped by the guard above. Only the *other*
        // participant's read position matters here (our own read events
        // echo back too, for the Inbox's unread-clear path — see
        // `ConversationsListController`); this thread ignores the caller's
        // own echo and never regresses an already-advanced position (e.g.
        // an out-of-order duplicate delivery of an older read event).
        final readerId = (event.data['readerId'] as num?)?.toInt();
        final lastReadMessageId = (event.data['lastReadMessageId'] as num?)
            ?.toInt();
        if (readerId == null || lastReadMessageId == null) return;
        if (readerId != _key.otherUserId) return;
        if (lastReadMessageId <= state.otherLastReadMessageId) return;
        state = state.copyWith(otherLastReadMessageId: lastReadMessageId);
      case 'typing.started':
      case 'typing.stopped':
        _handleRemoteTyping(event);
    }
  }

  /// Handles `typing.started`/`typing.stopped`. Malformed/stale/self/wrong-
  /// conversation events are all silently ignored — conversation-scoping is
  /// already done by the `conversationId` guard at the top of
  /// `_onRealtimeEvent`; this only needs to additionally reject the
  /// sender's own echo (the backend never actually sends one — see
  /// `publishTyping` on the backend, which publishes only to the *other*
  /// participant — but this check is a cheap, free extra guarantee that
  /// this client never displays "Typing…" for itself even if that ever
  /// changed).
  void _handleRemoteTyping(RealtimeMessageEvent event) {
    final typingUserId = (event.data['userId'] as num?)?.toInt();
    if (typingUserId == null) return;
    final myId = ref.read(currentUserProvider).userId;
    if (myId != null && typingUserId == myId) return;

    _remoteTypingExpiryTimer?.cancel();
    if (event.type == 'typing.started') {
      state = state.copyWith(remoteTyping: true);
      _remoteTypingExpiryTimer = Timer(
        TypingConstants.remoteExpiry,
        () => state = state.copyWith(remoteTyping: false),
      );
    } else {
      state = state.copyWith(remoteTyping: false);
    }
  }

  /// The subtle "foreground, same conversation already open" incoming-
  /// message cue. No custom audio asset exists in this project (and
  /// per-project policy is not to add a random/unlicensed sound file), so
  /// this deliberately reuses Flutter's built-in system click sound rather
  /// than fabricating a new asset pipeline — a real, audible, zero-asset
  /// cue that respects the OS's own silent/DND state automatically. A
  /// louder banner+channel-sound notification is used instead for the
  /// "foreground but different page" case (see NotificationController's
  /// foreground FCM handling), matching the spec's split between the two.
  Future<void> _playIncomingMessageSound() async {
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {
      // Best-effort — never let a sound failure affect message delivery.
    }
  }

  void _mergeIncoming(MessageModel incoming) {
    _upsertMessage(incoming);
    if (kDebugMode) {
      debugPrint('[Thread] afterCount=${state.messages.length}');
    }
    unawaited(_markRead());
  }
}
