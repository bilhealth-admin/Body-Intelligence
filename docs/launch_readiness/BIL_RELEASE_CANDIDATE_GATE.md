# BIL V1 Release Candidate Gate

## Current iOS 26 / Android 21 status

- `CURRENT_IOS26_ANDROID21_CANDIDATE_ACCEPTED: TRUE`
- Version metadata: iOS `1.0.0+26`; Android `1.0.0+21`.
- The iOS workflow accepts build number `26` and the Android workflow accepts
  build number `21`; older store builds are historical evidence only.
- The former `phase-3-product-excellence` / `BIL-V1-LAUNCH-005` record was a
  historical parent baseline. It is not the accepted source identity for the
  current heavily modified release worktree.
- This marker describes the complete signed release package, not permission to
  run the workflow that creates it. Source-only freeze acceptance is recorded
  separately in `docs/release/BIL_IOS26_ANDROID21_FROZEN_SOURCE_MANIFEST_2026-09-20.md`.
  It requires a reviewed clean commit and immutable source hashes; final package
  acceptance additionally requires actual signed-artifact verification.
- The owner's latest instruction on 2026-09-06 authorizes signed builds and
  publication after source/release checks, without simulator prerequisites.

## Repository release-candidate gate

## Local validation evidence (2026-09-20)

- Validated candidate HEAD: `6b4b9ee55e85ce64f87cce33543601b1ddcbd1f1`.
- Full Master Run: `4608` unique tests, `4607` passed, `0` failed, `1` skipped.
- Flutter: `4455` passed, `0` failed, `1` skipped.
- Portable release suite: `887/887` scheduled files passed.
- Deno AI Coach: `20/20` passed; Deno Store: `132/132` passed; Deno type-check: pass.
- Production release configuration validator: pass for Android build `21` and
  iOS build `26` using the approved application identifier and frozen manifest.
- Signing credentials, store-console access, device validation, and Mobile
  Integrity production binding remain external gates and are not claimed here.

A repository release candidate is accepted only when all of these checks pass
against the same immutable source commit in one package run:

1. The complete Dart source and test tree is already formatted.
2. Full Flutter static analysis reports no issues.
3. The complete Flutter test suite inventory is accounted for: every portable
   release test selected by `tool/release/run_portable_release_tests.py` passes.
   Its exact platform-raster/local-evidence exclusions are reported separately,
   alongside the ordinary host visual comparisons; exclusions are not passes.
4. Android release App Bundle generation succeeds.
5. Architecture, Dashboard, Truth, Premium UI, Android, Apple, and store-privacy
   closure or readiness contracts remain present.
6. The generated AAB path, byte size, and SHA-256 are written into package
   evidence.
7. The signed iOS workflow rejects every build number except `26`, and the
   signed Android workflow rejects every build number except `21`.
8. Optional simulator/emulator checks not run under the owner's waiver report
   `NOT_RUN_OWNER_WAIVED`, never PASS. Source tests and final artifact identity,
   SDK compatibility, signing, entitlements, and store requirements remain
   mandatory. Host rendering does not prove native billing, authentication,
   health-data, permission, media-decoder, or notification behaviour.

The verification run must not rewrite accepted source or golden files. Any
format, analyze, test, or build failure requires a focused revision rather than
waiving the gate.

## Artifact boundary

`build/app/outputs/bundle/release/app-release.aab` is repository build evidence.
Without the Product Owner's private upload key and verified Play App Signing
configuration it is not an authorized upload artifact. A later signed artifact
must be generated from an approved commit and re-hashed before Play submission.

## External gates

Apple archive and device validation, private signing assets, store-console
records, legal approvals, public privacy-policy hosting, declarations,
screenshots, review credentials, TestFlight or testing tracks, store review,
and rollout remain external. Passing this gate does not claim public launch.
Until the clean candidate commit and validated signed artifacts exist, the complete
release-package status remains `FALSE`. Simulator/emulator runtime reports are
not a prerequisite under the owner's latest explicit waiver; unperformed native
coverage remains unproved and must be reported honestly.
