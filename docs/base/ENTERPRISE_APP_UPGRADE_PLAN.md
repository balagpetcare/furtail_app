
# Furtail Flutter App — Enterprise Upgrade Plan

## Purpose

Upgrade the Flutter pet social app into a professional, lightweight, enterprise-level social app similar in quality to Facebook/Instagram, while keeping the app stable, fast, maintainable, and easy to scale.

This plan must be executed phase by phase by the AI coding agent.

---

## Global Execution Rules

1. Do not rewrite the whole app.
2. Do not redesign all screens at once.
3. Do not remove existing working features.
4. Do not add heavy packages unless absolutely required.
5. Follow the existing architecture, naming style, routing style, state management, theme system, and folder structure.
6. Keep the app lightweight and stable.
7. Work phase by phase.
8. Update the Phase Status Tracker after each phase.
9. After each phase, run:
   - flutter analyze
10. When practical, also run:
   - flutter build apk --debug
11. If analyze/build errors appear, fix them before moving to the next phase.
12. If backend APIs are missing, create safe placeholder services or local persistence without breaking the app.
13. Do not break:
   - Login/register
   - Feed
   - Post creation/upload/edit
   - Profile image upload
   - Cover image upload
   - Pet profile
   - Pet registration
   - Pet care upload
   - Navigation
14. For non-destructive Flutter code changes, proceed without asking.
15. For destructive actions, database changes, deleting files, removing dependencies, or changing backend contracts, do not proceed. Document the recommendation instead.
16. If a task is too risky, skip the risky part, document why, and continue with safe tasks.
17. Keep implementation modular and reusable.
18. Prefer existing packages and utilities already in the project.
19. Avoid unnecessary animations, heavy video loading, and excessive rebuilds.
20. At the end, provide a final report.

---

## Phase Status Tracker

| Phase | Name | Status | Notes |
|---|---|---|---|
| 1 | Audit & Roadmap | done | Audit complete; 321 info-level issues baseline; no build errors |
| 2 | Settings System | done | SettingsScreen restructured; AccountSettingsScreen + MediaStorageSettingsScreen added; l10n ARB updated |
| 3 | Privacy & Safety Foundation | done | PrivacySettingsScreen extended: whoCanComment, ReportBottomSheet wired; BlockedUsersScreen complete |
| 4 | Notification Settings | done | NotificationPreferencesScreen: mentionsNotif, messagesNotif, marketingNotif added |
| 5 | Media & Storage Settings | done | MediaUploadSettings model + datasource + provider; MediaStorageSettingsScreen with radio pickers |
| 6 | Feed UX & Performance | done | PostCard: hide-post, block-user menu items; _hidden guard; SettingsLocalDatasource.blockUser() |
| 7 | Profile & Pet Profile Polish | done | VisitorProfileScreen: real block implementation with confirmation + popUntil root |
| 8 | Account Settings & Session Safety | done | AccountSettingsScreen complete (placeholder for deactivate/delete per safety rules) |
| 9 | Global UI State Components | done | AppLoadingView, AppSkeletonCard, AppPostSkeleton, AppEmptyState, AppErrorState, AppOfflineBanner, AppSectionHeader, AppRetryButton |
| 10 | Accessibility, Responsive UI & Dark Mode | done | withOpacity → withValues(alpha:) fixed across 8 files; unnecessary_underscores fixed across 40+ lib files |
| 11 | Dependency & Performance Cleanup | done | __ → _ wildcards across all lib files; ARB source files corrected; 197 issues (was 321) |
| 12 | Final Enterprise QA | done | flutter analyze: 197 issues (info-only, 0 errors); flutter build apk --debug: PASS |

Allowed statuses:
- pending
- in_progress
- done
- skipped
- blocked

---

# Phase 1 — Audit & Roadmap

## Objective

Audit the current Flutter app before making major changes.

## Tasks

Check:

1. App architecture and folder structure
2. State management consistency
3. Navigation and route safety
4. Authentication and session handling
5. Feed performance and pagination
6. Profile, pet profile, and visitor profile UX
7. Post creation, upload, edit, delete, and background upload progress
8. Image/video picker, cropper, compression, cache, and upload flow
9. Error handling
10. Empty states
11. Loading states
12. Retry states
13. Offline-first behavior and cache strategy
14. Notification readiness
15. Privacy, blocking, reporting, and moderation basics
16. App settings and account settings
17. Accessibility and responsiveness
18. Dark mode readiness
19. Security issues in client code
20. Unused heavy dependencies or code that makes the app slow

## Output Required

Return:

1. Critical issues
2. High-priority improvements
3. Medium-priority improvements
4. Low-priority polish
5. Suggested phase-by-phase implementation plan
6. Files likely involved
7. Risks before implementation

## Restrictions

Do not modify code in this phase unless a build-breaking issue blocks basic inspection.

## Verification

Run:

```bash
flutter analyze
````

---

# Phase 2 — Professional Settings System

## Objective

Implement a professional, lightweight Settings system.

## Tasks

Add a main Settings screen with grouped sections:

1. Account
2. Privacy & Safety
3. Notifications
4. Media & Storage
5. Language
6. Appearance
7. Help & Support
8. About
9. Logout

## Requirements

1. Use existing design tokens, theme, typography, spacing, and reusable components if available.
2. Do not add heavy packages.
3. Each settings row should have:

   * Icon
   * Title
   * Optional subtitle
   * Trailing chevron or switch
4. Add placeholder detail screens only where backend is not ready.
5. Settings must be reachable from the user profile menu.
6. Add safe loading/error states where needed.
7. Keep code modular and reusable.
8. Do not break existing profile navigation.
9. Logout must not happen instantly. It must show confirmation first.
10. Settings screen must be clean and professional.

## Suggested Files

Use existing structure if available. Otherwise create files similar to:

* lib/features/settings/presentation/screens/settings_screen.dart
* lib/features/settings/presentation/widgets/settings_section.dart
* lib/features/settings/presentation/widgets/settings_tile.dart

## Verification

Run:

```bash
flutter analyze
flutter build apk --debug
```

---

# Phase 3 — Privacy & Safety Foundation

## Objective

Add client-side foundation for privacy, block, and report features.

## Tasks

Add Privacy & Safety screen under Settings.

Include:

1. Profile Visibility:

   * Public
   * Followers only
   * Private
2. Who can message me:

   * Everyone
   * Followers
   * No one
3. Who can comment:

   * Everyone
   * Followers
   * No one
4. Blocked Accounts
5. Report a Problem
6. Community Guidelines

## Requirements

1. If backend APIs exist, integrate them.
2. If backend APIs do not exist, create safe service/repository placeholders and local persistence.
3. Add report entry points from:

   * Post overflow menu
   * User profile overflow menu
   * Visitor profile overflow menu
   * Pet profile overflow menu if applicable
4. Report dialog must include:

   * Reason list
   * Optional description
   * Cancel button
   * Submit button
   * Loading state
   * Success state
   * Error state
5. Block action must show confirmation dialog before blocking.
6. Keep UX professional and lightweight.
7. Do not implement aggressive moderation logic yet.
8. Do not hide or delete real content from backend unless backend already supports it safely.
9. If backend is missing, use local placeholder persistence and document it.

## Suggested Report Reasons

Use these reasons:

1. Spam
2. Harassment or bullying
3. Hate or abusive content
4. Scam or fraud
5. Animal abuse or harmful content
6. False information
7. Other

## Verification

Run:

```bash
flutter analyze
flutter build apk --debug
```

---

# Phase 4 — Notification Settings

## Objective

Implement professional Notification Settings.

## Tasks

Add Notification Settings screen under Settings.

Include toggles for:

1. Likes
2. Comments
3. New followers
4. Mentions
5. Messages
6. Pet care reminders
7. Campaign or event updates
8. Marketing/promotional updates

## Requirements

1. Store preferences locally if backend is not ready.
2. Sync with backend if backend exists.
3. Use one reusable settings switch tile component.
4. Show loading state when saving if needed.
5. Show save failure and retry behavior.
6. Do not add push notification implementation in this phase unless already present.
7. Toggles must persist after app restart.
8. Keep the screen lightweight and professional.

## Verification

Run:

```bash
flutter analyze
flutter build apk --debug
```

---

# Phase 5 — Media & Storage Settings

## Objective

Add professional media and storage controls.

## Tasks

Add Media & Storage screen under Settings.

Include:

1. Upload quality:

   * Data saver
   * Standard
   * High quality
2. Auto-play videos:

   * Always
   * Wi-Fi only
   * Never
3. Save uploaded media to device: toggle
4. Compress images before upload: toggle
5. Compress videos before upload: toggle
6. Clear image cache button
7. Clear video/media cache button if available

## Requirements

1. Connect settings to existing image/video upload and compression flow where safe.
2. If upload flows are not centralized, create a lightweight MediaUploadSettingsService.
3. Do not break:

   * Post upload
   * Post edit upload
   * Profile avatar upload
   * Profile cover upload
   * Pet cover upload
   * Pet care image upload
4. Show confirmation dialog before clearing cache.
5. Show success/error snackbar after cache action.
6. Use local persistence if backend is not ready.
7. Keep defaults safe:

   * Upload quality: Standard
   * Auto-play videos: Wi-Fi only
   * Compress images: enabled
   * Compress videos: enabled
   * Save uploaded media: disabled

## Verification

Run:

```bash
flutter analyze
flutter build apk --debug
```

---

# Phase 6 — Feed UX & Performance

## Objective

Improve feed performance and lightweight social UX.

## Tasks

Ensure feed supports:

1. Initial skeleton loading
2. Pull to refresh
3. Infinite scroll pagination
4. Empty feed state
5. Offline cached feed state
6. Retry on failure
7. Memory-safe image rendering
8. Video loading that respects media settings

Add post overflow menu:

1. Save post
2. Hide post
3. Report post
4. Block user

## Requirements

1. Use local placeholder persistence if backend is missing.
2. Keep UI smooth.
3. Avoid unnecessary rebuilds.
4. Do not add heavy packages.
5. Videos should not auto-load heavily unless visible or user settings allow.
6. Images must use bounded cache size where practical.
7. Feed must not show a blank screen if cached content exists.
8. Error states must have retry action.
9. Empty feed must have clear friendly copy.
10. Offline state must be visible but not annoying.

## Verification

Run:

```bash
flutter analyze
flutter build apk --debug
```

---

# Phase 7 — Profile, Visitor Profile & Pet Profile Polish

## Objective

Upgrade profile screens to professional social-app quality.

## Tasks

Improve:

1. Header layout
2. Avatar loading state
3. Cover image loading state
4. Follow/message/action buttons
5. Edit profile entry point
6. Visitor profile view
7. Pet profile owner/visitor view
8. Empty posts state
9. Loading skeleton state
10. Error retry state
11. Back button visibility on cover images
12. Safe spacing for status bar and device notch
13. Profile menu and action menu consistency

Add profile overflow menu:

1. Share profile
2. Report user
3. Block user

## Requirements

1. Keep design consistent with current theme.
2. Do not make UI heavy or over-animated.
3. Do not break existing profile edit/upload behavior.
4. Do not break visitor profile behavior.
5. Do not break pet profile behavior.
6. If a feature is backend-dependent, create safe placeholder behavior and document it.

## Verification

Run:

```bash
flutter analyze
flutter build apk --debug
```

---

# Phase 8 — Account Settings & Session Safety

## Objective

Implement Account Settings and safer session handling.

## Tasks

Add Account Settings screen under Settings.

Include:

1. Edit profile
2. Change phone/email placeholder if backend is missing
3. Change password placeholder if backend is missing
4. Connected accounts placeholder
5. Active sessions placeholder
6. Download my data placeholder
7. Deactivate account placeholder
8. Delete account placeholder

## Requirements

1. Logout must show confirmation dialog.
2. Delete/deactivate actions must require confirmation.
3. Keep delete/deactivate disabled if backend is not ready.
4. If current architecture supports it, handle global unauthorized API response safely:

   * Redirect to login
   * Clear sensitive local session data
   * Show user-friendly message
5. Do not break existing login/register flow.
6. Do not add risky account deletion logic without backend support.
7. Do not remove user data locally except during confirmed logout/session clear.

## Verification

Run:

```bash
flutter analyze
flutter build apk --debug
```

---

# Phase 9 — Global UI State Components

## Objective

Create reusable loading, error, empty, retry, and offline UI components.

## Tasks

Add reusable components:

1. AppLoadingView
2. AppSkeletonCard
3. AppEmptyState
4. AppErrorState
5. AppRetryButton
6. AppOfflineBanner
7. AppSectionHeader

## Requirements

1. Replace duplicate loading/error/empty UI in major screens where safe:

   * Feed
   * Profile
   * Visitor profile
   * Pet profile
   * Settings
   * Post details if available
2. Follow existing theme.
3. Do not introduce heavy shimmer packages unless already installed.
4. If shimmer is not installed, use simple skeleton containers.
5. Components must support dark mode colors from theme.
6. Add clear copy text and retry callbacks.
7. Keep components generic and reusable.
8. Do not over-refactor unrelated screens.

## Verification

Run:

```bash
flutter analyze
flutter build apk --debug
```

---

# Phase 10 — Accessibility, Responsive UI & Dark Mode Readiness

## Objective

Improve app quality on real Android devices.

## Tasks

Audit and fix obvious issues:

1. Small phone layout problems
2. Large phone layout problems
3. Text overflow
4. Tap target size
5. Color contrast
6. Missing semantic labels
7. Unsafe hardcoded colors
8. Status bar overlap
9. Bottom navigation overlap
10. Keyboard overlap in forms

Add semantic labels to important buttons:

1. Back
2. Close
3. Post
4. Upload media
5. Like
6. Comment
7. Share
8. Profile actions
9. Settings
10. Retry

## Requirements

1. Replace unsafe hardcoded colors with theme-based colors where practical.
2. Ensure profile/feed/settings screens work on small Android devices.
3. Do not redesign the whole app.
4. Do not add heavy accessibility packages.
5. Keep changes practical and safe.

## Verification

Run:

```bash
flutter analyze
flutter build apk --debug
```

---

# Phase 11 — Dependency & Performance Cleanup

## Objective

Optimize dependencies and app performance safely.

## Tasks

1. Review pubspec.yaml dependencies.
2. Identify unused, duplicated, or heavy dependencies.
3. Search codebase for dependency usage before recommending removal.
4. Check image/video/media packages and confirm whether they are necessary.
5. Identify screens/widgets with unnecessary rebuilds.

## Safe Optimizations

Implement where safe:

1. Add const constructors
2. Reduce unnecessary rebuild areas
3. Use bounded image rendering
4. Use lazy loading
5. Avoid heavy video initialization
6. Avoid repeated network calls from build methods
7. Avoid unnecessary setState calls
8. Avoid unnecessary full-screen rebuilds

## Restrictions

1. Do not remove dependencies without clear evidence.
2. Do not change app behavior unexpectedly.
3. For risky dependency removal, only document recommendation.
4. Do not upgrade major package versions without approval.
5. Do not change Android Gradle, compileSdk, targetSdk, or Java version unless build requires it and the change is safe.

## Output Required

Return:

1. Dependencies kept
2. Dependencies safe to remove
3. Dependencies requiring manual decision
4. Performance improvements implemented
5. Files changed
6. Risks

## Verification

Run:

```bash
flutter analyze
flutter build apk --debug
```

---

# Phase 12 — Final Enterprise QA

## Objective

Run final QA and report production readiness.

## Check

1. App startup
2. Login/session flow
3. Home/feed
4. Post create/edit/upload progress
5. Image picker
6. Video picker
7. Image compression
8. Video compression
9. Profile and visitor profile
10. Pet profile
11. Pet registration
12. Pet care upload
13. Settings screens
14. Privacy and report/block flow
15. Notification settings
16. Media/storage settings
17. Offline behavior
18. Error/empty/loading states
19. Dark mode readiness
20. Small-device responsiveness
21. Build stability

## Output Required

Return:

1. PASS/FAIL verdict
2. Critical blockers
3. Non-critical issues
4. UX polish suggestions
5. Security concerns
6. Performance concerns
7. Exact changed files
8. Exact build/analyze result
9. Skipped items
10. Remaining risks
11. Next recommended steps

## Restrictions

Do not make large new changes in this phase unless required to fix build-breaking issues.

---

# Final Report Format

At the end, provide this report:

```text
Final Enterprise Upgrade Report

Verdict:
Completed Phases:
Skipped Phases:
Blocked Items:
Changed Files:
Analyze Result:
Build Result:
Implemented Features:
Local Placeholder Features:
Backend Required Features:
Remaining Risks:
Recommended Next Steps:
```
