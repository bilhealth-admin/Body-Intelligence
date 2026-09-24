# BIL iOS 1.0.0 build 28 — Apple privacy closure source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 28`

## Release identity and scope

iOS build 28 is the next candidate after Apple rejected build 27 under Guidelines 2.3.10, 5.1.1(i), and 5.1.2(i). It is derived from the exact build-27/Android-22 shared source commit `14786b08fa24991ba7445e8c607a993413a840a6` and preserves the existing application behavior except for the verified third-party AI disclosure, consent enforcement, privacy-language, and App Store screenshot closure documented in `BIL_APPLE_BUILD28_PRIVACY_CLOSURE_2026-09-24.md`.

The signed iOS workflow supplies `--build-number 28`, producing `CFBundleVersion 28`; the public marketing version remains `1.0.0`.

After the final source commit is pushed, repository variable `BIL_IOS_V28_AUDITED_SOURCE_SHA` must equal that exact commit and `BIL_IOS_V28_STAGING_MANIFEST_SHA256` must equal the SHA-256 of this committed file. The workflow independently validates the source, manifest, build number, signing, package, entitlements, and App Store Connect upload prerequisites.

## Deployment prerequisites

Before build 28 is submitted for review, deploy and verify:

- `supabase/migrations/202609240001_apple_ai_consent_policy_enforcement.sql`
- `supabase/functions/ai-coach`
- `supabase/functions/analyze-meal`
- the updated public privacy page from `public_site/app.js`

No production deployment or App Store submission is represented by this source manifest.

## Validation boundary

Targeted Flutter privacy tests, targeted Deno provider/consent tests, and changed-surface Flutter analysis passed locally. Signed IPA creation, physical-device consent flows, live backend deployment, TestFlight processing, and App Review acceptance remain separate release evidence produced only by their respective stages.
