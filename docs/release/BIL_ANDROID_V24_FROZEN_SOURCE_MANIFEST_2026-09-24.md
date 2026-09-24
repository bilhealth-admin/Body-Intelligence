# BIL Android 1.0.0 build 24 — unified release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 24`

## Release identity and source boundary

Android build 24 is the next candidate after versionCode 23. It is derived
from the exact build-27/Android-22 shared functional base
`14786b08fa24991ba7445e8c607a993413a840a6` and shares the final reviewed source
with iOS build 28.

The workflow supplies `--build-number 24`, producing `versionCode 24` while
`versionName` remains `1.0.0`.

After the final integration commit is pushed,
`BIL_ANDROID_V24_AUDITED_SOURCE_SHA` must equal that commit and
`BIL_ANDROID_V24_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. Source, manifest and expected build number are independently checked.
The binding is not self-referentially embedded in the commit it validates.

## Android runtime and review scope

- compileSdk and targetSdk remain 36; minSdk remains 26.
- Health Connect remains limited to steps, distance and active calories.
- Advertising and remote push remain disabled until their providers are ready.
- Store ownership remains server-verified and account-scoped.

This manifest does not claim that a signed AAB was built, uploaded, installed,
reviewed or published. Those remain separate release evidence.
