# Central Auth Login/Redirect Audit

Audit date: 2026-07-15
Scope: `D:\wpa\furtail\furtail_app`, `D:\wpa\furtail\furtail_api`, `D:\wpa\wpa_auth\wpa_auth_api`
Mode: READ-ONLY. No production code, config, database, migrations, or dependencies were modified. No stored tokens or app data were cleared. The only file created by this audit is this report.

---

## 1. Executive summary

Users log in successfully against the WPA Central Auth API, but the Furtail experience collapses back to a login wall almost immediately, and every protected feature (Profile, My Pets, Pet Care, Adoption, Fund Raising, Saved Items, Notifications) redirects to login even when the app has apparently reached the home screen. The system shows a "Guest" user with an email visible at the same time the feed reports "login required" — an internally inconsistent state.

Three independent, confirmed defects compound to produce this behavior:

1. **Furtail API — dual-mode auth fallthrough bug (confirmed root cause).** `authModeSelector.middleware.ts` swallows Central Auth verification failures (including plain token expiry) and silently falls through to the legacy local-JWT verifier using a different secret. The legacy verifier then also fails (wrong secret/format), producing a generic `401 Unauthorized: invalid token`. This is the exact source of the observed log line `authModeSelector: dual mode - token verify failed`, and it makes "access token merely expired" indistinguishable, on the wire, from "token is garbage" — no signal exists for the client to refresh instead of logging out.

2. **Flutter app — `Dio` `validateStatus` override defeats the refresh interceptor (confirmed root cause).** `ApiClient` is configured with `validateStatus: (_) => true`, so Dio never raises a `DioException` for 401/403 responses. The carefully built `AuthInterceptor` refresh-mutex logic in `auth_interceptor.dart` is consequently unreachable for the majority of API calls — real token refreshes never happen, and any 401 is instead surfaced as a plain `Exception` deeper in the call stack, typically interpreted by callers as "unauthenticated."

3. **Flutter app — duplicate, competing navigation authorities (confirmed contributor).** Both `AuthGate` (declarative widget swap) and a global `ref.listen<AuthState>` in `main.dart` independently react to auth-state changes and independently navigate. This produces redirect loops/hard bounces to `/login` whenever `AuthStatus` transitions through `unknown`/`bootstrapFailed`, even mid-session on a screen the user already reached.

A fourth, narrower defect — `profile_service.dart` using a separate raw `http` client with no refresh logic and unconditional-fatal 401 handling — plausibly explains why **Profile** specifically fails even when other screens might tolerate a stale token slightly longer, and is consistent with the reported "Guest user with an email" state (tokens present, profile fetch failed, stale/absent display-user cache retained).

No hard contract mismatch (issuer/audience/secret) was found between the Central Auth issuer defaults and the Furtail API verifier defaults, but both sides use **environment-variable defaults that point at localhost/dev values and an empty secret** — this was not verified against the actual deployed `.env` files in either repo (out of scope for static code reading) and is flagged as the top open question.

**Root causes confirmed by reading code: 5**
**Suspected/unverified causes: 7**

---

## 2. Reproduction path based on current symptoms

1. User has a previously-issued Central Auth access token that has expired (or is close to it), commonly because the app was backgrounded past the access-token TTL (Central Auth default `ACCESS_TOKEN_TTL=15m`).
2. User submits valid credentials on the Furtail login screen. Central Auth `/auth/login` succeeds, returns a fresh access/refresh token pair. `AuthController.login()` (`furtail_app/lib/core/auth/auth_controller.dart:176-208`) persists these to secure storage.
3. `AuthController` then calls Furtail's `/auth/me` (or equivalent) to hydrate the local profile. If this call is made through `ApiClient` (which has `validateStatus: (_) => true`), any non-2xx response does **not** throw a `DioException`; `_handle()` throws a plain `Exception`, which is not routed through the interceptor's refresh path.
4. On the Furtail API side, `authModeSelector` (dual mode, default) attempts Central Auth verification. If the token is even momentarily treated as invalid/expired (see §8), it silently falls through to the legacy local-JWT verifier, which fails for a structurally different reason (wrong secret) and returns a generic `401 {"success": false, "message": "Unauthorized: invalid token"}`.
5. `AuthController` cannot distinguish "expired, please refresh" from "actually invalid" because the response shape is identical either way in dual mode. It sets state to `AuthStatus.bootstrapFailed` — not `unauthenticated` — meaning tokens are retained but the profile/display-user is never populated.
6. `BootstrapRetryScreen` (or equivalent) renders, and simultaneously the `main.dart:106-126` `ref.listen<AuthState>` fires a `pushNamedAndRemoveUntil` navigation independent of whatever `AuthGate` is already rendering — producing the visible "bounce back to login" even though the app technically reached (or was about to reach) home.
7. Any subsequent tap into Profile, My Pets, Pet Care, Adoption, Fund Raising, Saved Items, or Notifications issues its own authenticated API call. Because the underlying Furtail-side bug (#1) reproduces on essentially every request once the access token is past its 15-minute TTL, every one of these screens independently 401s and redirects to login — matching "every protected page redirects to login."
8. The "Guest user with an email" state is explained by tokens surviving in secure storage (nothing clears them on `bootstrapFailed`) while `profile_service.dart`'s separate raw-`http` path (used specifically by Profile) fails outright on 401 with no refresh attempt, leaving cached/partial user data (email known, full profile/role unknown) displayed as a guest-like state elsewhere in the UI (e.g., the feed).

---

## 3. Authentication sequence from login to protected API request (step by step, citing files)

1. **Login submission (Flutter):** identifier normalization — `furtail_app/lib/core/auth/auth_identifier_normalizer.dart:33-95` — classifies inputs such as `"01701022200"` as `mobile` and leaves them unchanged; the value is sent under a single `emailOrUsername`-style field.
2. **Login request (Flutter → Central Auth):** `furtail_app/lib/core/auth/central_auth_api.dart:101-118` posts to Central Auth's login endpoint.
3. **Login handling (Central Auth API):** `wpa_auth_api/src/modules/auth/auth.routes.ts:27-31` (`loginSchema`, field literally named `emailOrUsername`, no format/regex validation) → `wpa_auth_api/src/modules/auth/auth.service.ts` `loginUser()` lines 187-199 (identifier lower-cased/trimmed; if it contains `@` treated as email, else matched via `OR` against `username`/`email`/`phone` with **no phone normalization**).
4. **Token issuance (Central Auth API):** `wpa_auth_api/src/lib/tokens.ts` `signAccessToken` (lines 5-18) and `signRefreshToken` (lines 27-34) — HS256, payload `{sub, email, username, roles}` for access tokens (no `phone`, no `client_id`/`aud` in the payload body — those come from `jwt.sign` options), `issuer`/`audience` from `wpa_auth_api/src/config/index.ts` (`OAUTH_ISSUER`, `ACCESS_TOKEN_AUDIENCE` default `"bpa-mobile"`), `ACCESS_TOKEN_TTL` default `15m`, `REFRESH_TOKEN_TTL` default `30d` (dev) / `7d` (`.env.production.example`).
5. **Token persistence (Flutter):** `furtail_app/lib/core/auth/auth_controller.dart:176-208` saves tokens via `SecureStorageService` under keys `central_access_token` / `central_refresh_token` (`furtail_app/lib/core/services/secure_storage_service.dart:15-16`) — no key-name mismatch found between save and read sites.
6. **Furtail-side profile hydration (Flutter → Furtail API):** `AuthController` calls Furtail's `/auth/me`/profile endpoint, routed through `furtail_app/lib/services/api_client.dart` (Dio instance configured at line 29 with `validateStatus: (_) => true`).
7. **Furtail API auth middleware:** `furtail_api/src/middleware/auth.middleware.ts` (`module.exports = centralAuthOrLegacy();`) → `furtail_api/src/middleware/authModeSelector.middleware.ts` dual-mode path (lines 213-227): try Central Auth verify (`tryVerifyCentralAuthToken`, lines 40-68, HS256 against `appConfig.centralAuth.jwtSecret`/`issuer`/`audience`, no clock-tolerance leeway); on any failure, log `authModeSelector: dual mode - token verify failed` and fall through to `authenticateToken` (`furtail_api/src/middleware/authLegacy.middleware.ts:15-24`), which verifies against the **separate** local secret `appConfig.jwt.secret`.
8. **Local-user resolution (on Central Auth success only):** `tryResolveCentralAuthLocalUser` (`authModeSelector.middleware.ts:79-169`) looks up `UserCentralAuthLink` by `sub`, then by `email` via `UserAuth.findMany`, auto-links or JIT-provisions a new local `User`/`UserProfile`/`UserCentralAuthLink` if none exists. No phone-based linking path exists.
9. **Response back to Flutter:** on any failure in step 7/8, Furtail API returns `401 {"success": false, "message": "Unauthorized: invalid token"}` (flat shape, no machine-readable code, from the legacy fallthrough) — indistinguishable from a garbage/malicious token.
10. **Flutter response handling:** because `ApiClient.validateStatus` accepts all statuses, `AuthInterceptor.onError` (`furtail_app/lib/core/auth/auth_interceptor.dart:46-111`, which contains a correctly structured single-flight refresh mutex) is not triggered by this 401; instead a generic `Exception` propagates from `_handle()` (`api_client.dart:62-85`), which upstream callers (including `AuthController`) treat as a hard failure, setting `AuthStatus.bootstrapFailed` while leaving tokens in storage.
11. **Navigation:** both `AuthGate` (`furtail_app/lib/core/auth/auth_gate.dart:29-41`) and the global listener in `furtail_app/lib/main.dart:106-126` react to the state transition and independently navigate, producing the visible login redirect/bounce.
12. **Profile screen specifically:** `furtail_app/lib/features/profile/data/profile_service.dart` bypasses `ApiClient`/`AuthInterceptor` entirely via raw `package:http` with its own token helper and unconditionally-fatal 401 handling (~lines 51, 83, 127, 182: "Unauthorized. Please login again.") — no refresh attempt at all for this specific feature.

---

## 4. Confirmed root causes (verified by reading code) vs Suspected causes (plausible but unverified)

### Confirmed root causes

1. **Dual-mode auth fallthrough conflates "expired" with "invalid" and masks refresh opportunity.** `furtail_api/src/middleware/authModeSelector.middleware.ts:213-227` — any Central Auth verification failure (including plain `TokenExpiredError`) falls through to `authenticateToken` (`authLegacy.middleware.ts:15-24`), which verifies against an unrelated local secret and also fails, yielding a generic 401. No refresh signal reaches the client.
2. **`Dio` `validateStatus: (_) => true` makes `AuthInterceptor`'s refresh logic unreachable.** `furtail_app/lib/services/api_client.dart:29` combined with `_handle()` at lines 62-85 means 401/403 never becomes a `DioException`, so `AuthInterceptor.onError` (`auth_interceptor.dart:46-111`) is structurally dead code for calls through `ApiClient`.
3. **Duplicate navigation authorities cause redirect bounces.** `furtail_app/lib/core/auth/auth_gate.dart:29-41` and `furtail_app/lib/main.dart:106-126` both independently observe `AuthState` and both navigate; there is no single source of truth for "where should the user be right now."
4. **Identity-conflict handling is silently swallowed in dual mode.** `authModeSelector.middleware.ts` lines 74-77, 111, 138 — a case that the standalone `central`-mode path correctly surfaces as `409 IDENTITY_CONFLICT` is, in dual mode (the deployed default), silently discarded and falls through to legacy, again producing an undifferentiated 401.
5. **`profile_service.dart` is a fourth, uncoordinated auth pathway.** `furtail_app/lib/features/profile/data/profile_service.dart` uses raw `http` with its own token retrieval and no refresh/retry logic, unconditionally treating 401 as fatal — inconsistent with the rest of the app's (nominal) refresh design.

### Suspected/unverified causes

1. Whether `CENTRAL_AUTH_JWT_SECRET`, `CENTRAL_AUTH_ISSUER`, `CENTRAL_AUTH_AUDIENCE` in Furtail API's deployed `.env` actually match Central Auth's live `OAUTH_ISSUER`/`ACCESS_TOKEN_AUDIENCE`/`JWT_ACCESS_SECRET` — code defaults on the Furtail side are dev/localhost values (`http://localhost:5010`, empty secret), and Central Auth's default audience is `bpa-mobile`, not any Furtail-specific string. Not verified against real deployed env files (out of scope of static reading; no `.env` was located/read with confirmed production values in either repo during this audit).
2. Whether Furtail API's `CENTRAL_AUTH_JWT_SECRET` is unset (defaults to `""`), which would make **all** Central Auth verifications fail (not just expired ones) and would independently explain the repeated log line even for freshly issued tokens.
3. No `clockTolerance`/leeway is passed to `jwt.verify` in `authModeSelector.middleware.ts:46-55` — plausible contributor to intermittent "expired" symptoms under clock skew, not confirmed against actual server clocks.
4. Whether `centralAuthLocalUser.middleware.ts` and its referenced-but-missing `centralAuth.middleware.ts` counterpart are genuinely dead code, or wired in somewhere not covered by the routes read.
5. Whether `src/api/v1/middlewares/auth.ts` (dev-only `x-user-id` header stub, explicitly documented as temporary) or `src/middlewares/auth.middleware.ts` (`authGuard` one-liner assuming `req.user` is already set) are mounted anywhere in the full route tree.
6. Existence of a distinct "Pet Care" module/feature and any "vet" role — not found under `furtail_api/src/api/v1/modules/*`; may be embedded in `pets` controllers not read in full.
7. Whether `profile_service.dart`'s token helper reads the same `SecureStorageService` keys as the rest of the app (plausible but not fully verified by the investigating subagent).

---

## 5. Evidence table

| Repo | File | Function/Class | Lines | Finding |
|---|---|---|---|---|
| furtail_api | `src/middleware/authModeSelector.middleware.ts` | `tryVerifyCentralAuthToken` | 40-68 | Non-throwing Central Auth JWT verify; swallowed failures (incl. expiry) logged and returned as `{ok:false}` |
| furtail_api | `src/middleware/authModeSelector.middleware.ts` | dual-mode branch | 213-227 | On Central Auth failure, silently falls through to legacy `authenticateToken` using a different secret — confirmed root cause of reported log line and generic 401s |
| furtail_api | `src/middleware/authModeSelector.middleware.ts` | `tryResolveCentralAuthLocalUser` | 79-169 | Identity-conflict cases return `{ok:false}` silently in dual mode (lines 111, 138) instead of 409 |
| furtail_api | `src/middleware/authModeSelector.middleware.ts` | `centralAuthOrLegacy` (`mode==="central"`) | 189-211 | Correctly differentiated 401 `UNAUTHORIZED` / 409 `IDENTITY_CONFLICT` responses exist but are unreachable because deployed mode is `"dual"` |
| furtail_api | `src/middleware/authLegacy.middleware.ts` | `authenticateToken` | 15-24, 79-81 | Verifies against `appConfig.jwt.secret` (separate from Central Auth secret); catch-all returns flat `401 {"success":false,"message":"Unauthorized: invalid token"}` |
| furtail_api | `src/config/appConfig.ts` | centralAuth config | ~49-51 | `CENTRAL_AUTH_ISSUER` defaults to `http://localhost:5010`; `CENTRAL_AUTH_JWT_SECRET` defaults to `""` if unset |
| furtail_api | `src/middlewares/optionalAuth.ts` | optional-auth for public adoption GETs | full file | Verifies only legacy local JWT; no Central Auth awareness — Central-Auth-only sessions treated as anonymous on "public" adoption endpoints |
| furtail_api | `src/api/v1/modules/profile/profile.routes.ts` | route table | 1-23 | All routes gated by `auth` = `centralAuthOrLegacy()` (dual mode) |
| furtail_api | `src/middleware/admin.middleware.ts` / `src/middleware/adminMiddleware.ts` | `requireAdmin` / `adminMiddleware` | ~122-159 / full | Two divergent admin-gate implementations, both DB-driven off `req.user.id`, unaffected by auth mode (not itself a Central Auth bug, but a maintenance risk) |
| furtail_app | `lib/services/api_client.dart` | Dio instance config | 29 | `validateStatus: (_) => true` — defeats `AuthInterceptor`'s 401/403 handling |
| furtail_app | `lib/services/api_client.dart` | `_handle()` | 62-85 | Throws plain `Exception` instead of allowing `DioException` to propagate to the interceptor |
| furtail_app | `lib/core/auth/auth_interceptor.dart` | `onError` / refresh mutex | 46-111 | Correctly structured single-flight refresh logic, but unreachable for calls through `ApiClient` |
| furtail_app | `lib/core/auth/auth_gate.dart` | `AuthGate` | 29-41 | Independent widget-level navigation on `AuthState` change |
| furtail_app | `lib/main.dart` | `ref.listen<AuthState>` | 106-126 | Second, independent imperative navigation (`pushNamedAndRemoveUntil`) on the same state changes |
| furtail_app | `lib/core/auth/auth_controller.dart` | `login()` | 176-208 | Persists Central Auth tokens before Furtail profile fetch; profile-fetch failure sets `bootstrapFailed`, not `unauthenticated` — tokens retained, display-user stale |
| furtail_app | `lib/core/auth/auth_controller.dart` | `bootstrap()` | ~78 | Re-enters `unknown` status on retry, re-triggering both navigation listeners |
| furtail_app | `lib/core/auth/auth_identifier_normalizer.dart` | `_bdMobilePattern` handling | 33-95 | Correctly classifies `"01701022200"` as mobile identifier — phone login format is NOT a bug |
| furtail_app | `lib/core/services/secure_storage_service.dart` | token key constants | 15-16 | `central_access_token` / `central_refresh_token` — no save/read key mismatch found |
| furtail_app | `lib/features/profile/data/profile_service.dart` | multiple methods | ~51, 83, 127, 182 | Separate raw-`http` auth path, no refresh logic, unconditionally-fatal 401 handling — independent bug affecting Profile specifically |
| wpa_auth_api | `src/modules/auth/auth.routes.ts` | `loginSchema` | 27-31 | Single `emailOrUsername` field, no phone regex/normalization |
| wpa_auth_api | `src/modules/auth/auth.service.ts` | `loginUser()` | 187-199 | Phone matched literally (no `+880` normalization) against stored `User.phone` |
| wpa_auth_api | `src/lib/tokens.ts` | `signAccessToken` | 5-18 | HS256, payload `{sub,email,username,roles}`, no `phone`/`client_id` claim |
| wpa_auth_api | `src/config/index.ts` | token config | 21-23 | `ACCESS_TOKEN_TTL=15m` default, `ACCESS_TOKEN_AUDIENCE` default `bpa-mobile` (not Furtail-specific) |
| wpa_auth_api | `src/modules/auth/auth.service.ts` | `refreshTokens()` | 400-541 | Refresh rotates token on every call; reuse of a stale refresh token triggers full session-family revocation (`TOKEN_REVOKED`) |
| wpa_auth_api | `prisma/seed.ts` | Furtail `AuthClient` seed row | ~78 | `slug: "furtail"`; `AuthClient` model has no per-client issuer/audience/TTL override fields — all clients share global token config |
| wpa_auth_api | `src/modules/oauth/oauth.service.ts` | `getJwks()` | n/a | Non-functional JWKS stub; irrelevant anyway since access tokens are HS256/shared-secret, not RS256 |

---

## 6. Token storage and refresh-flow findings

- **Flutter storage:** Central Auth tokens stored under `central_access_token` / `central_refresh_token` in `furtail_app/lib/core/services/secure_storage_service.dart:15-16`. No mismatch found between the keys written at login and the keys read elsewhere for these two constants.
- **Flutter refresh logic exists but is unreachable in practice.** `AuthInterceptor` (`auth_interceptor.dart:46-111`) implements a single-flight refresh mutex intended to serialize concurrent 401-triggered refresh attempts. Because `ApiClient`'s `validateStatus: (_) => true` (`api_client.dart:29`) prevents Dio from ever raising a `DioException` on 401/403, this interceptor logic does not fire for the majority of API calls (Profile via `ApiClient`, Pets, Adoption, Fund Raising, Notifications, Feed). Only genuine network/timeout-level `DioException`s reach it.
- **`profile_service.dart` bypasses the shared client entirely**, using raw `package:http` with its own ad hoc token retrieval and no refresh attempt — any 401 there is treated as immediately fatal.
- **Central Auth refresh contract (server side):** `wpa_auth_api/src/modules/auth/auth.service.ts:400-541` — refresh requests are verified, looked up by hash, checked for reuse (family-wide revocation with a `SecurityEvent`/`AdminNotification` on detected reuse), and rotated on every successful call (a new refresh token is always returned). **Any client that fails to persist and use the newly rotated refresh token on its next refresh attempt will trigger reuse detection and have its entire session family revoked** — a plausible amplifier of "randomly logged out," though not confirmed to occur in the Flutter code as read.
- **Central Auth token TTLs:** access token 15 minutes (dev default, confirmed in `.env` per Central Auth investigator), refresh token 30 days (dev) / 7 days (`.env.production.example`) — short access-token life makes the Furtail-side dual-mode fallthrough bug (§4, item 1) trigger routinely during normal usage, not just as an edge case.

---

## 7. Router and redirect-loop findings

- Two independent navigation authorities exist and both react to the same `AuthState` stream:
  - `AuthGate` (`furtail_app/lib/core/auth/auth_gate.dart:29-41`) — declarative widget swap based on state.
  - A global `ref.listen<AuthState>` in `furtail_app/lib/main.dart:106-126` — imperative `pushNamedAndRemoveUntil` call on every status change.
- `AuthController.bootstrap()` (`auth_controller.dart:~78`) re-enters `AuthStatus.unknown` on each retry, which re-fires both listeners independently, and each can push its own navigation — a structural cause of redirect thrashing/loops, not merely a single bad redirect.
- A profile-fetch failure produces `AuthStatus.bootstrapFailed` (not `unauthenticated`), which is a third state that both navigation authorities must handle consistently — no evidence was found that either one treats `bootstrapFailed` differently from `unauthenticated`, meaning a merely-stale-profile condition is visually indistinguishable from "not logged in" to the user, even though valid tokens are present.

---

## 8. Furtail API middleware findings

- `authModeSelector.middleware.ts` (dual mode, the deployed default per `appConfig.ts` — `AUTH_MODE` not found overridden in files read) is mounted on essentially all protected routes via `auth.middleware.ts` (`module.exports = centralAuthOrLegacy();`).
- Central Auth verification (`tryVerifyCentralAuthToken`, lines 40-68): HS256 only, secret/issuer/audience from `appConfig.centralAuth.*`, **no clock-tolerance leeway**, no JWKS (correctly, since Central Auth issues HS256 shared-secret tokens, not RS256).
- On **any** Central Auth verification failure — expired, bad signature, wrong issuer/audience, or missing token — the code falls through to `authenticateToken` (legacy local-JWT verification against a structurally unrelated secret), which also fails, and the client receives an undifferentiated `401 {"success":false,"message":"Unauthorized: invalid token"}`.
- Identity-conflict handling (multiple/relinked email matches during local-user resolution) is correctly implemented as a `409 IDENTITY_CONFLICT` in the standalone `central`-mode path but is **silently discarded** in the deployed dual-mode path (`authModeSelector.middleware.ts` lines 74-77, 111, 138), collapsing into the same generic 401.
- No phone-based Central-Auth-to-local-user linking exists; linking is by `sub` or `email` only. A Central Auth login with no email claim always JIT-provisions a brand-new local user rather than 404ing or linking by phone — a likely source of duplicate profiles for phone-primary accounts, though not the redirect-to-login bug itself.
- `optionalAuth.ts` (guarding "public" adoption GET routes) verifies only the legacy local JWT and has no Central Auth awareness — Central-Auth-authenticated users are silently treated as anonymous on those specific endpoints (personalization gaps, not hard failures).
- Admin/staff gating (`admin.middleware.ts` / `adminMiddleware.ts`) is DB-driven off `req.user.id` and works identically regardless of auth path — no evidence this migration broke admin/staff/owner role gating specifically.
- Two admin middleware implementations exist with diverging feature sets (`requireAdmin` supports a governance-permission bypass; `adminMiddleware` does not) — a maintenance/drift risk, not directly implicated in the login-redirect bug.
- Possible dead code: `centralAuthLocalUser.middleware.ts` references a `centralAuth.middleware.ts` file that could not be located in the codebase; `src/api/v1/middlewares/auth.ts` (explicitly documented as a temporary dev stub using an `x-user-id` header) and `src/middlewares/auth.middleware.ts`'s trivial `authGuard` one-liner were not confirmed to be mounted anywhere in the routes examined — flagged as unverified rather than ruled out.

---

## 9. Central Auth contract/configuration findings

- Login endpoint accepts a single `emailOrUsername` field with no format enforcement (`wpa_auth_api/src/modules/auth/auth.routes.ts:27-31`); phone numbers are matched literally against the stored `User.phone` value with no normalization (`auth.service.ts:187-199`) — a plausible *separate* bug (login/registration format mismatch) if a user's phone was stored in a different format than what's typed at login, but distinct from, and not confirmed to be the cause of, the "expired token" symptom.
- Access tokens are HS256, signed with a single global shared secret (`JWT_ACCESS_SECRET`), with global (not per-client) `issuer`/`audience`/TTL settings (`src/config/index.ts:21-23`; `AuthClient` Prisma model has no per-client override fields). Default audience is `bpa-mobile`, **not** any Furtail-specific string.
- Furtail API's Central Auth verifier (`appConfig.centralAuth.*`) defaults, if unmodified in the deployed environment, to `CENTRAL_AUTH_ISSUER=http://localhost:5010` and `CENTRAL_AUTH_JWT_SECRET=""` — neither confirmed nor ruled out against the actual production `.env` files in either repo during this read-only audit. If either default is live in production, Central Auth token verification would fail deterministically for every request (a stronger, more constant failure mode than what's described, but cannot be excluded without inspecting the live environment).
- JWKS (`getJwks()` in `wpa_auth_api/src/modules/oauth/oauth.service.ts`) is a non-functional stub, but this is irrelevant to the reported bug since Furtail's verifier correctly uses HS256/shared-secret rather than JWKS/RS256.
- Refresh-token rotation is enforced with reuse detection that revokes the entire token family on reuse — any client-side failure to persist rotated refresh tokens would manifest as full, hard session invalidation.
- The Furtail `AuthClient` seed row (`prisma/seed.ts:~78`) exists with `slug: "furtail"`, but the seed script segment assigning the actual `clientId`/secret/scopes for that row was not located in the portion of the file read — whether the Flutter app sends a valid Furtail `clientId` (vs. omitting it and silently falling back to an internal default client) is unverified.

---

## 10. Legacy local-auth and staff-role compatibility findings

- Local/legacy JWT verification (`authLegacy.middleware.ts:15-24`) remains fully wired and is the unconditional fallback in dual mode — it is not dead code, and it actively interferes with Central Auth token handling as described in §8.
- Role/permission resolution (`attachAuthContexts`, `authUnified.service.ts:223-228`) is driven by live DB lookups keyed on the local numeric `user.id`, identically regardless of whether the request authenticated via Central Auth or legacy JWT. No evidence was found that staff/owner/admin role gating itself was broken by the Central Auth migration — the DB-driven resolution path is shared.
- No dedicated "Pet Care" module or explicit "vet" role was located under `furtail_api/src/api/v1/modules/*` — either folded into the `pets` module (not read in full) or not yet implemented as a distinct concept; unverified.
- Two divergent admin-gate implementations (`admin.middleware.ts`'s `requireAdmin` vs. `adminMiddleware.ts`'s `adminMiddleware`) are both still in active use on different route files (`admin_staff.routes.ts` vs. `fundraising.routes.ts` respectively) — a legacy-era duplication that predates or is independent of the Central Auth migration, worth consolidating but not implicated in the login-redirect bug.

---

## 11. Protected-route access matrix

| Feature | Flutter route/guard | API endpoint | Middleware | Expected role | Actual failure point | Result |
|---|---|---|---|---|---|---|
| Profile | `AuthGate`/`main.dart` listener; screen calls `profile_service.dart` (separate raw-`http` path) | `GET /me`, `GET /profile` (furtail_api) | `centralAuthOrLegacy()` (dual mode) | any authenticated user | Central Auth token expiry → dual-mode fallthrough → generic 401; `profile_service.dart` has no refresh logic and treats 401 as unconditionally fatal | Redirect to login (hard fail, no refresh attempt at all) |
| My Pets | `AuthGate`/listener; `ApiClient` (Dio, `validateStatus` override) | `GET /pets`, `GET /pets/all`, etc. | `centralAuthOrLegacy()` | any authenticated user | Same dual-mode fallthrough; `validateStatus` prevents `AuthInterceptor` refresh | Redirect to login |
| Pet Care | not located as distinct route/module | not located as distinct module | unknown | unknown | unverified — module not found | Unverified |
| Adoption | `AuthGate`/listener; `ApiClient` | Public GETs: `optionalAuth` (legacy-only, no Central Auth awareness); authenticated actions: `centralAuthOrLegacy()` | mixed | any authenticated user (write actions); anonymous-tolerant (reads) | Reads: Central-Auth-only sessions silently treated as anonymous (personalization gap). Writes: same dual-mode fallthrough as above | Reads: silent guest-fallback; Writes: redirect to login |
| Fund Raising | `AuthGate`/listener; `ApiClient` | `/fundraising/*` | `centralAuthOrLegacy()`, plus `admin`+`admin2fa`+`requireFeature`+`policyGuard` on admin/payout routes | user or admin depending on route | Same dual-mode fallthrough for user routes | Redirect to login |
| Saved Items | `AuthGate`/listener; `ApiClient` | `posts` module: `GET/POST/DELETE .../bookmark` | `centralAuthOrLegacy()` | any authenticated user | Same dual-mode fallthrough | Redirect to login |
| Notifications | `AuthGate`/listener; `ApiClient` | `notifications` module | `centralAuthOrLegacy()` (via a second import path, confirmed functionally identical) | any authenticated user | Same dual-mode fallthrough | Redirect to login |
| News Feed | `AuthGate`/listener; `ApiClient` | `posts` module: `GET /feed`, `GET /videos` | `centralAuthOrLegacy()`, no optional/public variant | any authenticated user | Same dual-mode fallthrough | Redirect to login |
| Staff-only screens | not confirmed to exist in Flutter routing | `admin_staff.routes.ts` | `centralAuthOrLegacy()` → `requireAdmin` | admin/staff | DB-driven role check, independent of auth-mode bug; not confirmed broken | Unverified — no Flutter-side staff gating located |

---

## 12. Security risks discovered

- **Undifferentiated 401 responses leak no actionable signal**, but more importantly, the dual-mode fallthrough means a client holding a *stolen or tampered* Central Auth token gets exactly the same treatment (fallthrough to legacy verification) as one holding a merely expired token — this is not itself a bypass (both still fail closed), but the inconsistency between the two "modes" of the same middleware (dual vs. central) means security posture depends on an easily-toggled config value (`AUTH_MODE`) rather than being uniform.
- **Refresh-token reuse detection exists and looks sound** (family-wide revocation, `SecurityEvent`/`AdminNotification` on detected reuse) — this is a positive finding, not a risk, but is worth flagging as something the Flutter-side bug (if it fails to persist rotated tokens) could be triggering unnecessarily and repeatedly, generating false-positive security alerts/noise.
- **JIT-provisioning of local users on any successful Central Auth login with an email claim** (`authModeSelector.middleware.ts:79-169`) auto-links to existing accounts by email match with no additional verification step (e.g., no re-confirmation that the Central Auth user actually owns that email) — if Central Auth's email verification is weaker than assumed, this is a potential account-takeover vector via email-claim collision. Not confirmed exploitable without further investigation of Central Auth's email-verification guarantees.
- **`CENTRAL_AUTH_JWT_SECRET` defaulting to an empty string** if unset (`furtail_api/src/config/appConfig.ts`) is a significant risk if actually deployed unset — depending on how the underlying JWT library treats an empty HMAC secret, this could range from "always fails closed" (denial of service, matching current symptoms) to a weaker signing scenario. Verifying the deployed environment variable is genuinely set to a strong, correct value should be treated as urgent regardless of the login-redirect investigation.
- **A documented dev-only stub** (`src/api/v1/middlewares/auth.ts`, `x-user-id` header-based "TEMP auth middleware") still exists in the codebase; if ever accidentally wired into a route, it would allow trivial authentication bypass via a client-supplied header. Not confirmed to be mounted anywhere, but its presence in a production-adjacent codebase is itself a risk.

---

## 13. Prioritized repair plan

**Critical**
- Fix `authModeSelector.middleware.ts` dual-mode logic so an expired-but-otherwise-valid Central Auth token returns a distinct, refreshable error (e.g., a specific `401 CENTRAL_TOKEN_EXPIRED` code) instead of silently falling through to legacy verification against an unrelated secret.
- Remove or correct `validateStatus: (_) => true` in `furtail_app/lib/services/api_client.dart` so 401/403 responses reach `AuthInterceptor` and its refresh-mutex logic actually executes.
- Confirm (in the real deployed environment, not code defaults) that `CENTRAL_AUTH_JWT_SECRET`, `CENTRAL_AUTH_ISSUER`, and `CENTRAL_AUTH_AUDIENCE` on the Furtail API side exactly match Central Auth's live `JWT_ACCESS_SECRET`, `OAUTH_ISSUER`, and `ACCESS_TOKEN_AUDIENCE`.

**High**
- Collapse the two independent navigation authorities (`AuthGate` and the `main.dart` global listener) into a single source of truth for auth-driven routing to eliminate redirect bounces/loops.
- Migrate `profile_service.dart` off raw `package:http` onto the shared `ApiClient`/`AuthInterceptor` path (once Critical item 2 above is fixed) so Profile gets the same refresh handling as other features.
- Surface the `409 IDENTITY_CONFLICT` case in dual mode instead of silently discarding it in `tryResolveCentralAuthLocalUser`.

**Medium**
- Add Central Auth awareness to `optionalAuth.ts` so Central-Auth-authenticated users get personalized (favorited-status, etc.) results on "public" adoption endpoints instead of being silently treated as anonymous.
- Add clock-tolerance/leeway to `jwt.verify` calls in `authModeSelector.middleware.ts` to reduce false "expired" results from minor clock skew.
- Verify and, if needed, remove dead/duplicate code paths: `centralAuthLocalUser.middleware.ts` + missing `centralAuth.middleware.ts`, `src/api/v1/middlewares/auth.ts` dev stub, `src/middlewares/auth.middleware.ts`'s trivial `authGuard`.
- Consolidate the two divergent admin middleware implementations (`admin.middleware.ts` vs. `adminMiddleware.ts`).

**Low**
- Normalize phone-number storage/matching in Central Auth (`auth.service.ts:187-199`) to avoid future login/registration format-mismatch issues.
- Add phone-based Central-Auth-to-local-user linking in Furtail API to avoid duplicate profile creation for phone-primary accounts.
- Confirm/replace the `AuthStatus.bootstrapFailed` UX so a stale-profile condition (valid tokens, failed profile hydration) is visually distinguishable from a true "not logged in" state, addressing the "Guest with an email" symptom directly.

---

## 14. Exact files expected to require changes (list only — not modified)

- `furtail_api/src/middleware/authModeSelector.middleware.ts`
- `furtail_api/src/middleware/authLegacy.middleware.ts`
- `furtail_api/src/middleware/centralAuthLocalUser.middleware.ts` (or removal, pending dead-code confirmation)
- `furtail_api/src/middlewares/optionalAuth.ts`
- `furtail_api/src/config/appConfig.ts` (config/env verification, not necessarily code change)
- `furtail_app/lib/services/api_client.dart`
- `furtail_app/lib/core/auth/auth_interceptor.dart`
- `furtail_app/lib/core/auth/auth_gate.dart`
- `furtail_app/lib/main.dart`
- `furtail_app/lib/core/auth/auth_controller.dart`
- `furtail_app/lib/features/profile/data/profile_service.dart`
- `wpa_auth_api/src/modules/auth/auth.service.ts` (phone normalization, low priority)
- `wpa_auth_api/.env` / `furtail_api/.env` (configuration verification, not code)

---

## 15. Verification checklist for the later fix phase

- [ ] Confirm live `CENTRAL_AUTH_JWT_SECRET`/`CENTRAL_AUTH_ISSUER`/`CENTRAL_AUTH_AUDIENCE` in Furtail API's deployed environment match Central Auth's live signing secret/issuer/audience exactly.
- [ ] Issue a token, let it expire naturally (or force-expire in a test environment), and confirm Furtail API returns a distinct, documented error code rather than falling through to legacy verification.
- [ ] Confirm the Flutter `AuthInterceptor` refresh mutex actually fires on a real 401 once `validateStatus` is corrected — verify via a deliberately expired token in a controlled test.
- [ ] Confirm only one navigation authority acts on `AuthState` changes; test that reaching a protected screen and having a background token refresh does not bounce the user to login.
- [ ] Re-test Profile access specifically once `profile_service.dart` is migrated to the shared client; confirm 401 triggers a refresh attempt rather than immediate failure.
- [ ] Confirm identity-conflict scenarios (two local accounts sharing an email under different Central Auth subjects) produce a clear, actionable error rather than a silent fallthrough.
- [ ] Confirm phone-login users are not duplicated as new profiles on first Central Auth login.
- [ ] Re-run `flutter analyze`, Furtail API `npm run typecheck`, and Central Auth API `npx tsc --noEmit` after any code changes to confirm no regressions.
- [ ] Load-test/soak-test session longevity across the 15-minute access-token TTL boundary to confirm silent, transparent refresh with no visible login bounce.

---

## 16. Commands/tests executed and their real results

- `flutter analyze` — run in `D:\wpa\furtail\furtail_app` by the Flutter-investigation subagent. Result: clean compile, 135 issues reported, all lint/style-level info/warnings; zero compile errors; nothing auth-specific surfaced by the analyzer itself.
- `npm run typecheck` (`tsc -p tsconfig.json --noEmit`) — run in `D:\wpa\furtail\furtail_api` by the Furtail-API-investigation subagent. Result: clean, no output, exit success, no compile errors.
- `npx tsc --noEmit` — run in `D:\wpa\wpa_auth\wpa_auth_api` by the Central-Auth-investigation subagent. Result: clean, no output, exit success, no compile errors.
- Full-file reads of `authModeSelector.middleware.ts`, `authLegacy.middleware.ts`, `centralAuthLocalUser.middleware.ts`, `optionalAuth.ts`, `tokens.ts`, `auth.service.ts` (login/refresh), `auth.routes.ts`, `auth_interceptor.dart`, `auth_gate.dart`, `auth_identifier_normalizer.dart`, `secure_storage_service.dart`, and route files for profile/pets/adoptions/fundraising/posts/notifications/admin_staff — performed via Grep/Glob/Read by the three research subagents; not re-verified line-by-line by the synthesizing agent beyond cross-checking consistency across the three independent reports.
- Live deployed `.env` files for `furtail_api` and `wpa_auth_api` — **not read**; production/staging secret and issuer values were not confirmed. This is explicitly noted as unverified throughout the report rather than assumed.
- No database queries were run against any environment (would violate read-only/no-data-access constraints beyond source review).
- No JWTs from live logs were decoded during this audit — no log files were made available to the investigating agents; all findings are derived from source code reading only. Where the report references "expired Central Auth JWT" and the `authModeSelector: dual mode - token verify failed` log line, these are taken from the task's stated background/symptoms, not independently reproduced or decoded in this session.

---

## 17. Open questions or blockers

1. Are the deployed `.env` values for `CENTRAL_AUTH_JWT_SECRET`/`CENTRAL_AUTH_ISSUER`/`CENTRAL_AUTH_AUDIENCE` (Furtail API) and `JWT_ACCESS_SECRET`/`OAUTH_ISSUER`/`ACCESS_TOKEN_AUDIENCE` (Central Auth API) actually matched, or are one or both sides running on unmodified dev/localhost defaults? This could not be verified from source alone and is the single most consequential unknown.
2. What is `AUTH_MODE` actually set to in the deployed Furtail API environment? All analysis assumes `"dual"` (the code default), but this was not confirmed against a live config file.
3. Does the Flutter app ever call Central Auth's `/auth/refresh` directly, or does it rely on Furtail API to broker refreshes? The audit found Flutter-side token storage and a refresh-interceptor scaffold, but did not fully trace whether refresh requests go to Central Auth or a Furtail-side proxy — this affects whether the reuse-detection/rotation contract (§9) is actually exercised correctly by the app.
4. Is there a genuinely distinct "Pet Care" feature/module and a "vet" role anywhere in the system, or is this terminology from the task background not yet implemented? Not located in the files read.
5. Is `profile_service.dart`'s token retrieval reading the same secure-storage keys as the rest of the app, or a stale/different key — this determines whether Profile's failures are purely "no refresh logic" or also "reading a token that was never correctly populated for this code path."
6. Does the Furtail `AuthClient` row in Central Auth (`slug: "furtail"`) have a correctly configured `clientId` that the Flutter app actually sends on login, or does login silently fall back to an internal default client (as the Central Auth investigator flagged as a possible silent-misconfiguration path)? The relevant seed-script section assigning `clientId`/secret was not located in this pass.
7. No access was available in this session to production logs beyond what was already summarized in the task description — direct confirmation of the exact sequence of log lines around a real failed request (timestamps, correlated request IDs) was not possible and would materially strengthen confidence in the root-cause ordering described in §2/§3.
