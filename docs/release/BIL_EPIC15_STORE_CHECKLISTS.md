# BIL Epic 15 store checklists

> **Historical checklist — do not submit its old Data Safety or ads answers.**
> Current Android evidence and required Console actions are authoritative in
> `docs/google_play_preparation/BIL_ANDROID_HEALTH_POLICY_RELEASE_AUDIT_2026_08_24.md`.
> In particular, the current build contains conditional contextual ads and
> active Supabase-backed features; `ads (none)` below is obsolete.

## Google Play

Owner-supplied values that cannot be inferred remain explicitly marked
`OWNER_INPUT_REQUIRED` in the release metadata and blocker register.

- Upload the signed 16 KB-compatible AAB from Epic 14 to an internal/closed
  track; do not claim public release. Google currently requires support for
  target 35+ and begins blocking incompatible updates on 1 February 2027, so
  this is a release-compatibility gate rather than the August 2026 API deadline.
- Enter only owner-reviewed localized listings from
  `BIL_EPIC15_STORE_METADATA.json`; the app configures 25 locales, while the
  metadata draft currently contains five localized listing sets.
- Upload the 512×512 icon, 1024×500 feature graphic and actual Android
  screenshots from `store_assets` after the Epic 15 gate.
- Complete Data safety and the Health apps declaration accurately: Activity and
  Fitness, Nutrition and Weight Management, Sleep Management, and applicable
  general wellness. The owner limited this release to compatible external
  fitness devices and the code allows only weight-scale, body-composition, and
  heart-rate BLE profiles. Verify that boundary in the final signed AAB before
  marking Medical Device Apps not applicable; reopen the answer if devices,
  purpose, code, or claims later expand.
- Supply working privacy, support and account-deletion HTTPS URLs only after the
  real domain values are provided and verified.
- Configure Plus/Pro products and base plans, then inject their exact IDs at
  build time. Free has no store product.
- Complete content rating and apply the owner's **18+ only** target audience,
  and answer **Contains ads: Yes**
  while the Google Mobile Ads/banner integration remains in the release;
  app access/reviewer instructions, permissions declarations if prompted, and
  content rights. Do not reuse the historical `ads (none)` answer.
- Closed-track purchase, restore, cancellation and server-entitlement evidence
  remains external and must not be claimed by this package.

## Apple App Store

- Wait for Apple Developer activation, create the App Store Connect record and
  use the owner-approved bundle ID `com.bilhealth.bodyintelligencelog`.
- Enter the five localized metadata sets and upload 1–10 actual screenshots per
  selected device family. Screenshots and the 1024 icon must have no alpha.
- Complete App Privacy, age-rating and export-compliance questionnaires based on
  actual production behavior. Social networking and messaging require honest
  age-rating answers.
- Publish working privacy and support URLs before review.
- Create the subscription group and four Plus/Pro products using owner-selected
  immutable IDs; configure localization, duration, price and review screenshots.
- Put review credentials only in App Store Connect. Never commit them.
- Run the signed macOS workflow, validate the IPA and test purchase/restore in
  Sandbox/TestFlight. These remain external until evidence exists.

## Store preview plan

No preview video is claimed for v1. If produced later, use only real screen
recordings, disclose no personal health data, avoid simulated connected-device
success, and follow each store’s current duration/codec/device requirements.
