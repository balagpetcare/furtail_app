import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/blocked_user.dart';
import '../models/notification_preferences.dart';
import '../models/privacy_settings.dart';

/// SharedPreferences persistence for settings module.
class SettingsLocalDatasource {
  static const _kNotificationPrefs = 'bpa_settings_notification_prefs';
  static const _kPrivacyPrefs = 'bpa_settings_privacy_prefs';
  static const _kBlockedUsers = 'bpa_settings_blocked_users';

  Future<NotificationPreferences> loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNotificationPrefs);
    if (raw == null || raw.isEmpty) return const NotificationPreferences();
    try {
      final map = jsonDecode(raw);
      if (map is Map) {
        return NotificationPreferences.fromJson(
          Map<String, dynamic>.from(map),
        );
      }
    } catch (_) {}
    return const NotificationPreferences();
  }

  Future<void> saveNotificationPreferences(NotificationPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNotificationPrefs, jsonEncode(value.toJson()));
  }

  Future<PrivacySettings> loadPrivacySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrivacyPrefs);
    if (raw == null || raw.isEmpty) return const PrivacySettings();
    try {
      final map = jsonDecode(raw);
      if (map is Map) {
        return PrivacySettings.fromJson(Map<String, dynamic>.from(map));
      }
    } catch (_) {}
    return const PrivacySettings();
  }

  Future<void> savePrivacySettings(PrivacySettings value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrivacyPrefs, jsonEncode(value.toJson()));
  }

  Future<List<BlockedUser>> loadBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBlockedUsers);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => BlockedUser.fromJson(Map<String, dynamic>.from(e)))
          .where((u) => u.userId > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBlockedUsers(List<BlockedUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(users.map((e) => e.toJson()).toList());
    await prefs.setString(_kBlockedUsers, encoded);
  }
}
