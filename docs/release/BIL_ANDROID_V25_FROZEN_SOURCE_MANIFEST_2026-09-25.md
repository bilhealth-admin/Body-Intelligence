# BIL Android 1.0.0 build 25 — unified release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 25`

## Release identity and source boundary

Android build 25 is the next candidate after versionCode 24 and shares the
same final, host-validated source with iOS build 29. It contains the accepted
build-24/build-28 source plus the subsequent focused fixes for native Meta
authentication, onboarding, connected-health responsiveness, daily-log truth,
entitlement stability, AI Coach voice/composer presentation, and localization.

The workflow supplies `--build-number 25`, producing `versionCode 25` while
`versionName` remains `1.0.0`.

After the final integration commit is pushed,
`BIL_ANDROID_V25_AUDITED_SOURCE_SHA` must equal that commit and
`BIL_ANDROID_V25_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. The counterpart iOS variable must name the same commit. Source,
manifest, and expected build number are independently checked; the binding is
not self-referentially embedded in the commit it validates.

## Validation boundary

The complete local host suite passed before this freeze. The signed workflow
still independently validates source, configuration, signing certificate,
package identity, SDK level, optional hardware, 16 KB packaging, and ELF
alignment. This manifest does not claim Google Play upload or publication.
