# BIL Android 1.0.0 build 14 — release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 14`

## Release identity and scope

This candidate is the current GitHub release branch with the Android build
number advanced from 13 to 14. It also closes the Android cold-start OAuth
return gap: a Google callback delivered while the app is being launched is
read once after the app-link stream is attached and passed through the same
verified callback controller.

The existing HTTPS callback allow-list, Supabase exchange, and account
startup policy remain unchanged. No credentials, store data, or production
records are changed by this source update.

The signed workflow overrides the shared Flutter version with
`--build-number 14` / `versionCode 14`.

The binding is intentionally external: after this commit is pushed,
`BIL_ANDROID_V14_AUDITED_SOURCE_SHA` must equal the commit and
`BIL_ANDROID_V14_STAGING_MANIFEST_SHA256` must equal this file's committed
SHA-256. The workflow does not publish to Google Play automatically.

## Verification boundaries

Focused OAuth callback and release-configuration contract tests are required
before dispatch. Device return from a Play-signed install remains a runtime
verification step.
