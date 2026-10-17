# BIL Secure Administration — Supabase Edge origin fix V6 (2026-10-17)

## Incident
User's Replit preview at approximately 14:46 Egypt time showed STAGING · LOCKED after successful TOTP. Supabase auth logs showed successful TOTP POST 200, while the new BIL admin Edge Function received no status request in the relevant interval.

Root-cause code inspection of deployed Edge V5 found:
- `BIL_ADMIN_WEB_ALLOWED_ORIGINS` returned only `https://583f1411-1db3-49c7-805d-a98a45079dc6-00-jw3rzv8h1494.spock.replit.dev`.
- `policy.mjs exactOrigins()` explicitly rejected every explicit non-443 port, including Replit's external `:3000`.
- Replit Dev UI may be served under either exact origin, depending on which web preview it opens.

## Deployed solution
Supabase project: `tgmanzhqulksykhslrzb`. Function: `bil-admin-web-v1`. **V6 ACTIVE**.
- Index configuration allows precisely the **base URL** and its **:3000** variant.
- `exactOrigins` accepts `:3000` **only for that exact single Replit hostname**; unrelated hosts, HTTP, and other ports remain rejected.
- No changes to grants, revokes, rate limits, TOTP checks, JWT check, command idempotency, audit, or financial SQL.
- Files `server.mjs` remained byte-for-byte unchanged from V5.
- Local origin preflight simulations: both allowed origins return 204, unauthenticated POST rejected 401, unrelated origin rejected 403 without reflected CORS allow-origin.
- Existing backend unit suite: **57/57 PASS** in a copy of the backend with the patched policy and original migrations.
- Post-deploy readback V6 ACTIVE and verified two-origin config. Production records: 11 grants, 15 commands, 0 new web step-up receipts.
- Real browser result after deployment is **pending**; do not claim success before user confirms.

## Security / next action
Ask owner to use **Recheck access** once (not rebuild/re-enroll), expecting FINANCE · ACTIVE if existing session is still valid. Do not test financial grants on actual users. Publish on a permanent HTTPS host and replace temporary dev origin allowlist before operational cutover. Do not remove Flutter controls until browser issuance and revocation are end-to-end verified on a safe account.
