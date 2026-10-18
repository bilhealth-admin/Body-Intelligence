# BIL Secure Administration — 18 October 2026: complete-source moderation/Earn handoff

## Source and isolation
- App: `https://bilhealth-secure-admin.bilhealth-app.workers.dev/`, independent Cloudflare Worker.
- Repo: `bilhealth-admin/Body-Intelligence`, branch `feat/bil-secure-admin-ops-20261018` ONLY; **do not touch Flutter/Codex/main**.
- Old finance Edge `bil-admin-web-v1` V8 and generic ops Edge `bil-admin-web-ops-v1` V4 remain independent. Generic ops writes intentionally LOCKED until isolated owner-authorized verification.
- New owner-only signed-media / Earn gateway `bil-admin-web-review-v1` deploy separately with exact origin, Supabase `auth.getUser()`, AAL2 fresh 90-second TOTP on writes, owner-ID allowlist + database administrative role, no service_role in client. Reviewer actions **never** bypass SQL revision/authority locks.

## Evidence-first moderation
- Pending posts use existing `bil_list_pending_community_posts` only for IDs, then `bil_community_review_snapshots_v2` for a locked revision and complete title, body and attributes.
- Media metadata comes from `bil_community_post_media_v1`, plus historical `media_object_path` if applicable; service-role only on Edge signs **180-second** URLs for private bucket `community-post-images`. Browser CSP admits signed assets exclusively from the exact Supabase project domain; cache-control no-store, no admin data before authenticated AAL2 owner session. A broken/unsigned media manifest **disables decisions**.
- Review decision requires full-content acknowledgment, explicit selection + reason when rejecting, new operation UUID, server refresh of revision + media metadata, fresh TOTP and authoritative SQL RPC `bil_moderate_community_post_v2` with fixed `eligible` reward mode. Do not offer `deferred` until SQL policy independently allows it (live `allow_publish_only=false`).
- Recipient email from existing `bil_admin_web_reporter_contacts_v1` service-only author resolution against preauthorized post list; never open an arbitrary user lookup API.
- Details also show poll question/options, hashtags, place, time, user ID (when truly useful), optional title and multi-image gallery.

## Earn truth (production read-only checks)
- `bil_community_post_reward_policy`: `tokens_per_approval = 5`, max rewarded posts per owner per UTC day `= 5`; **up to 25 AI Tokens/day**. Approval can grant **0** if daily cap reached; UI must use returned `tokens_granted`, not assume `5`.
- Initial post publication and later Earn review are separate queues: `bil_community_reward_review_queue_v2`, `bil_request_community_post_reward_v2`, `bil_decide_community_post_reward_v2` handle already-approved posts; existing SQL handles idempotency, quota, unique grant receipt. Do not award a second grant after one has already been paid.
- Production SQL triggers for post review: `bil_community_post_review_grant_receipt_v2`, `bil_community_post_review_rejection_receipt_v2`; in-app activity + push-outbox queue are distinct from actual external push delivery.
- Expected receipt copies: `تم اعتماد منشورك وأُكدت مكافأة 5 توكنات AI. Post approved; +5 AI tokens confirmed.` or `تم اعتماد منشورك، لكن حد المكافأة اليومي اكتمل. Post approved; the daily reward limit was reached.` and rejection `منشورك يحتاج تعديلات. Your post needs changes.` **Confirm delivery only with independently verified push records.**

## Acceptance and execution gates
1. Isolated Node tests for Edge JWT/role/HTTP origin, private gallery, idempotency, 5-token and 0-token cases, stale revision, Earn, unsafe action denial.
2. Node browser source checks, `npm run build` and CSP review.
3. Playwright synthetic in real Chromium at 320/375/390/430/768/1280 widths, both RTL/LTR, 9 modules, 4 moderation queues, 2 fake private images, no horizontal overflow, no JS error; click approve + Earn with synthetic TOTP mocked **without touching Production**.
4. Deploy Edge **with review writes disabled**; smoke test from live Cloudflare origin: allowed preflight, unauthenticated 401, alien origin 403, signed preview API only under owner JWT. Run GitHub CI green and site HTTP smoke before considering any gate change.
5. If explicitly activated, review-only writes require an owner to submit a real TOTP step-up; do not execute real moderation, rewards or notification commands from automation. An isolated real-user-identity E2E is owner-assisted and remains `NOT VERIFIED` until authenticated, authorized tests with safe test objects are performed.
6. Generic global AI reset, notifications, moderators, member suspension remain gated by `BIL_ADMIN_OPS_WRITE_ENABLED=false`. Never label them operationally completed merely from successful static tests; do not remove mobile moderation until an equivalent web replacement has verified real E2E.

## Apple / Google / media compliance
- Apple guideline 1.2: UGC reports, moderation/filtering, abusive account blocking, contact; actual app workflows must exist independent of admin web.
- Google Play UGC policy: report/block content and people in app; timely moderation decisions and enforceable policy.
- Supabase signed URLs of private objects: short-lived, server-generated after owner authorization, never expose service-role credentials.
- Cloudflare Worker static SPA: separate worker, CSP, strict CORS preflight and no-cache of private display.

## Live-only verification NOT covered by synthetic E2E
- Owner account Email OTP+TOTP real browser and signed-media rendering in owner’s authenticated environment, including real pending multi-image post (current pending post count may be image-free).
- Owner authorized accept/reject on *controlled test data* and read-back of approval/rejection, credit ledger, in-app receipt, push outbox and actual external push receipt if applicable.
- Moderation of a truly image-bearing pending post: 2+ images and changed/expired URL behavior.
- Broad generic admin writes and account authorization cutover remain locked.