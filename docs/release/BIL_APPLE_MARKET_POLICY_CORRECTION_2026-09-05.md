# BIL Apple market policy correction — 2026-09-05

## Result

The final owner policy is now aligned across App Store Connect, Google Play,
the canonical repository contract, and the production Supabase resolver:

- regular Premium: `EG`, `NG`, `PK`, and `TR` only;
- Premium + AI Coach: the other 168 launch markets;
- held or unknown markets: not for sale;
- total enabled launch markets: 172.

## Controlled App Store mutation

The current App Store Connect subscription-plan availability API was used.
Before mutation, all four subscriptions matched the reviewed legacy state
exactly: regular Premium included India instead of Nigeria, and both AI plans
included Nigeria instead of India. Each plan had exactly one `UPFRONT`
availability, automatic new-territory availability was disabled, and the price
schedule for the territory being added was verified as present and positive.

The double-gated tool
`tool/apple_store_connect/asc_subscription_market_sync.mjs` then performed one
market swap per product with immediate read-back and guarded rollback:

| Product | Added | Removed | Final count | Final exact read-back |
|---|---:|---:|---:|---:|
| `bil_premium` | `NGA` | `IND` | 4 | PASS |
| `bil_premium_annual` | `NGA` | `IND` | 4 | PASS |
| `bil_premium_ai_coach` | `IND` | `NGA` | 168 | PASS |
| `bil_premium_ai_coach_annual` | `IND` | `NGA` | 168 | PASS |

A second independent authenticated inspection returned `exact=true` for all
four products. The same inspection must still be repeated immediately before
the final release gate. No application build or version submission was
performed by this change.

## Production backend alignment

Forward migration
`supabase/migrations/20260905170000_owner_store_market_policy_nigeria_alignment.sql`
was applied without rewriting deployed migration history. Its transaction
contains count and routing invariants. The production read-back returned:

- enabled = 172;
- regular Premium = 4;
- Premium + AI Coach = 168;
- `EG`, `NG`, `PK`, `TR` -> `premium`;
- `IN` -> `premium_ai_coach`;
- `CN` -> `not_for_sale`.

## Verification

- `node --test tool/apple_store_connect/asc_catalog_sync.test.mjs
  tool/apple_store_connect/asc_subscription_market_sync.test.mjs`: 15/15 PASS.
- Canonical catalog dry-run: valid, 172/4/168, no errors.
- App Store precondition inspection: exact reviewed one-market drift on all
  four products.
- App Store post-mutation read-back: exact final sets on all four products.
- Independent second App Store inspection: `exact=true` on all four products.
- Supabase `db push --dry-run`: only the new forward migration selected.
- Supabase migration apply: PASS.
- Supabase production resolver/count query: PASS.

Independent source review also confirms the mutation tool is fail-closed:

- apply requires both `ASC_ALLOW_AVAILABILITY_MUTATION=YES` and the exact owner
  policy confirmation;
- each product must have exactly one `UPFRONT` availability, automatic new
  territories disabled, and either the exact final or exact reviewed legacy
  set;
- mixed final/legacy states are resumable and only legacy rows are changed;
- the added territory must already have a positive configured price;
- every PATCH has an immediate read-back, partial failure rolls every changed
  product back to its captured snapshot, and final read-back revalidates both
  exact sets and the automatic-territory flag; and
- public output contains only product IDs, counts, country diffs and booleans;
  it does not emit keys, reviewer data, subscription/availability identifiers,
  or credentials.

`APPLE_MARKET_SYNC_TOOL_CONTRACT: PASS`

The App Store mutation follows Apple's current subscription-plan availability
resources and replaces only the `availableTerritories` relationship. The older
`subscriptionAvailability` API is deprecated and is not used by the new tool.
