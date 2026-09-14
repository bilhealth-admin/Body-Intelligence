# Android 15 Google Play / Android / Meta review checklist — 2026-09-14

This checklist is release evidence for BIL Android 1.0.0 (versionCode 15). It is
not a substitute for Play Console declarations. Android build 13 remains
untouched while under production review; Android build 14 remains an unsubmitted
historical candidate.

## Code and package gates

- [x] targetSdk 36 / compileSdk 36.
- [x] Production Play Integrity gate is required.
- [x] Release signing is fail-closed when the private release key is absent.
- [x] Final AAB gate verifies SDK level, optional hardware declarations and
      16 KB native-library alignment.
- [x] Cleartext traffic is disabled and Android backup is disabled.
- [x] Legacy external-storage permissions are removed.
- [x] AD_ID, Privacy Sandbox Topics, Attribution and Custom Audience permissions
      contributed by ad SDKs are removed from the merged manifest.
- [x] Google sign-in uses the reviewed native Android path.
- [x] Meta/Facebook sign-in uses the native SDK token flow; automatic app-event
      logging and advertiser-ID collection are disabled.
- [x] Store prices come from Play Billing, purchases are verified server-side,
      restore is available and subscription management opens the Play account.
- [x] AI Boost uses the canonical `bil_ai_boost` identifier in client/server
      persistence alignment.
- [x] Health Connect has a dedicated rationale/privacy surface and granular
      Android health permissions.
- [x] Community requires active policy acceptance before publishing/messaging
      and exposes report/block/delete safety controls.
- [x] Store reviewer access remains visible from the sign-in surface.

## Shared Build 18 quality carried into Android 15

- [x] AI Coach retains a verified surface during silent entitlement refresh and
      route re-entry instead of flashing the whole page into loading.
- [x] Health synchronization yields to the UI event loop and processes bounded
      pages rather than monopolizing the main isolate.
- [x] Health Connect historical bootstrap is paged and uses the supported
      changes API.
- [x] Manual cloud sync has a bounded RPC wait.
- [x] Meal-image preprocessing runs off the UI isolate.
- [x] Camera/photo errors are localized and raw platform failures are hidden.
- [x] Food-search runtime copy is complete across the 25 production locales.
- [x] Reminder scheduling invalidates stale asynchronous work.
- [x] Health information surfaces expose reviewable sources and methodology.

## Owner actions that cannot be guaranteed by source code

Before submitting versionCode 15, verify in Play Console:

- Health Apps declaration exactly matches current BIL features and Health
  Connect permissions.
- Store description contains the non-medical-device disclaimer and healthcare
  professional reminder required for non-medical health apps.
- Data Safety answers match every enabled production SDK and backend flow.
- App access credentials are reusable, location-independent and do not require
  expiring OTP/2FA.
- Subscription/free-trial wording, prices and billing periods match the Play
  products shown to the reviewer.
- Contains Ads answer matches the release configuration actually submitted.
- Community/UGC disclosure and public listing match the in-app moderation
  experience.
- Production screenshots/listing do not promise unavailable features.

## Final unified-source rule

After the locally tested iOS Build 18 work is committed, apply the single
Android 15 overlay commit to that iOS commit without altering iOS runtime files.
The final release source SHA should then build:

- iOS: 1.0.0, CFBundleVersion 18.
- Android: 1.0.0, versionCode 15.

Do not upload Android 14 and do not replace/cancel Android 13 while its current
Google Play review is active.
