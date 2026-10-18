# BIL Secure Admin Web Operations — 18 October 2026

Independent web-only administration backend. No modifications to Flutter integration, main, store builds, or existing financial Edge.

- The financial endpoint remains `bil-admin-web-v1`, with its deployed entrypoint tracked in `backend_v4/index.ts`. The strict origin allowlist includes the independent Workers site and the previously explicit Replit origins.
- This additional endpoint is bil-admin-web-ops-v1. It uses the identical verified Supabase JWT + AAL2 + verified active SQL admin + owner allowlist + strict CORS policy, then a service-role client **only in the Edge runtime** for service-only administrative RPCs.
- Read operations: moderators, suspended users, pending posts, post snapshots, open reports and their content, AI Coach safety reports.
- Write operations: add/remove moderator, suspend/reinstate community member, global/individual AI Coach reset, notifications, post/report/safety decisions. Every write requires recent TOTP, exact confirmations, idempotency, and SQL-enforced authority.
- **The current runtime entrypoint enables BIL_ADMIN_OPS_WRITE_ENABLED for the verified allowlisted owner.** Server authority, AAL2, fresh TOTP, typed confirmations and SQL checks remain mandatory. A successful synthetic test or public HTTP smoke does not prove an authenticated live write; controlled E2E must use a dedicated test identity and audit readback, never unrelated real users.
- User-facing UI must show disabled pending status for operations whose end-to-end contract has not been verified. Never infer success from presence of a button.
- SQL values and service-role secrets never belong in the web client or GitHub. Read receipts only under authorized actor.
- Rollback: disable the new endpoint (set BIL_ADMIN_OPS_ENABLED=false) or redeploy a read-only version; leave the original financial Edge untouched.
- Deployment verification: check Edge ACTIVE, strict origins, unauthenticated rejected, forbidden origin denied, owner + fresh TOTP E2E in real browser, readback, audit, and preservation of current Flutter mobile routes until web cutover.
