import 'dart:io';

import 'package:furtail_app/core/network/api_endpoints.dart';
import 'package:furtail_app/core/storage/local_storage.dart';
import 'package:furtail_app/features/notifications/data/repositories/notification_repository.dart';
import 'package:furtail_app/services/api_client.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../datasources/settings_local_datasource.dart';
import '../models/blocked_user.dart';
import '../models/notification_preferences.dart';
import '../models/privacy_settings.dart';
import '../models/storage_usage_info.dart';

class SettingsRepository {
  SettingsRepository({
    SettingsLocalDatasource? local,
    ApiClient? api,
    NotificationRepository? notificationRepository,
  })  : _local = local ?? SettingsLocalDatasource(),
        _api = api,
        _notificationRepository = notificationRepository;

  final SettingsLocalDatasource _local;
  final ApiClient? _api;
  final NotificationRepository? _notificationRepository;

  Future<NotificationPreferences> getNotificationPreferences() async {
    final local = await _local.loadNotificationPreferences();
    if (_api == null) return local;
    try {
      final server = await NotificationRepository(_api).fetchNotificationPrefs();
      if (server == null) return local;
      return local.copyWith(
        allowEmail: server['allowEmail'] != false,
        allowSms: server['allowSms'] == true,
      );
    } catch (_) {
      return local;
    }
  }

  Future<void> saveNotificationPreferences(NotificationPreferences prefs) async {
    await _local.saveNotificationPreferences(prefs);
    final api = _api;
    if (api == null) return;
    try {
      await api.patch(
        ApiEndpoints.notificationSettings(),
        {
          'allowEmail': prefs.allowEmail,
          'allowSms': prefs.allowSms,
        },
        auth: true,
      );
    } catch (_) {}
  }

  Future<PrivacySettings> getPrivacySettings() =>
      _local.loadPrivacySettings();

  Future<void> savePrivacySettings(PrivacySettings prefs) =>
      _local.savePrivacySettings(prefs);

  Future<List<BlockedUser>> getBlockedUsers() => _local.loadBlockedUsers();

  Future<void> blockUser(BlockedUser user) async {
    final list = await _local.loadBlockedUsers();
    final next = [
      ...list.where((u) => u.userId != user.userId),
      user,
    ];
    await _local.saveBlockedUsers(next);
  }

  Future<void> unblockUser(int userId) async {
    final list = await _local.loadBlockedUsers();
    await _local.saveBlockedUsers(
      list.where((u) => u.userId != userId).toList(),
    );
  }

  Future<StorageUsageInfo> calculateStorageUsage() async {
    int cacheBytes = 0;
    int tempBytes = 0;

    try {
      final cacheDir = await getTemporaryDirectory();
      tempBytes = await _dirSize(cacheDir);
    } catch (_) {}

    try {
      final appTemp = await getApplicationCacheDirectory();
      cacheBytes = await _dirSize(appTemp);
    } catch (_) {}

    try {
      // Default cache manager store (images).
      final libCache = await getApplicationDocumentsDirectory();
      final imageCache = Directory('${libCache.path}/libCachedImageData');
      if (await imageCache.exists()) {
        cacheBytes += await _dirSize(imageCache);
      }
    } catch (_) {}

    return StorageUsageInfo(
      cacheBytes: cacheBytes,
      tempBytes: tempBytes,
      totalBytes: cacheBytes + tempBytes,
    );
  }

  Future<int> clearCache() async {
    int freed = 0;
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}

    try {
      final appTemp = await getApplicationCacheDirectory();
      if (await appTemp.exists()) {
        freed += await _dirSize(appTemp);
        await _deleteDirContents(appTemp);
      }
    } catch (_) {}

    try {
      final temp = await getTemporaryDirectory();
      if (await temp.exists()) {
        freed += await _dirSize(temp);
        await _deleteDirContents(temp);
      }
    } catch (_) {}

    return freed;
  }

  Future<void> logout() async {
    await _notificationRepository?.unregisterDeviceToken();
    await LocalStorage.clearAuth();
  }

  Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  Future<void> _deleteDirContents(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      try {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
  }
}
