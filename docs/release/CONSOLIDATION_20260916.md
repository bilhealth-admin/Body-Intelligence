# Post-iOS 18 / Android 15 release consolidation

Date: 2026-09-16. Status: **STOPPED AT FAILED BATCH 1 — NOT RELEASE READY**.

This document supersedes the source-inclusion boundaries (not historical test
results) in the separate Google Play, refund/trial, and dashboard review notes.
It is not a claim of device validation, deployment, or store approval.

## Exact built baseline

Both successful signed-build workflows used
`d7fb5e5218ba82630ba635f227579fbc60b105f9`:

- [iOS 18, run 34942330385](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/34942330385).
- [Android 15, run 34942332846](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/34942332846).

The GitHub run metadata was read again on 2026-09-16. The failed attempts before
these successful runs are not treated as release evidence.

## Isolated candidate and preservation

- Branch: `codex/release-consolidation-20260916`.
- Worktree: `G:/BIL_Project/body_intelligence_log_release_20260916`.
- Integration base: `66172a802f1897abad95e9e08828ac79ba5b5227`.
- Source backup: `G:/BIL_Project/audit_backups/release-consolidation-20260916`.
- The backup contains binary/full-index patches, exact file copies, and SHA-256
  hashes for **64 pending files**: 31 dashboard files and 33 purchase/refund/trial
  files. All copies were hash-verified before integration.
- Original worktrees were not reset, cleaned, or used as edit targets.

The post-checkout Git hook reported a process-fork resource error after the
worktree was created. Independent checks confirmed HEAD, branch, 5,232 tracked
files, and an empty initial status before any integration. No retry overwrote it.

## All eight existing post-build commits are ancestors

| Commit | Included change |
| --- | --- |
| `1479618` | Native Google sign-in hardening; onboarding pace/calorie-floor validation, including 1 kg/week eligibility; direct system microphone consent on iOS; premium dashboard masking; initial Apple verification hardening. |
| `4cd43a8` | Preserve previously verified subscription access through transient refresh failures, bounded by owner and entitlement validity. |
| `63aa48f` | Meal-vision Gemini 3.7 migration, response normalization, model tests, and matching pricing migration. |
| `2d6b53f` | Safe Apple receipt reconciliation and purchase/restore queue recovery. |
| `e90f155` | Edge-runtime Apple certificate signature verification and restore recovery, without accepting unverified receipts. |
| `2768d49` | Reconcile Apple product changes and preserve the database RPC named-argument contract. |
| `cb389eb` | Bind Apple purchase claims to their verified BIL owner; guard restores across different BIL accounts. |
| `66172a8` | Android Health Connect minimum scope, Play offer refresh/identity guards, localized checkout feedback, and updated review/privacy declarations and regression tests. |

Android Health Connect is deliberately narrowed to **read-only Steps, Distance,
ActiveCaloriesBurned**. This includes removal of BodyFat, RestingHeartRate and
SleepSession requested by Google, plus the other out-of-scope import/write
permissions. Apple Health scope, manual input, and BLE are not removed by that
change. Do not describe Android weight/nutrition/sleep imports as retained.

## Pending fixes now included in this candidate

### Purchase, refund, trial, and content access

- A clock-aware verified access provider closes paid content at expiry and on
  authoritative revocation/refund without keeping another account's state.
- Recipe details and pushed workout/video routes re-check entitlement; video
  playback is disposed when access ends, rather than merely visually covered.
- An inactive restore triggers an authoritative account/balance refresh without
  treating empty store history as permission to revoke unrelated verified access.
- Apple notification freshness policy reconciles signed notice and canonical
  transaction state; retryable failures use claimed leases rather than false
  success acknowledgements.
- Verified AI Boost refund/reversal ledger, idempotency and reserved-credit
  handling; terminal subscription persistence and cancelled-trial allowance
  classification; ordered signed snapshots protect newer verified state.
- Four forward migration files, HTTP/lifecycle/ownership tests, local Postgres
  execution tests, and the complete ten-batch Flutter runner are preserved.
- The prior refund/trial audit is retained as historical evidence, not as proof
  that its original failures are all resolved.

### Dashboard and layout

- Centered wordmark with edge-aligned profile/bell/settings controls; compact
  settings icon replaces Edit text while preserving accessible touch targets.
- One compact AI Coach card; watch beside content-width Weight/Meals/Water
  cards aligned to its physical right, including Arabic, with large-text fallback.
- Calories remains the first nutrition card. Names, data sources, navigation,
  subscription gates, and the original calorie calculation are preserved.
- Compact weight/Body Twin/Discover/bottom navigation, truthful single weight
  point, controlled scroll bounds, and removal of excess bottom space.
- Preset selection retains its scroll position. Custom-card saving is local to
  the selected card instead of flashing the entire page.
- Icon/text spacing and badge size corrections; burnt-calorie pipeline and
  responsive/RTL/accessibility regression tests.

See `consolidation-source-inventory.csv` for every preserved pending file and its
source hash. The two overlapping commerce files were merged, not overwritten:
`bil_store_plans_page.dart` and `bil_store_plans_dynamic_contract_test.dart`.
Both the changed-Play-offer and inactive-restore widget tests are retained.
The other 62 imported files matched the backup exactly at integration time.

The read-only `verify-store-purchase` v44 source snapshot (updated
2026-09-16T03:29:02.926Z) was also compared with ancestor `cb389eb`: all ten
deployed source files match that committed source after line-ending
normalization. Those cloud fixes are inherited here, with the pending
refund/trial additions on top. The v44 snapshot is not evidence that those new
additions have been deployed.

## Integration-only follow-up

The installed Deno is 2.9.6 / TypeScript 6.0.3. Its type check found two typed-array
`BufferSource` incompatibilities in the Apple certificate verifier and its test.
They were repaired using owned `Uint8Array` copies, without disabling checking,
casting away those errors, changing certificate trust, or skipping tests.

## Explicit exclusions: preserved, not deleted

- The original dirty main tree and old community-recovery tree contain older,
  divergent pre-build snapshots, not subsequent 18/15 fixes. Their source file
  timestamps and diffs were checked. Overlaying them would revert newer native
  OAuth and account-name handling. They were not overlaid or cleaned.
- The old build-16 follow-up tree contains generated golden-failure pictures,
  not additional post-build source fixes. It remains untouched.
- Ignored build caches, old signed artifacts, local credentials and diagnostic
  images are not release source and are not staged.

## Previous validation attempt (before repair round 1)

- Offline dependency resolution: passed, with no lockfile upgrade.
- Full Flutter analysis: **PASS, no issues found**, 323.4 seconds.
- Flutter host tests: 989 test files, ten serial groups, no file exclusions or
  golden updates. The runner completes the failing group and does not advance.
  Every new invocation starts at analysis and group 1; no resume shortcut.
- Batch 1 finished all 98 files: **468 cases passed, 12 failed**. The runner
  exited with `STOPPED_AT_BATCH_1`. Batches 2–10 (891 files) were **NOT RUN**.
  No runner or test child was intentionally left running after this gate.
- Backend initial type check: two errors, repaired as described above.
- Backend rerun: type check passed; **271 passed, 13 failed**. Failures are in
  `apple_refund_trial_matrix_test.ts` (8) and
  `store_ownership_persistence_test.ts` (5), at `persistVerified` response
  validation. Existing mocks return the old boolean while the new persistence
  contract requires `{active, lifecycle, verified_at}`. No test was removed.
- Auxiliary runner stopped after that failed group. SQL execution and release
  Python checks were **NOT RUN** in that sequence.
- Host test logs: `build/diagnostics/full_validation_20260916T164349053848Z/`.
- Backend logs: `build/diagnostics/auxiliary_validation_20260916T164818858894Z/`.

### Flutter failure inventory and next repair order

| File | Failures requiring review |
| --- | --- |
| `test/epic15_store_screenshot_golden_test.dart` | Four dashboard golden mismatches: iPhone/Android, English/Arabic. Review actual render against the requested polish before accepting new baselines; no blind golden update. |
| `test/features/commerce/billing_release_hardening_contract_test.dart` | One source-count assertion about owner dependencies expects at least three direct watchers, finds two after the stable scalar owner provider. Replace brittle text counting only with equivalent behavioral protection, not reduced ownership guarantees. |
| `test/features/commerce/verified_subscription_access_test.dart` | Three failures: pending timer at cleanup; terminal response and account dependency completion do not render expected Free within the tested sequence. Investigate lifecycle/timing before declaring these fixture-only failures. |
| `test/features/nutrition_plans/nutrition_pathway_access_policy_test.dart` | One verified Premium deep-link test still finds the lock veil. Verify the fixture's entitlement boundary and the new access provider together. |
| `test/features/wellness/recipe_detail_entitlement_lifecycle_test.dart` | Two failures for already-open recipe relocking on refund/expiry. Do not claim lifecycle completion until these pass. |
| `test/accessibility/release_accessibility_regression_test.dart` | One common-icon accessible-name contract failure following the settings-icon header change. Preserve labels and touch access. |

Repair and verify subscription/restore/refund/owner-access cases first, then
review visual/accessibility expectations. Re-run the backend group and the full
Flutter pipeline from analysis and batch 1, not from the point of failure.
Only after all gates pass should a validated release commit be created.

## Repair round 1 and unattended validation protocol

The latest owner instruction supersedes the earlier build/commit request:
repair the recorded failures, restart the whole host pipeline, then leave the
runner alone. No agent monitoring, automatic repair, commit, build or deployment.
The owner will say `عالج` to request the next repair/restart cycle.

The current repair fixes the complete recorded failure set without disabling
tests or weakening entitlement checks:

- Updated the two Apple persistence test doubles to the ordered RPC response
  `{active, lifecycle, verified_at}` and its 16 arguments. Added rejection of
  malformed/legacy boolean responses and coverage that the canonical refunded
  result wins over a stale active receipt. Owner-token rejection is unchanged.
- Fixed widget-test lifecycle handling: explicit disposal of test-owned
  timers, waiting for the terminal provider result before asserting the next
  frame, and real async completion of cached recipe assets after opening the
  sheet. Both already-open recipe refund/expiry tests now pass, including
  assertions that real recipe details load before the lock is tested.
- Gave the paid nutrition test a deterministic valid expiry and added the
  negative case: missing expiry remains locked. Added a real owner-stream
  switch/sign-out test using the production owner/access providers.
- Replaced a brittle count of owner-stream mentions with checks of each actual
  owner dependency. The settings action's accessible tooltip and 44px target
  are tested across all 25 locales at normal and 2x text size.
- Reviewed and regenerated seven changed golden images: four compact
  dashboard views, two iPhone food-search views and one nutrition-pathways
  view. The latter three reflect the existing 0-to-12px icon/text gap change.
  No tolerance was expanded. A subsequent strict run, without golden updates,
  passed all eight screenshot test cases.

Focused repair verification:

- Flutter: **99 passed, 0 failed** across the seven affected test files.
  `build/diagnostics/repair_round_1_verified.log`
- Apple persistence/refund/trial Deno tests with type checking:
  **35 passed, 0 failed**.
  `build/diagnostics/repair_round_1_backend_verified.log`
- Background scheduler unit tests: **9 passed**. They cover sequential
  advancement, finishing all parts of a failed group, no later-group execution,
  restart from analysis/group 1, complete discovery, and exclusive execution.

`tool/release/run_full_validation_batches.py` now runs full Flutter analysis,
then 10 serial Flutter groups containing all 989 test files. Group 1 also
includes all discovered local Deno tests, five in-memory PostgreSQL test files,
Node release-helper tests and Python release-helper tests. No production RPCs,
store purchases, native device tests or signed builds are run by this runner.
Failure in any part finishes that group's remaining commands, then stops.
The runner never updates golden images, resumes midway, repairs itself, or
silently excludes a discovered Flutter file. Analysis failure stops before tests.

Each run writes its immutable inventory and per-command logs under a new
`build/diagnostics/full_validation_<UTC timestamp>/` directory. It publishes
`build/diagnostics/latest_full_validation.json` and the run's `summary.json`
atomically as progress changes. An OS-owned lock prevents a second full runner
on this tree; the lock releases even when the runner exits unexpectedly.
The owner corrected the launch requirement: use the ordinary Codex execution
terminal, not an external or hidden background process. Child output is mirrored
live into that terminal and retained in per-command logs. The computer must
remain on and awake. Do not modify this candidate while its tests are running.

These focused passes do **not** claim that the new full run has passed.
Read its final summary on the next owner request; leave it unmonitored now.

All 64 original source file hashes were checked again after the batch: no source
file in either original worktree was changed. A new release commit, push, or
build was deliberately **not** created from this failing candidate.

Read-only Supabase migration inventory on 2026-09-16 contains the Gemini pricing
migration but does **not** contain the four newly consolidated refund/trial/order
migrations. They have not been deployed by this task. This candidate's server
code must not be deployed ahead of its matching database contracts; preserve
compatibility with installed build 18 and Android 15 during that rollout.

No production data was modified, backend function deployed, GitHub workflow
dispatched, signed binary built, TestFlight build uploaded, or store submission
made by this consolidation. Full validation and device purchase/restore/refund,
trial-boundary and health-sync checks remain release gates.

The existing signed workflows are still deliberately frozen to iOS 18 and
Android 15 and their old audited source/manifest variables. Do not dispatch
them against this candidate as-is. Once validation passes, choose unused build
numbers, produce new freeze manifests, and bind both exact commit and manifest
digest before a new signed GitHub build. No frozen release binding was changed.

## Repair round 2: batch-1 auxiliary failures

The visible run `full_validation_20260916T173342442483Z` correctly stopped after
batch 1: Flutter, Deno and Node release helpers passed, but Python release helpers
had three errors and the local PostgreSQL suite had one failing file. Flutter's
success message was not a pass for the entire batch.

- Classified the three new dashboard/icon review tests as environment-guarded
  captures in the separate code-only audit policy. Their full layout/navigation
  assertions stay scheduled; no test file or test name was excluded. Both
  code-only entrypoints force the optional capture environment flags to zero.
  New unit coverage verifies inclusion and inherited-flag handling.
- Fixed the PostgreSQL test's `Date.parse(Date)` conversion, which lost fractional
  seconds through `Date.toString()`. Compare the driver's Date objects with
  `getTime()` instead. The database/RPC implementation was not changed. Added an
  exact-millisecond test proving that an older signed receipt within the same
  second cannot revive a refunded subscription.
- Added whole-batch console summaries and a final `VALIDATION_STATUS` marker so
  a passing Flutter subsection cannot conceal a failed auxiliary subsection.

Focused verification: **100 Python tests passed** and **all five PostgreSQL test
files passed (74 executable checks)**, including all 26 store refund/retry checks.
Logs: `build/diagnostics/repair_round_2_python.log` and
`build/diagnostics/repair_round_2_postgres.log`. Pre-edit copies of the six touched
files were hash-verified under the external `repair-round-2` audit backup.

Restart the complete host run from analysis and batch 1 in the Codex terminal.
Do not monitor or auto-repair it after launch. Each failed batch finishes its
remaining commands, then stops before the next batch; the next owner `عالج`
requests another repair/restart cycle. These focused results are not full-suite,
device, signed-artifact or store-release evidence. No cloud changes were made.

## Repair round 3: batch-2 architecture and presentation contracts

Run `full_validation_20260916T174948291369Z` passed full analysis and every
command in batch 1, then automatically advanced to batch 2. Batch 2 finished
with 515 passing Flutter tests and three failures; batch 3 was not started.

- Resolved the architecture ceiling without raising it: purchase processing
  now lives in a same-library private extension, the Health/BLE snapshot merge
  in its own part, and the fullscreen paid-access gate in its own part. The
  original files are now 687, 670 and 676 lines; the new parts are 622, 79 and
  36 lines. The single purchase queue, owner-scoped state and lifecycle stay
  on the existing service. No receipt verification, entitlement, health-data
  provenance, player-disposal or Supabase API behavior was changed.
- Updated source readers to inspect the extracted parts as well as the roots,
  retaining their existing billing and health-safety assertions.
- Replaced an obsolete source-order assertion with checks for the approved
  watch/daily-summary group and its standalone fallback, both before Body Twin.
  Existing runtime checks verify that summaries remain to the right of the
  watch in English and Arabic; Calories remains the first nutrition card.
- Scoped the typography exception to the compact numeric weight only, keeping
  the heavy-body-text prohibition. Added runtime assertions for that exact
  14px, w800, left-to-right value in both language previews. No production
  labels, layout, fonts, images or golden baselines were changed in this round.

Verification: affected-file analysis passed with no issues; **135 tests across
18 Flutter files passed, zero failures**. This includes all three original
failures, checkout/restore/queue and owner checks, Health/BLE truth, iOS/Android
daily active-energy propagation, and fullscreen access/player lifecycle.
Logs: `build/diagnostics/repair_round_3_analysis.log` and
`build/diagnostics/repair_round_3_flutter.log`. Pre-edit copies of 12 files were
hash-verified under the external `repair-round-3` audit backup. Mechanical
extraction was compared against those pre-edit sources, allowing only formatter
whitespace/trailing commas and explicit static-member qualification.

Restart the full run from analysis and batch 1 in the ordinary Codex terminal,
then leave it unmonitored as requested. A whole-batch success advances to the
next batch; a failure finishes its batch and stops before the next. These
focused passes are not a full-suite or device/store-release result. No commit,
push, build, cloud change or store submission was performed in this round.

## Repair round 4: batch-3 visual baselines and Free-ad contract

Run `full_validation_20260916T181222046450Z` passed full analysis and batches
1 and 2, then batch 3 finished with 402 passing tests and nine failures. Eight
were the same Epic 3 gallery golden mismatch; one was an obsolete source-shape
assertion in the safe Free-ad inventory contract. Batch 4 was not started.

- Reviewed all eight new gallery images: compact/large, English/Arabic and
  light/dark. Their only intended shift is the approved 12px ListTile
  icon-to-label gap that prevents icons touching text. Updated those eight
  baselines with no tolerance change. Every resulting golden hash exactly
  matches the failed run's captured test image.
- Kept the production server-entitlement and Supabase paths unchanged. The
  Free-ad source contract now verifies actual safety ordering: an active,
  owner-scoped closed-test grant returns its paid state before the subscription
  lookup; only a later canonical Free row becomes verified Free; transient or
  offline reads retain the fail-closed fallback. Ad policy still requires
  verified Free, adult eligibility, online/configured service and a reviewed
  non-sensitive placement.

Focused verification: affected-file analysis passed; **33 strict Flutter tests
passed, zero failures**, including all eight updated goldens, 200% text scale,
safe-area/keyboard behavior, the full Free-ad inventory/policy matrix, closed
test ownership, verified entitlement surfaces and refund/revocation/expiry
cache invalidation. Logs: `build/diagnostics/repair_round_4_analysis.log`,
`repair_round_4_golden_update.log` and `repair_round_4_flutter.log`. Pre-edit
copies of the test, report and eight goldens were hash-verified under external
`repair-round-4` backup.

Restart the full run from analysis and batch 1 in the ordinary Codex terminal,
then leave it unmonitored as requested. These focused passes are not full-suite,
device, signed-artifact or store-release evidence. No production code, cloud
state, database, commit, push, build or store submission changed in this round.

## Repair round 5: batch-5 verified Premium fixture

Run `full_validation_20260916T182851028036Z` passed full analysis and batches
1 through 4, then batch 5 finished with 592 passing Flutter tests and one
failure. Batch 6 was not started. The failing daily-log flow labeled its test
subscription Premium but omitted the canonical active lifecycle boundary, so
the fail-closed access provider correctly downgraded it to expired Free and the
nutrition glass intercepted the detail tap.

- Kept the production entitlement and nutrition-glass protection unchanged.
- Made the test fixture a deterministic server-verified active subscription
  with a fixed clock, valid start and future period end.
- Added an explicit assertion that this valid fixture has no paid glass before
  the nutrition-details interaction.

Focused verification: affected-file analysis passed; **15 Flutter tests passed,
zero failures**, covering the original food-add/reload failure, exact entitlement
deadlines, owner changes, terminal responses, verified Premium unlock and all
Free/loading/error glass states. Pre-edit copies of the test and this report were
hash-verified under the external `repair-round-5` backup. No production code,
cloud state, database, commit, push, build or store submission changed.

Restart the full run from analysis and batch 1 in the ordinary Codex terminal,
then leave it unmonitored as requested. A whole-batch success advances to the
next batch; a failed batch finishes and stops before the next.

## Repair round 8: batch-10 visual baseline and release candidate refresh

The full validation run passed analysis and batches 1 through 9. Its tenth
batch completed its executable cases with 474 passing tests but reported 58
failures before the Flutter process became idle during teardown. The exact
process tree was observed without CPU progress and stopped only after the batch
had finished reporting its failures; no later batch was started.

- Updated two stale dashboard dock source contracts from the intentional
  compact 76-pixel geometry, rather than changing production layout back to
  the obsolete 90-pixel expectation.
- Made dashboard-preference golden interactions deterministic by targeting the
  section keys and invoking the selected toggle callback after the card is in
  view, avoiding an off-screen restore control and bottom-navigation overlap.
- Reviewed the changed Premium dashboard, dashboard-preference, recipe-detail,
  connected-health and food-search captures. Updated only stale visual
  baselines; production behavior, cloud state and database state were not
  changed in this repair round.

Focused evidence: five source-contract tests passed; both repaired preference
captures passed; the strict three-suite visual rerun passed **195 tests, zero
failures**; and the affected-file analyzer completed without issues. The
requested batch-10-only rerun then completed all three original commands with
`BATCH_10_RETRY=PASS`; its final command passed **576 tests**. Evidence is in
`build/diagnostics/batch_10_retry_20260917T014129892`.

The next signed candidate is deliberately pinned to iOS build 19 and Android
versionCode 16. The iOS manual-release workflow defaults its TestFlight input
to enabled, but uploads only after the signed archive, validation and App Store
Connect gates succeed. New non-self-referential frozen manifests bind the
eventual committed source SHA and manifest SHA-256 through repository variables
before either signed workflow can proceed.

## Repair round 6: batch-7 onboarding golden harness

Run `full_validation_20260916T192221726103Z` passed full analysis and batches
1 through 6, then batch 7 finished with 877 passing Flutter tests and three
golden failures. Batch 8 was not started. Pixel isolation showed every changed
pixel belonged to the segmented setup-progress row; all copy, photos, fields,
controls, spacing and navigation remained identical.

The three stale baselines showed the Windows-host progress numerator (including
the non-iOS `name` step) even though those cases explicitly render iOS. Current
Flutter correctly retained the rendered iOS step list through capture, exposing
the mismatch. The complete master/test comparisons and isolated diffs confirmed
that only the progress segments changed. Update exactly those three baselines;
retain the helper's mandatory debug-platform cleanup so Flutter's per-test
foundation invariants remain satisfied. Production onboarding code is unchanged.

Pre-edit copies of the helper, this report and the three old baselines were
hash-verified under the external `repair-round-6` backup. No production code,
cloud state, database, commit, push, build or store submission changed.

Focused verification: affected-file analysis passed; **66 Flutter tests passed,
zero failures** without golden-update mode. This covers all nine onboarding
visuals, iOS/Android step routing, 25 locales, measurement persistence, weekly
pace safety (including the conditional one-kilogram choice), AI consent and
plan contracts. Each new baseline SHA-256 exactly matches its reviewed failed-run
test image; no other onboarding golden changed.

Restart the full run from analysis and batch 1 in the ordinary Codex terminal,
then leave it unmonitored as requested. A whole-batch success advances to the
next batch; a failed batch finishes and stops before the next.

## Repair round 7: batch-9 Apple AI Boost source contract

Run `full_validation_20260916T202521525772Z` passed full analysis and batches
1 through 8. Batch 9 finished with 460 passing tests, two skips and one failure;
batch 10 was not started. The failing AI Coach contract still required the old
direct `verifyApple(verification)` source shape even though the consolidated
backend now uses a stricter Apple verification path.

- Kept the production purchase, restore, ownership and credit code unchanged.
- Scoped the source contract to `verifyAiBoost` instead of accepting matching
  text from another purchase route.
- The contract now enforces the Apple safety order: verify the device-signed
  transaction, validate its exact requested product, read the canonical server
  transaction, require an exact active match, enforce BIL-account ownership,
  and only then call the atomic credit RPC. It also verifies both signed account
  tokens are considered.
- Retained the Google consumable order: verify before credit and consume only
  after the credit RPC. Boost still cannot grant a subscription tier or expose
  the Gemini API key.

Focused verification: affected-file analysis passed; **seven Flutter contract
tests passed** across AI Boost, Apple certificate-chain and App Store rejection
compliance coverage. The Apple reconciliation, ownership and persistence Deno
suites also passed **46 tests, zero failures**. Pre-edit copies of the contract
and this report were hash-verified under the external `repair-round-7` backup.
No production code, cloud state, database, commit, push, build or store
submission changed in this round.

Restart the full run from analysis and batch 1 in the ordinary Codex terminal,
then leave it unmonitored as requested. A whole-batch success advances to the
next batch; a failed batch finishes and stops before the next.
