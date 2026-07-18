import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/core/deep_link/deep_link_provider.dart';
import 'package:furtail_app/services/api_client.dart';

import '../../../campaign/data/models/campaign_models.dart';
import '../../../campaign/data/services/campaign_notification_service.dart';
import '../../../campaign/data/services/reminder_storage.dart';
import '../../data/models/notification_item.dart';
import '../../data/models/notification_payload.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/services/notification_service.dart';
import '../../domain/notification_type.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(apiClientProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    repository: ref.read(notificationRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Provider that exposes notification-controller methods to screens
/// without requiring a full rebuild on bootstrap state changes.
final notificationActionsProvider = Provider<NotificationController>((ref) {
  return ref.read(notificationControllerProvider.notifier);
});

/// Holds the in-app notification list (from GET /api/v1/notifications).
class NotificationsListState {
  final List<NotificationItem> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final int? nextCursor;
  final int unreadCount;
  final String? error;

  const NotificationsListState({
    this.items = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.nextCursor,
    this.unreadCount = 0,
    this.error,
  });

  NotificationsListState copyWith({
    List<NotificationItem>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    int? nextCursor,
    int? unreadCount,
    String? error,
  }) {
    return NotificationsListState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      unreadCount: unreadCount ?? this.unreadCount,
      error: error ?? this.error,
    );
  }
}

final notificationsListProvider =
    NotifierProvider<NotificationsListNotifier, NotificationsListState>(
      NotificationsListNotifier.new,
    );

class NotificationsListNotifier extends Notifier<NotificationsListState> {
  @override
  NotificationsListState build() => const NotificationsListState();

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final res = await repo.fetchNotifications();
      state = state.copyWith(
        items: res.items,
        loading: false,
        hasMore: res.hasMore,
        nextCursor: res.nextCursor,
        unreadCount: res.unreadCount,
      );
    } catch (e, st) {
      state = state.copyWith(loading: false, error: e.toString());
      if (kDebugMode) {
        debugPrint('[NotificationsList] load error: $e\n$st');
      }
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final res = await repo.fetchNotifications(cursor: state.nextCursor);
      state = state.copyWith(
        items: [...state.items, ...res.items],
        loadingMore: false,
        hasMore: res.hasMore,
        nextCursor: res.nextCursor,
        unreadCount: res.unreadCount,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> markAsRead(int notificationId) async {
    final repo = ref.read(notificationRepositoryProvider);
    final ok = await repo.markAsRead(notificationId);
    if (ok) {
      state = state.copyWith(
        items: state.items.map((n) {
          if (n.id == notificationId && !n.isRead) {
            return NotificationItem(
              id: n.id,
              type: n.type,
              title: n.title,
              body: n.body,
              actorName: n.actorName,
              actorAvatarUrl: n.actorAvatarUrl,
              actorId: n.actorId,
              deepLink: n.deepLink,
              createdAt: n.createdAt,
              readAt: DateTime.now(),
            );
          }
          return n;
        }).toList(),
        unreadCount: (state.unreadCount - 1).clamp(0, state.unreadCount),
      );
      ref.invalidate(notificationsUnreadCountProvider);
    }
  }

  Future<void> markAllAsRead() async {
    final repo = ref.read(notificationRepositoryProvider);
    final ok = await repo.markAllAsRead();
    if (ok) {
      state = state.copyWith(
        items: state.items.map((n) {
          if (!n.isRead) {
            return NotificationItem(
              id: n.id,
              type: n.type,
              title: n.title,
              body: n.body,
              actorName: n.actorName,
              actorAvatarUrl: n.actorAvatarUrl,
              actorId: n.actorId,
              deepLink: n.deepLink,
              createdAt: n.createdAt,
              readAt: DateTime.now(),
            );
          }
          return n;
        }).toList(),
        unreadCount: 0,
      );
      ref.invalidate(notificationsUnreadCountProvider);
    }
  }

  void prependItem(NotificationItem item) {
    state = state.copyWith(
      items: [item, ...state.items],
      unreadCount: state.unreadCount + 1,
    );
  }
}

/// Simple provider that refreshes the unread count on demand.
final notificationsUnreadCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(notificationRepositoryProvider);
  return repo.fetchUnreadCount();
});

class NotificationBootstrapState {
  final bool ready;
  final bool fcmAvailable;
  final String? fcmToken;

  const NotificationBootstrapState({
    required this.ready,
    this.fcmAvailable = false,
    this.fcmToken,
  });
}

/// Riverpod controller — bootstraps push + local notification stack.
final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, NotificationBootstrapState>(
      NotificationController.new,
    );

class NotificationController extends AsyncNotifier<NotificationBootstrapState> {
  @override
  Future<NotificationBootstrapState> build() async {
    final service = ref.read(notificationServiceProvider);
    final repo = ref.read(notificationRepositoryProvider);

    service.onNotificationTap = _handleNotificationTap;
    service.onIncomingFcm = _handleIncomingFcm;

    await service.initialize();

    final cached = await repo.getCachedFcmToken();
    await _syncVaccinationRemindersFromStorage();

    return NotificationBootstrapState(
      ready: true,
      fcmAvailable: service.fcmAvailable,
      fcmToken: cached,
    );
  }

  NotificationService get _service => ref.read(notificationServiceProvider);

  /// Call after successful login so token registration uses auth header.
  /// Also requests notification permissions at this point (deferred from app startup).
  Future<void> registerPushAfterAuth() async {
    // Request notification permissions now that user is authenticated
    await _service.requestNotificationPermissions();

    if (!_service.fcmAvailable) return;
    final repo = ref.read(notificationRepositoryProvider);
    final cached = await repo.getCachedFcmToken();
    if (cached != null && cached.isNotEmpty) {
      await _service.registerTokenWithBackend(cached);
    } else {
      await refreshFcmToken();
    }
  }

  Future<void> refreshFcmToken() async {
    await _service.initialize();
    final token = await ref
        .read(notificationRepositoryProvider)
        .getCachedFcmToken();
    state = AsyncData(
      NotificationBootstrapState(
        ready: true,
        fcmAvailable: _service.fcmAvailable,
        fcmToken: token,
      ),
    );
  }

  Future<void> unregisterPush() async {
    await _service.unregisterFromBackend();
    state = AsyncData(
      NotificationBootstrapState(
        ready: true,
        fcmAvailable: _service.fcmAvailable,
      ),
    );
  }

  Future<void> showLocal(NotificationPayload payload) =>
      _service.showLocalNotification(payload);

  Future<void> showTyped({
    required AppNotificationType type,
    required String title,
    required String body,
    String? actionUrl,
  }) => _service.showTyped(
    type: type,
    title: title,
    body: body,
    actionUrl: actionUrl,
  );

  Future<void> syncVaccinationReminders(List<VaccinationReminder> reminders) =>
      _service.syncVaccinationReminders(reminders);

  Future<void> _syncVaccinationRemindersFromStorage() async {
    try {
      final storage = ReminderStorage();
      final reminders = await storage.load();
      if (reminders.isNotEmpty) {
        await _service.syncVaccinationReminders(reminders);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationController] reminder sync: $e');
    }
  }

  Future<bool> _handleIncomingFcm(Map<String, dynamic> data) async {
    if (!CampaignNotificationService.isCampaignFcmPayload(data)) return false;
    await ref.read(campaignNotificationServiceProvider).handleFcmData(data);
    return true;
  }

  void _handleNotificationTap(NotificationPayload payload) {
    if (kDebugMode) {
      debugPrint(
        '[NotificationController] tap: ${payload.type.code} ${payload.actionUrl}',
      );
    }
    ref
        .read(notificationRepositoryProvider)
        .savePendingTapPayload(payload.data);

    // Prefer actionUrl from backend; fall back to type-based routing.
    final url = payload.actionUrl;
    if (url != null && url.isNotEmpty) {
      ref.read(deepLinkServiceProvider).handleString(url);
      return;
    }

    // Type-based fallback navigation.
    final deepLink = ref.read(deepLinkServiceProvider);
    switch (payload.type) {
      case AppNotificationType.friendRequestReceived:
      case AppNotificationType.friendRequestAccepted:
      case AppNotificationType.userFollowed:
        if (payload.data['actorId'] != null) {
          deepLink.handleString('/profile/${payload.data['actorId']}');
        }
        break;
      case AppNotificationType.petFollowed:
      case AppNotificationType.petLiked:
        if (payload.data['petId'] != null) {
          deepLink.handleString('/pet/${payload.data['petId']}');
        }
        break;
      case AppNotificationType.adoptionLike:
      case AppNotificationType.adoptionComment:
      case AppNotificationType.adoptionApplicationSubmitted:
      case AppNotificationType.adoptionApplicationApproved:
      case AppNotificationType.adoptionApplicationRejected:
      case AppNotificationType.adoptionListingStatusChanged:
        if (payload.actionUrl != null && payload.actionUrl!.isNotEmpty) {
          deepLink.handleString(payload.actionUrl!);
        }
        break;
      default:
        break;
    }
  }

  Future<Map<String, String>?> consumePendingTap() =>
      ref.read(notificationRepositoryProvider).consumePendingTapPayload();
}
