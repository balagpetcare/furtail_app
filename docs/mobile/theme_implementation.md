# Material 3 Theme Implementation

**Project:** `furtail_app`  
**Date:** 2026-06-04  
**Status:** Implemented

---

## 1. Overview

The app now uses a **Material 3** theme architecture with:

| Capability | Implementation |
|------------|----------------|
| Light theme | `AppTheme.light` |
| Dark theme | `AppTheme.dark` |
| System theme | `ThemeMode.system` via `themeModeProvider` |
| Persistence | `SharedPreferences` key `theme_mode` |
| Settings UI | Light / Dark / System radio group |
| Typography | Inter + Roboto fallback (`AppTypography`) |
| Semantic colors | `AppPalette` + `AppColorScheme` |

---

## 2. File structure

```
lib/core/theme/
├── colors.dart              # AppPalette, AppColorScheme.light/dark
├── typography.dart          # Inter TextTheme (see typography_migration.md)
├── app_theme.dart           # AppTheme.light, AppTheme.dark
├── theme_mode_provider.dart # ThemeModeNotifier (Riverpod)
├── theme_extensions.dart    # context.colorScheme helpers
└── theme_controller.dart    # @deprecated — use themeModeProvider

lib/core/storage/local_storage.dart
  └── getThemeMode() / setThemeMode()

lib/main.dart
  └── MaterialApp(themeMode, theme, darkTheme)

lib/features/settings/presentation/settings_screen.dart
  └── Appearance: Light / Dark / System
```

---

## 3. AppTheme

### Light (`AppTheme.light`)

- **Primary:** `#1E60AA` (brand blue)
- **Scaffold:** `#FFFFFF`
- **Surface:** `#F5F5F5`
- **Text:** `#1A1A1A` / `#666666` / `#999999`
- **App bar:** primary background, white foreground

### Dark (`AppTheme.dark`)

- **Primary:** `#5B8FD4` (lighter blue for contrast on dark)
- **Scaffold:** `#0F1419`
- **Surface:** `#1A1F26`
- **Surface container:** `#232A33`
- **Text:** `#F3F4F6` / `#B8BFC8`

Both themes configure: `elevatedButton`, `inputDecoration`, `card`, `drawer`, `bottomNavigationBar`, `divider`, `snackBar`, `switch`, `radio`.

### Usage

```dart
MaterialApp(
  themeMode: ref.watch(themeModeProvider).value ?? ThemeMode.system,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
);
```

---

## 4. ThemeModeProvider

**File:** `lib/core/theme/theme_mode_provider.dart`

```dart
final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
```

| Method | Behavior |
|--------|----------|
| `build()` | Loads `light` \| `dark` \| `system` from prefs (default **system**) |
| `setThemeMode(ThemeMode)` | Persists + updates `AsyncData` |

**Storage:** `LocalStorage.setThemeMode` / `getThemeMode` — same key as legacy `ThemeController` (`theme_mode`).

**Migration from `ThemeController`:** Removed from `main.dart`. `@Deprecated` stub kept for any stale imports.

---

## 5. Settings page

**Route:** `/settings` → `features/settings/presentation/settings_screen.dart`  
(Router updated from legacy settings screen.)

**Appearance section:**

| Option | `ThemeMode` | EN label | BN label |
|--------|-------------|----------|----------|
| Light | `ThemeMode.light` | Light | লাইট |
| Dark | `ThemeMode.dark` | Dark | ডার্ক |
| System | `ThemeMode.system` | System | সিস্টেম |

Uses `RadioListTile<ThemeMode>` bound to `themeModeProvider`.

**Themed UI:** Cards and scaffold use `context.colorScheme` (no hardcoded `#F5F5F5` / `#E6E6E6`).

**l10n keys:** `themeLight`, `themeDark`, `themeSystem`, `*Desc` — in `app_en.arb` / `app_bn.arb`.

---

## 6. Context extensions

**File:** `lib/core/theme/theme_extensions.dart`

```dart
context.colorScheme      // ColorScheme
context.primaryColor     // colorScheme.primary
context.scaffoldBg       // scaffoldBackgroundColor
context.isDarkMode       // brightness == dark
```

Prefer these over `Color(0x…)` and `AppColors.*` in widgets.

---

## 7. Color migration status

### Completed (theme-aware)

| Area | Change |
|------|--------|
| `main.dart` | `AppTheme.light` / `dark`, dynamic `themeMode` |
| Settings screen | Full `ColorScheme` |
| `primary_button.dart` | `colorScheme.primary` / `onPrimary` |
| Home shell | `bpa_home_screen`, `custom_bottom_nav`, `home_app_bar` |
| Feed / posts (partial) | Brand blue → `colorScheme.primary` in 18 files |
| `app_colors.dart` | Delegates to `AppPalette` |

### Remaining hardcoded hex (approx.)

| Pattern | Count (lib/) | Notes |
|---------|--------------|--------|
| All `Color(0x…)` | ~170+ | Down from ~212; many borders/surfaces/status chips |
| `0xFF1E60AA` specifically | ~25+ | Some files partially migrated |
| `Colors.*` | ~600 | Prefer `colorScheme.onSurfaceVariant`, etc. |

**Intentional exceptions:**

- Campaign card gradients (`digital_vaccination_card_widget.dart`)
- Wallet status badge palette (semantic success/warning per status)
- Pet profile accent oranges/blues (feature-specific)
- Video overlays (`Colors.white` on black)

### Recommended next pass

1. Replace `Color(0xFFE6E6E6)` borders with `colorScheme.outline`
2. Replace `Color(0xFFF5F5F5)` backgrounds with `colorScheme.surface`
3. Add CI: warn on new `Color(0x` outside `lib/core/theme/`

---

## 8. Backward compatibility

| Legacy | Replacement |
|--------|-------------|
| `buildAppTheme()` | `AppTheme.light` |
| `ThemeController.instance` | `ref.read(themeModeProvider.notifier)` |
| `AppColors.donateBlue` | `AppPalette.primary` / `colorScheme.primary` |
| `AppColors.textPrimary` | `colorScheme.onSurface` |

---

## 9. QA checklist

- [ ] Settings → Light: app stays light after restart
- [ ] Settings → Dark: dark scaffold, readable text, primary buttons visible
- [ ] Settings → System: follows device setting; toggle device dark mode
- [ ] Home feed, drawer, FAB in light and dark
- [ ] Campaign / wallet screens (many still use light-only hex — verify contrast in dark)
- [ ] Bengali strings on theme options

---

## 10. Related docs

- `docs/mobile/design_system_plan.md` — full token roadmap
- `docs/mobile/typography_migration.md` — Inter TextTheme migration

---

*End of theme implementation doc.*
