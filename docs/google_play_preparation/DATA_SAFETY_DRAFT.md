# Google Play Data Safety — Verified Repository Draft

**Status: repository evidence only. Do not submit unchanged.** The final Play
Console declaration must match the signed AAB, enabled configuration, network
behavior, privacy policy, and every transitive SDK.

## Current local-first release candidate

The app handles these categories on device:

- Profile and body attributes.
- Weight, nutrition, meals, hydration, activity, sleep, heart-related metrics,
  blood pressure, blood glucose, oxygen saturation, respiratory rate, exercise,
  and provenance associated with imported health records.
- Preferences, locale, theme, consent state, local decisions, explanations, and
  outcome evidence.
- Bluetooth peripheral identity and measurements after explicit pairing.

For the current build composition:

- Developer-controlled collection: None activated.
- Sharing with third parties: None activated.
- Advertising, attribution, analytics, and crash reporting: None activated.
- Accounts, cloud synchronization, remote AI, commerce, and community: None
  activated.
- Health Connect access: permission-gated and used for user-visible health
  timeline and decision-support features.
- Health Connect writes: limited to weight and hydration.
- User export: initiated by the user through the operating-system share sheet;
  the user selects the destination.
- Data in transit: not applicable while remote services remain inactive.
- Local deletion: available through the local-data lifecycle and uninstall.

The presence of an inactive Supabase dependency is not evidence of collection.
The current production capability boundary does not initialize account or sync
flows and defaults `BIL_USE_SUPABASE` to false. If any remote configuration or
SDK is activated, this draft is invalid until collection, sharing, purpose,
retention, security, and deletion are reassessed.

## Submission gate

Before Play Console submission, compare this draft with a release-AAB dependency
inventory and network inspection, complete the public privacy policy, confirm
age/target-audience answers, and have the Product Owner approve every Data
Safety selection. Console submission remains an external gate.
