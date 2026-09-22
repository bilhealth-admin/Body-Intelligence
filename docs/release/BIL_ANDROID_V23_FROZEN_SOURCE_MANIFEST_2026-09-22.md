# BIL Android 1.0.0 build 23 — corrected release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 23`

## Release identity and source boundary

Android build 23 replaces the rejected upload of versionCode 22, which Google
Play reports as already used. No runtime, SDK, ABI, hardware-feature, or device
compatibility setting is changed by this versionCode-only release correction.

The Android release workflow supplies `--build-number 23`, producing
`versionCode 23` while `versionName` remains `1.0.0`.

The binding is not self-referential: after the final corrected source commit is
pushed, `BIL_ANDROID_V23_AUDITED_SOURCE_SHA` must equal that exact commit and
`BIL_ANDROID_V23_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. Source, manifest, and expected build number are independently checked.

## Android runtime and review scope

- compileSdk and targetSdk remain 36; minSdk remains 26.
- The final AAB must retain arm64-v8a and x86_64 native libraries.
- Camera, microphone, location, Bluetooth, and Bluetooth LE remain optional.
- Play Integrity is required for the production release configuration.
- Health Connect remains feature-scoped and user revocable.
- Advertising remains disabled in this release configuration.
- Store prices, offers, and trial eligibility remain store-derived.
- Purchase, restore, renewal, refund, and AI Boost ownership remain
  server-verified and account-scoped.

Compatibility comparison against the working versionCode 21 final-AAB manifest
confirmed identical minSdk/targetSdk, identical optional hardware declarations,
and identical supported native ABIs. The 0-device Play display accompanied the
rejected versionCode 22 upload and is not supported by the signed-AAB evidence.

This manifest does not claim that the signed AAB has been uploaded, installed,
or approved. Signed CI, device testing, and Google Play processing remain
separate release evidence.
