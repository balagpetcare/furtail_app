# BPA Mobile — Deep Linking System

**Project:** `bpa_app`  
**Date:** 2026-06-04  
**Package:** `app_links`  
**Entry service:** `DeepLinkService` (`lib/core/deep_link/`)

---

## 1. Overview

The app supports deep links from:

| Source | Example |
|--------|---------|
| **Custom scheme** | `bpa://post/42` |
| **Universal / App Links (HTTPS)** | `https://app.bpa.global/post/42` |
| **Push `actionUrl`** | `bpa://post/42`, `/post/42`, `post/42` |

### Supported routes

| Pattern | Screen |
|---------|--------|
| `bpa://campaign/{id}` | `CampaignHubScreen` (id in route args; detail screen TBD) |
| `bpa://post/{id}` | `PostDetailsByIdScreen` → `PostDetailsScreen` |
| `bpa://pet/{id}` | `PetProfileScreen` |
| `bpa://fundraising/{id}` | `FundraisingDetailsScreen` |
| `bpa://profile/{id}` | `VisitorProfileScreen` |

Aliases: `posts`, `pets`, `user`, `donation`, `fundraise`, `campaigns`.

---

## 2. Architecture

```
Incoming URI (app_links)
        │
        ▼
DeepLinkParser.parse(uri)
        │
        ▼
DeepLinkTarget { kind, id }
        │
        ▼
DeepLinkNavigator.navigate(AppNavigator.key)
        │
        ▼
Feature screen
```

| Component | Path |
|-----------|------|
| `DeepLinkConfig` | `lib/core/deep_link/deep_link_config.dart` |
| `DeepLinkParser` | `lib/core/deep_link/deep_link_parser.dart` |
| `DeepLinkService` | `lib/core/deep_link/deep_link_service.dart` |
| `DeepLinkNavigator` | `lib/core/deep_link/deep_link_navigator.dart` |
| `AppNavigator.key` | `lib/core/navigation/app_navigator.dart` |
| Riverpod | `deepLinkServiceProvider` |

### Lifecycle

1. `main.dart` → `MaterialApp(navigatorKey: AppNavigator.key)`
2. Post-frame: `DeepLinkService.initialize()` listens to `uriLinkStream`
3. Cold start: `getInitialLink()` → `pendingTarget` → `flushPending()` after splash/home
4. Notifications: `NotificationController` calls `handleString(actionUrl)` on tap

---

## 3. URL formats

### Custom scheme (`bpa://`)

```
bpa://campaign/12
bpa://post/99
bpa://pet/3
bpa://fundraising/7
bpa://profile/1001
```

Parsed as: `scheme=bpa`, `host=<type>`, `path=/<id>`.

### HTTPS (Universal / App Links)

```
https://app.bpa.global/campaign/12
https://app.bpa.global/post/99
```

Parsed as: allowed host + `pathSegments[0]=type`, `pathSegments[1]=id`.

**Default allowed hosts:** `app.bpa.global`, `www.bpa.global`, `bpa.global`

**Override at build:**

```bash
flutter run --dart-define=DEEP_LINK_HOST=app.yourdomain.com
flutter run --dart-define=DEEP_LINK_HOSTS=staging.bpa.global,app.bpa.global
```

---

## 4. Platform configuration

### Android — custom scheme + App Links

`android/app/src/main/AndroidManifest.xml` (inside `MainActivity`):

- Intent filter: `bpa` scheme
- Intent filter: `https` + hosts with `android:autoVerify="true"`

**Digital Asset Links** (required for verified App Links):

Host at:

`https://app.bpa.global/.well-known/assetlinks.json`

See template: [`assetlinks.json.example`](assetlinks.json.example)

```bash
# Release SHA-256 fingerprint
keytool -list -v -keystore your-release.keystore -alias your-alias
```

Package name must match: `com.example.bpa_app` (update when applicationId changes).

Verify:

```bash
adb shell pm get-app-links com.example.bpa_app
```

### iOS — URL scheme + Universal Links

| File | Purpose |
|------|---------|
| `ios/Runner/Info.plist` | `CFBundleURLSchemes` → `bpa` |
| `ios/Runner/Runner.entitlements` | `applinks:app.bpa.global` (+ www, root) |
| `ios/Runner.xcodeproj` | `CODE_SIGN_ENTITLEMENTS` |

**Apple App Site Association** (no file extension):

`https://app.bpa.global/.well-known/apple-app-site-association`

Template: [`apple-app-site-association.example`](apple-app-site-association.example)

Replace `TEAMID` with your Apple Developer Team ID and bundle `com.example.bpaApp`.

Enable **Associated Domains** capability in Xcode (Signing & Capabilities).

---

## 5. API usage (Dart)

```dart
import 'package:bpa_app/core/deep_link/deep_link_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Initialize (done in main.dart post-frame)
await ref.read(deepLinkServiceProvider).initialize();

// Handle programmatically
await ref.read(deepLinkServiceProvider).handleString('bpa://post/12');
await ref.read(deepLinkServiceProvider).handleUri(Uri.parse('https://app.bpa.global/pet/3'));

// Pending cold-start link
await ref.read(deepLinkServiceProvider).flushPending();
```

### Push notification payload

Set FCM data field:

```json
{
  "type": "comment",
  "actionUrl": "bpa://post/456"
}
```

Supported `actionUrl` shapes: full URI, path `/post/456`, or `post/456`.

---

## 6. Testing

### Android (custom scheme)

```bash
adb shell am start -a android.intent.action.VIEW -d "bpa://post/1" com.example.bpa_app
```

### Android (HTTPS)

```bash
adb shell am start -a android.intent.action.VIEW -d "https://app.bpa.global/fundraising/2" com.example.bpa_app
```

### iOS Simulator (custom scheme)

```bash
xcrun simctl openurl booted "bpa://pet/5"
```

### Parser (unit-style manual check)

```dart
DeepLinkParser.parse(Uri.parse('bpa://campaign/10'));
DeepLinkParser.parseString('/post/12');
```

---

## 7. Integration checklist

- [ ] Replace `com.example.bpa_app` / `com.example.bpaApp` with production bundle IDs everywhere
- [ ] Publish `assetlinks.json` on each HTTPS host
- [ ] Publish `apple-app-site-association` on each HTTPS host
- [ ] Add release SHA-256 to asset links
- [ ] Enable Associated Domains in Apple Developer portal
- [ ] QA cold start + warm start + background tap from push
- [ ] Align backend/share links with `https://app.bpa.global/...`

---

## 8. Known limitations

| Item | Notes |
|------|--------|
| `campaign/{id}` | Opens **Campaign Hub**; dedicated campaign detail by ID is a follow-up |
| Login-gated routes | Deep link may open screen before auth — add guard in phase 2 |
| `post` ID | Must be numeric for API `getPostById` |
| iOS entitlements | Requires Apple Developer program + domain verification |

---

## 9. Related docs

- [`notification_system.md`](notification_system.md) — FCM `actionUrl` integration
- [`theme_implementation.md`](theme_implementation.md)

---

*End of deep linking documentation.*
