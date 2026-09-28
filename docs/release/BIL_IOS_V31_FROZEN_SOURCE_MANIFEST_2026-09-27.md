# BIL iOS 1.0.0 build 31 — unified release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 31`

## Release identity and source boundary

iOS build 31 is the next candidate after build 30 and shares the same final,
host-validated source with Android build 28. It preserves the accepted 30/26
lineage and layers the current local reliability, connected-health, AI Coach,
navigation, localization, commerce, and release-audit repairs above it.

The signed workflow supplies `--build-number 31`, producing
`CFBundleVersion 31`; the marketing version remains `1.0.0`. TestFlight upload
occurs only when the owner explicitly dispatches with
`upload_to_testflight=true`.

After the final integration commit is pushed,
`BIL_IOS_V31_AUDITED_SOURCE_SHA` must equal that commit and
`BIL_IOS_V31_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. `BIL_ANDROID_V28_AUDITED_SOURCE_SHA` must name the same commit. These
bindings are intentionally set only after the comprehensive host suite passes.

## Validation boundary

The final local host validation completed on 2026-09-28: `flutter analyze`
reported no issues and the comprehensive Flutter suite completed with 5,526
passing tests, 6 intentional skips, and 0 failures. The focused AI Coach,
commerce, navigation, and Quick Add regressions also passed after the final
repairs.

Signed IPA creation, the native iOS Simulator crypto gate, signed-IPA crypto
scanning, App Store Connect validation, TestFlight processing, device
validation, App Review submission, and public release remain separate evidence
and authorization boundaries. This dispatch authorizes TestFlight upload only;
it does not authorize App Review submission or public release.
