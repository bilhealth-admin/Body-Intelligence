# BIL Epic 15 store checklists

## Google Play

Owner-supplied values that cannot be inferred remain explicitly marked
`OWNER_INPUT_REQUIRED` in the release metadata and blocker register.

- Upload the signed 16 KB-compatible AAB from Epic 14 to an internal/closed
  track; do not claim public release.
- Enter the five localized listings from `BIL_EPIC15_STORE_METADATA.json`.
- Upload the 512×512 icon, 1024×500 feature graphic and actual Android
  screenshots from `store_assets` after the Epic 15 gate.
- Complete Data safety and the Health apps declaration accurately: Activity and
  Fitness, Nutrition and Weight Management, Sleep Management, and applicable
  general wellness. Do not select Medical Device Apps without regulatory proof.
- Supply working privacy, support and account-deletion HTTPS URLs only after the
  real domain values are provided and verified.
- Configure Plus/Pro products and base plans, then inject their exact IDs at
  build time. Free has no store product.
- Complete content rating, target audience, ads (`none`), app access/reviewer
  instructions, permissions declarations if prompted, and content rights.
- Closed-track purchase, restore, cancellation and server-entitlement evidence
  remains external and must not be claimed by this package.

## Apple App Store

- Wait for Apple Developer activation, create the App Store Connect record and
  keep bundle ID `com.kadem.bil`.
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
