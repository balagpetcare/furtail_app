# Furtail Mobile — Deep Linking System

**Project:** `furtail_app`  
**Date:** 2026-06-04  
**Package:** `app_links`  
**Entry service:** `DeepLinkService` (`lib/core/deep_link/`)

---

## 1. Overview

The app supports deep links from:

| Source | Example |
|--------|---------|
| **Custom scheme** | `furtail://post/42` |
| **Universal / App Links (HTTPS)** | `https://app.furtail.global/post/42` |
| **Push `actionUrl`** | `furtail://post/42`, `/post/42`, `post/42` |

### Supported routes

| Pattern | Screen |
|---------|--------|
| `furtail://campaign/{id}` | `CampaignHubScreen` (id in route args; detail screen TBD) |
| `furtail://post/{id}` | `PostDetailsByIdScreen` → `PostDetailsScreen` |
| `furtail://pet/{id}` | `PetProfileScreen` |
| `furtail://fundraising/{id}` | `FundraisingDetailsScreen` |
| `furtail://profile/{id}` | `VisitorProfileScreen` |

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

### Custom scheme (`furtail://`)

```
furtail://campaign/12
furtail://post/99
furtail://pet/3
furtail://fundraising/7
furtail://profile/1001
```

Parsed as: `scheme=furtail`, `host=<type>`, `path=/<id>`.

### HTTPS (Universal / App Links)

```
https://app.furtail.global/campaign/12
https://app.furtail.global/post/99
```

Parsed as: allowed host + `pathSegments[0]=type`, `pathSegments[1]=id`.

**Default allowed hosts:** `app.furtail.global`, `www.furtail.global`, `furtail.global`

**Override at build:**

```bash
flutter run --dart-define=DEEP_LINK_HOST=app.yourdomain.com
flutter run --dart-define=DEEP_LINK_HOSTS=staging.furtail.global,app.furtail.global
```

---

## 4. Platform configuration

### Android — custom scheme + App Links

`android/app/src/main/AndroidManifest.xml` (inside `MainActivity`):

- Intent filter: `furtail` scheme
- Intent filter: `https` + hosts with `android:autoVerify="true"`

**Digital Asset Links** (required for verified App Links):

Host at:

`https://app.furtail.global/.well-known/assetlinks.json`

See template: [`assetlinks.json.example`](assetlinks.json.example)

```bash
# Release SHA-256 fingerprint
keytool -list -v -keystore your-release.keystore -alias your-alias
```

Package name must match: `com.example.furtail_app` (update when applicationId changes).

Verify:

```bash
adb shell pm get-app-links com.example.furtail_app
```

### iOS — URL scheme + Universal Links

| File | Purpose |
|------|---------|
| `ios/Runner/Info.plist` | `CFBundleURLSchemes` → `furtail` |
| `ios/Runner/Runner.entitlements` | `applinks:app.furtail.global` (+ www, root) |
| `ios/Runner.xcodeproj` | `CODE_SIGN_ENTITLEMENTS` |

**Apple App Site Association** (no file extension):

`https://app.furtail.global/.well-known/apple-app-site-association`

Template: [`apple-app-site-association.example`](apple-app-site-association.example)

Replace `TEAMID` with your Apple Developer Team ID and bundle `com.example.furtailApp`.

Enable **Associated Domains** capability in Xcode (Signing & Capabilities).

---

## 5. API usage (Dart)

```dart
import 'package:furtail_app/core/deep_link/deep_link_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Initialize (done in main.dart post-frame)
await ref.read(deepLinkServiceProvider).initialize();

// Handle programmatically
await ref.read(deepLinkServiceProvider).handleString('furtail://post/12');
await ref.read(deepLinkServiceProvider).handleUri(Uri.parse('https://app.furtail.global/pet/3'));

// Pending cold-start link
await ref.read(deepLinkServiceProvider).flushPending();
```

### Push notification payload

Set FCM data field:

```json
{
  "type": "comment",
  "actionUrl": "furtail://post/456"
}
```

Supported `actionUrl` shapes: full URI, path `/post/456`, or `post/456`.

---

## 6. Testing

### Android (custom scheme)

```bash
adb shell am start -a android.intent.action.VIEW -d "furtail://post/1" com.example.furtail_app
```

### Android (HTTPS)

```bash
adb shell am start -a android.intent.action.VIEW -d "https://app.furtail.global/fundraising/2" com.example.furtail_app
```

### iOS Simulator (custom scheme)

```bash
xcrun simctl openurl booted "furtail://pet/5"
```

### Parser (unit-style manual check)

```dart
DeepLinkParser.parse(Uri.parse('furtail://campaign/10'));
DeepLinkParser.parseString('/post/12');
```

---

## 7. Integration checklist

- [ ] Replace `com.example.furtail_app` / `com.example.furtailApp` with production bundle IDs everywhere
- [ ] Publish `assetlinks.json` on each HTTPS host
- [ ] Publish `apple-app-site-association` on each HTTPS host
- [ ] Add release SHA-256 to asset links
- [ ] Enable Associated Domains in Apple Developer portal
- [ ] QA cold start + warm start + background tap from push
- [ ] Align backend/share links with `https://app.furtail.global/...`

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
