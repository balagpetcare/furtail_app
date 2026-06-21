import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bpa_app/core/deep_link/deep_link_provider.dart';
import 'package:bpa_app/services/api_client.dart';

import '../../../campaign/data/models/campaign_models.dart';
import '../../../campaign/data/services/campaign_notification_service.dart';
import '../../../campaign/data/services/reminder_storage.dart';
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
  Future<void> registerPushAfterAuth() async {
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
    final token = await ref.read(notificationRepositoryProvider).getCachedFcmToken();
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
  }) =>
      _service.showTyped(
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
      debugPrint('[NotificationController] tap: ${payload.type.code} ${payload.actionUrl}');
    }
    ref.read(notificationRepositoryProvider).savePendingTapPayload(payload.data);
    final url = payload.actionUrl;
    if (url != null && url.isNotEmpty) {
      ref.read(deepLinkServiceProvider).handleString(url);
    }
  }

  Future<Map<String, String>?> consumePendingTap() =>
      ref.read(notificationRepositoryProvider).consumePendingTapPayload();
}
