# BIL Android 1.0.0 build 15 — unified review-ready source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 15`

## Release identity and source boundary

Android build 15 supersedes the unsubmitted Android build 14 candidate while
leaving Android build 13 untouched in Google Play production review.

This candidate is intentionally based on the shared Build 18 application source
at `6d1247cd20b500691d9d71cc924ea5760979afe9` so Android receives the same current cross-platform stability
work instead of copying fixes manually from the older Android 14 source. The
Android release workflow overrides the shared Flutter version with
`--build-number 15`, producing `versionCode 15` while `versionName` remains
`1.0.0`.

The final release may later be rebased/cherry-picked onto the locally tested
iOS Build 18 commit. That integration must preserve the iOS runtime and use one
final source SHA for iOS build 18 and Android versionCode 15.

## Android 15 runtime and review scope

The shared source inherited by this candidate includes the current AI Coach
retained-surface and silent-refresh protections, bounded cloud synchronization,
responsive Health synchronization and SQLite paging, Health Connect paging,
off-UI-isolate meal-image preprocessing, 25-locale food-search copy, localized
camera controls, notification stale-work invalidation, health information
sources/methodology, and the canonical `bil_ai_boost` product alignment.

Android-specific release boundaries remain:

- compileSdk 36 and targetSdk 36.
- minSdk 26 for the supported Health Connect client.
- Play Integrity required in production release builds.
- Google Credential Manager and native Meta/Facebook authorization.
- Meta automatic app-event logging and advertiser-ID collection disabled.
- Contextual/deferred ads only; AD_ID, Topics, Attribution and Custom Audience
  permissions are removed from the final merged manifest.
- Health Connect permissions remain feature-scoped and user revocable, with a
  dedicated permission rationale activity and privacy-policy entry point.
- Release AAB is restricted to arm64-v8a and x86_64 and is checked for Android
  16 KB page-size/ELF alignment.
- Store reviewer access, purchase restore, subscription management and truthful
  device-store pricing remain available.
- Community publishing/messaging remains policy-gated with in-app report, block
  and delete safety surfaces.

## Google Play owner-console checks

The repository can enforce runtime and packaging contracts, but these Play
Console declarations must still match the submitted Android 15 binary before
review:

1. Health Apps declaration: Activity and Fitness plus Nutrition and Weight
   Management, and every actually used Health Connect data type.
2. Health/medical store disclaimer: BIL is not a medical device and does not
   diagnose, treat, cure or prevent a medical condition; users should consult a
   qualified healthcare professional for medical advice, diagnosis or treatment.
3. Data Safety: health/fitness data, account data, user content, photos, voice
   transcript, AI requests, Community data and every enabled third-party SDK
   must match actual collection/sharing behavior.
4. App access: the reusable reviewer account/instructions must work globally,
   must not depend on OTP/2FA expiry, and must unlock subscription-gated review
   paths as documented.
5. Subscription and trial surfaces in Play Console must match the localized
   device-store price, billing period, auto-renewal and cancellation wording.
6. Community/UGC declarations and store copy must match the active in-app
   policy, report/block/delete controls and Free Community access.
7. The public Play listing and screenshots must describe the functionality in
   this binary; Android build 14 must not be promoted by mistake.

## Verification boundary

This manifest records the intended source and policy boundary. It does not claim
that a signed Android 15 AAB has already been built, uploaded, reviewed or run on
a physical device. The signed workflow still independently validates source
binding, manifest digest, analyzer, portable tests, signing, Play Integrity
configuration, package SDK level, optional hardware declarations, and 16 KB/ELF
alignment before producing an authorized artifact.
