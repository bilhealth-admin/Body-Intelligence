# BIL ANDROID 1.0.0 build 30 — frozen Community source candidate

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 30`

## Source and scope

Base: `9f439cae97d72b784880a1b1ac4ef1d33ede30c1` (Android 29 / iOS 32).
This is a new source candidate, not a rename of an already-built binary.
Changes cover Facebook Android OAuth routing, push compile flags, exact unread
counts, visible-message read receipts, Community/More badges and scoped polish.
Google and iOS Facebook login paths, purchases, Health and diary are unchanged.
The already-deployed QR fix is retained in migration history.

## Source freeze evidence and boundary

The runtime/test source was verified at
`d6319d1333c4ffba2df02581f1bb09fa8c24eecd` in successful run
https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/36600429394
All six jobs passed: formatting, analysis, existing performance budgets, four
complete partitions of the portable code-only selection, and visual/cloud tests.
Detailed counts and scope exclusions are in BIL_COMMUNITY_3033_QA_EVIDENCE_2026-09-29.md.

This freeze commit changes only the two candidate manifests and their QA record;
no application, native, cloud or test code is changed from that green source.
Its own exact-commit candidate QA must also be green before release bindings are
activated. YES means source frozen for signed-artifact QA, not store approval or
real-device acceptance. Signed native compilation, repeated Facebook sign-in,
notification permission, real push delivery and terminated-app routing remain
separate checks. A provider acceptance response is not proof of phone presentation.
No 29/32 test totals are inherited and no failed assertion is waived.

## Exact release bindings

`BIL_ANDROID_V30_AUDITED_SOURCE_SHA` must equal the final reviewed freeze commit,
`BIL_IOS_V33_AUDITED_SOURCE_SHA` must name the same commit, and
`BIL_ANDROID_V30_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. The hashes are computed after commit, not self-referentially embedded.
The values must be installed and checked before running the signed workflow;
this document does not assert that repository variables have been changed.
The workflow supplies `--build-number 30`; marketing version stays `1.0.0`.
No App Review, Play production release or TestFlight upload is authorized here.
