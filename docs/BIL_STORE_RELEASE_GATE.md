# BIL Google Play and App Store release gate

No build is release-ready until every applicable item is green.

## Code and product

- Analyzer and full test suite pass on the release commit.
- Arabic and English are complete. French, Spanish and Turkish receive native
  review wherever advertised as supported.
- Account, local-only, verification, reset, export, deletion and permission
  denial are tested on physical devices.
- Search, barcode, voice and image analysis fail honestly offline.
- Tobacco, medicine/supplement, cosmetic/cleaner, food and unknown states never
  invent nutrition or permit a non-food product into a meal.
- Only licensed, verified recipe/workout packs are visible; no demo content.
- Guide, Body Twin, evidence, watch and supported fitness-device states remain
  truthful; no medical-device reading capability is claimed.

## External activation

- Apple Developer and Play Console agreements and signing identities are live.
- The four subscriptions (`bil_premium`, `bil_premium_annual`,
  `bil_premium_ai_coach`, and `bil_premium_ai_coach_annual`) and the consumable
  `bil_ai_boost` match the device-store catalog and server entitlements.
- Supabase migrations, RLS, edge functions, SMTP, secrets and redirects deploy.
- Vision/catalog/wellness endpoints use HTTPS, integrity and monitoring.
- Media licenses and food-data provenance are documented.
- Reporting, blocking, moderation and abuse response exist before community.

## Native review

- Android AAB, current target API, Health Connect/BLE declarations and Play
  pre-launch report pass.
- iOS archive is built on macOS; privacy, HealthKit, BLE and TestFlight pass.
- Small/large text, RTL, light/dark, reduced motion, screen reader and denied
  permissions pass on phones.
- Screenshots, medical disclaimer, privacy, terms, support and review account
  are complete.

## Final build boundary

Do not treat a raw `flutter build appbundle --release` or `flutter build ipa`
as a store candidate. Both commands default commerce and several production
features to fail closed. The signed Android and iOS workflows are the
authoritative build entry points: they pin Flutter, require an explicit build
number, run the full gates, and pass the reviewed production Dart defines.

The repository also provides the manual GitHub workflow
`BIL Android signed release candidate`. It refuses to build without all four
Android signing secrets, verifies the resulting AAB signature, records its
SHA-256 and uploads it only as a private workflow artifact. It never submits
to Google Play automatically.

Required GitHub Actions secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_UPLOAD_CERTIFICATE_SHA256`

The signed iOS workflow additionally requires the Apple team, distribution
certificate, provisioning profile, and App Store Connect API secrets named in
that workflow. Its TestFlight upload input defaults to `false`; neither signed
workflow submits a version for public review or starts a production rollout.

## Current external evidence — 2026-08-31

- App Store Connect GET-only audit: app `1.0.0` is
  `PREPARE_FOR_SUBMISSION`, no build is uploaded or attached, and no product
  page screenshot set is uploaded. All 175 territories are selected; 27 EU
  territories still report `TRADER_STATUS_NOT_PROVIDED`.
- Apple local signing material exists and its provisioning profile matches the
  production bundle, HealthKit, Sign in with Apple, production push, and
  distribution constraints. This does not prove the corresponding GitHub
  secrets are configured or that a signed CI archive has passed.
- Authenticated Android Publisher audits from two existing credentials agree on
  the live catalog. The accidental `P1M` plan under the annual AI product is
  inactive; the correct AI monthly and yearly plans each have the active exact
  `trial-7-day` / `new-customer` / `P7D` offer. Premium has no trial. Evidence
  is under `artifacts/release/google/2026-08-31-api-audit/` and
  `artifacts/release/google/2026-08-31-exact-catalog-repair/`.
- Google Play has version-code 4 completed on the alpha track, eight phone
  screenshots, an icon and feature graphic, but no `+5` bundle or production
  release. App Content and Data Safety still rely on retained authenticated
  Console/UI evidence because the API does not expose all questionnaire state.
- Belarus is configured consistently: AI monthly USD 7.19 and its seven-day
  trial cover the same 168 regions as AI annual. Annual BY remains USD 43.19
  and Boost BY remains USD 6.00. Before/operation/after evidence is under
  `artifacts/release/google/2026-08-31-by-monthly-repair/`.
- The existing local Android APK/AAB artifacts are build 4 and predate the
  current `1.0.0+5` source. They are not final candidates.
- BrowserStack/real-phone evidence and physical Health Connect, HealthKit,
  Apple Watch, Wear OS, fitness-BLE, Play Billing, and StoreKit evidence are
  not recorded for the final build. Simulator or emulator evidence cannot
  close these gates.
