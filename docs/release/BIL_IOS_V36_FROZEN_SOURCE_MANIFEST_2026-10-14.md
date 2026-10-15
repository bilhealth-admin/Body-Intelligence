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

The latest full Flutter evidence is for application-source commit
`ef4b9f19f491426ba8663ba1a9d76f9af6fe0c67` with source-input fingerprint
`80087ad7b2ef76192e9f22c5be0af34edc53dfc2139eb1b63ad81eaf7416614e`:
9,843 passed, 0 failed, 0 errors, 0 skipped across 1,356 test files, followed
by full `flutter analyze --no-pub` with `No issues found!`. The matching focused
GitHub run is [38653187976](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38653187976).
The 15 October audit adds workflow/security and Cloudflare dependency changes;
it does not change Dart source, tests, or Flutter dependencies. See
`../qa_next/BIL_MAXIMUM_TEST_COVERAGE_REGISTER_20261015.md` for exact scope and
evidence boundaries.

This result does not complete the release manifest: there is still no iOS 36
signed IPA, TestFlight upload, or current App Store Connect/device validation.
The manifest remains `STAGING_MANIFEST_COMPLETE: NO` and
`CANDIDATE_FROZEN_OR_ACCEPTED: NO`.

## Immutable build bindings

After the source is clean and the exact iOS review artifact is validated, set
`BIL_IOS_V36_AUDITED_SOURCE_SHA` and
`BIL_ANDROID_V33_AUDITED_SOURCE_SHA` to the same final accepted commit. Set
`BIL_IOS_V36_STAGING_MANIFEST_SHA256` to this file's committed-byte SHA-256
only after updating the completion fields and final evidence. The signed iOS
workflow rejects an incomplete manifest, mismatched source SHA, or any build
number other than 36. Do not set these GitHub variables, build a signed IPA, or
upload to TestFlight from this preparation record.
