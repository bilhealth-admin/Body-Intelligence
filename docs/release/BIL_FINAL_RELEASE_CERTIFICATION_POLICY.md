# BIL Final Release Certification Policy

This policy defines the release-candidate certification gate for **Body Intelligence Log (BIL)**.

## Immutable release candidate

1. Certification selects exactly one Git commit as the release candidate (RC).
2. Every certification checkout must use that exact SHA.
3. Checkout credentials are not persisted and certification jobs have read-only repository contents permission.
4. No certification job may commit, push, rewrite, format, regenerate product assets, change onboarding, or otherwise mutate the RC.
5. If the branch moves or any source/config byte changes after freeze, the certification is invalid. A new commit becomes a new RC and certification restarts from zero.
6. The deterministic BIL_RC_MANIFEST.json records every tracked file SHA-256/Git blob plus dependency inventory, Supabase migrations, Edge Function sources, Cloudflare sources, iOS configuration, Android configuration, and GitHub workflows.

## Status semantics

Every top-level certification gate has exactly one status:

- **PASS** — all evidence required by this policy exists for the exact RC.
- **FAIL** — the gate ran and a required assertion failed.
- **NOT RUN** — evidence is absent, incomplete, unavailable, or intentionally deferred.

NOT RUN is fail-closed and blocks **READY**. Passing a narrower unit/widget/static check never upgrades a broader device/live/store requirement to PASS.

## Current execution boundary

Until the owner explicitly authorizes release builds:

- do **not** build Android APK/AAB;
- do **not** build iOS app/IPA;
- do **not** upload to App Store Connect or Google Play;
- do **not** change Store tracks or submit for review;
- do **not** replace/generate application images or assets;
- do **not** change the current onboarding design or sequence.

Read-only live audits, disposable QA backend data, isolated databases, public endpoint probes, and simulator/widget tests are allowed when they do not create a release binary or mutate Store state.

## Required certification gates

The final report must cover all of the following, and none may be silently omitted:

1. One frozen RC and deterministic source/dependency/backend/config manifest.
2. True end-to-end journey from fresh install through authentication, onboarding, complete product paths, relogin/restore, and account deletion.
3. Byte/data-level local DB -> encrypted outbox -> Supabase -> download -> decrypt -> inbox -> local DB -> UI round-trip, two-device edits/conflicts, account isolation, interruption/retry/idempotency/stale/corrupt/session/key/offline/lifecycle cases.
4. Disposable-account live backend certification for Auth, RLS, food search, meal analysis, AI text/vision/voice, barcode, subscription verification, Cloudflare/workouts/public site/links/app-ads, deletion, Community, restore, plus required failure/status/timeout/malformed/partial-response matrix.
5. Apple/Google sandbox commerce lifecycle including trial, purchase, restore, reinstall/device transfer, upgrade/downgrade, cancel/expire/grace/retry/refund/revoke, duplicate/delayed server notifications, cached offline entitlement, paid no-ads and free behavior.
6. Complete permission-state matrix.
7. Lifecycle/chaos matrix with no corruption, crash, or permanent UI stall.
8. Upgrade migration certification from representative historical/installed schema versions with row/duplicate/FK comparisons and PRAGMA integrity_check.
9. Independent OWASP MASVS + MASTG open-book review of mobile clients and backend, including live authorization/RLS and dependency vulnerability triage.
10. Performance/stress/soak evidence for startup/render, large data sets, long AI/community use, image decoding, repeated navigation/scroll, memory/CPU/battery/DB/jank/network.
11. Requested iPhone/Android/tablet/OS/language/RTL/text-scale/VoiceOver/TalkBack/theme/keyboard/safe-area visual and accessibility matrix.
12. Exhaustive navigation graph crawl and auth/Premium/account-boundary checks.
13. Apple/Google Store policy/configuration certification against the exact shipping behavior and artifact.
14. Signed IPA/AAB inspection and clean-device install/launch from the exact RC (deferred until build permission).
15. Two distinct consecutive complete Master Certification runs on the same RC, each from clean checkouts, with no flaky or unexplained critical skip.
16. This single GitHub Master Gate orchestrating current QA/audit/evidence systems.
17. Agent-readable provenance, logs, manifests, security/dependency evidence, visual evidence and failure artifacts.
18. Independent full-day human exploratory pass.
19. READY only under the zero-defect/security/privacy/store and positive cloud/isolation/commerce/migration/device/signed/repeatability conditions defined below.

## Dependency and supply-chain rule

The RC must inventory dependencies and scan resolved coordinates where an advisory source is available. Any known vulnerability finding fails the automated dependency gate until triaged/fixed. Unsupported advisory ecosystems must remain identified in the inventory and cannot be described as scanned.

Certification pins toolchain/action versions wherever possible. "latest" dependencies are forbidden in certification paths because they break repeatability.

## Skipped-test rule

No critical test may disappear behind an unexplained skip. The all-test shards permit only an explicitly documented live-network workout-range test skip because the Master live-backend job executes that same test with its live opt-in enabled. Any other non-hidden skip fails the shard policy.

## Security baseline

The open-book security assessment uses the current OWASP Mobile Application Security Verification Standard (MASVS) and Mobile Application Security Testing Guide (MASTG), including storage, cryptography, authentication/authorization, network, platform interaction, code quality/supply chain, resilience and privacy.

Official baseline:
- https://mas.owasp.org/MASVS/
- https://mas.owasp.org/MASTG/
- https://mas.owasp.org/MASVS/controls/MASVS-CODE-3/

Live Supabase Security Advisor warnings are evidence requiring explicit triage. A warning is not automatically a vulnerability, but unresolved authorization-relevant warnings prevent the independent security gate from being called PASS.

## Store-policy baseline

Apple:
- https://developer.apple.com/support/offering-account-deletion-in-your-app/
- https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- https://developer.apple.com/support/third-party-SDK-requirements/
- https://developer.apple.com/app-store/review/guidelines/

Google:
- https://support.google.com/googleplay/android-developer/answer/10144311
- https://support.google.com/googleplay/android-developer/answer/9859455
- https://developer.android.com/guide/practices/page-sizes
- https://support.google.com/googleplay/android-developer/answer/9844487

The Store API read-only audit is sub-evidence only. It cannot replace a final signed-artifact reconciliation or Google Play pre-launch/device-lab results.

## READY condition

The report may say **READY** only when all top-level gates are PASS and all of these are simultaneously true:

- 0 known crash;
- 0 P0;
- 0 P1;
- 0 unresolved functional defect;
- 0 unexplained test failure;
- 0 unexplained skipped critical test;
- 0 High/Critical security finding;
- 0 privacy/store mismatch;
- cloud round-trip PASS;
- account isolation PASS;
- purchase/restore PASS;
- upgrade migration PASS;
- account deletion PASS;
- clean real-device PASS;
- clean signed-artifact PASS;
- two consecutive complete certification runs PASS on the same immutable RC.

Anything less is **NOT READY**.
