# BIL Android 9 / iOS 10 release handoff

## Release identity

- Android artifact: `1.0.0`, Google Play `versionCode 9`.
- iOS artifact: `1.0.0`, App Store `CFBundleVersion 10`.
- The shared Flutter source remains `1.0.0+8`; each signed workflow supplies
  its platform build number explicitly. This avoids assigning the same build
  number to two different stores while preserving the previously frozen
  source baseline.
- Source manifests:
  - `docs/release/BIL_ANDROID_V9_FROZEN_SOURCE_MANIFEST_2026-09-06.md`
  - `docs/release/BIL_IOS_V10_FROZEN_SOURCE_MANIFEST_2026-09-06.md`

## Fixed subscription behavior

The annual/monthly delay was a UI state bug, not normal store behavior. The
paywall now locks offer selection only while the catalog is loading or a store
purchase is pending. The store listener clears the lock on cancellation,
failure, or verification, and the page also guards the tiny interval before a
store event arrives. Returning from the payment sheet therefore lets the user
switch plans immediately without leaving and reopening the page.

Regression coverage is in
`test/features/commerce/subscription_offer_selection_test.dart`.

## Steps and energy contract

The dashboard does not draw a Cartesian line chart for steps and does not mix
steps with calories. The pipeline is:

1. HealthKit on iOS or Health Connect on Android emits `steps` signals.
2. `connected_health_provider.dart` aggregates the selected signals into
   local-calendar daily totals and persists a 30-day `stepHistory` snapshot.
3. `connected_health_model.dart` normalizes that history to exactly 30
   ascending daily buckets, filling missing days with zero.
4. `dashboard_grid.dart` passes those values to the dashboard step card, which
   renders a bar trend. The energy card remains a separate calorie progress
   surface sourced from nutrition/activity totals.

The source-of-truth paths are:

- `lib/features/connected_health/providers/connected_health_provider.dart`
- `lib/features/connected_health/connected_health_model.dart`
- `lib/features/dashboard/widgets/dashboard_grid.dart`

## Food-search status and safe boundary

The deployed Supabase Edge Function `food-search` is the only external USDA
boundary. It authenticates the user, applies quotas, calls FoodData Central,
and returns normalized verified rows. Supabase currently has both
`BIL_USDA_API_KEY` and `BIL_TRANSLATION_API_KEY`, and `food-search` version 14
is deployed. The mobile resolver refreshes expired sessions, forwards the
server search hint, and keeps trusted translated cloud rows for non-Latin
queries such as Arabic watermelon/kiwi searches. Secret values are never
bundled in the app or recorded in release evidence. The function remains
fail-closed if either server-side capability is unavailable, while local
installed catalogs remain available.

## Verification record

The source gates below completed on the exact candidate before its GitHub
commit. A passing source suite is not a signed-device or store-review pass.

- `flutter clean` and dependency resolution: passed.
- Portable Flutter inventory: 904 test files discovered, 29 explicit
  platform/golden exclusions, 875 scheduled and 875 executed; all passed.
- Performance budget: passed (`startup_ms=187`, search median `150 ms` for the
  1,000-food catalog test).
- Targeted Today/meal-detail, food-add, community, and visual contracts: 41/41
  passed after the final compact-Today change.
- Full `flutter analyze --no-pub`: passed with no issues.
- Changed-Dart format gate and `git diff --check`: passed.
- Portable runner unit tests: 9/9 passed.
- High-confidence secret scan: 4,856 tracked/candidate files checked; no
  private key, provider token, or signing bundle is part of the upload.
- Android signed AAB: GitHub Actions only; Windows cannot produce the signed
  iOS archive.
- iOS signed IPA/TestFlight: GitHub Actions macOS runner only.

## GitHub Actions bindings

The current signed workflows are:

- `BIL Android signed release candidate (build 9)`
- `BIL iOS signed release candidate (build 10)`

Before dispatch, bind each manifest and the exact commit in repository
variables:

- `BIL_ANDROID_V9_AUDITED_SOURCE_SHA`
- `BIL_ANDROID_V9_STAGING_MANIFEST_SHA256`
- `BIL_IOS_V10_AUDITED_SOURCE_SHA`
- `BIL_IOS_V10_STAGING_MANIFEST_SHA256`

Android signing and store inputs are required as GitHub Secrets/Variables:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_UPLOAD_CERTIFICATE_SHA256`
- `BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID`
- `BIL_PLAY_INTEGRITY_PROJECT_NUMBER` (repository variable)

iOS signing and upload inputs are required as GitHub Secrets:

- `APPLE_TEAM_ID`
- `APPLE_DISTRIBUTION_CERTIFICATE_BASE64`
- `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`
- `APPLE_PROVISIONING_PROFILE_BASE64`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY_BASE64`
- `BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID`

The workflows validate application ID, Supabase/receipt endpoints, HealthKit,
Sign in with Apple, associated domains, push entitlement, App Attest/Play
Integrity bindings, signing material, native plugin graphs, and final artifact
metadata before publishing artifacts.

## Store rollout order

1. Run the Android workflow with build number `9`; review the AAB evidence and
   install it through Google Play Closed Testing.
2. Run the iOS workflow with build number `10` and
   `upload_to_testflight=true` only after the signing gates pass; verify the
   processed build in TestFlight.
3. Perform the owner device checks for StoreKit/Play Billing, HealthKit/Health
   Connect, Bluetooth, sign-in, community, and the subscription cancellation
   path.
4. Keep Google Play production promotion separate until the closed-test
   evidence and Google review decision are complete.
