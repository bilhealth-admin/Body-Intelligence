# BIL +8 release gate sequence recheck — 2026-09-06

## Latest owner instruction — supersedes simulator prerequisites

The owner subsequently instructed: «بعد انتهاء الفحوصات اصدر نسخ موثقه
وموقعه وانشرها لا داعي للمحاكيات». Signed `+8` builds, uploads, and store
submission/publication are therefore authorized after the source and release
checks pass. Simulators/emulators are no longer a prerequisite. Optional native
runtime checks not executed under this instruction must be reported as
`NOT_RUN_OWNER_WAIVED`, never as passed. Source tests, configuration validation,
frozen-source verification, signing, final artifact identity, and platform/store
requirements remain mandatory. Build `+7` remains excluded. Apple's manual
public-release setting is retained. The original investigation below is
historical context, not a renewed request for simulator testing or permission.

Status: **read-only gate audit plus one scoped iOS Keychain correction**. This
record does not claim that a signed build, TestFlight/Play install, physical
device test, store submission, or upload occurred.

## Decision summary

The release sequence must not require a signed `+8` binary before the workflow
that creates that binary can run. The correct sequence has three distinct
evidence layers:

1. **Pre-build source and simulator/emulator QA** on a frozen `1.0.0+8`
   commit. This proves portable contracts, ordinary account flows, navigation,
   responsive layout, deep-link routing, and the requested multi-role flows to
   the extent supported by unsigned simulators/emulators.
2. **Signed GitHub builds** from that exact accepted commit and manifest. The
   signed workflows create the IPA/AAB; a pre-existing signed `+8` is not an
   input to those workflows.
3. **Post-build signed/store canaries** using TestFlight and Play internal or
   closed distribution. This is where store receipts, provider returns,
   production entitlements, integrity assertions, and hardware-only features
   can be evidenced.

The current source/configuration Facebook gate and explicit user approval must
close before step 2. Instagram login is not a substitute for that gate and is
not silently promoted into the build scope.

## User authority and the App Attest boundary

The literal U185 phrase is:

> والايفون يجب ان يطلبا اي تحقق داخلي

See
`docs/release/BIL_ACTUAL_USER_MESSAGE_LEDGER_2026-09-06.md#full-u185`.
It is ambiguous and does **not** name App Attest, DeviceCheck, a production
entitlement, or a fail-closed policy. It therefore cannot by itself authorize
turning App Attest into an App Store acceptance requirement. App Attest remains
a separate security initiative whose rollout and user-impact policy require an
explicit risk decision.

Apple's current guidance confirms that distinction:

- [Establishing your app's integrity](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
  says to check `isSupported` because not all devices support App Attest and to
  gracefully bypass the service when unavailable.
- [Secure your apps with App Attest (WWDC26)](https://developer.apple.com/videos/play/wwdc2026/201/)
  says to store generated key identifiers in Keychain, retry later with
  exponential backoff rather than hard-coded retry logic, collect attestation
  outside user flows, and degrade App-Attest-dependent functionality rather
  than directly blocking a user without a comprehensive risk assessment.
- [Preparing to use App Attest](https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service)
  calls for staged onboarding rather than an uncontrolled all-user cutover.

Accordingly, App Attest proof is a gate to enabling App-Attest-dependent
enforcement. It is not inferred as a universal build/submission gate from U185.
This audit does not disable or weaken the existing implementation.

## Current source findings

### App Attest implementation

- `lib/app/environment/release_configuration_validator.dart:165-181` currently
  requires mobile integrity and a backend release identifier for every
  production configuration.
- `lib/app/security/bil_mobile_integrity_service.dart:50-69` fails a protected
  action when required integrity is unavailable.
- `lib/app/security/bil_app_attest_service.dart:44-61` checks native support,
  but `:91-108` can perform first registration in the submitted user flow and
  `:260-277` contains a fixed 250 ms retry.
- `ios/Runner/BILAppAttestBridge.swift` now stores each account's opaque key ID
  as a non-synchronizing generic-password Keychain item with
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. It migrates the old
  app-owned UserDefaults map one account at a time and removes a legacy entry
  only after a successful Keychain write. The bridge returns bounded error
  codes without a key ID, account ID, credential, or error message.
- `ios/RunnerTests/RunnerTests.swift` contains native source tests for account
  isolation, one-at-a-time migration, failed-write preservation, and
  matching-key deletion. These tests were added but were **not executed** by
  this Windows audit.
- `test/apple_preparation/apple_preparation_contract_test.dart` now asserts the
  Keychain/non-sync/device-only source contract and preserves the privacy
  manifest assertion needed by the legacy migration. It was not executed in
  this scoped audit.

The validator, signed workflows, entitlement policy, and fail-closed runtime
policy were deliberately not changed here; they need the independent product
risk decision described above.

### Build and QA workflow order

- Android already performs exact-build/configuration/tests/emulator checks
  before creating the signed AAB:
  `.github/workflows/bil_android_release_candidate.yml:28-41`, `:76-132`,
  `:137-158`.
- iOS already performs exact-build/signing-input/profile/configuration and a
  simulator crypto check before creating the signed IPA:
  `.github/workflows/bil_ios_signed_release.yml:55-100`, `:131-190`,
  `:193-249`, `:330-352`.
- The local dual-simulator workflow builds an **unsigned debug** simulator app
  from frozen `+8` source and explicitly records the signed-device boundary:
  `.github/workflows/bil_ios_plus8_dual_simulator_qa.yml:30-67`, `:183-220`,
  `:258-413`, `:425-456`.
- The contradictory text is
  `docs/release/BIL_PREPRODUCTION_CONTRACT_AUDIT_2026-09-05.md:122-125` and
  R-090 in
  `docs/release/BIL_LITERAL_USER_REQUEST_TRACEABILITY_2026-09-06.md`: both can
  be read as requiring signed `+8` before the user's pre-build simulator
  matrix. U246 instead says to build after the tests; see the U240-U247 rows in
  the literal ledger.

## Effective three-stage gate

### Stage A — before signed build

Required and actionable now:

1. Close the Facebook login source/configuration gate and obtain the user's
   explicit build approval.
2. Select the intentional candidate changes into a clean side worktree; do not
   delete or reset the shared dirty worktree.
3. Freeze one exact `1.0.0+8` commit, regenerate the source manifest, resolve
   every classified review row, mark the candidate accepted, and bind its SHA
   and manifest digest.
4. Run analysis, portable contracts, deep-link/lifecycle contracts, and the
   requested role-based ordinary-flow QA on unsigned iOS simulators and Android
   emulators. Record platform/identity/size/orientation for every result.
5. Report unsupported simulator functions as boundaries, not passes.

The user's iPhone-priority, iPad, Apple reviewer, Google reviewer, owner, and QA
matrix is a pre-build regression request. Absence of a signed `+8` does not
block this stage; lack of a remote iOS runner/workflow execution still does.

### Stage B — signed GitHub build

After Stage A passes, run the signed iOS and Android workflows at the accepted
commit. Their inputs are signing/store/integrity configuration and the frozen
source identity. Their outputs are the signed IPA/AAB. Verify signature,
entitlements/certificate, package identity, exact `+8`, and artifact digest.

### Stage C — signed/store proof

Install only the Stage B artifacts through TestFlight and Play internal/closed
distribution. Prove the provider callback, Sign in with Apple lifecycle,
StoreKit/Play Billing purchase and restore, signed no-paywall/no-ad reviewer
session, App Attest/Play Integrity only if that independent feature is retained
and enabled, push, HealthKit/Health Connect, camera, BLE, and other
hardware/store-only behavior. Only this stage can support signed-runtime or
store-runtime claims.

## Current evidence snapshot

Observed on 2026-09-06; it must be refreshed after concurrent work stabilizes:

- Branch `release/store-rc-20260831`, HEAD
  `21f16767fad82d625ced9b6da2146b66b4b27953`.
- Working source declares `1.0.0+8`; committed HEAD declares `1.0.0+5`.
- The staging manifest says complete `YES`, accepted `NO`, unresolved `172`,
  version `1.0.0`, build `8` at
  `docs/release/BIL_PLUS8_STAGING_MANIFEST_2026-09-05.md:5-13`.
- The current hygiene classifier saw 2,062 dirty paths before this document:
  768 classified include, 1,159 classified exclude, and 135 unclassified. A
  defensible current split is 792 candidate changes and 1,270 preserve-only
  paths; adding this document makes 793 candidate paths if nothing else changes.
  The 135 omissions are not all release blockers: 24 are intentional candidate
  metadata/logo-cleanup paths and 111 are local probes, media authoring, or a
  generated macOS file to preserve outside the release tree. Recalculate and
  review every path before freeze.
- Only Android `emulator-5554` was connected. Its installed BIL package reports
  version `1.0.0`, versionCode `8`, target SDK 36, `DEBUGGABLE`, and no installer
  package. It is emulator regression evidence only, not signed/store or Play
  Integrity evidence.
- No local exact `+8` IPA/AAB was found. The local AAB files are older seed/+4
  artifacts.
- The latest publicly visible successful signed GitHub runs were iOS
  `33601954427` and Android `33605469013` at the old HEAD above. Because that
  commit declares `+5` and the public run metadata does not prove a `+8` input,
  they are not accepted as `+8` artifacts.
- The local dual-simulator workflow is not present on GitHub (workflow API
  returned 404), so no remote iPhone/iPad run is claimed.
- `ios/Runner.xcodeproj/project.pbxproj:533,714,738` uses team
  `43F9Y5Y96K`. The live AASA file at
  `https://www.bilhealth.com/.well-known/apple-app-site-association` currently
  lists `43F9Y5Y96K.com.bilhealth.bodyintelligencelog` for the authentication
  callback and password-reset paths.

## Gate disposition

| Gate | Correct current disposition | Reason |
|---|---|---|
| R-062 | **OPEN — ambiguous authority** | U185 does not name App Attest. Keep the security work independent; do not claim it as a literal user/store requirement. |
| R-074 | **OPEN — actionable** | A dirty shared worktree is not itself the release tree. Build an allowlisted clean side worktree/commit and accept its manifest. |
| R-075 | **OPEN after Stage A** | The workflows create the signed artifacts; they do not require a pre-existing signed `+8`. Local workflow changes must first exist in the frozen commit. |
| R-079 | **ACTIVE** | Only exact `1.0.0+8` may advance. No current artifact proves that identity. |
| R-090 | **OPEN for Stage A; BLOCKED for Stage C** | Ordinary simulator/emulator role QA belongs before build. Signed/store/hardware claims remain blocked until signed artifacts and appropriate distribution exist. |

No status in this document overrides the Facebook-before-build condition or
the explicit user-approval condition.
