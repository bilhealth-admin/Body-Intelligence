# BIL store API completeness handoff — 2026-08-31

This handoff separates live store configuration from build-, owner-, UI-, and
hardware-dependent work. It does not reopen App Content, Data Safety, or the
already-entered subscription benefit copy. It did not build Flutter, upload a
binary, update a track, submit for review, publish, rotate a credential, or
change a price.

## Fresh authenticated evidence

- App Store Connect `v1` GET audit refreshed at
  `2026-08-31T03:07:23.847Z`.
- App Store Connect commerce GET audit refreshed at
  `2026-08-31T03:08:07.955Z`.
- Google Play release-surface evidence was generated at
  `2026-08-31T02:22:15.375Z`; both existing Android Publisher credentials had
  already returned the same repaired catalog state.
- Sanitized evidence lives under
  `artifacts/release/apple/2026-08-30-final-audit/` and
  `artifacts/release/google/2026-08-31-api-audit/`.

## Complete now

### Apple

- App `6805349703`, bundle `com.bilhealth.bodyintelligencelog`, version `1.0.0`
  and manual release are configured.
- English (US) version copy, app-information localization, support/marketing,
  privacy and privacy-choices URLs, categories, content-rights declaration,
  age-rating declaration, and App Review contact/demo-account/notes presence
  are recorded.
- Production and sandbox App Store Server Notification V2 URLs both point to
  the live purchase-verification endpoint.
- The subscription group has four subscriptions. Each has an English (US)
  localization, one version, one complete 1024×1024 subscription image, one
  complete review screenshot, availability, prices, and review notes.
- Both AI Coach products have 168 one-week free-trial territory records.
  Premium monthly/annual correctly have no trial.
- `bil_ai_boost` is `READY_TO_SUBMIT` with localization, availability, price,
  and complete review screenshot.
- App availability is selected for all 175 App Store territories and new
  territories are enabled.

The top-level four subscription resources still report the derived state
`MISSING_METADATA`, while each v2 subscription version and localization is
`PREPARE_FOR_SUBMISSION`, both image types are `COMPLETE`, and authenticated UI
reconciliation exposes Add for Review without an inline validation error. No
specific missing field is proven by the API. Therefore there is no safe
metadata mutation to make from that derived state alone.

### Google Play

- Default `en-GB` listing, contact website/email, icon, feature graphic, and
  eight phone screenshots are present. The current copy makes no blood
  pressure, oxygen, SpO2, medical-reading, or medical-device capability claim.
- Premium monthly/yearly are active in their intended four markets without a
  trial.
- AI Coach monthly/yearly are active in 168 markets. Both expose the exact
  active offer `trial-7-day`, tag `new-customer`, and one free `P7D` cycle.
- The accidental `P1M` base plan under the annual AI product is inactive, not
  deleted.
- Belarus is aligned at AI monthly USD 7.19, AI annual USD 43.19, and unchanged
  Boost USD 6.00; the monthly offer includes Belarus.
- `bil_ai_boost` is active. No price change is authorized by this handoff.
- Four AABs exist, version codes 1–4. Alpha serves completed version 4 in 176
  countries. Production, beta, and internal contain no release.

## No safe store-API mutation remains before source freeze

The following work is technically possible through an API only after its
prerequisite exists; doing it now would be premature rather than completing a
missing setting:

1. Upload signed Android build 5 or higher without updating a track, after QA
   freezes one source commit and the workflow proves its hash/signing identity.
2. Upload the matching signed IPA to TestFlight, wait for one valid
   App-Store-eligible build, then attach only that build to version 1.0.0.
3. Upload public App Store product-page screenshots only after final iPhone
   6.9-inch and iPad 13-inch runtime captures are approved. Current product-page
   screenshot-set count is zero; product review attachments are a different,
   already-complete asset class.

None of these steps authorizes App Store submission, Play track mutation,
review submission, or public rollout.

## Owner/UI/external blockers

- Apple DSA trader status remains unprovided for 27 EU territories. This is an
  owner/App Store Connect compliance action, not a normal catalog API patch.
- Apple currently has zero builds and zero pre-release versions. The current
  local APK/AAB are build 4 and predate source `1.0.0+5`; there is no local IPA.
- Public App Store screenshots require truthful final-build iPhone and iPad
  runtime captures; generated widget goldens and Android emulator captures are
  not substitutes.
- First-version subscriptions and the consumable must later be added to the
  same draft submission as app version 1.0.0. Submission remains owner-gated.
- Google closed-test eligibility time/feedback and any Console warning are
  Console state, not safely inferred from the Android Publisher catalog API.
- Google RTDN/Pub/Sub is not live-proven. The current Android Publisher
  credentials do not have Pub/Sub list/configure authority. Supabase Edge
  secret names also cannot be enumerated through the available connection.
  Topic, OIDC push subscription, Console test notification, and a processed
  inbox row remain an owner/GCP/Supabase operations gate.
- Real Android/iPhone, Health Connect/Wear OS, HealthKit/Apple Watch,
  fitness-only BLE, Play Billing, and StoreKit lifecycle evidence must be
  collected against the exact final binary hashes.

## Release decision

`STORE_API_CONFIGURATION_BEFORE_BUILD=PASS`

`FINAL_BINARY_AND_PUBLIC_RELEASE=BLOCKED`

The blockers are final source QA/freeze, signed build creation, real-device and
purchase-lifecycle evidence, approved Apple screenshots, Apple DSA, RTDN, and
separate owner approval for submission/rollout—not a proven missing ordinary
Apple or Google catalog field that should be patched now.
