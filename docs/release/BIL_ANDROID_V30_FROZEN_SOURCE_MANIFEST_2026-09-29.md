# BIL Android 1.0.0 build 30 — frozen Sapphire source candidate

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 30`

## Source and scope

Native 29/32 base: `9f439cae97d72b784880a1b1ac4ef1d33ede30c1`.
Retained Community, QR, Facebook and push corrections: `59839c7deb4d1cc860275b9e69578e299cc24d0a`.
Verified Sapphire runtime and test source: `5da2bbf3a3fbb17a05a18106a243b865aa862aa9`.
Working branch: `fix/community-sapphire-health-3033`.
The changes cover Community-only Sapphire presentation, local athlete welcome,
shared unread indicators, accessible conversations, and daily energy/heart
history projections. Raw health records, native queries, Watch permissions,
current-value card, dashboard, purchases and native iOS/Google login are preserved.

## Verified source acceptance

Run https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/36640466225
completed every full-suite shard successfully on the runtime source above.
All 1,032 discovered test files were scheduled with no path exclusions or name
filters: 5,654 visible Flutter cases passed, zero failed, six existing conditional
cases were skipped. This total includes the two isolated performance cases and
does not double-count the 294 focused or eight visual cases rerun separately.
The 120 actual-widget captures and 14 scoped Community reference images were
reviewed. Only ten intentionally changed Community masters were replaced; all
non-Community masters and strict comparators remain intact. Isolated SQL: 22
assertions passed. Mocked provider tests: 12 passed. See the source acceptance
record for exact skip names, evidence provenance and platform limits.

This freeze changes only the two source manifests and the acceptance record.
The resulting final commit must pass its own exact-commit QA before its build
bindings are used. YES means source frozen for signed artifact testing, not
native build, physical-device, medical or store approval. The 100-bpm marker is
informational, not a background alarm or a diagnosis. Completed-day summaries
refresh on the next load/sync; no guaranteed midnight execution is claimed.

## Immutable release bindings

`BIL_ANDROID_V30_AUDITED_SOURCE_SHA` and `BIL_IOS_V33_AUDITED_SOURCE_SHA` must name
the same final verified freeze commit. `BIL_ANDROID_V30_STAGING_MANIFEST_SHA256`
must match this file's committed-byte SHA-256. Values are computed after commit,
not self-referentially embedded. A dedicated dispatch-control branch may pin
those same immutable values in the existing signed workflows without changing
the source checked out for compilation. Prior 29/32 or 59839 bindings are invalid.
The workflow supplies build number 30 and version 1.0.0. No signed binary, Play
rollout, TestFlight upload or App Review submission is authorized by this record.
