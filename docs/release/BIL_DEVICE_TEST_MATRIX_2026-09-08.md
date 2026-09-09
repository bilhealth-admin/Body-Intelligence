# BIL signed-device release matrix — 2026-09-08

Status: **REQUIRED — NOT YET COMPLETE**

This is the execution/evidence sheet for the tester issues and current Apple
and Google release gates. A source test, simulator-only result, unsigned APK or
local debug entitlement is never entered as signed-device proof.

## Evidence rules

For every run record:

- UTC start/end time, tester and device owner;
- device model, OS/build, locale, text/display scale, orientation and network;
- app version/build, store channel and exact signed artifact SHA-256/source
  commit;
- clean install versus upgrade, account role and subscription state;
- expected/actual result, sanitized screenshot/video/log reference;
- backend/store correlation ID only when non-secret; never record JWTs,
  receipts, purchase tokens, private keys or passwords;
- cleanup result for posts/messages/test accounts and store test purchases.

Failure means the row stays open. Retesting one scenario does not erase the
original evidence; link both runs.

## Required device set

| Platform | Minimum matrix | Current evidence |
| --- | --- | --- |
| iOS | Current iPhone on iOS 26; one device on the oldest supported practical iOS (deployment target is 15.0); current iPad with split view/Stage Manager where available. | **MISSING for the recovered source/build.** Requires macOS/Xcode 26 and a processed TestFlight build tied to the source commit. |
| Android | Physical Android 16/API 36 phone; one older supported device (API 26 or representative still-supported version); Android tablet/large-screen or foldable; 16 KB page-size environment/device. | **MISSING for the recovered source/build.** Requires exact Play-signed AAB/internal-test install and artifact provenance. |

## Account and backend fixtures

Use disposable, auditable accounts only:

1. ordinary free user A;
2. ordinary free user B;
3. genuine store-sandbox/license-tester subscriber;
4. non-paid moderator (moderator role only, no Premium entitlement);
5. trusted administrator, used only for audited moderation/admin actions;
6. suspended user and a bilateral block pair created through supported admin
   or user actions;
7. never insert a policy acceptance or entitlement with service role to make a
   client test pass.

Before and after each group record counts for test-owned posts, comments,
messages, reports, acceptances and entitlements. Cleanup uses product/admin
paths and store test controls, not table truncation.

## Cross-platform functional matrix

| ID | Journey | Required variations | Pass evidence | Status |
| ---: | --- | --- | --- | --- |
| X01 | Community policy, first entry | No active policy in isolated rollback/staging; active unaccepted; accepted; new version; explicit decline/back; offline; suspended. | UI recording plus live/isolated database readback showing acceptance only for the signed-in user and exact version. | **PENDING**; SQL rollback cases pass, device UI pending. |
| X02 | Community publish | Caption-only, image-only, image+caption, invalid content, rapid double tap, slow upload, offline/retry, pending/public result. | Recording, one resulting server row, object cleanup and no duplicate. | **PENDING** |
| X03 | Community interactions | Like/unlike, save/unsave, comment, nested reply, share/deep link, report, delete/visibility. | Two-account recording and server row/policy readback. | **PENDING** |
| X04 | Friend discovery | Unique username claim/search, add by username, request/accept/decline/cancel/remove, QR share/scan/resolve. | Concurrent-claim evidence; QR resolves identity only and exposes no email/token. | **PENDING** |
| X05 | Blocking and suspension | A blocks B, B blocks A, both message directions, comments/replies/reactions/QR, unblock, suspended account. | All protected writes denied with clear UI; no bypass or leaked private data. | **PENDING**; server message-block rollback test passes. |
| X06 | Friend Chat viewport | Existing long history, initial bottom, send, receive near bottom, receive while reading history, jump-to-latest, prepend history, keyboard, rotate/resize, RTL/long text, copy/time. | Continuous video without top jump/flicker and with preserved read anchor. | **PENDING** |
| X07 | AI Coach response | Cloud answer; answer+action; action only; provider unavailable; timeout/retry; consent denied; no-charge failure; duplicate request; voice; safety question. | UI video plus sanitized Edge logs/metering before/after proving provenance and settlement behavior. | **PENDING** |
| X08 | AI Coach viewport/lifecycle | Thinking and completed response, copy/timestamp, background/foreground, lock/unlock, rotation, large text/RTL. | Continuous video, no history replacement/jump/flicker/squashed frame. | **PENDING** |
| X09 | Community food submission | Required/optional fields, Arabic digits, decimal comma, paste, invalid ratios, huge/NaN-like input, server failure/retry, navigate to chat. | Inline errors remain in form, values preserved, no queued snackbar in another route. | **PENDING** |
| X10 | Weekly Digest | First cold open with empty and populated history; slow storage; back/reopen; locale/date change. | First view correct without reopening; no replacement flash. | **PENDING** |
| X11 | Quick Add food | Open general Log Food, choose every meal explicitly, cancel/back; barcode/camera route. | No implicit Dinner route; saved entry lands in chosen meal/date. | **PENDING** |
| X12 | Today/goals | Consumed-only primary macro, target secondary, scheduled-day and meal goal overrides, rounding/decimal locales, day boundary. | Values match stored canonical targets and display sensible precision. | **PENDING** |
| X13 | Steps/connected health | Allow all, partial, deny, revoke, no data, multiple sources, day boundary, background/resume/process death. | Dashboard total matches authoritative platform aggregate/source labels. | **PENDING** |
| X14 | Sleep | Overnight, less than recommendation, invalid range, DST/time zone, goal versus actual, connected-source labels. | Clear validation/recommendation without changing source observations. | **PENDING** |
| X15 | Challenge | Free/paid/locked/progress states, keyboard/focus, screen reader and large text. | Each lock has reason/progress/action; no inaccessible wall of controls. | **PENDING** |
| X16 | Recipes/videos | Cold/warm cache, slow/offline network, full-screen, pause/resume, rotate/background. | No white flash, state loss or repeated download loop. | **PENDING** |
| X17 | Resume policy | Short interruption with draft, long absence, process death, deep link, free/paid/expired/revoked offline/online. | Draft preserved on short interruption; deliberate Dashboard policy on long resume; no false paywall flash or indefinite unlock. | **PENDING** |
| X18 | Accessibility/localization | Screen reader, switch/focus, 200%/largest text, high contrast where supported, Reduce Motion, RTL, all critical errors. | Structured focus/order/labels, no clipping, translated actionable errors. | **PENDING** |
| X19 | Account deletion | User with posts/comments/messages/photos and linked Apple/social identity; active subscription guidance; in-app and web paths. | Request receipt, token revocation where applicable, worker completion and data-deletion/retention readback. | **PENDING** |

## Apple/TestFlight matrix

| ID | Test | Pass condition | Status |
| ---: | --- | --- | --- |
| A01 | Signed artifact provenance | TestFlight build metadata, exported archive and CI identify the same source commit; Xcode 26+/iOS 26 SDK; SHA-256 retained. | **BLOCKED: build 10 not verified/present.** |
| A02 | StoreKit plan → Continue | Real sandbox sheet opens exactly once; displayed localized product/price matches selected plan. | **PENDING / RELEASE BLOCKER** |
| A03 | StoreKit lifecycle | Cancel, Ask to Buy/pending where available, success, restore, reinstall, cross-device, renewal, billing retry, grace, expiry, refund/revoke. | **PENDING / RELEASE BLOCKER** |
| A04 | App Store Server Notifications V2 | Test notification succeeds; renewal/refund/revoke update server entitlement idempotently. | **PENDING** |
| A05 | App Attest | Development build uses dev category; TestFlight uses production category; challenge, assertion counter, replay, wrong app/key and key rotation behavior pass. | **PENDING / ENFORCEMENT MUST STAY OFF UNTIL PASS** |
| A06 | HealthKit | Per-type partial authorization, revoke, no data, multiple sources, weight write permission, no health-to-ads flow. | **PENDING** |
| A07 | Apple Sign In | New/returning, hidden email, nonce/callback, credential revoked, token revocation during deletion. | **PENDING** |
| A08 | Universal links | Auth callback/reset on clean install, cold start and running app; AASA matches signed Team ID/bundle. | **PENDING** |
| A09 | Push | Ask in context, deny/re-enable, foreground/background/terminated, privacy-safe preview and deep link. | **PENDING** |
| A10 | iPad/iPhone UI | Split view/Stage Manager, rotation, keyboard, Dynamic Type/VoiceOver, lock/unlock on Community and Coach. | **PENDING** |

## Android/Play matrix

| ID | Test | Pass condition | Status |
| ---: | --- | --- | --- |
| G01 | Signed artifact provenance | Play app bundle/install identifies same source commit/version; AAB SHA-256 and Play signing certificate retained. | **BLOCKED: Android build 9 AAB not verified/present.** |
| G02 | Play Billing plan → Continue | License-tester sheet opens exactly once and selected base plan/offer/price are correct. | **PENDING / RELEASE BLOCKER** |
| G03 | Billing lifecycle/RTDN | Pending complete/cancel, success, acknowledgement, restore, renewal, grace, hold, cancel, refund/revoke and duplicate RTDN all update entitlement correctly. | **PENDING / RELEASE BLOCKER** |
| G04 | Play Integrity | Warm provider; correct request hash/package/app/device/timestamp; replay/stale/wrong hash fail safely; protected actions work on Play-signed install. | **PENDING / ENFORCEMENT MUST STAY OFF UNTIL PASS** |
| G05 | Health Connect | Permission rationale, partial/deny/revoke/history, manage access, multiple sources and version/update-required paths. | **PENDING** |
| G06 | Android 16 UI | Edge-to-edge, gesture/3-button predictive back, keyboard/insets, notifications and every modal/route on API 36. | **PENDING** |
| G07 | Large screen/foldable | >=600dp portrait/landscape, split/freeform/desktop, fold/unfold and camera/community/chat resize. | **PENDING** |
| G08 | 16 KB | Every packaged 64-bit `.so` passes alignment verifier and app starts/exercises scanner/media on 16 KB environment. | **PENDING** |
| G09 | App Links | Live Digital Asset Links contains Play app-signing SHA-256; forced verification and auth/reset paths pass without redirects. | **PENDING** |
| G10 | Pre-launch report | No unresolved stability, compatibility, performance or accessibility error for the exact candidate. | **PENDING** |

## Completion boundary

This matrix is intentionally not checked off from source inspection. Release
readiness requires every applicable row to have linked evidence for the exact
signed candidate, plus cleanup confirmation and a zero-unresolved-blocker
review. Until then the correct conclusion is **not ready to submit/release**.
