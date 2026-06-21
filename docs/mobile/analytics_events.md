# Furtail Mobile — Analytics Event Catalog

Firebase Analytics via [`AnalyticsService`](../../lib/core/analytics/analytics_service.dart).

## Setup

1. Configure Firebase (`flutterfire configure`) so `firebase_options.dart` is valid.
2. Dependency: `firebase_analytics` (with `firebase_core`).
3. `AnalyticsService.initialize()` runs from `main.dart` after `Firebase.initializeApp`.
4. Debug: events print to console when `kDebugMode` is true.

## Event catalog

| Product event | Firebase event name | When fired | Standard Firebase API |
|---------------|---------------------|------------|------------------------|
| **Login** | `login` | Email/password, Google, or Facebook sign-in succeeds | `logLogin` + custom `login` |
| **Registration** | `sign_up` | New account registration succeeds | `logSignUp` + custom `sign_up` |
| **Pet Created** | `pet_created` | New pet saved via pet form (not edit) | `logEvent` |
| **Campaign Registered** | `campaign_registered` | User imports campaign bookings from phone (`campaign-link/import`) | `logEvent` |
| **Donation Made** | `donation_made` | Fundraising donate API succeeds | `logEvent` |
| **Post Created** | `post_created` | Post/reel/video publish succeeds | `logEvent` |
| **Comment Created** | `comment_created` | Comment or reply posted successfully | `logEvent` |
| **Profile Viewed** | `profile_viewed` | Visitor profile screen loads profile data | `logEvent` |
| **QR Viewed** | `qr_viewed` | QR viewer screen opened | `logEvent` |
| **Certificate Viewed** | `certificate_viewed` | Certificate viewer loads certificate data | `logEvent` |

Constants live in [`analytics_events.dart`](../../lib/core/analytics/analytics_events.dart).

## Parameters

| Parameter | Type | Used on events | Description |
|-----------|------|----------------|-------------|
| `method` | string | `login`, `sign_up` | `email`, `google`, `facebook` |
| `pet_id` | int | `pet_created` | Created pet ID |
| `species` | string | `pet_created` | Optional species label |
| `imported_count` | int | `campaign_registered` | Optional count from import API |
| `campaign_id` | int | `donation_made` | Fundraising campaign ID |
| `amount` | num | `donation_made` | Donation amount |
| `currency` | string | `donation_made` | Default `BDT` |
| `post_type` | string | `post_created` | `TEXT`, `IMAGE`, `VIDEO`, `REEL`, etc. |
| `post_id` | int | `post_created`, `comment_created` | Post ID when known |
| `comment_id` | int | `comment_created` | New comment ID when known |
| `is_reply` | bool | `comment_created` | `true` for thread replies |
| `profile_user_id` | int | `profile_viewed` | Viewed user ID |
| `source` | string | `profile_viewed`, `qr_viewed` | e.g. `in_app`, `deep_link` |
| `has_token` | bool | `certificate_viewed` | Whether a certificate token was present (token value is **not** logged) |

## User identity

- After **login**, `AnalyticsService.setUserIdFromStorage()` sets Firebase user ID from `LocalStorage` `userId`.
- On **logout**, call `AnalyticsService.instance.clearUserId()` (wire when centralizing logout).

## Instrumentation map

| Event | File / trigger |
|-------|----------------|
| Login | `login_screen.dart` — email, Google, Facebook success |
| Registration | `register_screen.dart` — registration success |
| Pet Created | `pet_form_cubit.dart` — create (non-edit) success |
| Campaign Registered | `campaign_hub_screen.dart` — import records success |
| Donation Made | `fundraising_details_screen.dart` — donate success |
| Post Created | `create_post_screen.dart` — after `createPost` |
| Comment Created | `post_details_screen.dart`, `comments_sheet.dart` — after add/reply |
| Profile Viewed | `visitor_profile_screen.dart` — first successful profile load |
| QR Viewed | `qr_viewer_screen.dart` — screen open |
| Certificate Viewed | `certificate_viewer_screen.dart` — certificate data loaded |

## Usage

```dart
import 'package:furtail_app/core/analytics/analytics_service.dart';

await AnalyticsService.instance.logPetCreated(petId: 12);

// With Riverpod
ref.read(analyticsServiceProvider).logDonationMade(
  campaignId: 5,
  amount: 500,
);
```

## Privacy

- Do not log passwords, tokens, or PII in event parameters.
- Certificate/QR flows log `has_token` / `source` only, not raw tokens.

## Firebase console

Events appear under **Analytics → Events** (may take up to 24h for first aggregates). Use **DebugView** with:

```bash
# Android
adb shell setprop debug.firebase.analytics.app <package_name>
```

Replace `<package_name>` with your app applicationId from `android/app/build.gradle`.
