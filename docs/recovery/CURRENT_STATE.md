# BIL recovery current state

Checked: 2026-09-08T18:30:28+03:00 (Africa/Cairo host)

## Preserved source baseline

- Earliest release branch recorded by the handoff: `release/store-rc-20260831`
- Preserved original working repository at this continuation's boundary:
  `codex/bil-release-recovery-20260908`
- Original/current baseline commit: `21f16767fad82d625ced9b6da2146b66b4b27953`
- Separate safety worktree branch used for this continuation without resetting
  or discarding the original dirty tree:
  `codex/bil-community-policy-recovery-20260908`
- Pre-change tracked state: 680 paths (`624` modified, `56` deleted).
- Pre-change untracked state: 2,545 files, 2,450,100,269 bytes.
- No staged changes existed; the saved index patch is intentionally empty.
- Git LFS's `post-checkout` shell wrapper failed to fork after the branch switch.
  The switch stayed on the same commit, the tracked-status count remained 680,
  and no checkout content changed.

Logical recovery commits created in this worktree:

- `4540401` — reconcile deployed migration history.
- `2bf331b` — enforce the Community policy ledger and default-ACL boundary.
- `fcee4c5` — add policy-aware Community write preflight.
- `f4733a3` — integrate policy-aware Community/social surfaces and tests.
- `aeac11e` — publish the canonical Community Guidelines web source.

The documentation-only closure is committed separately after final evidence
checks; unrelated inherited dirty-tree paths are intentionally left untouched.

The original ten commits were:

```text
21f1676 ci: align contract tests with renamed migrations
c2a4f7a Merge remote release updates into release/store-rc-20260831
c83d4bd release: build 8 final fixes and store artifacts
911d8e9 fix: restore existing cloud profile on fresh install
b2a39d3 fix: unblock onboarding and workout previews
955baf1 fix(ios): restore Console app icon
a00ffc4 normalize signed ios entitlements evidence
cc97aab harden ios signed entitlement verification
1235e7e fix ios signed entitlement evidence parser
7998c2a fix(ios): force manual App Store signing
```

## Recovery backup

The exact recovery set is outside the source worktree at:

`C:\Users\HP 1040 G8\.codex\visualizations\2026\09\08\01a07ede-370c-7bc1-93b6-fe5ffb5708fa\bil-recovery-backup-20260908`

It contains a verified complete Git bundle for the base commit, a full binary
working-tree patch, the empty index patch, the full untracked manifest and tar,
and a separate list for 34 tracked recipe-catalog paths that Git reported as
deleted because their directory was inaccessible. Those 34 status entries are
recorded separately because `git diff` warned and omitted their contents.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `baseline-head.bundle` | 2,093,355,066 | `8531B420DA475EAEBAE914CAD2C057679868CEA2011613066E7F766A5C98FDA7` |
| `working-tree.patch` | 51,305,926 | `F2864D54C6F7C209F297D6979B5DA9854CD3A3EEFFB1FA1B534FFEB40BF52092` |
| `index.patch` | 0 | `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855` |
| `untracked-paths.txt` | 211,937 | `EC1F48911DD99F54B59F7234D713E42CFA2DEAF7DD7FFBA171A46FAE8E34052C` |
| `untracked-files.tar` | 2,452,044,288 | `A123786EA833DD7C1AFFDB5D1A9A266377B1F4838CED1FCFFD3B945888E50F38` |
| `tracked-status-porcelain.txt` | generated | `2D5AE79873A394626BD66EE932D793D76372A2E634021BD65900B2BBA92CA09E` |
| `inaccessible-tracked-deletions.txt` | generated | `BE440168E49CCC9054DE8D74EB793069C70998386F40E11CF23FD7F4A3D9FD7F` |

`git bundle verify` passed and reported the complete history at `21f1676`.
The untracked archive contained exactly 2,545 entries, matching its manifest.

An additional exact pre-continuation backup is stored at
`G:\BIL_Project\BIL_recovery_backups\body_intelligence_log_20260908_pre_recovery`.
Its SHA-256 manifest contains 3,239 unique files totaling 2,473,835,219 bytes.
The final read-only verification rehashed every original-repository file:
**3,239/3,239 paths, lengths and hashes matched**, with zero missing, length,
hash, malformed-path or out-of-root mismatches. Original Git HEAD, branch and
all 3,261 status entries also matched the captured baseline exactly: 657 tracked
status paths (22 deleted), 2,604 untracked paths and zero staged paths. The
manifest SHA-256 is
`7B38B809F3E9E17BA265C827A8F1B9D4ECC4E8240D1CF57D59F76750EB680C92`.

## Local toolchain and application identity

- Windows: `10.0.26200.9278` (Windows 11 family)
- Flutter: `3.44.6` stable, framework `ee80f08bbf`
- Dart: `3.12.2`
- DevTools: `2.57.0`
- Java: OpenJDK `21.0.10`
- Gradle wrapper/runtime: `9.1.0`
- Android SDK installed under `G:\BIL_Toolchains\Android\SDK`, including API
  35 and 36 platforms.
- Android `compileSdk`: 36
- Android `targetSdk`: 36
- Android `minSdk`: 26
- Android application ID: `com.bilhealth.bodyintelligencelog`
- Flutter source version: `1.0.0+8`
- iOS deployment target: 15.0
- iOS bundle ID: `com.bilhealth.bodyintelligencelog`
- iOS marketing/build values are supplied through Flutter build settings;
  tests use their own bundle suffix.

Flutter Doctor also found that the PATH resolves `flutter` and `dart` from
`G:\BIL_Toolchains\Flutter\flutter`, while the explicitly verified SDK is
`C:\develop\flutter`. Recovery commands pin the verified executable instead of
depending on that ambiguous PATH.

## Release-candidate provenance

The local release worktree
`G:\BIL_Release_Candidates\20260906\body_intelligence_log_plus8` is clean at
`de3f17e56853698f40726291a46733c095e07c5e` on
`release/android9-ios10-20260907`. That commit configures the Android build-9
and iOS build-10 workflows and their source manifests. This proves the intended
candidate source/configuration, not that signed artifacts were produced from it.

The independently retained store evidence currently proves only:

- Android build 8 AAB: source `6d25a6ad3ca7eb3242b723ced6ad7d7296f673eb`,
  SHA-256 `54e6167516a9d35959f4dc0aef4ce4384c208bddfe04fd07c32f75f152887801`.
- iOS build 9 IPA/TestFlight: source
  `9c79e5468fdcaa13dbb6e7182427b373dbd4b9f7`, SHA-256
  `5f0d8f6d25761d24df5d0f33f854295907365b02cca6ec213fc82c46f10b05d7`.
- The 2026-09-07 App Store Connect readback listed valid builds through build 9;
  it did not list build 10.
- No local build-9 AAB or build-10 IPA was found in the candidate worktree.

Therefore exact signed Android-9/iOS-10 artifact provenance is **NOT VERIFIED**.
The source manifests are preparatory evidence only; signed artifact hashes,
workflow-run identity, store processing, and device evidence remain required.

## Backend baseline and safe recovery changes

- Supabase project: `tgmanzhqulksykhslrzb`
- Project health: active/healthy
- PostgreSQL: `17.6.1.155`
- Live migration `20260908013800_bil_community_social_v2` and its Social v2
  objects exist and were not rebuilt or replaced.
- All five initially absent migration sources are now present locally. Four
  (`20260906100000`, `20260906110000`, `20260906120000`, and
  `20260907010000`) are exact release-candidate copies from commit
  `de3f17e56853698f40726291a46733c095e07c5e`, verified by SHA-256, Git blob,
  and no-index diff; their individual evidence is recorded in
  `SERVER_RECONCILIATION.md`.
- `20260908013800_bil_community_social_v2` was recovered directly from the
  live migration-history `statements[1]` value. The deployment record is
  23,548 UTF-8 bytes with SHA-256
  `e36139da4a97becd840325080e57dbb9fc6a6f0d99481bdbba6bcef08ac46812`; the
  local Git text file has only the required terminal LF in addition (23,549
  bytes; SHA-256
  `a44a3e659fbed85e13f1a24518c2035808c9ec26963275f2c4ee004877e91293`).
  Removing that one LF in memory reproduces the deployment SHA exactly. No
  Social v2 object was reconstructed or replaced.
- `20260908132433_community_policy_client_status_rpc` was then applied
  successfully by the Supabase CLI only. A fresh independent production
  readback on 2026-09-09 now aligns all **124/124** local versions with
  production through
  `20260908235044_harden_legacy_community_writes_and_reports`; there is no
  local-pending or remote-only migration.
- This migration added two narrow RPCs only: the `SECURITY INVOKER`,
  server-clock policy/own-receipt status RPC and the no-argument,
  fixed-search-path `SECURITY DEFINER` publish-readiness assertion. Their
  execute ACL is `authenticated` only; `anon`, `service_role`, and `PUBLIC`
  cannot execute either RPC. It made no table, RLS, table-grant, trigger,
  policy, or business-data change.
- The post-apply transactional SQL runtime scenarios passed with zero fixture
  residue. Independent readback remains exactly one active/effective policy
  and zero acceptance rows; the pre-existing `community-policy-v1` row was
  not changed.
- `20260908141133_harden_public_default_table_privileges` was subsequently
  applied by the Supabase CLI after a transactional pre-apply probe passed.
  It removes only the four dangerous future-relation default privileges
  (`TRUNCATE`, `REFERENCES`, `TRIGGER`, `MAINTAIN`) for `anon` and
  `authenticated` on `postgres`-owned relations created in `public`.
  `supabase/tests/default_privileges_hardening_test.sql` then passed: client/
  PUBLIC dangerous global and `public` defaults are zero, the four
  `service_role` defaults remain, its synthetic relation left no residue, and
  the migration-history row exists. This changed no business data, RLS,
  existing table ACL, table, or role.
- `20260908175000_community_policy_storage_upload_guard` adds a restrictive
  authenticated INSERT policy to the Community Storage bucket so a modified
  client cannot upload before policy acceptance or while suspended. The
  existing owner/path policy remains unchanged.
- `20260908180500_community_policy_version_immutability` makes policy identity
  rows append-only: it rejects identity edits, deletes and reactivation while
  permitting active-to-inactive supersession by a new version.
- `20260908181500_community_policy_ledger_postconditions` reasserts the exact
  canonical v1 identity and single-active invariant and rejects privileged
  `TRUNCATE` through a private fixed-search-path trigger.
- Those three later migrations perform no policy/acceptance DML and do not
  change Community table RLS or grants. Their final live fixture passed in
  `BEGIN`/`ROLLBACK` with zero residue across all 11 tracked fixture categories.
  Each version has exactly one live migration-history row.
- `20260908235044_harden_legacy_community_writes_and_reports` subsequently
  removed broad authenticated `INSERT`/`UPDATE`/`DELETE` table privileges from
  the three legacy Community tables and retained only the reviewed
  column-scoped post, message, and report writes. It widened the existing post
  moderation guard trigger to every update and added bounded report guard and
  index enforcement. It did not recreate Social v2, alter RLS policies, or
  change any business row. Post-apply readback remained 4 posts, 5 messages,
  0 reports, 1 policy row, 1 active policy, and 0 acceptance rows.
- Read-only Edge Function source reconciliation found no semantic drift across
  the 19 deployed files in `app-attest` v12, `play-integrity` v23,
  `verify-store-purchase` v27, `community-push-dispatch` v12, and
  `account-data-deletion` v18. The AI Coach safety delta was then deployed as
  `ai-coach` v51 and downloaded again: all five bundle files have exact
  normalized local/live parity. v51 sends explicit Gemini safety settings,
  fails closed on prompt/candidate safety metadata, refunds the reservation,
  and returns the stable `422 ai_safety_blocked` envelope. The client displays
  provider-neutral copy in all 25 locales without speech, actions, or
  same-request retry. An unauthenticated live probe returned the expected 401;
  signed-device and authenticated answer canaries are still required.
- The live advisor's leaked-password-protection warning is currently blocked
  by the `BIL Health` Free plan: the read-only console reports that the control
  requires Pro or above. This is an owner plan/configuration decision, not a
  database migration defect; no auth setting was changed.
- The new advisor finding
  `authenticated_security_definer_function_executable` for
  `bil_assert_community_publish_ready()` is intentional: its no-argument,
  JWT-bound, fixed-search-path, self-only assertion checks membership and the
  private exact-policy receipt guard. Do not widen or revoke this reviewed
  client boundary merely to clear the linter warning.
- Final focused Community policy validation is **36 PASS / 0 FAIL / 0 SKIP**.
  The official portable runner executed 875/875 scheduled files with **4,071
  PASS / 0 FAIL / 1 opt-in live-stream SKIP**; root `flutter analyze --no-pub`
  reports no issues.
- Android debug APK build passed using only a process-scoped Java Unix-domain
  socket temp-directory override. The 271,497,350-byte artifact SHA-256 is
  `4E32D15E71709F91C8DFAC90E1A69E68D3DE88F1957F0ACAF443BE0BC82A2250`;
  it was rebuilt after the final application-source edit and is not a
  Play-signed release artifact.
- MCP `apply_migration` was not used because it cannot preserve a caller's
  local timestamp/version and is unsuitable for history reconciliation.
- The handoff records an earlier pre-activation `0` total / `0` active policy
  snapshot. The mandatory first current read-only inspection in this
  continuation found the canonical v1 row and activation migration already
  live, so it was not replayed or replaced. Acceptances remained `0`.
- The source tree and history did not contain a previously published canonical
  community-policy row that could be restored. A production-ready English and
  Arabic policy was therefore authored and published at the real BIL route
  `https://www.bilhealth.com/community-guidelines`; no placeholder URL was
  used.
- Cloudflare Worker production version:
  `f8023569-4367-4a8a-9f4a-3ce8efbf77e0`. HTTP and real-browser checks passed
  for English and Arabic, including version/effective date and every required
  policy section. These checks cover the public web document only; they are not
  evidence of the in-app acceptance or publishing flow on iOS or Android.
- Live Supabase migration
  `20260908032057_community_policy_v1_activation` inserted exactly one active
  `community-policy-v1` row referencing the real route. Acceptance remains a
  user-JWT action; no acceptance was inserted for any user.
- The policy migration adds a one-active-policy invariant, exact-version and
  effective-time acceptance checks, and publish/message/comment guards without
  recreating Social v2 tables or broadening RLS/GRANTs.
- The rollback SQL test found a real bilateral block defect: a sender could not
  see a recipient-owned block through RLS when the message guard queried as the
  sender. The failed test transaction rolled back with zero fixture residue.
- Forward migration
  `20260908032453_community_message_block_visibility_hardening` moved the
  bilateral check behind a private, fixed-search-path security-definer guard;
  `20260908032558_community_block_pair_uuid_lock_fix` corrected UUID pair-lock
  ordering without editing the applied migration.
- The final SQL `BEGIN`/`ROLLBACK` test passed for no policy, unaccepted policy,
  accepted policy, new version, suspension, bilateral block and direct publish
  without acceptance. Post-test production readback remained one active policy,
  zero acceptances and zero fixture users/posts/messages/entitlements.
- RLS remains enabled on both policy tables. Dangerous
  `anon`/`authenticated` table privileges (`TRUNCATE`, `TRIGGER`, `REFERENCES`)
  remain at zero. Existing Social v2 objects, moderator separation and prior
  privilege hardening were not rebuilt or reversed.

Further live/local reconciliation is recorded in `SERVER_RECONCILIATION.md`.

## Community Stage1 integration

- Package:
  `C:\Users\HP 1040 G8\Downloads\BIL_Community_Stage1.zip`
- SHA-256:
  `7F747A64E52A01F0B209CED174AACA2674C6614072118552B7B69E16B1722A36`
- All 29 target preimages and nine prerequisites matched the preserved tree.
- The two missing braces were repaired in the temporary candidate, not by
  disabling the lint, and the candidate was applied atomically.
- Targeted analysis of the 18 changed library files passed.
- The Community publish regression exposed an async `setState` callback; the
  underlying code was corrected and the exact regression run then passed 4/4.
- Content-policy and shared-chat source integration passed the final portable
  suite. Source success is still not signed-device proof.

## Store state

- The current retained App Store Connect tab is at the Apple Account sign-in
  boundary with `authResult=FAILED`. Authentication was not attempted, so the
  current Apple build/version/review/subscription state and exact red validation
  text are unverified. Earlier readbacks are historical only and were not used
  to guess or mutate metadata.
- Current Google Play read-only inspection shows Production inactive while its
  production-access application is under review. Build 8 (`1.0.0`) remains on
  Closed testing - Alpha for 177 testers with 0.00% install base. Managed
  publishing is on and one `en-GB` full-description change is ready to publish;
  it was deliberately not published. No artifact/track/release mutation
  occurred.
- Exact signed Android build 9 and iOS build 10 artifacts remain **NOT
  VERIFIED**. Store metadata publication does not close artifact or device
  release gates.

Detailed evidence is in
`docs/release/BIL_STORE_COMMUNITY_POLICY_LINK_UPDATE_2026-09-08.md` and current
platform requirements are in
`docs/release/BIL_PLATFORM_REQUIREMENTS_2026-09-08.md`.
