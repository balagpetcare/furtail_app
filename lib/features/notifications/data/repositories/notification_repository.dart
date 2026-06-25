import 'dart:convert';
import 'dart:io';

import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_item.dart';

/// Persists FCM token and syncs with backend (when API is available).
class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  static const _kFcmToken = 'furtail_fcm_token';
  static const _kFcmTokenSynced = 'furtail_fcm_token_synced';

  Future<String?> getCachedFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kFcmToken);
  }

  Future<void> cacheFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFcmToken, token);
    await prefs.remove(_kFcmTokenSynced);
  }

  Future<void> clearFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFcmToken);
    await prefs.remove(_kFcmTokenSynced);
  }

  /// Registers device token with API. Fails silently until backend endpoint ships.
  Future<bool> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await cacheFcmToken(token);
    try {
      await _api.post(
        ApiEndpoints.registerDeviceToken(),
        {
          'token': token,
          'platform': platform,
          'provider': 'fcm',
        },
        auth: true,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFcmTokenSynced, token);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[NotificationRepository] registerDeviceToken: $e');
        debugPrint('$st');
      }
      return false;
    }
  }

  Future<bool> unregisterDeviceToken() async {
    final cached = await getCachedFcmToken();
    if (cached == null) return true;
    try {
      await _api.delete(
        ApiEndpoints.unregisterDeviceToken(),
        auth: true,
      );
    } catch (_) {
      // Best-effort when endpoint missing.
    }
    await clearFcmToken();
    return true;
  }

  Future<Map<String, dynamic>?> fetchNotificationPrefs() async {
    try {
      final res = await _api.get(ApiEndpoints.notificationSettings(), auth: true);
      if (res is Map && res['data'] is Map) {
        return Map<String, dynamic>.from(res['data'] as Map);
      }
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (_) {}
    return null;
  }

  /// Fetch paginated notification list from backend.
  Future<NotificationListResponse> fetchNotifications({int limit = 20, int? cursor}) async {
    try {
      final res = await _api.get(
        ApiEndpoints.notificationsList(limit: limit, cursor: cursor),
        auth: true,
      );
      if (res is Map) {
        return NotificationListResponse.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[NotificationRepository] fetchNotifications: $e');
        debugPrint('$st');
      }
    }
    return const NotificationListResponse(items: []);
  }

  /// Mark a single notification as read.
  Future<bool> markAsRead(int notificationId) async {
    try {
      await _api.patch(
        ApiEndpoints.markNotificationRead(notificationId),
        {},
        auth: true,
      );
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[NotificationRepository] markAsRead: $e');
        debugPrint('$st');
      }
      return false;
    }
  }

  /// Mark all notifications as read.
  Future<bool> markAllAsRead() async {
    try {
      await _api.post(
        ApiEndpoints.markAllNotificationsRead(),
        {},
        auth: true,
      );
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[NotificationRepository] markAllAsRead: $e');
        debugPrint('$st');
      }
      return false;
    }
  }

  /// Fetch unread count from backend.
  Future<int> fetchUnreadCount() async {
    try {
      final res = await _api.get(
        ApiEndpoints.notificationsUnreadCount(),
        auth: true,
      );
      if (res is Map) {
        final raw = res['data'] ?? res['unreadCount'] ?? res['unread_count'];
        if (raw is num) return raw.toInt();
      }
    } catch (_) {}
    return 0;
  }

  static String platformLabel() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  Future<void> savePendingTapPayload(Map<String, String> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bpa_pending_notification_tap', jsonEncode(data));
  }

  Future<Map<String, String>?> consumePendingTapPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('bpa_pending_notification_tap');
    if (raw == null) return null;
    await prefs.remove('bpa_pending_notification_tap');
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return null;
  }
}
