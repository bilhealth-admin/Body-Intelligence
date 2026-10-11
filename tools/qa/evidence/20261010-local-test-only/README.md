# BIL local test-only handoff — 10 October 2026

Branch: `qa/bil-quality-ux-integration-20261009`, PR #11.

All ladder results below were run on **`c3acb5c79d80f65488f3f048ab307b61aabb0ca3`**, worktree fingerprint **`50ae73e4a239a3a79599e6c420d166c0b9073f7e2c687f7be8eef35949283c19`**, Windows, Flutter **3.44.6**, Dart **3.12.2**. The later evidence-only commit packages these results; it is not a new test run. Original handoff HEAD `1e24421bc12afdc1a1dac87a5ca7c20e94213b9b` remains an ancestor. No production source was changed.

## Results

| Stage | Groups passed / failed / skipped | Tests passed / failed / skipped |
|---|---|---|
| Runner integrity | 8 checks passed | 8 / 0 / 0 |
| Source | 182 Dart targets in 5 strict batches; analyze exit 0 | No issues found |
| Arabic | 1 / 0 / 0 | 2 / 0 / 0 |
| P0 | 11 / 0 / 0 | 199 / 0 / 0 |
| Focused | 5 / 0 / 0 | 272 / 0 / 0 |
| Broad | 2 / 4 / 0 | 216 / 33 / 0 |
| Full | 0 / 0 / 8 shards | Not run: Broad is red |
| Isolated overflow reproduction | 0 / 1 / 0 | 0 / 1 / 0 |

Broad details: dashboard-nutrition **75/4**, dashboard-contract-health **28/1**, weekly-onboarding-goldens **19/26**, settings-language-icons **39/0**, wellness-commerce **9/2**, community-cold-back **46/0**. These are executed case counts, not counts of distinct product defects.

## Test repairs and original causes

Only four source files changed:

- `test/features/nutrition/meal_vision_flutter_capture_test.dart`: exact SDK formatting of the Arabic builder.
- `test/launch_readiness/navigation_and_more_master_closure_test.dart`: exact SDK formatting of the existing routing assertion.
- `tools/qa/bil_codex_test_ladder.py`: resolve Windows `.bat` launchers; reject a missing source comparison ref instead of silently checking two files; batch the full format scope to avoid Windows command-length failure; bind cache to comparison ref; invalidate downstream or changed-worktree greens before saving; retry only red suites on the identical fingerprint; retain unique attempt logs; default to serial Flutter processes; exclude generated failure PNG outputs while still fingerprinting real golden baselines and all nonignored untracked inputs.
- `tools/qa/test_bil_codex_test_ladder.py`: eight regression checks, including a real temporary Git repository proving diagnostics do not alter the fingerprint and baseline changes do.

No assertion, golden master, threshold, production font, Home, Log Food, package dependency, subscription, Trial, cloud configuration or store version was changed.

## Evidence

- [Structured results and per-suite failure names](results.json).
- [Complete logs, exact ladder manifest, tested patches/sources and all 29 local Golden image/diff sets](local-evidence.zip).
- [Individual review for all 29 Goldens](golden-review.md). All 29 current local MASTER/TEST pairs are exactly equal to the inspected historical pairs in decoded RGBA pixels. None is approved or updated.
- Actual Flutter renderer PNGs, 860×1864: [review](01_review_ar_dark.png), [eaten confirmation](02_review_eaten_confirmation_ar_dark.png), [quick nutrition](03_nutrition_quick_ar_dark.png), [full nutrition](04_nutrition_full_ar_dark.png).
- All four Arabic PNGs were opened individually. Arabic is connected/readable; unknown sugar, sodium and iron say `غير متوفر`. P0 rerendered the identical SHA-256 image bytes. The meal and nutritional source are clearly marked test fixtures, with no real image substituted or meal saved.
- Archive logs preserve earlier tool failures and invalidated analysis attempts. Only `manifest.json` under the tested HEAD/fingerprint defines final gate results. Runner-unit-test logs intentionally simulate red gates and refusals; their final verdict is **8 passed**.

## Main QA / development action required

1. **Blocking product fix: Dashboard 1px overflow.** Local Broad reproduced English LTR 320/390/430 at 1.0x and the current-production/dock preview. A narrow rerun of `en 320 at 1.0x retains all content and burned calories` remained red. Render tree identifies `Column['dashboard-reference-calories-card']` with `BoxConstraints(w=256.0, h=216.0)` and a 1.00px bottom overflow. Source: `lib/features/dashboard/widgets/dashboard_reference_goal_components.dart:194`; 16px padding at line 119; carousel height at `lib/features/dashboard/widgets/dashboard_reference_phone_components.dart:57`. The burned-note case provides 224+24=248px, minus 32px padding=216px, while content needs approximately 217px. **Proposal only:** have the main development conversation measure/allocate the calorie card's content height plus padding (at least 249px for this fixture), preserving protected Home appearance; validate all widths, text scales, both directions and approved visual references. Do not swallow the exception or remove its assertion.
2. **29 real Golden mismatches need individual reference approval.** Weekly/onboarding/protected Home account for 26, watch for 1, recipes/workouts for 2. Background, card, font/wrapping, image composition and scroll changes are documented per name. They are not 29 proven production defects. Existing baseline comparisons stay red.
3. **Arabic time-order visual issue to confirm/fix in production.** Review PNG uses fixture `DateTime(2026,10,10,11,30)` but shows `30 :11`. `lib/features/nutrition/presentation/meal_vision_premium_review.dart:535` concatenates `hour + ': ' + minute` inside inherited RTL. **Proposal only:** format the time with the locale and isolate the digital clock direction, then verify 11:30 and other hours in Arabic/LTR. No production edit was made.
4. **Legacy fixture limitations.** `test/dashboard_polish/live_health_watch_layout_golden_test.dart` does not load the evidence font; both old/new watch images contain block-shaped text/icons. Some historical Home buttons are blocks too. Those images cannot certify readable metrics or actions. Repair the dedicated font fixture and obtain explicit baseline/reference approval in main QA. The Arabic Vision captures above are readable; their font result must not be generalized to every Golden.

## Commands and untested scope

Executed in sequence, with unchanged source HEAD/fingerprint:

```text
python -m unittest discover -s tools/qa -p test_bil_codex_test_ladder.py -v
python tools/qa/bil_codex_test_ladder.py --through-stage arabic --parallel 1
python tools/qa/bil_codex_test_ladder.py --through-stage p0 --parallel 1
python tools/qa/bil_codex_test_ladder.py --through-stage focused --parallel 1
python tools/qa/bil_codex_test_ladder.py --through-stage broad --parallel 1
flutter test --no-pub --timeout=3m test/dashboard_polish/dashboard_polish_layout_review_test.dart --plain-name "en 320 at 1.0x retains all content and burned calories"
```

The code repair commits carry `[skip ci]` to prevent push-triggered full shards/mobile builds. No CI workflow was dispatched. No Android/iOS build, simulator, physical Android/iPhone, camera/picker, real offline/lifecycle/permissions, VoiceOver/TalkBack, all 25 Vision E2E cases, Vision 320/tablet/2x device matrix, SQLite-to-Dashboard device readback, TestFlight, store or production verification was performed. P0 includes repository-level SQLite/readback tests, not a complete device journey. No merge, deployment, payment/Trial change or store submission occurred. **Not release ready.**

Generated diagnostic files remained outside the committed patch: four modified workout-library failure PNGs and four untracked watch failure PNGs. They are preserved in the archive and were never staged as Golden baselines. The original dirty workspace was left intact; the clean QA worktree was created at `G:\BIL_Project\worktrees\bil-test-only-20261010`.
