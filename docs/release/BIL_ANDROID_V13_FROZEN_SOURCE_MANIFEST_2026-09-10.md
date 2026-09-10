# BIL Android 1.0.0 build 13 — release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 13`

## Release identity and scope

This tester-feedback candidate follows `a05140609ee145e5002eaa9c960bb3ff4f75ede0`.
It contains the reviewed display-name persistence, Dashboard refresh, AI Coach
scrolling, More heading, Free Community/friendship, and sleep-reminder fixes.
The owner's food-search/navigation decisions, real health-data behavior,
purchase entitlements, and non-accumulating token resets remain preserved.
AdMob and pricing changes remain deferred. The shared version stays `1.0.0+8`;
the signed workflow overrides it with `--build-number 13` / `versionCode 13`.

The binding is not self-referential: after the commit is pushed,
`BIL_ANDROID_V13_AUDITED_SOURCE_SHA` must equal that exact commit and
`BIL_ANDROID_V13_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. Source, manifest, and expected build number are independently checked.
Older source bindings, manifests, and release artifacts remain unchanged.

## Verification boundaries

The complete selected host-only suite passed: 26 groups, 950 of 950 test files
covered, zero failed or stale files. The full analyzer reported no issues.
See `../qa/TESTER_FIXES_RELEASE_GATE_2026-09-10.md` for final verification.
Signed CI retains configuration, analyzer, code-only portable tests, signing,
manifest, and 16 KB/ELF packaging gates. Native runtime checks are explicitly
not requested; their exclusion is not a pass.

This manifest does not claim an AAB exists, a Google Play upload occurred, or
any device/visual test passed. The workflow builds the signed Android artifact
without publishing it to Google Play or deploying server migrations.
