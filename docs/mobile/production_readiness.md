# Furtail Mobile — Production Readiness Audit

**App:** `furtail_app` (Flutter)  
**Audit date:** 2026-06-04  
**Scope:** Client-side production readiness (security, storage, permissions, background work, media, memory, navigation, offline)

## Executive scorecard

| Area | Rating | Summary |
|------|--------|---------|
| API security | **High risk** | HTTP/cleartext defaults in release; no TLS pinning; no global 401 handling |
| Token storage | **High risk** | JWT in plaintext `SharedPreferences`; secure storage unused |
| Permissions | **Medium risk** | Service exists; manifest over-declares unused permissions |
| Background services | **Medium risk** | FCM + local notifications OK; background handler minimal |
| Image uploads | **Medium risk** | Streaming upload exists; size policy not enforced |
| Large file handling | **High risk** | No client timeouts; full-body reads; 80MB limit not applied |
| Memory leaks | **Medium risk** | Video dispose patterns good; `FutureBuilder` anti-patterns; `IndexedStack` |
| Navigation | **Medium risk** | Mixed routing; deep links skip auth; incomplete campaign routes |
| Offline handling | **High risk** | No connectivity layer; no offline queue or cached API reads |

**Overall:** Not production-ready for a public store release without addressing **High** items and completing a release build checklist.

---

## 1. API security

### Current state

| Item | Status | Evidence |
|------|--------|----------|
| HTTPS in production | Fail | `env/prod.json` placeholder; `ApiConfig` release fallback is `http://192.168.10.111:3000` (`lib/core/network/api_config.dart`) |
| Cleartext HTTP | Enabled | `android:usesCleartextTraffic="true"` + `network_security_config.xml` allows LAN IP |
| Auth header | Partial | `Bearer` via `ApiClient` / `PostsRemoteDs` (`lib/services/api_client.dart`) |
| Token refresh | None | No refresh token flow; 401 not handled globally |
| Certificate pinning | None | Standard TLS only |
| Request timeouts | None | `package:http` calls without `timeout` |
| Sensitive logging | Partial | Crashlytics logs network paths/status, not bodies; debug prints in FCM |
| Env injection | Good | `--dart-define-from-file=env/prod.json` documented |

### Findings

1. **Release builds can ship with hardcoded LAN HTTP** if `API_BASE_URL` is not set at build time (`kReleaseMode ? _lanHost : _emulatorHost`).
2. **Cleartext permitted** for dev MinIO/backend — must be disabled or scoped to debug builds only for production.
3. **Dual HTTP stacks:** `ApiClient` (Riverpod) and `PostsRemoteDs` (direct `http` + own token read) — inconsistent security/error handling.
4. **No interceptor** for expired sessions — users see generic errors; tokens may remain after server-side revoke.
5. **Deep links** navigate to protected screens without checking login (`lib/core/deep_link/deep_link_navigator.dart`).

### Recommendations (priority)

| P | Action |
|---|--------|
| P0 | Require `API_BASE_URL=https://…` for all release CI builds; fail build if URL is HTTP or placeholder |
| P0 | Set `usesCleartextTraffic=false` in release; restrict `network_security_config` to debug manifest flavor |
| P1 | Unify networking on one client (Dio or `http` wrapper) with timeouts (connect 15s, receive 60s, upload 300s) |
| P1 | Global 401 handler → `LocalStorage.clearAuth()` + navigate to login |
| P2 | Optional certificate pinning for API host |
| P2 | Auth-gate deep links and push routes that need a session |

---

## 2. Token storage

### Current state

| Store | Data | Mechanism |
|-------|------|-----------|
| `LocalStorage` | `token`, `userName`, `userEmail`, `userId`, `avatarUrl` | `SharedPreferences` (`lib/core/storage/local_storage.dart`) |
| `ApiClient` | `token` | Reads `SharedPreferences` key `"token"` directly |
| `PostsRemoteDs` | `token` | Separate `_token()` from SharedPreferences |
| FCM token | Cached in prefs | `NotificationRepository` |
| Secure storage | **Not used** | `flutter_secure_storage` only transitive (e.g. Facebook SDK) |

### Findings

1. **JWT stored in plaintext** — extractable on rooted devices / backups (Android auto-backup not audited here).
2. **Logout inconsistency:** Settings uses `SettingsRepository.logout()` (clears auth + FCM unregister); drawer logout only removes `token`, `userName`, `userEmail` (`furtail_home_screen.dart` ~312–317) — leaves `userId`, FCM registration, analytics/crashlytics IDs.
3. **No token expiry handling** on client.
4. **No binding** of token to device attestation / biometrics.

### Recommendations

| P | Action |
|---|--------|
| P0 | Store `token` (and refresh token if added) in `flutter_secure_storage` with Android encrypted shared prefs / iOS Keychain |
| P0 | Single `AuthTokenProvider` used by all HTTP layers |
| P1 | Centralize logout in one service; call from drawer, settings, and 401 handler |
| P1 | Clear FCM token, analytics user id, crashlytics user id on every logout |
| P2 | Disable Android backup for auth prefs or exclude from backup rules |

---

## 3. Permissions

### Manifest (`android/app/src/main/AndroidManifest.xml`)

Declared: `INTERNET`, `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` (≤28), `CAMERA`, `RECORD_AUDIO`, `FINE/COARSE_LOCATION`, `READ_CONTACTS`, `WRITE_CONTACTS`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`.

### Code

- `PermissionService` (`lib/core/permissions/permission_service.dart`) — location, mic, camera, contacts, photos, storage with `openAppSettings()`.
- **No Dart usage found** for `READ_CONTACTS` / `WRITE_CONTACTS` — over-declaration risks Play Store rejection.
- Image pickers often use `image_picker` without always routing through `PermissionService`.
- iOS permission strings — verify `Info.plist` (not fully audited in this pass).

### Recommendations

| P | Action |
|---|--------|
| P1 | Remove unused `READ_CONTACTS` / `WRITE_CONTACTS` unless feature ships |
| P1 | Request permissions in-context (just-in-time) before camera/gallery/location |
| P1 | Document iOS `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, etc. |
| P2 | Add `READ_MEDIA_VIDEO` if video pick from gallery on Android 13+ |

---

## 4. Background services

### Implemented

| Service | Behavior |
|---------|----------|
| FCM | `FirebaseMessaging.onBackgroundMessage` → init Firebase only (`main.dart`, `notification_service.dart`) |
| Foreground FCM | `NotificationService` — local notification display, token refresh subscription |
| Local scheduled | Campaign vaccination reminders → `flutter_local_notifications` + boot receiver |
| Deep links | `app_links` stream after app start |
| Post upload | `PostUploadManager` — in-process only, not OS background task |

### Findings

1. **FCM background handler** does not persist or display notifications when app killed (depends on system tray payload).
2. **`RECEIVE_BOOT_COMPLETED`** used for scheduled notifications — acceptable; document battery impact.
3. **No Workmanager** for retry uploads when app backgrounded mid-upload.
4. **Wakelock** used during feed video play (`feed_video_player.dart`) — released on dispose (good).

### Recommendations

| P | Action |
|---|--------|
| P1 | Extend background FCM handler to show local notification when data-only messages arrive |
| P2 | Persist failed uploads and retry with connectivity restoration |
| P2 | Dispose `NotificationService` / cancel FCM subscriptions on logout |

---

## 5. Image uploads

### Current state

| Path | Implementation |
|------|----------------|
| Posts / feed | `PostsRemoteDs.uploadMedia` / `uploadMediaWithProgress` — multipart stream (`lib/features/posts/data/datasources/posts_remote_ds.dart`) |
| Generic | `ApiClient.multipartPost` — `MultipartFile.fromPath` (loads path, no progress) |
| Fundraising / KYC | Reuses `PostsRemoteDs.uploadMedia` |
| Pets | `PetRemoteDataSource` via `ApiClient` or dedicated DS |

### Positive

- Streaming upload with **progress callback** for `File` inputs.
- Image crop/compress in UI (`imageQuality` 85–92, `image_cropper`).

### Findings

1. **`MediaPolicy` limits defined but never enforced** (`lib/core/media/media_policy.dart` — 8MB image, 80MB video — **zero references** in codebase).
2. **No MIME/type validation** before upload.
3. **Duplicate auth** — `PostsRemoteDs` bypasses `ApiClient` crash reporting for some paths.
4. **No retry** on transient network failure.

### Recommendations

| P | Action |
|---|--------|
| P0 | Enforce `MediaPolicy.max*Bytes` before upload; user-facing error |
| P1 | Shared `MediaUploadService` wrapping stream upload + progress + Crashlytics |
| P2 | Server-aligned compression pipeline documented in UI (already noted in video edit) |

---

## 6. Large file handling

### Findings

1. **Full response body in memory:** `streamed.stream.bytesToString()` on upload responses (large error HTML could allocate heavily).
2. **No upload timeout** — 80MB video on slow network can hang indefinitely.
3. **`ApiClient.multipartPost`** reads entire file from disk without size check.
4. **Video** client compression flag in `MediaPolicy` but not wired to a compressor package.
5. **Certificate PDF download** — `certificate_share_service` writes to temp dir (OK); size not capped client-side.

### Recommendations

| P | Action |
|---|--------|
| P0 | Pre-flight `file.length()` vs `MediaPolicy` |
| P1 | Timeouts per operation type; cancel tokens on widget dispose |
| P1 | Stream upload for all large files (avoid loading whole file to memory) |
| P2 | Chunked/resumable uploads if API supports |

---

## 7. Memory leaks & lifecycle

### Positive patterns

- `FeedVideoPlayer` — lazy init, `dispose()` cancels timers, disposes `VideoPlayerController`, disables wakelock (`lib/core/media/feed_video_player.dart`).
- `NotificationService.dispose()` cancels token refresh subscription.
- `DeepLinkService.dispose()` cancels link subscription (call on app teardown if needed).

### Risks

| Issue | Location | Impact |
|-------|----------|--------|
| **Future recreated every build** | `PostDetailsByIdScreen` — `future: _ds.getPostById(...)` inside `build()` | Repeated API calls, memory churn, jank |
| **IndexedStack** | `furtail_home_screen.dart` — 4 tabs kept alive | Shop, services, profile, home all in memory |
| **Feed list + videos** | Many players if visibility not off-screen | Mitigated by lazy `_setup()` on visibility |
| **CachedNetworkImage** | Default cache growth | Mitigated via settings cache clear |
| **Global singletons** | `MediaPlaybackController`, `PostUploadManager` | Listeners must be removed (feed video does) |

### Recommendations

| P | Action |
|---|--------|
| P0 | Fix `PostDetailsByIdScreen` — init `late final Future` in `initState` or use Riverpod `FutureProvider` |
| P1 | Lazy-load non-visible `IndexedStack` children or use `AutomaticKeepAliveClientMixin` selectively |
| P2 | Profile memory with DevTools during feed scroll + reels + post create |
| P2 | Cap in-memory image decode size for thumbnails |

---

## 8. Navigation issues

### Architecture

- Named routes: `AppRouter` + `AppRoutes` (`lib/app/router/app_router.dart`).
- **Many flows bypass router** with raw `MaterialPageRoute` (home, login, fundraising).

### Findings

1. **Inconsistent navigation API** — harder to test, no deep link parity, back-stack surprises.
2. **Deep link campaign** opens `CampaignHubScreen` only — ID in `RouteSettings.arguments` unused (`deep_link_navigator.dart`).
3. **No auth guard** on wallet, fundraising create, post details by id.
4. **`LoginScreen` not const** in router — minor.
5. **Splash** uses `pushReplacement` without named routes — OK but duplicates login/home logic.
6. **Risk of duplicate home routes** on stack when mixing `pushNamed('/home')` vs `MaterialPageRoute(FurtailHomeScreen)`.

### Recommendations

| P | Action |
|---|--------|
| P1 | Migrate to `go_router` or enforce all navigation through `AppRouter` |
| P1 | `AuthRedirect` wrapper for protected routes |
| P2 | Campaign deep link → detail screen when implemented |
| P2 | Document back behavior for FAB / tab stack |

---

## 9. Offline handling

### Current state

| Capability | Status |
|------------|--------|
| Connectivity detection | **None** (`connectivity_plus` not used) |
| Offline UI / banner | **None** |
| API retry / backoff | **None** (except user pull-to-refresh) |
| Local DB / cache of feed | **None** |
| Image cache | **Yes** — `cached_network_image` / `flutter_cache_manager` |
| Settings / prefs | Local persistence only |
| Queued mutations | **None** (posts, comments, donations require network) |

### User experience today

- Failed requests throw `Exception` → snackbars / error text.
- Airplane mode: login fails, feed errors, no graceful degraded mode.
- Pull-to-refresh on home is the primary recovery path.

### Recommendations

| P | Action |
|---|--------|
| P1 | Add `connectivity_plus` + global offline banner |
| P1 | Retry wrapper with exponential backoff for idempotent GETs |
| P2 | Cache last feed page in Hive/SQLite for read-only offline |
| P2 | Queue critical writes (post create) with `PostUploadManager` persistence |

---

## Release build checklist

Use before any store or production APK:

```bash
# 1. Set production API (HTTPS only)
flutter build apk --release --dart-define-from-file=env/prod.json

# 2. Verify defines
# API_BASE_URL must start with https:// and not contain 192.168 or YOUR_DOMAIN placeholder

# 3. Firebase
# flutterfire configure — real google-services.json / GoogleService-Info.plist

# 4. Signing
# Release signing config (currently debug signing in build.gradle.kts — change for Play Store)

# 5. ProGuard / R8
# Review minify rules for Flutter + Firebase

# 6. App Links
# Host assetlinks.json / AASA for app.furtail.global domains

# 7. Manual QA
# - Login / logout (drawer + settings) clears session
# - Upload image near 8MB boundary
# - Airplane mode on feed and post create
# - Deep link post/profile while logged out
# - Background push tap → correct screen
```

---

## Remediation roadmap (suggested order)

### Phase 0 — Blockers (1–2 weeks)

1. HTTPS-only production `API_BASE_URL` + disable cleartext in release manifest  
2. Secure token storage + unified logout  
3. Enforce `MediaPolicy` size limits on upload  
4. Fix `PostDetailsByIdScreen` FutureBuilder pattern  
5. HTTP timeouts + 401 global handler  

### Phase 1 — Hardening (2–4 weeks)

6. Single network layer with Crashlytics reporting  
7. Remove unused dangerous permissions  
8. Auth-gated deep links  
9. Connectivity banner + GET retry  
10. Drawer logout parity with settings  

### Phase 2 — Polish (ongoing)

11. `go_router` migration  
12. Offline feed cache  
13. Upload queue persistence  
14. Certificate pinning (if threat model requires)  

---

## Files referenced

| Topic | Primary paths |
|-------|----------------|
| API config | `lib/core/network/api_config.dart`, `env/prod.json` |
| HTTP client | `lib/services/api_client.dart`, `lib/features/posts/data/datasources/posts_remote_ds.dart` |
| Auth storage | `lib/core/storage/local_storage.dart`, `lib/features/auth/data/repositories/auth_repository_impl.dart` |
| Permissions | `lib/core/permissions/permission_service.dart`, `android/app/src/main/AndroidManifest.xml` |
| Notifications | `lib/features/notifications/data/services/notification_service.dart`, `lib/main.dart` |
| Media policy | `lib/core/media/media_policy.dart` |
| Video lifecycle | `lib/core/media/feed_video_player.dart` |
| Navigation | `lib/app/router/app_router.dart`, `lib/core/deep_link/deep_link_navigator.dart` |
| Home shell | `lib/features/home/presentation/screens/furtail_home_screen.dart` |

---

## Related documentation

- [Notification system](notification_system.md)
- [Deep linking](deep_linking.md)
- [Crash monitoring](crash_monitoring.md)
- [Accessibility audit](accessibility_audit.md)
- [Theme implementation](theme_implementation.md)

---

## Sign-off template

| Role | Name | Date | Approved |
|------|------|------|----------|
| Mobile lead | | | |
| Security | | | |
| QA | | | |
| Product | | | |

**Audit conclusion:** Address all **Phase 0** items and complete the release checklist before calling the mobile client production-ready for end users.
