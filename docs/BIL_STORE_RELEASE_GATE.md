# BIL Google Play and App Store release gate

No build is release-ready until every applicable item is green.

## Current Google Play access update — 2026-09-05

This update supersedes only the Google Play state in the historical
2026-08-31 snapshot below. It does not rewrite that dated evidence and does not
declare either store release-ready.

The Play Console was re-read without a write action on 2026-09-05 at 13:57
`+03:00`:

- the developer account is a personal account;
- Production remains `Inactive`;
- Play displays all three Production-access prerequisites as completed:
  closed release published, at least 12 opted-in testers, and at least 12
  testers for at least 14 days;
- `Apply for production` is displayed and enabled; it was not clicked;
- Alpha serves `1.0.0 (7)`, released on 2026-09-01;
- the configured tester list contains 18 accounts and Installed audience shows
  12. The exact continuously qualifying count is not exposed; the completed
  Play gate proves at least 12, not that all 18 qualify;
- five private Play feedback reports cover Android 10, 12, 14, and 16 and
  version codes 4, 5, and 7. The substantive reports concern onboarding
  target-weight entry, stale data until restart, and occasional cloud-sync
  delay;
- Play currently shows no developer-account or app policy issue and no pending
  App content item, but no pre-launch report has been generated.

The activity log shows Alpha at 100% on 2026-08-17 at 06:02 and the tester
list attached at 06:54 in the Console-displayed timezone. The earliest possible
14-day completion from that attachment was 2026-08-31 at 06:54. At the 13:57
`+03:00` recheck on 5 September, the maximum possible uninterrupted duration
from attachment was 19 days, 7 hours, and 3 minutes; individual opt-in times
remain undisclosed. Eight testers performing brief actions from 31 August
through 4 September does not itself prove either 12 testers or 14 days; the
live completed Play gate is the authoritative eligibility evidence.

| Decision | State | Boundary |
|---|---|---|
| Request Production access | `GO AFTER OWNER INPUT` | The Play eligibility gate is complete. The owner must truthfully select recruitment difficulty and a supported first-year install range before any separately authorised application. |
| Submit the access form | `NOT AUTHORISED` | No `Apply`, `Next`, save, or submission action is part of this audit. |
| Android package registration | `GREEN LIVE` | Play shows `com.bilhealth.bodyintelligencelog` as `Registered`, with four keys and last update 2026-08-18. This satisfies the package-name registration limb ahead of the 2026-09-30 deadline; no identity or address details are reproduced here. |
| Target API in current source | `GREEN IN SOURCE` | `android/app/build.gradle.kts` sets `compileSdk = 36` and `targetSdk = 36`, matching Google's Android 16 / API 36 requirement for new apps and updates from 2026-08-31. The final signed AAB manifest still requires verification. |
| Meta publication and Android reattachment | `LIVE / FOLLOW-UP` | Meta is Published/Live after the owner authorised temporary removal of the Android store platform whose canonical Play URL returns anonymous HTTP 404. Website and iOS remain configured, and Meta reports no required actions. Recreate the Android platform only after that exact Play URL returns HTTP 200; the removal did not delete Android from BIL or Play and does not add a native Meta SDK dependency. |
| Upload/promote a new signed candidate | `NO-GO` | Live Alpha is `+7`; current source is `+8`, and the latest tester-note closure is not a signed or Play-tested candidate. |
| Public Production rollout | `NO-GO` | Requires the signed-candidate/device matrix, Play Billing and Integrity proof, declaration reconciliation against the final AAB, pre-launch report, tablet assets, and catalog price/territory repair. |

The complete copy-ready answers, evidence limits, prohibited claims, and
post-application operating plan are in
[`release/GOOGLE_PLAY_PRODUCTION_ACCESS_APPLICATION_DRAFT_2026-09-05.md`](release/GOOGLE_PLAY_PRODUCTION_ACCESS_APPLICATION_DRAFT_2026-09-05.md).
The cross-platform public-URL dependency and the Pre-registration/Open-testing
decision are in
[`release/GOOGLE_PLAY_PUBLIC_LISTING_FOR_META_DECISION_2026-09-05.md`](release/GOOGLE_PLAY_PUBLIC_LISTING_FOR_META_DECISION_2026-09-05.md).
The time-sensitive Target API comparison uses Google's current
[Target API requirement](https://developer.android.com/google/play/requirements/target-sdk),
last updated 2026-08-14 UTC.
The package-registration status is evaluated against Google's current
[Play package-name registration requirement](https://support.google.com/googleplay/android-developer/answer/16984799?hl=en),
which states that unregistered Play packages are removed after 2026-09-30.

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
  current `1.0.0+8` source. They are not final candidates.
- BrowserStack/real-phone evidence and physical Health Connect, HealthKit,
  Apple Watch, Wear OS, fitness-BLE, Play Billing, and StoreKit evidence are
  not recorded for the final build. Simulator or emulator evidence cannot
  close these gates.
