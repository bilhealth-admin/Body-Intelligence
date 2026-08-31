# BIL App Store Connect v1.0 final API and UI audit

- Audit date: 2026-08-30
- App Store Connect app: `6805349703`
- Bundle ID: `com.bilhealth.bodyintelligencelog`
- Version: iOS `1.0`
- Mode: authenticated App Store Connect API plus authenticated UI reconciliation, read-only
- Store mutation performed: **no**
- Build/upload/submission performed: **no**

## Version and app information

| Item | Live API result |
|---|---|
| Version state | `PREPARE_FOR_SUBMISSION` |
| Release | `MANUAL` |
| Copyright | `2026 KATHIM ALHIASSAH` |
| Uses IDFA | `false` |
| Build | **not attached** |
| Product-page screenshots | **0 screenshot sets** |
| App Review Information | **complete**: contact fields, required demo credentials, and review notes are present |
| Locale | `en-US` only; valid as the primary/fallback localization |
| Name | `Body Intelligence Log` |
| Subtitle | `Nutrition, Fitness & Progress` |
| Description | present |
| Keywords | present |
| Support URL | `https://www.bilhealth.com/support` |
| Marketing URL | `https://www.bilhealth.com/` |
| Privacy Policy URL | `https://www.bilhealth.com/privacy` |
| Privacy Choices URL | `https://www.bilhealth.com/account-deletion` |
| Primary category | `HEALTH_AND_FITNESS` |
| Secondary category | `LIFESTYLE` |
| App Store Server Notifications | production and sandbox URL present, version `V2` |
| Content rights | `USES_THIRD_PARTY_CONTENT` |
| App Store age rating | `SEVENTEEN_PLUS`; developer override is 18+ |

The live promotional text is correctly encoded and contains
`progress—without`. The API also returns the corrected app name above.

## App availability

- `175/175` territories are selected.
- `availableInNewTerritories=true`.
- App price point is the free tier (`10000`) in the USA base territory and its
  automatic equalizations.
- All 175 territory records currently contain `CANNOT_SELL`, consistent with an
  unreleased app.
- 27 EU territories additionally report `TRADER_STATUS_NOT_PROVIDED`; DSA
  trader verification is an owner/account blocker.

## Business, agreements, banking, and tax

Authenticated App Store Connect UI reconciliation confirmed:

- Free Apps Agreement: `Active` through 2027-08-24.
- Paid Apps Agreement: `Active` through 2027-08-24.
- USD bank account: `Active`.
- U.S. Certificate of Foreign Status of Beneficial Owner: `Active`.
- U.S. Form W-8BEN: `Active`.

The only visible Business warning is the DSA trader-compliance flow. It still
opens at the trader/non-trader selection step; no choice was resubmitted during
this audit because Apple support case `20000151571917` is already pending after
the phone-verification delivery failure.

Authenticated UI verification also confirms that Billing Grace Period is now
enabled for **Production and Sandbox**, lasts 16 days, and applies to all
renewals. Streamlined Purchasing remains enabled. No review or release action
was triggered by either setting.

## Subscription group and products

Subscription group `22343739` / `BIL Membership` exists and has an `en-US`
display localization. The live levels are AI Coach = 1 and Premium = 2.

| Product | Period | Level | Territories | Exact current/reference price | Live state |
|---|---|---:|---:|---|---|
| `bil_premium` | month | 2 | 4 | EGY 129.99 EGP; IND 249 INR; PAK 700 PKR; TUR 129.99 TRY | UI: `PREPARE_FOR_SUBMISSION`; API snapshot: `MISSING_METADATA` |
| `bil_premium_annual` | year | 2 | 4 | EGY 999.99 EGP; IND 1,999 INR; PAK 5,900 PKR; TUR 999.99 TRY | UI: `PREPARE_FOR_SUBMISSION`; API snapshot: `MISSING_METADATA` |
| `bil_premium_ai_coach` | month | 1 | 168 | USA reference 5.99 USD; Apple-equalized elsewhere | UI: `PREPARE_FOR_SUBMISSION`; API snapshot: `MISSING_METADATA` |
| `bil_premium_ai_coach_annual` | year | 1 | 168 | USA reference 49.99 USD; Apple-equalized elsewhere | UI: `PREPARE_FOR_SUBMISSION`; API snapshot: `MISSING_METADATA` |
| `bil_ai_boost` | consumable | — | 172 | USA reference 2.49 USD; Apple-equalized elsewhere | `READY_TO_SUBMIT` |

Every subscription has:

- one `en-US` display localization;
- one completed 1024×1024 subscription image;
- one completed 1170×2532 App Review screenshot;
- a review note;
- `UPFRONT` plan availability matching the intended 4/168 market split;
- a configured price schedule.

The consumable also has its localization, 172-market availability, price
schedule, review note and completed review screenshot.

Both the 06:19 UTC snapshot and a fresh 07:04 UTC API recheck return
`MISSING_METADATA` for all four subscriptions. No required child resource
exposed by the API is absent. An
authenticated UI reconciliation later the same morning showed all four rows as
`Prepare for Submission`; the group and each product expose an enabled
`Add for Review` button and no inline validation error. The AI Coach annual
detail additionally confirmed 168-territory availability, localization,
subscription image, review screenshot, and review notes. This is therefore a
stale/lagging derived API state, not evidence of a field that should be invented
or patched. No review button was pressed.

The final 16:24 UTC API recheck and authenticated UI reconciliation confirm
that the intended introductory offers are live on the two AI Coach products
only: `bil_premium_ai_coach` and `bil_premium_ai_coach_annual`. Each product has
168 territory-specific `FREE_TRIAL` records, duration `ONE_WEEK`, one period,
starting 2026-08-30 with no end date. The ordinary Premium products have zero
introductory offers and remain excluded from trial eligibility and trial-token
grants. Customer eligibility remains limited to one introductory offer per
subscription group. Official procedure:
<https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/>.

The API returns the correctly encoded display name
`BIL AI Boost 2,500 Tokens`.

## Exact blockers before v1.0 submission

1. Attach the final signed build.
2. Upload at least one valid product-page screenshot set for `en-US`.
3. Complete the DSA trader requirement for the 27 affected EU territories.
   Apple support case `20000151571917` remains pending and is an external
   account-verification blocker.
4. Complete build-dependent export-compliance processing after upload.
The seven-day introductory-offer requirement is complete for both AI Coach
products and is intentionally absent from ordinary Premium.

App Review Information and App Privacy are already complete. The subscription
UI states are reconciled and no longer treated as a submission blocker. The
final app version and subscription group must still be submitted together
because these are the first auto-renewable subscriptions; submission remains
intentionally deferred until the clean QA-approved build and screenshots exist.

## Evidence

Machine-readable snapshots are stored in
`artifacts/release/apple/2026-08-30-final-audit/`:

- `v1-metadata.json`
- `review.json`
- `app-availability.json`
- `catalog.json`
- `commerce.json`
- `selected-prices.json`

All public URLs returned HTTP 200 during this audit.

Official requirements:

- <https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties>
- <https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information>
- <https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/>
- <https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information>
