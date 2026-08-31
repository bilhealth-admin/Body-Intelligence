# BIL App Store Connect catalog package — 2026-08-29

## Canonical pricing outcome

The active source is
`tool/apple_store_connect/canonical_store_pricing_2026-08-29.json`. It
supersedes the 2026-08-28 MyFitnessPal research matrices for active pricing;
those files remain immutable research evidence only.

- Customer-facing price and currency always come from StoreKit/App Store
  metadata. Flutter contains no fallback or fixed monetary price.
- The annual comparison is computed at runtime from each storefront's monthly
  price multiplied by 12 versus its annual price; the rounded saving percentage
  is displayed only when both matching store offers are available.
- Apple local prices are Apple-equalized from the documented US reference
  point. The repository does not invent per-country prices.

Dry-run validation: **PASS (5/5 tests)**.

## Current app and group

- App Store Connect app ID: `6805349703`
- Bundle ID: `com.bilhealth.bodyintelligencelog`
- Subscription group: `BIL Membership`
- Subscription group ID: `22343739`
- Standard subscriptions use `UPFRONT`.

## Product, market, and reference-price contract

| Product ID | ASC ID | Period | Group level | Availability | Business target | Apple reference |
|---|---:|---|---:|---|---:|---:|
| `bil_premium` | `6806555342` | 1 month | 2 | EG/IN/PK/TR | USD 2.50 equivalent | USD 2.49 |
| `bil_premium_annual` | `6806555198` | 1 year | 2 | EG/IN/PK/TR | USD 21.00 equivalent | USD 21.00 |
| `bil_premium_ai_coach` | `6806555282` | 1 month | 1 | remaining 168 launch markets | USD 5.99 | USD 5.99 |
| `bil_premium_ai_coach_annual` | `6806555344` | 1 year | 1 | remaining 168 launch markets | USD 49.99 | USD 49.99 |
| `bil_ai_boost` | resolved live in ASC | consumable | — | all 172 launch markets | USD 2.50 | USD 2.49 |

Apple does not expose an exact USD 2.50 point for the relevant products. The
approved Apple reference is therefore the closest supported point not above
the target: USD 2.49. This does not create a Flutter price; StoreKit still
returns the localized amount shown to the customer.

The four low-cost Premium markets are exactly Egypt, India, Pakistan, and
Türkiye. Nigeria belongs to the 168-market Premium + AI Coach set. BY/CN/RU
remain held and are not in launch availability.

## Runtime authority

The later migration
`supabase/migrations/20260829233000_canonical_store_market_pricing_policy.sql`
supersedes the older market assignment without rewriting migration history. It
fails closed for unknown/held storefronts and accepts both ISO-2 and ISO-3
storefront codes.

Immutable cross-store product IDs remain in
`lib/features/commerce/domain/store_catalog_configuration.dart`. The active
store remains the only price, currency, availability, offer, and eligibility
authority.

## Trial boundary

- Decision: `BOTH_AI_PRODUCTS_NO_PREMIUM_TRIAL`.
- Both `bil_premium_ai_coach` and `bil_premium_ai_coach_annual` are eligible
  for the seven-day Premium + AI Coach trial with 1,000 AI tokens.
- `bil_premium` and `bil_premium_annual` remain valid paid subscriptions but
  are not eligible for the AI trial or its token allowance.
- This package and its dry-run tool are declarative: they do not create an
  introductory offer. Store-side offers remain a separate explicit action.
- Store eligibility remains authoritative whenever the offer is configured.

## Tooling and generated evidence

```powershell
node --test tool/apple_store_connect/asc_catalog_sync.test.mjs
node tool/apple_store_connect/asc_catalog_sync.mjs --dry-run
```

- Policy manifest: `tool/apple_store_connect/apple_catalog_policy.json`
- Canonical pricing: `tool/apple_store_connect/canonical_store_pricing_2026-08-29.json`
- Safe sync/inspection utility: `tool/apple_store_connect/asc_catalog_sync.mjs`
- Tests: `tool/apple_store_connect/asc_catalog_sync.test.mjs`
- Compact dry-run: `artifacts/pricing/BIL_APPLE_CATALOG_DRY_RUN_2026-08-29.json`
- Complete territory plan: `artifacts/pricing/BIL_APPLE_CATALOG_FULL_PLAN_2026-08-29.json`

The utility defaults to dry-run. It does not publish, submit a version, or
invent local prices. Live modes still require explicit credentials and the
existing mutation gate.
