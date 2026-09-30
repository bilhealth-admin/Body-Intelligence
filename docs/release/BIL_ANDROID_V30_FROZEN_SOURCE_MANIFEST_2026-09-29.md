# BIL Android 1.0.0 build 30 — final prebuild source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 30`

## Accepted application source

Native Android 29 / iOS 32 base: `9f439cae97d72b784880a1b1ac4ef1d33ede30c1`.
Retained Facebook/QR/Community/push functional base:
`59839c7deb4d1cc860275b9e69578e299cc24d0a`.
Final exhaustive application/test source:
`960bead1d24ffea38d963b9e5f58fac0963a2579`.

Final exhaustive QA:
https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/36664811378

The run completed Flutter analyze, the focused regression/performance gate,
visual + isolated cloud contracts, and all eight full-suite shards successfully.

## Final verified counts

- Test files discovered and scheduled exactly once: **1,033**
- Visible Flutter cases passed: **5,656**
- Failed cases: **0**
- Error events: **0**
- Existing conditional skips: **6**
- Focused regression cases: **363 passed**
- Explicit performance budget cases: **2 passed**
- Community visual matrix: **8 passed**
- Deno push/community provider tests: **12 passed**
- Final visual/cloud contract job: **SUCCESS**

No path exclusion or test-name filter was used in the eight full-suite shards.

## Included final corrections

The accepted source includes the reviewed premium More presentation and compact
three-item bottom dock; the Quick Add action itself retains its existing routes
and behavior. Weekly Report and Nutrition/Steps directional controls are
RTL/LTR-aware. Nutrition empty-day Log food opens the existing real FoodLogPage
and is covered by an open/return widget regression. The More split preserves all
existing destinations while keeping architecture size limits strict.

Previously accepted Community, QR, Android Facebook, push, daily Active Energy
and completed-day heart history behavior is retained. Native Watch settings,
native health query surfaces, dashboard/current-value UI, package/bundle IDs,
store routes, purchase logic and native iOS/Google login routes remain outside
the visual polish changes.

The reviewed Weekly RTL and More/settings golden baselines were refreshed only
for the intentionally changed UI and then the one-shot refresh mechanism was
removed.

## Production cloud review

Production Supabase includes the reviewed QR and Community attention/read
migrations plus the final RLS auth-initplan and FK-index performance
hardening migrations. Public-table RLS and private-schema client isolation were
rechecked. Remaining advisor items are documented in
`docs/release/BIL_SAPPHIRE_SOURCE_ACCEPTANCE_2026-09-30.md`; they are not
unresolved application-source defects.

## Immutable release bindings

`BIL_ANDROID_V30_AUDITED_SOURCE_SHA` and
`BIL_IOS_V33_AUDITED_SOURCE_SHA` must both name the same final frozen source commit chosen
after the final docs-only freeze QA.

`BIL_ANDROID_V30_STAGING_MANIFEST_SHA256` must equal this file's committed-byte SHA-256 in
that frozen source commit.

A later dispatch-control commit may pin the existing signed workflow to that
already-audited source without changing the source checked out for compilation.

No AAB/IPA build, Play rollout, TestFlight upload or store submission is
authorized merely by this manifest. Signed artifact and real-device acceptance
remain separate.
