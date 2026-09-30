# BIL Premium Global Release Polish — QA Candidate

Date: 2026-09-30

This candidate is the post-Sapphire premium polish track.

## Intended scope

- Premium AI Coach entry welcome presentation.
- Premium Quick Add voice and meal-photo actions.
- Near-black premium dark surfaces.
- More refined consent and clinical guidance presentation.
- Multilingual food-search presentation with canonical nutrition identity kept separate from localized display labels.
- iOS runtime orientation parity with the audited iPhone/iPad Info.plist contract.
- Android-native Health Connect rationale presentation with day/night support.

## Invariants

- No Bundle ID or Android Application ID change.
- No route identifier change.
- No store metadata identifier change.
- No Google Play or TestFlight upload is performed by this QA track.
- USDA/provider food identity and nutrient values remain canonical; localized food names are display-only.
- Existing purchase, authentication, permission, Community, Connected Health, Weekly Report, Nutrition and Quick Add behavior remains subject to regression tests.

## Acceptance

The candidate is not release-ready until formatting, flutter analyze, focused regressions, complete tests/goldens, cloud contracts, platform configuration contracts and the exhaustive Sapphire shard suite pass on the accepted source.
