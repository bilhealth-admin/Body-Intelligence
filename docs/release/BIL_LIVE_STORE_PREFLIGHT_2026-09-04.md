# BIL live store preflight — 2026-09-04

## Safety decision

This was an authenticated, no-build, no-submit, no-rollout preflight. It did
not upload a binary, attach a new build, submit a version or product for
review, migrate subscription price cohorts, activate a production track, or
change automatic release. No live store mutation was made.

The two known Google price drifts were converted successfully in a dry run,
but were deliberately not patched through the Publisher API. The only API
write paths replace the whole repeated `basePlans` or `purchaseOptions`
field. That would include unrelated plans/options and is outside the narrow
revenue-change safety rule for this release.

## App Store Connect live read-back

Authenticated App Store Connect reads completed successfully.

- App `6805349703`, iOS version `1.0.0`, is `DEVELOPER_REJECTED`. There is no
  active App Store version submission resource.
- Release mode is `AFTER_APPROVAL`; it remains manual. No phased release is
  configured.
- Builds `5`, `6`, and `7` are all `VALID`. Build `7` is App Store eligible
  and is the build attached to version `1.0.0`.
- The public en-US listing has eight complete iPhone 6.7-inch screenshots and
  eight complete iPad 12.9-inch screenshots. Required description, keywords,
  support URL, reviewer contact fields, demo-account fields and review notes
  are present. Secret values are intentionally omitted from this report.
- TestFlight group `BIL Internal QA` is internal, feedback-enabled, has one
  tester, and contains valid builds `5` and `7`. Build `6` is valid but is not
  assigned to that group.
- All five expected commerce product IDs exist. The four subscriptions and
  the consumable Boost are `READY_TO_SUBMIT`; no expected product is missing.
- Apple prices match the approved anchors: AI monthly USA `USD 5.99`, AI
  annual USA `USD 49.99`, and Boost USA `USD 2.49`. Premium monthly/annual
  retain the approved localized EG/IN/PK/TR prices.
- Apple product availability matches the intended split: Premium products in
  EG/IN/PK/TR, AI products in the other 168 launch markets, and Boost across
  the 172 launch markets. App availability itself is enabled in all 175
  current App Store territories and future territories are enabled.
- Each subscription version is version `1` and currently
  `DEVELOPER_REJECTED`, consistent with the withdrawn app version. Each has
  one complete 1024x1024 product image. The four subscription products use
  the shared Premium subscription artwork; Boost uses its separate Coach
  artwork/review screenshot.

No Apple metadata or commerce repair was justified by the live read-back, so
none was attempted.

## Google Play live read-back

Two independent existing service-account credentials authenticated. After
removing timestamps, credential labels and the intentionally transient edit
IDs, their catalog and release-surface responses were identical. No credential
identifier, access token or key is recorded here.

- Production, beta and internal tracks have no release. Closed testing
  (`alpha`) contains completed release `7 (1.0.0)` with version code `7`, plus
  an empty draft release. The alpha country set contains 177 countries.
- Uploaded bundle version codes are `1`, `2`, `3`, `4`, `5`, and `7`.
- The en-GB listing exists with one icon, one feature graphic and eight phone
  screenshots. No seven-inch or ten-inch tablet screenshots are currently in
  the listing.
- Four subscriptions and Boost are active. Premium monthly and annual each
  have four regional configurations. AI monthly and the correct AI annual
  `yearly` / `P1Y` plan each have 168. The mistaken sibling `annual` / `P1M`
  plan remains safely `INACTIVE`.
- AI monthly and AI yearly each retain the active `trial-7-day` offer, tag
  `new-customer`, one free `P7D` phase, and 168 offer/phase regions. Premium
  plans have no trial.
- Boost `bil_ai_boost` / `standard-2500` is active, consumable, and has 173
  live regional price/availability configurations.

### Price drift and dry-run conversion

Google's non-persistent `monetization.convertRegionPrices` endpoint returned
HTTP 200 and current RegionsVersion `2025/03` for both targets.

| Product / plan | Live USA | Approved USA | Existing live regions to be repriced | Example converted targets |
|---|---:|---:|---:|---|
| `bil_premium_ai_coach_annual` / `yearly` | USD 35.99 | USD 49.99 | 168 + other-regions USD/EUR | EG EGP 2,899.99; IN INR 5,600; TR TRY 2,909.99; other USD 49.99 / EUR 43.00 |
| `bil_ai_boost` / `standard-2500` | USD 4.99 | USD 2.49 | 173 + new-regions USD/EUR | EG EGP 139.99; IN INR 280; TR TRY 144.99; other USD 2.49 / EUR 2.14 |

The dry-run guard hashes prove that the constructed target retained IDs,
states, billing periods, tags, tax type, region-code sets, availability and
the separate free-trial resource. Even so, the official write API requires:

- subscription `PATCH .../subscriptions/{productId}` with
  `updateMask=basePlans`, which replaces the complete base-plan array and
  necessarily includes the unrelated inactive `annual` plan; and
- one-time product `PATCH .../onetimeproducts/{productId}` with
  `updateMask=purchaseOptions`, which replaces the complete purchase-option
  array.

There is no element-level price patch for one base-plan ID or purchase-option
ID. Price migration endpoints are for legacy subscriber cohorts and must not
be used for this correction. Therefore the live prices remain unchanged.

### Canonical territory drift

Equal counts masked a real set mismatch against
`20260830180011_canonical_store_market_pricing_policy.sql`:

| Surface | Expected / live | Missing from live | Extra in live |
|---|---:|---|---|
| Premium monthly and annual | 4 / 4 | IN | NG |
| AI monthly and yearly (the inactive sibling has the same set) | 168 / 168 | AF, AI, BB, BN, BT, GY, ME, MG, MR, MS, MW, NG, NR, PW, ST, SZ, VC, XK | AW, BD, BY, CF, DJ, ER, GI, GN, HT, IN, KM, LI, MC, SM, SO, TG, VA, WS |
| Boost | 172 / 173 | AF, AI, BB, BN, BT, GY, ME, MG, MR, MS, MW, NR, PW, ST, SZ, VC, XK | AW, BD, BY, CF, DJ, ER, GI, GN, HT, KM, LI, MC, RU, SM, SO, TG, VA, WS |

No territory was changed because doing so through the API has the same broad
replacement risk. This is a separate Console blocker, not a count-only pass.

## Narrow Google Play Console repair

Perform these as two isolated, human-reviewed price operations before the next
release, then run both authenticated read-only audits again:

1. Open **Monetize with Play > Products > Subscriptions**,
   `bil_premium_ai_coach_annual`, base plan `yearly`. In **Price and
   availability**, select exactly the 168 currently available region rows,
   choose the bulk price update, enter `USD 49.99`, let Play perform its
   one-time local conversion, review the row count and USD/EUR other-regions
   values, then save. Do not edit/activate the inactive `annual` / `P1M` plan,
   do not edit `trial-7-day`, and do not migrate or end any legacy cohort.
2. Open **Monetize with Play > Products > One-time products**,
   `bil_ai_boost`, purchase option `standard-2500`. Use **Set prices > Bulk
   edit pricing**, select exactly the 173 currently available rows, set
   `USD 2.49`, review Play's conversions and the new-regions USD/EUR values,
   then save. Do not edit availability, tags, tax settings, or offers.
3. Repair the territory sets in a separate reviewed Console operation using
   the exact missing/extra lists above. Do not combine territory changes with
   the price changes; independently read back product IDs, plan/option IDs,
   states, periods, trials, tags, region sets and prices after each operation.

Google documents that regional prices can be set individually or in bulk and
that Play performs a one-time currency conversion for selected regions:

- <https://support.google.com/googleplay/android-developer/answer/12124625?hl=en>
- <https://support.google.com/googleplay/android-developer/answer/140504?hl=en>
- <https://support.google.com/googleplay/android-developer/answer/16430488?hl=en>
- <https://developers.google.com/android-publisher/api-ref/rest/v3/monetization.subscriptions/patch>
- <https://developers.google.com/android-publisher/api-ref/rest/v3/monetization.onetimeproducts/patch>

## AdMob and `app-ads.txt`

Production AdMob is intentionally fail-closed, not configured:

- `docs/release/BIL_DEFERRED_OWNER_INPUTS.json` has null publisher, Android
  app/banner and iOS app/banner IDs, with `production_enabled: false`.
- iOS Release.xcconfig and Android Gradle fallback use the all-zero placeholder
  app ID; banner IDs/publisher ID are empty compile-time inputs.
- `https://www.bilhealth.com/app-ads.txt` returned HTTP 200 as `text/plain` and
  matches the repository file, but contains only the explicit
  `pub-OWNER_PROVIDED_ID` placeholder instruction.

Do not enable ads until the owner supplies verified production publisher/app/
unit IDs and publishes a real DIRECT record. No fabricated or test ID was
installed.

## Evidence

No secret is stored in these reports.

- `G:\BIL_Temp\store-preflight-20260904\apple\v1.json`
- `G:\BIL_Temp\store-preflight-20260904\apple\commerce.json`
- `G:\BIL_Temp\store-preflight-20260904\apple\availability.json`
- `G:\BIL_Temp\store-preflight-20260904\apple\catalog.json`
- `G:\BIL_Temp\store-preflight-20260904\apple\selected-prices.json`
- `G:\BIL_Temp\store-preflight-20260904\apple\testflight.json`
- `G:\BIL_Temp\store-preflight-20260904\google\release-surface-c1.json`
- `G:\BIL_Temp\store-preflight-20260904\google\release-surface-c2.json`
- `G:\BIL_Temp\store-preflight-20260904\google\catalog-c1.json`
- `G:\BIL_Temp\store-preflight-20260904\google\catalog-c2.json`
- `G:\BIL_Temp\store-preflight-20260904\google\canonical-price-conversion.json`
- `G:\BIL_Temp\store-preflight-20260904\google\price-repair-dry-run-final\plan.json`
- `G:\BIL_Temp\store-preflight-20260904\google\price-repair-dry-run-final\operations.json`

The dry-run reports explicitly state `mutationPerformed: false`. The two
temporary Play edits used only to read edit-scoped release/listing data were
deleted without commit (`committed: false`, delete HTTP 204).
