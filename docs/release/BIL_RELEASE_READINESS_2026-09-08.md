# BIL release readiness — 2026-09-08

Status: **NOT READY TO SUBMIT OR RELEASE**

Branch: `codex/bil-community-policy-recovery-20260908`
Baseline commit: `21f16767fad82d625ced9b6da2146b66b4b27953`

This record separates verified source/backend results from signed-device and
store evidence. A green host test is never promoted to a production-release
claim.

## Gate A — source and portable tests

- `flutter analyze --no-pub`: **PASS**, no issues.
- Final focused Community policy batch: **36 PASS / 0 FAIL / 0 SKIP**.
- Official portable runner: 904 files discovered, 29 fixed exclusions and
  875/875 executed; **4,071 PASS / 0 FAIL / 1 SKIP**, exit 0, 878.584 seconds.
- The only skip is the opt-in real public workout-stream probe controlled by
  `BIL_LIVE_WORKOUT_STREAM_CHECK`.
- No blanket golden update, tolerance increase or added skip was used.

The full details and boundaries are in
`docs/recovery/FULL_SUITE_REPORT_2026-09-08.md`.

## Gate B — Community policy and production backend

- Live project: `tgmanzhqulksykhslrzb`.
- Current state: exactly one active/effective `community-policy-v1`, locale
  `en`, URL `https://www.bilhealth.com/community-guidelines`, effective
  `2026-09-08T00:00:00Z`; production acceptances remain **0**.
- The mandatory first read-only audit in this continuation found that row and
  activation migration already present. It was not reinserted or replaced.
- All **124/124** migration versions are aligned local/live through
  `20260908235044_harden_legacy_community_writes_and_reports`. The five initially absent
  historical sources, including exact Social v2 deployment SQL, were recovered
  locally without rebuilding production objects.
- Controlled forward migrations added the authenticated self-status/readiness
  RPC boundary, hardened future default privileges, gated Community Storage
  uploads, made policy versions append-only and protected the ledger from
  privileged `TRUNCATE`:
  - `20260908132433_community_policy_client_status_rpc`
  - `20260908141133_harden_public_default_table_privileges`
  - `20260908175000_community_policy_storage_upload_guard`
  - `20260908180500_community_policy_version_immutability`
  - `20260908181500_community_policy_ledger_postconditions`
  - `20260908235044_harden_legacy_community_writes_and_reports`
- The final live SQL fixture passed inside `BEGIN`/`ROLLBACK` with zero residue.
- Social v2 remains five RLS-enabled tables and 17 functions. Dangerous current
  client grants remain zero; dangerous future client defaults remain zero;
  the four intended `service_role` defaults remain.
- No Community policy row, user acceptance, entitlement, moderator membership,
  purchase, receipt, or Social v2 business row was changed by this continuation.
  Durable database changes were reviewed schema/function/policy/trigger,
  column-ACL, index, default-ACL definitions and their migration-history rows
  only.

## Gate C — application behavior

The repository now uses the server-clock policy status RPC, fails closed when a
policy is unavailable or not accepted, requires a fresh receipt for a new
version, keeps decline explicit, and maps suspension and upload-policy errors
to clear UI states. The Arabic safety page opens the real canonical route with
`?lang=ar`; the English route remains unchanged. No acceptance is ever created
until the signed-in user confirms it. `ai-coach` v51 is ACTIVE with exact
normalized parity to the five local bundle files; its explicit Gemini safety
boundary returns a refunded `422 ai_safety_blocked`, and the 25-locale client
state exposes no provider answer, action, automatic speech, or same-request
retry. Authenticated signed-device canaries remain a release gate.

Host widget/unit/contract tests cover Android and iOS target-platform overrides,
but real-device policy open/accept/decline/suspend/publish/upload journeys remain
required.

## Gate D — Android artifact and Google Play

- Debug APK build: **PASS**, 271,497,350 bytes, SHA-256
  `4E32D15E71709F91C8DFAC90E1A69E68D3DE88F1957F0ACAF443BE0BC82A2250`.
  It was rebuilt after the final application-source edit.
- This is not a Play-signed AAB or 16 KB device result.
- Current read-only Play Console evidence: production is inactive; the
  production-access application is under review; build 8 is on Closed testing
  Alpha for 177 testers with 0.00% install base; managed publishing is on.
- One `en-GB` description change is ready to publish and was deliberately not
  published. No track, artifact or release mutation was made.

**RELEASE BLOCKER:** produce an exact-source Play-signed AAB and complete API
36, 16 KB, Billing, Play Integrity, Health Connect, App Links, accessibility,
large-screen/foldable and pre-launch checks.

## Gate E — iOS artifact and App Store Connect

The Windows host cannot produce an Xcode 26 signed archive. The current retained
App Store Connect session showed the Apple sign-in boundary with
`authResult=FAILED`; no login was attempted. Therefore current build, review,
subscription and exact `MISSING_METADATA` state are **unverified**. Historical
state must not be used to guess or mutate metadata.

**RELEASE BLOCKER:** authenticated readback, an exact-source Xcode 26/TestFlight
build and StoreKit/ASSN, App Attest, HealthKit, Sign in with Apple, universal
links, push, account deletion, accessibility, iPad/Stage Manager and lifecycle
tests.

## Gate F — remaining evidence

- Review the intentionally excluded English/Arabic visual/golden evidence on
  required form factors; do not regenerate blindly.
- Resolve the three pre-existing Deno failures in untracked App Attest fixture
  paths; no App Attest source was changed here.
- Run authenticated live canaries for custom-auth Edge Functions and signed
  mobile integrity paths.
- Decide whether to upgrade Supabase for leaked-password protection; the
  read-only console showed the control is unavailable on the current Free plan.

## Decision

The Community policy repair is implemented and verified at source and live
database level. The overall app remains **NOT READY TO SUBMIT OR RELEASE** until
Gates D–F are backed by signed-device, authenticated-store and visual evidence.

Related evidence: [full suite report](../recovery/FULL_SUITE_REPORT_2026-09-08.md),
[Community policy recovery](../recovery/COMMUNITY_POLICY_RECOVERY_2026-09-08.md),
[server reconciliation](../recovery/SERVER_RECONCILIATION.md), and
[signed-device matrix](BIL_DEVICE_TEST_MATRIX_2026-09-08.md).
