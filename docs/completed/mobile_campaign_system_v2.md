# Furtail Mobile Vaccination Campaign System v2 — Smart Campaign Engine

**Project:** `furtail_app`  
**Prior version:** [mobile_campaign_system_completed.md](./mobile_campaign_system_completed.md)  
**Plan reference:** [mobile_campaign_system_plan.md](../planning/mobile_campaign_system_plan.md)  
**Date:** 2026-06-05  
**Status:** Implemented

---

## Executive summary

Version 2 adds the **Smart Campaign Engine** — a reusable orchestration layer on top of the v1 discovery/booking stack. It delivers geo-targeted notifications, vaccine-specific reminder schedules, live countdown on the home banner, emergency broadcast handling, priority-based homepage placement, A/B testing, and a local performance dashboard.

The architecture is **program-type agnostic** via `FurtailCampaignType` and `SmartCampaignConfig`, so future Deworming, Sterilization, Health Checkup, and Adoption campaigns reuse the same engine with different metadata.

---

## Feature delivery matrix

| # | Feature | Implementation | Entry points |
|---|---------|----------------|--------------|
| 1 | Geo-targeted notifications | `GeoTargetingService`, `UserGeoPreferencesService`, `CampaignGeoPreferencesPage` | Hub → Area Prefs; FCM via `CampaignNotificationService.handleFcmData` |
| 2 | Vaccination reminder engine | `VaccinationReminderEngine` — Cat Flu 7/3/0d, Rabies 30/7/0d | `smartVaccinationReminderSyncProvider` |
| 3 | Campaign countdown | `CampaignCountdownService` + `CampaignCountdownStrip` on banner | `GET /campaign/public/campaigns/:slug/countdown` |
| 4 | Emergency broadcast | `EmergencyBroadcastHandler` | FCM types: `emergency_broadcast`, `disease_outbreak_alert`, `campaign_extension` |
| 5 | Dynamic homepage priority | `CampaignPriority` HIGH/MEDIUM/LOW + `GeoTargetingService.sortByPriority` | `SmartCampaignEngine.prepareHomeCampaigns` |
| 6 | A/B testing | `CampaignAbTestingService` stable variant per user | Analytics + `CampaignPerformanceTracker` |
| 7 | Performance dashboard | `CampaignPerformanceDashboardPage` | Hub → Performance |
| 8 | Reusable architecture | `FurtailCampaignType`, `SmartCampaignConfig` | Admin `metadataJson.mobile` |

---

## Architecture

```
SmartCampaignEngine
├── GeoTargetingService          → filter + sort by priority
├── CampaignAbTestingService     → variant A/B assignment
├── CampaignCountdownService     → booking window countdown
├── UserGeoPreferencesService    → city / district / service area
├── VaccinationReminderEngine    → multi-offset local schedules
├── EmergencyBroadcastHandler    → urgent FCM types
└── CampaignPerformanceTracker   → views / clicks / bookings / revenue

PublicCampaign
└── smartConfig: SmartCampaignConfig
    ├── campaignType (VACCINATION | DEWORMING | …)
    ├── priority (HIGH | MEDIUM | LOW)
    ├── geoTarget (cities, districts, serviceAreas)
    ├── abTestKey + abVariants
    └── countdownEnabled
```

### Module layout (new / extended)

```
lib/features/campaign/
├── domain/smart_campaign/
│   ├── furtail_campaign_type.dart
│   ├── campaign_priority.dart
│   ├── campaign_geo_target.dart
│   ├── campaign_ab_variant.dart
│   └── smart_campaign_config.dart
├── data/
│   ├── models/campaign_countdown.dart
│   ├── models/campaign_performance_metrics.dart
│   └── services/
│       ├── smart_campaign_engine.dart
│       ├── geo_targeting_service.dart
│       ├── user_geo_preferences_service.dart
│       ├── campaign_countdown_service.dart
│       ├── campaign_ab_testing_service.dart
│       ├── campaign_performance_tracker.dart
│       ├── vaccination_reminder_engine.dart
│       └── emergency_broadcast_handler.dart
├── presentation/
│   ├── providers/smart_campaign_providers.dart
│   └── screens/
│       ├── campaign_performance_dashboard_page.dart
│       └── campaign_geo_preferences_page.dart
└── widgets/
    ├── campaign_countdown_strip.dart
    └── campaign_hero_banner_smart.dart
```

---

## 1. Geo-targeted notifications

**User preferences** (SharedPreferences `bpa_campaign_geo_prefs_v1`):

- City
- District
- Preferred service area

**Campaign geo rules** (admin `metadataJson.mobile.geoTargets`):

```json
{
  "mobile": {
    "geoTargets": {
      "cities": ["Dhaka"],
      "districts": ["Dhaka", "Gazipur"],
      "serviceAreas": ["Mirpur", "Uttara"]
    }
  }
}
```

**Behaviour:**

- Homepage campaigns filtered when user has configured prefs.
- Push notifications skipped when FCM payload includes `geoTargets` and user location does not match.
- Campaigns with **empty** geo targets remain visible to all users.
- Emergency broadcasts **bypass** geo filter.

---

## 2. Vaccination reminder engine

| Vaccine class | Offsets (days before due) |
|---------------|---------------------------|
| Cat Flu / Feline / PUREVAX | 7, 3, 0 (due today) |
| Rabies | 30, 7, 0 (due today) |

Classification uses `VaccinationRecord.vaccineType` string matching. Reminders schedule via existing `NotificationService.scheduleCampaignReminder`.

---

## 3. Campaign countdown (homepage)

Banner shows via `CampaignCountdownStrip`:

- **Days left** and **hours left** (from `bookingEndAt` when `countdownEnabled`)
- **Remaining slots** (from discovery/upcoming enrichment)

Data source: `GET /api/v1/campaign/public/campaigns/:slug/countdown`

---

## 4. Emergency broadcast

Supported FCM `type` values:

| Type | Notification channel |
|------|---------------------|
| `emergency_broadcast` | Emergency (max priority) |
| `disease_outbreak_alert` | Emergency |
| `urgent_vaccination_notice` | Announcement |
| `campaign_extension` | Campaign update / announcement |

Deep link: `campaign/detail/{slug}` when `campaignSlug` present.

---

## 5. Dynamic homepage placement

Priority from `metadataJson.mobile.priority`:

| Level | Sort order |
|-------|------------|
| HIGH | 0 (first) |
| MEDIUM | 1 |
| LOW | 2 |

HIGH campaigns show a **Featured** pill on the banner.

Pipeline: fetch public campaigns → geo filter → A/B assign → priority sort → render.

---

## 6. A/B testing

- Test key: `metadataJson.mobile.abTestKey`
- Variants: `metadataJson.mobile.abVariants` (default `["A","B"]`)
- Stable assignment per user seed (`userId` / phone / guest)
- Tracked in:
  - Firebase Analytics (`ab_test_key`, `ab_variant`)
  - `CampaignPerformanceTracker` per slug

**Metrics:**

- Banner CTR = clicks / views
- Booking rate = bookings / clicks
- Payment tracked on WebView success

---

## 7. Campaign performance dashboard

**Screen:** `CampaignPerformanceDashboardPage` (Hub → Performance)

Displays per slug:

| Metric | Source |
|--------|--------|
| Views | Banner impression (visibility ≥50%) |
| Clicks | Banner / CTA tap |
| Bookings | Checkout success |
| Revenue | Payment completion |
| Banner CTR | clicks / views |
| Booking rate | bookings / clicks |
| Conversion | bookings / views |

Metrics stored locally in SharedPreferences (`bpa_campaign_perf_v1_{slug}`). Server live stats available via `GET /discovery/live-stats` for future merge.

---

## 8. Reusable program types

`FurtailCampaignType` enum:

| Code | Label |
|------|-------|
| VACCINATION | Vaccination |
| DEWORMING | Deworming |
| STERILIZATION | Sterilization |
| HEALTH_CHECKUP | Health Checkup |
| ADOPTION | Adoption Drive |

Set via admin metadata: `metadataJson.mobile.campaignType`. Same engine powers homepage, geo, A/B, and analytics for all types; reminder offsets can be extended per type in future.

---

## Admin metadata contract (recommended)

```json
{
  "mobile": {
    "bannerImageUrl": "https://cdn.example/banner.jpg",
    "priority": "HIGH",
    "campaignType": "VACCINATION",
    "countdownEnabled": true,
    "abTestKey": "home_banner_v2",
    "abVariants": ["A", "B"],
    "geoTargets": {
      "cities": ["Dhaka"],
      "districts": ["Dhaka"],
      "serviceAreas": ["Mirpur"]
    }
  }
}
```

---

## API endpoints used (v2 additions)

| Endpoint | Use |
|----------|-----|
| `GET /campaign/public/campaigns/:slug/countdown` | Banner countdown |
| `GET /campaign/public/discovery/live-stats?slug=` | Optional server stats |
| Existing v1 endpoints | Unchanged |

---

## Tests

```bash
cd furtail_app
flutter test test/campaign/
```

New: `test/campaign/smart_campaign_engine_test.dart` — priority sort, geo filter, A/B stability, reminder offsets.

Total campaign tests: **24** (v1 + v2).

---

## Integration wiring (v2)

| Hook | Location |
|------|----------|
| Geo-filtered FCM | `NotificationController._handleIncomingFcm` → `CampaignNotificationService.handleFcmData` |
| Vaccination reminder sync | `CampaignHubScreen` watches `smartVaccinationReminderSyncProvider` |
| Smart home campaigns | `homeCampaignsProvider` → `SmartCampaignEngine.prepareHomeCampaigns` |

---

## Navigation updates

Campaign Hub new tiles:

- **Browse Campaigns** → `CampaignListPage`
- **Performance** → `CampaignPerformanceDashboardPage`
- **Area Prefs** → `CampaignGeoPreferencesPage`

---

## Known limitations & follow-ups

1. **Geo prefs UI** — free-text city/district/area; can link to BD location picker later.
2. **Server-side analytics** — dashboard is device-local; aggregate reporting needs backend ingest endpoint.
3. **A/B copy variants** — variant assignment only; separate banner copy per variant requires admin CMS fields.
4. **Emergency broadcast send** — client ready; admin must send FCM with documented payload types.
5. **Program-specific reminders** — Deworming/Sterilization schedules use vaccination engine until dedicated profiles added.

---

## Verification checklist

- [x] Geo prefs filter homepage campaigns
- [x] Geo prefs filter non-emergency push (when payload includes geoTargets)
- [x] Cat Flu + Rabies multi-offset reminders
- [x] Countdown days/hours + slots on banner
- [x] HIGH priority campaigns sort first
- [x] A/B variant stable + logged
- [x] Performance dashboard shows CTR/booking/conversion
- [x] Reusable `FurtailCampaignType` + `SmartCampaignConfig`
- [x] Emergency FCM types mapped to channels
- [x] Unit tests pass

---

*Smart Campaign Engine v2 complete. Configure campaigns via admin `metadataJson.mobile` and user area preferences in the app hub.*
