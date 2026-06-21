# BPA Flutter — Mobile UI Standardization Report

**Date:** 2026-06-05  
**Scope:** Application-wide typography, forced light theme, back navigation, drawer, responsive home shell

---

## Executive summary

| Phase | Status |
|-------|--------|
| 1 — Typography | ✅ Central `app_typography.dart` + drawer scale |
| 2 — Force light mode | ✅ `ThemeMode.light` only; dark/system disabled |
| 3 — Brightness | ✅ Device brightness unchanged (OS-level only) |
| 4 — Back button | ✅ `HomeBackHandler` on home root |
| 5 — Drawer | ✅ 82.5% width, Wrap chips, typography |
| 6 — Quality audit | ✅ This document |

---

## Phase 1 — Typography standardization

### New source of truth

**File:** `lib/core/theme/app_typography.dart`

| Token | Size (sp) | Use |
|-------|-----------|-----|
| Display Large | 28 | Hero / display |
| Display Medium | 24 | Large headings |
| Page Title | 22 | App bar, drawer name |
| Section Title | 18 | Section headers |
| Menu Title | 16 | List tiles, cards |
| Card Title | 16 | Card headers |
| Body Large | 15 | Emphasized body |
| Body Regular | 14 | Default body |
| Caption | 12 | Secondary text |
| Meta | 11 | Timestamps, hints |
| Drawer Section | 13 | Sidebar section labels |
| Drawer Menu | 16 | Sidebar items (not oversized) |
| Drawer Subtitle | 12 | Sidebar subtitles |

### Migration

- `lib/core/theme/typography.dart` re-exports `app_typography.dart` for backward compatibility.
- `AppTheme` builds `TextTheme` from `AppTypography.buildTextTheme()`.
- Drawer, settings appearance, profile header, service grid, network chips updated to semantic styles.

### Remaining typography work (P2)

- Grep `TextStyle(` / `fontSize:` in `lib/features/**` outside home shell (~legacy screens).
- Migrate fundraising/profile tabs to `AppTypography.*(context)` helpers.

---

## Phase 2 — Force consistent light mode

### Changes

| File | Change |
|------|--------|
| `lib/main.dart` | `themeMode: ThemeMode.light`; `darkTheme: AppTheme.light` |
| `lib/core/theme/app_theme.dart` | Light-only builder; `brightness: Brightness.light` |
| `lib/core/theme/theme_mode_provider.dart` | Always returns `ThemeMode.light` |
| `lib/core/theme/theme_extensions.dart` | `isDarkMode` → always `false` |
| `lib/core/theme/theme_controller.dart` | Legacy controller locked to light |
| `lib/features/settings/.../settings_screen.dart` | Removed dark/system radio tiles; info tile only |

### Behavior

- Android dark mode / system theme **does not** change BPA colors.
- `MediaQuery.platformBrightness` is **not** used for theming.
- Device **screen brightness** (slider) is unaffected — OS setting only.

### Verification

1. Enable Android dark mode.
2. Open BPA → background, cards, drawer, feed remain light.
3. Adjust brightness in quick settings → content dims/brights; colors stay BPA light palette.

---

## Phase 3 — Brightness compatibility

No code blocks `Brightness` or screen brightness APIs. Only `ThemeData` colors are locked.

---

## Phase 4 — Back button governance

### New component

**File:** `lib/core/navigation/home_back_handler.dart`

Wrapped around `BPAHomeScreen` scaffold.

| Step | Action |
|------|--------|
| 1 | If drawer open → close drawer |
| 2 | If tab ≠ Home → switch to Home tab |
| 3 | First back on Home → Snackbar: "Press back again to exit" |
| 4 | Second back within 2s → `SystemNavigator.pop()` |

### Not used

- No `exit(0)` in app code.
- `SystemNavigator.pop()` only in confirmed double-back exit path.

### Other routes

- Pushed routes (`Navigator.push`, named routes) use default stack pop.
- Dialogs/sheets: standard `Navigator.pop` when user dismisses.

### Remaining (P2)

- Audit modal routes for `barrierDismissible` + back consistency.
- Optional: global `PopScope` wrapper for full-screen flows without scaffold.

---

## Phase 5 — Responsive drawer

| Requirement | Implementation |
|-------------|----------------|
| Width 80–85% | `width = screenWidth * 0.825`, clamp 280–400 |
| No overflow | `Wrap` action chips; `maxLines` + ellipsis on titles |
| Profile header | Column layout; `BpaNetworkAvatar`; membership badge |
| Typography | Drawer section 13 / menu 16 / subtitle 12 |

---

## Phase 6 — Files modified

| File | Phase |
|------|-------|
| `lib/core/theme/app_typography.dart` | **New** — typography |
| `lib/core/theme/typography.dart` | Re-export |
| `lib/core/theme/app_theme.dart` | Light-only theme |
| `lib/core/theme/theme_mode_provider.dart` | Force light |
| `lib/core/theme/theme_extensions.dart` | `isDarkMode` false |
| `lib/core/theme/theme_controller.dart` | Force light |
| `lib/core/navigation/home_back_handler.dart` | **New** — back |
| `lib/main.dart` | `ThemeMode.light` |
| `lib/features/home/.../bpa_home_screen.dart` | Back handler + theme surfaces |
| `lib/features/home/.../custom_drawer.dart` | Width, typography, layout |
| `lib/features/settings/.../settings_screen.dart` | Appearance copy |
| `lib/features/profile/.../profile_header.dart` | Typography import |
| `lib/core/widgets/bpa_network_image.dart` | Caption scale |
| `lib/features/home/.../service_grid.dart` | Meta scale |
| `docs/mobile_ui_standardization_report.md` | **This report** |

Prior UI pass (see `docs/ui_audit_report.md`): story section, bottom nav, feed avatar, cause cards.

---

## Overflow & responsive status

| Area | Status |
|------|--------|
| Drawer header chips | ✅ `Wrap` |
| Drawer menu text | ✅ Ellipsis |
| Bottom nav labels | ✅ `FittedBox` |
| Story labels | ✅ Fixed width |
| Cause cards | ✅ % width |
| Service grid | ✅ Dynamic item width |

**Manual test:** `flutter run --dart-define-from-file=env/dev.json` on 320 / 360 / 390 widths; open drawer, scroll feed, press back twice on home.

---

## Remaining recommendations

### P1

1. Migrate remaining screens to `AppTypography` (auth, fundraising, campaign, pets).
2. Replace `Colors.white` hard-codes in drawer list tiles with `colorScheme.surface`.
3. Add l10n string for "Press back again to exit".

### P2

1. Tablet: master-detail or wider max drawer width.
2. Golden tests: typography scale + light `ColorScheme` snapshot.
3. Remove `@Deprecated` `AppTheme.dark` after confirming no references.

### P3

1. Optional `ThemeExtension` for donation/fundraising accent colors.
2. Screenshot matrix under `docs/ui/screenshots/`.

---

## Sign-off checklist

| Criterion | Met |
|-----------|-----|
| Central typography | ✅ |
| Drawer menu not oversized | ✅ |
| Always BPA light theme | ✅ |
| Device brightness unaffected | ✅ |
| Professional back on home | ✅ |
| Drawer 80–85% width | ✅ |
| Analyzer errors on touched core files | ✅ (no errors) |

---

*Generated as part of BPA global UX standardization. Complements `docs/ui_audit_report.md`.*
