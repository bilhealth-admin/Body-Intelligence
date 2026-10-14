# BIL iOS 1.0.0 build 36 — preparation record, not release freeze

`STAGING_MANIFEST_COMPLETE: NO`

`CANDIDATE_FROZEN_OR_ACCEPTED: NO`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 36`

## Release state

This local record aligns the signed-release workflow with the requested iOS
build 36 and Android build 33 pair. It is not a frozen source approval, signed
IPA, TestFlight upload, or App Store submission. No iOS artifact, TestFlight
reviewer session, current App Store Connect status, or device run was performed
for this preparation record. Google Play findings are tracked separately in the
Android 33 manifest and are not reclassified as Apple review findings.

The current full Flutter run completed on the preceding source SHA
`e27a58984bff50b4bcf45044ea9893f344307e85` with 9,791 pass, 22 failures,
2 errors, and 0 skipped. It cannot attest the fixes in the isolated snapshot.
Focused verification and full analysis remain pending before any final freeze.

## Immutable build bindings

After the source is clean and the exact iOS review artifact is validated, set
`BIL_IOS_V36_AUDITED_SOURCE_SHA` and
`BIL_ANDROID_V33_AUDITED_SOURCE_SHA` to the same final accepted commit. Set
`BIL_IOS_V36_STAGING_MANIFEST_SHA256` to this file's committed-byte SHA-256
only after updating the completion fields and final evidence. The signed iOS
workflow rejects an incomplete manifest, mismatched source SHA, or any build
number other than 36. Do not set these GitHub variables, build a signed IPA, or
upload to TestFlight from this preparation record.
