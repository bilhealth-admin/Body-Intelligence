# BIL Android 1.0.0 build 22 — unified release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 22`

## Release identity and source boundary

Android build 22 is the next candidate after versionCode 21, which is already
present in Google Play and must not be uploaded again. It uses the same final
unified source as iOS build 27 and retains the reviewed Google OAuth release
certificate fix, cache-first connected-health behavior, purchase ownership and
restore safeguards, Today and AI Coach corrections, and health-evidence
disclosures.

The Android release workflow supplies `--build-number 22`, producing
`versionCode 22` while `versionName` remains `1.0.0`.

The binding is not self-referential: after the final unified source commit is
pushed, `BIL_ANDROID_V22_AUDITED_SOURCE_SHA` must equal that exact commit and
`BIL_ANDROID_V22_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. Source, manifest and expected build number are independently checked.

## Android runtime and review scope

- compileSdk and targetSdk remain 36; minSdk remains 26.
- Play Integrity is required for the production release configuration.
- Health Connect remains feature-scoped and user revocable.
- Advertising remains disabled in this release configuration.
- Store prices, offers and trial eligibility remain store-derived.
- Purchase, restore, renewal, refund and AI Boost ownership remain
  server-verified and account-scoped.

This manifest does not claim that the signed AAB has been uploaded, installed
or approved. Signed CI, device testing and Google Play review remain separate
release evidence.

Final local source validation before freezing: Flutter analysis reported no
issues; the complete Flutter suite reported 5,456 passed, 6 intentionally
skipped, and 0 failed. These results validate source only and do not claim that
the signed AAB has been installed or published.
