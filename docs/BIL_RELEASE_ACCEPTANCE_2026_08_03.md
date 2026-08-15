# BIL release acceptance gate — 2026-08-03

This document is the final authority when older roadmaps, screenshots, or
completion notes disagree. A feature is complete only when its production path,
failure state, privacy boundary, and verification evidence all exist.

## Product experience included in the release candidate

- Phone-first dashboard, daily log, progress, insights, profile, and settings.
- Weight, meals, hydration, context, trend evidence, and reviewable Body Twin.
- Local food search plus integrity-checked downloadable catalog packs.
- Barcode classification that distinguishes non-food products from missing food.
- Wellness library covering recipes, sleep, movement, workouts, and fasting.
- Nutrition pathways for smart fat loss, lean-mass gain, Mediterranean,
  high-protein, plant-forward, DASH, low-carb, guided keto, pregnancy, and
  clinician-supervised PSMF.
- Connected-health carousel preserving both the smartwatch and medical-device
  experiences. No simulated measurement may be shown as a live reading.
- Free, Plus, Pro, Coach, Clinic, and Enterprise product-plan presentation.
- Account, local-only use, cloud boundary, community, notifications, weekly
  reports, voice capture, and image-analysis entry points.
- Original BIL visual assets. Reference applications are used for information
  hierarchy only; their trademarks, screens, photographs, and copy are not
  shipped.

## Safety invariants

- BIL does not diagnose, fabricate measurements, or silently change a plan.
- Every generated plan remains a reviewable draft until the user accepts it.
- Pregnancy, keto, DASH, and PSMF display their applicable professional-review
  boundary. PSMF must never be presented as a self-directed plan.
- AI answers expose uncertainty, missing data, and evidence provenance.
- Camera, microphone, Bluetooth, Health Connect, and HealthKit are requested only
  at the moment the user invokes the associated feature.

## Honest activation boundary

The repository contains interfaces and user experiences for several connected
capabilities. They are not called production-active until their external service
is configured and a real-device or sandbox transaction has passed:

- store subscriptions and purchase restoration;
- cloud AI inference and paid usage controls;
- SMS verification and branded transactional email;
- community moderation, messaging delivery, and push notifications;
- public catalog/community-food publishing workflow;
- HealthKit, Health Connect, and supported BLE-device certification.

Unavailable services must show a clear unavailable/local-only state. Demo data
must never be labelled live.

## Localization gate

The application exposes Arabic, English, French, Spanish, and Turkish locales.
Release in a locale is allowed only after every reachable screen passes a native
speaker copy review, overflow review at large text, RTL/LTR navigation review,
and store-metadata review. Until then, Arabic and English remain the primary
release languages and the other locales are preview candidates, not a claim of
complete translation.

## Android / Google Play gate

- Create an owned upload keystore and `android/key.properties`; never commit it.
- Confirm final package ID, app name, version code, icons, adaptive icon, and
  Android 12 splash on physical phones.
- Produce a signed release App Bundle and verify installation from an internal
  Play track.
- Configure Play Billing product IDs and verify purchase, cancellation, expiry,
  grace period, upgrade/downgrade, and restore with licensed test accounts.
- Publish an accessible privacy-policy URL and complete Data safety, content
  rating, health-app declarations, ads declaration, and account deletion flow.
- Capture localized phone screenshots from the final signed candidate.
- Complete closed testing and policy requirements shown by the current Play
  Console account before production submission.

## iOS / App Store gate

- Use a Mac with the current supported Xcode and Flutter toolchain.
- Confirm the owned bundle ID, Apple Developer team, entitlements, HealthKit
  purpose, Bluetooth purpose, camera, photos, and microphone prompts.
- Configure StoreKit products and verify purchase and restoration using Sandbox
  and TestFlight accounts.
- Archive the Release scheme, validate it in Xcode, and complete App Privacy,
  nutrition/health disclosures, export compliance, age rating, support URL,
  privacy-policy URL, and account deletion.
- Test Arabic RTL and all enabled locales on representative iPhone sizes with
  large text and reduced motion.
- Upload to TestFlight, complete an external beta pass, then submit the same
  accepted build to App Review.

## Required verification before either upload

Run the formatter, full analyzer, focused release contracts, full Flutter tests,
Android release bundle, and iOS archive on macOS. Inspect all generated goldens
and store screenshots. A green test command alone is not visual approval.

## Definition of done

“Ready for store upload” means all repository checks pass and the signed builds
complete. “Released” means the relevant store approved the submitted build.
Neither phrase may be used earlier.
