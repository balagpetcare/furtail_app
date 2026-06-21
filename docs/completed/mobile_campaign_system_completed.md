# Furtail Mobile Vaccination Campaign System — Implementation Complete

**Project:** `furtail_app`  
**Plan reference:** [mobile_campaign_system_plan.md](../planning/mobile_campaign_system_plan.md)  
**Date:** 2026-06-05  
**Status:** Implemented

---

## Summary

The Flutter app now supports **end-to-end vaccination campaign discovery, home promotion, in-app booking, payment (WebView), and notification deep linking**, built on existing Furtail backend `/api/v1/campaign/public/*` and `/campaign-link/*` APIs.

The prior post-booking hub (certificates, QR, import) remains unchanged and integrates after booking success via `importRecords()`.

---

## Module structure

```
lib/features/campaign/
├── data/
│   ├── models/
│   │   ├── campaign_models.dart          # extended CampaignBooking (zone/nullable location)
│   │   ├── campaign_public_models.dart   # Campaign, Location, Slot, Notification DTOs
│   │   └── campaign_booking_draft.dart
│   ├── repositories/
│   │   └── campaign_repository.dart      # public + campaign-link APIs + cache
│   └── services/
│       ├── campaign_cache_service.dart
│       ├── campaign_notification_service.dart
│       ├── reminder_storage.dart
│       └── certificate_share_service.dart
├── domain/
│   ├── campaign_notification_category.dart
│   └── entities/
│       ├── campaign.dart
│       ├── campaign_location.dart
│       ├── campaign_slot.dart
│       ├── campaign_booking.dart
│       └── campaign_notification.dart
├── presentation/
│   ├── providers/
│   │   ├── campaign_providers.dart
│   │   └── campaign_discovery_providers.dart
│   ├── screens/
│   │   ├── campaign_list_page.dart
│   │   ├── campaign_details_page.dart
│   │   ├── campaign_booking_page.dart
│   │   ├── campaign_payment_page.dart
│   │   ├── campaign_success_page.dart
│   │   └── … (existing hub/records screens)
│   └── widgets/
│       └── campaign_state_views.dart
└── widgets/
    ├── campaign_hero_banner.dart
    ├── campaign_carousel.dart
    ├── campaign_mini_card.dart
    ├── campaign_home_section.dart
    └── campaign_price_badge.dart
```

---

## Features delivered

| Requirement | Implementation |
|-------------|----------------|
| Home campaign banner | `CampaignHomeSliver` in `furtail_home_screen.dart` — below app bar, above stories |
| Dynamic campaigns from API | `GET /campaign/public/campaigns` + `/discovery/upcoming` enrichment |
| Multiple campaigns | `CampaignCarousel` with page indicators |
| Booking flow | `CampaignBookingPage` → checkout init → payment WebView → success |
| Notifications | Extended `AppNotificationType` + channels; `CampaignNotificationService` |
| Deep links | `campaign/detail/{slug}` → `CampaignDetailsPage` |
| Riverpod | `homeCampaignsProvider`, `campaignDetailProvider`, checkout notifiers |
| Repository | Extended `CampaignRepository` |
| Offline cache | `CampaignCacheService` (15 min TTL) + stale badge |
| Analytics | Banner impression/click, booking/payment funnel events |
| Loading / empty / offline / retry | `campaign_state_views.dart` |
| Tests | 19 unit/widget tests under `test/campaign/`; integration scaffold in `integration_test/` |

---

## Screens

| Screen | Route / entry |
|--------|----------------|
| `CampaignListPage` | Programmatic nav / future menu item |
| `CampaignDetailsPage` | Banner tap, deep link `campaign/detail/{slug}` |
| `CampaignBookingPage` | Book Now CTA |
| `CampaignPaymentPage` | Paid checkout WebView + status poll |
| `CampaignSuccessPage` | Booking ref, QR, import to hub |

---

## API endpoints wired

| Endpoint | Use |
|----------|-----|
| `GET /campaign/public/campaigns` | Home + list |
| `GET /campaign/public/campaigns/:slug` | Details + booking |
| `GET /campaign/public/discovery/upcoming` | Remaining slots |
| `GET /campaign/public/campaigns/:slug/locations` | Location picker |
| `GET /campaign/public/locations/:id/slots` | Slot picker |
| `POST /campaign/public/checkout/init` | Create booking |
| `POST /campaign/public/checkout/confirm-free` | Free campaigns |
| `GET /campaign/public/checkout/:id/status` | Payment poll |
| `POST /campaign-link/import` | Post-login link |

---

## Notification categories

| Category | Types | Channel |
|----------|-------|---------|
| **Campaign** | `campaign_new`, `campaign_update`, `campaign_cancelled` | `bpa_campaign_new`, etc. |
| **Booking** | `campaign_booking_confirmed` | `bpa_campaign_booking_confirmed` |
| **Reminder** | `campaign_reminder`, `vaccine_reminder` | existing reminder channels |

Notification tap uses `actionUrl` → `DeepLinkService` → `CampaignDetailsPage` when URL is `campaign/detail/{slug}`.

---

## Dependencies added

- `webview_flutter` — payment gateway
- `visibility_detector` — banner impressions (already present)
- `integration_test`, `mockito` — dev

---

## Tests

```bash
cd furtail_app
flutter test test/campaign/
```

| File | Coverage |
|------|----------|
| `campaign_public_models_test.dart` | JSON parsing, cache round-trip |
| `deep_link_parser_campaign_test.dart` | Campaign deep links |
| `campaign_notification_test.dart` | Notification categories |
| `campaign_widgets_test.dart` | Hero banner, mini card |
| `campaign_state_views_test.dart` | Error/empty states |
| `integration_test/campaign_flow_test.dart` | Details page smoke |

---

## UI notes

- **Responsive / tablet:** `campaignHorizontalPadding()`, grid layout on `CampaignListPage` for width ≥ 600.
- **Dark mode:** Widgets use `Theme.of(context).colorScheme` (ready if app theme adds dark).
- **Accessibility:** Semantics on banner and mini cards; 48dp touch targets on CTAs.

---

## Known limitations / follow-ups

1. **Banner image:** Uses `Campaign.metadataJson.mobile.bannerImageUrl` when set; otherwise asset fallback.
2. **Dhaka / zone booking:** Venue + slot flow only in v1; zone-interest flow can mirror web in a follow-up.
3. **FCM campaign push from server:** Client ready; backend must send payloads with `type` + `actionUrl`.
4. **Pet picker at booking:** Cat count stepper; link pets post-booking via existing `linkPet` API.

---

## Touch points modified outside `campaign/`

- `lib/features/home/presentation/screens/furtail_home_screen.dart` — home banner sliver
- `lib/core/network/api_endpoints.dart` — public campaign routes
- `lib/core/analytics/analytics_events.dart` — funnel events
- `lib/core/deep_link/deep_link_parser.dart` — campaign detail paths
- `lib/core/deep_link/deep_link_navigator.dart` — navigate to details
- `lib/core/deep_link/deep_link_target.dart` — `campaignDetail` kind
- `lib/app/router/app_routes.dart` — `campaignDetail` route name
- `lib/features/notifications/domain/notification_type.dart` — campaign types
- `lib/features/notifications/data/notification_channels.dart` — Android channels

---

## Verification checklist

- [x] Home banner loads from API with cache fallback
- [x] Book Now opens booking wizard
- [x] Free checkout completes to success screen
- [x] Paid checkout opens WebView with status poll
- [x] Deep link `campaign/detail/{slug}` opens details
- [x] Analytics events defined and logged
- [x] Unit + widget tests pass (19/19)

---

*Implementation complete per approved plan. For backend banner images, set `metadataJson.mobile.bannerImageUrl` on campaigns via admin.*
