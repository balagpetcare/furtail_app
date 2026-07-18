# Furtail × WPA Central Auth — Final Integration / Hardening Report

Capstone verification pass across four repos, 2026-07-18. Every command output
summarized here was actually run in this environment. MOCKED vs REAL is labeled
explicitly; no green result is fabricated.

---

## 1. Final architecture status

Central Auth (`wpa_auth_api`) is the sole identity authority. Furtail's backend
(`furtail_api`) trusts it: middleware verifies **HS256** Central Auth access
tokens (issuer + audience + expiry, algorithm pinned) and resolves a local user
by subject, with a gated verified-email auto-link path. The Flutter app
(`furtail_app`) authenticates natively in-app against `/api/v1/auth/*` (no
hosted page/WebView), stores tokens in secure storage only, and refreshes via a
single-flight mutex interceptor. BPA (`bpa_user_app`) remains an independent
consumer on audience `bpa-mobile`, unaffected.

Architecturally sound and internally consistent. Not production-launch-complete
because: no native provider SDKs are wired in the app; access tokens are HS256
only (no JWKS for them); `/oauth/introspect` still doesn't check `LoginSession`
revocation for JWT access tokens; Android `applicationId` is a placeholder; and
the reset-password deep link needs a `MainActivity` intent-filter added at
deploy time.

## 2. Files changed by repository

**wpa_auth_api**
- `src/config/index.ts` — added `PASSWORD_RESET_URL_BY_CLIENT`, `EMAIL_VERIFICATION_URL_BY_CLIENT` (per-client deep-link routing).
- `src/modules/auth/resetLinkRouting.ts` — **new** pure, dependency-free link-routing module.
- `src/modules/auth/resetLinkRouting.test.ts` — **new** 8 unit tests (REAL).
- `src/modules/auth/auth.service.ts` — `buildPasswordResetLink()` / `buildEmailVerificationLink()`; `forgotPassword()` now takes `clientId`; reset email routes per-client (fixes the admin-panel-only reset link bug).
- `src/modules/auth/auth.routes.ts` — `forgotPasswordSchema` accepts optional `clientId`, passed through.
- `src/modules/auth/identityLogin.service.ts` — **new** `listLinkedIdentities()` + `unlinkIdentity()` (safe, token-free).
- `src/modules/auth/identityAuth.routes.ts` — **new** `GET /auth/identities`, `DELETE /auth/identity/:provider`.
- `.env.example` — documented the two new per-client URL vars.

**furtail_api**
- `src/middleware/centralAuthLocalUser.middleware.ts` — conflict logs now emit an `emailFingerprint` (sha256, 12 chars) + counts instead of raw email PII; DB writes untouched.
- `scripts/central-auth-link-dry-run.ts` — hardened: case-insensitive email matching (matches runtime), PII-safe default output (`--include-pii` to opt in), explicit `--apply` flag (0-writes-by-design, documented), `mode`/`writesPerformed` in summary.
- `src/middleware/__tests__/centralAuthLinkDryRun.categorize.test.ts` — added case-insensitivity + idempotency tests.

**furtail_app**
- `lib/core/config/central_auth_config.dart` — added `clientId` (`furtail-mobile`, dart-define overridable).
- `lib/core/auth/central_auth_api.dart` — `forgotPassword()` sends `clientId`.
- `lib/core/auth/auth_controller.dart` — passes `CentralAuthConfig.clientId` on password-reset request.
- `lib/core/deep_link/deep_link_target.dart` — new `DeepLinkKind.resetPassword`.
- `lib/core/deep_link/deep_link_parser.dart` — parses `reset-password?token=...` (custom scheme + allowed-host HTTPS, anti-spoof).
- `lib/core/deep_link/deep_link_navigator.dart` — routes to `ResetPasswordScreen(initialToken:)`.
- `lib/features/auth/presentation/screens/reset_password_screen.dart` — updated stale doc comment.
- `test/core/deep_link_reset_password_test.dart` — **new** 6 tests (REAL).
- `test/core/auth/auth_controller_test.dart`, `test/core/auth/auth_interceptor_test.dart` — fake `forgotPassword` signatures updated for the new param.
- `docs/FURTAIL_AUTH_PROVIDER_SETUP.md`, `docs/FURTAIL_CENTRAL_AUTH_FINAL_REPORT.md` — **new**.

**bpa_user_app** — **zero code changes.** Only ran its existing auth tests as a regression check.

## 3. Database migrations

**No new schema migrations were required.** All Central Auth models already
existed (`AuthClient`, `OAuthAccount`, `UserCentralAuthLink`,
`EnterpriseIdentityProvider`, `PasswordResetToken`, etc.). The linked-identity
read/unlink endpoints reuse the existing `OAuthAccount` table; the reset-link
fix is env-config only. `npx prisma validate` passes for both backends. The
per-client reset routing was deliberately done via env (not a new
`AuthClient` column) to keep the change additive and migration-free.

## 4. Authentication methods completed

| Method | Status |
|---|---|
| Email + password | REAL, tested |
| Phone + password (verified phone required) | REAL, tested |
| Email OTP | REAL, tested |
| Phone (SMS) OTP | REAL, tested |
| WhatsApp OTP | Correctly `PROVIDER_DISABLED` (no channel) — passing behavior |
| Forgot / reset password | REAL; email link now deep-links per client |
| Google / Facebook / Apple / Microsoft ID/access-token login | Verification logic REAL; provider connectivity MOCKED (no creds) |
| Enterprise OIDC | REAL logic (DB-driven); SAML `PROVIDER_DISABLED` |
| Account linking (list / unlink / link) | Backend REAL (new list+unlink endpoints, typechecked); app screen pending |
| Refresh rotation + reuse detection + family revocation | REAL, tested |
| Session list / revoke | REAL, tested |

## 5. Providers fully verified (REAL, end-to-end in this environment)

- Email/password, phone/password, email OTP, SMS OTP, forgot/reset password — verified against the **real dev Postgres/Redis** via `wpa_auth_api` integration tests (`centralAuth.integration.test.ts`, 7 tests) and `furtail_api` middleware tests.
- Per-client reset/verify link routing — `resetLinkRouting.test.ts` (8 REAL unit tests).
- Reset-password deep-link parsing/routing — `deep_link_reset_password_test.dart` (6 REAL widget-layer tests).
- Refresh mutex / interceptor, controller state machine, secure-storage-only tokens — REAL Flutter unit/widget tests.

## 6. Providers verified only with mocks

- **Google, Apple, Microsoft, Enterprise OIDC:** JWKS/id-token verification is exercised by `identityProviders.unit.test.ts` (4 tests) using a **local mock JWKS server** — asserts wrong-audience rejection, expired-token rejection, and untrusted-signer rejection. This proves the *token-validation logic* is correct; it does **not** prove live provider connectivity (no real console credentials exist; all provider env vars are empty/absent). A live OAuth consent screen cannot be driven headlessly in this pass.
- **Facebook:** access-token/`debug_token` path is code-complete but has no dedicated mock test; treated as MOCKED/unverified for live connectivity.

## 7. External console configuration still required

See `FURTAIL_AUTH_PROVIDER_SETUP.md` for the full operator runbook. Blocking items:
1. Change Android `applicationId` from `com.example.furtail_app` to a real reverse-DNS id.
2. Generate a release keystore; obtain SHA-1/SHA-256 via `./gradlew signingReport` (not obtainable by this pass — no keystore in repo).
3. Register OAuth clients + fingerprints/bundle ids in Google Cloud, Meta, Apple, Azure/Entra; populate `GOOGLE_LOGIN_AUDIENCE`, `FACEBOOK_APP_ID/SECRET`, `APPLE_LOGIN_AUDIENCE`, `MICROSOFT_CLIENT_ID/TENANT_ID`.
4. Wire native SDKs into `pubspec.yaml` (none present today).
5. Add `MainActivity` deep-link intent-filter + App Links `assetlinks.json`; set `PASSWORD_RESET_URL_BY_CLIENT={"furtail-mobile":"furtail://reset-password"}`.
6. Configure approved email + SMS `CommunicationProvider` rows. WhatsApp needs backend `CommunicationChannel` schema work first.

## 8. Security controls implemented / verified

- Algorithm-pinned HS256 verification (issuer/audience/expiry) in `furtail_api`; audience confirmed `furtail-mobile` across `.env`/`.env.example`/`appConfig.ts`.
- Refresh-token rotation + reuse detection + session-family revocation (REAL tests).
- Legacy `/register`,`/login` gated to `410 LEGACY_AUTH_DISABLED` unless `AUTH_MODE=legacy`.
- Auto-link only on verified + unambiguous email; `409 IDENTITY_CONFLICT` otherwise; never merges on unverified email; never deletes legacy rows.
- **PII hardening (this pass):** identity-conflict logs no longer emit raw emails — sha256 fingerprint + counts only. Migration script defaults to PII-safe output.
- Password reset revokes all refresh tokens; user-enumeration-safe (always 200).
- New linked-identity endpoints never return provider tokens; unlink refuses removing the last login method (`409 LAST_LOGIN_METHOD`).
- No secrets in `furtail_app/lib/` (grep-verified). Reset deep link rejects non-allowed HTTPS hosts (anti-spoof, tested).

## 9. Automated test / build results (real output)

| Repo | Command | Result |
|---|---|---|
| wpa_auth_api | `npx prisma validate` | PASS ("schema is valid") |
| wpa_auth_api | `npx tsc --noEmit` (`npm run check`) | PASS (exit 0) |
| wpa_auth_api | `npm run build` (`tsc`) | PASS (exit 0) |
| wpa_auth_api | `npm test` | **33 pass / 0 fail** (incl. 7 REAL DB integration, 4 MOCKED JWKS, 8 REAL reset-routing) |
| furtail_api | `npm run prisma:generate` | PASS (exit 0) |
| furtail_api | `npm run typecheck` (`tsc --noEmit`) | PASS (exit 0) |
| furtail_api | `npx jest centralAuth centralAuthLinkDryRun` | **20 pass / 0 fail** (3 suites) |
| furtail_app | `dart format` (changed files) | PASS (reformatted 3) |
| furtail_app | `flutter analyze` (changed dirs) | 7 pre-existing `info` hints, **0 from this pass**, 0 errors/warnings |
| furtail_app | `flutter test` (full) | **91 pass / 0 fail** |
| bpa_user_app | `flutter test` (auth suites) | **9 pass / 0 fail** — zero code changes made |

Notes: a genuine test-load failure was found and fixed — adding the `clientId`
param to `forgotPassword` broke two Flutter fake classes; both fake signatures
were updated (assertions untouched, not weakened). furtail_api's full jest suite
was not run end-to-end (large, unrelated domain suites); the auth-relevant
suites were run and pass.

## 10. Remaining blockers

1. **No native provider SDKs** in `furtail_app/pubspec.yaml` — social login cannot run live in-app yet. (Provider buttons honestly render "coming soon".)
2. **`/oauth/introspect` does not check `LoginSession` revocation** for JWT access tokens (only signature+expiry) — a revoked session's unexpired access token still introspects as `active`. No live sid-based revocation for consumers. **Not fixed this pass** (would need a `sid` claim + session lookup); documented as a real limitation.
3. **Access tokens are HS256 only** — no JWKS for them; consumers must share the secret. JWKS covers OIDC `id_token` only.
4. **Android `applicationId` is a placeholder**; no release keystore/fingerprints available.
5. **Reset-password deep link needs a `MainActivity` intent-filter** + App Links verification file added at deploy time (parsing/routing logic is complete and tested).
6. **App-side linked-identities/profile-completion/session UI:** backend surface now exists (`GET /auth/identities`, `DELETE /auth/identity/:provider`, plus existing session endpoints), but the dedicated Flutter screens for linked-providers management were not built this pass — the flow is testable at the API/data layer, screens remain follow-up work.
7. **WhatsApp OTP** blocked on backend `CommunicationChannel` schema addition (correctly disabled today).

## 11. Final readiness status: **NOT READY** for full production launch

The **authentication architecture is sound** and everything that can be
verified without external credentials is REAL-tested and green (33 + 20 + 91 + 9
tests passing; both backends typecheck, build, and validate). The reset-email
routing bug is fixed, PII-in-logs is hardened, migration is idempotent and
side-effect-free by design, and the linked-identity backend gap is closed
additively.

It is **NOT READY** for launch because production requires external work this
pass cannot perform: real provider-console credentials + native SDK wiring,
a real signing identity/package name, the deep-link manifest filter, and
resolution of the introspection-revocation and HS256-only limitations. These
are honest, expected gaps for a system whose social-login and store-release
surfaces depend on operator-owned secrets and consoles. Core email/phone/OTP
auth for Furtail is functionally complete and verified.
