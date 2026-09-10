# Tester-feedback release gate — Android 13 / iOS 14

## Scope

One candidate after `a05140609ee145e5002eaa9c960bb3ff4f75ede0` contains:

- Durable display-name edits from all existing editors, with ordered remote
  synchronization, pending-edit protection, and account-owner isolation.
- Dashboard refresh preserving loaded content and native scroll rebound;
  AI Coach history scrolling preserving the user's active drag and momentum.
- Text-only More section headings, retaining action-row icons and localization.
- Free Community, friends, and messages; authentication, RLS, moderation,
  suspension, blocking, and rate limits remain enforced. Paid AI, subscriptions,
  administrative grants, and token balances are not reclassified as Free.
- Sleep reminder disable/save correctness for historical goals, a guarded
  single permission/native/persistence operation, and stable pending state.
- Regression assertions aligned with the requested Free feature and durable
  name behavior; refreshed byte-verified legal-publication evidence; opt-in
  fail-fast scheduling with its own negative tests.
- New exact build-number guards and independently bound frozen manifests.

No food-search/navigation behavior, signing credentials, pricing, AdMob
activation, or live account balances are changed by this release preparation.
The deleted Premium-friendship-only contract is replaced by Free access and
unchanged-security contracts, not removed to conceal a failure.

## Executed verification

| Gate | Result | Evidence |
| --- | --- | --- |
| Complete selected Flutter host suite | PASS | 26 groups, exit 0 |
| Current suite coverage after release-only rerun | PASS | 950/950 selected test files; zero missing, failing, or stale files |
| Full Flutter analysis after final Dart edits | PASS | No issues; 20.3 seconds |
| Affected release/workflow/manifest contracts | PASS | 89 tests in 17 files |
| Prebuild Python tests | PASS | 21 tests |
| Release-tool Python tests | PASS | 88 tests |
| Isolated PostgreSQL grant/reset/Free Community tests | PASS | 21 + 10 + 14 checks; no remote writes |
| English/Arabic website Free-copy tests | PASS | 6 tests |
| Formatting of changed Dart files | PASS | 48 files, zero changes |
| Git whitespace validation | PASS | `git diff --check HEAD` |
| Conflict-marker scan of executable/configuration trees | PASS | No matches |
| Final staged credential scan | PASS | Gitleaks with full redaction; zero leaks in the staged patch |
| Simulator, emulator, devices, screenshots, visual testing | NOT RUN | Explicitly outside this phase |
| Final signed artifacts / store processing | NOT RUN | Must be produced and verified by dispatched CI |

The local full-suite evidence is retained at
`G:/BIL_Temp/full-project-tests-20260910`, including the 26-group summary,
timestamped logs, the final release-only rerun, and
`final_code_test_coverage.json`. The 950 count is files, not test cases.
Fifteen image/visual/live-media-only files and five device integration files
were not run; mixed files used the reviewed code-only name filters. These
exclusions are not passes. Host widget tests do not prove real OS behavior.

## Release boundary

GitHub previously completed Android 12 and iOS 13 successfully at the parent
commit. This candidate uses Android 13 and iOS 14 to avoid reusing store build
identities. The shared pubspec version remains unchanged; both signed workflows
pass the exact platform build override and verify the frozen source/hash binding.
The workflows keep code-only test selection and native runtime opt-in disabled.

The owner authorized commit, push, and starting both builds after the completed
suite. iOS may upload the validated IPA to TestFlight; that is not App Review or
public release. Android produces a signed AAB without publishing to Google Play.
No CI success, TestFlight availability, Play publication, or real-device sleep,
scrolling, purchase, or HealthKit success is claimed by this source checkpoint.
