# BIL iOS 1.0.0 build 12 — release source manifest

## Machine-readable release markers

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 12`

## Release identity

This manifest is the iOS App Store candidate for build 12. The signed
workflow passes `--build-number 12`, so the archive and IPA use
`CFBundleVersion 12`. The shared Flutter source remains `1.0.0+8`; the iOS
workflow override is the authoritative App Store build identity.

The signed workflow binds this file's SHA-256 and the exact checked-out commit
through `BIL_IOS_V12_STAGING_MANIFEST_SHA256` and
`BIL_IOS_V12_AUDITED_SOURCE_SHA`. A build is accepted only when both bindings
match the commit and manifest used by GitHub Actions; the bindings must be set
after this commit is pushed.

## Scope

This unified candidate includes the verified Community Social v2 and public
BIL Code path, AI Coach conversation and navigation responsiveness, trusted
cloud food search and 25-language presentation, dashboard and splash recovery,
connected-health synchronization and Apple Watch signal provenance, purchase
verification hardening, nutrition macro editing, and the generated runtime-copy
closure. The portable release suite, Flutter analysis, signing checks,
archive/IPA inspection, and Xcode 26 toolchain gate remain mandatory workflow
stages.

## Explicit boundaries

- The Community Guidelines URL remains
  `https://www.bilhealth.com/community-guidelines`; reviewer credentials stay
  only in private store metadata and are never committed.
- USDA external search remains fail-closed and server-backed. Secret values are
  not bundled in the app or this manifest.
- The workflow requires the Apple distribution certificate, provisioning
  profile, Team ID, App Store Connect API key fields, and mobile-integrity
  release binding. Secret values stay in GitHub Secrets.
- TestFlight processing, physical-device launch, HealthKit, StoreKit, and App
  Review remain external gates until their own evidence exists.
