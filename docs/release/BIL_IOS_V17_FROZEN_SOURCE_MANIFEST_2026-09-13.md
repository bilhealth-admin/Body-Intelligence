# BIL iOS 1.0.0 build 17 — release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 17`

## Release identity and scope

This corrective candidate follows the uploaded iOS build 16 candidate. It
contains the approved native OAuth return-to-app work, iPhone HealthKit
synchronization resilience and Apple Watch data-source handling, AI Coach
refresh/typing stability, profile-photo recovery, and Food Log search and
visual-evidence updates. Existing Daily Log meal routes remain intact.

AdMob remains deferred. The shared Flutter source version remains `1.0.0+8`;
the signed iOS workflow explicitly supplies `--build-number 17`, which becomes
`CFBundleVersion 17` while the public version remains `1.0.0`.

The binding is not self-referential: after this commit is pushed,
`BIL_IOS_V17_AUDITED_SOURCE_SHA` must equal the exact pushed commit and
`BIL_IOS_V17_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. The workflow independently checks source, manifest, and build number.
Older source bindings, manifests, and release artifacts remain unchanged.

## Verification boundaries

The serialized Flutter suite for this checkout completed with exit code zero
over 970 discovered test files. That is source-test evidence only; it does not
claim a physical-device result, an IPA, a TestFlight upload, App Review
approval, or a server deployment.

Signed CI additionally runs the configuration validator, analyzer, portable
source tests, signing, IPA/entitlement checks, and App Store Connect
validation. Native runtime checks are optional and remain a separate request.
