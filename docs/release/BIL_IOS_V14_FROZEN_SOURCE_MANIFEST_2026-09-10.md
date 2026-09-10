# BIL iOS 1.0.0 build 14 — release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 14`

## Release identity and scope

This tester-feedback candidate follows `a05140609ee145e5002eaa9c960bb3ff4f75ede0`.
It contains the reviewed display-name persistence, Dashboard refresh, AI Coach
scrolling, More heading, Free Community/friendship, and sleep-reminder fixes.
The owner's food-search/navigation decisions, real health-data behavior,
purchase entitlements, and non-accumulating token resets remain preserved.
AdMob and pricing changes remain deferred. The shared version stays `1.0.0+8`;
the signed workflow overrides it with `--build-number 14` / `CFBundleVersion 14`.

The binding is not self-referential: after the commit is pushed,
`BIL_IOS_V14_AUDITED_SOURCE_SHA` must equal that exact commit and
`BIL_IOS_V14_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. Source, manifest, and expected build number are independently checked.
Older source bindings, manifests, and release artifacts remain unchanged.

## Verification boundaries

The complete selected host-only suite passed: 26 groups, 950 of 950 test files
covered, zero failed or stale files. The full analyzer reported no issues.
See `../qa/TESTER_FIXES_RELEASE_GATE_2026-09-10.md` for final verification.
Signed CI retains Xcode/iOS SDK 26+, configuration, analyzer, code-only portable
tests, signing, IPA/entitlement, and App Store Connect validation gates.
Native runtime checks are explicitly not requested; their exclusion is not a
pass. A requested TestFlight upload follows successful signed-artifact checks;
this is not App Review submission or public release.

This manifest does not claim an IPA exists, a TestFlight upload has completed,
or any HealthKit, StoreKit, device, or visual flow passed. This mobile workflow
does not deploy server migrations.
