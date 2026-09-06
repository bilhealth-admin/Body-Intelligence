# BIL +8 automated preflight — 2026-09-06

## Scope and result

Local source preflight passed after the corrections and explicit reruns below.
This is not a signed-artifact, native-device, store-approval, or zero-defect claim.
The owner waived further simulator prerequisites, not signing, entitlements,
production configuration, or artifact verification. Only `1.0.0+8` may be built;
existing store build 7 must not be promoted.

Host: Windows; Flutter 3.44.6 stable, Dart 3.12.2. Raw logs are retained outside
the repository at `G:/BIL_Temp/plus8-preflight-20260906/`.

## Complete portable inventory and first execution

Discovery found 889 Flutter test files: the existing exact 29 portable-release
exclusions and 860 scheduled files. All 860 were invoked in 15 Windows-sized
batches (14 of 60 files, then 20) to avoid the Windows command-line limit.
No new exclusion was introduced. The first execution recorded 3,952 passing
tests, seven failures, and one explicitly opt-in live-network test skipped.
These are the actual first-run results, not a claim that every batch was green.

| Batch | Passing | Failing | Skipped |
| --- | ---: | ---: | ---: |
| 01 | 257 | 1 | 0 |
| 02 | 226 | 0 | 0 |
| 03 | 193 | 0 | 0 |
| 04 | 132 | 0 | 0 |
| 05 | 253 | 0 | 0 |
| 06 | 295 | 0 | 0 |
| 07 | 258 | 0 | 0 |
| 08 | 187 | 0 | 0 |
| 09 | 353 | 0 | 0 |
| 10 | 515 | 0 | 0 |
| 11 | 383 | 0 | 1 |
| 12 | 222 | 0 | 0 |
| 13 | 284 | 1 | 0 |
| 14 | 323 | 2 | 0 |
| 15 | 71 | 3 | 0 |

The 29 excluded files are not counted as passing here. Independent current
ordinary visual reruns are documented in
`BIL_VISUAL_REVIEW_15_CURRENT_RECHECK_2026-09-06.md`.

## Corrections and verification

- Accessibility source assertions now inspect the complete workout library,
  including its extracted fullscreen parts and real Pause/Play labels.
- Release metadata retains build 8 and the canonical `Version metadata:` field.
- The shell contract checks the current separate identity rail rather than a
  retired fixed height. More's nutrition destination retains `?from=settings`.
- A genuine regression repeated visible Premium text on nutrition pathway
  cards. Paid cards retain their semantic subscription icon/accessibility label
  and one page-level Premium label; duplicate card text was removed. Both the
  unchanged visual widget assertion and unchanged negative source assertion pass.
- Initial concurrent performance measurement exceeded the existing startup and
  search-outlier budgets. Three independent serial executions then passed the
  unchanged budgets. CI now runs that same performance file once, first, with
  one worker; failure stops immediately. All other 859 files follow once.
  There are no automatic retries, budget increases, or performance exclusions.

| Isolated performance run | Startup ms | Five search samples ms | Median ms |
| --- | ---: | --- | ---: |
| 1 | 423 | 777, 274, 255, 209, 180 | 255 |
| 2 | 397 | 877, 230, 249, 188, 188 | 230 |
| 3 | 506 | 810, 265, 183, 208, 189 | 208 |

Budgets remain startup <2,000 ms, median search <500 ms, every search <1,500 ms.
The difference is consistent with host contention; this is not a measurement
of production-phone performance.

Final focused Flutter rerun: **30/30 passed**, including every non-performance
first-run failure, release gates, and full-transfer verification contracts.
Three isolated performance runs: **2/2 each passed**.
Portable-runner contracts and explicitly enabled public live-video range check:
**4/4 passed** (`BIL_LIVE_WORKOUT_STREAM_CHECK=true`, no skipped live check).
Python scheduling tests: **8/8 passed**, including exact partition coverage,
serial-first invocation, fail-fast behavior, and no retries.

Whole-source `dart format --output=none --set-exit-if-changed lib test
integration_test`: **1,970 files, zero changes, exit 0**.
Whole-source `flutter analyze --no-pub`: **No issues found, exit 0** (204.2 s).

## Final evidence digests

SHA-256 of retained raw logs:

| Log | SHA-256 |
| --- | --- |
| focused-retry-final.log | ccbe8e9ab419a4b02a2415c3a7f3819a94c710d81e437d0d797fd8804b4c8378 |
| performance-isolated-01.log | 08850e28febdb3fa828aadcd39016c95c1fb99c180ed6266ebe34335e7cf83c2 |
| performance-isolated-02.log | b0447fdffea1a1a244681b0afaf6037c3c9e0a0ca214ddc0f807b71f32526a56 |
| performance-isolated-03.log | a15f60b2f61f938487dc2618f48d28c02b533787e67fcc85ff13d7475e20847c |
| runner-and-live-final.log | 50de74c7ef65e384d71aaa8de1dc063c7383fd4c0fff5be87bf26c7b3bc6ea88 |
| runner-python-final.log | 4445090d9f2c4b88b37633e9d37c728234ad3acfcb32f9ec6c37033df33b2994 |
| format-final.log | c952ae113439095023f842764b1924a4c9aa70437ded45536dfa2c0d6b21fefa |
| analyze-final.log | ec7c14347829b9b349eeabfa2608aa625dcfb0af16c37397fe6410ea3ba5a615 |

## Remaining release sequence

Transfer the verified INCLUDE overlay to an isolated worktree; verify the full
HEAD plus INCLUDE tree and preservation of EXCLUDE changes; finalize and bind
the new source manifest externally; commit and dispatch signed build 8 jobs.
Both jobs rerun the portable suite from the immutable candidate, then validate
their signed artifacts. Store upload, TestFlight, review submission, and public
availability must each be reported from their own actual results. Apple public
release remains manual; Google production-access review is a separate decision.

## First clean GitHub execution and bounded correction

The initial clean commit `1888807bd2011f1970f16eee5effdeb882aff639` ran on
Android `34021076234` and iOS `34021077842`. Both completed unsuccessfully at
the portable suite: **3,958 passed, one failed, one skipped**. Signing inputs
and prior configuration gates passed, but signed artifact construction and
store upload did not start. Do not report these runs as successful builds.

Both failed the same stale assertion at line 62 of
`test/features/nutrition_plans/nutrition_pathway_access_badge_test.dart`, which
expected repeated visible Premium text inside each paid card. Existing
application code deliberately keeps one page-level label and localized access
labels on semantic icons. The corrected test verifies that intended behavior
instead of restoring duplicated UI text.

The correction retains free-plan visible text, correct icons, English/Arabic,
hero and compact layouts, 1.6 text scale, scrolling and exception checks. It
adds exact icon semantic labels and a single access-label line in the actual
merged tappable-card semantics. The first local attempt assumed an isolated
icon semantics node; Flutter correctly merged it with the card description.
The second attempt exposed a redundant manually-created semantics handle.
Both harness assumptions were corrected; the final test uses Flutter's own
`semanticsEnabled: true` lifecycle. Their failed logs remain retained rather
than represented as passes.

Final command: `flutter test --no-pub` with the access-badge, pathways-contract,
access-policy, and semantic-icon-spacing test files: **19/19 passed**.
`dart analyze` on the modified file: **No issues found**. Formatting: one file,
zero changes. No production source, dependency, CI step, exclusion or budget
was changed. Both entire CI workflows must be rerun from the follow-up commit.

| Retained log | SHA-256 |
| --- | --- |
| candidate-premium-semantic-verified.log | bf13161bd791365776439fe94e086692686f5273f87bf777ff5ce09df960e213 |
| candidate-premium-semantic-analyze.log | b79d2097625d56e75afcfd49583a3d04232ab4f3ba0433b7804da23d5ecc4837 |
| ios-run-34021077842-job-101453661896.log | 18be94941e50be7b6c1d4d90fd5cbb4d7445b88ea1f4984d8230a06f6efee17b |

Logs are retained under `G:\BIL_Temp\plus8-preflight-20260906`. The skipped
opt-in live-network test was already run explicitly and passed in the earlier
local evidence; its default CI skip is not counted as a pass.
