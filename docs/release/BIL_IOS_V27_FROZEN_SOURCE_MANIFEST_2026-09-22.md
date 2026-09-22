# BIL iOS 1.0.0 build 27 — unified release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 27`

## Release identity and scope

iOS build 27 is the next candidate after build 26, which is already present
in TestFlight and must not be uploaded again. It uses the unified candidate
source derived from the successful build-25/Android-20 baseline and contains
only the subsequently reviewed fixes, including stable connected-health sync,
Android authentication parity, Today and AI Coach corrections, purchase
hardening, and the complete Guideline 1.4.1 health-evidence remediation.

The signed iOS workflow supplies `--build-number 27`, producing
`CFBundleVersion 27` while the public version remains `1.0.0`. Upload is
allowed only after source, analysis, tests, signing, package, entitlement and
App Store Connect validation gates pass.

The binding is not self-referential: after this manifest and the final source
commit are pushed, `BIL_IOS_V27_AUDITED_SOURCE_SHA` must equal that exact
commit and `BIL_IOS_V27_STAGING_MANIFEST_SHA256` must equal this file's
committed-byte SHA-256. The workflow independently validates source, manifest
and build number.

## Review and evidence boundaries

The health-evidence implementation is documented in
`BIL_IOS_V27_GUIDELINE_1_4_1_AND_PURCHASE_REVIEW_NOTES_2026-09-22.md`.
Automated source checks do not claim that StoreKit sandbox lifecycle tests ran
on physical hardware, that production migrations were deployed, or that the
IPA was accepted by TestFlight or App Review. Those remain separately recorded
release results.

The final unified source SHA is intended to build:

- iOS 1.0.0, CFBundleVersion 27.
- Android 1.0.0, versionCode 22.

Final local source validation before freezing: Flutter analysis reported no
issues; the complete Flutter suite reported 5,456 passed, 6 intentionally
skipped, and 0 failed. These results validate source only and do not replace
the signed GitHub Actions, TestFlight, or App Review evidence.
