# Furtail Mobile — Crash Monitoring

Firebase **Crashlytics** via [`CrashReportingService`](../../lib/core/crash_reporting/crash_reporting_service.dart).

## Setup

1. Configure Firebase (`flutterfire configure`) with Crashlytics enabled for the project.
2. Dependency: `firebase_crashlytics` (with `firebase_core`).
3. Android: `com.google.firebase.crashlytics` Gradle plugin on the app module (see `android/app/build.gradle.kts`).
4. `main.dart` boot order:
   - `Firebase.initializeApp`
   - `CrashReportingService.instance.initialize()`
   - `CrashReportingService.instance.installGlobalHandlers()`
   - `runZonedGuarded` + `ProviderScope(observers: [FurtailCrashlyticsProviderObserver()])`

Collection is **disabled in debug** (`kDebugMode`) to avoid noise; enable locally with:

```dart
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
```

## Error capture matrix

| Category | Mechanism | Fatal? | Custom key `crash_source` |
|----------|-----------|--------|---------------------------|
| **Flutter errors** | `FlutterError.onError` → `recordFlutterFatalError` | Yes (framework) | `flutter` |
| **Async errors** | `PlatformDispatcher.instance.onError` + `runZonedGuarded` | Yes | `async` |
| **Riverpod errors** | `FurtailCrashlyticsProviderObserver.providerDidFail` | No | `riverpod` |
| **Network errors** | `ApiClient` on HTTP failure / transport errors | No | `network` |

Additional keys for network: `http_method`, `http_path`, `http_status`.  
Riverpod adds `riverpod_provider` with the provider name.

## CrashReportingService API

| Method | Purpose |
|--------|---------|
| `initialize()` | Enable Crashlytics when Firebase is available |
| `installGlobalHandlers()` | Wire Flutter + platform error handlers |
| `recordZoneError(error, stack)` | `runZonedGuarded` callback |
| `recordFlutterError(details)` | Widget/layout framework errors |
| `recordError(error, stack, {source, fatal, reason})` | Generic non-fatal/fatal record |
| `recordRiverpodError(...)` | Provider failure |
| `recordNetworkError(...)` | API / transport failures |
| `setUserId` / `setUserIdFromStorage` / `clearUserId` | Tie crashes to Furtail user id |
| `log(message)` | Breadcrumb log line |
| `setCustomKey(key, value)` | Arbitrary diagnostic key |

## Network instrumentation

[`ApiClient`](../../lib/services/api_client.dart) reports:

- HTTP responses with status **≥ 400** (non-fatal)
- Socket/timeout/transport failures before a response (non-fatal)

URLs are reduced to **path only** in custom keys (no query strings or tokens).

## User identity

- After login, call `CrashReportingService.instance.setUserIdFromStorage()` (or set from analytics login flow).
- On logout, `clearUserId()` (wired in settings logout).

## Files

```
lib/core/crash_reporting/
├── crash_source.dart
├── crash_reporting_service.dart
├── furtail_crashlytics_provider_observer.dart
└── crash_reporting_provider.dart
```

## Manual reporting

```dart
import 'package:furtail_app/core/crash_reporting/crash_reporting_service.dart';
import 'package:furtail_app/core/crash_reporting/crash_source.dart';

try {
  await riskyOperation();
} catch (e, st) {
  await CrashReportingService.instance.recordError(
    e,
    st,
    source: CrashSource.manual,
    fatal: false,
    reason: 'risky_operation',
  );
}
```

## Firebase console

Crashes and non-fatals appear under **Crashlytics** in the Firebase console. Non-fatals are grouped under “Non-fatals” / issues with `fatal: false`.

### Force a test crash (release only, when collection enabled)

```dart
FirebaseCrashlytics.instance.crash();
```

Do not ship test-crash calls in production builds.

## Privacy

- Do not set custom keys for passwords, tokens, or full request bodies.
- `http_path` uses URI path only.

## Related

- Analytics: [`analytics_events.md`](analytics_events.md)
