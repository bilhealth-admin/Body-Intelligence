# BIL Workout Video: independent cloud delivery audit — 2026-10-25

**Scope:** Cloudflare/R2/CDN delivery of the exact protected biceps-curl MP4 at:
https://workouts.bilhealth.com/v2/objects/workouts/v1/gym-six-month/movements/resistance-upper-body-dumbbell-biceps-curl-technique.mp4

**Safety:** Read-only live checks, plus a review-only Cloudflare Worker MIME hardening proposal. NO iOS/Android code changes, NO direct changes to main/integration, NO live deployment, NO cache purge, NO bucket mutation, NO merges.

## Evidence captured in this audit

1. **Independent browser navigation on 2026-10-25, no session:** A branded HTML page titled “Dumbbell Biceps Curl — BIL Health source” appeared at the exact URL, with the message “This video requires an eligible account. Browser links do not carry the app's secure sign-in session.” No video played. The browser agent reported HTTP 200 and text/html, **but the browser tool could not expose raw network headers or the redirect chain**. Report those status/MIME values as browser-agent observations, not independently captured response headers. No conclusions about a correctly authenticated iOS request can be drawn from this unauthenticated browser result.
2. **Direct HTTP HEAD, GET Range, OPTIONS from the execution container:** attempted with curl, requests, and the accompanying Python diagnostic tool. Every request was blocked before HTTP by DNS resolution failure for workouts.bilhealth.com (Errno -3). **There was no raw HTTP response**, so live Accept-Ranges, 206, Content-Length, CORS, Age, Cache-Control and CDN HIT/MISS remain **unverified**. Do not label missing headers as server failures.
3. **GitHub source inspection:** On integration/bil-qa-media-policy-20261011, the exact video key is in artifacts/workout_media/cloudflare_runtime_v2/protected_object_keys_v2.json but **not** in artifacts/workout_media/cloudflare_runtime_v2/free_preview_keys_v1.json. It is an intentionally protected **Premium** asset; do NOT make it publicly cacheable or anonymously accessible to fix review.
4. **Source/runtime mismatch:** cloudflare/workout-runtime/src/index.ts deliberately returns 401 application/json (authentication_required; cache-control no-store) for no Bearer token, 403 JSON for an authenticated Free account, and 200/206 streaming to an entitled member. The unauthenticated browser instead displayed an HTML landing page. Possible explanations include a browser-specific rule, a competing Cloudflare route, an access/transform rule, or a deployed bundle different from the checked-in Worker; **no cause is confirmed**.
5. **Worker code hardening in this Draft PR:** For an allowlisted .mp4 object, the Worker now refuses to serve data unless the R2 HTTP metadata MIME is video/mp4. Existing positive authenticated streaming tests still describe expected 206; a new regression test asserts that mislabeled text/html R2 objects fail closed with 502 and no-store for HEAD, GET and Range. This is protective guardrails, **not a proven fix** for the browser HTML gate or missing reviewer entitlement.
6. **Offline tool validation:** python -m unittest on the dedicated diagnostic module: **4 passed**. Syntax compilation passed. Live direct diagnostic returned INCOMPLETE because the execution container could not resolve the hostname. Worker TypeScript, Cloudflare Vitest, dry-run and E2E iOS tests **not run** in this environment.

## Expected contract (for this exact Premium key)

| Request | Expected source behavior | Real live outcome |
| --- | --- | --- |
| Anonymous HEAD | HTTP 401, application/json, Cache-Control: no-store | DNS prevented direct HTTP test |
| Anonymous GET with Range: bytes=0-1023 | HTTP 401 JSON, no media bytes | DNS prevented direct HTTP test |
| Anonymous browser GET, Accept: text/html | HTTP 401 JSON according to checked-in Worker | HTML gate observed; browser agent reported 200/text/html without raw headers |
| Authenticated Premium HEAD | HTTP 200; video/mp4; full-object Content-Length; Accept-Ranges: bytes; ETag; private cache; Vary: Authorization | no Premium JWT available |
| Authenticated Premium GET Range 0-1023 | HTTP 206; Content-Range: bytes 0-1023/TOTAL; Content-Length: 1024; Content-Type: video/mp4 | no Premium JWT, no raw HTTP connectivity |
| Authenticated Free user | HTTP 403 premium_entitlement_required | untested live |
| OPTIONS from https://www.bilhealth.com | HTTP 204, exact Access-Control-Allow-Origin; allowed headers authorization and range | DNS prevented direct HTTP test |
| OPTIONS from unapproved Origin | HTTP 403 | DNS prevented direct HTTP test |
| Cache policy | Authenticated MP4 must remain private and vary by Authorization; auth denials are no-store | raw CDN headers and repeat HIT/MISS unverified |

For native iOS network clients, browser CORS is not the authorization mechanism. For webviews and browser JS, exact allowed Origin and preflight matter. Successful single-byte-range responses must use 206 with consistent Content-Range and Content-Length.

## Existing checked-in Cloudflare config

- cloudflare/workout-runtime/wrangler.jsonc: Worker bil-workout-runtime, custom domain workouts.bilhealth.com, private R2 WORKOUTS bucket bil-premium-workouts-2026-v1, exact CORS Origin https://www.bilhealth.com.
- cloudflare/workout-runtime/src/index.ts: auth and entitlement gates, R2 HEAD and byte ranges, Cache-Control private/public, ETag, Accept-Ranges, Origin and Authorization Vary, CORS.
- Cloudflare worker's .mp4 content-type originally depended entirely on R2 HTTP metadata. The proposed MIME check prevents sending mislabeled HTML as successful MP4 media if the request reaches this Worker.
- **STAGING SAFETY BLOCKER:** The currently committed wrangler.jsonc env.staging still references production R2 bucket names and production Supabase URL. The check:staging-isolation guard rejects shared production resources. Do not bypass it or deploy to that staging configuration.

## Read-only verification and engineer instructions

1. From a network-enabled build runner, execute from repository root:

       python3 -m unittest discover -s tool/release -p test_bil_workout_video_http_audit.py -v
       python3 tool/release/bil_workout_video_http_audit.py --output /tmp/bil-workout-unauth.json

   The script sends HEAD, OPTIONS and limited GET Range requests to the **exact fixed URL only**, reads <=1024 response-body bytes per GET, does NOT follow redirects, and does not print a token. Browser-like and native-like Accept headers are checked independently.

2. For a **genuine entitled reviewer-equivalent Supabase user**, set BIL_AUDIT_WORKOUT_BEARER securely as a process environment variable, rerun the script, capture the sanitized JSON. Do not use a service-role key; do not print or commit credentials. Confirm 200 HEAD and 206 GET, correct Content-Type and ranges, ETag, Vary, private cache and full-vs-partial lengths. Confirm the same account can fetch the video through the app downloader.
3. In Cloudflare dashboard, inspect the actual deployment version and custom-domain route for workouts.bilhealth.com, and all Access/Redirect/Transform/Cache rules matching /v2/objects/*. Determine why an anonymous browser sees a 200 HTML gate while the checked-in Worker would return 401 JSON; distinguish a deliberate browser-only help page from accidental API interception. Do not automatically remove a user-facing notice if a separate UI route is intended.
4. Inspect the exact private R2 object's httpMetadata.contentType (must be video/mp4), byte length, integrity SHA and release inventory before approving the fail-closed MIME guard. Wrong MIME must not be fixed by publicizing the bucket; restore metadata carefully after verifying the signed object bytes.
5. Confirm Apple's review account has the intended Premium entitlement under server policy and passes a **Supabase user JWT Bearer** on protected media requests, including Range/HEAD. Apple identity tokens or anonymous browser links are not substitutes for this JWT. If review access is intended, provision it via approved entitlement grants, not global bypass.
6. Provision fully isolated staging R2/Supabase values first; then run cloudflare/workout-runtime npm ci, npm run types:check, npm run check, npm test, npm run dry-run:staging and the remote HTTP probe. Stage and test before requesting explicit production change approval.
7. Confirm publicly shared CDN cache does not store authenticated MP4 responses or HTML denials; verify Cache-Control: private and Vary: Authorization, plus Age/cf-cache-status and a repeated read. A cache purge or prod Worker deploy is **out of scope for this PR/run**.

## Execution results / release gate

- Browser check: COMPLETE, observed HTML gate / no playable media without session; raw response header capture unavailable.
- Python offline tests: **4 PASS**.
- Python source compile: **PASS**.
- Direct HTTP live header checks: **INCOMPLETE due to runner DNS**, not a confirmed server fault.
- Premium reviewer authentication/playback: **NOT RUN**.
- Cloudflare Worker Vitest and TypeScript build: **NOT RUN** (required before merging).
- Production Worker R2/custom-domain state: **NOT MODIFIED**.
- Current PR status: Draft only. **Do not merge or deploy until Cloudflare/R2 metadata, live HTTP and isolated staging tests pass.**
