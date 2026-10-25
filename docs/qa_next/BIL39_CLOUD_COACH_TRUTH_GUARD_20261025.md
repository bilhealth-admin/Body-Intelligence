# BIL39 cloud Coach source completion — not deployed

Scope: CLOUD-COACH-01, CLOUD-COACH-02, CC-1009-01 through CC-1009-10.
Parent: PR15 at 5ba7fabe3b4fed130d21ac47e924d98503596d1f.
Protected iOS38 remains 155b079696430919f8272df934371f033fb11be2.

## Actual behavior

- A deterministic post-model guard examines both `reply` and `spoken_reply`
  against only the already authorized request's `weight.summary.recordCount`.
  A positive full-series summary survives an empty/truncated row sample.
- A false whole-diary absence claim is replaced with app-owned read-only copy.
  The copy reports only the confirmed count, explicitly describes its full-history
  scope, makes no missing-date measurements, and drops all provider proposals.
  This is not a general verifier of every possible numerical model claim.
- Only explicit `readStatus: verified` plus integer zero establishes empty data.
  Missing, denied, withheld, failed and timed-out reads remain unknown. Legacy
  positive summaries work; legacy zero is not proof of an empty diary.
- The correction uses no additional context, provider call, reservation, database
  operation, or raw user-data logging. Normal metering settles the original call
  once. Unsafe health/food advice and invented receipts still fail and refund.
- Fenced JSON and both AR/EN denial variants use the same guard. Structural voice
  length/Markdown and citation-classification checks still apply.
- Fixed PR15's native Deno type error by using its shared `CoachTurn` contract.
  Preserved the app-owned, read-only saved-plan review offered after an exact
  workout completion request; other unrequested plan proposals remain filtered.

## Verification and limits

Local native Deno, with type checking enabled:

`deno test --allow-env --allow-read --allow-net supabase/functions/ai-coach`

164 passed, 0 failed before this documentation commit. The suite includes the
full handler with synthetic Auth/consent/provider/metering boundaries, negative
advice, malformed replies, capability negotiation and credit reconciliation.
This is local handler evidence, not a paid live-Gemini or staging deployment.
See the exact-commit receipt in the central private BIL39 evidence register.

Read-only production inspection confirmed `ai-coach` version 131, function ID
8484c037-8c77-498f-a621-434a04224b91, bundle SHA256
29c96fa980f9d5ed4cb31807b778f45843166a5866e5aec828815052b426d917.
All 13 published source files were preserved privately with individual hashes.
No production setting, function, account, entitlement, price or data was changed.

The historical 6:50 screenshot cannot establish whether its client omitted
context or its provider ignored context. Both conditions have isolated tests;
the historical root cause remains UNRESOLVED, not retrospectively invented.

## Remaining release gates

Isolated cloud staging, a rollback rehearsal and approved live-provider evidence
remain BLOCKED. Any production deployment requires separate new owner approval.
Do not deploy this draft, merge it into iOS38/main, or infer Build39 readiness
from these source tests. App-side intent/context work and VIDEO-SOURCE-01 remain
separate tracked requirements. Rollback is the prior source ref; production
rollback must use the preserved published v131 bundle rather than assuming a
Git branch equals the published function.

Testing approach reference:
https://supabase.com/docs/guides/functions/unit-test
