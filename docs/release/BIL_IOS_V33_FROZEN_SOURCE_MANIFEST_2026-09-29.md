# BIL iOS 1.0.0 build 33 — Sapphire source candidate under verification

`STAGING_MANIFEST_COMPLETE: NO`

`CANDIDATE_FROZEN_OR_ACCEPTED: NO`

`UNRESOLVED_REVIEW_COUNT: 1`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 33`

## Scope and ancestry

Native 29/32 base: `9f439cae97d72b784880a1b1ac4ef1d33ede30c1`.
Retained functional Community/QR/Facebook/badge fixes: `59839c7deb4d1cc860275b9e69578e299cc24d0a`.
Working branch: `fix/community-sapphire-health-3033`.
The Sapphire candidate additionally changes Community-only presentation, immediate
local welcome, and daily energy/heart history projection. Native Health queries,
Watch permissions, current-value cards, dashboard, purchases and iOS/Google sign-in
are not changed by this phase. Raw health evidence is preserved.

## Acceptance boundary

This source is NOT covered by the former 5,221-case portable acceptance.
Its full unfiltered test run and all actual-widget visual captures must be reviewed.
The remaining review item is exact-final-source QA closure, including inherited
visual test-environment errors. A failed test is never silently marked passed.
Only after closure may NO/NO be changed together, review count become zero, and
both platform source bindings and committed manifest digests be recomputed.

`BIL_IOS_V33_AUDITED_SOURCE_SHA` and `BIL_ANDROID_V30_AUDITED_SOURCE_SHA` must name
the same final verified source. `BIL_IOS_V33_STAGING_MANIFEST_SHA256` must match
this file's exact committed bytes. Prior source/digest values are not valid for
the new candidate. The workflow supplies build number 33 and version 1.0.0.
No signed build, TestFlight upload, Play rollout or App Review submission is
claimed or authorized by this source document. Physical auth/push acceptance is
separate from host-only tests and synthetic cloud fixtures.
