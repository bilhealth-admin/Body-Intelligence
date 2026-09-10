# BIL iOS 1.0.0 build 13 — release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 13`

## Release identity and scope

This source-only candidate preserves the complete code audit in
`3e1ab6b12dbab099a1424bf0e47ffb5b7229bd40`, including administrative Premium
grants, purchase isolation, HealthKit permission ordering, Apple login sizing,
and the owner's nutrition/navigation decisions. The preparation commit only
updates release configuration, its tests, and explicit code-only CI selection.
The dormant manual QA workflow also resolves runner-local paths inside steps
instead of using an unavailable job-level expression context; it is not run.
The shared Flutter version remains `1.0.0+8`; the signed workflow passes
`--build-number 13`, producing iOS `CFBundleVersion 13`.

The binding is not self-referential: after the preparation commit is pushed,
`BIL_IOS_V13_AUDITED_SOURCE_SHA` must equal that exact commit and
`BIL_IOS_V13_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. Source, manifest, and expected build number are independently checked.
Older V12 bindings and release artifacts remain unchanged.

## Verification boundaries

The code audit is recorded in `../qa/FINAL_PREBUILD_CODE_AUDIT_2026-09-10.md`.
Signed CI requires Xcode/iOS SDK 26+, analyzer, code-only portable tests,
configuration and signing checks, IPA/entitlement validation, and App Store
Connect validation. The initial dispatch does not upload to TestFlight or
submit App Review. Simulator and visual/image checks are NOT RUN in this
owner-requested phase; excluded tests are not passes. AdMob remains deferred.

This manifest does not claim an IPA exists or that HealthKit, StoreKit,
accessibility, or any device flow passed. This build does not deploy pending
Supabase/Worker changes; server publication and its verification are separate.
