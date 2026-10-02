# BIL Android 1.0.0 build 30 — warning-clean final frozen source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 30`

## Frozen application source

Production baseline shared by iOS 32 / Android 29:
`9f439cae97d72b784880a1b1ac4ef1d33ede30c1`.

Last exhaustive application/test certification source:
`2184f772468fb36c6ab633c8b79591e3472ebb64`.

Warning-clean release source:
`7ab4da5f991f9bbfab986c333af66af553133066`.

The warning-clean source preserves the certified application/runtime behavior and
adds only release/build hygiene around the already-reviewed plugin graph:
- iOS removes only Flutter-generated CocoaPods scaffolding after the Windows-only
  simple_barcode_scanner native plugin is excluded from the iOS graph.
- Android keeps mobile_scanner 7.4.0 runtime bytes unchanged and removes direct
  legacy KGP application from hosted plugin Gradle scripts while Flutter 3.44's
  compatibility bridge remains authoritative.
- The signed iOS/Android release workflows apply those same fail-closed cleanup
  steps before the real signed builds.

The release freeze commit containing this manifest is documentation-only and must
not change application, native runtime, dependency, or signed-build logic from
the warning-clean release source above.

## Certification and cleanup evidence

BIL Final Release Certification #89:
https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/36966056579

Result: **SUCCESS** on `2184f772468fb36c6ab633c8b79591e3472ebb64`.

Its complete full-test pass contains **5,698 successful tests across 1,046 test
files**, with 0 failures, 0 errors, and 6 documented skips. The certification
runs the full suite twice and also includes static/security/dependency,
visual/cloud, live backend, fault/stress, and Apple + Google store read-only
gates.

BIL RC mobile test builds #55:
https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/36966056600

Result: **SUCCESS** on `2184f772468fb36c6ab633c8b79591e3472ebb64`.

- Android APK/AAB + emulator evidence: **SUCCESS**
- iOS simulator + unsigned production-shaped device evidence: **SUCCESS**
- iOS native integration tests: **SUCCESS**
- iPhone/iPad lifecycle and deep-link evidence: **SUCCESS**

Warning-clean iOS evidence:
https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/36976851791

The iOS SwiftPM-only job completed **SUCCESS**. It built both the simulator app
and the unsigned production-shaped device app after fail-closed removal of only
the generated CocoaPods scaffolding; the workflow rejects the former CocoaPods
warning and any `Running pod install` marker.

Warning-clean Android evidence:
https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/36978238064

The Android cleanup job completed **SUCCESS**. It resolved the unchanged locked
dependency graph, applied the fail-closed Gradle cleanup, passed focused release
contracts, built both the debug APK and production-shaped release AAB, rejected
the legacy KGP warning, and confirmed the lockfile did not move.

Changes after those cleanup evidence commits are restricted to cleanup/release
workflow wiring; no BIL application runtime file, iOS Runner source, Android app
source, or barcode runtime implementation changed.

## Included release corrections

This source retains all accepted changes after iOS 32 / Android 29, including
local-first dashboard continuity when offline, verified paid-entitlement
continuity through transient network failures, prevention of false temporary
Free locks, Community/message unread-count corrections, onboarding/profile
persistence fixes, RTL/navigation polish, connected-health daily history,
explicit user-initiated Apple Health permission timing, and the existing iOS
barcode native-graph isolation while preserving iPhone barcode scanning.

## Accepted non-blocking limitation

Supabase Leaked Password Protection remains owner-deferred because it requires
the paid plan. It is not an unresolved build defect.


## Immutable release bindings

`BIL_ANDROID_V30_AUDITED_SOURCE_SHA` and
`BIL_IOS_V33_AUDITED_SOURCE_SHA` must both name the exact same documentation-only
release freeze commit containing this manifest.

`BIL_ANDROID_V30_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256 in that frozen commit.

A later dispatch-control commit may update only the signed release workflow
binding to that already-frozen source. The signed Android build must check out
the frozen source, not the dispatch-control commit.

Signed-binary and physical/store-device acceptance remain the next release gates.
