# Furtail Mobile — Notification System Implementation Report

**Project:** `furtail_app`  
**Date:** 2026-06-04  
**Stack:** Firebase Cloud Messaging (FCM) + `flutter_local_notifications`  
**Status:** Implemented (client); backend FCM send + device-token API pending

---

## 1. Executive summary

Production-grade notification infrastructure is in place under `lib/features/notifications/`, with three layers:

| Module | File | Responsibility |
|--------|------|----------------|
| **NotificationService** | `data/services/notification_service.dart` | FCM + local display, scheduling, foreground/background/killed handling |
| **NotificationRepository** | `data/repositories/notification_repository.dart` | Token cache, API registration, pending tap payload |
| **NotificationController** | `presentation/providers/notification_controller.dart` | Riverpod bootstrap, vaccine reminder sync, public API |

**Supported notification categories (11):**

| # | Type | `AppNotificationType` | Channel ID | Delivery |
|---|------|----------------------|------------|----------|
| 1 | Push (generic) | via FCM payload `type` | per type | FCM |
| 2 | Local | `showLocalNotification` | per type | Local |
| 3 | Campaign reminder | `campaignReminder` | `bpa_campaign_reminder` | Local schedule |
| 4 | Vaccine reminder | `vaccineReminder` | `bpa_vaccine_reminder` | Local schedule |
| 5 | Donation update | `donationUpdate` | `bpa_donation_update` | FCM / local |
| 6 | Community activity | `communityActivity` | `bpa_community_activity` | FCM / local |
| 7 | Comment | `comment` | `bpa_comment` | FCM / local |
| 8 | Like | `like` | `bpa_like` | FCM / local |
| 9 | Follow | `follow` | `bpa_follow` | FCM / local |
| 10 | Announcement | `announcement` | `bpa_announcement` | FCM / local |
| 11 | Emergency | `emergency` | `bpa_emergency` | FCM / local (max priority) |

---

## 2. Architecture

```
main.dart
  ├── FirebaseMessaging.onBackgroundMessage (killed/background FCM)
  ├── Firebase.initializeApp (optional if configured)
  └── ref.watch(notificationControllerProvider) → NotificationService.initialize()

NotificationController (Riverpod)
  └── NotificationService
        ├── FirebaseMessaging (token, refresh, listeners)
        ├── FlutterLocalNotificationsPlugin (channels, show, schedule)
        └── NotificationRepository (prefs + API)

Campaign module
  └── VaccinationRemindersNotifier → syncVaccinationReminders()
```

### App lifecycle coverage

| State | FCM | Local | Implementation |
|-------|-----|-------|----------------|
| **Foreground** | Yes | Yes | `FirebaseMessaging.onMessage` → `showLocalNotification` |
| **Background** | Yes | Yes | `@pragma('vm:entry-point')` `firebaseMessagingBackgroundHandler` |
| **Killed (terminated)** | Yes | Scheduled | `getInitialMessage()` + boot receivers for scheduled local |
| **Tap (open app)** | Yes | Yes | `onMessageOpenedApp`, `onDidReceiveNotificationResponse`, pending payload store |

---

## 3. FCM token lifecycle

| Step | Behavior |
|------|----------|
| **Registration** | After FCM init, `getToken()` → `NotificationRepository.registerDeviceToken()` |
| **Refresh** | `FirebaseMessaging.onTokenRefresh` → re-register |
| **Cache** | `SharedPreferences`: `furtail_fcm_token`, `furtail_fcm_token_synced` |
| **API** | `POST /api/v1/me/device-tokens` (forward-compatible; fails silently until backend exists) |
| **Unregister** | `DELETE /api/v1/me/device-tokens` + clear cache |

**Platform field:** `android` | `ios`

---

## 4. Payload contract (FCM data)

Server should send **data** payload (and optional notification block for system tray when app is backgrounded):

```json
{
  "type": "comment",
  "title": "New comment",
  "body": "Someone commented on your post",
  "actionUrl": "/posts/123",
  "notificationId": "456"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Recommended | Maps to `AppNotificationType.code` |
| `title` | Yes | Notification title |
| `body` / `message` | Yes | Body text |
| `actionUrl` | Optional | Deep link / route hint |
| `notificationId` | Optional | Dedupe / analytics |

---

## 5. Vaccine & campaign reminders

- **Source:** `ReminderStorage` + `VaccinationRemindersNotifier`
- **On save/toggle:** `NotificationController.syncVaccinationReminders()`
- **Schedule:** `dueDate - daysBefore` (default 7 days) via `zonedSchedule`
- **Disable:** Cancels local notification by stable ID (`reminder.id.hashCode`)

**Campaign-specific scheduling API:**

```dart
await notificationService.scheduleCampaignReminder(
  dedupeKey: 'campaign-slot-42',
  title: 'Vaccination tomorrow',
  body: 'Your appointment is at 10:00 AM',
  scheduledDate: DateTime(...),
  actionUrl: '/campaign',
);
```

---

## 6. Files added / changed

### New (`lib/features/notifications/`)

```
domain/notification_type.dart
data/models/notification_payload.dart
data/notification_channels.dart
data/repositories/notification_repository.dart
data/services/notification_service.dart
presentation/providers/notification_controller.dart
```

### Supporting

| File | Change |
|------|--------|
| `lib/firebase_options.dart` | Placeholder Firebase options (run `flutterfire configure`) |
| `lib/main.dart` | Background handler, Firebase init, controller bootstrap |
| `lib/core/network/api_endpoints.dart` | Device token + notification settings URLs |
| `lib/core/storage/local_storage.dart` | (theme only — tokens in repository prefs) |
| `pubspec.yaml` | `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| `android/app/google-services.json` | Placeholder — **replace for real FCM** |
| `android/app/build.gradle.kts` | Google Services plugin |
| `android/app/src/main/AndroidManifest.xml` | `POST_NOTIFICATIONS`, FCM channel meta, boot receivers |
| `ios/Runner/Info.plist` | `remote-notification` background mode |
| `campaign_providers.dart` | Sync local reminders after save/toggle |

---

## 7. Firebase setup (required for production push)

1. Create Firebase project and add Android (`com.example.furtail_app`) + iOS apps.
2. Run from `furtail_app`:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
3. Replace `android/app/google-services.json` and add `ios/Runner/GoogleService-Info.plist`.
4. Upload APNs key in Firebase Console for iOS.
5. Implement backend:
   - `POST /api/v1/me/device-tokens` body: `{ token, platform, provider: "fcm" }`
   - Push sender (Admin SDK or queue) with data payload contract above.

Until Firebase is configured, **local notifications and scheduled vaccine reminders still work**.

---

## 8. Usage (Dart)

```dart
// Bootstrap (automatic via main.dart)
ref.watch(notificationControllerProvider);

// Show in-app local notification
ref.read(notificationControllerProvider.notifier).showTyped(
  type: AppNotificationType.comment,
  title: 'New comment',
  body: '…',
  actionUrl: '/posts/1',
);

// After login — token registers automatically on init/refresh

// Sync vaccine reminders
ref.read(notificationControllerProvider.notifier)
    .syncVaccinationReminders(reminders);
```

---

## 9. Backend integration status

| API | Backend today | Mobile client |
|-----|---------------|---------------|
| `GET /notifications` | Yes | Endpoints defined, UI TBD |
| `GET /notifications/settings` | Yes | `fetchNotificationPrefs()` |
| `POST /me/device-tokens` | **No** | Implemented, graceful failure |
| FCM push send | **No** | Ready to receive |

Existing Prisma `Notification` model uses types like `SYSTEM`, `FINANCE_PAYMENT` — align server push `type` strings with mobile `AppNotificationType.code` when implementing send.

---

## 10. QA checklist

- [ ] Android 13+: grant notification permission on first launch
- [ ] Foreground FCM → local banner appears
- [ ] Background/killed FCM (real Firebase project)
- [ ] Tap notification → `consumePendingTap()` / route (wire in router phase 2)
- [ ] Vaccine reminder toggle ON → scheduled notification fires at due date − N days
- [ ] Token refresh after reinstall
- [ ] App runs without crash when `google-services.json` is placeholder (local-only mode)

---

## 11. Follow-up

- [ ] Notifications inbox screen (drawer destination currently “coming soon”)
- [ ] Deep link router from `actionUrl`
- [ ] Backend `DeviceToken` model + FCM send worker
- [ ] User preference gates per channel (sync with `UserNotificationPrefs`)
- [ ] iOS `GoogleService-Info.plist` + push capability in Xcode

---

## 12. Dependencies

```yaml
firebase_core: ^3.8.1
firebase_messaging: ^15.1.6
flutter_local_notifications: ^18.0.1
flutter_timezone: ^3.0.1
timezone: ^0.9.4
```

---

*End of notification system report.*
