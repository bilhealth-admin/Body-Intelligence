# BIL frozen 31554 — verified scoped evidence and unresolved gates (2026-10-22)

## Authority and immutability
- Product source is **frozen** at `31554b3e078667a38bd3c53aa105f5f1d2a4dc96` on `integration/bil-qa-media-policy-20261011`. No changes, branch move, merge or rebase were authorized or performed.
- All supporting harness changes belong to `qa/bil-independent-31554-20261022`; they do **not** remediate original committed source. No TestFlight, signed release, store upload, deployment, Production DDL, GRANT or real-user-data mutation was authorized or performed.
- Evidence must keep original/pristine run conclusions separate from scoped QA-overlay replacements. A skipped job is NOT a test PASS.

## Verified source-scoped successes not to rerun
- Original full Flutter root suite: [run 39701825576](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39701825576), job `119572616754`, **10,282 passed; 0 failed, 0 skipped**. The parent workflow remains red because its distinct supplemental dependency/security job failed.
- Windows setup, focused, Goldens, analyzer: [run 39702297238](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39702297238), five jobs PASS.
- Pub, Deno/npm, Maven audits: [run 39704345483](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39704345483), three jobs PASS.
- RC Android APK/AAB, Android API 33/36 notification simulations, iOS simulator and **unsigned** IPA: [run 39701903483](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39701903483) all four required jobs PASS; no actual device or store-signed IPA proof.
- Native CodeQL Swift and Java/Kotlin jobs PASS in [run 39701926911](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39701926911); the parent remains historically red for the original iOS harness.
- Offline MobSF actual static scan of original debug APK: [run 39708661097](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39708661097), job `119594530707` PASS as **scanner execution**, with manifest findings (including debuggable debug-build and other warnings). It is not a signed release scan, dynamic test or blanket security approval.
- Existing successful original Coach, source-policy, isolated Supabase, Android native, HealthKit, admin, store lifecycle and six-API startup runs retain their original receipts. Barcode boundary, community translation, account-deletion, public endpoints have their distinct scoped QA recovery receipts in [run 39704151885](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39704151885), including translation job rerun `119583685036`; do not mark the full historical failed live workflow green.

## Native iOS **simulator** journeys — actual test result versus parent gate
The original frozen Dart/native integration cases ran and finished with exit 0:
- iPhone and iPad system-crypto: [run 39727128571](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39727128571), job `119653859014`, `+3 All tests passed` on **each** simulated device. Xcode simulator build and original XCTest five passed with zero failures.
- iPhone/iPad native-settings: [run 39728742077](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39728742077), job `119659230555`, two tests on each simulated device, actual drive exit 0.
- iPhone feature-splashes: same run `39728742077`, 13 original tests PASS.
- iPad feature-splashes: [run 39769902887](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39769902887), job `119795021224`, 13 original tests PASS, drive exit 0. This was isolated because the previous iPad run timed out during bootstrap.

Thus six required device/entrypoint combinations have direct native simulator execution evidence. **The GitHub parent workflows are still historically FAILURE**: a post-drive tracked-working-tree gate failed after Flutter/CocoaPods altered generated tracked iOS project configuration in the disposable checkout. The separate [run 39770380667](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39770380667) failed before devices because the QA generator demanded a pristine tracked tree *after* dependency preparation. Its preserved pre-native diff lists exactly:
`ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner.xcworkspace/contents.xcworkspacedata`.
These paths were changed inside ephemeral CI workspace, **not committed to the protected branch**.

QA-only fix [commit f509a754](https://github.com/bilhealth-admin/Body-Intelligence/commit/f509a754bf51f17cba8c7250d4b38bbf00e552c4) assembles the signature helper *before* dependency preparation, requires the exact four preflight modified paths, and compares **full Git binary diffs plus path inventories** before vs. after any future native execution, rejecting further mutation. [Run 39783289422](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39783289422), job `119839764210`, passed **51 offline QA regression tests**. Its native job `119840470914` was intentionally **SKIPPED** to avoid repeating successful native tests. This closes the offline QA-helper proof only; no newly green end-to-end native job or pristine full CI result is claimed.

## Guarded SQL rollback programs — scoped QA replacement, not pristine reclassification
- `ai_consent_receipt`, `cloud_sync_consent`: PASS with original strict rollback and independent residue in [run 39708418326](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39708418326), jobs `119594207341`, `119594207391`.
- `community_prebuild`, `community_collaborator_privacy`, `community_policy_20261019`: PASS under QA-only consent-before-public-profile fixture in [run 39773543636](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39773543636), job `119806735382`, **79/79 + 33/33 + 79/79 = 191/191**, including original rollback, assertions and residue checks.
- Original historical SQL run `39704151885` and earlier modified-guard failed jobs `39727340163` remain red on their own SHA. The successful QA fixture follows existing policy consent constraints. No Production permission, RLS or schema changes were made.

## Still-open certification / scope limits
1. **DEPENDENCY_SECURITY (original/pristine RED):** original locked Vite/Vitest/Cloudflare development-tool dependency audit failed in owner supplemental security job `119572616385` of run `39701825576`. A temporary isolated QA overlay [run 39702054172](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39702054172) PASS does **not** fix committed dependency locks. Remediation would require a separately authorized product-source change, prohibited by the current immutable-SHA mandate.
2. **HARNESS_DEFECT (historical CI RED):** native simulator drives PASS, yet original parent iOS workflow jobs remain FAILURE. The strict post-preflight tracked-diff guard is prepared and offline-validated only, not yet proven end-to-end on macOS after native execution. Do not erase or relabel those failure statuses.
3. **NOT_RUN / outside scope:** signed IPA, TestFlight, store uploads, app-review approval, production device tests, and real-device hardware security/attestation. These cannot be inferred from simulator PASS.
4. **Security follow-up:** original debug MobSF manifest findings must be reviewed separately against release build before treating security as release-ready.

## Stop/retry decision
- Do **not** rerun successful full suites, successful individual rollback programs, or the six passed native simulator journeys just to turn historical red parent runs green.
- No additional deployment or product edits are permitted. Recheck immutable heads before future work; repair a narrowly diagnosed tool issue only in QA branch with expected-SHA concurrency checks.
- This ledger records **completed scoped functional evidence** and **honest outstanding pristine/security/CI limitations**. It is not final release certification.
