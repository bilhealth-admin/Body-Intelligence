# BIL iOS 1.0.0 build 11 — release source manifest

## Machine-readable release markers

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 11`

## Release identity

This manifest is the iOS App Store candidate for build 11. Build 10 already
exists in TestFlight and must not be reused. The signed workflow passes
`--build-number 11`, so the archive and IPA use `CFBundleVersion 11`.

The workflow binds this file's SHA-256 and the exact checked-out commit through
the repository variables `BIL_IOS_V11_STAGING_MANIFEST_SHA256` and
`BIL_IOS_V11_AUDITED_SOURCE_SHA`. A build is accepted only when both bindings
match the commit and manifest used by GitHub Actions.

## Scope

This unified candidate includes the verified Community Social v2 and community
policy acceptance path, community/friend/AI Coach language and conversation
polish, trusted cloud food search and 25-language presentation, dashboard and
navigation corrections, purchase verification hardening, App Attest and
backend security reconciliation, and the reviewed visual Golden baselines.
The portable release suite, Flutter analysis, signing checks, archive/IPA
inspection, and Xcode 26 toolchain gate remain mandatory workflow stages.

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
