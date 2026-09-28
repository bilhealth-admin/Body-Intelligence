# BIL Android 1.0.0 build 27 — unified release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 27`

## Release identity and source boundary

Android build 27 is the next candidate after versionCode 26 and shares the
same final, host-validated source with iOS build 31. It preserves the accepted
30/26 lineage and layers the current local reliability, connected-health, AI
Coach, navigation, localization, commerce, and release-audit repairs above it.

The signed workflow supplies `--build-number 27`, producing `versionCode 27`;
`versionName` remains `1.0.0`.

After the final integration commit is pushed,
`BIL_ANDROID_V27_AUDITED_SOURCE_SHA` must equal that commit and
`BIL_ANDROID_V27_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. `BIL_IOS_V31_AUDITED_SOURCE_SHA` must name the same commit. These
bindings are intentionally set only after the comprehensive host suite passes.
The manifest digest is bound externally by the release workflow, not self-referentially
inside this manifest.

## Validation boundary

The final local host validation completed on 2026-09-28: `flutter analyze`
reported no issues and the comprehensive Flutter suite completed with 5,520
passing tests, 6 intentional skips, and 0 failures. The focused AI Coach,
commerce, navigation, and Quick Add regressions also passed after the final
repairs.

Signed AAB creation, signing validation, Play upload, device validation, store
review, and public release remain separate evidence and authorization
boundaries.
