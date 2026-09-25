# BIL iOS 1.0.0 build 30 — unified release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 30`

## Release identity and source boundary

iOS build 30 is the next candidate after build 29 and shares the same final,
host-validated source with Android build 26. It preserves all accepted release
work and adds the focused HealthKit fair-pagination repair plus the verified
Remote AI consent cache repair. The AI Coach navigation-action repair is also
present in source and deployed independently to Production.

The signed workflow supplies `--build-number 30`, producing
`CFBundleVersion 30`; the marketing version remains `1.0.0`. This release run
may validate and upload the signed IPA to TestFlight only when the explicitly
provided workflow input `upload_to_testflight=true` is used.

After the final integration commit is pushed,
`BIL_IOS_V30_AUDITED_SOURCE_SHA` must equal that commit and
`BIL_IOS_V30_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. The counterpart Android variable must name the same commit. Source,
manifest, expected build number, signing, bundle identity, and entitlements are
independently checked; the binding is not self-referentially embedded in the
commit it validates.

## Validation boundary

The complete local host suite passed before this freeze. Signed IPA creation,
App Store Connect validation, TestFlight upload and processing remain separate
workflow evidence. This manifest does not authorize App Review submission or
public App Store release.
