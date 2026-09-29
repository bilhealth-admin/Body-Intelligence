# BIL ANDROID 1.0.0 build 30 — Community candidate

`STAGING_MANIFEST_COMPLETE: NO`

`CANDIDATE_FROZEN_OR_ACCEPTED: NO`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 30`

## Source and scope

Base: `9f439cae97d72b784880a1b1ac4ef1d33ede30c1` (Android 29 / iOS 32).
This is a new candidate, not a rename of an already-built binary.
Changes cover Facebook Android OAuth routing, push compile flags, exact unread
counts, visible-message read receipts, Community/More badges and scoped polish.
Google and iOS Facebook login paths, purchases, Health, diary and QR semantics
are not changed. The already-deployed QR fix is retained in migration history.

## Honest acceptance boundary

This candidate is not frozen yet. The recorded QA run for its actual commit,
source review and correct build bindings must be checked before changing the
NO/NO gates together. No test totals from build 29/32 are inherited.
Signed native builds and real-device login/push delivery are separate checks.
A successful provider response alone is not proof of phone presentation.

After freezing the actual reviewed commit,
`BIL_ANDROID_V30_AUDITED_SOURCE_SHA` must equal that commit,
`BIL_IOS_V33_AUDITED_SOURCE_SHA` must name the same commit, and
`BIL_ANDROID_V30_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. These bindings must not be guessed or self-referentially embedded.
The workflow supplies `--build-number 30`; marketing version stays `1.0.0`.
No App Review, Play production release or TestFlight upload is authorized here.
