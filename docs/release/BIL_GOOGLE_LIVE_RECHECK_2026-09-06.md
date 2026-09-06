# Google Play live recheck — 2026-09-06

## Scope and evidence window

This is an authenticated, read-only recheck of Google Play. The catalogue was
read at `2026-09-06T03:06:44.231Z`, the one-time-product offer was read again at
`2026-09-06T03:14:05.583Z`, and the transient release/listing read completed at
`2026-09-06T03:21:16.535Z`. An authenticated Play Console UI recheck of
Production, Publishing overview, releases, and all four approved subscription
base plans completed at `2026-09-06T06:41:31.164Z`. The temporary release edit
was deleted without a commit. No price, offer, date, listing, track or release
was changed; no build was produced, uploaded or submitted. After the owner gave
the explicit action-time instruction `نعم، أرسل الطلب الآن`, the separate
Production-access questionnaire was submitted once and its under-review state
was read back at `2026-09-06T07:23:29.300Z`.

## Live billing result

| Surface | Authenticated live state |
| --- | --- |
| AI Boost product | `bil_ai_boost` / `standard-2500`, active buy option |
| AI Boost base price | US `USD 4.99`; 173 regional configurations |
| AI Boost offer | `launch-50`, active in 173/173 regions |
| Boost offer timing | starts `2026-08-28T09:00:00Z`; no end time |
| Boost offer discount | user pays `0.5` of the purchase-option price (50% discount); US result rounds from USD 2.495 to the nearest billable unit |
| AI Premium monthly | `bil_premium_ai_coach/monthly`, active `P1M`, US `USD 5.99`; API returned 168 regional configurations and Console summarized 169 countries/regions |
| AI Premium monthly trial | `bil_premium_ai_coach/monthly/trial-7-day`, active in the Console's 169-country/region scope |
| AI Premium yearly | `bil_premium_ai_coach_annual/yearly`, active `P1Y`, US `USD 49.99`; API returned 168 regional configurations and Console summarized 169 countries/regions; Console notes one legacy price point |
| AI Premium yearly trial | `bil_premium_ai_coach_annual/yearly/trial-7-day`, active in the Console's 169-country/region scope |
| Annual saving in the US | `(5.99 × 12 - 49.99) / (5.99 × 12) = 30.45%`; a displayed rounded `Save 30%` is accurate for that same-currency pair |
| Erroneous sibling retained but inactive | `bil_premium_ai_coach_annual/annual`, inactive `P1M`, US `USD 35.99`; it was not changed |
| BIL Premium monthly | `bil_premium/monthly`, active monthly auto-renewing, exactly 4 countries: Egypt `EGP 99.99`, Nigeria `NGN 1,859.00`, Pakistan `PKR 599.00`, Türkiye `TRY 99.99` |
| BIL Premium yearly | `bil_premium_annual/annual`, active yearly auto-renewing, exactly the same 4 countries: Egypt `EGP 599.99`, Nigeria `NGN 11,159.00`, Pakistan `PKR 3,599.00`, Türkiye `TRY 599.99` |

Google defines `relativeDiscount` as the fraction of the purchase-option price
the user pays and rounds the result to the nearest billable unit. It also
documents discounted-offer start/end times and a batch-update operation, but it
does not state that a past start time on an active **discount** offer is mutable.
The Help statement that a passed start date cannot be modified appears under
**pre-orders**, so it must not be represented as a documented restriction on
discount offers. Testing a save would be a live mutation and was intentionally
not attempted.

## Literal user decision: 30% belongs to the annual subscription

The 250-entry user ledger was checked directly. The relevant entries are:

- **U219:** “شغل ايضا مدقق للاسعار وتاكد ان التطبيق يعرض 30% save والتاكد من ان جميع الاسعار في المتاجر صحيحه”
- **U223:** “هو يجعل المتجر 30 وليس 50 يعدل يعني ويعمل بوليش السعر ل ai premium 5.99 والسنوي المجموع يخصم منه 30 % والبريميوم العادي فعلا ل 4 دول”
- **U224:** “اذا تقدر تخليه 49.99 السنوي ممتاز والشهري 5.99”
- **U226:** “خليه يعدل التاريخ لا يكون غبي عاد مو كل نقطه لازم انا احكيله” — attached to the Google Play `BIL AI Boost - 2,500 tokens` / `launch-50` date screen.

**Decision:** the text is sufficiently explicit and does not require another
owner choice. The requested 30% is the saving for the AI Premium annual price
relative to monthly (`USD 49.99` versus `USD 5.99 × 12`). No literal user entry
asks to change the AI Boost discount from 50% to 30%. U226 separately requests
correction of the Boost offer date. Therefore there is no contradiction between
the annual 30% request and the Boost `launch-50` discount; the real outstanding
gap is that the live Boost start date remains 28 August 2026 despite U226.

Changing Boost itself to a 30% discount would produce about `USD 3.49` from a
`USD 4.99` base price, not the current approximately `USD 2.50` offer. That
change is neither implied by U223/U224 nor performed by this audit.

## Live releases and Production boundary

| Track/artifact | Authenticated live read-back |
| --- | --- |
| Production | Inactive; the Production-access application was submitted and is under Google review |
| Production prerequisites | all three shown completed: closed-testing release, at least 12 opted-in testers, and at least 12 testers for at least 14 days |
| Beta | no release |
| Internal | no release |
| Alpha | completed `7 (1.0.0)` plus an empty draft |
| Uploaded bundle version codes | `1, 2, 3, 4, 5, 7` |
| Uploaded build 8 | **No** |
| Publishing overview | Managed publishing is on; no changes are ready to publish; last publication shown as 5 Sept 2026 |

The Android Publisher API does not expose the account's current
production-access questionnaire/button state, so that portion was checked in
the authenticated Play Console UI. After submission, the Dashboard displayed
`We have your application for production access`, stated that Google is
reviewing the form and usually responds within seven days or less (occasionally
longer), and showed `Applied today, 10:22`. This is an application receipt, not
an approval or a rollout. Production remains inactive, build 7 must not be
promoted, and the absence of build 8 is independently confirmed by the live
bundle list.

## Live listing-image boundary

The `en-GB` listing currently returns one icon, one feature graphic, eight phone
screenshots, zero 7-inch screenshots and zero 10-inch screenshots. Their remote
hashes and order are unchanged from the 5 September audit. None is byte-identical
to the 19 current local files under `store_assets/screenshots/google_play`, but
Google may re-encode uploaded images, so hashes alone cannot prove a visual
mismatch. No remote image was downloaded or replaced. R-002 therefore cannot be
closed visually from this API read alone.

## Official Google references

- [One-time product offer resource and `relativeDiscount`](https://developers.google.com/android-publisher/api-ref/rest/v3/monetization.onetimeproducts.purchaseOptions.offers)
- [Create/update one-time product offers](https://developers.google.com/android-publisher/api-ref/rest/v3/monetization.onetimeproducts.purchaseOptions.offers/batchUpdate)
- [One-time products and discount-offer setup](https://support.google.com/googleplay/android-developer/answer/16430488?hl=en)
- [Production-access testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB)
- [List current track releases](https://developers.google.com/android-publisher/api-ref/rest/v3/applications.tracks.releases/list)

## Current decision

`GOOGLE_BUILD_8_UPLOADED=NO`

`GOOGLE_PRODUCTION_ELIGIBLE_TO_APPLY_UI_CONFIRMED_2026_09_06=YES`

`GOOGLE_PRODUCTION_APPLICATION_SUBMITTED=YES`

`GOOGLE_PRODUCTION_ACCESS_REVIEW_STATE=UNDER_REVIEW`

`GOOGLE_PRODUCTION_APPLICATION_SUBMITTED_AT_UTC=2026-09-06T07:23:29.300Z`

`GOOGLE_APPROVED_SUBSCRIPTION_BASE_PLANS_ACTIVE=YES`

`GOOGLE_MONETIZATION_ACTIVATION_REQUIRED=NO`

`GOOGLE_DEPRECATED_AI_ANNUAL_MONTHLY_DUPLICATE_REMAINS_INACTIVE=YES`

`AI_PREMIUM_US_SAVE_30_PERCENT=CONFIRMED`

`AI_BOOST_DISCOUNT_CHANGE_TO_30_PERCENT=NOT_REQUESTED`

`AI_BOOST_DATE_REQUEST=OPEN`
