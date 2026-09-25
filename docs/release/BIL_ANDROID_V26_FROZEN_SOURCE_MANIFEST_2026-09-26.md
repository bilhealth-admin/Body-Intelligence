# BIL Android 1.0.0 build 26 — unified release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 26`

## Release identity and source boundary

Android build 26 is the next candidate after versionCode 25 and shares the
same final, host-validated source with iOS build 30. It preserves all accepted
release work and adds the verified shared Remote AI consent cache repair. The
AI Coach navigation-action repair is also present in source and deployed
independently to Production.

The workflow supplies `--build-number 26`, producing `versionCode 26` while
`versionName` remains `1.0.0`.

After the final integration commit is pushed,
`BIL_ANDROID_V26_AUDITED_SOURCE_SHA` must equal that commit and
`BIL_ANDROID_V26_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. The counterpart iOS variable must name the same commit. Source,
manifest, and expected build number are independently checked; the binding is
not self-referentially embedded in the commit it validates.

## Validation boundary

The complete local host suite passed before this freeze. The signed workflow
still independently validates source, configuration, signing certificate,
package identity, SDK level, optional hardware, 16 KB packaging, and ELF
alignment. This manifest does not claim Google Play upload or publication.
