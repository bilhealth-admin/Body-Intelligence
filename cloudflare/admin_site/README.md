# BIL Secure Administration — isolated browser frontend

Independent public assets protected by server-enforced Supabase Auth and admin policies. The static site has no privileged secrets and does not touch Flutter applications.

- Owner login: email OTP + Supabase TOTP AAL2, checked again inside Supabase Edge.
- Financial operations: `bil-admin-web-v1`, grants/revokes/receipts. Only operate against the real server with owner-confirmed inputs and recent TOTP. Never use real users as test fixtures.
- Moderation and operational modules: `bil-admin-web-ops-v1`; reads are available to the verified owner. Writes are **server-side locked** (`BIL_ADMIN_OPS_WRITE_ENABLED=false`) pending authorized, controlled E2E testing on a dedicated test identity.
- Client does not store a service-role token, does not call privileged SQL directly, does not cache admin responses persistently or fake counts.
- Cloudflare Workers asset site is independent of `bilhealth.com` public product website, and cannot overwrite the existing production worker.
- The published Workers hostname must be added as an **exact HTTPS origin** in both admin Edge functions. Never use `*` or allow all origins.
- To enable email magic-link callback (if used by the site's current Supabase Auth template), the owner must approve the exact new redirect host in Auth redirect allowlist, separately; email numeric OTP can be verified through `verifyOtp`.
- Rollback: disable the new Worker, remove its origin from Edge, or point the custom hostname back. Avoid changing live grant and audit ledger.
- Test gate: `npm run check`, `npm run build`, GitHub Actions UI static checks and deployment HTTP smoke, then owner login and real-browser read-only verification. Do not declare grant/revoke E2E passed until witnessed and audited.