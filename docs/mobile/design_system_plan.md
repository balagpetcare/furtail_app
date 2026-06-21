# Furtail — Design System Standardization Plan

**Project:** `furtail_app` (Flutter)  
**Scope:** Full `lib/` audit (237 Dart files, 132 presentation-layer files, 66 `*screen*.dart` routes/widgets)  
**Status:** Planning only — **no code changes applied**  
**Date:** 2026-06-04

---

## 1. Executive summary

The Furtail mobile app has **partial** design primitives (`lib/core/constants/app_colors.dart`, `app_text_styles.dart`, `lib/core/theme/app_theme.dart`) but they are **largely unused**. `main.dart` applies a generic `ThemeData(primarySwatch: Colors.blue)` and does **not** wire `appTheme`. UI code relies on **inline** `Color(0x…)`, `Colors.*`, `fontSize`, `EdgeInsets`, `BorderRadius`, and icon `size` values spread across **~100+ files**.

This plan defines centralized tokens under `lib/core/theme/`, maps today’s de-facto brand values to semantic roles, and provides a **phased migration** so screens can be updated incrementally without visual regressions.

### Audit totals (automated scan)

| Pattern | Occurrences | Files affected (approx.) |
|--------|-------------|---------------------------|
| `Color(0x…)` hex literals | **212** | ~55 |
| `Colors.*` (Material palette) | **603** | ~100 |
| `fontSize:` inline | **158** | ~60 |
| `BorderRadius.circular` | **210** | ~90 |
| `EdgeInsets.*` | **383** | ~100 |
| `Icon` / widget `size:` numeric | **264** | ~55 |
| `SizedBox(height/width:)` numeric | **591** | ~90 |

**Adoption of existing tokens:** `AppColors` / `AppTextStyles` appear in only **9 files** (mostly fundraising detail widgets + theme definition). The live brand color in UI is **`#1E60AA`**, while `AppColors.primary` is still **`#4A90E2`** — a consistency bug to resolve in Phase 0.

---

## 2. Current state

### 2.1 Existing design-related files

| Path | Role | Issue |
|------|------|--------|
| `lib/core/constants/app_colors.dart` | 9 color constants | Wrong primary; missing semantic set; not used app-wide |
| `lib/core/constants/app_text_styles.dart` | 7 named styles (`headline1`, `bodyLarge`, …) | Naming ≠ Material 3 scale requested; 7 styles only |
| `lib/core/theme/app_theme.dart` | `ThemeData` stub | Incomplete; **not referenced** from `main.dart` |
| `lib/core/theme/theme_controller.dart` | Light/dark preference | Theme mode forced to `ThemeMode.light` in `main.dart` |
| `lib/ui/components/*` | Shared buttons, fields, `AppText` | Still hardcode `#1E60AA`, radius `14`, `fontSize: 16` |
| `lib/main.dart` | App entry | `ThemeData(primarySwatch: Colors.blue, useMaterial3: true)` |

### 2.2 De-facto brand palette (from code frequency)

These colors appear most often and should become **semantic tokens**, not one-off hex in widgets.

| Hex | Usage | Proposed token |
|-----|--------|----------------|
| `#1E60AA` | App bars, CTAs, links, campaign, nav selected | `AppColors.primary` |
| `#FFD700` / `#FFC107` | Gold accents, trophies, drawer | `AppColors.secondary` (accent gold) |
| `#4A90E2` | Legacy `AppColors.primary` only | Deprecate → alias to `info` or remove |
| `#F5F5F5` / `#F6F7FB` / `#F6F8FB` | Scaffold / section backgrounds | `AppColors.background` / `surface` variants |
| `#EFEFEF` / `#F2F2F2` | Avatar placeholders, media empty | `AppColors.surfaceVariant` |
| `#E6E6E6` / `#EAEAEA` / `#EEEEEE` | Borders, dividers | `AppColors.outline` |
| `#1A1A1A` / `#666666` / `#999999` | Text (already in constants) | `onSurface` / `onSurfaceVariant` |
| `#4CAF50` / `#1EAD5A` | Success states | `AppColors.success` |
| `#FFB4B4` / `#B91C1C` | Error / rejected wallet status | `AppColors.error` |
| `#FFD18A` / `#B45309` | Warning / pending | `AppColors.warning` |
| `#2D7FF9` / `#1D4ED8` / `#EAF2FF` | Info / links (pet profile, wallet) | `AppColors.info` |
| `#0B1220` | Dark overlays (gallery, profile header) | `AppColors.scrim` |
| Campaign gradient set | `#0B5C5C`, `#2E86C1`, `#C8A951` | `AppColors.campaign*` extensions |

### 2.3 Typography drift

Inline `fontSize` values found (non-exhaustive): **10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 26, 28, 30, 34** — many map to the requested scale with snapping rules (see §4.4).

`Theme.of(context).textTheme` is used in **~30 files** only; most text uses raw `TextStyle`.

### 2.4 Border radius drift

`BorderRadius.circular` values in codebase: **8, 10, 12, 14, 16, 18, 20, 24, 26, 28, 30, 99, 999** (+ `OutlineInputBorder` duplicates).

**Standard scale (requested):** 4, 8, 12, 16, 20, 24.

| Current | Migrate to |
|---------|------------|
| 4 | `AppRadius.xs` |
| 8 | `AppRadius.sm` |
| 10 | `AppRadius.sm` (8) or `AppRadius.md` (12) — pick per component class |
| 12 | `AppRadius.md` |
| 14 | `AppRadius.md` (12) or `AppRadius.lg` (16) — **document: cards/buttons → lg** |
| 16 | `AppRadius.lg` |
| 18, 20 | `AppRadius.xl` (20) or `AppRadius.xxl` (24) |
| 24–30 | `AppRadius.xxl` (24); search field `30` → `xxl` or custom `AppRadius.search` |
| 99, 999 | `AppRadius.pill` → implement as `BorderRadius.circular(999)` **alias** documented as full pill (not in 4–24 scale) |

### 2.5 Spacing drift

`EdgeInsets` and `SizedBox` use many values: **2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 32, 40, 48** and occasional **56, 72**. Standard scale: **4, 8, 12, 16, 20, 24, 32, 40, 48**.

| Off-scale | Snap to |
|-----------|---------|
| 6, 10, 14, 18 | nearest token (document per component) |
| 56, 72 | `AppSpacing.xxxl` (48) + layout exception doc, or add `56` only if repeated ≥5× |

### 2.6 Icon size drift

Common sizes: **14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 40, 42, 44, 48, 52, 56, 64, 72, 120**.

Recommend **`lib/core/theme/icon_sizes.dart`** (optional 6th file) or a section in `spacing.dart`:

| Token | dp | Typical use |
|-------|-----|-------------|
| `xs` | 14 | Drawer rows, metadata |
| `sm` | 16 | Inline actions, comment like |
| `md` | 20 | Toolbar, list trailing |
| `lg` | 24 | App bar, profile chips |
| `xl` | 32 | Empty states |
| `xxl` | 48 | Placeholders |
| `hero` | 72+ | QR / pet avatar hero (screen-specific, minimize) |

---

## 3. Target architecture

```
lib/core/theme/
├── colors.dart       # AppColors semantic palette + extensions
├── spacing.dart      # AppSpacing + EdgeInsets helpers
├── radius.dart       # AppRadius + BorderRadius helpers
├── typography.dart   # AppTypography → TextTheme
├── app_theme.dart    # ThemeData light (+ dark stub)
└── (optional) icon_sizes.dart
```

**Deprecation path (after migration):**

- `lib/core/constants/app_colors.dart` → export from `colors.dart` or delete after call sites updated  
- `lib/core/constants/app_text_styles.dart` → replace with `typography.dart`  
- Update `docs/PROJECT_STRUCTURE.md` constants bullet to point at `core/theme/`

**Consumption rules:**

1. **No new** `Color(0x…)` in feature code — use `AppColors` or `Theme.of(context).colorScheme`.  
2. **Prefer** `Theme.of(context).textTheme.titleMedium` over raw `fontSize`.  
3. **Padding/margin** → `AppSpacing.md` or `AppSpacing.insetHorizontalMd`.  
4. **Shared components** (`lib/ui/components/`) migrate in Phase 1 so features inherit tokens automatically.

---

## 4. Token specifications (to implement)

### 4.1 `colors.dart`

```dart
/// Semantic colors — light theme baseline.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFF1E60AA);      // was donateBlue in constants
  static const Color secondary = Color(0xFFFFD700);   // accent gold

  // Feedback
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFD18A);     // borders; pair with onWarning text
  static const Color error = Color(0xFFB91C1C);
  static const Color info = Color(0xFF2D7FF9);

  // Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F5);
  static const Color surfaceMuted = Color(0xFFF6F8FB); // wallet/campaign sections

  // Text on surfaces (or map via ColorScheme.onSurface in app_theme)
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color onSurfaceVariant = Color(0xFF666666);
  static const Color outline = Color(0xFFE6E6E6);

  // Feature-specific (optional extensions)
  static const Color campaignTeal = Color(0xFF0B5C5C);
  static const Color scrim = Color(0xFF0B1220);
}
```

**`ColorScheme` mapping in `app_theme.dart`:** wire `primary`, `secondary`, `surface`, `error`, etc., so Material widgets (`ElevatedButton`, `InputDecoration`) pick up tokens without per-widget overrides.

**Resolve primary conflict:** Replace `AppColors.primary = 0xFF4A90E2` with `#1E60AA`; keep old blue only if product confirms secondary/info role.

### 4.2 `spacing.dart`

```dart
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;

  // Helpers
  static EdgeInsets get screenPadding =>
      const EdgeInsets.symmetric(horizontal: md, vertical: md);
  static SizedBox vertical(double v) => SizedBox(height: v);
}
```

### 4.3 `radius.dart`

```dart
abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 999; // documented exception for chips/pills

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get card => BorderRadius.circular(lg); // replaces 14
  static BorderRadius get button => BorderRadius.circular(lg);
}
```

### 4.4 `typography.dart`

Map to Material 3 names (user-requested). Base font family: **Roboto** (Flutter default) unless product adds custom font later.

| Token | Size | Weight | Line height | Notes |
|-------|------|--------|-------------|-------|
| `displayLarge` | 32 | w700 | 1.2 | Was `headline1` / splash titles |
| `displayMedium` | 28 | w700 | 1.2 | Profile hero numbers |
| `headlineLarge` | 24 | w700 | 1.25 | Section heroes |
| `headlineMedium` | 20 | w700 | 1.3 | App bar titles, drawer name |
| `titleLarge` | 18 | w800 | 1.3 | Card titles |
| `titleMedium` | 16 | w700 | 1.35 | Buttons, list titles |
| `bodyLarge` | 16 | w400 | 1.5 | Post body |
| `bodyMedium` | 14 | w400 | 1.45 | Default body |
| `bodySmall` | 12 | w400 | 1.4 | Captions, metadata |
| `labelLarge` | 14 | w600 | 1.2 | Chips, tabs |
| `labelMedium` | 12 | w600 | 1.2 | Bottom nav, badges |

**Snap rule for migration:** inline sizes round to nearest row (e.g. 13→`bodyMedium` 14, 15→`bodyLarge` 16, 11→`bodySmall` 12).

```dart
abstract final class AppTypography {
  static TextTheme textTheme = const TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.onSurface),
    // ... remaining styles
  );
}
```

### 4.5 `app_theme.dart`

```dart
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
      // ...
    ),
    scaffoldBackgroundColor: AppColors.background,
    textTheme: AppTypography.textTheme,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
        minimumSize: const Size.fromHeight(52),
      ),
    ),
    // inputDecorationTheme, dividerTheme, appBarTheme, chipTheme...
  );
}
```

**`main.dart` change (Phase 0):** `theme: buildAppTheme()`, keep `themeMode: ThemeMode.light` until dark palette is defined.

---

## 5. Screen & widget inventory

### 5.1 Screens by feature (66 screen files)

| Feature | Screens | Widgets (high-traffic) | Hardcoding severity |
|---------|---------|-------------------------|---------------------|
| **home** | `bpa_home_screen` | `custom_drawer`, `feed_post_card`, `feed_reels_strip`, `home_app_bar`, `cause_modules_section`, `service_grid`, `feed_list`, `story_section`, `custom_bottom_nav` | **Critical** |
| **profile** | 8 screens + `profile_media_upload_screen` | `profile_header`, `profile_header_stack`, `pet_horizontal_list`, `achievements_section`, 10+ tab widgets | **Critical** |
| **posts** | `post_details_screen`, `reels_player_screen` | `comments_sheet`, `comments_preview_section`, `report_bottom_sheet` | **High** |
| **fundraising** | 12+ screens | `fundraising_card`, `details/*`, `fundraising_create_screen` | **High** |
| **campaign** | 14 screens | `digital_vaccination_card_widget`, `vaccination_timeline_widget` | **High** |
| **pets** | 6 screens + wizard | `pet_profile_screen` (largest single file) | **Critical** |
| **wallet** | 3 screens | Status chips with many hex colors | **Medium** |
| **auth** | `login_screen`, `register_screen` | `auth_header`, `auth_text_field`, `auth_button` | **Medium** |
| **legacy** | 14 screens | `create_post_screen`, `edit_post_screen`, `splash_screen` | **High** |
| **settings/location** | 3 screens | `location_selector_widget` | **Low** |
| **core/media** | 5 screens | `feed_video_player`, fullscreen players | **Medium** (often `Colors.white` on video — acceptable) |

### 5.2 Top 20 files to migrate first (by design-debt density)

| Priority | File | Hex | Colors.* | fontSize | Radius | Notes |
|----------|------|-----|----------|----------|--------|-------|
| P0 | `lib/main.dart` | — | 2 | — | — | Wire `buildAppTheme()` |
| P0 | `lib/ui/components/buttons/primary_button.dart` | 1 | 1 | 1 | 1 | Shared CTA |
| P1 | `lib/features/home/presentation/widgets/feed/feed_post_card.dart` | 11 | 27 | 12 | 7 | Feed core |
| P1 | `lib/features/home/presentation/screens/widgets/custom_drawer.dart` | 7 | 26 | 10 | 7 | Global nav |
| P1 | `lib/features/pets/presentation/screens/pet_profile_screen.dart` | 11 | 29 | 9 | 13 | Largest screen |
| P1 | `lib/features/profile/presentation/widgets/profile_header.dart` | 8 | 12 | 3 | 3 | Brand profile |
| P2 | `lib/features/posts/presentation/screens/post_details_screen.dart` | 4 | 13 | 5 | 4 | |
| P2 | `lib/features/fundraising/presentation/screens/fundraising_create_screen.dart` | 0 | 16 | 2 | 6 | |
| P2 | `lib/features/wallet/presentation/screens/wallet_withdraw_requests_screen.dart` | 12 | 1 | 0 | 3 | Status colors → semantic |
| P2 | `lib/features/campaign/presentation/screens/campaign_hub_screen.dart` | 2 | 13 | 1 | 2 | |
| P2 | `lib/features/auth/presentation/screens/login_screen.dart` | 4 | 13 | 2 | 2 | |
| P3 | `lib/features/legacy/presentation/screens/create_post_screen.dart` | 0 | 18 | 3 | 6 | |
| P3 | `lib/features/legacy/presentation/screens/edit_post_screen.dart` | 0 | 17 | — | 6 | |
| P3 | `lib/features/posts/presentation/screens/reels_player_screen.dart` | 0 | 21 | 3 | 2 | Video overlay exceptions |
| P3 | `lib/features/home/presentation/screens/furtail_home_screen.dart` | 5 | 6 | — | 1 | |
| P3 | `lib/features/profile/presentation/screens/visitor_profile_screen.dart` | 3 | 8 | 5 | 4 | |
| P3 | `lib/features/fundraising/presentation/screens/fundraising_withdraw_hub_screen.dart` | 10 | 9 | 2 | 6 | |
| P4 | Remaining ~80 presentation files | — | — | — | — | Batch by feature PR |

---

## 6. Migration plan

### Phase 0 — Foundation (1 PR, no UI visual change if mapped correctly)

**Goal:** Tokens exist; app uses `buildAppTheme()`.

| Step | Action |
|------|--------|
| 0.1 | Add `colors.dart`, `spacing.dart`, `radius.dart`, `typography.dart`, expand `app_theme.dart` |
| 0.2 | Point `main.dart` `theme:` to `buildAppTheme()` |
| 0.3 | Add `icon_sizes.dart` (recommended) |
| 0.4 | Make `app_colors.dart` / `app_text_styles.dart` **export** new tokens with `@Deprecated` aliases for one release |
| 0.5 | Update `lib/ui/components/**` to use tokens only |
| 0.6 | Manual QA: splash → home → login → profile → feed card → fundraising donate |

**Acceptance:** `grep Color(0x lib/ui` → 0; `main.dart` has no `Colors.blue` swatch.

### Phase 1 — Shared shell & feed (2–3 PRs)

| PR | Files |
|----|-------|
| 1A | `custom_drawer`, `home_app_bar`, `custom_bottom_nav`, `bpa_home_screen`, `service_grid` |
| 1B | `feed_post_card`, `feed_reels_strip`, `feed_list`, `cause_modules_section`, `story_section` |
| 1C | `primary_button`, `app_primary_button`, `social_button`, `app_text_field`, `app_snackbar` |

**Replace patterns:**

- `const Color(0xFF1E60AA)` → `AppColors.primary` or `Theme.of(context).colorScheme.primary`
- `Colors.black54` → `AppColors.onSurfaceVariant` or `colorScheme.onSurfaceVariant`
- `fontSize: 16, fontWeight: FontWeight.w900` → `textTheme.titleMedium.copyWith(fontWeight: FontWeight.w900)`
- `BorderRadius.circular(14)` on cards/buttons → `AppRadius.card` / `AppRadius.button`

### Phase 2 — Profile & pets (2 PRs)

| PR | Files |
|----|-------|
| 2A | `profile_header`, `profile_header_stack`, `visitor_profile_header_stack`, `user_profile_screen`, `visitor_profile_screen`, tab widgets |
| 2B | `pet_profile_screen`, pet wizard/edit widgets |

**Note:** Pet profile uses a **secondary palette** (orange `#F0852B`, blue `#2D7FF9`) — map to `AppColors.info` + new `AppColors.accentOrange` extension if product wants to keep distinction.

### Phase 3 — Posts, fundraising, campaign (3–4 PRs)

| PR | Feature bundle |
|----|----------------|
| 3A | `post_details_screen`, comments widgets, `report_bottom_sheet` |
| 3B | Fundraising screens + `fundraising_card` + details widgets (already partial `AppColors`) |
| 3C | Campaign/vaccination screens + `digital_vaccination_card_widget` |
| 3D | Wallet screens (status badge helper → `AppStatusColors` using success/warning/error/info) |

### Phase 4 — Legacy & media cleanup (2 PRs)

| PR | Files |
|----|-------|
| 4A | `legacy/*` create/edit post, splash, country picker, dashboard |
| 4B | `core/media/*` — allow `Colors.white` / `Colors.black` on video overlays; tokenize chrome only |

### Phase 5 — Enforcement & cleanup

| Step | Action |
|------|--------|
| 5.1 | Remove deprecated `lib/core/constants/app_colors.dart` & `app_text_styles.dart` |
| 5.2 | Add `custom_lint` or CI script: fail on `Color(0x` in `lib/features` (allowlist `lib/core/theme`) |
| 5.3 | Document component recipes in `docs/mobile/design_system_components.md` (follow-up) |

---

## 7. Per-screen migration checklist (template)

For each screen file, apply in order:

- [ ] Replace `backgroundColor` / `color` hex with `AppColors` or `colorScheme`
- [ ] Replace `Colors.grey.shade*` with `onSurfaceVariant` or `outline`
- [ ] Replace padding/margin with `AppSpacing.*`
- [ ] Replace `BorderRadius.circular(n)` with `AppRadius.*`
- [ ] Replace `TextStyle(fontSize: n)` with `Theme.of(context).textTheme.*`
- [ ] Replace icon `size: n` with `AppIconSize.*`
- [ ] Remove duplicate local `static const _primary` constants
- [ ] Visual compare screenshot (before/after)

---

## 8. Feature-level screen list (migration tracking)

Use this table in PR descriptions (`[ ]` → `[x]` when done).

### Auth
- [ ] `login_screen.dart`
- [ ] `register_screen.dart`

### Home
- [ ] `furtail_home_screen.dart`
- [ ] `custom_drawer.dart`, `home_app_bar.dart`, `custom_bottom_nav.dart`
- [ ] `feed_post_card.dart`, `feed_reels_strip.dart`, `feed_list.dart`
- [ ] `service_grid.dart`, `cause_modules_section.dart`, `story_section.dart`

### Profile
- [ ] `profile_screen.dart`, `user_profile_screen.dart`, `visitor_profile_screen.dart`
- [ ] `edit_profile_screen.dart`, `profile_edit_overview_screen.dart`, `edit_about_details_screen.dart`
- [ ] All `profile_*` widgets (20 files)

### Pets
- [ ] `pet_profile_screen.dart`, `pet_profile_wizard_screen.dart`, `pet_list_screen.dart`, `pet_create_screen.dart`
- [ ] `pet_edit_*` screens + pet widgets

### Posts
- [ ] `post_details_screen.dart`, `reels_player_screen.dart`
- [ ] `comments_sheet.dart`, `comments_preview_section.dart`, `report_bottom_sheet.dart`

### Fundraising
- [ ] All `fundraising_*` screens (12+)
- [ ] `fundraising_card.dart`, `details/*`, legacy `fundraising_details_page.dart`

### Campaign
- [ ] All `campaign/presentation/screens/*` (14)
- [ ] `digital_vaccination_card_widget.dart`, `vaccination_timeline_widget.dart`, `booking_tile.dart`

### Wallet
- [ ] `wallet_screen.dart`, `wallet_withdraw_screen.dart`, `wallet_withdraw_requests_screen.dart`

### Legacy
- [ ] `splash_screen.dart`, `settings_screen.dart`, `language_select_screen.dart`, `country_picker_screen.dart`
- [ ] `create_post_screen.dart`, `edit_post_screen.dart`, `dashboard_screen.dart`, shop/vet/services/donation/adoption

### Settings / location
- [ ] `settings_screen.dart` (feature), `location_picker_screen.dart`

### Core media
- [ ] `feed_video_player.dart`, `fullscreen_*`, `video_edit_screen.dart`, `video_trim_screen.dart`

---

## 9. Risk & decisions

| Topic | Recommendation |
|-------|----------------|
| Primary color | Standardize on **`#1E60AA`** everywhere; update old `#4A90E2` constant |
| Pill radius 999 | Keep as named `AppRadius.pill`; not part of 4–24 grid |
| `service_grid` semantic colors | Replace `Colors.blue/red/orange` with role-based service icon colors in `colors.dart` |
| Dark theme | Defer; define `ColorScheme.dark` in `app_theme.dart` when `ThemeController` re-enabled |
| Visual regression | Screenshot tests for home feed, profile, pet profile, campaign card |
| Bengali / EN typography | Same scale; verify line heights for Bengali glyphs in QA |

---

## 10. Success metrics

| Metric | Baseline | Target after Phase 5 |
|--------|----------|----------------------|
| `Color(0x` in `lib/features` | 212 | 0 |
| `AppColors` adoption files | 9 | 100+ via theme |
| Inline `fontSize:` in features | 158 | < 20 (exceptions documented) |
| `main.dart` uses design theme | No | Yes |
| Shared buttons use tokens | Partial | 100% |

---

## 11. References

- Existing structure doc: `docs/PROJECT_STRUCTURE.md` (§ Core constants — update after implementation)
- Current constants: `lib/core/constants/app_colors.dart`, `app_text_styles.dart`
- Entry point: `lib/main.dart` (lines 50–52 — theme not connected)
- Material 3 typography: [Flutter TextTheme](https://api.flutter.dev/flutter/material/TextTheme-class.html)

---

## Appendix A — Proposed `app_theme.dart` integration snippet

```dart
// main.dart — after Phase 0
import 'core/theme/app_theme.dart';

MaterialApp(
  theme: buildAppTheme(),
  darkTheme: buildAppDarkTheme(), // optional stub
  themeMode: ThemeMode.light,
  // ...
);
```

## Appendix B — Example widget migration (before / after)

**Before** (`primary_button.dart`):

```dart
backgroundColor: const Color(0xFF1E60AA),
borderRadius: BorderRadius.circular(14),
style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
```

**After:**

```dart
style: ElevatedButton.styleFrom(
  backgroundColor: AppColors.primary,
  shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
  textStyle: AppTypography.textTheme.titleMedium,
),
```

---

*End of plan — implementation PRs should reference this document and tick §8 checkboxes.*
