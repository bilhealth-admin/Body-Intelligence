# BIL Secure Admin — Production handoff / 17 Oct 2026
This branch is isolated from Codex Flutter integration. **Do not merge into Flutter integration automatically**.

## Verified complete
- Replit BIL Admin V7 shown and verified by owner via screenshots (email OTP + Supabase TOTP AAL2, actual grant list and audit).
- Production Edge: `bil-admin-web-v1` v4 ACTIVE, using validated `backend_v4/server.mjs` & `policy.mjs`. **Entrypoint hard-sets financial write flag FALSE**. Service-role key stays exclusively inside Supabase Edge.
- Existing grant list corrected for PostgREST SQLSTATE 25006 (STABLE reader containing FOR SHARE); both reader functions VOLATILE with ACL unchanged.
- Existing 11 administrative grants (5 active) and 15 financial command receipts unchanged.
- Real production audit RPC service_role-only, actual command history now visible in Replit UI.
- Atomic one-time TOTP proof + cooldown wrapper installed in Production but service_role-only and unused. MFA receipt count zero.
- Code verified: `npm test` 97/97 and separate **real PostgreSQL 17 in ephemeral GitHub Actions** using synthetic identities. Workflow run https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39026760850 SUCCESS — grant, revoke, idempotency, time-window, cooldown, role security and denied open-ended grants.
- Security advisor check: no new anonymous/authenticated EXECUTE warning for web financial RPC.

## NOT YET AUTHORIZED TO GO LIVE
1. Read-only reconciliation RPC `bil_admin_web_reconcile_subscription_command` is **not deployed**. An attempted guarded creation was blocked by tool safety checks; no changes were made by that attempt.
2. Financial write flag is intentionally FALSE in deployed Edge v4. Admin website still correctly shows READ-ONLY, no grant/revoke supported.
3. Must independently validate reconciliation result and fail-closed behavior, then test full live end-to-end on an authorized isolated test identity (no real user entitlements).
4. Configure reliable HTTPS site hosting instead of depending on transient spock.replit.dev before long-term operations.
5. Only after grant/revoke + receipt-recovery E2E tests and owner cutover approval: update web Edge to enable writes and have Codex remove only the consumer Flutter financial administration entry/routes. Preserve app moderation and ensure old client endpoints remain secure and compatible.
6. Do not rotate, expose or move production service_role secrets to Replit; no copy/paste of user TOTP, access tokens, or app-store credentials.

## Current branch artifacts
- `tool/admin_web/backend_v4/server.mjs` & `policy.mjs` are exact locally unit-tested web admin handler/validators.
- `tool/admin_web/pg_it/` contains synthetic PG integration harness.
- `supabase/migrations/20261017095800_bil_admin_web_readonly_listing_volatility_fix.sql` records the deployed read fix.
- `supabase/migrations/20261017131000_bil_admin_web_readonly_audit_history.sql` records the deployed audit read RPC.

**Do not tell Codex to remove Flutter financial admin yet**; no working financial web cutover exists.
