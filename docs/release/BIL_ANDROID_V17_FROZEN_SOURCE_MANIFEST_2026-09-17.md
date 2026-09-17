# BIL Android 1.0.0 build 17 — unified release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 17`

## Release identity and source boundary

Android build 17 is the next candidate after build 16 and uses the same final
unified source as iOS build 20. It includes the reviewed Health Connect scope,
Apple/Google purchase entitlement safeguards shared by the app, and the
dashboard, accessibility, premium-content, and native-permission corrections.

The Android release workflow overrides the shared Flutter version with
`--build-number 17`, producing `versionCode 17` while `versionName` remains
`1.0.0`.

The binding is not self-referential: after this final unified source commit is
pushed, `BIL_ANDROID_V17_AUDITED_SOURCE_SHA` must equal that exact commit and
`BIL_ANDROID_V17_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. Source, manifest and expected build number are independently checked.

## Android runtime and review scope

- compileSdk and targetSdk remain 36; minSdk remains 26.
- Play Integrity is required in production release builds.
- Health Connect access remains feature-scoped, user revocable and policy
  declared only for the data types used by the submitted binary.
- Contextual/deferred ads remain disabled from the release configuration and
  advertising identifiers and ad-service permissions remain removed.
- The signed AAB remains subject to package, optional-hardware and 16 KB/ELF
  alignment checks.
- Store reviewer access, purchase restore, subscription management and
  device-store pricing remain available.

## Console and runtime boundaries

This manifest does not claim that the AAB has been uploaded, reviewed or run on
a physical device. Before Play review, the Play Console Health Apps
declaration, Data Safety, reviewer access, subscription/trial metadata and
public listing must match this binary. Signed CI and device/store testing
remain distinct evidence.
