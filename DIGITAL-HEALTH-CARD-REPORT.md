# Digital Health Card — Furtail Campaign Integration

**Project:** `D:\BPA_Data\furtail_app`  
**Date:** 2026-06-02  
**API:** `backend-api` → `/api/v1/campaign-link/*`

---

## Summary

Campaign integration in the Flutter app is extended with a **pet-centric digital health experience** that reuses the existing **Pet Profile** (`PetProfileScreen`, `PetService`, `PetProfileModel`) and **campaign-link** APIs. Owners can view vaccination cards per pet, manage a certificate wallet, browse a unified timeline, track reminders, share certificates, and verify QR tokens.

---

## Feature matrix

| Requirement | Screen / component | Entry points |
|-------------|-------------------|--------------|
| **Digital Vaccination Card** | `DigitalHealthCardScreen` + `DigitalVaccinationCardWidget` | Pet profile → “Digital Health Card”; Campaign hub |
| **Certificate Wallet** | `CertificateWalletScreen` | Campaign hub; Health card quick action |
| **Vaccination Timeline** | `VaccinationTimelineScreen` + `VaccinationTimelineWidget` | Campaign hub; Health card quick action |
| **Campaign History** | `CampaignHistoryScreen` (existing) | Campaign hub |
| **Upcoming Reminders** | `UpcomingVaccinationsScreen` + `VaccinationRemindersScreen` | Campaign hub |
| **Certificate Sharing** | `CertificateShareService` + viewer share actions | Certificate viewer app bar |
| **QR Verification View** | `QrVerificationScreen` | Campaign hub; Wallet app bar; Health card |

---

## Pet profile reuse

| Existing asset | How it is reused |
|----------------|------------------|
| `PetProfileScreen` | “Digital Health Card” opens `DigitalHealthCardScreen(petId: …)` |
| `PetService.getPetProfile()` | Loads photo, breed, `healthStatus.vaccinated`, `nextDueDate` on health card |
| `GetPetsUsecase` | Pet picker when opening health card without `petId` |
| `PetProfileModel` | Summary chips (vaccinated / next due) above vaccination cards |

Campaign vaccinations are matched to pets via:

1. `VaccinationRecord.petId` (after `campaign-link/import` or `linkPet`)
2. Fallback: `petName` case-insensitive match when `petId` is null

Provider: `petVaccinationRecordsProvider(PetHealthFilter)`.

---

## Architecture

```
lib/features/campaign/
├── data/
│   ├── models/campaign_models.dart
│   ├── repositories/campaign_repository.dart
│   └── services/
│       ├── certificate_share_service.dart   ← NEW
│       └── reminder_storage.dart
├── presentation/
│   ├── providers/campaign_providers.dart      ← PetHealthFilter, share service
│   ├── utils/campaign_health_utils.dart       ← NEW timeline + filters
│   ├── widgets/
│   │   ├── digital_vaccination_card_widget.dart  ← NEW
│   │   └── vaccination_timeline_widget.dart     ← NEW
│   └── screens/
│       ├── digital_health_card_screen.dart      ← NEW
│       ├── certificate_wallet_screen.dart       ← NEW
│       ├── vaccination_timeline_screen.dart       ← NEW
│       ├── qr_verification_screen.dart          ← NEW
│       ├── campaign_hub_screen.dart             ← reorganized
│       ├── certificate_viewer_screen.dart       ← share actions
│       └── vaccine_card_screen.dart               ← alias → wallet
```

---

## User flows

### 1. Digital Health Card (per pet)

1. User opens **Pet Profile** → **Digital Health Card**.
2. App loads `PetProfileModel` + filtered `VaccinationRecord` list.
3. UI shows profile summary, quick actions (Wallet, Timeline, Reminders, Verify), and gradient **digital cards** per certificate.
4. Tap card → `CertificateViewerScreen`.

From hub without `petId`: pet picker lists `GetPetsUsecase` results.

### 2. Certificate Wallet

- Lists all records with `certificateToken`.
- Tap → full certificate; toolbar → QR verification.

### 3. Vaccination Timeline

- Merges `campaign-link/vaccinations` + `my-bookings` into chronological events (booking, check-in, completed, vaccination).
- Optional filter by `petId` / `petName` from health card.

### 4. Campaign History / Upcoming / Reminders

- **History:** past bookings (`isHistory`).
- **Upcoming:** `campaign-link/upcoming`.
- **Reminders:** local storage + `nextDueDate` from records (`VaccinationRemindersNotifier`).

### 5. Certificate sharing

- **Share link:** text summary via `share_plus`.
- **Share PDF:** `fetchCertificatePdf` → temp file → `Share.shareXFiles`.

### 6. QR verification

- User enters/pastes token → `GET /campaign/public/certificates/:token/verify` (no auth).
- Shows valid/invalid + optional navigation to full certificate / QR display.

---

## API dependencies

| Endpoint | Used by |
|----------|---------|
| `GET /campaign-link/summary` | Hub import banner |
| `POST /campaign-link/import` | Import banner |
| `GET /campaign-link/my-bookings` | Timeline, history, campaigns |
| `GET /campaign-link/vaccinations` | Records, wallet, health card |
| `GET /campaign-link/upcoming` | Upcoming screen |
| `GET /campaign-link/certificates/:token` | Certificate viewer |
| `GET /campaign-link/certificates/:token/pdf` | PDF share |
| `GET /campaign/public/certificates/:token/verify` | QR verification |

---

## Campaign hub layout (2026)

**Digital health** (top):

- Digital Health Card  
- Certificate Wallet  
- Vaccination Timeline  
- QR Verification  

**Campaign & reminders**:

- My Campaigns · Campaign History · Upcoming · Reminders · Records · Benefits  

---

## Testing checklist

- [ ] Pet profile → Digital Health Card shows correct pet and cards after import.
- [ ] Wallet lists all certificates; empty state copy is clear.
- [ ] Timeline shows bookings + vaccinations; pet filter works.
- [ ] Reminders toggle persists (SharedPreferences).
- [ ] Share link and PDF from certificate viewer.
- [ ] QR verify valid + invalid tokens.
- [ ] Import banner still links records and refreshes providers.

---

## Known limitations / follow-ups

| Item | Notes |
|------|-------|
| QR camera scan | Manual token entry only; add `mobile_scanner` for live scan (BUG-305 area). |
| Push notifications | Reminders are local toggles; no FCM (BUG-112). |
| Pet–booking link | Timeline filters bookings by pet **name** until API exposes `permanentPetId` on booking pets. |
| Deep link `furtail://certificate/{token}` | Not wired; use `QrVerificationScreen(initialToken: …)` when added. |

---

## Verification

```bash
cd D:\BPA_Data\furtail_app
flutter analyze lib/features/campaign
flutter run
```

Navigate: **Home → Vaccination →** exercise hub tiles; **Pets → profile → Digital Health Card**.

---

## Related docs

- `docs/vaccination-campaign-2026/CAMPAIGN-MODULE-REPORT.md`
- `backend-api/docs/vaccination-campaign-2026/16-furtail-app-linking.md`
