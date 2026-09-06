# BIL +8 deployed backend parity audit — 2026-09-06

## Verdict

The production Supabase project has every Edge Function, migration, database
object, and non-secret configuration name needed by the protected client paths
compiled into signed build `1.0.0+8`. No Supabase deployment is required before
building `+8` for AI Coach requests/actions, owner/admin reset and community
access administration, App Attest/Play Integrity grant creation, store receipt
verification, AI Boost crediting, Apple token custody, account deletion, or
barcode lookup.

This is a deployed-source/configuration finding, not a signed-device integrity
claim. Mobile-integrity enforcement remains intentionally off until the signed
App Attest and Play-installed canaries pass. The workflow evidence binding does
not replace those canaries.

One production function is deliberately excluded from that PASS:
`community-push-dispatch` v5 does not match the current safer local source.
Both signed `+8` workflows compile `BIL_PUSH_ENABLED=false` and
`BIL_PUSH_PROVIDER_READY=false`, and the production secret-name inventory has
no APNs/FCM gateway configuration. Therefore build `+8` neither calls nor
claims remote push delivery. Remote push must not be enabled until the current
dispatcher is separately reviewed/deployed and the real provider configuration
is present.

No function, migration, secret, database row, store setting, or release was
mutated during this audit.

## Fresh production read-back

`supabase functions list` returned these relevant functions as `ACTIVE`:

| Function | Version | JWT gateway | Updated UTC |
|---|---:|---:|---|
| `ai-coach` | 44 | handler-owned | 2026-09-05 09:08:25 |
| `verify-store-purchase` | 22 | handler-owned | 2026-09-05 09:08:25 |
| `play-integrity` | 18 | required | 2026-09-05 09:08:25 |
| `app-attest` | 2 | required | 2026-09-05 15:14:03 |
| `account-data-deletion` | 13 | required | 2026-09-05 16:17:10 |
| `apple-sign-in-notifications` | 2 | handler-owned S2S | 2026-09-05 17:01:37 |
| `apple-sign-in-token` | 2 | required | 2026-09-05 17:10:47 |
| `ai-coach-global-reset` | 10 | required | 2026-09-05 17:32:17 |
| `barcode-lookup` | 22 | handler-owned | 2026-09-04 04:51:41 |
| `analyze-meal` | 52 | required | 2026-08-21 17:50:15 |
| `food-search` | 4 | handler-owned | 2026-09-04 05:10:48 |
| `community-push-dispatch` | 5 | internal-secret handler | 2026-08-31 19:29:30 |

The production download API was used read-only for each relevant function.
SHA-256 comparison of every downloaded source file against the current local
file produced **30/31 exact matches** across the downloaded bundles. The one
mismatch was `community-push-dispatch/index.ts`. The 30 matches include every
file used by the protected `+8` calls, plus the two remaining client-facing
nutrition endpoints:

- `ai-coach/{index.ts,server.ts,deno.json}` plus `_shared/bcp47.ts` and
  `_shared/mobile_integrity.ts`;
- `ai-coach-global-reset/{index.ts,server.ts}` plus the same integrity guard;
- all six `verify-store-purchase` implementation files plus the integrity
  guard;
- `play-integrity/index.ts` and `app-attest/index.ts`;
- `account-data-deletion/index.ts` plus its three shared workers;
- `apple-sign-in-token/index.ts` and
  `apple-sign-in-notifications/index.ts` plus the shared Apple token lifecycle;
  and
- `barcode-lookup/index.ts` plus `_shared/gtin.ts`.
- all six `analyze-meal` source/provider files; and
- `food-search/index.ts`.

The local files `community-push-dispatch/index.ts` and
`community_push_dispatch.ts` are identical to each other (SHA-256
`896A2DDB5B297BAA7DD5F2CF44733756DA9AAF772D25F3B413AB6EA0412915CF`),
but production contains the earlier dispatcher source (downloaded SHA-256
`16E07BC6348820F236766028E7B4C338F8F06879B0861BCC294A15ABF2065513`).
The current source adds per-device leasing/idempotency, bounded provider
timeouts, strict HTTPS gateway validation, and safer preview/token-failure
handling. That delta is real and unpublished; it is not on the `+8` runtime
path while the two push build gates remain false.

## All 36 local Supabase status entries

`git status --porcelain=v1 -uall -- supabase` contains 36 leaf entries. They
resolve as follows:

- **12 deployed runtime files:** exact byte matches with the current production
  downloads listed above.
- **2 push-dispatch source mirrors:** current local source is not yet deployed;
  excluded from `+8` by the false/false push gates.
- **10 migrations:** `supabase migration list --linked` shows every local
  version through `20260905170000` on both the local and remote sides. There is
  no local-only migration.
- **11 test files:** source verification only; they are not Edge Function
  runtime inputs.
- **1 `deno.lock`:** local dependency-lock evidence; it is not a missing remote
  function endpoint. Exact production source was assessed from the downloaded
  function bundles instead.

## Database boundary read-back

Read-only SQL through the linked Management API confirmed the three mobile
integrity tables, the reset-token-grant table, the store registry,
subscriptions, and notification inbox exist. It also confirmed the exact RPCs
needed by the current deployed handlers exist with the intended boundary:

- `bil_consume_mobile_integrity_grant(uuid,uuid,text,text)` is executable by
  `service_role`, not `authenticated`;
- current three-argument global reset and five-argument individual reset RPCs
  are service-role executable, while their historical overloads are not;
- notification, moderator, suspension/reinstatement, receipt persistence,
  AI Boost credit, and store-notification claim RPCs are service-role-only;
- `bil_can_manage_ai_coach()` and the bounded rate-limit RPC remain available
  to authenticated callers as required by the handlers; and
- the push lease/record/finalize tables and RPCs from migration
  `20260904040000` are already present, although production dispatcher v5 does
  not yet consume them.

The production store registry read-back contains the enabled Apple and Google
monthly/annual products for both `premium` and `premium_ai_coach`, all bound to
`com.bilhealth.bodyintelligencelog`. Boost verification uses its separate
idempotent credit RPC and canonical `bil_ai_boost` identifier.

## Configuration-name read-back

The production secret inventory was read without printing values or digests.
All required names used by the exact deployed integrity and commerce sources
are present:

- App Attest: `BIL_APP_ATTEST_APP_ID`,
  `BIL_APP_ATTEST_ENVIRONMENTS`, and
  `BIL_APP_ATTEST_BUNDLE_VERSIONS`;
- Play Integrity: `BIL_PLAY_INTEGRITY_PACKAGE_NAME` and
  `BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON`;
- rollout: `BIL_MOBILE_INTEGRITY_ENFORCEMENT`;
- Apple receipt verification: `APPLE_BUNDLE_ID`, `APPLE_ISSUER_ID`,
  `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, and `APPLE_ROOT_CA_SHA256`;
- Google receipt/RTDN verification: `GOOGLE_PLAY_PACKAGE_NAME`,
  `GOOGLE_PUBSUB_AUDIENCE`, and `GOOGLE_PUBSUB_SERVICE_ACCOUNT`;
- reconciliation: `BIL_RECONCILIATION_SECRET`; and
- the automatic Supabase URL/anon/service-role bindings.

For the non-secret release settings whose exact values matter, the management
API returns a one-way SHA-256 value. The audit compared it in memory with the
SHA-256 of the expected setting and printed only `MATCH`; it did not print the
stored value or digest. All of these exact comparisons passed:

- `BIL_APP_ATTEST_BUNDLE_VERSIONS` is exactly `8`;
- `BIL_APP_ATTEST_ENVIRONMENTS` is exactly `production`;
- `BIL_MOBILE_INTEGRITY_ENFORCEMENT` is exactly `off`;
- the App Store, Google receipt, and Play Integrity package/bundle names are
  exactly `com.bilhealth.bodyintelligencelog`; and
- the backend Play Integrity project-number binding matches the authenticated
  Play-linked project recorded by the release audit.

The App Attest App-ID secret is present, and the same-day signed-profile audit
records its exact App ID as successfully checked without disclosing its prefix.
This read-only pass does not try to brute-force or expose that secret from its
one-way digest; the signed `+8` App Attest canary remains authoritative.

`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` is not separately present. This is not a
missing receipt-verification input: the exact deployed source explicitly falls
back to `BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON`, which is present. Optional
Gemini cost-rate and alternate text-endpoint overrides are absent and have
explicit source defaults; they do not disable Coach.

The same-day authenticated release evidence records the GitHub secret
`BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID` and repository variable
`BIL_PLAY_INTEGRITY_PROJECT_NUMBER` as present. The release ID is an immutable
workflow evidence label, not a value consumed by the Edge Function guard and
not a cryptographic proof of deployment. The current audit instead proves the
actual deployed source/migrations/configuration separately.

## Remaining acceptance boundary

Before changing server enforcement from `off` to `enforce`, run the signed
`+8` App Attest and Play-installed canaries for registration/assertion or token
decode, action and payload binding, expiry, replay rejection, reinstall/key
loss, and verifier outage. Do not enable remote push in this candidate. If push
is scheduled for a later candidate, deploy and read back the current dispatcher
and configure its internal/APNs/FCM gateway names first.
