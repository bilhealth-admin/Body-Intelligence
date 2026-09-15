# BIL iOS 1.0.0 build 18 — unified review-ready source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 18`

## Release identity and scope

iOS build 18 is the next corrective candidate after build 17. It keeps the
current shared application stability work and the Apple-review corrections
already present in source: Sign in with Apple does not force a second identity
entry step, camera permission entry points no longer use the rejected
dismissible pre-permission prompt, iOS onboarding does not stage HealthKit
authorization, and health-information surfaces expose reviewable sources and
methodology.

The shared source also includes the current AI Coach retained-surface/silent
refresh protections, responsive health synchronization, bounded HealthKit reads,
off-UI-isolate meal-image preprocessing, localized camera/food-search copy, and
the canonical `bil_ai_boost` product alignment used by the store backend.

The signed iOS workflow supplies `--build-number 18`, which becomes
`CFBundleVersion 18` while the public version remains `1.0.0`.

The binding is not self-referential: after the final unified source commit is
pushed, `BIL_IOS_V18_AUDITED_SOURCE_SHA` must equal that exact commit and
`BIL_IOS_V18_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. The workflow independently checks source, manifest and build number.

## Review boundaries outside source

This manifest does not claim that App Store Connect promotional IAP artwork has
been corrected, that a production Supabase migration has been deployed, that a
StoreKit sandbox purchase has succeeded, or that a signed IPA has been uploaded
or resubmitted. Those are external release checks and must be verified before
submission.

The final unified source SHA is intended to build:

- iOS 1.0.0, CFBundleVersion 18.
- Android 1.0.0, versionCode 15.

## Verification boundary

Source and contract tests can prove the checked-in behavior and release
configuration only. Signed CI must still validate the configuration, analyzer,
portable source suite, signing, IPA/entitlements and App Store Connect package
requirements. Physical-device/TestFlight behavior and live StoreKit/Supabase
state remain separate runtime evidence.
