# Google Play Data Safety — BLOCKED DRAFT

> **DO NOT SUBMIT THIS FILE TO PLAY CONSOLE.** The earlier local-only answers in
> this draft are obsolete for the current build. The app now initializes
> Supabase-backed account/cloud features, can send user-authorized content to
> Gemini through BIL Edge Functions, includes Google Mobile Ads/UMP and Google
> Play Billing, and exposes Community features. Use the evidence matrix and
> owner checklist in
> [`BIL_ANDROID_HEALTH_POLICY_RELEASE_AUDIT_2026_08_24.md`](BIL_ANDROID_HEALTH_POLICY_RELEASE_AUDIT_2026_08_24.md)
> against the exact signed AAB. Console answers remain blocked until the Product
> Owner reviews that matrix and the release AAB/SDK inventory.

The owner selected an adult-only 18+ Google Play audience on 2026-08-24. The
local Privacy/Terms and store metadata now reflect that decision; they still
must be published/applied in the live site and Play Console before submission.

## Current local-first release candidate

The app handles these categories on device:

- Profile and body attributes.
- Weight, nutrition, meals, hydration, activity, sleep, heart-rate metrics,
  exercise, and provenance associated with imported fitness records.
- Preferences, locale, theme, consent state, local decisions, explanations, and
  outcome evidence.
- Compatible fitness-peripheral identity plus weight, body-composition, and
  heart-rate measurements after explicit Bluetooth pairing. The product BLE
  paths expose only the explicitly supported fitness profiles in this release.

Under Google's Data Safety definition, those on-device-only uses are **not
collection** unless the app or one of its SDKs transmits the data off-device.
Do not mark a field collected merely because it exists in SQLite, Health
Connect, secure storage, or memory. Mark the same field collected when an
enabled sync, AI, upload, Community, commerce, ads, or SDK path transmits it.

For the current build composition:

- Developer-controlled collection: active for signed-in/cloud-enabled features.
- Third-party processing/sharing assessment: required for Supabase, Gemini,
  Google Mobile Ads/UMP, Play Billing/Integrity, Cloudflare delivery, and any
  enabled external food lookup. Compare actual data flow with Play's current
  collection/sharing definitions; package names alone are not enough.
- Advertising: contextual/non-personalized ads can be requested for eligible
  free adult users only. Health, nutrition, weight, profile, location, search,
  and AI content are excluded from ad requests. Google's official native GMA
  SDK 25.4.0 disclosure says it automatically collects and shares IP address
  (which may estimate general location), user product interactions,
  diagnostics, and device/account identifiers for advertising, analytics, and
  fraud prevention. The public privacy policy and Console form must reflect
  that behavior while the SDK operates; contextual/NPA does not make it
  `none`.
- Contains ads: answer **Yes** while the production artifact integrates Google
  Mobile Ads/banner code, even if eligibility and consent gates fail closed.
- Accounts, cloud synchronization, remote AI, commerce, and Community: present
  and conditional on user action, consent, configuration, or entitlement.
- Health Connect access: permission-gated and used for user-visible health
  timeline and wellness insights.
- Health Connect writes: limited to weight and nutrition records explicitly
  selected by the user for synchronization.
- User export: initiated by the user through the operating-system share sheet;
  the user selects the destination.
- Data in transit: applicable to enabled remote services and required to be
  encrypted in transit.
- Local deletion: available through the local-data lifecycle and uninstall.

The former statement that Supabase and other remote services were inactive is
not true for the current release candidate. Do not reuse screenshots or Console
answers based on that older boundary.

## Submission gate

Before Play Console submission, compare this draft with a release-AAB dependency
inventory and network inspection, complete the public privacy policy, confirm
age/target-audience answers, and have the Product Owner approve every Data
Safety selection. Console submission remains an external gate.
