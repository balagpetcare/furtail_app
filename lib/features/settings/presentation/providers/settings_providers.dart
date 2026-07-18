import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:furtail_app/core/auth/auth_controller.dart';
import 'package:furtail_app/features/notifications/data/repositories/notification_repository.dart';
import 'package:furtail_app/services/api_client.dart';

import '../../data/datasources/settings_local_datasource.dart';
import '../../data/models/blocked_user.dart';
import '../../data/models/media_upload_settings.dart';
import '../../data/models/notification_preferences.dart';
import '../../data/models/privacy_settings.dart';
import '../../data/models/storage_usage_info.dart';
import '../../data/repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final api = ApiClient();
  return SettingsRepository(
    api: api,
    notificationRepository: NotificationRepository(api),
  );
});

final notificationPreferencesProvider =
    AsyncNotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
  NotificationPreferencesNotifier.new,
);

class NotificationPreferencesNotifier extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    return ref.read(settingsRepositoryProvider).getNotificationPreferences();
  }

  Future<void> apply(NotificationPreferences Function(NotificationPreferences) fn) async {
    final current = state.asData?.value ?? const NotificationPreferences();
    final next = fn(current);
    state = AsyncData(next);
    await ref.read(settingsRepositoryProvider).saveNotificationPreferences(next);
  }
}

final privacySettingsProvider =
    AsyncNotifierProvider<PrivacySettingsNotifier, PrivacySettings>(
  PrivacySettingsNotifier.new,
);

class PrivacySettingsNotifier extends AsyncNotifier<PrivacySettings> {
  @override
  Future<PrivacySettings> build() async {
    return ref.read(settingsRepositoryProvider).getPrivacySettings();
  }

  Future<void> apply(PrivacySettings Function(PrivacySettings) fn) async {
    final current = state.asData?.value ?? const PrivacySettings();
    final next = fn(current);
    state = AsyncData(next);
    await ref.read(settingsRepositoryProvider).savePrivacySettings(next);
  }
}

final blockedUsersProvider =
    AsyncNotifierProvider<BlockedUsersNotifier, List<BlockedUser>>(
  BlockedUsersNotifier.new,
);

class BlockedUsersNotifier extends AsyncNotifier<List<BlockedUser>> {
  @override
  Future<List<BlockedUser>> build() async {
    return ref.read(settingsRepositoryProvider).getBlockedUsers();
  }

  Future<void> block(BlockedUser user) async {
    await ref.read(settingsRepositoryProvider).blockUser(user);
    state = AsyncData(await ref.read(settingsRepositoryProvider).getBlockedUsers());
  }

  Future<void> unblock(int userId) async {
    await ref.read(settingsRepositoryProvider).unblockUser(userId);
    state = AsyncData(await ref.read(settingsRepositoryProvider).getBlockedUsers());
  }
}

final storageUsageProvider =
    AsyncNotifierProvider<StorageUsageNotifier, StorageUsageInfo>(
  StorageUsageNotifier.new,
);

class StorageUsageNotifier extends AsyncNotifier<StorageUsageInfo> {
  @override
  Future<StorageUsageInfo> build() async {
    return ref.read(settingsRepositoryProvider).calculateStorageUsage();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).calculateStorageUsage(),
    );
  }

  Future<int> clearCache() async {
    final freed = await ref.read(settingsRepositoryProvider).clearCache();
    await refresh();
    return freed;
  }
}

final settingsLogoutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(settingsRepositoryProvider).logout();
    await ref.read(authControllerProvider.notifier).logout();
  };
});

// ── Media upload settings ──────────────────────────────────────────────────

final _mediaUploadDatasource = Provider<SettingsLocalDatasource>(
  (_) => SettingsLocalDatasource(),
);

final mediaUploadSettingsProvider =
    AsyncNotifierProvider<MediaUploadSettingsNotifier, MediaUploadSettings>(
  MediaUploadSettingsNotifier.new,
);

class MediaUploadSettingsNotifier extends AsyncNotifier<MediaUploadSettings> {
  @override
  Future<MediaUploadSettings> build() async {
    return ref.read(_mediaUploadDatasource).loadMediaUploadSettings();
  }

  Future<void> patch(MediaUploadSettings Function(MediaUploadSettings) fn) async {
    final current = state.asData?.value ?? const MediaUploadSettings();
    final next = fn(current);
    state = AsyncData(next);
    await ref.read(_mediaUploadDatasource).saveMediaUploadSettings(next);
  }
}
