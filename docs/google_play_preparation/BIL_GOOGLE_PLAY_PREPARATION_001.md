# BIL-GOOGLE-PLAY-PREPARATION-001

Baseline: `9b906a41b241a27c4c85fcdf1a396b77226ead7d`

## Purpose

Prepare the local Android repository for the future Google Play Console onboarding stage without creating credentials, enabling billing, activating cloud services, or claiming store approval.

## Internal correction

The app used `google_fonts` for Manrope and IBM Plex Sans Arabic while those font files were not bundled. The package supports HTTP runtime fetching, which conflicted with BIL's offline-first and no-upload-while-cloud-disabled statements. This package removes the runtime font dependency, uses the platform font for non-Arabic locales, and registers the already-present Noto Naskh Arabic assets for Arabic.

## External gates intentionally left open

- Play Console developer account and identity verification.
- Organization registration decision and D-U-N-S information.
- Play App Signing / upload key creation.
- Public privacy-policy URL.
- Data Safety form submission.
- Health Apps declaration submission.
- Store listing content, screenshots, content rating, target audience, and app access.
- Billing, subscriptions, Play Integrity, analytics, crash reporting, and production cloud.

## Acceptance

- No Google Fonts runtime-fetch dependency or import remains.
- Bundled Arabic font assets are registered.
- Existing privacy and medical-disclaimer surfaces remain present.
- Android package identity, API 36, signing boundary, Health Connect rationale, and cleartext prohibition remain intact.
- Flutter analysis, focused tests, release AAB build, and diff hygiene pass.
