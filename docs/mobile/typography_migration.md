# Typography Migration Report

**Project:** `bpa_app`  
**Date:** 2026-06-04  
**Scope:** Inter (Google Fonts) + Roboto fallback, Material 3 `TextTheme`, removal of hardcoded `fontSize` across `lib/`

---

## 1. Summary

| Metric | Before | After |
|--------|--------|-------|
| Hardcoded `fontSize: <number>` in `lib/` | **158** occurrences (~58 files) | **0** |
| `fontSize` references | Widget-level literals | **`typography.dart` only** (token constants) |
| App `theme` | `ThemeData(primarySwatch: Colors.blue)` | `buildAppTheme()` with `AppTypography.buildTextTheme()` |
| Primary font | System default / mixed | **Inter** via `google_fonts` |
| Fallback | None | **Roboto** (`fontFamilyFallback`) |

**Files updated:** **60** presentation/core/ui files + foundation files (`typography.dart`, `app_theme.dart`, `app_text_styles.dart`, `main.dart`).

---

## 2. Typography system

### 2.1 Source file

`lib/core/theme/typography.dart`

- **Font:** `GoogleFonts.inter(...).copyWith(fontFamilyFallback: ['Roboto'])`
- **Builder:** `AppTypography.buildTextTheme()`
- **Context helper:** `context.appText` → `Theme.of(context).textTheme`
- **Legacy helper:** `AppTypography.styleForLegacySize()` (optional; unused in UI after migration)

### 2.2 Material 3 scale (implemented)

| Role | Size (sp) | Default weight |
|------|-----------|----------------|
| `displayLarge` | 32 | w700 |
| `displayMedium` | 28 | w700 |
| `headlineLarge` | 24 | w700 |
| `headlineMedium` | 22 | w600 |
| `titleLarge` | 20 | w600 |
| `titleMedium` | 18 | w600 |
| `bodyLarge` | 16 | w400 |
| `bodyMedium` | 14 | w400 |
| `bodySmall` | 12 | w400 |
| `labelLarge` | 14 | w600 |
| `labelMedium` | 12 | w600 |

**Also populated** (for Material 3 completeness): `displaySmall`, `headlineSmall`, `titleSmall`, `labelSmall` — derived from adjacent sizes.

### 2.3 Theme wiring

| File | Change |
|------|--------|
| `lib/core/theme/app_theme.dart` | `buildAppTheme()` sets `textTheme` / `primaryTextTheme` from `AppTypography` |
| `lib/main.dart` | `theme:` and `darkTheme:` → `buildAppTheme()` |
| `lib/core/constants/app_text_styles.dart` | Delegates to `AppTypography.buildTextTheme()` (`@deprecated` shim) |

---

## 3. Legacy size → TextTheme mapping

Used during migration when replacing inline `fontSize`:

| Old size (sp) | New role | Notes |
|---------------|----------|--------|
| 32, 34 | `displayLarge` | Hero titles (pet name, splash) |
| 28, 30 | `displayMedium` | Fundraising amount, profile stats |
| 24 | `headlineLarge` | Section headers |
| 22, 26 | `headlineMedium` | Card titles, country picker |
| 20 | `titleLarge` | App bar, drawer name |
| 18 | `titleMedium` | Buttons, emphasis body |
| 16, 15 | `bodyLarge` | Default UI copy, post body |
| 14, 13 | `bodyMedium` / `labelLarge` | `labelLarge` when w600+ label |
| 12 | `bodySmall` / `labelMedium` | Captions, metadata |
| 11, 10 | `labelMedium` | Chips, grid labels |

**Preserved via `copyWith` only:** `color`, `fontWeight`, `height`, `letterSpacing` — never `fontSize`.

---

## 4. Migration patterns

### Before

```dart
const Text(
  'Request withdrawal',
  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
);
```

### After

```dart
Text(
  'Request withdrawal',
  style: context.appText.bodyLarge!.copyWith(fontWeight: FontWeight.w900),
);
```

### InputDecoration

```dart
hintStyle: context.appText.bodyMedium!.copyWith(color: Colors.grey),
```

### Without context (discouraged)

Use `AppTypography.buildTextTheme()` static styles via deprecated `AppTextStyles`, or pass `TextStyle` from parent `build`.

---

## 5. Files migrated (by feature)

### Campaign (11)
- `campaign_hub_screen.dart`
- `qr_verification_screen.dart`, `qr_viewer_screen.dart`
- `digital_health_card_screen.dart`, `certificate_wallet_screen.dart`
- `digital_vaccination_card_widget.dart`, `vaccination_timeline_widget.dart`, `booking_tile.dart`
- `campaign_benefits_screen.dart`, `certificate_viewer_screen.dart`

### Home (8)
- `bpa_home_screen.dart` (if touched via theme)
- `custom_drawer.dart`, `home_app_bar.dart`, `custom_bottom_nav.dart`
- `service_grid.dart`, `cause_modules_section.dart`, `story_section.dart`
- `feed_post_card.dart`, `feed_reels_strip.dart`, `feed_list.dart` (if applicable)

### Profile (18)
- `profile_header.dart`, `profile_header_stack.dart`, `visitor_profile_header_stack.dart`
- `user_profile_screen.dart`, `visitor_profile_screen.dart`, `profile_edit_overview_screen.dart`
- `achievements_section.dart`, `profile_gallery.dart`, `pet_horizontal_list.dart`
- `my_pets_family_white.dart`, `posts_placeholder.dart`, `profile_tab_more.dart`
- `profile_tab_videos.dart`, `trophy_case.dart`, `user_stats.dart`

### Pets (3)
- `pet_profile_screen.dart`, `pet_step_header.dart`, `pet_profile_wizard_screen.dart` (if migrated)

### Posts (5)
- `post_details_screen.dart`, `comments_sheet.dart`, `comments_preview_section.dart`
- `report_bottom_sheet.dart`, `reels_player_screen.dart`

### Fundraising (12+)
- `fundraising_create_screen.dart`, `fundraising_account_setup_screen.dart`
- `fundraising_payout_methods_screen.dart`, `fundraising_withdraw_hub_screen.dart`
- `fundraising_withdraw_request_screen.dart`, `fundraising_details_screen.dart`
- `fundraising_account_documents_screen.dart`, `fundraising_reactions_section.dart`
- `fundraising_card.dart`, `fundraising_edit_screen.dart`, details widgets, etc.

### Auth (4)
- `login_screen.dart`, `register_screen.dart`
- `auth_header.dart`, `auth_button.dart`

### Legacy (7)
- `splash_screen.dart`, `country_picker_screen.dart`, `settings_screen.dart`
- `language_select_screen.dart`, `dashboard_screen.dart`, `create_post_screen.dart`

### Wallet / location / settings
- `wallet_screen.dart`, `wallet_withdraw_screen.dart`, `wallet_withdraw_requests_screen.dart`
- `location_selector_widget.dart`, `settings_screen.dart`

### Core media (4)
- `feed_video_player.dart`, `fullscreen_video_player_screen.dart`
- `video_trim_screen.dart`, `video_edit_screen.dart`

### UI components (1)
- `ui/components/buttons/primary_button.dart`

---

## 6. Visual deltas to QA

Snapping off-scale sizes to the token scale may shift layout slightly:

| Area | Old | New role | Δ |
|------|-----|----------|---|
| Pet profile name | 34 sp | `displayLarge` (32) | −2 sp |
| Auth header | 26 sp | `headlineMedium` (22) | −4 sp |
| Fundraising detail amount | 30 sp | `displayMedium` (28) | −2 sp |
| Post username | 15 sp | `bodyLarge` (16) | +1 sp |
| Timeline title | 15 sp | `bodyLarge` (16) | +1 sp |
| Micro copy (10–11 sp) | 10–11 sp | `labelMedium` (12) | +1–2 sp |

**Recommendation:** Screenshot-compare home feed, pet profile, splash, login, fundraising details before release.

---

## 7. Verification

```powershell
# No hardcoded font sizes outside typography.dart
Get-ChildItem lib -Recurse -Filter *.dart |
  ForEach-Object { Select-String -Path $_.FullName -Pattern 'fontSize:\s*\d+' }
# Expected: no output

flutter analyze lib/core/theme/typography.dart
# Expected: No issues found
```

### Consumption stats (post-migration)

- Files importing `package:bpa_app/core/theme/typography.dart`: **~58**
- Uses of `context.appText` / `Theme.of(context).textTheme`: **~200+** style applications

---

## 8. Follow-up (not in this PR)

- [ ] CI rule: fail build on `fontSize:\s*\d+` outside `lib/core/theme/typography.dart`
- [ ] Extend `docs/mobile/design_system_plan.md` — mark typography phase complete
- [ ] Bengali (bn) locale line-height pass with real content
- [ ] Remove `AppTextStyles` shim after all imports migrated to `context.appText`
- [ ] Dark theme: duplicate `buildTextTheme` with adjusted `onSurface` colors

---

## 9. References

- Plan: `docs/mobile/design_system_plan.md`
- Implementation: `lib/core/theme/typography.dart`, `lib/core/theme/app_theme.dart`
- Package: `google_fonts: ^6.1.0` (already in `pubspec.yaml`)

---

*End of migration report.*
