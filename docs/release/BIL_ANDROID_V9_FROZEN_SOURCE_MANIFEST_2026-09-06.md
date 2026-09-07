# BIL Android 1.0.0 build 9 — release source manifest

## Machine-readable release markers

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 9`

## Release identity

This manifest is the Android store candidate for Google Play build 9. The
workflow passes `--build-number 9`, so the generated AAB has `versionCode 9`.
The repository's shared Flutter source remains `1.0.0+8` because the iOS
candidate uses its own monotonically increasing App Store build number; the
platform workflow override is the authoritative store identity.

The signed workflow binds this file's SHA-256 and the exact checked-out commit
through the repository variables `BIL_ANDROID_V9_STAGING_MANIFEST_SHA256` and
`BIL_ANDROID_V9_AUDITED_SOURCE_SHA`. A build is not accepted until both
bindings match the commit and manifest used by GitHub Actions; the binding is
not self-referential because it is applied after the commit is created.

## Scope

This candidate includes the subscription monthly/annual interaction fix,
heart-health maximum color scale, connected step-history bars, quick-action
routing, cloud-sync entitlement correction, community/admin fixes, and the
existing iOS deferred-ads safety work. Today meal cards are intentionally
summary-free; each meal's foods and nutrition detail live on its dedicated
meal page. The portable release suite, Flutter
analysis, platform contract tests, signing checks, 16 KB packaging checks, and
the Android native gates remain mandatory workflow stages.

## Explicit boundaries

- USDA external search is fail-closed and server-backed. Supabase currently
  has both `BIL_USDA_API_KEY` and `BIL_TRANSLATION_API_KEY`, and deployed
  `food-search` version 14 serves the authenticated multilingual search path.
  Secret values are not bundled in the app or this manifest.
- A signed AAB, Play-installed closed-test run, Play Integrity evidence, and
  physical-device checks are separate gates; this source manifest does not
  claim any of them before the workflow produces evidence.
- The workflow requires the Android keystore inputs, upload certificate
  fingerprint, mobile-integrity release binding, and Play-linked Cloud project
  number. Secret values must stay in GitHub Secrets/Variables.
