# BIL pre-production contract audit — 2026-09-05

## Decision

**NO-GO for a release build, TestFlight/Play upload, App Review submission, or
public rollout at this audit boundary.**

`OVERALL_PLUS8_RELEASE_CONTRACT: FAIL`

The shared Dart source is currently static-analysis/test green, but that is not
the same as a frozen, signed, installed release candidate. The remaining gates
include the Android Integrity store bootstrap, signed reviewer and
device/tablet evidence, signed navigation/lifecycle proof, and release-governance work
described below. The previously open Apple lifecycle/community deployments,
Apple/Google store-market reconciliation, and both platforms' workflow bindings
are now live/read-back PASS and are not re-opened by older snapshots.

This audit made only isolated release-contract, workflow-guard, contract-test,
and documentation edits through reviewed patches. It did not run a native
release build, sign an archive, upload a binary, change a store/Meta/backend
record, submit, publish, clean the worktree, stage, commit, or push anything.

## Audit boundary and evidence vocabulary

The dedicated staging snapshot was taken on `2026-09-05` immediately before
its two manifest outputs were created:

- branch: `release/store-rc-20260831`;
- HEAD: `21f16767fad82d625ced9b6da2146b66b4b27953`;
- source version: `1.0.0+8` (`pubspec.yaml:14-19`);
- no tag points at HEAD;
- `git status --short --untracked-files=normal`: **1,694 entries** (untracked
  directories collapsed);
- `git status --short --untracked-files=all`: **1,925 leaf paths**;
- the exhaustive staging CSV classifies those 1,925 paths plus its two manifest
  outputs: **1,927 unique rows = 552 INCLUDE + 1,203 EXCLUDE + 172 REVIEW**
  (`docs/release/BIL_PLUS8_STAGING_MANIFEST_2026-09-05.md`); and
- other remediation tasks were active during this audit, so these counts are a
  timestamped observation, not a freeze manifest.

Evidence labels used here:

- **SOURCE** — the behavior/configuration exists in reviewed source.
- **TEST** — a deterministic host test or static contract exercised it.
- **SIGNED/STORE PROOF REQUIRED** — only a signed installed binary, provider
  sandbox, or authenticated live read-back can establish the claim.
- **BLOCKER** — must be closed before the release action named in the finding.

The following commands supplied current host evidence:

- root verification: `flutter analyze --no-pub` exited `0` with `No issues
  found` in 64.3 seconds;
- root verification: `flutter test --no-pub --reporter compact
  --concurrency=4` exited `0` with 4,125 tests and `All tests passed` in 17:52;
- root verification: `git diff --check` exited `0` with no output; and
- post-audit focused verification ran 19 release/auth/commerce/admin/link/video
  test files with `flutter test --no-pub --reporter compact --concurrency=4`;
  it exited `0` with 133 tests and `All tests passed` in 2:15; and
- after the exact-8/staging documentation update, a final focused run of the
  release-candidate, store-market, Facebook-visibility and auth-boundary tests
  exited `0` with 14 tests and `All tests passed` in 1:58; and
- after the live Apple/Supabase market reconciliation, the store-market policy
  and dynamic price-comparison tests exited `0` with 9 tests and `All tests
  passed` in 0:44; and
- after the incoming-link/notification FIFO repair, an independent focused run
  of five Dart/source-contract files exited `0` with 26 tests and `All tests
  passed` in 0:28. This includes distinct auth callbacks, auth-before-generic,
  failure-continuation, reentrant A/B/C notification order, retained-head retry,
  both native FIFO source contracts and the vendored `app_links` cold-start
  replay contract; and
- independent review of the Apple catalog/market mutation tooling completed
  with 15/15 Node tests and `git diff --check` PASS. Its two explicit apply
  gates, exact/legacy preconditions, mixed-state resume, price check,
  per-mutation read-back, rollback, final race check and secret-safe public
  output all pass (`docs/release/BIL_APPLE_MARKET_POLICY_CORRECTION_2026-09-05.md`);
  and
- a later fail-closed active-artifact/tool audit corrected the Apple review-
  golden packager, its generated review manifest and the selected-price
  inspector from the superseded India ordinary-Premium set to
  **EGY/NGA/PAK/TUR**. The focused market-policy file then
  exited `0` with 6/6 tests, `node --check` passed for the inspector and the
  targeted diff check passed. The test explicitly rejects the legacy India
  sequence in all three active surfaces; historical transition fixtures and deployed
  migrations remain unchanged; and
- independent re-execution of the frozen-candidate validator tests exited `0`
  with 11/11 tests. A direct invocation against the present staging manifest,
  even with a matching digest, exited `78` because it declares the candidate
  unaccepted and retains 172 unresolved review rows; the accepted `1.0.0+8`
  fixture exited `0`. Source identity is bound separately to the protected
  audited SHA, avoiding an impossible self-referential commit marker inside the
  manifest; and
- independent re-execution of the environment/release-truth group exited `0`
  with 12/12 tests: ad-hoc builds default to `development`, while both signed
  workflows pass `BIL_ENVIRONMENT=production` explicitly; and
- after the final iOS dual-account source handoff, an independent execution of
  the exact 26-file workflow suite exited `0` with **180/180 tests**; the
  workflow contract alone passed 12/12. Thirteen JavaScript entry/modules
  passed `node --check`, both injected runtime probes passed, all eight Bash
  entry/modules passed `bash -n`, the Apple-tool secret-scope probe passed, the
  sensitive modules stayed below their enforced 300-line caps, targeted
  `git diff --check` passed, and an independent `flutter analyze --no-pub`
  ended with `No issues found`. No remote workflow or authenticated mutation
  was executed by this audit; and
- this audit ran `python tool/release/run_portable_release_tests.py
  --list-only`, which found 869 test files, explicitly excluded 29 and would run
  840. The release runner itself documents that exclusion boundary
  (`tool/release/run_portable_release_tests.py:1-8`, `:20-53`, `:57-106`).

These results confirm the present host source. They do not prove Xcode/Gradle
compilation, signing, installation, OS callbacks, StoreKit/Play Billing,
App Attest/Play Integrity, or store acceptance.

## Four prerequisite gates before platform runtime acceptance

| Gate | Configuration/source result | What still blocks progression |
|---|---|---|
| G1 — exact `1.0.0+8` identity and workflows | **PASS — SOURCE/TEST:** Android/iOS package identities agree; both signed workflows accept build 8 only, require the protected audited source SHA and manifest digest, and execute a fail-closed content validator. | **FAIL — CANDIDATE STATE:** the current manifest explicitly says `NO`/172 unresolved; no clean accepted commit/tag/digest or signed artifacts exist. |
| G2 — backend, integrity and privileged operations | **PASS — LIVE CONFIG:** Apple lifecycle functions/migrations/S2S, App Attest/profile/ASC bindings, Play Integrity/project/release-ID bindings and community admin v10 are live/read back; enforcement remains intentionally off. | Signed App Attest/Play Integrity and privileged-client canaries. |
| G3 — store catalogue and reviewer | **PASS — LIVE CONFIG:** both stores expose ordinary Premium only in owner-required EG/NG/PK/TR; Apple exposes AI in the other 168 launch markets; reviewer backend login/roles/Premium+AI/tokens and both private store fields pass; AI USD 5.99/49.99 passes. | **SIGNED/STORE PROOF REQUIRED:** signed no-paywall/no-ad reviewer sessions and device-localized offer rendering are absent. |
| G4 — Meta/social authentication | **PASS — CONFIGURATION/SOURCE:** Meta business/domain/app are verified and Published/Live; `email` and `public_profile`, the exact Supabase callback/provider keys, and the BIL return URL contract are configured; both workflows enable Facebook; Instagram is correctly unclaimed. The implemented flow is Supabase hosted browser OAuth, not the Meta Android/iOS SDK, so an Android platform/store entry is not a dependency of this source path. | **FAIL — SIGNED RUNTIME:** neither signed platform has Facebook browser-return E2E covering success/cancel/error/retry/logout/reinstall. |

No platform agent may call an emulator/simulator report a release PASS. After G1
through G4 configuration blockers close and the exact signed `+8` exists, the
Android phone/tablet and iPhone/iPad agents must each produce independent
runtime reports. Their four reports are release gates, not optional follow-up.

## Independent QA audit — iPhone owner/admin + iPad Apple reviewer workflow

`IOS_DUAL_ACCOUNT_COMMUNITY_CANARY_SOURCE_CONTRACT: PASS`

`IOS_DUAL_ACCOUNT_COMMUNITY_CANARY_REMOTE_RUNTIME: NOT_EXECUTED`

`IOS_SIGNED_DEVICE_ACCEPTANCE: NOT_SATISFIED`

The manual workflow is now a fail-closed **source contract** for an unsigned
`1.0.0+8` simulator canary. It is SHA/manifest bound, uses separately booted
iPhone-owner and iPad-reviewer sessions, and will not upload an artifact unless
the authenticated canary, backend cleanup and privacy scan all succeed
(`.github/workflows/bil_ios_plus8_dual_simulator_qa.yml:30-70`, `:401-474`).
This is approval to carry the source into clean-candidate review, not evidence
that the remote job ran and not signed-device acceptance.

| Required path | Current evidence | Independent result |
|---|---|---|
| Separate identities and reviewer access | Bootstrap authenticates both accounts, rejects identity equality, proves owner moderator plus reviewer non-admin/non-moderator, and verifies the reviewer's live closed-test grant, Premium AI entitlement, active subscription and at least 2,500 usable tokens (`tool/release/ios_plus8_canary/setup.mjs:26-136`, `:199-220`). The App Store review credential is fetched live into a mode-0600 runner-temp file (`tool/release/ios_plus8_simulator_ui/private_review_account.sh:3-59`). | **PASS — SOURCE/TEST; REMOTE NOT EXECUTED** |
| Friend request then acceptance | The iPad sends the request and the iPhone accepts; the oracle requires one exact pending pair, captures its UUID, then requires the same UUID to be accepted with `responded_at` (`tool/release/ios_plus8_simulator_ui/community_flow.sh:15-33`; `tool/release/ios_plus8_canary/community.mjs:16-44`). | **PASS — SOURCE/TEST; REMOTE NOT EXECUTED** |
| Bidirectional chat | Deterministic run markers travel reviewer→owner and owner→reviewer; both receiving UIs must show the exact marker and the oracle requires one exact sender/recipient row and UUID (`tool/release/ios_plus8_simulator_ui/community_flow.sh:35-54`; `tool/release/ios_plus8_canary/community.mjs:47-65`; `tool/release/ios_plus8_canary/run_identity.mjs:3-24`). | **PASS — SOURCE/TEST; REMOTE NOT EXECUTED** |
| Moderation without polluting the reviewer | The real reviewer creates a post, the owner **rejects** it, and the same reviewer iPad must show that exact post plus `Rejected`. A disposable third account supplies the approval path; owner approval must yield exactly +5 tokens and the approved post must be visible to the reviewer (`tool/release/ios_plus8_simulator_ui/community_flow.sh:56-91`; `tool/release/ios_plus8_canary/community.mjs:68-161`). Exact reviewer approval is deliberately excluded because its immutable receipt/reward would alter the App Review account. | **PASS — SAFE SOURCE DESIGN; REMOTE NOT EXECUTED** |
| Destructive administrator paths | Only the disposable account receives individual reset + exact custom message +2,500, targeted notification, moderator add/remove, block/write denial, suspension/write denial/reinstatement and restored write. Owner self-suspension must be denied. Global reset and general notification remain source/server/SQL tests because a production-wide mutation is not safe (`tool/release/ios_plus8_simulator_ui/owner_admin_flow.sh:10-103`; `tool/release/ios_plus8_canary/disposable_account.mjs:172-241`; `tool/release/ios_plus8_canary/owner_admin.mjs:16-66`; workflow `:447-456`). | **PASS — SOURCE BOUNDARY; REMOTE NOT EXECUTED** |
| Server authority and fail-closed lookup | Every claimed UI transition has an authenticated exact-row/RPC postcondition. Reviewer administrator access is required to return the protected denial. Service-role email discovery paginates and fails closed at its finite page cap instead of treating an incomplete scan as absence (`setup.mjs:74-98`; `tool/release/ios_plus8_canary/service_runtime.mjs:74-96`). | **PASS — SOURCE/INJECTED TEST; REMOTE NOT EXECUTED** |
| Cleanup, restoration and runner failure | Initial friendship/block/reviewer-suspension must be absent. Main cleanup reinstates first, removes exact IDs and markers, hard-checks service-role zero residue, proves reviewer credits unchanged and deletes the disposable account before evidence can upload (`tool/release/ios_plus8_canary/cleanup_evidence.mjs:73-260`; `tool/release/ios_plus8_canary/cleanup_readback.mjs:3-49`). A separate pinned Ubuntu watchdog re-authenticates, removes deterministic run residue even if no disposable account exists, and fails closed on ambiguous state (`tool/release/ios_plus8_canary/watchdog_cleanup.mjs:29-142`; workflow `:528-560`). | **PASS — SOURCE/TEST; REMOTE NOT EXECUTED.** The workflow honestly says a GitHub-wide outage/cancellation can still prevent the watchdog. |
| Secret and PII containment | Owner/ASC/service credentials are unset from the shell environment and re-scoped only to required processes; Apple tools run through environment-sanitizing wrappers. Reviewer credentials never enter `GITHUB_ENV`, live only in a trapped mode-0600 temporary file, and authenticated screenshots/accessibility data stay outside the upload set. The artifact scanner rejects exact private values and JWT-shaped text (`tool/release/ios_plus8_dual_simulator_ui.sh:18-68`, `:87-104`; `tool/release/ios_plus8_canary/evidence_io.mjs:36-107`). | **PASS — SOURCE/LOCAL PROBES; REMOTE NOT EXECUTED** |
| Evidence honesty and device boundary | The evidence labels the binary unsigned Debug/Simulator, records iPad portrait runtime only, states landscape is widget-contract-only, and lists Sign in with Apple, App Attest, Facebook callback/universal link, StoreKit, HealthKit/Watch, push and camera as signed-only (`.github/workflows/bil_ios_plus8_dual_simulator_qa.yml:331-397`, `:425-456`). | **PASS — CLAIM SCOPE. Signed/TestFlight iPhone+iPad evidence remains OPEN.** |

The independent source verdict is based on 12/12 workflow-contract tests,
180/180 tests in the exact workflow suite, JS/Bash syntax checks, injected
runtime/page-cap probes, secret-scope execution, dependency/action pins, module
line caps and diff checks. The remote simulator canary itself has not run, iPad
landscape simulator runtime is explicitly not executed, and the app has not
been signed or installed from TestFlight. Therefore the overall release verdict
remains **FAIL/NO-GO** even though this source contract is now eligible for the
future frozen INCLUDE set.

## Blocking findings

| ID | Gate | Evidence and impact | Required closure |
|---|---|---|---|
| P0-01 | Frozen candidate | The intended version is `+8`, while the current checkout is heavily modified/untracked and has no audited tag. The immutable staging snapshot records 1,694 normal status entries / 1,925 expanded leaf paths and classifies 1,927 rows including its own two outputs as 552 INCLUDE, 1,203 EXCLUDE and 172 REVIEW. Its companion delta currently observes 1,724 normal / 1,969 expanded leaf paths and 43 provisional INCLUDE additions, yielding a provisional 1,970-path universe when the still-present ignored CSV is counted (`docs/release/BIL_PLUS8_STAGING_MANIFEST_2026-09-05.md:24-57`). The older freeze report's 507/1,388/1,895 snapshot is superseded (`docs/release/BIL_RELEASE_TREE_FREEZE_AUDIT_2026-09-05.md:15-23`, `:205`). | Stabilize all agents, regenerate the manifest, resolve all 172 REVIEW rows, create a clean candidate from the reviewed INCLUDE set, and record commit/tag, manifest hashes and a clean status. Preserve this dirty evidence worktree. |
| P0-02 | iOS Integrity signed-canary gate | The earlier capability/backend blockers are now objectively closed: the exact live App ID and active distribution profile authorize Associated Domains, production App Attest, HealthKit, IAP, Push and Sign in with Apple; the profile/team/application identifier gate passes; the three App Store Connect CI bindings have successful GitHub API read-backs; and `app-attest` is live `ACTIVE` v2 with `verify_jwt=true`, production-only/build-8 configuration. Source independently validates server allowlists (`supabase/functions/app-attest/index.ts:421-441`, `:541-547`, `:607-612`) and both the profile and final IPA (`.github/workflows/bil_ios_signed_release.yml:140-180`, `:367-382`; `tool/release/verify_signed_ios_entitlements.py:57-94`, `:112-159`). Enforcement is correctly **OFF** until a genuine signed canary. | Produce/install the exact signed `+8`, prove App Attest registration/assertion, payload/action binding, replay rejection, reinstall/key loss and outage behavior, then make a separately reviewed staged-enforcement decision. Do not turn enforcement on merely because deployment/profile gates are green. |
| P0-03 | Android Integrity signed-canary boundary | Play's authenticated read-back identifies the linked Cloud project, shows Play Integrity `7/7` active and all seven requested verdict families enabled, but records no requests in the last 30 days. Fresh authenticated GitHub REST read-back confirms both required workflow bindings: `BIL_PLAY_INTEGRITY_PROJECT_NUMBER=1041595138122` and the immutable `BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID` secret are present (`docs/release/GOOGLE_PLAY_LIVE_RELEASE_AUDIT_2026-09-05.md:102-136`; `.github/workflows/bil_android_release_candidate.yml:46-61`, `:117-132`). Genuine `PLAY_RECOGNIZED`/`LICENSED` evidence still requires a Google-Play-known build. | Re-read both bindings immediately before CI. Permit only an explicitly reviewed, zero-rollout **internal-testing bootstrap** for the frozen candidate; validate Play-installed licensing/app/device verdicts, binding and replay denial with enforcement off. Do not promote closed/open/production before that canary and the old-client rollout plan pass. |
| P0-04 | No signed `+8` evidence | Existing store builds stop at `7`; build `7` predates this repair batch (`docs/release/APP_STORE_CONNECT_DSA_RELEASE_AUDIT_2026-09-05.md:59-85`). Both workflows themselves record that physical device proof remains required (`.github/workflows/bil_ios_signed_release.yml:386-396`; `.github/workflows/bil_android_release_candidate.yml:250-260`). | After P0-01 through P0-03, produce signed `+8` candidates and retain hashes, signing identities, embedded entitlements/manifests, exact commit, build flags, store validation logs, and installation provenance. |
| P0-05 | iOS live release record | The newest authenticated API addendum supersedes earlier GUI observations: release mode is `MANUAL`, reviewer/demo fields are present, and all four subscriptions plus Boost are `READY_TO_SUBMIT` (`docs/release/BIL_APPLE_PLUS8_STORE_GATE_AUDIT_2026-09-05.md:19-38`). There is still no `+8`; `What to Test` is empty; only one internal tester/no external group exists; and six historical crashes belong to `+7`, not the repaired candidate (`:46-64`). DSA/trader is owner-deferred and is **not** a source-build, signing or TestFlight blocker; it is handled separately below. | Preserve Manual mode and secret review values. Create focused `+8` TestFlight notes and close signed-device/crash evidence. Explicitly decide/read back Vision Pro. Attach only the clean `+8` plus the five READY commerce items to review. Do not claim EU production availability until the separate DSA storefront gate is satisfied. |
| P0-06 | Google catalog/track readiness | Authenticated live state is now authoritative: closed Alpha runs `+7` at full 177/177 rollout and is available to testers; internal/open are not started; production is inactive, though its three access prerequisites are complete and the application can be started; no `+8` exists (`docs/release/GOOGLE_PLAY_LIVE_RELEASE_AUDIT_2026-09-05.md:22-55`). The live ordinary-Premium set is the owner-confirmed EG/NG/PK/TR; AI yearly was corrected/read back at USD 49.99 for new subscribers; Boost remains base USD 4.99 with live `launch-50` USD 2.50; and build 7 has custom schemes only, no detected web links/domains (`:72-100`, `:138-210`). | Never use `+7` for production access or promotion. Freeze and sign `+8`, close the Integrity bootstrap, reviewer/billing/Facebook/account-deletion/tablet/App-Link/pre-launch matrix, reconcile listing/declarations/assets, then answer the production-access questions truthfully and seek owner approval before applying. Existing subscriber price migration is a separate owner decision. |
| P0-07 | Facebook surface is enabled in future signed binaries without device proof | Meta is documented Published/Live and the live browser-OAuth configuration is present. Source obtains a Supabase `/auth/v1/authorize?provider=facebook` URL, opens it in a strict Android Custom Tab or iOS `SFSafariViewController`, and contains no Meta native SDK dependency (`lib/features/auth/supabase_auth_service.dart:66-110`; `lib/features/auth/facebook_oauth_launcher.dart:4-47`; `android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILFacebookOAuthBridge.kt:12-89`; `android/app/build.gradle.kts:102-106`). Supabase's official Facebook Auth contract requires the Facebook OAuth app, `email`/`public_profile`, exact Supabase callback, provider keys and client `signInWithOAuth`; it does not require a Meta Android platform entry for this hosted browser flow. The removed Android entry is therefore not a blocker for the implemented integration; it becomes relevant only if a future native Meta SDK/store integration is adopted. Both signed build invocations enable and mark Facebook ready, but no signed mobile E2E exists (`.github/workflows/bil_ios_signed_release.yml:205-206`, `:348-349`; Android `:89-90`, `:154-155`). | Before accepting either binary, preserve/read back Meta Published/Live, only `email`/`public_profile`, the exact Supabase callback and enabled matching provider keys; then prove cancel/success/error/retry/logout/reinstall and return-to-app on signed iPhone/iPad and Play-signed Android. Keep Instagram login unclaimed/disabled unless separately configured and reviewed. Do not make optional Meta native-platform metadata a false browser-OAuth release gate. |
| P0-08 | Storefront price/claim truth | **LIVE CONFIG/SOURCE/TEST PASS; SIGNED DISPLAY OPEN:** AI Coach US matches on both stores at monthly USD 5.99 and yearly USD 49.99, whose computed saving is 30.45% and rounds to `Save 30%`. Both stores now expose ordinary Premium only in **EG/NG/PK/TR**. Apple's immediate authenticated read-back additionally proves the AI pair in exactly 168 markets, including IN and excluding NG, with `UPFRONT` availability and `availableInNewTerritories=false`. The new forward migration is live with `enabled=172`, `premium=4`, `ai=168`; active policy/canonical sources, the Apple review-golden packager, its generated review manifest and the selected-price inspector now all use the September 5 contract (`tool/apple_store_connect/canonical_store_pricing_2026-09-05.json:1-19`; `tool/apple_store_connect/apple_catalog_policy.json:12-31`; `tool/apple_store_connect/package_app_review_goldens.dart:20-35`; `store_assets/review/apple/v1.0/manifest.json:6-34`; `tool/apple_store_connect/asc_selected_prices_inspect.mjs:29-34`; `supabase/migrations/20260905170000_owner_store_market_policy_nigeria_alignment.sql:8-52`, `:120-141`). The focused fail-closed test requires all three active surfaces to use Nigeria and reject the legacy India sequence (`test/features/commerce/final_store_market_policy_alignment_test.dart:102-141`); it passes 6/6. The old EG/IN migration/file and explicit legacy-transition fixtures remain immutable history, not active authority. Fixed worldwide `Save 30%` is still false because localized pairs vary; Google Boost is USD 2.50 while Apple/reference artifacts use USD 2.49. | Preserve and re-read the exact catalog immediately before release. On signed storefront sessions, prove localized monthly/annual pairing, dynamic saving text, eligible/ineligible offer behavior, and the independent Boost prices; never normalize one store's localized price into the other. |
| P0-09 | Store reviewer signed-app gate | Both private store fields are populated and the credential was freshly authenticated without exposing it. Live server booleans prove exactly one confirmed active reviewer identity, successful password sign-in, a reusable 12-month grant, effective Premium + AI access, at least 2,500 usable tokens, and denial of administrator/moderator roles (`docs/release/GOOGLE_PLAY_LIVE_RELEASE_AUDIT_2026-09-05.md:289-369`). Source has an empty generic reviewer form and no compiled identity (`lib/features/auth/login_page.dart:14-49`; `test/auth_boundary_test.dart:12-23`, `:106-149`). What remains unproved is the exact signed `+8` UI session: no purchase/paywall/ad, all text/voice/vision paths, global/no-OTP reuse and deletion. | Preserve the proven private credential only in store fields. On each store-delivered `+8`, execute the remaining UI/device checklist and keep reviewer roles non-admin/non-moderator. Do not call the proven backend account a signed-binary PASS. |
| P1-01 | Sign in with Apple signed lifecycle proof | Source implements authorization-code exchange, nonce/subject binding and fail-closed server custody (`lib/features/auth/supabase_auth_service.dart:118-176`; `supabase/functions/apple-sign-in-token/index.ts:67-138`), server-to-server events (`supabase/functions/apple-sign-in-notifications/index.ts:37-74`) and revocation before account deletion (`supabase/functions/_shared/account_deletion_worker.ts:115-126`). Migration `20260905143000` and fixes `20260905160100`/`20260905160200` are remote/live; `apple-sign-in-token` and `apple-sign-in-notifications` are `ACTIVE` v2; the Apple server-to-server registration is configured. Deployment is PASS. | Prove first/return/private-relay/revocation/account-deletion behavior on the exact signed iPhone/iPad candidate, including fail-closed handling. Source/backend completion is not OS/store-session proof. |
| P1-02 | Incoming-link ordering | **PASS — SOURCE/TEST; SIGNED LIFECYCLE OPEN:** `_BILLinkBootstrap` attaches the vendored `app_links` replay stream synchronously and sends every auth or generic URI through one serial dispatcher (`lib/main.dart:245-279`; `tool/vendor_app_links/ios/app_links/Sources/app_links/AppLinksIosPlugin.swift:238-240`; Android plugin `AppLinksPlugin.java:130-132`). The dispatcher preserves arrival order, reports a failed item without poisoning the tail and drains accepted work on dispose (`lib/app/analytics/bil_incoming_link_controller.dart:6-36`). Tests now prove two distinct callbacks, auth-before-generic and failure continuation (`test/bil_incoming_uri_order_test.dart:8-99`). | Compile both native candidates, then prove cold/warm Safari and Custom Tabs returns, two rapid distinct callbacks, password reset, duplicate delivery and process death on exact signed `+8`. The former source race is closed; device/browser delivery remains a release gate. |
| P1-03 | Notification tap ordering | **PASS — SOURCE/TEST; SIGNED LIFECYCLE OPEN:** Dart now uses a bounded 32-route FIFO with deduplication; reentrant taps join the tail, removal occurs only after successful navigation and a thrown navigation keeps the head for retry (`lib/features/notifications/services/bil_notification_navigation.dart:40-104`, `:145-169`). Android uses the same bounded/deduplicated head-ack FIFO (`android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/MainActivity.kt:24-25`, `:106-124`, `:154-217`); iOS uses a bounded head-ack FIFO and explicitly captures `launchOptions[.remoteNotification]` (`ios/Runner/AppDelegate.swift:16-30`, `:84-87`, `:205-265`). Tests cover FIFO/deduplication, reentrant A/B/C, retained-head retry, cold/warm bridge payloads and both native source contracts (`test/features/notifications/android_notification_presentation_test.dart:90-177`, `:258-298`; `test/features/notifications/ios_notification_navigation_test.dart:135-203`). | Obtain Android/iOS native compile evidence, then prove terminated/background/foreground multiple taps and provider delivery on exact signed `+8`. Source FIFO is closed; OS/provider behavior is not inferred. |
| P1-04 | Remote push is not a shippable cross-platform enabled claim | Push defaults fail closed (`lib/app/environment/app_environment.dart:52-59`, `:130-132`); neither signed build invocation supplies the two push flags. Authenticated read-back shows `community-push-dispatch` `ACTIVE` v5, superseding older “undeployed” snapshots, and iOS source exposes an APNs bridge. Android still wires `BILUnconfiguredPushProvider` (`android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/MainActivity.kt:23-28`), and neither platform has signed registration/delivery/tap proof. | It is acceptable to ship an honestly unavailable remote-push surface. It is a blocker if release metadata/notes claim cross-platform community notifications. Enabling requires verified provider secrets, a real Android provider, signed APNs/FCM registration/delivery, lifecycle tap proof and privacy/permission copy reconciliation. |
| P1-05 | Executable release-configuration gate | **PASS — SOURCE/TEST:** both signed workflows invoke `tool/release/validate_release_configuration.dart`; the validator covers exact app/platform identity, cloud/receipt/store, Facebook, push consistency, integrity backend/Play project, checked-out-vs-protected audited SHA, manifest digest, explicit `YES` acceptance, zero unresolved reviews and exact `1.0.0`/`8` (`lib/app/environment/release_configuration_validator.dart:66-270`; `lib/app/environment/release_manifest_metadata.dart:10-31`; Android workflow `:78-100`; iOS workflow `:193-218`). Independent tests are 11/11 PASS; current manifest invocation is correctly FAIL/78 and the accepted fixture is PASS/0. | Preserve the gate. It must remain red until the reviewed manifest is regenerated with zero REVIEW rows and the protected source/digest variables are set to the clean frozen candidate. |
| P1-06 | Signed-CI reproducibility and freeze binding | **PASS — SOURCE CONTRACT / LIVE FREEZE VALUES OPEN:** both signed workflows reject every build except `8`, use fixed runner families, pin checkout/Flutter/artifact actions (and Android emulator action), execute portable release tests, compare `github.sha` with the protected audited SHA, and compare the manifest bytes with the protected SHA-256. The manifest content gate removes the prior hash-only bypass. No commit self-reference remains. | **BLOCKED by P0-01, not by missing code:** after the tree stabilizes, resolve all REVIEW rows, create the clean commit, regenerate/accept the manifest, set/read back the two protected values, and run the workflows. Review the broader non-signed verification workflow separately; never print credentials or treat pinned configuration as a successful CI run. |
| P1-07 | Administrator signed operational proof | Server authority is UUID membership, never email/client metadata (`supabase/migrations/20260831151527_ai_coach_admin_global_individual_reset.sql:3-16`, `:160-179`). Live `ai-coach-global-reset` is `ACTIVE` v10 and the migrations support audited global/individual resets, exact owner messages, notifications and exactly 2,500 idempotent Boost tokens. PII-free live checks confirm exactly one combined owner/admin, confirmed identity, active admin RPC, moderator enrollment and protected-admin status; the reviewer is distinct and denied both roles. | On signed `+8`, prove the hidden route, list/reset/message operations, audit rows, ordinary/reviewer denial, positive-balance gate reopening and zero-only closure. Do not create or document a second administrator. |
| P1-08 | Community moderation signed operational proof | Admin-only roster list/add/remove, moderator approve/reject, owner-protected suspend/reinstate, bounded reasons and private audit are service-authorized in source. Migrations `20260905160000`, `20260905160100` and `20260905160200` are remote/live, and `ai-coach-global-reset` is `ACTIVE` v10. Backend deployment is PASS. | Prove list/add/remove, approve/reject, suspend/reinstate, audit rows, protected-owner denial and fail-closed ordinary/reviewer denial on exact signed `+8`. Do not mislabel backend PASS as installed-client PASS. |
| P2-01 | Default environment naming | **PASS — SOURCE/TEST:** an ad-hoc build now defaults to `development` (`lib/app/environment/app_environment.dart:93-102`), while the Android and iOS signed build commands pass `BIL_ENVIRONMENT=production` explicitly (Android workflow `:143-149`; iOS workflow `:336-343`). The focused environment/release-truth group is 12/12 PASS. | Preserve the explicit production defines in signed workflows; do not infer production identity from an ad-hoc build. |

## Recently closed and intentionally staged live gates

This PII/secret-free boolean ledger prevents old audit snapshots from
reopening work that was subsequently completed. It also prevents configuration
success from being misreported as signed-device success:

| Gate | Boolean | Evidence meaning |
|---|---:|---|
| `IOS_APP_ATTEST_FUNCTION_ACTIVE_V2` | **TRUE** | Authenticated live read-back: function is active v2, JWT verification is enabled, and its deployed source hash is recorded outside this public summary. |
| `IOS_APP_ATTEST_PRODUCTION_BUILD8_CONFIGURED` | **TRUE** | Exact application identifier, production environment and build-8 allowlist were read back from live secrets without printing their values. |
| `IOS_PROFILE_AUTHORIZATION` | **TRUE** | Active profile and App ID/team match; App Attest, Associated Domains, HealthKit, IAP, Push and Sign in with Apple are authorized. The updated workflow/verifier tests passed 8/8 plus 9/9 contract tests. |
| `ASC_CI_BINDINGS_PRESENT` | **TRUE** | All three App Store Connect CI bindings were updated and read back through the GitHub API with successful status/timestamps; no credential value is reproduced here. |
| `IOS_INTEGRITY_ENFORCEMENT` | **FALSE — intentional** | Compatibility/observe mode remains the correct state until the signed `+8` canary succeeds. |
| `SIGNED_BUILD8_EXISTS` | **FALSE** | No native archive/AAB, installation or store-delivered `+8` proof exists yet. This is the remaining boundary, not a missing entitlement/secret claim. |

Final authenticated Supabase read-back supersedes the earlier mid-remediation
inventory. Migrations `20260905143000`, `20260905160000`, `20260905160100` and
`20260905160200` are remote/live. Current relevant functions are `app-attest`
v2 (`verify_jwt=true`), `apple-sign-in-token` v2 (`verify_jwt=true`),
`apple-sign-in-notifications` v2 (`verify_jwt=false`, as required for Apple's
signed server callback), `account-data-deletion` v13, `ai-coach-global-reset`
v10, `community-push-dispatch` v5, `ai-coach` v44,
`verify-store-purchase` v22, `play-integrity` v18 and
`reviewer-password-bootstrap` v13. Apple's server-to-server notification
registration is configured. A final pre-build read-back must preserve—not
recreate—this state.

## Store reviewer account contract

Reviewer credentials are deliberately omitted. They belong only in each
store's private review fields, never source, screenshots, logs, artifacts or
this document.

| Review requirement | Current boolean | Proof / remaining boundary |
|---|---:|---|
| Apple private review fields populated | **TRUE** | Newest authenticated Apple API read-back; values were not copied. |
| Google private app-access fields populated | **TRUE** | Authenticated Play read-back; values were not copied. |
| Generic dedicated reviewer route; no compiled identity/password | **TRUE** | `/reviewer-login` routes to empty normal email/password fields (`lib/app/router/app_router.dart:123-129`; `lib/features/auth/login_page.dart:14-49`; `test/auth_boundary_test.dart:12-23`, `:106-149`). |
| Facebook/Apple optional, not the only route | **TRUE — source** | The reviewer uses standard first-party email/password access; social login is not required. |
| Reviewer is distinct and not administrator | **TRUE — live account read-back** | PII-free role check supplied to the audit. It must remain non-admin and must not be silently enrolled as moderator. |
| Login succeeds from Apple-delivered `+8` | **NOT PROVED** | No `+8` exists. Exercise the exact private credentials through TestFlight. |
| Login succeeds from Google-delivered `+8` | **NOT PROVED** | No `+8` exists. Exercise the exact private credentials through the authorized Play test track. |
| Premium and AI entitlement without purchase | **TRUE — live server** | Fresh reviewer-authenticated checks prove effective Premium + AI and an active 12-month review grant. The absence of a signed-app paywall/ad is still unproved. |
| At least 2,500 usable AI tokens | **TRUE — live server** | Fresh reviewer-JWT usage RPC returned `total_remaining >= 2500`; repeated text/voice/Vision UI execution remains a signed-app test. |
| Credential is active/reusable for review window | **TRUE — live server** | Fresh password authentication passed and the review grant spans 12 months. Location independence and exact no-OTP/2FA signed UI flow remain unproved globally. |
| Account deletion discoverable in-app and on web | **TRUE — source/web path** | Router `/help/delete-account`, settings and help entry points exist (`lib/app/router/app_router.dart:471-473`; `lib/features/settings/settings_page.dart:210-218`; `lib/features/settings/help_center_page.dart:170`); execution still needs signed/backend proof. |

Apple requires an active demo account or fully featured demo mode, live backend,
explanations for non-obvious features/IAP and a final on-device submission:
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
Google's reviewer-access contract requires reusable, always accessible,
location-independent English instructions, credentials that bypass OTP/2FA,
social-login details where applicable and access beyond a paywall:
[Provide access instructions](https://support.google.com/googleplay/android-developer/answer/15748846?hl=en).
Google also requires both an in-app deletion path and a functional,
discoverable web deletion resource:
[Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).

These are independent gates: private store fields, fresh backend login,
entitlement/token sufficiency and role separation are **PASS**; installed
reviewer-session/no-paywall/no-ad/global modality behavior remains **NO-PROOF**
until the exact signed candidates exist.

## Owner/administrator account and operations contract

There is exactly one combined owner/administrator account. This report neither
names it nor records its credentials; it must not be confused with the separate
reviewer account and no second administrator is implied.

| Administrator requirement | Current boolean | Evidence / boundary |
|---|---:|---|
| Account exists exactly once | **TRUE — live** | PII-free authenticated account/role read-back. |
| Email confirmed | **TRUE — live** | Boolean only; no address printed. |
| Server `bil_can_manage_ai_coach` permission | **TRUE — live** | UUID membership is authoritative; the client cannot self-assign it (`supabase/migrations/20260831151527_ai_coach_admin_global_individual_reset.sql:3-16`, `:160-179`). |
| Enrolled community moderator | **TRUE — live** | Boolean roster read-back. |
| Protected administrator | **TRUE — live/source** | Removal/suspension contracts fail closed for the protected owner. |
| Reviewer is this administrator | **FALSE — live** | Accounts and roles are distinct. |
| Authenticated administrator RPC | **TRUE — live** | The single owner/admin passed the server permission check; no credential or identity is printed. Signed-client login and UI operations remain separate. |
| Admin console route and permission check | **TRUE — source** | Route exists at `lib/app/router/app_router.dart:578-580`; all mutations re-check server authority and mobile Integrity. |
| Individual reset by email + exact custom message | **TRUE — source/deployed contract** | UI at `lib/features/admin/presentation/ai_coach_admin_page.dart:190-449`; audited/idempotent SQL at `supabase/migrations/20260831151527_ai_coach_admin_global_individual_reset.sql:501-731` and `supabase/migrations/20260904010000_ai_coach_reset_token_grants.sql:188-371`. |
| General reset + exact owner-authored message | **TRUE — source/deployed contract** | UI `lib/features/admin/presentation/ai_coach_admin_page.dart:128-189`, `:454-563`; SQL `20260831151527_ai_coach_admin_global_individual_reset.sql:333-490`. |
| Targeted/general custom notification | **TRUE — source/server contract** | Presets and arbitrary copy are selectable in `lib/features/admin/presentation/admin_notification_controls.dart:47-107`, `:355-649`; server checks the privileged operation. |
| Exactly 2,500 non-expiring Boost tokens per reset | **TRUE — source/deployed contract** | `supabase/migrations/20260904010000_ai_coach_reset_token_grants.sql:3-55`, `:89-184`. |
| AI gate opens for any positive total balance, including 15 | **TRUE — source/test** | `total_remaining > 0`, independent of label (`lib/features/commerce/providers/commerce_providers.dart:61-76`; `test/features/commerce/ai_coach_credit_access_policy_test.dart:21-43`). A specific request may still cost more than the balance and correctly receive 402 without charging. |
| AI gate closes only at zero/no verified credit | **TRUE — source/test** | Same client policy; the server maps `ai_usage_exhausted` to HTTP 402 (`supabase/functions/ai-coach/server.ts:632-661`, `:790-806`). |
| Protected mutations and audit rows proved end-to-end | **NOT PROVED on `+8`** | Do not mutate production merely to make a document green; exercise a controlled canary after mobile Integrity works and verify denial for ordinary/reviewer accounts. |

### `ADMIN_COMMUNITY_MODERATION` sub-gate

- **SOURCE/TEST:** moderator list/add/remove, protected-owner denial,
  approve/reject, suspension/reinstatement, bounded reasons and private audit
  exist in current code. The latest suspension source is
  `supabase/migrations/20260905160000_admin_community_access_control.sql`, its
  Edge operations are at
  `supabase/functions/ai-coach-global-reset/server.ts:334-491`, and its focused
  test is
  `test/features/admin/community_member_access_admin_contract_test.dart`.
- **LIVE:** the single owner/admin is enrolled and protected; migrations
  `20260905160000`, `20260905160100` and `20260905160200` are remote/live; and
  `ai-coach-global-reset` is `ACTIVE` v10. Backend deployment is PASS.
- **OPEN:** on signed `+8`, prove the administrator can list/add/remove
  moderators, approve/reject, suspend/reinstate and observe audit entries,
  while both a normal account and the reviewer receive a fail-closed denial.
  Until that device/client proof exists, the end-to-end sub-gate is not PASS.

Vendor contract cross-checks reinforce these gates:

- Apple describes App Attest as a device-and-server protocol and recommends
  testing in development and onboarding users gradually, so source compilation
  alone cannot close P0-02:
  [DeviceCheck and App Attest](https://developer.apple.com/documentation/devicecheck).
- Apple says programmatic Sign in with Apple revocation requires a valid access
  or refresh token obtained by validating the authorization code. Its current
  account-deletion guidance also calls for revocation-event handling, which
  matches P1-01:
  [TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple),
  [Token revocation](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens).
- Google requires a Cloud project and describes Play Console linking for Play
  apps; it also identifies Play-installed/recognized and licensed verdicts as
  distinct evidence, which is why server readiness precedes the one internal
  bootstrap and the genuine verdict test follows it:
  [Play Integrity setup](https://developer.android.com/google/play/integrity/setup).

## Commerce and price contract

### Complete product inventory

The executable catalog contains exactly four subscription identifiers and one
repeatable consumable:

| Product | Term/type | Permitted offer/benefit claim | Runtime authority |
|---|---|---|---|
| `bil_premium` | Premium, one month | Paid only; no AI trial | Device store metadata + server entitlement |
| `bil_premium_annual` | Premium, one year | Paid only; no AI trial | Device store metadata + server entitlement |
| `bil_premium_ai_coach` | Premium + AI Coach, one month | Store-eligible seven-day new-customer trial; 1,000 trial tokens; then 2,500/week up to 10,000/month | Store metadata + server lifecycle/credit limits |
| `bil_premium_ai_coach_annual` | Premium + AI Coach, one year | Same exact trial/credit contract; not the inactive erroneous Google `annual`/`P1M` sibling | Store metadata + server lifecycle/credit limits |
| `bil_ai_boost` | repeatable consumable | 2,500 verified, stackable, non-expiring tokens; discount only from a complete eligible store offer | Store product/offer metadata + server purchase verification |

The IDs and term bindings are fixed in
`lib/features/commerce/domain/store_catalog_configuration.dart:31-77`; prices,
trials, availability, tax and localized display text are explicitly store-owned
at `:31-32`, and all five IDs are queried at `:88-96`.

The trial is fail-closed on exact AI product IDs plus the Google offer ID/tag and
period (`lib/features/commerce/domain/store_catalog_configuration.dart:38-49`;
UI acceptance at
`lib/features/commerce/presentation/bil_dynamic_store_offers.dart:16-21`). The
1,000-token trial and 2,500/10,000 paid limits are executable server/source
contracts, not price metadata
(`supabase/migrations/20260821124334_ai_trial_universal_1000_tokens.sql:3-7`;
`supabase/migrations/20260821102504_commerce_country_policy_and_ai_allowances.sql:252-256`;
customer copy at `lib/features/commerce/presentation/bil_store_copy.dart:120-127`).
They still require signed StoreKit/Play lifecycle proof; a visible trial string
does not grant a trial.

The production plans route is `/plans` (`lib/app/router/app_router.dart:230-235`)
and uses `BilStorePlansPage`, which initializes the device store, times out an
unavailable catalog after 12 seconds and filters provider metadata through the
market policy (`lib/features/commerce/presentation/bil_store_plans_page.dart:16-31`,
`:37-62`, `:87-124`). Premium feature gates route to this same plans surface;
AI Coach settings has a separate Boost purchase card, but its price also comes
from `queryProductDetails` (`lib/features/intelligence_center/services/ai_boost_purchase_service.dart:20-63`).

The repository also contains `CommercePaywall`, `PaywallState` and
`PaywallController`, but repository references show no production route or
production caller; they are exercised only by tests
(`lib/features/commerce/presentation/commerce_paywall.dart:8-17`;
`lib/features/commerce/presentation/paywall_controller.dart:8-16`). Their
`$4.99`/`$9.99`/`$19.99` test values are synthetic widget/state fixtures, not
offerings. Mark these classes explicitly legacy/test-only or remove them in a
separate reviewed cleanup after the candidate freeze so they cannot be mistaken
for the live paywall contract.

The UI displays `selectedOffer.localizedPrice` both on the selected tile and
sticky purchase action
(`lib/features/commerce/presentation/bil_dynamic_store_plan_components.dart:366-399`;
`lib/features/commerce/presentation/bil_dynamic_store_offers.dart:293-303`). A
store callback never grants access locally: subscriptions/Boost are protected
and verified server-side before entitlement/credit is accepted
(`lib/features/commerce/services/verified_store_purchase_service.dart:333-440`).

### Annual savings algorithm

`Save N%` is not hard-coded in the runtime plans page. It appears only when the
annual and monthly offers:

- have the same product family and currency;
- have positive store-provided micros;
- are exactly `P1Y` and `P1M`; and
- produce a positive saving.

The formula is
`round(((monthlyMicros * 12) - annualMicros) * 100 /
(monthlyMicros * 12))`, clamped to 0–100
(`lib/features/commerce/domain/store_price_comparison.dart:20-48`). The UI
renders that computed value at
`lib/features/commerce/presentation/bil_dynamic_store_plan_components.dart:191-205`
and `:335-425`. Currency formatting uses the offer currency and active locale
at `:468-477`.

Verified arithmetic for the Apple review fixtures:

- Premium Egypt: `129.99 × 12 = 1,559.88`; `(1,559.88 - 999.99) /
  1,559.88 = 35.893%`, which rounds to **Save 36%**.
- Premium AI Coach USA: `5.99 × 12 = 71.88`; `(71.88 - 49.99) /
  71.88 = 30.452%`, which rounds to **Save 30%**.

The algorithm and these market-specific outcomes are covered by
`test/features/commerce/store_price_comparison_test.dart:6-55`, `:58-103` and
`:105-146`. The widget test's literal `Save 30%` is fixture evidence, not a
production price (`test/features/commerce/bil_dynamic_store_offers_test.dart:522-578`).

### Fixed `Save 30%`, price and paywall artifact inventory

The production commerce UI contains no fixed currency price and no fixed
numeric `Save 30%`; it consumes store metadata. An exhaustive text search of
the commerce/runtime, release-document, Apple tooling/asset and commerce-test
boundaries found the literal English `Save 30%` in exactly these nine places:

- generated review package:
  `docs/release/BIL_APP_STORE_REVIEW_ASSET_MANIFEST_2026-08-29.json:128`,
  `store_assets/review/apple/v1.0/manifest.json:61`, and
  `docs/release/BIL_APP_STORE_REVIEW_ASSETS_AUDIT_2026-08-29.md:117`;
- generator source: `tool/apple_store_connect/package_app_review_goldens.dart:48`;
- the newest Apple live-audit statement, explicitly limited to the US
  storefront: `docs/release/BIL_APPLE_PLUS8_STORE_GATE_AUDIT_2026-09-05.md:92`;
- golden/tests:
  `test/features/commerce/goldens/app_store_review/v1.0/README.md:23`,
  `test/features/commerce/apple_review_product_screenshot_test.dart:167`,
  `test/features/commerce/apple_review_asset_package_contract_test.dart:69`, and
  `test/features/commerce/bil_dynamic_store_offers_test.dart:557`.

The parameterized production translation remains `SAVE {percent}%`, not a
numeric claim (`lib/app/localization/runtime_copy_extended.dart:40214`,
`:40508`). The Apple generator/review fixtures contain Apple planning values
129.99/999.99 EGP, USD 5.99/49.99 and USD 2.49. In particular, their USD 2.49
Boost value cannot be projected onto Google's independently configured live
USD 2.50 introductory offer. The remaining commerce tests use deliberately
synthetic values to exercise rendering, ordering, rounding and rejection.
None is runtime price authority.

Fixed monetary values also appear in dated policy/read-back documents. They are
not all equivalent evidence:

| Evidence family | Files | Meaning |
|---|---|---|
| Canonical owner policy | Active: `tool/apple_store_connect/canonical_store_pricing_2026-09-05.json:1-73`; `tool/apple_store_connect/apple_catalog_policy.json:12-31`; historical: `tool/apple_store_connect/canonical_store_pricing_2026-08-29.json` | September 5 business/reference choices and EG/NG/PK/TR split. The dated August file is preserved as explicitly superseded history. |
| Apple authenticated snapshots/package | `docs/release/BIL_APP_STORE_CONNECT_CATALOG_PACKAGE_2026-08-29.md:28-44`; `docs/release/BIL_ASC_V1_FINAL_API_AUDIT_2026-08-30.md:74-115`; `docs/release/BIL_FINAL_RELEASE_GATE_AUDIT_2026-08-31.md:47-57`; newest live addendum `docs/release/BIL_APPLE_PLUS8_STORE_GATE_AUDIT_2026-09-05.md:19-38`, `:72-106` | Dated Apple state, not permanent global price constants. The September 5 addendum is the controlling Apple read-back in this audit. |
| Google authenticated snapshots | Controlling read-back: `docs/release/GOOGLE_PLAY_LIVE_RELEASE_AUDIT_2026-09-05.md:138-210`; older snapshots: `docs/release/BIL_GOOGLE_BILLING_LIVE_CONFIGURATION.md:16-30`, `docs/release/BIL_LIVE_STORE_PREFLIGHT_2026-09-04.md:65-98`, `artifacts/release/google/2026-08-31-api-audit/credential-1-after-by.json:13-55`, `:4652-4699` | September 5 live state supersedes the dated 35.99 annual-AI observation. Historical files remain evidence of change, not current catalog authority. |
| Generated Apple pricing plans | `artifacts/pricing/BIL_APPLE_CATALOG_DRY_RUN_2026-08-29.json:16-63`; `artifacts/pricing/BIL_APPLE_CATALOG_FULL_PLAN_2026-08-29.json:16-63` | Generated from the canonical Apple policy; planning evidence, not live StoreKit. |
| Superseded market research | The historical files are enumerated in `tool/apple_store_connect/canonical_store_pricing_2026-09-05.json:60-72` | Explicitly superseded for active pricing by the September 5 canonical file; historical research must not configure a store. |
| Cross-store summaries | `docs/BIL_STORE_RELEASE_GATE.md:140-149`; `docs/release/BIL_STORE_API_COMPLETENESS_2026-08-31.md:57-64`; `docs/release/PLATFORM_PARITY_AUDIT_2026-09-03.md:55-58` | Secondary summary; cannot override a newer authenticated read-back. |
| Tests | `test/features/commerce` | Fixture assertions only, except that generated-review contract tests reproduce the named Apple asset package. |

This inventory also resolves the apparent legacy `$4.99`, `$9.99` and `$19.99`
paywalls: those amounts occur only in tests for the unrouted generic paywall.
They are not products configured for sale.

The local review manifest says `uploaded: false` at line 90, whereas a later
read-back says five attachments are live. This means the manifest is a local
package record, not current App Store Connect state; its field name should be
renamed/annotated on the next regeneration to prevent a false blocker.

### Owner-approved 30% rule and current store state

The September 5 owner decision is unambiguous: AI Coach monthly is USD 5.99;
the annual economic target is twelve monthly payments less 30%. The raw target
is `5.99 × 12 × 0.70 = 50.316`. A store cannot necessarily accept 50.316 as a
price point, so the owner must approve the closest supported point recorded by
each store. The repository's selected point is USD 49.99
(`tool/apple_store_connect/canonical_store_pricing_2026-09-05.json:36-51`), and
that produces `round(30.452%) = Save 30%`.

The authenticated September 5 Play mutation/read-back records the active
AI annual `yearly` base plan at USD 49.99 for new subscribers, replacing the
older USD 35.99 state. Existing subscribers remain at their current price until
Google's separate migration process is deliberately used
(`docs/release/GOOGLE_PLAY_LIVE_RELEASE_AUDIT_2026-09-05.md:157-199`). Therefore:

- `Save 30%` is mathematically correct for the documented US 5.99/49.99 pair
  on both Apple and Google;
- the older Google 5.99/35.99 observation, which calculated to `Save 50%`, is
  superseded current-state evidence but remains important change history;
- the app must never force 30% worldwide: every localized monthly/annual pair
  must calculate its own rounded saving under the source formula;
- migration of existing Google subscribers is a separate commercial decision,
  not something the app or this audit may silently trigger;
- Google's live Boost truth is USD 4.99 base with an eligible `launch-50`
  introductory offer displayed as USD 2.50; the older Apple/generator USD 2.49
  value is platform-specific planning evidence; and
- price-policy documents and generated screenshots never override the exact
  price/offer returned by the customer's device store.

### Ordinary Premium: live cross-store reconciliation completed

The final owner policy is exactly **EG/NG/PK/TR** for ordinary Premium on both
stores. A September 5 authenticated Apple read-back initially exposed the old
EG/IN/PK/TR set. The fail-closed availability update then removed IN, added NG
for both Premium periods, and immediately read back the corrected state:

- ordinary Premium monthly and annual: exactly EGY/NGA/PAK/TUR (4);
- AI Premium monthly and annual: exactly 168 markets, including IND and
  excluding NGA;
- availability mode: `UPFRONT`; and
- `availableInNewTerritories=false`.

The Apple Nigeria price points were verified before availability was changed;
their numeric values are deliberately not reproduced or inferred here. The
same-day authenticated result is recorded in
`docs/release/BIL_APPLE_MARKET_POLICY_CORRECTION_2026-09-05.md` and
`docs/release/BIL_APPLE_PLUS8_STORE_GATE_AUDIT_2026-09-05.md:89-135`; it
supersedes the August EG/IN snapshot.

The owner-confirmed September 5 Google policy and live read-back also report
ordinary Premium in EG, NG, PK and TR:

| Store | EG | NG | PK | TR | IN |
|---|---:|---:|---:|---:|---:|
| Google monthly | EGP 99.99 | NGN 1,859 | PKR 599 | TRY 99.99 | missing |
| Google annual | EGP 599.99 | NGN 11,159 | PKR 3,599 | TRY 599.99 | missing |

Evidence:
`docs/release/GOOGLE_PLAY_LIVE_RELEASE_AUDIT_2026-09-05.md:138-155`.

Both stores therefore pass the country-set contract. India's ordinary-Premium
availability is historical only, while Nigeria is now authenticated live on
both periods. Customer-visible prices remain store-derived and must never be
copied from Google or another Apple storefront.

The repository/backend contract is forward-only and aligned. Historical
`20260830180011_canonical_store_market_pricing_policy.sql` and the August
canonical file remain immutable evidence. Active policy now uses
`20260905170000_owner_store_market_policy_nigeria_alignment.sql`; the deployed
read-back reports `enabled=172`, `premium=4`, `ai=168`, routes EG/NG/PK/TR to
Premium, IN to AI, and CN to `not_for_sale`. The September 5 canonical JSON,
catalog policy and deterministic contract test reference the same split. This
closes the former cross-store/backend blocker without rewriting history.

Boost shows 50% only when Google supplies a complete eligible one-time offer
with full-price micros, explicit 50% discount information, offer ID and checkout
offer token, and the micros independently calculate to 50%
(`lib/features/commerce/services/verified_store_catalog_adapter.dart:188-245`;
`lib/features/commerce/domain/store_offer_metadata.dart:64-82`). The bundled
wrapper may not expose those fields, in which case the adapter deliberately
shows no discount
(`lib/features/commerce/services/verified_store_catalog_adapter.dart:188-191`).
Tests cover
both explicit and absent/fabricated offers
(`test/features/commerce/ai_boost_discount_offer_test.dart:12-137`, `:140-208`).

### Price source-of-truth order

1. Customer-facing price/period/offer eligibility: the exact StoreKit or Play
   Billing metadata returned for that signed-in storefront/account.
2. Access/credits: server verification of that exact store transaction.
3. Approved commercial anchors/territories: owner policy used to configure and
   audit each store, never injected as an app price.
4. Screenshots, docs and test fixtures: reproducibility evidence only; regenerate
   after any live catalog change.

## iOS manual release and TestFlight contract

The archive workflow uses manual distribution signing and does not let Xcode
silently change the app version/build number
(`.github/workflows/bil_ios_signed_release.yml:223-292`). It always validates
the resulting IPA with App Store Connect at `:399-427`. TestFlight upload is an
explicit boolean input and defaults to `false` (`:3-14`); only `true` executes
the upload at `:429-439`.

This workflow does **not** set the App Store version's release-after-approval
mode or attach products/builds to an App Review submission. “Manual signing,”
“upload to TestFlight,” and “manually release after Apple approval” are three
separate controls.

Repository evidence currently conflicts:

- the September 4 API read-back says release mode `AFTER_APPROVAL`/Manual and
  reviewer fields present
  (`docs/release/BIL_LIVE_STORE_PREFLIGHT_2026-09-04.md:16-37`);
- an early September 5 GUI audit says Automatic release and required reviewer
  fields blank
  (`docs/release/APP_STORE_CONNECT_DSA_RELEASE_AUDIT_2026-09-05.md:117-135`);
  but
- the newest September 5 authenticated API addendum records that the release
  setting was saved/read back as `MANUAL`, reviewer/demo fields are present and
  all five commerce items are `READY_TO_SUBMIT`
  (`docs/release/BIL_APPLE_PLUS8_STORE_GATE_AUDIT_2026-09-05.md:16-38`).

The newest authenticated API read-back wins. Before upload, re-read and preserve
**Manual release** without touching the populated secret review values. After
P0 gates close, run this audited workflow with exact build number `8` and
`upload_to_testflight=true`; verify processing, write focused
`What to Test`, then test that exact TestFlight build. Do not add it to App
Review until the signed matrix and commerce draft are complete.

Apple's current documentation confirms that “Manually release this version” is
an App Store Connect version setting, distinct from signing or uploading, and
that an approved manual version waits in Pending Developer Release:
[Select an App Store version release option](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option).
Its TestFlight contract separately requires test information, an uploaded build,
tester groups and installed-device feedback before submission:
[TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview).

### DSA/trader status — explicitly deferred, not a build blocker

The owner has explicitly deferred the DSA/trader decision until after this
repair build and initial distribution work. Therefore it is **non-blocking for
source completion, signing and TestFlight** and must not be used to stop those
actions. It also must not be silently marked complete or guessed from an email,
phone number, business name or screenshot.

Apple requires the Account Holder to declare trader or non-trader status even
when the app is not distributed in the EU. Apple states that an app distributed
only through TestFlight, or only outside the EU, is not treated as acting as a
trader in the EU; when a trader distributes in the EU, verified contact details
are displayed on the EU storefront. Apple also announced that, from October 17,
2024, trader status is required to submit EU app updates and that apps without
status were removed from EU availability on February 17, 2025:
[Manage EU DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements),
[Apple DSA deadlines](https://developer.apple.com/news/?id=yfacfeal).

This audit makes no legal classification. Before any EU App Store production
submission/availability, the Account Holder must either complete and read back
the applicable declaration/verification or explicitly exclude the EU
storefronts. The overall NO-GO in this report comes from independent frozen,
signed, Integrity, reviewer and device/store evidence gaps—not from the deferred
DSA item.

## Android track contract

The Android signed workflow builds and privately uploads a CI artifact; it has
no Google Publisher/Play-track upload step
(`.github/workflows/bil_android_release_candidate.yml:111-132`, `:263-279`).
That is the correct safe boundary until the backend/linking preconditions pass.
A separately created manual Play upload would bypass this contract and must not
occur. Once those preconditions pass, however, full production-like Integrity
proof requires a narrowly authorized bootstrap: Google's own Play Console help
instructs developers to publish to the internal test track (or intended test
track) when testing Play Integrity. That internal canary is evidence gathering,
not permission to promote the app:
[Use the Play Integrity API](https://support.google.com/googleplay/android-developer/answer/11395166).

Android source is configured for package
`com.bilhealth.bodyintelligencelog`, min SDK 26, target/compile SDK 36, arm64 and
x86_64, release shrinking, and optional release signing
(`android/app/build.gradle.kts:26-77`). A raw local Gradle release may be
unsigned when `key.properties` is absent (`:56-71`), so it is never store
evidence. Only the workflow's verified upload-certificate candidate qualifies.

Required order: freeze → backend/verifier readiness and non-store tests → signed
private AAB → owner-authorized zero-rollout internal-testing bootstrap →
Play-installed Integrity/billing/deep-link/tablet QA → catalog/declarations and
pre-launch closure → only then closed/open/production promotion or production
access/rollout. Internal App Sharing is not equivalent evidence for the final
candidate because Google re-signs it with a separate internal-sharing key:
[Internal App Sharing contract](https://support.google.com/googleplay/android-developer/answer/9844679).

## Meta/Facebook and Instagram contract

Authenticated Meta/Supabase evidence is now **PASS for configuration**: the
business and domain are verified, the Meta app is Published/Live, no required
actions remain, `email` and `public_profile` are ready, and the Supabase
Facebook provider, credentials and exact callback are configured
(`docs/release/META_BUSINESS_VERIFICATION_EVIDENCE_2026-09-05.md:17-84`,
`:107-163`). Both exact build-8 workflows compile Facebook enabled and ready,
while ads remain off. Facebook/Apple are optional because first-party
email/password remains available.

This app does not integrate the Meta Android or iOS SDK. Android requests the
Supabase-generated Facebook authorization URL and accepts only the exact HTTPS
Supabase host/path/provider/BIL return tuple before opening a pinned native
Custom Tab; iOS uses Supabase `signInWithOAuth` with `inAppBrowserView`, which
the locked launcher implements with `SFSafariViewController`
(`lib/features/auth/supabase_auth_service.dart:66-110`;
`lib/features/auth/facebook_oauth_launcher.dart:4-47`;
`android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILFacebookOAuthBridge.kt:12-89`;
`android/app/build.gradle.kts:102-106`). A repository-wide Android/iOS/package
dependency scan finds no `FBSDK`, Facebook Android SDK, `FacebookActivity` or
Flutter Facebook-auth plugin. The focused platform/login contract group passes
7/7 (`test/features/auth/facebook_oauth_platform_contract_test.dart` and
`test/premium_login_oauth_contract_test.dart`, run 2026-09-06); it proves URL
allow-listing, strict Custom Tabs/no-WebView source and platform launch-mode
selection, not a real provider session.

The official Supabase setup lists the browser-OAuth dependencies as a Facebook
OAuth app, `email`/`public_profile`, the exact
`https://<project-ref>.supabase.co/auth/v1/callback`, matching provider keys and
client `signInWithOAuth`; it does not list a Meta Android platform/store entry:
[Supabase — Sign in with Facebook](https://supabase.com/docs/guides/auth/social-login/auth-facebook).
Therefore the Android platform entry removed after Meta rejected the private
Play URL is optional metadata for a future native Meta SDK/store integration,
not a blocker for the implemented hosted browser flow. This is an inference
from the official contract plus the dependency/source trace, not signed-runtime
proof. The exact signed iOS Safari and Android Custom Tabs
cancel/success/error/retry/logout/reinstall/return flows remain
**FAIL / NO-PROOF**.

Instagram login is not configured or supported by the present auth contract.
It must remain absent/unclaimed in build-8 UI and metadata. Adding it would be a
new provider/data/review scope, not an automatic extension of Facebook Login.

## Deep links, authentication callbacks and notification navigation

### Confirmed in source

- Android disables Flutter's parallel deep-link owner and registers narrow,
  verified HTTPS callback/reset paths while retaining the non-credential
  `bil://` route scheme
  (`android/app/src/main/AndroidManifest.xml:119-175`).
- iOS disables Flutter's parallel deep-link owner, registers `bil`, adopts a
  scene manifest and declares the associated domain
  (`ios/Runner/Info.plist:53-102`;
  `ios/Runner/Runner.entitlements:7-16`).
- Callback acceptance is limited to HTTPS, exact `www.bilhealth.com`, port 443,
  exact two-segment paths and a recognized auth/error parameter; credential
  callbacks on the custom scheme are rejected
  (`lib/features/auth/bil_auth_callback_controller.dart:102-146`).
- The router handles auth/reset before generic launch/community links and
  rejects unknown routes (`lib/app/router/app_router.dart:96-118`).
- Password reset uses the exact HTTPS return URL
  (`lib/features/auth/supabase_auth_service.dart:24-27`, `:152-153`).
- Notification payloads are length-bounded and must resolve through the
  community deep-link allowlist
  (`lib/features/notifications/services/bil_notification_navigation.dart:145-169`).
- Distinct auth and generic URIs share one serial dispatcher, and the vendored
  native plugin replays the cold-start URI to the synchronously attached stream
  (`lib/main.dart:245-279`; `lib/app/analytics/bil_incoming_link_controller.dart:6-36`).

### Test boundary

The route contract discovers at least 80 literal `GoRoute` declarations and at
least 50 external aliases, and checks malformed/open-redirect inputs
(`test/launch_readiness/deep_link_exhaustive_source_contract_test.dart:8-45`,
`:48-101`). However, its “cold and warm” test simulates HTTPS cold handling by
assigning the expected route directly at lines 54-60; it is parser/source proof,
not an OS cold-start test. The iOS return test similarly verifies manifest,
source and vendored-plugin strings, while explicitly noting that source
registration is not live proof
(`test/apple_preparation/ios_return_to_app_link_contract_test.dart:6-49`,
`:51-82`, `:84-129`). Facebook tests mock the native method channel and inspect
Custom Tabs source; they do not authenticate a real account
(`test/features/auth/facebook_oauth_platform_contract_test.dart:17-91`).

The prior distinct-URI source race is now closed by deterministic tests; signed
proof must still cover fresh install, logged-out/logged-in, cold/warm process,
cancel/success/error, duplicate delivery, two different rapid links, Safari or
Custom Tabs return, password reset, process death/relaunch, logout/reinstall and
malicious lookalikes on both platforms.

## Android lifecycle/back/rotation/tablet contract

**SOURCE:** `MainActivity` is `singleTop`, resizable, predictive-back enabled,
uses `adjustResize`, and owns orientation/screen/layout/density/ui-mode changes
(`android/app/src/main/AndroidManifest.xml:88-128`). `onNewIntent` updates the
Activity intent and forwards bounded push payloads, and bridge resources are
cleared with the Flutter engine
(`android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/MainActivity.kt:154-242`).
Its push-tap handoff is a bounded, deduplicated FIFO that waits for a positive
Dart acknowledgement before removing the head (`:163-206`).
The shared compact and wide shells use `PopScope` and keep the same root-back
contract across the responsive breakpoint
(`lib/app/router/responsive_app_shell.dart:217-285`).

**TEST:** host widgets cover compact/wide navigation, system back, semantics,
160% localized text and Quick Add routing
(`test/responsive_shell_test.dart:119-405`, `:517-634`).

**SIGNED/STORE PROOF REQUIRED:** predictive back gesture, hardware back, nested
dialogs/sheets, rotation during camera/contact/BLE/store/auth work, process
recreation, split-screen/freeform, keyboard/IME, 7/10-inch tablets, RTL and
200% text on a Play-installed candidate. Manifest `configChanges` is a source
choice, not proof that every plugin future survives lifecycle transitions.

## iOS scene/Safari/iPad contract

**SOURCE:** iOS 15 and both iPhone/iPad families are configured
(`ios/Runner.xcodeproj/project.pbxproj:509-533`, `:637-738`); `SceneDelegate` is
compiled and inherits `FlutterSceneDelegate`
(`ios/Runner/SceneDelegate.swift:1-6`; project file `:24`, `:74`, `:185`,
`:432`). The app delegate uses a scene-aware active presenter
(`ios/Runner/AppDelegate.swift:127-159`), APNs callbacks/tap routing at
`:171-243`, and iOS Facebook uses Store-owned Supabase URL handling through
`SFSafariViewController` semantics
(`lib/features/auth/supabase_auth_service.dart:29-68`).

The AppDelegate now explicitly captures a terminated remote-notification launch
and uses a bounded, deduplicated FIFO with head acknowledgement
(`ios/Runner/AppDelegate.swift:16-30`, `:228-265`).

**SIGNED/STORE PROOF REQUIRED:** Safari consent/cancel/return, Universal Link
cold/warm delivery, permission sheets, background/foreground, scene reconnect,
iPad split view/stage manager, keyboard, rotations, RTL/200% text, terminated
APNs tap and TestFlight upgrade. The explicit source path closes the missing
handler finding, but terminated-notification behavior must still be observed,
not inferred from source tests.

## Workout-video uniqueness and listing-count contract

- **PASS — local binary inventory:** `rg --files` finds one repository video,
  `assets/branding/bil_splash_motion.mp4` (119,574 bytes), and no duplicate local
  SHA-256 group. Workout media is remote and must not be mistaken for bundled
  APK/IPA video duplication.
- **PASS — explicit catalogue truth:** two approved packs contain 302 logical
  movement records but one intentionally shared payload, yielding 301 unique
  video SHA-256 values
  (`lib/features/wellness/domain/wellness_content_pack.dart:22-29`;
  `docs/release/WORKOUT_BUNDLE_302_HANDOFF.md:16-30`). “300+ workout videos” is
  therefore supportable as a logical-catalogue statement, not as a claim of 302
  byte-distinct files.
- **PASS — source/test deduplication:** the discovery wall canonicalizes by
  video SHA-256 (stable ID fallback), keeps one preferred card and globally
  claims payloads across sections
  (`lib/features/wellness/presentation/bil_workout_videos_wall.dart:282-336`;
  `test/features/wellness/workout_videos_wall_test.dart:46-102`). Each signed
  release pack also rejects duplicate URL or digest internally
  (`lib/features/wellness/services/workout_release_verifier.dart:76-77`,
  `:94-95`, `:126-134`).
- **OPEN — exact candidate/runtime:** regenerate the catalogue-count evidence
  from the frozen candidate and prove all 301 unique payloads load/play once on
  phone/tablet and iPhone/iPad. CDN availability, caching, decoder behavior and
  signed UI playback cannot be proved by the host dedupe test. Store copy must
  not silently change “300+” to “302 unique videos.”

## CI secret and build-flag contracts

### Exact build identity

| Contract | Current result |
|---|---|
| Dart version | **PASS — SOURCE:** `pubspec.yaml` is `1.0.0+8`. |
| Android identity | **PASS — SOURCE:** package `com.bilhealth.bodyintelligencelog`; Flutter provides `versionName=1.0.0` and `versionCode=8`. |
| iOS identity | **PASS — SOURCE:** bundle `com.bilhealth.bodyintelligencelog`; `CFBundleShortVersionString`/`CFBundleVersion` resolve from Flutter build metadata. |
| Signed workflow input | **PASS — SOURCE:** both workflows now require `BUILD_NUMBER == 8`; `+7` and any unaudited later number fail. |
| Store artifact | **FAIL / ABSENT:** neither store has a signed/uploaded `+8`; source identity is not artifact identity. |

### Secret-name contract

Required Android inputs are the keystore, four signing values/certificate hash,
backend integrity evidence ID and Play-linked project number
(`.github/workflows/bil_android_release_candidate.yml:43-68`). Required iOS
inputs are the distribution certificate/password, provisioning profile, Team
ID, three App Store Connect API values and backend integrity evidence ID
(`.github/workflows/bil_ios_signed_release.yml:80-100`). These workflows check
presence/shape and inspect produced signatures; they cannot prove that the
generic backend evidence ID refers to the currently deployed functions. That
limitation is explicit in
`docs/release/BIL_MOBILE_INTEGRITY_DEPLOYMENT_2026-09-05.md:101-106`.

The historical Apple addendum at
`docs/release/BIL_APPLE_PLUS8_STORE_GATE_AUDIT_2026-09-05.md:112-148`,
`:200-217` reported missing profile authorization and three absent App Store
Connect Actions bindings. Those findings are now superseded: the exact active
profile/App ID passes the workflow verifier with App Attest, Associated Domains,
HealthKit, IAP, Push and Sign in with Apple, and all three CI bindings have
successful GitHub API update/read-back timestamps. The values remain secret and
are intentionally absent from source, shell output and this report. The open iOS
gate is the signed `+8` IPA/canary—not profile or ASC-binding configuration.

Android's Play-linked project-number variable and immutable backend verifier
release-ID secret are now present and were authenticated by GitHub read-back
(`docs/release/GOOGLE_PLAY_LIVE_RELEASE_AUDIT_2026-09-05.md:116-140`). Required
Android names are `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
`ANDROID_UPLOAD_CERTIFICATE_SHA256`,
`BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID` and the repository variable
`BIL_PLAY_INTEGRITY_PROJECT_NUMBER`. Required iOS names are
`APPLE_DISTRIBUTION_CERTIFICATE_BASE64`,
`APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`,
`APPLE_PROVISIONING_PROFILE_BASE64`, `APPLE_TEAM_ID`,
`APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
`APP_STORE_CONNECT_PRIVATE_KEY_BASE64` and
`BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID`. Presence/read-back is PASS; final
artifact signing and provider canaries remain open. Values are never recorded
here.

No provider secret belongs in the Flutter binary. Supabase uses a publishable
client key while privileged provider credentials remain server-side
(`lib/app/environment/app_environment.dart:14-28`). Before release, inventory
the final `--dart-define` list in the evidence artifact and prove that no
unexpected define or secret entered the archive.

## Documentation contradictions and precedence

The following must be reconciled before declaring the release package
“documented and verified”:

1. `TESTER_NOTES_CLOSURE` records 4,121 tests at line 136; the current root run
   completed 4,125. Update the closure count only from an archived final run.
2. September 4 API evidence and an early September 5 GUI observation disagree
   about release mode/reviewer fields. The later authenticated September 5 API
   addendum supersedes both: `MANUAL`, review fields present, commerce
   `READY_TO_SUBMIT`. `+8`, TestFlight notes and signed proof remain open; DSA
   is a separate owner-deferred EU storefront gate, not a build/TestFlight gate.
3. The freeze document's status counts/hash allowlist predate active edits and
   explicitly require recomputation.
4. `TESTER_NOTES_CLOSURE:210-216` says the client release flag remains disabled,
   while both future signed workflows compile it as true. Clarify that the
   existing `+7` client is disabled and a future `+8` must not be built until
   both verifiers are ready.
5. The Apple review-asset manifest's `uploaded:false` is local-package state,
   not current App Store Connect attachment state.
6. Older platform/native and Supabase deployment reports are historical
   snapshots. Current authenticated provider read-back and the newest dated
   closure document supersede their “not deployed” or product-state statements.
   In particular, the Apple lifecycle and community-access migrations are now
   remote/live; the Apple functions are v2 and community administrator Edge
   boundary is v10. Older local-only/v7 statements must not drive release state.
7. The earlier iOS profile/ASC-secret failure is historical. The active exact
   App ID/profile and three ASC CI bindings now pass authenticated read-back;
   the controlling open evidence is the final signed IPA and installed canary.
8. September 4's Google USD 35.99 AI annual price is historical. The September
   5 authenticated mutation/read-back at USD 49.99 supersedes it for new
   subscribers; existing-subscriber migration remains a separate decision.
9. Old documents that mention a compiled reviewer identity are superseded by
   the generic empty-field route and boundary test. Private credentials remain
   store-owned; fresh backend login, Premium/AI, token and non-admin role checks
   pass, while no-paywall/no-ad/device modality behavior still needs exact
   signed-candidate proof.
10. The old release-candidate document falsely labelled an historical parent
    hash as accepted for the current tree. It now declares
    `CURRENT_PLUS8_CANDIDATE_ACCEPTED: FALSE`, and both signed workflows accept
    exact build `8` only. A new immutable commit/tag/allowlist is still required.
11. The earlier Apple EG/IN/PK/TR snapshot is historical. The authenticated
    same-day post-update read-back, September 5 canonical policy/test, and live
    forward migration now align Apple, Google and backend on ordinary Premium
    EG/NG/PK/TR; AI remains in the other 168 Apple launch markets. Dated Apple
    screenshots and the immutable August migration must not override that newer
    evidence or be edited to erase the change history.
12. Two active Apple utilities and their generated review manifest still
    referenced the superseded India ordinary-Premium set after the live
    reconciliation. All three now use EGY/NGA/PAK/TUR, and a fail-closed source
    test rejects regression to EGY/IND/PAK/TUR. India remains intentional only
    for AI availability and legacy transition fixtures/history; those
    historical records were not rewritten.

Evidence precedence for release decisions:

1. exact signed candidate inspection and authenticated current provider/store
   read-back;
2. archived CI/device logs tied to the exact candidate hash;
3. current source and deterministic tests;
4. dated reports and screenshots; and
5. plans, fixtures and marketing assets.

No lower level may overwrite a contradiction at a higher level.

## Minimum signed-device/store matrix

Run against the exact hashed candidate, not a debug build:

| Area | iPhone/iPad | Play-signed Android/tablet |
|---|---|---|
| Install/upgrade | clean install and upgrade from build 7/TestFlight | clean install and upgrade from alpha 7 |
| Auth | email OTP, reset Universal Link, native Apple first/return/relay/revocation/deletion, Facebook Safari cancel/success/error | email OTP, reset App Link, Google return, Facebook Custom Tabs cancel/success/error |
| Integrity | App Attest registration/assertion, changed payload/action, replay, reinstall/key loss, outage | Standard Play token, request hash/action, replay, licensing/app/device verdicts, outage/quota |
| Commerce | all locally available products, trial eligibility/ineligibility, purchase, pending, cancel, restore, renewal/expiry/refund/revoke, Boost | exact base plan/offer token, purchase, pending, cancel, restore/change, account hold/pause/expiry/refund, Boost consumption/idempotency |
| Native data | HealthKit/Watch, camera/photo limited access, BLE, microphone/speech | Health Connect/Wear, camera/gallery, BLE/location variants, microphone/speech |
| Lifecycle | Safari/permission/store return, background/foreground, scene reconnect, terminated APNs tap | predictive/hardware back, Custom Tabs/permission/store return, rotation/process recreation, notification `onNewIntent` |
| Layout/accessibility | iPhone + iPad portrait/landscape/split view, RTL, 200% text, keyboard | phone + 7/10-inch tablet portrait/landscape/freeform, RTL, 200% text, IME |
| Tester repairs | all 19 PNG screenshots plus `IMG_7632.HEIC` scenarios | all shared scenarios plus Android-specific back/tablet/provider paths |

Release progression is blocked until four independent build-8 runtime reports
exist: **Android phone**, **Android tablet**, **iPhone**, and **iPad**. An Android
emulator may prove responsive widgets, rotation and routing but cannot close
Play signing/licensing/Integrity, store billing, BLE/Health Connect, native
Facebook or production notification delivery. An iOS simulator may prove layout,
scene routing and localization but cannot close App Attest, APNs, StoreKit,
HealthKit/Watch, native Sign in with Apple/Facebook or provisioning. Every report
must label simulator/emulator versus signed physical device and tie evidence to
the same candidate SHA-256/source commit.

The tester closure correctly classifies the screenshot batch as source-fixed
with explicit device/external gates rather than “proved fixed in production”
(`docs/release/TESTER_NOTES_CLOSURE_2026-09-04.md:31-79`, `:249-263`).

## Ordered path to GO

1. Finish all source agents; preserve the now-tested P1-02/P1-03 FIFO contracts,
   obtain both native compile results, and keep OS/browser/provider lifecycle
   behavior in the exact signed-device matrix.
2. Recompute the release allowlist and create the clean, immutable `+8`
   candidate. Populate/read back the already-enforced protected audited-source
   SHA and accepted-manifest digest bindings.
3. Preserve the now-green App Attest deployment/profile/ASC-binding and Play
   project/release-ID gates in compatibility mode. Keep both enforcement
   policies off until their signed store-delivered canaries.
4. Preserve Apple's verified Manual release mode, populated reviewer/demo
   fields, five `READY_TO_SUBMIT` commerce items, and the now-aligned
   ordinary-Premium EG/NG/PK/TR and AI-168 catalog; explicitly decide Vision
   Pro, and reconcile Google assets/access/declarations against its current
   5.99/49.99 AI and 4.99/2.50 Boost state. Re-read both stores without copying
   secrets into evidence. Track DSA separately as the owner-deferred EU
   production-availability gate; do not let it block signing or TestFlight.
5. Preserve/read back Meta Published/Live, `email`/`public_profile`, the exact
   Supabase callback/provider keys and BIL return allow-list; keep Instagram
   unclaimed; prove both Facebook browser returns on the exact signed candidates.
   Do not block this hosted OAuth path on an unused Meta native-SDK platform
   entry.
6. Preserve/read back the now-live Apple lifecycle and community access-control
   migrations/functions. Preserve the single owner/admin and separate non-admin
   reviewer booleans; never expose credentials or create a second administrator.
7. Run pinned full verification plus the signed workflows. First retain private
   signed artifacts and inspect them. Then upload iOS to TestFlight explicitly;
   use only the owner-authorized zero-rollout Play internal bootstrap needed to
   obtain genuine Integrity evidence before any promotion.
8. Complete the four independent Android phone/tablet and iPhone/iPad reports,
   then the full signed-device/store matrix; attach logs, screenshots, crash
   diagnostics, provider receipts and hashes to the exact build.
9. Reconcile privacy manifests/labels, purpose strings, metadata, review notes,
   pricing screenshots and all current docs against that exact binary.
10. Only after every applicable P0/P1 closure has objective evidence may the
   owner create the review submissions or production rollout.

Until then, the accurate release statement is: **host source checks pass; no
clean signed `+8` candidate or production-ready store submission is proved.**
