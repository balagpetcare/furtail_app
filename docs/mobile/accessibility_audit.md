# BPA Mobile — Accessibility Audit

Audit date: 2026-06-04  
Scope: `bpa_app` Flutter client (`lib/`)  
Standards reference: WCAG 2.1 AA (where applicable), Material 3 accessibility guidance

## Executive summary

| Area | Status before | Status after fixes |
|------|---------------|-------------------|
| Text scaling | Partial — typography tokens, some fixed-height rows | Supported via Material `TextTheme`; global scaling not blocked |
| Screen readers | Poor — no `Semantics` usage | Improved on shell, settings, home nav; backlog remains |
| Contrast ratios | Fail — muted `#999` on white | Fixed token `#5C5C5C`; theme pairs documented |
| Touch targets | Fail — custom nav ~26px icons | 48dp minimum in theme + `MinTouchTarget` / `AccessibleIconButton` |
| Dark mode | Partial — many hardcoded `Colors.white` / `black54` | Fixed on home, settings, visitor profile; migration ongoing |

---

## 1. Text scaling

### Findings

- **Positive:** No hardcoded `fontSize:` in feature code; text uses `AppTypography` / `context.appText` (`lib/core/theme/typography.dart`).
- **Risk:** Fixed-height containers (e.g. search bar `height: 45`, bottom nav `height: 60`) may clip when system text scale exceeds ~1.3×.
- **Gap:** `MaterialApp` did not restrict scaling (correct for accessibility); layouts must stay scrollable/flexible.

### Fixes applied

- Documented expectation: prefer `TextTheme` + flexible/`Expanded` layouts.
- `MaterialApp.builder` → `AppAccessibilityBuilder` hook for future announcements (`lib/core/accessibility/a11y_widgets.dart`).

### Recommendations (backlog)

- Audit feed cards, fundraising screens, and pet wizard for overflow at **200% text scale** (Android: Display size + font size).
- Use `LayoutBuilder` or `FittedBox` only where appropriate; avoid capping `textScaler`.

---

## 2. Screen readers (TalkBack / VoiceOver)

### Findings

- **0** explicit `Semantics` widgets before audit.
- Custom bottom nav: icon+label columns without button semantics.
- Home header: drawer avatar `InkWell` without label; notification icon non-interactive `Stack` without role.
- Icon-only actions across feed/profile lacked `tooltip` / `semanticLabel`.

### Fixes applied

| Location | Change |
|----------|--------|
| `custom_bottom_nav.dart` | `MinTouchTarget` + `Semantics` (tab name, selected state) |
| `home_app_bar.dart` | “Open navigation menu”, search field label, `AccessibleIconButton` for notifications |
| `bpa_home_screen.dart` | FAB: “Create new post” |
| `settings_widgets.dart` | `SettingsNavTile` semantics |
| `settings_screen.dart` | Theme radio tiles: combined label + selected |
| `app_primary_button.dart` | Button semantics + enabled state |

### New utilities

```
lib/core/accessibility/
├── a11y_constants.dart      # minTouchTarget = 48
├── a11y_widgets.dart        # MinTouchTarget, AccessibleIconButton, AppAccessibilityBuilder
```

### Recommendations (backlog)

- Add semantics to `feed_post_card.dart` action row (like, comment, share).
- `comments_sheet.dart` / `post_details_screen.dart`: label composer and list items.
- `custom_drawer.dart`: menu items as buttons with clear labels.
- Images: `Semantics(label: '…', image: true)` or exclude decorative avatars with `excludeFromSemantics: true`.
- Run manual TalkBack pass on login → home → settings → profile.

---

## 3. Contrast ratios

### Token audit (sRGB, WCAG AA normal text ≥ 4.5:1)

| Pair | Ratio | AA normal | Notes |
|------|-------|-----------|-------|
| `#1A1A1A` on `#FFFFFF` (onSurface / light bg) | ~16.6:1 | Pass | Primary text |
| `#666666` on `#FFFFFF` (old onSurfaceVariant) | ~5.7:1 | Pass | Body secondary |
| `#999999` on `#FFFFFF` (old outlineVariant / bodySmall) | ~2.8:1 | **Fail** | Used for captions |
| `#5C5C5C` on `#FFFFFF` (new outlineVariant) | ~6.0:1 | Pass | **Fixed** in `AppPalette.lightOutlineVariant` |
| `#1E60AA` on `#FFFFFF` (primary buttons/links) | ~4.9:1 | Pass | Primary brand |
| `#F3F4F6` on `#0F1419` (dark onSurface / bg) | ~15:1 | Pass | Dark mode body |
| `#B8BFC8` on `#1A1F26` (dark onSurfaceVariant) | ~7.5:1 | Pass | Dark secondary |
| `#5B8FD4` on `#0F1419` (dark primary) | ~5.5:1 | Pass | Dark primary |
| `#FFD700` on `#FFFFFF` (secondary gold on white) | ~1.4:1 | **Fail** | Avoid for small text on light surfaces |

### Fixes applied

- `lib/core/theme/colors.dart`: `lightOutlineVariant` `#999999` → `#5C5C5C`.
- Theme-aware muted text via `context.mutedTextColor` (`theme_extensions.dart`).

### Recommendations (backlog)

- Replace ~80+ `Colors.black54` / `Colors.white` usages with `colorScheme` (see grep in `lib/features/posts`, `fundraising`, `legacy`).
- Do not use `AppPalette.secondary` (#FFD700) for text on white; use for icons/accents only.

---

## 4. Touch target size

### Findings

- Material recommends **48×48 dp** minimum (WCAG 2.5.5).
- Bottom nav `InkWell` children ~26px icon only.
- Home notification glyph ~42px including padding but not a proper `IconButton`.

### Fixes applied

- `A11yConstants.minTouchTarget = 48`.
- Global `iconButtonTheme` / `textButtonTheme` in `app_theme.dart`.
- `MinTouchTarget` and `AccessibleIconButton` widgets.
- Bottom nav and home app bar updated.

### Recommendations (backlog)

- Feed reaction chips and reel controls: wrap with `MinTouchTarget`.
- Campaign `booking_tile` QR button: verify height ≥ 48.

---

## 5. Dark mode compatibility

### Findings

- `AppTheme.light` / `AppTheme.dark` and settings theme mode exist.
- Widespread hardcoded `Colors.white`, `Colors.black54`, `Colors.grey` break dark surfaces and contrast.
- Worst offenders: `visitor_profile_screen`, `post_details_screen`, `comments_sheet`, `create_post_screen`, `fundraising_details_screen`.

### Fixes applied

| File | Change |
|------|--------|
| `settings_widgets.dart` | `cardSurface` instead of `Colors.white` |
| `bpa_home_screen.dart` | RefreshIndicator + FAB use `colorScheme` |
| `custom_bottom_nav.dart` | `cs.surface` for bar |
| `home_app_bar.dart` | Full `colorScheme` for search + notification |
| `visitor_profile_screen.dart` | Scaffold, app bar, tabs, stats, award cards |

### Recommendations (backlog)

- Continue migration using `context.colorScheme` / `context.cardSurface` / `context.mutedTextColor`.
- Remove `backgroundColor: Colors.white` from scaffolds (30+ files).
- Test **Settings → Dark** on: home feed, post detail, fundraising, campaign hub.

---

## Testing checklist

### Text scaling

1. Android: Settings → Display → Font size **Largest**; open Home, Settings, Login.
2. iOS: Larger Text → maximum; verify no critical overflow.

### Screen readers

1. Enable TalkBack (Android) or VoiceOver (iOS).
2. Traverse: drawer → tabs → FAB → Settings → theme radios.
3. Confirm each actionable control speaks a meaningful name.

### Contrast

1. Use [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/) on token hex pairs above.
2. Spot-check dark mode primary buttons and error text.

### Touch targets

1. TalkBack “Explore by touch” — targets should not overlap below 48dp.
2. Physical test: tap bottom nav and notification with thumb.

### Dark mode

1. Settings → Appearance → Dark.
2. Visit Home, Visitor Profile, Settings; no large white panels or invisible `black54` text.

---

## File index (fixes in this pass)

| Path | Purpose |
|------|---------|
| `lib/core/accessibility/a11y_constants.dart` | WCAG constants |
| `lib/core/accessibility/a11y_widgets.dart` | Reusable a11y widgets |
| `lib/core/theme/colors.dart` | Contrast fix |
| `lib/core/theme/app_theme.dart` | Icon/text button min size |
| `lib/core/theme/theme_extensions.dart` | `cardSurface`, `mutedTextColor` |
| `lib/main.dart` | `AppAccessibilityBuilder` |
| `lib/features/home/.../custom_bottom_nav.dart` | Nav semantics + touch |
| `lib/features/home/.../home_app_bar.dart` | Header semantics + theme |
| `lib/features/home/.../bpa_home_screen.dart` | FAB + refresh colors |
| `lib/features/settings/.../settings_widgets.dart` | Card + nav semantics |
| `lib/features/settings/.../settings_screen.dart` | Theme radio semantics |
| `lib/features/profile/.../visitor_profile_screen.dart` | Dark mode surfaces |
| `lib/ui/components/buttons/app_primary_button.dart` | Semantics + loader color |
| `lib/features/auth/.../auth_button.dart` | Loader/text onPrimary |

---

## Related docs

- Theme: `docs/mobile/theme_implementation.md`
- Typography: `docs/mobile/typography_migration.md`
- Design tokens: `docs/mobile/design_system_plan.md`
