# BIL iOS 1.0.0 build 10 — release source manifest

## Machine-readable release markers

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 10`

## Release identity

This manifest is the iOS App Store candidate for build 10. The signed
workflow passes `--build-number 10`, so the archive and IPA use
`CFBundleVersion 10`. The previous iOS 9 startup-hotfix manifest remains
historical and is not reused by this candidate.

The signed workflow binds this file's SHA-256 and the exact checked-out commit
through the repository variables `BIL_IOS_V10_STAGING_MANIFEST_SHA256` and
`BIL_IOS_V10_AUDITED_SOURCE_SHA`. A build is not accepted until both bindings
match the commit and manifest used by GitHub Actions.

## Scope

This candidate includes the subscription monthly/annual interaction fix,
heart-health maximum color scale, connected step-history bars, quick-action
routing, cloud-sync entitlement correction, community/admin fixes, and the
deferred native-ads graph correction that prevents the prior startup crash.
Today meal cards are intentionally summary-free; each meal's foods and
nutrition detail live on its dedicated meal page.
The workflow keeps pre-archive and post-archive native graph checks, Apple
signing validation, IPA artifact checks, and the optional Simulator crypto gate.

## Explicit boundaries

- USDA external search is fail-closed and server-backed. Supabase currently
  has both `BIL_USDA_API_KEY` and `BIL_TRANSLATION_API_KEY`, and deployed
  `food-search` version 14 serves the authenticated multilingual search path.
  Secret values are not bundled in the app or this manifest.
- The workflow requires the Apple distribution certificate, provisioning
  profile, Team ID, App Store Connect API key fields, and mobile-integrity
  release binding. Secret values must stay in GitHub Secrets.
- A signed IPA, TestFlight processing, physical-device launch, HealthKit,
  StoreKit, and App Review are separate external gates; this source manifest
  does not claim them before the workflow produces evidence.
