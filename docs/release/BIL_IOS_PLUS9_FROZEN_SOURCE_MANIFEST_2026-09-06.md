# BIL iOS 1.0.0 (9) startup hotfix — source acceptance manifest

## Machine-readable release markers

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 9`

## Scope and verified failure

The exact uploaded iOS build 8 from source
`6d25a6ad3ca7eb3242b723ced6ad7d7296f673eb` crashes on the owner's iPhone.
Apple's crash log records `EXC_CRASH (SIGABRT)` with
`GADApplicationVerifyPublisherInitializedCorrectly` in the exception backtrace,
approximately 57 ms after launch at `2026-09-06T13:03:43Z`.

Google Mobile Ads and User Messaging Platform were still linked/embedded while
the owner-deferred build removed `GADApplicationIdentifier`. Disabling Dart ads
calls and removing the plist key did not prevent native SDK startup validation.
The previous plist-absence gate is insufficient for iOS deferred safety.

Redacted source evidence SHA-256:
`c84e5afb14d32f814e07a518f217f163dbba05bf96fff2c884b6749c699072f0`.
Google documents the same missing-ID native initialization failure in its
[iOS SDK guide](https://developers.google.com/ad-manager/mobile-ads-sdk/ios/adx-direct).

This hotfix excludes the native iOS Google ads plugin/SDK from build-local Flutter
plugin discovery before native compilation. The original package cache, source
pubspec, dependency lock, Android integration, and future enabled-advertising
implementation must remain intact. No fake ad ID, WebView integration bypass,
post-signing framework stripping, or global plugin removal is permitted.

The signed iOS workflow requires build 9 and this manifest's exact digest and
source SHA, bound through `BIL_IOS_PLUS9_AUDITED_SOURCE_SHA` and
`BIL_IOS_PLUS9_STAGING_MANIFEST_SHA256`. The shared source pubspec stays 1.0.0+8;
the iOS archive explicitly overrides build number to 9. Android's already-built
8, its frozen SHA/digest bindings and workflow build-number guard are unchanged.

## Acceptance and release boundaries

Status: SOURCE-ONLY ACCEPTED for signed build 9 and TestFlight verification.
No replacement binary has yet been built, uploaded or run on the iPhone.

The reviewed hotfix is exactly thirteen paths: this manifest, the signed iOS
workflow, the platform build-number validator, its three related contract tests,
the existing plugin sanitizer, the new build-local deferred-package helper and
its fixture tests, and the two Python graph/artifact verifiers with their tests.
No Android workflow/native file, pubspec, lock, iOS Runner code, logo, UI or
signing capability changed. The prior source remains separately reproducible.

Final local validation:

- Related Flutter tests: 79 passed, zero failed; one Windows-only symlink fixture
  skipped (not counted as a pass). The macOS CI suite executes that fixture.
- New Python artifact/graph verifiers: 32/32 passed, including actual local
  symlink-escape cases. The actual signed build-8 IPA is rejected by the new
  artifact verifier for retaining GoogleMobileAds.framework.
- Whole-source Flutter analysis: no issues, 108.1 seconds.
- Formatting: seven changed Dart files, zero changes; whitespace check passed.
- The first targeted run caught a raw-string typo in a new workflow assertion;
  it was corrected before the final successful rerun. No test assertion was
  weakened and no golden/exclusion/performance budget changed.

Evidence log SHA-256:

- Flutter targeted: `06f1f0bb646ca65553c6ebe8f899b3de3e1902ddb59a07a6c0a0ce6d4d229ac4`
- Python gates: `d6a956006d36ba114a6cb26f22a1da8b81e1fd73a7412d691844d9b59dd01c38`
- Whole analysis: `9d05926317ced916198fc47e63c6e4d77cc67be35aaec688c5a9d4cc0754e528`

Commit only the reviewed hotfix paths on
`release/ios-plus9-startup-hotfix-20260906`, then bind the exact commit and this
manifest's digest externally before dispatch. The preexisting eight diagnostic
PNG modifications must remain unstaged. CI reruns the whole unchanged portable
test policy on the committed checkout, not this local diagnostic worktree.

The final signed artifact must pass both plist checks and a native-artifact
scan: no GoogleMobileAds/UserMessagingPlatform frameworks, google_mobile_ads
resources/registration or native SDK markers. The new gate is regression-tested
against the actual crashing build 8 and rejects it. Codesign, entitlements,
provisioning, package identity and whole portable suite remain mandatory.

These source/artifact checks do not prove launch success. App Store submission
remains held until the replacement TestFlight build opens successfully on the
owner's iPhone. Existing broad simulator waiver is not relabeled as a pass.
Public release remains MANUAL; build 7 and crashing iOS build 8 must not advance.

Historical +8 manifests and test evidence remain unmodified as lineage, not as
certification of this new build or denial of the observed crash. The eight
unstaged diagnostic PNGs and all original preserve-only user changes are kept
outside the staged hotfix delta. No broad git add/reset/checkout is authorized.
