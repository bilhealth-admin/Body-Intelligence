# Roadmap and activation blockers

## Product Excellence program status

- Branch: `phase-3-product-excellence`
- Reconciled baseline: `7071621`
- Phase 3 Product Excellence: **complete**, subject to the Phase 3 Ledger Reconciliation package full verification and Product Owner commit.
- Epics 1–8: **complete** in `docs/phase_3_execution_ledger.md`.
- No stale ledger item authorizes reimplementation of accepted production behavior.
- The remaining items below are activation/release blockers, not unfinished Phase 3 production Epics.

The offline/local product is the active implementation. The following
capabilities require external infrastructure and must remain disabled until the
whole activation checklist is satisfied:

- Account/auth: owned Supabase project, approved redirect URLs, email delivery,
  secure token storage, verification/reset flows, session/device testing, RLS.
- Cloud sync: audited schema, per-table RLS, outbox/inbox worker, conflict and
  tombstone integration tests, selective-sync consent, backup/restore drills.
- AI assistant: server-side provider key, consent, redaction, rate/cost limits,
  abuse policy, deterministic-tool boundary, write confirmation, deletion and
  export.
- Coach/community/shared challenges: verified identities, membership RLS,
  consent/revocation, block/report/moderation, retention and deletion policies.
- Commerce: store products, server-side receipt verification, entitlement
  service, restore/grace/refund behavior, and current regional store-policy
  review.
- Remote update/admin operations: authenticated signed configuration, rollout
  and rollback controls, minimum-version policy, platform store/download links,
  maintenance and safe-export paths.

Credentials alone are not sufficient. A capability becomes available only
after its adapter, authorization rules, failure behavior, tests, privacy text,
and production monitoring are verified. Service-role keys and administrator,
payment, signing, or AI secrets must never be placed in the Flutter client.

Release identity is also pending: Android and Apple projects retain example
bundle identifiers, and Android release-mode development artifacts currently
use debug signing. Owned identifiers, external signing credentials, store
records, and physical-device release testing are required before publication.
