# BIL iOS 1.0.0 build 25 — unified release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 25`

## Release identity and scope

iOS build 25 is the next candidate after build 24, which is already present
in App Store Connect and cannot be uploaded again. It uses the unified source
tree at the audited commit and includes the authentication, dashboard,
connected-health, purchase, community, Food Log, AI Coach, and localization
corrections carried by that tree.

The signed iOS workflow supplies `--build-number 25`, which becomes
`CFBundleVersion 25` while the public version remains `1.0.0`. Its manual
dispatch requires uploading only the validated, signed IPA to TestFlight;
the upload step remains downstream of all source, signing and App Store
Connect validation gates.

The binding is not self-referential: after this manifest and the final source
commit are pushed, `BIL_IOS_V25_AUDITED_SOURCE_SHA` must equal that exact
commit and `BIL_IOS_V25_STAGING_MANIFEST_SHA256` must equal this file's
committed-byte SHA-256. The workflow independently checks source, manifest
and build number.

## Review boundaries outside source

This manifest does not claim that a StoreKit sandbox purchase, refund, trial
expiry or restore has succeeded on a physical device, that a production
Supabase migration has been deployed, or that the IPA has been accepted by
TestFlight or App Review. Those remain external release checks.

The final unified source SHA is intended to build:

- iOS 1.0.0, CFBundleVersion 25.
- Android 1.0.0, versionCode 19.

## Verification boundary

Source and contract checks prove checked-in behavior only. Signed CI still
validates the release configuration, analyzer, portable source suite, signing,
IPA/entitlements and App Store Connect package requirements. Physical-device,
TestFlight and live-store behavior remain separate runtime evidence.
