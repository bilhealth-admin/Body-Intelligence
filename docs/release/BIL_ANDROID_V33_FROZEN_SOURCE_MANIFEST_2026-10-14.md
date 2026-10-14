# BIL Android 1.0.0 build 33 — preparation record, not release freeze

`STAGING_MANIFEST_COMPLETE: NO`

`CANDIDATE_FROZEN_OR_ACCEPTED: NO`

`UNRESOLVED_REVIEW_COUNT: 5`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 33`

## Why this file is not complete

This is a fail-closed preparation record for the next Android candidate. It
replaces the stale build-31 release bindings in the local workflow; it is not
an accepted source freeze, a signed artifact, or permission to build or upload.
The user-owned full Flutter run completed on source SHA
`e27a58984bff50b4bcf45044ea9893f344307e85` with source fingerprint
`c91dd3c449bc08efb0152badc8b4ff55e5774ea421ddef7e477cb95d922def71` and
reported 9,791 pass, 22 failures, 2 errors, 0 skipped. Those results do not
include the fixes now in the isolated snapshot. The focused repairs and final
full analysis remain pending.

Five historical Google case records remain unclosed against an exact new
artifact and reviewer session: the September 2026 broken-functionality notice,
the Android 13 Health Connect scope notice, the October 3 paywall notice, the
October 8 build-32 paywall rejection, and the October 8 suspension. The source
has relevant fixes, but none of these are called resolved for Android 33 until
artifact- and account-level evidence exists. The suspension appeal remains an
owner-managed store action.

## Source facts to validate for build 33

- `android/app/build.gradle.kts` sets `compileSdk = 36`, `targetSdk = 36`, and
  `minSdk = 26`. This meets the current Google Play API-level rule for mobile
  app updates, but is only source evidence.
- The checked-in main manifest declares only Health Connect reads for Steps,
  Distance, and Active Calories. The previously rejected Body Fat, Resting
  Heart Rate, and Sleep Session permissions are absent from source manifests.
  A merged release manifest still needs to be captured from the final build.
- The lockfile pins `in_app_purchase_android` 0.5.2. Its installed package
  source declares `com.android.billingclient:billing:8.0.0`. Source and lock
  evidence do not prove the final AAB dependency graph or Play product setup.
- The source catalog contains `bil_premium`, `bil_premium_annual`,
  `bil_premium_ai_coach`, `bil_premium_ai_coach_annual`, and `bil_ai_boost`.
  These identifiers must be compared with the live Play Console products and
  subscription base plans; that read-only Console check has not been completed.
- Release configuration uses AGP 9.0.1, 64-bit `arm64-v8a` and `x86_64`, and
  excludes the known 4 KB-only `armeabi-v7a` scanner binary. The workflow has
  an AAB/bundletool/ELF alignment evidence gate. No build-33 AAB or 16 KB
  runtime test exists, so 16 KB support is not claimed as verified.
- Main source removes legacy external-storage and advertising-personalization
  permissions at manifest merge and requests camera/microphone only for their
  feature journeys. The final merged manifest and store Data Safety/App Access
  declarations still need comparison with the exact artifact and active SDKs.
- Purchase checkout, entitlement loading, Goals/Plans routing, retry behavior,
  and subscription restore have source tests. A real review account with a
  server-verified Premium entitlement and AI balance has not been tested on
  build 33; Play store items, country, account, and service state are unverified.

## Immutable build bindings

After all relevant focused tests and full analysis pass, and after an exact
reviewer-access artifact test is available, set
`BIL_ANDROID_V33_AUDITED_SOURCE_SHA` and
`BIL_IOS_V36_AUDITED_SOURCE_SHA` to the same final accepted commit. Set
`BIL_ANDROID_V33_STAGING_MANIFEST_SHA256` to this file's committed-byte SHA-256
only after updating the completion fields and final evidence. The workflow
rejects an incomplete manifest, mismatched source SHA, or any build number other
than 33. Do not set these GitHub variables or dispatch a signed build from this
preparation record.

No Play Console, production, account entitlement, pricing, trial, or release
track was changed here. Build 32 and the currently delivered binary were not
modified by these source edits.
