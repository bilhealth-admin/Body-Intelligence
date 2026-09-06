# Supabase production deployment — 2026-09-04

Completed at `2026-09-04T05:22:36Z` against the explicitly linked BIL
production project. This record intentionally contains no API keys, database
passwords, access tokens, or secret digests.

## Target preflight

- Project ref: `tgmanzhqulksykhslrzb`
- Project name: `body-intelligence-log`
- Region/status: `eu-west-1` / `ACTIVE_HEALTHY`
- Supabase CLI: `2.116.0`
- The repository link, compiled app default URL, release workflows, public
  site, and Cloudflare worker all identify the same project ref.
- Preflight found exactly two local-only migrations and three modified Edge
  functions with older active remote versions.

Read-only preflight commands:

```powershell
npx --yes supabase@latest projects list --output json
npx --yes supabase@latest migration list --linked
npx --yes supabase@latest functions list --project-ref tgmanzhqulksykhslrzb --output json
```

## Database migration

The dry run named only these migrations:

- `20260904010000_ai_coach_reset_token_grants.sql`
- `20260904020000_register_google_store_products.sql`

Commands:

```powershell
npx --yes supabase@latest db push --linked --dry-run
npx --yes supabase@latest db push --linked --yes
```

Both applied successfully. A new `migration list --linked` returned zero
local/remote mismatches. No database reset, seed replacement, destructive
schema command, or data wipe was run.

Post-deployment read-only SQL checks confirmed:

- reset-grant table and trigger exist;
- RLS is enabled and table reads are revoked from `anon` and `authenticated`;
- the three message-aware admin RPC overloads exist;
- reset RPC execution is allowed to `service_role` and denied to `anon`;
- existing grant rows use exactly 2,500 tokens and have no orphan reset notice;
- all four canonical Google products are enabled with the correct package,
  plan, and monthly/annual term.

## Edge Functions

Commands:

```powershell
npx --yes supabase@latest functions deploy ai-coach --project-ref tgmanzhqulksykhslrzb --no-verify-jwt
npx --yes supabase@latest functions deploy ai-coach-global-reset --project-ref tgmanzhqulksykhslrzb
npx --yes supabase@latest functions deploy barcode-lookup --project-ref tgmanzhqulksykhslrzb --no-verify-jwt
npx --yes supabase@latest functions deploy food-search --project-ref tgmanzhqulksykhslrzb --no-verify-jwt
```

`food-search` was added after the complete local/remote inventory proved that
the Flutter client calls it and that it was the only local function missing
from production. The final active versions are:

| Function | Version | JWT gateway |
|---|---:|---:|
| `ai-coach` | 40 | disabled; handler validates the session |
| `ai-coach-global-reset` | 4 | enabled |
| `barcode-lookup` | 19 | disabled; handler validates the session |
| `food-search` | 1 | disabled; handler validates the session |

All nine local function directories now exist remotely. The sole remote-only
function is `reviewer-password-bootstrap`; it was left untouched because it is
an established reviewer operation and has no local deployment source in this
change set.

The CLI printed a local Docker warning while bundling, but every remote deploy
returned `Deployed Functions`, and the subsequent API inventory showed all
four functions as `ACTIVE` at the versions above.

## Verification

- Unauthenticated POST smoke checks reached all four deployed endpoints and
  were rejected with HTTP 401 at the intended authentication boundary.
- Barcode production E2E: a temporary account was denied as free (403), then
  accepted after a temporary Premium entitlement (200); cleanup succeeded.
- The tester barcode `6223000350027` currently resolves from Open Food Facts
  with energy `34.5 kcal/100 g`, protein `3 g`, carbohydrate `4.5 g`, fat
  `0.5 g`, and serving quantity `200 g`.
- AI Coach production E2E: one Gemini attempt, provider latency 5,589 ms,
  correct 7 kg calculation, successful metering/feedback, duplicate request
  rejected with 409, and session/user/database cascade cleanup all succeeded.
- Focused local Deno tests: 39/39 for AI/reset/GTIN plus 4/4 for food search.
- The AI live-test PowerShell helper was repaired to pipe SQL through stdin and
  call `db query --linked --project-ref`, which is required by CLI 2.116 on
  Windows. Two failed harness attempts left zero ephemeral users before the
  successful rerun.

## Remaining external configuration

`BIL_GEMINI_API_KEY` and the automatic Supabase runtime secrets are present.
`BIL_USDA_API_KEY` is not present in the Supabase secret inventory or local
environment files. Consequently:

- barcode lookup remains operational through Open Food Facts, but its USDA
  exact-GTIN fallback is unavailable;
- the newly deployed `food-search` function correctly fails closed with 503
  after authentication until a real USDA FoodData Central production key is
  supplied.

A production USDA key must be obtained from its owner account and installed as
`BIL_USDA_API_KEY`; no demo key or fabricated credential was installed.

No Flutter app build, store upload, or unrelated external deployment was
performed in this operation.
