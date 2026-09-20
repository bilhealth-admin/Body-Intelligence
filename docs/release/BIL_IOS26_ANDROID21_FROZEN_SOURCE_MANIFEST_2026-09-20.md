# BIL iOS 26 / Android 21 release candidate manifest — 2026-09-20

## Machine-readable release markers

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER_IOS: 26`

`RELEASE_BUILD_NUMBER_ANDROID: 21`

## Candidate contract

This manifest is the local source contract for the platform-specific release
candidate. iOS and Android intentionally use separate store build numbers:
iOS `26` and Android `21`. The application identifiers remain
`com.bilhealth.bodyintelligencelog` on both platforms.

The source commit and this manifest's SHA-256 are bound externally by the
signed release workflow variables. No signing key, provisioning profile,
keystore, certificate, fingerprint, or store credential is embedded here.
The workflow supplies the audited source through `BIL_RELEASE_AUDITED_SOURCE_SHA`
and verifies this manifest through `BIL_RELEASE_MANIFEST_SHA256`.

The zero-failure automated evidence is recorded outside this self-referential
manifest. Device, store, signing, and external integrity evidence remains a
separate gate and must not be inferred from this file.
The manifest deliberately avoids a self-referential hash.
