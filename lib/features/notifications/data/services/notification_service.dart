import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../../firebase_options.dart';
import '../../../campaign/data/models/campaign_models.dart';
import '../../domain/notification_type.dart';
import '../models/notification_payload.dart';
import '../notification_channels.dart';
import '../repositories/notification_repository.dart';

/// Top-level FCM background handler (killed / background).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    debugPrint('[FCM] background message: ${message.messageId}');
  }
}

typedef NotificationTapCallback = void Function(NotificationPayload payload);
typedef IncomingFcmHandler = Future<bool> Function(Map<String, dynamic> data);

/// Orchestrates FCM + local notifications.
class NotificationService {
  NotificationService({required NotificationRepository repository})
      : _repository = repository;

  final NotificationRepository _repository;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging? _messaging;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  bool _fcmAvailable = false;

  bool get isInitialized => _initialized;
  bool get fcmAvailable => _fcmAvailable;

  NotificationTapCallback? onNotificationTap;
  IncomingFcmHandler? onIncomingFcm;

  Future<void> initialize() async {
    if (_initialized) return;

    await _initTimezone();
    await _initLocalNotifications();
    await _initFirebaseMessaging();

    _initialized = true;
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<void> _initTimezone() async {
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackgroundHandler,
    );

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      for (final ch in NotificationChannels.androidChannels()) {
        await androidPlugin.createNotificationChannel(ch);
      }
    }

    final iosPlugin = _local
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final data = <String, String>{'rawPayload': payload};
    final parsed = NotificationPayload.fromFcmMap(data);
    onNotificationTap?.call(parsed);
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _messaging = FirebaseMessaging.instance;
      _fcmAvailable = true;

      await _requestFcmPermission();

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      final initial = await _messaging!.getInitialMessage();
      if (initial != null) {
        await _handleOpenedMessage(initial);
      }

      final token = await _messaging!.getToken();
      if (token != null && token.isNotEmpty) {
        await registerTokenWithBackend(token);
      }

      _tokenRefreshSub = _messaging!.onTokenRefresh.listen((token) async {
        await registerTokenWithBackend(token);
      });
    } catch (e, st) {
      _fcmAvailable = false;
      if (kDebugMode) {
        debugPrint('[NotificationService] FCM unavailable: $e');
        debugPrint('$st');
      }
    }
  }

  Future<void> _requestFcmPermission() async {
    if (_messaging == null) return;
    await _messaging!.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> registerTokenWithBackend(String token) async {
    await _repository.registerDeviceToken(
      token: token,
      platform: NotificationRepository.platformLabel(),
    );
  }

  Future<void> unregisterFromBackend() => _repository.unregisterDeviceToken();

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    if (onIncomingFcm != null) {
      final handled = await onIncomingFcm!(message.data);
      if (handled) return;
    }
    final payload = _payloadFromRemoteMessage(message);
    await showLocalNotification(payload);
  }

  Future<void> _onMessageOpenedApp(RemoteMessage message) async {
    await _handleOpenedMessage(message);
  }

  Future<void> _handleOpenedMessage(RemoteMessage message) async {
    final payload = _payloadFromRemoteMessage(message);
    await _repository.savePendingTapPayload(payload.data);
    onNotificationTap?.call(payload);
  }

  NotificationPayload _payloadFromRemoteMessage(RemoteMessage message) {
    final merged = <String, dynamic>{
      ...message.data,
      if (message.notification?.title != null)
        'title': message.notification!.title,
      if (message.notification?.body != null)
        'body': message.notification!.body,
    };
    return NotificationPayload.fromFcmMap(merged);
  }

  /// Shows a local notification immediately (foreground FCM or in-app events).
  Future<void> showLocalNotification(NotificationPayload payload) async {
    final type = payload.type;
    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.idFor(type),
      type.code,
      channelDescription: type.code,
      importance: _importanceFor(type),
      priority: _priorityFor(type),
      icon: '@mipmap/launcher_icon',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final id = _notificationId(payload);
    await _local.show(
      id,
      payload.title,
      payload.body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload.actionUrl ?? payload.type.code,
    );
  }

  Future<void> showTyped({
    required AppNotificationType type,
    required String title,
    required String body,
    String? actionUrl,
    String? dedupeKey,
  }) {
    return showLocalNotification(
      NotificationPayload.local(
        type: type,
        title: title,
        body: body,
        actionUrl: actionUrl,
        dedupeKey: dedupeKey,
      ),
    );
  }

  Future<void> cancelNotification(int id) => _local.cancel(id);

  Future<void> cancelByDedupeKey(String dedupeKey) async {
    await cancelNotification(_stableId(dedupeKey));
  }

  /// Schedules enabled vaccination reminders as local notifications.
  Future<void> syncVaccinationReminders(List<VaccinationReminder> reminders) async {
    for (final r in reminders) {
      final id = _stableId(r.id);
      if (!r.enabled) {
        await _local.cancel(id);
        continue;
      }
      final scheduled = r.dueDate.subtract(Duration(days: r.daysBefore));
      if (scheduled.isBefore(DateTime.now())) {
        await _local.cancel(id);
        continue;
      }
      await _schedule(
        id: id,
        type: AppNotificationType.vaccineReminder,
        title: 'Vaccine reminder',
        body: '${r.petName}: ${r.vaccineType} due on ${_formatDate(r.dueDate)}',
        scheduledDate: scheduled,
        payload: '/campaign/reminders',
      );
    }
  }

  Future<void> scheduleCampaignReminder({
    required String dedupeKey,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? actionUrl,
  }) {
    return _schedule(
      id: _stableId(dedupeKey),
      type: AppNotificationType.campaignReminder,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      payload: actionUrl ?? '/campaign',
    );
  }

  Future<void> _schedule({
    required int id,
    required AppNotificationType type,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
      await _local.cancel(id);
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      NotificationChannels.idFor(type),
      type.code,
      channelDescription: type.code,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _local.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  int _notificationId(NotificationPayload payload) {
    final key = payload.notificationId ?? '${payload.type.code}_${payload.title}';
    return _stableId(key);
  }

  int _stableId(String key) => key.hashCode.abs() % 2147483647;

  Importance _importanceFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.emergency:
        return Importance.max;
      case AppNotificationType.campaignReminder:
      case AppNotificationType.vaccineReminder:
      case AppNotificationType.announcement:
        return Importance.high;
      case AppNotificationType.like:
        return Importance.low;
      default:
        return Importance.defaultImportance;
    }
  }

  Priority _priorityFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.emergency:
        return Priority.max;
      case AppNotificationType.campaignReminder:
      case AppNotificationType.vaccineReminder:
        return Priority.high;
      default:
        return Priority.defaultPriority;
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse response) {
  if (kDebugMode) {
    debugPrint('[LocalNotification] background tap: ${response.payload}');
  }
}
