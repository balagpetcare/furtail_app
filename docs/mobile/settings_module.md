# App Settings Module (BPA Mobile)

Complete settings experience under `lib/features/settings/` with **Riverpod** state and **SharedPreferences** persistence.

## Features

| Feature | Location | Persistence |
|--------|----------|-------------|
| Theme (Light / Dark / System) | Settings hub | `LocalStorage` (`theme_mode`) via `themeModeProvider` |
| Language (EN / BN) | Settings hub | `LocalStorage` (`locale`) via `localeControllerProvider` |
| Media playback | Settings hub | `MediaPlaybackController` (existing) |
| Notification preferences | `NotificationPreferencesScreen` | `bpa_settings_notification_prefs` + optional API sync |
| Privacy | `PrivacySettingsScreen` | `bpa_settings_privacy_prefs` |
| Blocked users | `BlockedUsersScreen` | `bpa_settings_blocked_users` (JSON list) |
| Storage usage & cache | `StorageCacheScreen` | Computed on demand; clear wipes cache/temp dirs |
| Logout | Settings hub | Clears auth + unregisters FCM (best-effort) |

## Architecture

```
lib/features/settings/
├── data/
│   ├── models/
│   │   ├── notification_preferences.dart
│   │   ├── privacy_settings.dart
│   │   ├── blocked_user.dart
│   │   └── storage_usage_info.dart
│   ├── datasources/
│   │   └── settings_local_datasource.dart
│   └── repositories/
│       └── settings_repository.dart
└── presentation/
    ├── providers/
    │   └── settings_providers.dart
    ├── widgets/
    │   └── settings_widgets.dart
    └── screens/
        ├── settings_screen.dart
        ├── notification_preferences_screen.dart
        ├── privacy_settings_screen.dart
        ├── blocked_users_screen.dart
        └── storage_cache_screen.dart
```

### Riverpod providers

- `settingsRepositoryProvider` — repository with `ApiClient` + `NotificationRepository`
- `notificationPreferencesProvider` — load/save notification toggles
- `privacySettingsProvider` — load/save privacy toggles
- `blockedUsersProvider` — local block list
- `storageUsageProvider` — size scan + `clearCache()`
- `settingsLogoutProvider` — `Future<void> Function()` for sign-out

Theme and language remain in `lib/core/theme/theme_mode_provider.dart` and `lib/core/localization/locale_controller.dart` (used by the hub).

## Navigation

- Route: `AppRoutes.settings` → `SettingsScreen` (`app_router.dart`)
- Sub-screens: pushed with `MaterialPageRoute` from the hub

## Local storage keys

| Key | Content |
|-----|---------|
| `bpa_settings_notification_prefs` | JSON `NotificationPreferences` |
| `bpa_settings_privacy_prefs` | JSON `PrivacySettings` |
| `bpa_settings_blocked_users` | JSON array of `BlockedUser` |

Auth/theme/locale continue to use existing `LocalStorage` keys.

## API integration

- **Notification settings**: On save, `PATCH /api/v1/notifications/settings` with `allowEmail` / `allowSms` when logged in (best-effort).
- **Logout**: `LocalStorage.clearAuth()` + `NotificationRepository.unregisterDeviceToken()`.
- **Blocked users**: Local-only until a backend block-list API exists.

## Cache management

`SettingsRepository.clearCache()`:

1. `DefaultCacheManager().emptyCache()` (network images)
2. Deletes contents of application cache and temp directories
3. Refreshes `storageUsageProvider`

## Usage

```dart
// Read notification prefs elsewhere
final prefs = ref.watch(notificationPreferencesProvider);
if (prefs.asData?.value.pushEnabled == true) { ... }

// Block a user programmatically
await ref.read(blockedUsersProvider.notifier).block(
  BlockedUser(userId: 42, displayName: 'Name', blockedAt: DateTime.now()),
);
```

## Localization

Strings added to `lib/l10n/app_en.arb` and `app_bn.arb`. Regenerate after edits:

```bash
flutter gen-l10n
```

## Future work

- Server sync for privacy and blocked users
- Enforce notification channel toggles in `NotificationService` / FCM topic subscription
- Block user from profile actions (wire to `blockedUsersProvider`)
