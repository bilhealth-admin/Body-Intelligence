# BIL Secure Administration — final operator release, 18 October 2026

## Independent site
- Production URL: https://bilhealth-secure-admin.bilhealth-app.workers.dev/
- Isolated Git branch: `feat/bil-secure-admin-ops-20261018` — NEVER merge into Flutter/main as a side effect.
- Cloudflare Worker: `bilhealth-secure-admin`, not the main BIL public site.
- Supabase Project `tgmanzhqulksykhslrzb`.

## What changed
1. **Operator-style dashboard:** live (not fake) post, Earn, report, grant, moderator and suspended-user counts; deep links to relevant modules. No public data without MFA.
2. **Subscriptions:** real account email, plan, expiration, status, expandable/copyable grant ID, current-page search, idempotent grant/revoke/receipt recovery. Distinct from store payments.
3. **Financial audit:** additively introduced `bil_admin_web_list_subscription_commands_v2`; owner/service-role-only read of actual command actor email, recipient email (by existing grant), plan, expiration, reason and receipt. No table privileges opened to authenticated/anon. Existing V1 command untouched.
4. **Owner Ops:** existing Supabase Edge `bil-admin-web-ops-v1` guarded AAL2 + fresh TOTP + owner allowlist + SQL-admin check + per-command confirmations/idempotency. Tested all operation paths before enabling the write feature. A separate typed `GRANT 2500 AI TOKENS TO ALL USERS` confirmation is REQUIRED before broadcasting a token-affecting gift/compensation, on top of `SEND TO ALL`, checkbox, native summary, MFA.
5. **Moderation/Earn:** continue using independent reviewed backend `bil-admin-web-review-v1` V3, signed temporary private media, full post title/body/gallery/author, revision-checked approve/reject and Earn token receipt, no silent grant repetition.
6. **Community members:** suspend/reinstate community access only; not delete account or subscription. Moderator add/remove cannot override protected admins.
7. **AI Coach:** individual/global reset of current usage allowances as specified by existing SQL, without revoking store purchases or deleting chats; global typed confirmation and MFA. No action performed in tests.
8. **Notifications:** custom text vs gift/compensation (configured 2,500 AI tokens per recipient), exact audience and message preview, strong mass confirmation. Receipt confirms queueing, NOT mobile Push delivery.
9. **Responsive design:** dense and legible 9-module UI, full IDs available to view and copy, side drawer dismisses via backdrop/tap outside/X/Escape/navigation, Arabic RTL and English LTR, iPhone small view.

## Security and testing
- Service-role key remains in Supabase Edge only; website holds only public Supabase key.
- Backend authorizes each read/write, not just CSS flags; CORS exact Cloudflare site, no wildcards.
- Every mutation requires a fresh TOTP and a meaningful confirmation with the recipient or global effect. SQL retains idempotent receipts.
- GitHub CI runs site tests, review tests, ops tests, audit validation, build, deploy, live CORS and unauthenticated 401, forbidden 403.
- Synthetic Playwright checks 320/375/390/430/768/1280 responsive views, sidebar, 9 modules, 4 moderation queues, private images with a mocked signed URL, cross-form actions and signed receipts; no production writes.
- Production owner live full action tests require a real owner session and a dedicated test user. DO NOT use arbitrary live members to simulate grant, suspend, broadcast or global reset.

## Operational notes
- All time-sensitive resource keys and donation/approval receipts need to be respected even after network interruption. No fake success after a timeout.
- Finance command status and in-app notifications are distinct; an Edge receipt does not attest successful mobile Push delivery.
- App screenshots of inaccessible community images are a separate mobile/client issue; no Flutter source or Production image objects were modified by this admin release.
- If a serious incident occurs, redeploy the previous `bil-admin-web-ops-v1` read-only gate version, preserve ledgers, and contact the operator. Do not delete financial or community audit tables.