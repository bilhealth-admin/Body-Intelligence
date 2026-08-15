# BIL v1 Final Release Constitution

Status: current and sole execution authority for the v1 release-candidate closure.
Verified: 2026-08-05.

## Product identity

- Product: Body Intelligence Log (BIL)
- Public developer: BIL Health
- Android application ID: `com.kadem.bil` (frozen for v1)
- Apple bundle ID: `com.kadem.bil` (frozen for v1)
- Domain: `bilhealth.com`
- Administration: `bilhealth.app@gmail.com`
- Support receiving address: `support@bilhealth.com`
- Privacy receiving address: `privacy@bilhealth.com`

The domain aliases are proven for inbound forwarding only. Sending from them is
not claimed. Package identifiers must not change during v1 closure.

## Product truth

BIL is a privacy-first, offline-first health and nutrition log. Calculated
insights expose their source, confidence, limitations, and missing-data state.
The product does not diagnose disease, invent nutrition facts, fabricate
measurements, or represent emulators, mocks, static audits, or configured code
as proof of a live external service or physical device.

External features fail closed. Community, cloud analysis, push, advertising,
store billing, catalog downloads, and provider-backed media are visible only
when their complete production configuration is present. Subscribers are
ad-free. Digital subscriptions use Google Play Billing or Apple In-App
Purchase; prices and taxes are displayed from the store response.

## Release architecture

The supported user journeys cover account lifecycle, onboarding, profile,
daily food/water/weight/exercise logging, barcode classification, voice and
meal-image gateways, plans, licensed content packs, analytics, weekly reports,
explainable intelligence, community safety controls, notifications, connected
health, and device management. Local persistence is authoritative while
offline. Cloud synchronization is opt-in, deduplicated, conflict-aware, and
subject to authentication and row-level security.

Arabic, English, French, Spanish, and Turkish are supported. Arabic is RTL;
the others are LTR. Release evidence includes light/dark, responsive,
accessibility, and golden coverage. Professional linguistic and physical-device
review remain external evidence gates and are never inferred from automation.

## Privacy, health, and safety

- Collect only data required for user-requested functionality and consent.
- Never use health data for advertising, marketing, or targeting.
- Never place sensitive health details in lock-screen notifications by default.
- Tokens and credentials use platform secure storage and are never committed.
- Account deletion covers local and cloud data; unavailable cloud deletion is
  reported honestly and queued/retried safely where supported.
- Health Connect, HealthKit, BLE, camera, microphone, and notifications request
  the minimum permissions at the point of use.
- Unsupported, stale, duplicated, corrupt, implausible, or unit-ambiguous
  measurements are rejected rather than displayed.

## Build and store boundary

Android v1 targets API 36, requires API 26+, uses Java 17, produces a signed
64-bit AAB, and verifies native 16 KB page compatibility. Release signing
secrets remain outside Git. iOS source, entitlements, privacy manifest, and
cloud workflow are prepared, but a signed archive, IPA, TestFlight result,
HealthKit device result, and APNs result require an active Apple Developer team.

Current official references:

- Google Play target API requirements (checked 2026-08-05):
  https://support.google.com/googleplay/android-developer/answer/11926878
- Apple App Review Guidelines (checked 2026-08-05):
  https://developer.apple.com/app-store/review/guidelines/
- Apple privacy manifests (checked 2026-08-05):
  https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Android Health Connect guidance (checked 2026-08-05):
  https://developer.android.com/health-and-fitness/guides/health-connect

## External gates

The following are not engineering failures and must not be claimed complete:

1. Google Play identity/address review and console-side listing approval.
2. Apple Developer Program activation, Team ID, signing, IAP, APNs, archive,
   TestFlight, and App Store review.
3. Final store product IDs, sandbox/closed-track purchase and restore evidence.
4. Credentialed Supabase smoke/RLS tests and deployment verification.
5. FCM/APNs credentials and real push delivery.
6. Physical Android/iPhone, Health Connect/HealthKit, BIL watch, and BLE device
   validation.
7. Publication and HTTPS verification of the eight public policy/support URLs.
8. Professional French, Spanish, and Turkish linguistic review.
9. Legal, medical, and owner visual approval.
10. GitHub transfer to `bilhealth/Body-Intelligence` when interactive authority
    and integration verification are available.

## Closure rules

An engineering RC requires clean format/analyze/tests/goldens, a signed Android
AAB with recorded SHA-256 and 16 KB verification, no P0/P1 internal defect, no
secret or unknown untracked file, verified rights, a reproducible final audit,
and a clean Git worktree. A tag requires the additional literal owner decision
`VISUAL_OWNER_APPROVAL=PASS`. Store upload and publication always require a
separate owner instruction and the applicable account gates.

