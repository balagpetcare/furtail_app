# Furtail Central Auth — Provider & Configuration Setup

Operator guide for taking WPA Central Auth from its current (mostly
placeholder) state to production for the Furtail app. Every value below was
read from the **actual** config files in this environment on 2026-07-18, not
guessed. Real secret values are never printed here; where a live `.env`
contains a value it is reported only as *present*/*empty*.

Repos referenced:
- **wpa_auth_api** — `D:\wpa\wpa_auth\wpa_auth_api` (Central Auth backend; owns all provider verification)
- **furtail_api** — `D:\wpa\furtail\furtail_api` (Furtail backend; only *consumes* Central Auth tokens)
- **furtail_app** — `D:\wpa\furtail\furtail_app` (Flutter app; native login UI, no hosted page)

> **Secret hygiene (verified):** `grep -riE "CLIENT_SECRET|APP_SECRET|APPLE_PRIVATE_KEY|FACEBOOK_APP_SECRET"`
> over `furtail_app/lib/` returns **no matches**. No provider secret is present
> in Flutter code. All provider secrets live server-side in `wpa_auth_api` only.

---

## 0. Current-state summary (what's real right now)

| Area | Status in this environment |
|---|---|
| Email/password, phone/password, email/phone OTP | Implemented + tested (REAL, DB-backed) |
| WhatsApp OTP | **Unsupported by design** — no `CommunicationChannel` for it; returns `PROVIDER_DISABLED` cleanly |
| Google / Facebook / Apple / Microsoft login | Token-verification logic implemented + unit-tested with **mocked JWKS**; **all provider env vars empty/absent** → runtime returns `PROVIDER_DISABLED` |
| Enterprise OIDC | DB-driven (`EnterpriseIdentityProvider`); SAML stubbed as `PROVIDER_DISABLED` |
| Native provider SDKs in the app | **None wired** — `pubspec.yaml` has no `google_sign_in` / `flutter_facebook_auth` / `sign_in_with_apple` / MSAL. Provider buttons render as honest "coming soon" |
| Access-token signing | **HS256 only** (`JWT_RSA_*` empty). JWKS endpoint serves keys only for the separate OIDC `id_token`, not access tokens |
| Password-reset email routing | **Fixed this pass** — now per-client via `PASSWORD_RESET_URL_BY_CLIENT` (see §7) |
| Android applicationId | `com.example.furtail_app` — **placeholder**, must change before store release |

---

## 1. Google

- **Server config field (wpa_auth_api):** `GOOGLE_LOGIN_AUDIENCE` (`src/config/index.ts:69`) — comma-separated allow-list of Google OAuth **client IDs** accepted as the `aud` of the incoming ID token. (`GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET`/`GOOGLE_CALLBACK_URL` are for the separate OAuth *code*-flow and are currently empty strings.)
- **Current value:** `GOOGLE_LOGIN_AUDIENCE` is **absent** from `.env` → provider disabled (`PROVIDER_DISABLED`).
- **App config:** none needed in-app *today* (no native SDK). Adding Sign-In-with-Google requires `google_sign_in` in `pubspec.yaml`, which produces an ID token the app POSTs to `POST /api/v1/auth/identity/google`.
- **Operator console steps (Google Cloud Console):**
  1. Create/choose a project → *APIs & Services → Credentials*.
  2. Create an **Android** OAuth client: supply package name `com.example.furtail_app` (**change to a real reverse-DNS id first**, e.g. `global.furtail.app`) and the SHA-1 fingerprint (see §11).
  3. Create an **iOS** OAuth client (bundle id) and, if used, a **Web** client.
  4. Put every client ID the app may present into `GOOGLE_LOGIN_AUDIENCE` (comma-separated).

## 2. Facebook

- **Server config fields:** `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` (`src/config/index.ts:70-71`). The secret is used server-side only (Graph `debug_token`); never shipped to the client.
- **Current value:** both **absent** from `.env` → `PROVIDER_DISABLED`.
- **App config:** requires `flutter_facebook_auth` (not present) to obtain an access token → `POST /auth/identity/facebook`.
- **Operator console steps (Meta for Developers):** create an app → add Facebook Login → register Android key hash (derived from the signing SHA-1) and iOS bundle id → copy App ID + App Secret into the server env.

## 3. Apple

- **Server config field:** `APPLE_LOGIN_AUDIENCE` (`src/config/index.ts:72`) — Services ID / app bundle id(s) accepted as `aud`. (`APPLE_TEAM_ID`/`APPLE_KEY_ID`/`APPLE_PRIVATE_KEY`/`APPLE_CLIENT_ID` are for the code flow and are empty.)
- **Current value:** `APPLE_LOGIN_AUDIENCE` **absent** → `PROVIDER_DISABLED`.
- **App config:** requires `sign_in_with_apple` (not present) → identity token to `POST /auth/identity/apple` (nonce supported).
- **Operator console steps (Apple Developer):** register the App ID with "Sign in with Apple" capability; create a Services ID for web/redirect; create a Sign-in-with-Apple key (.p8). Put the bundle id / Services ID into `APPLE_LOGIN_AUDIENCE`.

## 4. Microsoft

- **Server config fields:** `MICROSOFT_CLIENT_ID`, `MICROSOFT_TENANT_ID` (`src/config/index.ts:73-74`). `MICROSOFT_TENANT_ID` defaults to `common`.
- **Current value:** `MICROSOFT_CLIENT_ID` **absent** → `PROVIDER_DISABLED`. Tenant defaults to `common`.
- **App config:** requires MSAL (not present) → id token to `POST /auth/identity/microsoft`.
- **Operator console steps (Azure AD / Entra):** register an application; add mobile/desktop redirect URIs; note the Application (client) ID and directory (tenant) ID → server env.

## 5. Enterprise OIDC / SAML

- **Storage:** DB-driven, not env — the `EnterpriseIdentityProvider` table (`prisma/schema.prisma:983`). Each org row carries issuer/JWKS/audience. Login: `POST /auth/identity/enterprise?org=<slug>`.
- **SAML:** intentionally stubbed → `PROVIDER_DISABLED`.
- **Operator steps:** insert/activate an `EnterpriseIdentityProvider` row per organization (issuer URL, JWKS URI, allowed audience, allowed email domains). No env var toggles this; it is data-driven.

## 6. Email delivery (OTP, verification, reset)

- **Server:** SMTP/templated email via `nodemailer` + `CommunicationProvider` rows. OTP knobs: `OTP_LOGIN_CODE_LENGTH`, `OTP_LOGIN_EXPIRY_MINUTES`, `OTP_LOGIN_MAX_VERIFY_ATTEMPTS`, `OTP_LOGIN_RESEND_COOLDOWN_SECONDS`, plus `COMMUNICATION_*` rate caps (`src/config/index.ts`).
- **Operator steps:** configure an approved `CommunicationProvider` (SMTP creds live encrypted in DB via `CREDENTIAL_ENCRYPTION_KEY`), verify sender domain (SPF/DKIM).

## 7. SMS OTP delivery

- **Server:** channel `SMS` in the `CommunicationChannel` enum; delivered through an approved SMS `CommunicationProvider`. Same OTP/rate-limit knobs as email.
- **Operator steps:** configure an SMS provider row; set per-phone caps (`COMMUNICATION_MAX_SMS_PER_PHONE_PER_HOUR/DAY`).

## 8. WhatsApp OTP delivery — **currently unsupported (by design)**

- **Config field:** `WHATSAPP_OTP_ENABLED` (`src/config/index.ts:81`, default `false`).
- **Reality:** the Prisma `CommunicationChannel` enum has **only `SMS` and `EMAIL`** — there is no WhatsApp channel. `otp.service.ts:61-66` returns `PROVIDER_DISABLED` for `channel: 'whatsapp'` rather than faking delivery. This is the **correct** behavior until the backend adds a WhatsApp `CommunicationChannel` + provider. **Backend schema work required** before this can be enabled.

## 9. Central Auth URL, client ID, audience, issuer, JWKS

| Concept | wpa_auth_api field | furtail_api field | furtail_app field |
|---|---|---|---|
| Central Auth public URL | `APP_URL` / `OAUTH_ISSUER` | `CENTRAL_AUTH_API_BASE_URL`, `CENTRAL_AUTH_ISSUER` | `CENTRAL_AUTH_API_BASE_URL` / `CENTRAL_AUTH_API_HOST` (dart-define; `CentralAuthConfig`) |
| Furtail client ID | `AuthClient.clientId` (DB) | `CENTRAL_AUTH_CLIENT_ID=furtail-mobile` | `CentralAuthConfig.clientId=furtail-mobile` (added this pass; `--dart-define=CENTRAL_AUTH_CLIENT_ID`) |
| Furtail JWT audience | `AuthClient.audience` + `ADDITIONAL_JWT_AUDIENCES` (accepts `furtail-mobile`) | `CENTRAL_AUTH_AUDIENCE=furtail-mobile` ✅ (audience bug fixed in prior pass, re-confirmed consistent across `.env`/`.env.example`/`appConfig.ts`) | n/a (app doesn't verify tokens) |
| Token issuer | `OAUTH_ISSUER` (present, https) | `CENTRAL_AUTH_ISSUER` | n/a |
| JWKS / public keys | `JWT_RSA_PUBLIC_KEY` / `JWT_RSA_PUBLIC_KEYS_JSON` / `JWT_KEY_ID` (**all empty** → JWKS covers OIDC `id_token` only; access tokens are HS256, verified by shared secret) | `CENTRAL_AUTH_JWT_SECRET` (HS256 shared secret; present) | n/a |
| Provider enable/disable | per-provider env presence (§1-4) + `WHATSAPP_OTP_ENABLED`; bootstrap reflects it via `GET /auth/bootstrap` | `CENTRAL_AUTH_ENABLED=true`, `CENTRAL_AUTH_EMAIL_AUTOLINK_ENABLED=true` | bootstrap-driven `ProviderButtonGrid` |

## 10. Deep-link schemes / App Links (furtail_app)

- **Custom scheme:** `furtail` (`DeepLinkConfig.customScheme`).
- **Universal/App Link hosts:** `app.furtail.global` (default), `www.furtail.global`, `furtail.global` (`DeepLinkConfig.defaultAllowedHosts`); overridable via `--dart-define=DEEP_LINK_HOST` / `DEEP_LINK_HOSTS`.
- **Reset-password deep link (added this pass):** `furtail://reset-password?token=...` and `https://app.furtail.global/reset-password?token=...` now resolve to `DeepLinkKind.resetPassword` → `ResetPasswordScreen(initialToken:)`.
- **Android manifest caveat:** `AndroidManifest.xml` currently declares a `VIEW` intent-filter only for the `flutter_web_auth_2` OAuth callback activity (scheme `${appAuthRedirectScheme}`). **To receive `furtail://reset-password` (and other custom-scheme deep links) into `MainActivity`, the operator must add a `VIEW`/`BROWSABLE` intent-filter to `MainActivity`** (and an `autoVerify` App Links filter + `/.well-known/assetlinks.json` for HTTPS links). This was left as a documented deploy step to avoid conflicting with the existing OAuth callback scheme. The parsing/routing logic is complete and unit-tested.

## 11. Android package name & signing fingerprints

- **Package/application id:** `com.example.furtail_app` — from `android/app/build.gradle` (`namespace` + `applicationId`). **This is the Flutter default placeholder and must be changed to a real reverse-DNS id (e.g. `global.furtail.app`) before any store release or provider console registration**, because it is baked into every OAuth Android client and Facebook key-hash.
- **SHA-1 / SHA-256 signing fingerprints:** **not obtainable by this pass** — no release keystore or CI signing config is checked into the repo. The operator must run `./gradlew signingReport` (debug) and generate/register the release keystore, then provide the resulting SHA-1 (Google/Facebook) and SHA-256 (App Links `assetlinks.json`) fingerprints to each provider console.

## 12. Redirect URIs

- Native token-exchange flows (Google/Apple/Microsoft ID token, Facebook access token) do **not** use browser redirect URIs — the SDK returns the token in-app and the app POSTs it to `/auth/identity/*`. Redirect URIs are only needed if a hosted/web OAuth *code* flow is enabled (the empty `*_CALLBACK_URL` server vars). For deep links, register the App Link host + custom scheme per §10.
