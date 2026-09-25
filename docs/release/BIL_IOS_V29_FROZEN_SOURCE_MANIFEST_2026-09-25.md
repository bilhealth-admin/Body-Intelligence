# BIL iOS 1.0.0 build 29 — unified release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 29`

## Release identity and source boundary

iOS build 29 is the next candidate after build 28 and shares the same final,
host-validated source with Android build 25. It preserves the Apple privacy
consent closure while adding the subsequent focused fixes for native Meta
authentication, onboarding, connected-health responsiveness, daily-log truth,
entitlement stability, and AI Coach voice/composer presentation.

The signed workflow supplies `--build-number 29`, producing
`CFBundleVersion 29`; the marketing version remains `1.0.0`. This release run
may validate and upload the signed IPA to TestFlight only when the explicitly
provided workflow input `upload_to_testflight=true` is used.

After the final integration commit is pushed,
`BIL_IOS_V29_AUDITED_SOURCE_SHA` must equal that commit and
`BIL_IOS_V29_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. The counterpart Android variable must name the same commit. Source,
manifest, expected build number, signing, bundle identity, and entitlements are
independently checked; the binding is not self-referentially embedded in the
commit it validates.

## Validation boundary

The complete local host suite passed before this freeze. Signed IPA creation,
App Store Connect validation, TestFlight upload and processing remain separate
workflow evidence. This manifest does not authorize App Review submission or
public App Store release.
