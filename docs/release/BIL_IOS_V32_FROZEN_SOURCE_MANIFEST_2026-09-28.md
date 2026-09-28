# BIL iOS 1.0.0 build 32 — unified release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 32`

## Release identity and source boundary

iOS build 32 replaces the already-uploaded build 31 while preserving the same
host-validated application source and Android build 29 lineage. The increment
is required solely because App Store Connect does not accept a reused
`CFBundleVersion`.

The signed workflow supplies `--build-number 32`, producing
`CFBundleVersion 32`; the marketing version remains `1.0.0`. TestFlight upload
occurs only when the owner explicitly dispatches with
`upload_to_testflight=true`.

After the release-binding commit is pushed,
`BIL_IOS_V32_AUDITED_SOURCE_SHA` must equal that commit and
`BIL_IOS_V32_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. `BIL_ANDROID_V29_AUDITED_SOURCE_SHA` identifies the matching audited
Android application source.

## Validation boundary

The application source validation completed on 2026-09-28: `flutter analyze`
reported no issues and the comprehensive Flutter suite completed with 5,532
passing tests, 6 intentional skips, and 0 failures. The focused AI Coach,
commerce, navigation, and Quick Add regressions also passed after the final
repairs.

Signed IPA creation, signed-IPA crypto scanning, App Store Connect validation,
TestFlight processing, device validation, App Review submission, and public
release remain separate evidence and authorization boundaries. This dispatch
authorizes TestFlight upload only; it does not authorize App Review submission
or public release.
