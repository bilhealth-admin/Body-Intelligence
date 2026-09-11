# BIL iOS 1.0.0 build 15 — release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 15`

## Release identity and scope

This tester-feedback candidate follows `a05140609ee145e5002eaa9c960bb3ff4f75ede0`.
It contains the reviewed display-name persistence, Dashboard refresh, AI Coach
scrolling, More heading, Free Community/friendship, and sleep-reminder fixes.
It also locks the app to portrait on phone and adds a standalone Food Log entry
surface reached from Quick Add. The existing breakfast, lunch, dinner, and snack
Daily Log pages and their routes remain unchanged.
The owner's food-search/navigation decisions, real health-data behavior,
purchase entitlements, and non-accumulating token resets remain preserved.
AdMob remains deferred; the shared version stays `1.0.0+8`;
the signed workflow overrides it with `--build-number 15` / `CFBundleVersion 15`.

The binding is not self-referential: after the commit is pushed,
`BIL_IOS_V15_AUDITED_SOURCE_SHA` must equal that exact commit and
`BIL_IOS_V15_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. Source, manifest, and expected build number are independently checked.
Older source bindings, manifests, and release artifacts remain unchanged.

## Verification boundaries

The complete selected host-only suite passed: 968 discovered files, 936
scheduled/executed files, zero failures, with the documented native/mixed-filter
exclusions. The full analyzer reported no issues. The portable run ended with
`PORTABLE_RELEASE_EXECUTED_TEST_FILES=936` and `All tests passed!`.
See `../qa/TESTER_FIXES_RELEASE_GATE_2026-09-10.md` for final verification.
Signed CI retains Xcode/iOS SDK 26+, configuration, analyzer, code-only portable
tests, signing, IPA/entitlement, and App Store Connect validation gates.
Native runtime checks are explicitly not requested; their exclusion is not a
pass. A requested TestFlight upload follows successful signed-artifact checks;
this is not App Review submission or public release.

This manifest does not claim an IPA exists, a TestFlight upload has completed,
or any HealthKit, StoreKit, device, or visual flow passed. This mobile workflow
does not deploy server migrations.
