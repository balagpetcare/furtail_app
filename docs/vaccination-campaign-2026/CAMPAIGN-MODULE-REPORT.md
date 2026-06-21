# BPA App — Vaccination Campaign Module Report

**Project:** `D:\BPA_Data\bpa_app`  
**Design reference:** `backend-api/docs/vaccination-campaign-2026/16-bpa-app-linking.md`  
**Date:** June 2, 2026

---

## Summary

Implemented the **2026 Vaccination Campaign** module in the BPA Flutter app as a dedicated feature under `lib/features/campaign/`, separate from the existing **fundraising** “campaign” module.

The module reuses existing auth (`ApiClient` + Bearer token), pet profile data, navigation (drawer + service grid), and the standard API layer pattern (`ApiEndpoints` → repository → Riverpod providers).

Supporting **authenticated campaign-link APIs** were added in `backend-api` at `/api/v1/campaign-link/*` so the app can load bookings, vaccinations, certificates, and import flows without OTP session tokens.

---

## Features Delivered

| Feature | Screen / Entry | API |
|--------|----------------|-----|
| My Campaigns | `MyCampaignsScreen` | `GET /campaign-link/my-bookings` |
| Campaign History | `CampaignHistoryScreen` | Same bookings API (completed/cancelled filter) |
| Vaccination Records | `VaccinationRecordsScreen` | `GET /campaign-link/vaccinations` |
| Digital Vaccine Card | `VaccineCardScreen` | Vaccination records with certificate tokens |
| Certificate Viewer | `CertificateViewerScreen` | `GET /campaign-link/certificates/:token` |
| Certificate Download | Certificate viewer action | `GET /campaign-link/certificates/:token/pdf` + `share_plus` |
| QR Viewer | `QrViewerScreen` | Booking QR token / certificate QR image |
| Campaign Benefits | `CampaignBenefitsScreen` | `GET /campaign-link/benefits` |
| Upcoming Vaccinations | `UpcomingVaccinationsScreen` | `GET /campaign-link/upcoming` |
| Vaccination Reminders | `VaccinationRemindersScreen` | Local `SharedPreferences` + due dates from records |

**Hub:** `CampaignHubScreen` — central entry with import banner and feature grid.

---

## Module Structure

```
lib/features/campaign/
├── data/
│   ├── models/campaign_models.dart
│   ├── repositories/campaign_repository.dart
│   └── services/reminder_storage.dart
└── presentation/
    ├── providers/campaign_providers.dart
    ├── screens/
    │   ├── campaign_hub_screen.dart
    │   ├── my_campaigns_screen.dart
    │   ├── campaign_history_screen.dart
    │   ├── vaccination_records_screen.dart
    │   ├── vaccine_card_screen.dart
    │   ├── certificate_viewer_screen.dart
    │   ├── qr_viewer_screen.dart
    │   ├── campaign_benefits_screen.dart
    │   ├── upcoming_vaccinations_screen.dart
    │   └── vaccination_reminders_screen.dart
    └── widgets/
        ├── booking_tile.dart
        └── vaccination_record_tile.dart
```

---

## Navigation Wiring

- **Routes:** `AppRoutes.campaignHub`, `AppRoutes.campaignCertificate`
- **Drawer:** “Vaccination Campaign” under Services (login required)
- **Home service grid:** “Vaccination” tile → `CampaignHubScreen`

---

## Linking Flow (per design doc)

1. User opens Campaign hub → summary checks for unlinked phone bookings.
2. **Import Records** calls `POST /campaign-link/import` to link bookings/pets/vaccinations.
3. Certificate deep link route: `/campaign/certificate` with `{ token }` argument.
4. Claim endpoint available: `POST /campaign-link/certificate/:token/claim`.

Phone is the primary link key; bookings match by `ownerUserId` or `ownerPhone`.

---

## Backend Additions (required for app)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/campaign-link/summary` | Link status + counts |
| GET | `/campaign-link/my-bookings` | User bookings |
| GET | `/campaign-link/vaccinations` | Vaccination history |
| GET | `/campaign-link/upcoming` | Future appointments |
| GET | `/campaign-link/benefits` | Campaign info + benefits |
| POST | `/campaign-link/import` | Import unlinked records |
| POST | `/campaign-link/pet/:id` | Link campaign pet to BPA pet |
| POST | `/campaign-link/certificate/:token/claim` | Claim certificate |
| GET | `/campaign-link/certificates/:token` | Certificate data (auth) |
| GET | `/campaign-link/certificates/:token/pdf` | PDF download |

Public endpoints still used for verification: `/campaign/public/verify/:token`.

---

## Reminders

Client-side reminder preferences stored in `SharedPreferences` (`campaign_vaccination_reminders`). Initial reminders are seeded from vaccination `nextDueDate` values. Push notifications are out of scope; toggles control in-app reminder state for future notification integration.

---

## Dependencies Used

Existing: `flutter_riverpod`, `http`, `shared_preferences`, `intl`, `path_provider`, `share_plus`.

No new pub packages added (QR rendered from server base64 image or placeholder icon).

---

## Testing

Run from `bpa_app`:

```bash
flutter analyze
```

Ensure backend is running with campaign-link routes mounted and user has a phone number on their account for import/linking.

---

## Notes

- **Fundraising vs vaccination:** Fundraising remains at `lib/features/fundraising/`. Vaccination campaign uses `lib/features/campaign/` only.
- **OTP booking flow:** Public campaign booking still uses OTP session APIs; the BPA app module uses BPA JWT via campaign-link.
- **PDF download:** Depends on server Puppeteer; falls back with user message if unavailable.
