# BIL Android 1.0.0 build 29 — unified release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 29`

## Release identity and source boundary

Android build 29 replaces the already-uploaded versionCode 28 while preserving
the same host-validated application source and iOS build 32 lineage. The
increment is required solely because Google Play does not accept a reused
versionCode.

The signed workflow supplies `--build-number 29`, producing versionCode 29;
the marketing version remains `1.0.0`.

After the release-binding commit is pushed,
`BIL_ANDROID_V29_AUDITED_SOURCE_SHA` must equal that commit and
`BIL_ANDROID_V29_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. `BIL_IOS_V32_AUDITED_SOURCE_SHA` must name the same commit.

## Validation boundary

The application source validation completed on 2026-09-28: `flutter analyze`
reported no issues and the comprehensive Flutter suite completed with 5,532
passing tests, 6 intentional skips, and 0 failures. The focused AI Coach,
commerce, navigation, and Quick Add regressions also passed after the final
repairs.

Signed AAB creation, signed-AAB crypto scanning, Play Console processing,
device validation, review submission, and public release remain separate
evidence and authorization boundaries. This workflow produces a signed release
candidate artifact; it does not publish it to Google Play.
