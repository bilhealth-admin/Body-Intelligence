# BIL Android 1.0.0 build 11 — release source manifest

## Machine-readable release markers

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 11`

## Release identity

This manifest is the Android store candidate for Google Play build 11. The
signed workflow passes `--build-number 11`, so the generated AAB has
`versionCode 11`. The repository's shared Flutter source remains `1.0.0+8`;
the platform workflow override is the authoritative store identity.

The signed workflow binds this file's SHA-256 and the exact checked-out commit
through `BIL_ANDROID_V11_STAGING_MANIFEST_SHA256` and
`BIL_ANDROID_V11_AUDITED_SOURCE_SHA`. A build is accepted only when both
bindings match the commit and manifest used by GitHub Actions; the bindings
must be set after this commit is pushed. The binding is intentionally not self-referential:
the audited source commit and manifest digest are supplied
as protected repository variables after the final commit exists.

## Scope

This unified candidate includes the subscription monthly/annual interaction
fix, dashboard and navigation responsiveness corrections, connected-health
sync and step-history handling, Apple Watch signal provenance, Community
public-feed and BIL Code access, AI Coach conversation polish, nutrition macro
editing, trusted cloud food search, and the 25-locale runtime-copy closure.
The portable release suite, Flutter analysis, platform contract tests, signing
checks, 16 KB packaging checks, and Android native gates remain mandatory
workflow stages.

## Explicit boundaries

- USDA external search remains fail-closed and server-backed. Secret values are
  not bundled in the app or this manifest.
- A signed AAB, Play-installed closed-test run, Play Integrity evidence, and
  physical-device checks are separate gates; this source manifest does not
  claim any of them before the workflow produces evidence.
- The workflow requires the Android keystore inputs, upload certificate
  fingerprint, mobile-integrity release binding, and Play-linked Cloud project
  number. Secret values must stay in GitHub Secrets/Variables.
