# BIL Android 1.0.0 build 14 — release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 14`

## Release identity and scope

This corrective candidate follows Android build 13. It contains the approved
native OAuth return-to-app work, profile-photo recovery, AI Coach
refresh/typing stability, Food Log search and visual-evidence updates, and
the shared cross-platform application changes. iOS-only HealthKit changes do
not alter the Android health-connection path.

AdMob and pricing changes remain deferred. The shared Flutter source version
remains `1.0.0+8`; the signed Android workflow explicitly supplies
`--build-number 14`, which becomes `versionCode 14` while `versionName` remains
`1.0.0`.

The binding is not self-referential: after this commit is pushed,
`BIL_ANDROID_V14_AUDITED_SOURCE_SHA` must equal the exact pushed commit and
`BIL_ANDROID_V14_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. The workflow independently checks source, manifest, and build number.
Older source bindings, manifests, and release artifacts remain unchanged.

## Verification boundaries

The serialized Flutter suite for this checkout completed with exit code zero
over 970 discovered test files. That is source-test evidence only; it does not
claim a physical-device result, a signed AAB, a Google Play upload, or a server
deployment.

Signed CI additionally runs the configuration validator, analyzer, portable
source tests, signing, and Android package gates. Native runtime checks are
optional and remain a separate request.
