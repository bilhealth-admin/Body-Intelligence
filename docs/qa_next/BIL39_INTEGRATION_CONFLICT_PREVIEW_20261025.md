# BIL39 — Six-stream conflict resolution preview (not QA-approved)

**State: UNVERIFIED SNAPSHOT, NOT A RELEASE OR INTEGRATION ACCEPTANCE.** The isolated preview exists only to compile/test interactions of six actively developed branches. Never merge this preview into iOS38, main, App Review, TestFlight, stores or cloud production.

## Protected baseline

`work/ios38-safe-fixes-20261025` at `155b079696430919f8272df934371f033fb11be2`. No modifications to that ref.

## Exact source snapshot

- PR #17: `92781f90553172e3da35f83ae15d825ac2f0bbc9`
- PR #18: `553a9f65276cfb899fd1d2aa498fc7793ef17af7`
- PR #19: `a29ce359e6b9de6e0b5f51b7e7b301dbe25ea824`
- PR #20: `790cc3f4a9ee0ca8bb32e57f029140200e42246e`
- PR #21: `8c3721d302eaa483b34d566888b653ba11252767`
- PR #22: `9522d5d1c572ad6690b4fb507be6afeae9573be5`

## Explicitly resolved overlapping files

1. `.github/workflows/verify.yml`: kept Meal Planner's regression test job and added four route paths and four Crystal paths into the formatter targets. The source check, P0, focused, broad, and eight Flutter shards remain intact. All 13 new stream-specific diagnostic targets occur once.
2. `lib/features/smart_plan/presentation/bil_smart_plan_page.dart`: retained Reliability's owner isolation, safe retry, sanitized errors, read-only saved-plan protection; applied only My Plan's bottom padding change (30 → 24) and its tab typography change (font size 12, weight w700).

Every non-overlapping modified/addition path uses its exact source Git blob. Two temporary worker diagnostic workflows (`bil39_coach_format_diagnostics.yml`, `bil39_myplan_format_preview.yml`) are intentionally omitted; their ephemeral purposes must not contaminate official integration.

## Important QA and release restrictions

This preview may include failed or unverified stream CI, and must never be treated as HANDOFF_READY_FOR_INTEGRATION or FINAL_QA_PASS. Run preview CI as diagnostic only. Independent workers must fix their own source branches and pass required checks; Integration Lead can then create the official `bil39/integration-20261025` from approved current heads. Final QA comes **after** accepted full integration, before any signed iOS39 build and TestFlight upload. Any failed/untested gate remains BLOCKED.
