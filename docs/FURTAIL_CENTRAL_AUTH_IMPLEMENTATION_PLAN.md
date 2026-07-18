# Furtail — Centralized Authentication Implementation Plan

Status: **Audit + Plan only. No implementation performed.**
Scope: `bpa_user_app` (reference), `furtail_app`, `wpa_auth_api` (Central Auth), `furtail_api`.

---

## 1. Current Architecture

### 1.1 WPA Central Auth API (`D:\wpa\wpa_auth\wpa_auth_api`)
Express + Prisma (Postgres), mounted at `/api/v1`. Already serves BPA User App as its primary client.

- Routes: `auth.routes.ts` — register, login, refresh, logout, me, sessions, change-password, deactivate/delete, forgot/reset-password (email only), verify-email, admin-invitations, presence.
- Social sub-router `auth/social.routes.ts`: `GET /social/providers` (public), `GET /social/:provider/start`, `GET /social/:provider/callback`, `complete-email/request|confirm`. Providers with adapters: Google, Facebook, Apple, Microsoft (inline/generic), LinkedIn, TikTok, X, GitHub, Instagram (dedicated adapter files).
- OAuth2/OIDC surface: `oauth.routes.ts` (authorize/token/userinfo/jwks/revoke/introspect) + `/.well-known/openid-configuration`.
- Prisma models: `User`, `AuthClient` (client/app registry: clientId, type FIRST_PARTY_APP/THIRD_PARTY_APP/SERVICE, redirectUris, allowedOrigins, allowedScopes), `SocialIdentityProviderConfig` (**global singleton per provider**, no per-client scoping), `UserClientAccess`, `RefreshToken` (rotation/reuse detection), `LoginSession`, `OAuthAccount` (account-linking table, unique on provider+providerAccountId), `PasswordResetToken`, `EmailVerificationToken`, `OidcSigningKey`, communication/OTP scaffolding (`CommunicationProvider`, `CommunicationRoutingRule.appId`, `OtpTemplate`) with a `CommunicationChannel` enum containing only `SMS`/`EMAIL` (no `WHATSAPP`).
- JWT: HS256, `JWT_ACCESS_SECRET`/`JWT_REFRESH_SECRET`, access TTL 15m, refresh TTL 30d, **`aud` is a single hardcoded global string (`ACCESS_TOKEN_AUDIENCE`, default `'bpa-mobile'`)** — not per-client. `id_token` supports RS256 if RSA keys configured, else falls back to HS256 with a dev-only warning.
- `authGuard` middleware (`middleware/auth.ts`) verifies in-process using the shared HS256 secret; no remote introspection is required today (introspection endpoint exists via OIDC but isn't the primary path).
- **Known defects relevant to Furtail onboarding:**
  - Social-login sessions hardcode `clientId: 'social'` in `social.service.ts` (loginOrLink call) instead of the real requesting `AuthClient` — breaks per-app attribution.
  - No per-client audience minting — one global audience for all apps.
  - No per-app enable/disable for social providers (unlike `CommunicationRoutingRule`/`EmailTemplate`/`ClientBranding`, which already support per-`appId` overrides).
  - No phone/WhatsApp OTP send/verify flow, no `WHATSAPP` channel enum value, no dedicated adapter (only a generic HTTP SMS adapter).
  - No magic-link login route.
  - No explicit "link additional provider to an already-authenticated account" endpoint (linking is only inferred opportunistically at login by verified email).
  - Legacy `clients.routes.ts` / `clientValidation.ts` exist but are explicitly unmounted/marked insecure — must not be reused as-is.
  - No Furtail-specific `AuthClient` row is confirmed to exist at runtime (only referenced in doc/seed history, not verified against a live DB).

### 1.2 BPA User App (`D:\bpa_main\bpa_user_app`) — reference client
Flutter + Riverpod. Fully consumes Central Auth as the single identity source:
- `login_screen.dart` / `register_screen.dart` / `forgot_password_screen.dart` / `verify_reset_token_screen.dart` / `reset_password_screen.dart`.
- Social login is **entirely server-driven**: `GET auth/social/providers` returns `{provider, displayName, icon, startUrl}`; the app never hardcodes a provider list or embeds SDKs (no `google_sign_in`, `flutter_facebook_auth`, `sign_in_with_apple`, MSAL). OAuth is launched via `flutter_web_auth_2` (system browser / Custom Tabs / SFSafariViewController — **not embedded WebView**), result posted to `auth/social/callback`.
- `flutter_appauth` is present in `pubspec.yaml` but unused — dead dependency, not part of the working flow.
- Token storage: `flutter_secure_storage`, only `access_token`/`refresh_token` (no id token, no profile data cached).
- `dio_factory.dart` + `auth_interceptor.dart`: bearer-token attach on every request, mutex-guarded single-flight refresh on 401, retry-once with fresh Dio instance, hard logout (`forceLogout`) on unrecoverable refresh failure.
- No OTP (email/SMS/WhatsApp), no magic link, no Microsoft/enterprise SSO actually implemented (icon mapping only) — these are backend capabilities not yet built even for BPA.
- No `client_id`/`audience` parameter sent by the app on any call today (single global audience, consistent with the Central Auth gap above).

### 1.3 Furtail App (`D:\wpa\furtail\furtail_app`) — mid-migration
Already substantially migrated to Central Auth, not on pure legacy auth:
- `core/auth/central_auth_api.dart` calls Central Auth directly for login/register/refresh/logout/forgot-reset-password — own bespoke Dio client (deliberately separate from the interceptor-equipped app client to avoid refresh circularity).
- `core/auth/auth_controller.dart`: Riverpod StateNotifier, login → save Central Auth tokens → call Furtail `/auth/me` to JIT-resolve/create local profile (`FurtailProfileException` on that step's failure, distinct from login failure).
- `secure_storage_service.dart`: stores **only** `central_access_token`/`central_refresh_token` — a regression test (`no_legacy_token_key_test.dart`) actively guards against reintroducing a legacy SharedPreferences token key.
- `auth_interceptor.dart`: bearer attach, mutex-guarded refresh keyed off error code `CENTRAL_TOKEN_EXPIRED`, retry-once, `forceLogout` on failure — same pattern as BPA.
- **No social login UI wired at all** (no packages in `pubspec.yaml`; `README_SETUP.md` describing Google/Facebook social buttons is stale/aspirational and doesn't match shipped code).
- **No OTP, no magic link, no WhatsApp** anywhere in the app.
- No `client_id`/`clientId` sent in any Central Auth request body today.
- Two overlapping config classes (`core/network/api_config.dart` `ApiConfig` and `core/config/app_config.dart` `AppConfig`) both expose the Furtail API base URL — duplication to consolidate.
- Central Auth base URL is not defined in any `env/*.json` file (including `prod.json`) — currently only overridable via ad-hoc `--dart-define`.
- No `ResetPasswordScreen` UI was found — only the controller/API method exists; the reset-link landing screen appears missing or unbuilt.

### 1.4 Furtail API (`D:\wpa\furtail\furtail_api`) — mid-migration, dual-mode
Express + Prisma. This is the most architecturally advanced of the four in terms of Central Auth groundwork, but it **still issues its own tokens**:
- `authModeSelector.middleware.ts` implements a working `AUTH_MODE=central|legacy|dual` selector (default `dual`): tries Central Auth HS256 verification first, JIT-provisions/auto-links the local user by `sub` (falls back to matching by verified email), only falls through to legacy JWT verification on `NO_TOKEN`/`NOT_CONFIGURED` (expired/invalid Central tokens and identity conflicts correctly do **not** silently fall through).
- Prisma already has `UserCentralAuthLink` (`userId` unique, `subject` unique, `linkMethod`) — exactly the "local profile keyed by Central Auth subject" table the target architecture requires. `UserProfile` is the app-profile model to retain.
- **However**, `auth.routes.ts` still has live routes that mint Furtail's own 7-day HS256 JWTs: `POST /register`, `POST /login`, `POST /oauth/google`, `POST /oauth/facebook` (Apple/Twitter are 501 stubs), `POST /staff/login`, and three invite-accept flows — six call sites in `auth.controller.ts` + `oauthLogin.service.ts::issueSession`. No refresh endpoint exists for these local tokens; they're just long-lived.
- `UserAuth` (password hash, phone/email, its own `oauthSubject`+`provider` for Furtail-local social login) and `UserSession` (a refresh-token-hash table that's scaffolded but **unused** by any controller) are the legacy local-credential stores to retire.
- Verification today is **shared-secret HS256** (`CENTRAL_AUTH_JWT_SECRET` shared with Central Auth), not JWKS/RS256 — no JWKS fetch/rotation logic exists client-side.
- Local user resolution/JIT-provisioning/auto-linking logic is duplicated across three files (`centralAuthLocalUser.middleware.ts`, `authModeSelector.middleware.ts`, `optionalAuth.ts`) — needs consolidation.
- Dead/unsafe code found: `src/middlewares/auth.middleware.ts` is an empty file; `src/api/v1/middlewares/auth.ts` (`requireUser`) trusts an `x-user-id` header with **no verification** — must be confirmed unused in production and removed.
- `.env.example` already has `CENTRAL_AUTH_CLIENT_ID=furtail-mobile` and `CENTRAL_AUTH_AUDIENCE=bpa-mobile` — note the **audience is currently set to BPA's audience**, confirming Furtail is piggybacking on BPA's single global audience rather than having its own.

---

## 2. Target Architecture

```
                        ┌─────────────────────────────┐
                        │   WPA Central Auth API      │
                        │  (single source of identity  │
                        │   + sessions, all apps)      │
                        │                              │
                        │  AuthClient(furtail-mobile)  │
                        │  audience=furtail-mobile     │
                        │  Social providers, OTP        │
                        │  (email + WhatsApp/SMS),      │
                        │  password, sessions, JWKS     │
                        └───────────┬──────────────────┘
                                    │ issues access+refresh JWT
                                    │ (aud=furtail-mobile, sub=<central-user-id>)
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
   ┌──────────▼─────────┐ ┌─────────▼──────────┐ ┌────────▼─────────┐
   │  Furtail Flutter    │ │   Furtail API        │ │   BPA app /       │
   │  app                │ │ (validates token,    │ │   other clients   │
   │  - never stores a   │ │  never issues one;   │ │   (unaffected)    │
   │    local/legacy      │ │  local profile keyed │ │                   │
   │    token             │ │  by centralAuthLink)  │ │                   │
   └──────────────────────┘ └──────────────────────┘ └───────────────────┘
```

Rules enforced by design:
1. Furtail API deletes all local JWT issuance; `authModeSelector` collapses to `AUTH_MODE=central` only (legacy path removed after migration window).
2. Furtail Flutter never introduces a second token key; `secure_storage_service.dart` stays the sole holder of the Central Auth token pair (already true today — preserve, don't regress).
3. Central Auth remains the only issuer/verifier of sessions; Furtail API's `UserCentralAuthLink` is a read-side profile join, not an identity store.
4. `UserProfile` (Furtail) is retained and extended; `UserAuth`/`UserSession` are deprecated and eventually dropped.
5. Social identities link to one Central Auth `User` via `OAuthAccount`; Furtail never creates a duplicate identity per provider.
6. Client secrets (Google/Facebook/Apple/Microsoft/WhatsApp-BSP) live only in Central Auth's `SocialIdentityProviderConfig`/communication-credential tables, never in the Furtail app or Furtail API.
7. OAuth uses `flutter_web_auth_2` (system browser), matching BPA — no embedded WebView.
8. WhatsApp is implemented as an **OTP delivery channel** (alongside SMS/email), not as an OAuth-style social provider — see §8.

---

## 3. BPA-to-Furtail Feature Comparison Matrix

| Capability | BPA app (reference) | Furtail app (current) | Central Auth API (current) | Furtail API (current) | Gap to close |
|---|---|---|---|---|---|
| Email/username + password login | ✅ `login_screen.dart` → Central Auth | ✅ same pattern already wired | ✅ `/auth/login` | Delegates via dual-mode | None — reuse as-is |
| Registration | ✅ | ✅ | ✅ `/auth/register` | Delegates | None |
| Forgot/reset password | ✅ 3-screen flow | ⚠️ controller+API present, **no ResetPasswordScreen UI** | ✅ email-only | N/A | Build missing UI screen |
| Token storage (no legacy token) | ✅ secure storage, 2 keys | ✅ same, actively tested | — | ⚠️ `UserSession`/`UserAuth` still exist | Retire local stores |
| Dio 401 refresh interceptor | ✅ | ✅ equivalent, arguably more precise (`CENTRAL_TOKEN_EXPIRED` code match) | ✅ `/auth/refresh` | N/A | None — keep Furtail's version |
| Logout/session invalidation | ✅ | ✅ | ✅ `/auth/logout`, `/auth/sessions/*` | ⚠️ local `/logout` only clears cookie, no revocation | Remove local logout route; delegate to Central Auth |
| Google login | ⚠️ generic (server-driven, no SDK) | ❌ not wired | ✅ adapter present | ⚠️ owns local Google OAuth, issues own JWT | Migrate: remove Furtail-local Google OAuth; add server-driven button in app |
| Facebook login | ⚠️ generic | ❌ not wired | ✅ adapter present | ⚠️ owns local Facebook OAuth, issues own JWT | Same as Google |
| Apple login | ⚠️ generic (icon only, no real flow confirmed working) | ❌ not wired | ⚠️ inline/generic handling, unclear real coverage | ❌ 501 stub | Verify/build in Central Auth; wire generically in app |
| Microsoft/enterprise login | ❌ not implemented (icon only) | ❌ | ⚠️ inline/generic handling only | ❌ | New work in Central Auth; low priority unless a customer requires org SSO |
| Email OTP / magic link | ❌ none | ❌ none | ❌ none | ⚠️ scaffolding only (`authOtp.service.ts`, unwired) | New capability, build in Central Auth first |
| WhatsApp/phone OTP | ❌ none | ❌ none | ⚠️ generic SMS adapter, no WhatsApp channel, no OTP route | ⚠️ scaffolding only, unwired | New capability — implement as OTP channel (§8) |
| Provider enable/disable | ✅ server-driven (`/auth/social/providers`) | N/A (no social UI yet) | ⚠️ global per-provider only, no per-`AuthClient` scoping | N/A | Add per-client provider scoping to Central Auth |
| Account linking (social→user) | Implicit via Central Auth | N/A | ⚠️ opportunistic-at-login only, no explicit "link to my account" endpoint | N/A | Build explicit linking endpoint (nice-to-have, not blocking) |
| `client_id`/audience distinction | ❌ none sent by app; ⚠️ single global audience server-side | ❌ none sent; ⚠️ same global audience bug | ⚠️ `AuthClient` model exists but not used for JWT `aud` or social sessions | ⚠️ `.env` sets audience = BPA's audience | **Primary architectural fix required** (§9) |

---

## 4. Exact Reusable BPA Files/Components

Copy the *pattern*, adapt package names/branding — these are the direct templates for Furtail:

- `D:\bpa_main\bpa_user_app\lib\services\api\dio_factory.dart` → mirror as Furtail's shared Dio factory (Furtail already has an equivalent in `api_client.dart`; align retry/redaction/error-mapping logic).
- `D:\bpa_main\bpa_user_app\lib\services\api\auth_interceptor.dart` → Furtail's `auth_interceptor.dart` is already very close; no rewrite needed, only extend for any new endpoints.
- `D:\bpa_main\bpa_user_app\lib\services\storage\secure_storage_service.dart` → Furtail's equivalent already matches this pattern; keep as-is.
- `D:\bpa_main\bpa_user_app\lib\models\social_provider_model.dart` → **new file needed in Furtail**, port directly (flexible parse of `provider/name/key`, `isEnabled && isVisible` filter).
- `D:\bpa_main\bpa_user_app\lib\features\auth\social_login_providers.dart` (Riverpod `FutureProvider.autoDispose` wrapping `GET auth/social/providers`) → **new file needed in Furtail**, port directly, repoint at Furtail's own Central Auth client instance.
- `D:\bpa_main\bpa_user_app\lib\features\auth\widgets\social_login_grid.dart` (`_open()` using `FlutterWebAuth2.authenticate`, posting callback params to `auth/social/callback`) → **new file needed in Furtail**, port directly, restyle with Furtail branding (colors/icons container, not the OAuth mechanics).
- `D:\bpa_main\bpa_user_app\lib\features\auth\forgot_password_screen.dart`, `verify_reset_token_screen.dart`, `reset_password_screen.dart` → Furtail has 1 of 3; port the missing `reset_password_screen.dart` (and arguably `verify_reset_token_screen.dart`'s resend-cooldown UX) directly, restyle only.
- Android manifest callback-activity registration (`AndroidManifest.xml` lines 61–68, `flutter_web_auth_2` `CallbackActivity` intent-filter with `${appAuthRedirectScheme}`) → mirror in Furtail's `android/app/src/main/AndroidManifest.xml` with a Furtail-specific redirect scheme.
- **Do not port**: `flutter_appauth` dependency (confirmed dead/unused in BPA) — skip entirely.

---

## 5. Exact Furtail Files Requiring Modification

Flutter app (`D:\wpa\furtail\furtail_app`):
- `lib\core\auth\central_auth_api.dart` — add `fetchSocialProviders()`, `verifySocialCallback()`, and (once built) OTP send/verify + client_id param on all requests.
- `lib\core\auth\auth_controller.dart` — add `socialLogin()` method mirroring BPA's; add OTP login state handling.
- `lib\core\config\central_auth_config.dart` — add `clientId` constant (`furtail-mobile`, matching the value already reserved in `.env.example`/Furtail API config) and thread it into every Central Auth request body/header.
- `lib\core\network\api_config.dart` and `lib\core\config\app_config.dart` — consolidate into a single config class (currently duplicated); low-risk cleanup, do during this migration since both will need the new Central Auth fields anyway.
- `env\dev.json`, `env\emulator-dev.json`, `env\mobile-dev.json`, `env\phone-dev.json`, `env\prod.json` — add `CENTRAL_AUTH_API_BASE_URL` to all five (currently missing everywhere, including `prod.json`).
- `lib\features\auth\presentation\screens\login_screen.dart` — add `SocialAuthSection`-equivalent widget below the password form.
- `lib\features\auth\presentation\screens\` — new `reset_password_screen.dart` (missing today), optionally a `verify_reset_token_screen.dart` if resend-cooldown UX is wanted.
- New files: `lib\features\auth\social_login_providers.dart`, `lib\features\auth\widgets\social_login_grid.dart`, `lib\models\social_provider_model.dart` (ported from BPA per §4).
- `android\app\src\main\AndroidManifest.xml` — register `flutter_web_auth_2` callback activity + Furtail redirect scheme; add `pubspec.yaml` dependency `flutter_web_auth_2`.
- `test\core\auth\no_legacy_token_key_test.dart` — keep as a permanent regression guard; do not weaken during migration.

---

## 6. Exact Central Auth Files Requiring Modification

`D:\wpa\wpa_auth\wpa_auth_api`:
- `prisma\schema.prisma` — see §7 for exact model changes (per-client provider scoping, `WHATSAPP` channel, OTP models).
- `src\modules\auth\social.service.ts` — fix hardcoded `clientId: 'social'` in the `loginOrLink(...)` call (line ~285) to thread the real `AuthClient` from the request (via `clientId` query param on `/social/:provider/start` or a signed state parameter carried through the callback).
- `src\modules\auth\social.routes.ts` — accept/require `clientId` on `GET /social/:provider/start`; validate against `AuthClient`.
- `src\lib\tokens.ts` — replace the single global `config.ACCESS_TOKEN_AUDIENCE` with a per-client audience lookup (`getAudienceForClient(clientId)` sourced from `AuthClient.clientId`, e.g. `furtail-mobile`, `bpa-mobile`), applied in `signAccessToken`/`signRefreshToken`.
- `src\config\index.ts` — remove/repurpose the single hardcoded `ACCESS_TOKEN_AUDIENCE` default; make it a fallback only, not the production value.
- `src\modules\admin\admin.routes.ts` / `admin.service.ts` — add admin CRUD or a seed migration to create the Furtail `AuthClient` row (`clientId=furtail-mobile`, `type=FIRST_PARTY_APP`, real `redirectUris`/`allowedOrigins`).
- `src\modules\auth\auth.routes.ts` + a new `otp.service.ts` — add `POST /auth/otp/send`, `POST /auth/otp/verify` (email + WhatsApp/SMS channel parameter), reusing `OtpTemplate`/`CommunicationDeliveryLog`.
- `src\modules\communication\communication.adapters.ts` — add a WhatsApp Business API adapter class alongside `GenericHttpSmsAdapter` (see §8).
- New: per-client social-provider enablement — either a new join table (`AuthClientSocialProvider`) or a nullable `appId` column on `SocialIdentityProviderConfig`, mirroring the existing `CommunicationRoutingRule.appId` pattern.
- `src\middleware\clientValidation.ts` — do **not** revive as-is (documented legacy/insecure); if client-secret validation is needed for server-to-server calls, write a fresh, reviewed middleware instead.

---

## 7. Furtail API Middleware Changes

`D:\wpa\furtail\furtail_api`:
- `src\config\appConfig.ts` — flip default `AUTH_MODE` from `dual` to `central` once BPA-parity features ship and legacy traffic is confirmed drained (see §12 migration plan); fix `CENTRAL_AUTH_AUDIENCE` env value from `bpa-mobile` to `furtail-mobile` once Central Auth's per-client audience change (§6) ships.
- `src\api\v1\modules\auth\auth.controller.ts` — **remove** local JWT issuance at lines ~251 (`register`), ~356 (`login`), ~1479 (`staffLogin`), and the three invite-accept flows (~1146/1201/1302); these become thin proxies to Central Auth or are retired if Central Auth already covers the flow (invite-accept may need a Central-Auth-side "accept invite and create/link user" endpoint — flag for design review).
- `src\api\v1\services\oauthLogin.service.ts` — remove `issueSession()` (local JWT mint) entirely; Google/Facebook login moves fully to Central Auth's social flow.
- `src\api\v1\modules\auth\oauth.controller.ts`, `src\api\v1\providers\oauth\google.provider.ts`, `facebook.provider.ts` — retire once Central Auth owns social login; keep only if a transitional dual-write is needed during migration window (see §12).
- `src\middleware\authModeSelector.middleware.ts` — remove the `legacy` branch and the `dual` fallback path once migration completes; collapse to Central-Auth-only verification.
- `src\middleware\authLegacy.middleware.ts` — delete once no route depends on `AUTH_MODE=legacy`/`dual` fallback.
- `src\middleware\centralAuthLocalUser.middleware.ts`, `authModeSelector.middleware.ts`'s `tryResolveCentralAuthLocalUser`, `src\middlewares\optionalAuth.ts`'s `resolveCentralAuthUser` — **consolidate the three duplicated JIT-provisioning/auto-link implementations into one shared function** (e.g. `src\lib\centralAuthUserResolver.ts`), imported by all three call sites.
- `src\middlewares\auth.middleware.ts` — delete (empty file, dangling).
- `src\api\v1\middlewares\auth.ts` (`requireUser`, trusts `x-user-id` header) — confirm zero production route dependencies, then delete; this is a live security hole if anything still references it.
- `src\api\v1\modules\auth\auth.routes.ts::POST /logout` — replace cookie-clear-only logic with a call to Central Auth's `/auth/logout` (revoke server-side), then clear the local cookie.
- `src\middleware\centralAuth.middleware.ts` — if Central Auth moves to RS256/JWKS (recommended, see §9), replace shared-secret HS256 verification with JWKS-based verification (fetch + cache `/api/v1/.well-known/openid-configuration` → `jwks_uri`).

---

## 8. Provider-by-Provider Implementation Plan

| Provider | Mechanism | Central Auth work | Furtail app work | Notes |
|---|---|---|---|---|
| Email + password | Existing | None — already correct | Reuse existing screens | No change |
| Google | OAuth2 (system browser via Central Auth `/social/start`→`/social/callback`) | Fix `clientId` attribution (§6); confirm adapter production-ready | Add server-driven social button (port BPA's `social_login_grid.dart`) | Provider secrets stay server-side already |
| Facebook | OAuth2, same pattern | Same as Google | Same as Google | Same |
| Apple | OAuth2, same pattern; must support "Sign in with Apple" native button requirement on iOS per App Store review guidelines | Verify/complete Apple adapter (`complete-email/request` handles Apple's private-relay/no-email case) | Add button; may need `sign_in_with_apple` package on iOS specifically for the native button requirement even though the OAuth exchange itself goes through Central Auth's system-browser flow — confirm against current App Store guidance before implementation | Apple review requires the native "Sign in with Apple" affordance when other social logins are offered on iOS; decide during phase design whether BPA's generic-button approach already satisfies this |
| Microsoft/enterprise org SSO | OAuth2 / potentially Azure AD multi-tenant | New work — only build if a customer/contract requires it | Icon/button already stylable via existing generic grid | Treat as backlog, not required for MVP parity |
| Email OTP (passwordless) | New: `OtpTemplate` + email delivery + `POST /auth/otp/send|verify` | Build in Central Auth first (shared by all clients) | Add OTP entry UI once Central Auth ships it | Not currently used by BPA either — new capability for the whole platform |
| WhatsApp / phone OTP | **OTP delivery channel, not an OAuth provider** (per architecture rule #8) | Add `WHATSAPP` to `CommunicationChannel` enum; build a WhatsApp Business API (or Twilio WhatsApp) adapter alongside `GenericHttpSmsAdapter`; wire `POST /auth/otp/send{channel: whatsapp}` / `/verify` | Add "Login with WhatsApp OTP" as a phone-number + code entry flow (not a button that opens WhatsApp OAuth) | Confirm with product whether WhatsApp Business API access/BSP account already exists before committing to a delivery vendor |

---

## 9. Required Prisma/Database Changes

**Central Auth (`wpa_auth_api/prisma/schema.prisma`):**
1. Ensure/verify an `AuthClient` row exists for Furtail (`clientId=furtail-mobile`, `type=FIRST_PARTY_APP`) — via admin API or a reviewed seed, not the unmounted legacy `clients.routes.ts`.
2. Add per-client social-provider scoping: either a nullable `appId String?` FK on `SocialIdentityProviderConfig` (simplest, matches `CommunicationRoutingRule` precedent) or a new `AuthClientSocialProvider(clientId, provider, enabled)` join table (needed if a provider must be enabled for one app but disabled for another simultaneously — join table is more correct long-term).
3. Add `WHATSAPP` to `CommunicationChannel` enum.
4. Add an OTP verification-attempt model if one doesn't already fit `OtpTemplate`/`CommunicationDeliveryLog` (e.g. `OtpChallenge { id, userId?, destination, channel, codeHash, expiresAt, attempts, consumedAt }`) — needed for both email-OTP and WhatsApp/SMS-OTP.
5. Migration to backfill `AuthClient.id` into any existing `RefreshToken`/`LoginSession`/`OAuthAccount` rows currently attributed to the fake `'social'` clientId (data-cleanup migration, run once the code fix in §6 ships).

**Furtail API (`furtail_api/prisma/schema.prisma`):**
1. No new tables required — `UserCentralAuthLink` and `UserProfile` already fit the target model.
2. Deprecate `UserAuth` (password hash, phone, local `oauthSubject`/`provider`) and `UserSession` (unused refresh-token-hash table) — mark `@@deprecated`-by-convention (Prisma has no native deprecation, so: stop writing to them, add a migration comment, plan a follow-up migration to drop columns/tables after the legacy-drain window in §12).
3. Add a migration to backfill `UserCentralAuthLink` for any existing local-only users at cutover time (matched by verified email, same auto-link logic already used in `authModeSelector.middleware.ts`).

---

## 10. Central Auth Client ID and Audience Strategy

- Register Furtail as its own `AuthClient`: `clientId=furtail-mobile`, `type=FIRST_PARTY_APP` — distinct from BPA's client row.
- Central Auth issues access/refresh tokens with `aud=furtail-mobile` for Furtail-originated logins (fixing the current shared-`bpa-mobile`-audience bug in §1.1/§1.4).
- Furtail's `authModeSelector`/`centralAuth.middleware.ts` must validate the token's `aud` matches `furtail-mobile` (or a small allow-list if Furtail should also accept BPA-issued tokens for a cross-app SSO scenario — confirm this is NOT desired before implementing; default assumption is **strict single-audience** per app).
- `clientId` must be threaded through every Central Auth request the Furtail app makes (login, register, refresh, social start/callback, OTP) so Central Auth can (a) mint the correct audience and (b) apply per-client provider enablement (§9).
- Long-term: consider moving from shared-secret HS256 to RS256 + JWKS (`OidcSigningKey` table already exists for this) so Furtail API validates tokens without holding a shared secret — reduces blast radius if one service's secret leaks. Flag as a security-hardening phase, not a blocker for functional parity.

---

## 11. Redirect URI and Android Deep-Link Strategy

- Mirror BPA's system-browser pattern exactly: `flutter_web_auth_2` + a registered `CallbackActivity` intent-filter in `AndroidManifest.xml` with a Furtail-specific custom scheme (e.g. `furtailapp` — must not collide with BPA's `bpauserapp` scheme or any other app installed on the same device).
- Central Auth's `AuthClient.redirectUris` for the Furtail client must include this exact scheme + callback path (e.g. `furtailapp://oauth-callback`).
- iOS: register the same custom scheme in `Info.plist` (`CFBundleURLTypes`) — BPA audit didn't confirm iOS wiring explicitly; verify BPA's iOS config as an additional reference before implementing Furtail's.
- No embedded WebView anywhere in the flow (architecture rule #7) — `flutter_web_auth_2` uses Chrome Custom Tabs (Android) / `ASWebAuthenticationSession` (iOS), both out-of-process from the app, satisfying platform OAuth best practices and Google/Apple's "no WebView for OAuth" policies.

---

## 12. Account-Linking and Duplicate-Account Rules

- One Central Auth `User` per human; `OAuthAccount` (unique on `provider`+`providerAccountId`) links each social identity to that one user — already correctly modeled in Central Auth.
- Login-time auto-linking: if a social provider returns a verified email matching an existing Central Auth user, link automatically (existing `loginOrLink` behavior) — keep this for Furtail too, no per-app deviation.
- Explicit account linking (add a second provider while already logged in) does not exist today — recommended as a fast-follow, not a blocker: add `POST /auth/social/:provider/link` (authenticated) to Central Auth.
- Furtail-side duplicate prevention: `UserCentralAuthLink.subject` is unique — the existing JIT-provisioning logic in `authModeSelector.middleware.ts`/`centralAuthLocalUser.middleware.ts` already prevents creating two local `User` rows for one Central Auth subject; preserve this invariant, just consolidate the duplicated implementation (§7).
- Legacy Furtail local accounts (`UserAuth` password-based, pre-migration) must be matched to a Central Auth identity at cutover by verified email, same pattern Central Auth already uses for social auto-link — one migration script, run once (§14).

---

## 13. Token Lifecycle

- Access token: 15m TTL (Central Auth default), `aud=furtail-mobile`, `sub=<central-user-id>`, HS256 (or RS256 post-hardening).
- Refresh token: 30d TTL, rotation + reuse detection already implemented in Central Auth's `RefreshToken` model (`familyId`/`replacedByTokenId`/`reusedAt`) — no changes needed, Furtail simply becomes a consumer.
- Furtail app: single-flight mutex refresh on 401 (already implemented in `auth_interceptor.dart`), matching BPA's pattern — preserve as-is (architecture rule #9).
- Furtail API: **never mints, never refreshes** — pure verification of Central Auth-issued tokens; local session state (if any is needed at the Furtail-API layer, e.g. for websockets) must reference the Central Auth `sub`, not create a parallel session token.

---

## 14. Logout/Revocation Behavior

- Furtail app `logout()` keeps its current pattern: clear local secure-storage tokens immediately (offline-safe UX), then best-effort call Central Auth `POST /auth/logout` to revoke server-side — already implemented correctly, no change needed.
- Furtail API's local `/logout` route must stop being a no-op cookie-clear and instead proxy/delegate to Central Auth's logout+session revocation (or be removed entirely if the Flutter app talks to Central Auth directly for logout, which it already does — likely this route becomes dead and can be deleted rather than fixed, since the Furtail app doesn't appear to call Furtail's own `/logout` for the Central Auth-token case).
- `forceLogout()` (interceptor-driven, on unrecoverable refresh failure) requires no server call — session is already invalid — keep as-is.

---

## 15. Migration Plan from Legacy Furtail Sessions

Phased drain, using the already-built `AUTH_MODE=dual` as the transition vehicle:

1. **Phase A (backend readiness)** — ship Central Auth fixes (§6: clientId attribution, per-client audience, per-client provider enablement) and Furtail-API middleware consolidation (§7) while `AUTH_MODE` stays `dual`. No user-facing change yet.
2. **Phase B (stop minting new legacy tokens)** — repoint `login`/`register`/`staffLogin`/social routes in `furtail_api` to Central Auth (remove local `jwt.sign` calls, §7); any client still holding an old 7-day local token keeps working via the `legacy` fallback branch in `authModeSelector.middleware.ts` until it naturally expires (max 7 days from a given issuance) or the user re-authenticates.
3. **Phase C (drain window)** — hold `AUTH_MODE=dual` for at least the max legacy token lifetime (7 days) plus a safety margin (recommend 14 days) after Phase B ships, monitoring the legacy-fallback branch's hit rate (add a metric/log line if not already present) to confirm it drops to zero.
4. **Phase D (cutover)** — once legacy-fallback usage is confirmed at zero for a sustained period, flip `AUTH_MODE` to `central`, delete `authLegacy.middleware.ts` and the `legacy` branch of `authModeSelector.middleware.ts`.
5. **Phase E (data cleanup)** — migration to backfill any remaining unlinked local users into `UserCentralAuthLink` by verified email, then deprecate/drop `UserAuth` and `UserSession` columns/tables in a follow-up Prisma migration.

---

## 16. Security Risks

- **Shared-secret HS256 across services** (Central Auth ↔ Furtail API) means a leak of `CENTRAL_AUTH_JWT_SECRET` in either codebase compromises token integrity platform-wide — recommend moving to RS256/JWKS as a hardening follow-up (§10).
- **`x-user-id`-trusting dev middleware** (`src\api\v1\middlewares\auth.ts` in `furtail_api`) is a live authentication bypass if any production route still references it — must be audited and removed before/alongside this migration, independent of Central Auth work.
- **Hardcoded `JWT_SECRET` fallback** (`"super-secret-key"` in `furtail_api/src/config/appConfig.ts`) — ensure production environments always set `JWT_SECRET`/eventually remove this code path entirely once local issuance is deleted (§7).
- **`clientId: 'social'` hardcoding** in Central Auth (§6) is not just a bookkeeping bug — it means social-login refresh tokens/sessions today aren't scoped to a real `AuthClient`'s `redirectUris`/`allowedScopes`, a latent cross-app confusion risk that must be fixed before Furtail relies on social login.
- **Global per-provider enable flag** means disabling a compromised provider (e.g. revoking a leaked Google client secret) currently takes down that provider for every app simultaneously — per-client scoping (§9) also serves as an incident-response control, not just a UX nicety.
- **WhatsApp/SMS OTP delivery** introduces a new abuse surface (OTP-bombing, toll fraud via premium-rate numbers) — rate-limiting and per-destination throttling must be part of the OTP build (§8), not bolted on after.
- **Apple review requirement**: shipping other social logins on iOS without a native "Sign in with Apple" affordance risks App Store rejection — confirm current Apple guidelines during the Apple provider work (§8), not at submission time.
- **Migration window dual-mode risk**: while `AUTH_MODE=dual` is active, a compromised legacy Furtail JWT remains valid for its full original lifetime — ensure the drain window (§15) is bounded and monitored, not left indefinitely.

---

## 17. Ordered Implementation Phases

1. **Central Auth foundation fixes** — fix `clientId:'social'` hardcoding, add per-client JWT audience, create/confirm Furtail `AuthClient` row, add per-client social-provider scoping. *(Blocking for everything else.)*
2. **Furtail API middleware consolidation** — merge the three duplicated JIT-provisioning implementations into one shared module; delete the empty `auth.middleware.ts` stub; audit and remove `x-user-id`-trusting dev middleware.
3. **Furtail API: stop local token issuance** — remove `jwt.sign` calls from register/login/staffLogin/social/invite-accept; route those flows to Central Auth; keep `AUTH_MODE=dual` for backward compatibility during drain.
4. **Furtail app: social login UI** — port BPA's `social_provider_model.dart` / `social_login_providers.dart` / `social_login_grid.dart`; wire `clientId=furtail-mobile` into all Central Auth requests; add Android/iOS deep-link registration.
5. **Furtail app: complete forgot/reset password parity** — build missing `reset_password_screen.dart` (and optionally the resend-cooldown UX from BPA's `verify_reset_token_screen.dart`).
6. **Central Auth: OTP capability** — add `WHATSAPP` channel, WhatsApp/SMS adapter, `OtpChallenge` model, `/auth/otp/send|verify` routes; ship for all clients (BPA benefits too).
7. **Furtail app: OTP UI** — consume the new OTP endpoints once available.
8. **Legacy drain and cutover** — per §15 phases C–E: monitor, flip `AUTH_MODE=central`, delete legacy middleware, run data-cleanup migration, drop deprecated Furtail tables/columns.
9. **Security hardening (parallel track, can start anytime after phase 1)** — RS256/JWKS migration for cross-service token verification; explicit account-linking endpoint; rate-limiting for OTP.

---

## 18. Automated Verification Plan

- **Central Auth**: unit tests for `signAccessToken`/`signRefreshToken` asserting `aud` varies correctly per `clientId`; integration test confirming `social.service.ts` no longer hardcodes `'social'` as clientId (assert real `AuthClient.id` propagates end-to-end through start→callback→session); provider-scoping test confirming a provider disabled for `furtail-mobile` doesn't appear in `GET /social/providers?clientId=furtail-mobile` while still appearing for `bpa-mobile`.
- **Furtail API**: extend existing `authModeSelector.middleware.test.ts` / `centralAuth.middleware.test.ts` suites to cover the consolidated resolver; add a test asserting no route under `src/api/v1/modules/auth` calls `jwt.sign` with the local `appConfig.jwt.secret` (a static grep-based regression test, similar in spirit to the Flutter side's `no_legacy_token_key_test.dart`); add a security-regression test asserting `x-user-id` header alone never authenticates a request post-removal.
- **Furtail app**: extend `no_legacy_token_key_test.dart`'s spirit with a "no hardcoded provider list" test (mirrors BPA's design intent) if BPA has an equivalent; widget tests for the new social login grid (mock `GET auth/social/providers`, assert buttons render/hide correctly); widget test for the new `reset_password_screen.dart`.
- **End-to-end / manual verification checklist** (run before each phase's rollout): login with email/password → Furtail API resolves correct local profile via `UserCentralAuthLink`; login via each enabled social provider → confirm single `OAuthAccount` created, no duplicate `User`; forgot→reset password full round trip; logout → confirm refresh token revoked server-side (attempt reuse, expect rejection); 401 mid-session → confirm single-flight refresh + retry succeeds; legacy-token holder (pre-migration) → confirm dual-mode fallback still authenticates until natural expiry, then confirm it stops working post-cutover.
- **Monitoring**: add a log/metric counter for legacy-fallback authentications in `authModeSelector.middleware.ts` (if not already present) to give an objective signal for when Phase 8 drain is safe to cut over.
