# BIL Secure Admin — Root-cause / Mobile UI repair (18 Oct 2026)

## Scope and isolation
- Repository `bilhealth-admin/Body-Intelligence`, branch `feat/bil-secure-admin-ops-20261018` only.
- No Flutter app/CodeX branch changes, no UI access to `service_role` secret, no account grants/suspensions/resets, no token balances changed by this patch.
- Production site remains `https://bilhealth-secure-admin.bilhealth-app.workers.dev/`.

## Demonstrated root cause
- Supabase PostgreSQL logs around 02:09–02:15 UTC include SQLSTATE `42501` errors when privileged Edge Review attempted direct SELECT on `public.bil_community_post_media_v1` and `public.bil_community_post_reward_policy`.
- `service_role` does not hold direct table SELECT on either table (nor on hashtags and poll tables). This is intentional least-privilege hardening, **not proof the owner account lost its role**.
- Edge translated table-level errors into `not_authorized`, creating a misleading red banner and failed/partial review previews. Buttons that require confirmed media could not be enabled safely.
- Separate `bil-admin-web-ops-v1` explicitly has `BIL_ADMIN_OPS_WRITE_ENABLED=false`; connection/status being active **never meant** all account-mutating operations were unlocked.

## Changes
1. Added two read-only, SECURITY DEFINER, service_role-only, active-admin-scoped RPCs in Supabase migration `bil_admin_owner_scoped_review_read_context_v1_20261018`:
   - `bil_admin_web_review_context_v1(actor, post)` provides all image paths/metadata, title, author display, tags/topics/circles/location and poll (pending/approved only; cannot inspect own post through the review flow).
   - `bil_admin_web_review_reward_policy_v1(actor)` returns live Earn policy and maximum; cannot grant tokens.
   - **No broad GRANT SELECT to service_role, authenticated or anon**; PostgreSQL role/ACL rechecked.
2. Edge Review now uses only these scoped RPCs for table metadata, still uses private signed URLs (180 seconds) and versioned, actor-checked review decisions; if resources are unavailable, preserves visible text but blocks approval. Maps backend setup errors to a service error, not a false claim that the owner is unauthorized.
3. Cloudflare operator UI: Arabic/English contextual error messages; accurate read-only versus write capability states; independent status refreshing, per-queue detailed errors; per-page descriptions and working explanation of locked account-changing buttons.
4. iPhone navigation: outside tap/backdrop, close ×, Escape, section navigation, and resize close the sidebar; safe focus and background scrolling.
5. Visual polish: consistent outlines/icons, compact readable cards, updated spacing and SF-system font, no remote image/font dependencies.

## Tests and evidence
- Read-only database transaction performed using `SET LOCAL ROLE service_role` + simulated service JWT claims (rolled back). It returned 5 AI tokens/approval, daily cap 5 and successfully read a pending post via scoped function.
- Unit tests (Node) validate 21 separate review gateway behaviors, including denied origin, stale revision, invalid auth, media signing failure, 5/0 Earn receipts, contextual table denial, and absence of direct service table SELECT.
- Synthetic browser E2E on viewport widths 320,375,390,430,768,1280 validates all nine modules, four moderation queues, full synthetic post and images, no document horizontal overflow/JS errors, Arabic/English, review acceptance, MFA modal, no mutations, and outside-click/Escape/nav/× closure of sidebar.
- Final GitHub CI and Cloudflare deployment MUST show success after commit. The owner must authenticate and test the real moderation data/decision in their browser before claiming full Production E2E.

## Remaining boundaries
- Separate Ops writes (moderator changes, suspension, resets, notifications) remain intentionally disabled until approved real E2E. Do not silently unlock global reset or broad notifications. The interface must explain this and never show fake success.
- User also reports image placeholders in the **Flutter mobile app**. Storage metadata shows 10/10 media references exist and signed-object GET requests returned HTTP 200 in this sampling. That does NOT prove real iOS widgets/cache work: inspect the mobile client's signed-URL renewal, image cache and image expiration separately with Codex; do not change the active Flutter branch here.