# BIL39 — Strict QA independent audit, 25 October 2026

**Decision BLOCKED — no frozen integrated Build39 candidate and no full exact-source native/device certification.**

Immutable read-only iOS38 baseline: `155b079696430919f8272df934371f033fb11be2` on `work/ios38-safe-fixes-20261025`. All six BIL39 workers have separate Draft PRs #17–22, and none was merged by this audit.

## Observed worker CI on exact SHA

| PR | Head SHA | Current verifiable CI evidence |
|---|---|---|
| [#17 ROUTES](https://github.com/bilhealth-admin/Body-Intelligence/pull/17) | a7c37d7d7 | [verify 40147373248](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/40147373248) fails Dart parse in `test/features/connected_health/steps_history_navigation_test.dart` (63/77 expected `)`), plus 3 files failing Dart formatter. Android debug 40147373167 succeeded; not full QA. |
| [#18 CRYSTAL](https://github.com/bilhealth-admin/Body-Intelligence/pull/18) | 639ba45d4 | [verify 40148081820](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/40148081820) fails 3 source/test formatter files. Android debug 40148081875 succeeded; P0/full not run. |
| [#19 MEAL](https://github.com/bilhealth-admin/Body-Intelligence/pull/19) | a29ce359e | [verify 40147915890](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/40147915890) source, P0, focused and broad passed; full 8 Flutter shards were in progress on last check. Android debug 40147915878 passed. Overall result still unknown until all 8 complete. |
| [#20 RELIABILITY](https://github.com/bilhealth-admin/Body-Intelligence/pull/20) | b37866c35 | [verify 40149812347](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/40149812347) source green, P0 architecture FAIL: `bil_smart_plan_page.dart` at 769 lines vs enforced 700. Full gated off; Android debug 40149812360 green only. |
| [#21 COACH APP](https://github.com/bilhealth-admin/Body-Intelligence/pull/21) | 8c3721d30 | [verify 40148377034](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/40148377034) FAIL 7 Dart formatter differences, dependent P0/full skipped. Android debug 40148377033 passed only. |
| [#22 MYPLAN](https://github.com/bilhealth-admin/Body-Intelligence/pull/22) | de434c471 | [verify 40147925306](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/40147925306) FAIL 3 Dart formatter differences, dependent P0/full skipped. Android debug 40147925292 passed only. |

## Mandatory cross-PR conflict review

**Collision A:** PR18 and PR19 both modify `.github/workflows/verify.yml`. Crystal extends formatter targets; Meal extends its own targets and adds a required Meal regression step. These independent edits must be combined and verified together in an isolated integration candidate, never last-writer-wins.

**Collision B:** PR20 and PR22 both modify `lib/features/smart_plan/presentation/bil_smart_plan_page.dart`. Reliability changes storage errors, owner isolation and read-only state while MyPlan changes visible layout and tab styling. Merge needs semantic review plus fix of the P0 architecture size violation; merely accepting both patches may keep a failing app.

**Cloud-only PR15:** [verify run 40146782864](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/40146782864) failed historical iOS38 release-manifest workflow test on Flutter shard 5; no production migration authorized. **Video PR16:** base branch is older integration, not protected iOS38; [CodeQL/native run 40146846432](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/40146846432) includes failure of iOS simulator native test on its own SHA. Neither can stand in for 39's own simulator evidence.

## Required release gates

First fix source syntax/formatter and architecture P0 in each own worker PR; wait for Meal's eight shards; then isolated reviewed integration of two overlapping paths. Only after frozen integrated 39 SHA, run fresh targeted/P0 → Golden/focused → broad → full 8 of 8 → negative/adversarial, deep links, owner A→B→A, real isolated RLS/SQL, CodeQL/Semgrep/dependency tests → Android emulators API 26/29/33/34/35/36 and iPhone+iPad native tests → accessibility, performance, signed IPA identity, Apple read-only and actual device validation. 27 BIL cases, 10 COACH-ADD and 18 supplemental QA-COACH cases require exact-SHA evidence; all currently UNVERIFIED on a combined candidate. Do not update Golden baselines to hide defects.

**Safety:** no edits to main/iOS38/App Review, production deployment, Store payments or purchase CTA, user records, any merging or TestFlight upload. This new QA branch contains report, evidence guard and synthetic self-tests only. A green self-test of the gate means the gate logic works, **not** that the app passed a test.
