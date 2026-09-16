# Apple refund and seven-day trial audit — 2026-09-16

## Scope and release verdict

Source: `cb389ebf4659eca1e946e5f850e61e429c8ec097` in the isolated build18 worktree.
Verdict: **NOT READY for refund lifecycle sign-off**. This is an audit, not a fix or deployment.

No real purchase, refund, cancellation, entitlement edit, account deletion, app build,
commit, or deployment was performed. The earlier account's Sandbox grant was not changed.
Browser access timed out twice; current live SQL definitions, notification delivery,
App Store offer configuration, and scheduled reconciliation were not verified this turn.

## Executed checks

- Deno **2.1.4**: **49 passed, 0 failed** across `apple_refund_trial_matrix_test.ts`
  (20 new cases), `apple_subscription_lifecycle_test.ts`,
  `apple_subscription_selection_test.ts`, `store_ownership_persistence_test.ts`,
  and `store_persistence_payload_test.ts`.
- Flutter: **65 passed, 0 failed** across subscription lifecycle, entitlement
  resolution, session continuity, recovery, surface contracts, store entitlement
  truth, AI credit access, Apple offer metadata, catalog adapter, AI trial product
  scope, and workout access policy tests.
- Real local PostgreSQL via in-memory PGlite: **2 checks passed, 1 failed** in
  `supabase/tests/apple_notification_retry_test.mjs`. It loads the actual latest
  repository migration definition, not a copied implementation.
- Stopped test execution after the failing PostgreSQL group. No full-suite run.

Initial sandbox-restricted Flutter execution was stopped before results; Deno
encountered a Windows pipe-permission crash. Successful runs above used the
permitted local tool execution. These infrastructure attempts are not app failures.
The new Deno matrix uses synthetic verified-payload fixtures and mocked persistence;
it does not execute Apple notifications, verify their delivery, or prove live SQL.

## Scenario results

| Scenario | Local finding |
| --- | --- |
| Premium monthly/annual | Canonical paid products; not classified as AI free trials |
| Premium AI Coach monthly/annual | Exact seven-day signed free-trial window recognized |
| Disable renewal on trial days 1, 3, or 6 | Trial lifecycle and original expiry preserved; no extension |
| Exactly day 7, or after | Trial becomes expired in backend lifecycle and Dart resolver |
| Revocation before future expiry | Terminal; paid access denied by resolver |
| Request/decline refund | Not equivalent to an approved refund; canonical lifecycle retained |
| Approved refund event | Terminal mapping exists, but delivery retry and ordering defects block sign-off |
| Repeat notification after processing error | **FAILED**: actual SQL returns false instead of allowing retry |

The matrix does not prove that trial cancellation or monetary billing occurred on
Apple's servers. The authoritative Apple expiry must drive access; the client
does not decide whether Apple charges the customer.

## Findings requiring repair

### P1: Failed Apple notification cannot retry

`202608040004_bil_store_entitlement_truth.sql:72` claims a notification by inserting
its UUID with `ON CONFLICT DO NOTHING`. After processing sets `status='error'`, a
redelivery still returns false. `store_backend.ts:1129` acknowledges it as duplicate.
The test reproduced exactly `false !== true`. The claim RPC error is also ignored
by the handler. A missed refund can leave access until some other successful
verification removes it. Do not promise scheduled catch-up without evidence.

Repair must distinguish processed duplicates from retryable errors, handle claim
failures as failures, and protect concurrent workers using an atomic claim/lease.

### P1: Old notification can deactivate a newer renewal

`store_backend.ts:1137` retrieves the latest transaction in the same subscription
chain, then `:1174–1186` unconditionally applies an old REFUND/REVOKE/EXPIRED/failure
notification's lifecycle to that latest transaction. Reconciliation validates
chain/bundle/environment but intentionally permits different transaction IDs.
Source-proven control-flow risk; no signed live notification was replayed.

Repair must scope terminal events to the affected transaction and preserve newer
authoritative status. Add reordered-event and refund-reversal regressions.

### P1: Boost refund credit reversal is missing

Apple notifications always use the subscriptions endpoint, including consumable
Boost. No matching Boost refund/debit path was found. Credited tokens therefore
have no implemented refund reversal. Repair needs idempotency, owner validation,
and an explicit policy for already spent/reserved tokens; do not delete ledger rows.

### P2: UI does not uniformly re-lock at the boundary

The provider refreshes on a 30-second interval. An already opened recipe detail
sheet does not observe subsequent entitlement changes. Workout access policy
allows equality at expiry (`!now.isAfter`), unlike the strict entitlement resolver.
These relevant UI paths were also present in frozen build18 (`d7fb5e5`).
Mounted-view expiry/refund tests are still required, especially for recipe sheets.

### Other limitations

- Sandbox accelerated introductory trials may be classified as active because
  trial detection requires exactly seven days; expiry is still bounded.
- Reconciliation reads at most 500 subscriptions without pagination. No scheduled
  invocation was established by this audit.
- CONSUMPTION_REQUEST has no consumption-data response implementation. Adding one
  must respect user consent; never automatically transmit consumption history.
- Separately purchased Boost credits or administrative grants can legitimately
  retain some access after a subscription ends. Exclude these when testing refund
  acceptance; do not treat them as evidence of a free subscription.
- Cancellation should remain `trial` plus auto-renew disabled during a free trial.
  A separate conditional SQL risk exists if another path persists it as `cancelled`:
  the AI mirror may classify it as paid active. Not reproduced for the Apple path.

## Reproduce the failing SQL regression

From this worktree, after installing the pinned test dependency:

```powershell
npm ci --prefix supabase/tests --ignore-scripts --no-audit --no-fund
node supabase/tests/apple_notification_retry_test.mjs
```

Expected repair target: all three checks pass. Present result: first delivery and
processed duplicate pass; retry after error fails. No network or persistent
database is used by the regression itself.

## Apple references

- [Notification types](https://developer.apple.com/documentation/appstoreservernotifications/notificationtype)
- [Responding to notifications](https://developer.apple.com/documentation/AppStoreServerNotifications/responding-to-app-store-server-notifications)
- [Canceling a trial: at least 24 hours before its end](https://support.apple.com/en-us/118428)

## Next acceptance gate

Repair the server retry/order/Boost paths, add reactive UI expiry coverage, rerun
these focused checks from the beginning, then verify signed Sandbox notification
delivery and TestFlight behavior. Do not mark refund handling production-ready
from unit-test success alone.
