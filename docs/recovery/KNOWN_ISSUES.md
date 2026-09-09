# BIL recovery known-issues tracker

Checked: 2026-09-08
Branch: `codex/bil-community-policy-recovery-20260908`
Baseline: `21f16767fad82d625ced9b6da2146b66b4b27953`

Status vocabulary:

- **VERIFIED** — the relevant automated/live check passed and no additional
  proof is inherent to the issue.
- **FIXED IN SOURCE; DEVICE TEST PENDING** — a bounded implementation and
  regression test exist, but the tester-observed device behavior has not yet
  been reproduced on the required signed-device matrix.
- **SERVER TEST PASSED; APP E2E PENDING** — live schema/function checks pass,
  but a real-user app journey is still required.
- **OPEN / RELEASE BLOCKER** — the end-to-end failure is not closed.
- **AUDIT IN PROGRESS** — source/live reconciliation is still running and is
  not counted as fixed.

No item is marked fully fixed solely from code inspection when it needs a real
device, store-signed build, or live backend journey.

Test-status supersession: table cells below that still say “final run pending”
refer to their earlier per-issue checkpoint. The final official portable run
has now completed: 875/875 files, **4,071 PASS / 0 FAIL / 1 opt-in live-stream
SKIP**, and root analysis has no issues. This supersedes source-suite pending
wording only; every stated device, visual, live-canary and store proof remains
open.

## Owner tester checklist — verbatim

- AI Coach does not reliably work/cloud reply is inconsistent.
- AI Coach chat jumps to the top; after typing/thinking it jumps again.
- AI Coach screen flickers without interaction.
- iPhone lock/unlock while app is open briefly shows a squashed/enlarged layout.
- AI Coach text cannot be copied and lacks message times.
- Sleep minimum/allowed schedule logic conflicts.
- Friend add still has problems.
- Friend messages can arrive but stale “Complete all required values” appears.
- Community Publish sometimes appears dead.
- image-only Publish appeared dead.
- Community has no polished general feed for subscribers.
- Community needs modern posts/comments/replies/likes/save/share/Add Friend.
- Community screens are crowded and need a spacious redesign.
- Community admin posts become Pending and need a deliberate trusted-admin moderation design.
- Community moderator account should reach moderation without having to buy Premium.
- Verified/community food submission UX is unclear/dead-looking on invalid fields.
- One Best Action/algorithm needs review.
- Steps must reliably record/show on Dashboard.
- Weekly Digest opens blank first time and appears after leaving/reopening.
- Challenge page is unclear and has too many unexplained locked icons.
- Recipes/videos flash when opening.
- plan → Continue purchase does not start purchase.
- goals/triggers need review.
- scheduled goals show overly precise gram decimals.
- returning to app after a long time should follow deliberate Dashboard policy.
- subscriber paywall/protection briefly flashes on resume.
- Dashboard logo should be a little wider/larger.
- Quick Add → Log Food incorrectly goes to Dinner search.
- Today macro primary display should show consumed only, e.g. `3 g`, not `3/36 g`.
- unique usernames must be server-unique.
- add friends by username.
- every member should have a BIL QR code in Community to share/scan.
- newest friend/AI messages must live at the bottom like a normal modern chat.

## Detailed closure records

| ID | Current status | Evidence / root cause | Changed implementation | Regression tests and latest result | Proof still required | Rollback |
| ---: | --- | --- | --- | --- | --- | --- |
| 01 | **SOURCE/LIVE PARITY VERIFIED; AUTHENTICATED CANARY REQUIRED** | The active `ai-coach` v51 bundle and all five deployed files exactly match the checked-out source after normalized comparison. v51 sends explicit Gemini safety settings and maps provider safety blocks to a stable refunded `422` response. This proves source/deploy parity, not a working signed-device cloud-answer journey: a local answer must never be presented as a cloud answer. | `lib/features/intelligence_center/services/intelligence_center_engine.dart`, safety/query/context flow files, `supabase/functions/ai-coach/*`. | Deno 24/24 and focused Flutter 42/42 passed after the safety delta; unauthenticated live probe returned 401. | Authenticated live canary for answer, provider failure, retry, no-charge rollback, voice and all supported locales. | Revert the bounded client/Edge Function commit; deploy only a forward server version known to match the retained live digest. Never restore entitlement rows. |
| 02 | **FIXED IN SOURCE; DEVICE TEST PENDING** | Whole-list replacement/controller resets caused top jumps. A shared bottom-anchored viewport now preserves the near-bottom state and history anchor. | `lib/shared/widgets/chat_history_viewport.dart`, Friend Chat and AI Coach presentation integration. | `test/shared/widgets/chat_history_viewport_regression_test.dart`; final post-integration run pending. | Long history, send/receive, keyboard, rotation, RTL and intentional scroll-up on iPhone/iPad/Android phone/tablet. | Revert the shared-viewport integration commit; no data migration is involved. |
| 03 | **FIXED IN SOURCE; DEVICE TEST PENDING** | Loading/thinking state previously risked replacing/rebuilding the message surface. The candidate keeps history mounted and renders progress separately. | AI Coach page/message widgets/query flow and shared viewport. | AI conversation/action/persistence tests plus shared viewport test; final aggregate result pending. | Leave the screen idle, stream/finish replies, background/foreground and 60/120 Hz visual inspection. | Revert the presentation-only commit; persisted conversation data remains compatible. |
| 04 | **SOURCE-CONFIRMED MITIGATION; IOS DEVICE REQUIRED** | Lifecycle/size transition can briefly expose an intermediate Flutter surface. Privacy shield and responsive lifecycle work are present, but Windows cannot prove the tester's iPhone lock/unlock symptom is gone. | `lib/app/services/app_switcher_privacy_shield.dart`, responsive shell and iOS lifecycle code. | iOS runtime/responsive contract tests exist; no physical iPhone result yet. | Repeated lock/unlock in AI Coach and every major route on current iPhone plus older supported iOS; capture slow-motion evidence. | Revert the lifecycle/layout commit only if it regresses state restoration; no backend rollback. |
| 05 | **FIXED IN SOURCE; DEVICE TEST PENDING** | Message widgets lacked selection and visible persisted timestamps. Candidate uses selectable/copyable text and stored message time. | AI Coach message widgets and `chat_history_viewport.dart`. | Message text/history and shared viewport tests; final focused run pending. | Long-press/copy, VoiceOver/TalkBack reading order, locale/RTL time format on devices. | Revert presentation commit; message schema is unchanged. |
| 06 | **FIXED IN SOURCE; DEVICE TEST PENDING** | Goal/recommendation duration and arbitrary clock ranges were conflated. Updated UI/domain validation separates a sleep goal from recorded sleep and validates overnight spans. | `lib/features/wellness/presentation/sleep_tracker_experience.dart` and nutrition/schedule domain/UI helpers. | `test/features/settings/nutrition_goal_schedule_page_test.dart`, locale/sleep aggregation tests; final run pending. | DST/time-zone, overnight, min/max, HealthKit/Health Connect source labels on both platforms. | Revert bounded sleep/schedule commit; existing saved schedules must remain readable. |
| 07 | **SERVER TEST PASSED; APP E2E PENDING** | Social-v2 identity/friendship paths exist; the prior symptom needs a real two-account test and race/duplicate verification. | Community repository, people/connections/friends pages; live Social v2 migration retained. | Community connection/profile/friendship contract tests exist; final focused and live two-account run pending. | Search/request/accept/decline/cancel/remove/block with two ordinary users, reconnect and process death. | Revert Flutter integration. Backend correction, if needed, must be a forward migration; do not recreate Social v2 tables. |
| 08 | **FIXED IN SOURCE; DEVICE TEST PENDING** | The text originated in the Community food form and queued through a shared `ScaffoldMessenger`, then appeared over Friend Chat. Inline field validation replaces cross-route generic snackbars. | Community food input model, form copy and submission sheet/tab. | Community food input/sheet/form regression tests; final run pending. | Navigate away after invalid Arabic/English input, then receive/send chat messages; confirm no stale snackbar. | Revert food-form UI commit; no server data rollback. |
| 09 | **VERIFIED AT REGRESSION LEVEL; DEVICE TEST PENDING** | Publish returned early on validation and `setState` incorrectly returned a `Future`, making the action appear dead. The async call is now outside the synchronous callback and failures are explicit. Active policy enforcement is live. | Community composer/feed/repository and content-policy domain. | `test/features/community/community_publish_validation_regression_test.dart`: **4/4 PASS** in the recovery run; policy SQL/contract tests also pass. | Real Android/iOS caption post, pending/public result, offline/retry, duplicate tap and rejected-policy flow. | Revert Flutter composer commit. Backend policy rollback must be a new forward deactivation migration, never acceptance fabrication/deletion. |
| 10 | **FIXED IN SOURCE; DEVICE TEST PENDING** | Image-only submissions previously shared text validation and could silently return. Candidate validates media presence independently and reports picker/upload state. | Composer, post image picker and cloud store. | Community image-support and publish-validation tests exist; full focused result pending. | Camera/gallery, image-only, slow upload, cancel, lost process, denied permission, retry on both mobile platforms. | Revert media/composer commit; remove only newly uploaded test objects through the documented test cleanup path. |
| 11 | **FIXED IN SOURCE; DEVICE TEST PENDING** | The earlier hub lacked a coherent subscriber feed. Stage1 introduces a feed hierarchy, refresh/error/empty states and preserves existing content. | `community_hub_page.dart`, `community_feed_tab.dart`, models/repository. | `test/features/community/community_feed_redesign_regression_test.dart`; final run/visual acceptance pending. | Real mixed feed, cold/warm refresh, pagination, long/RTL copy on phone/tablet. | Revert feed presentation commit; server tables/data remain untouched. |
| 12 | **SERVER TEST PASSED; APP E2E PENDING** | Social v2 supplies posts, nested comments/replies, reactions, saves, share/deep links and identity/friend operations. The exact base migration `20260908013800_bil_community_social_v2` has been recovered from authoritative deployment history (the local Git text representation adds only its required terminal LF); client integration still needs multi-user verification. | Live Social v2 objects plus the recovered migration and community models/repository/feed/detail/profile surfaces. No production table was rebuilt or replaced. | Social/community contracts and SQL role tests exist; policy/block SQL runtime passed. Complete feature E2E still pending. | Run two-user likes/unlikes, comment/reply deletion/moderation, save/unsave, share/deep link, and block/suspend bypass attempts. | Revert UI commit; use forward migrations only for server defects and preserve existing rows/RLS hardening. |
| 13 | **FIXED IN SOURCE; VISUAL ACCEPTANCE PENDING** | The Stage1 design moves dense controls into clearer tabs/cards/sheets and adds spacing/responsive structure. | Community hub/feed/people/messages/food/safety presentation files. | Community pre-release visual/redesign tests exist; final goldens and device review pending. | English/Arabic visual QA on iPhone, iPad, Android phone/tablet, large text and dark mode. | Revert presentation commit; no database rollback. |
| 14 | **SERVER TEST PASSED; APP E2E PENDING** | `Pending` is an intentional moderation state, not publish failure. Trusted-admin behavior must remain server-authorized and auditable rather than client self-approval. | Moderation page/repository plus existing Social v2 moderation functions/policies. | Community post moderation and admin authorization tests exist; live role-path canary pending. | Ordinary author, trusted admin and moderator posting/moderating with audit readback; ensure authors cannot approve themselves. | Revert client moderation UI; server changes only through a forward migration, retaining audit history. |
| 15 | **SERVER TEST PASSED; APP E2E PENDING** | Moderator authorization and subscription entitlement are separate. Existing moderator roster/admin paths must allow moderation without granting Premium. | Community moderation route/admin service plus existing moderator backend; no subscription grant added. | `community_moderator_admin_contract_test.dart`, `community_member_access_admin_contract_test.dart` and entitlement separation tests exist; final run/live login pending. | Sign in as an actual non-paid moderator, reach moderation, verify premium content remains locked and audit entry is emitted. | Remove moderator only through the audited admin function if the test account was temporary; never grant/revoke store entitlement as rollback. |
| 16 | **FIXED IN SOURCE; DEVICE TEST PENDING** | Generic validation hid missing/invalid fields and allowed nonsensical ratios to look actionable. New per-field model normalizes localized numbers, checks finite/nonnegative values and nutrition coherence, and keeps server errors in the form. | `community_food_input.dart`, submission sheet, form copy and food tab. | Community food input/sheet/form tests exist; final focused run pending. | Arabic digits, comma decimal, pasted text, blank/huge/NaN-like values, slow/failing server and duplicate submit. | Revert food-form commit; test submissions must be deleted through normal moderation/test cleanup, not table truncation. |
| 17 | **OPEN — ALGORITHM REVIEW REQUIRED** | One Best Action can affect health/fitness guidance; source contains adapter/engine changes but there is not yet sufficient evidence that ranking, stale data, conflicting goals and non-medical wording are correct. | Dashboard intelligence input adapter and One Best Action/engine surfaces under review. | Intelligence/domain tests exist; no completed reviewer matrix is recorded yet. | Curated scenarios for missing/stale/conflicting data, injury/health boundaries, localization, deterministic ranking and real device rendering. | Revert only the bounded algorithm commit; retain stored user data and prior explainability fields. |
| 18 | **FIXED IN SOURCE; DEVICE TEST PENDING** | Connected-health foreground/read provenance and Dashboard provider refresh were revised to avoid missing step totals. | Connected health provider/bridge, dashboard grid/header/card integration. | Connected-health steps/runtime and dashboard tests exist; final run pending. | Real HealthKit and Health Connect with allow/deny/revoke, multiple sources, day boundary, background/foreground and process death. | Revert provider/UI commit; never delete HealthKit/Health Connect source data. |
| 19 | **FIXED IN SOURCE; DEVICE TEST PENDING** | Initial provider/listener timing left the first frame without resolved data; reopening observed the later state. Candidate makes the initial fetch deterministic without replacing populated content. | Weekly report provider/page/components. | Weekly report history navigation/truth/reference tests exist; final focused result pending. | Cold first open with empty/populated/slow local store, background/resume and locale/date changes. | Revert weekly-report initialization commit; no data migration. |
| 20 | **FIXED IN SOURCE; VISUAL ACCEPTANCE PENDING** | A wall of lock icons did not explain eligibility or progress. Candidate exposes state/reason/progress and reduces disabled-control noise. | `lib/features/challenges/challenges_page.dart`. | `test/challenges_state_visual_contract_test.dart`; final run and semantic device review pending. | TalkBack/VoiceOver, large text, free/premium states, progress transitions on phone/tablet. | Revert challenge presentation commit; challenge progress data remains unchanged. |
| 21 | **FIXED IN SOURCE; DEVICE/NETWORK TEST PENDING** | Route entry and asynchronous media/cache replacement produced visible flashes. Candidate retains placeholders/content and uses a shared media cache. | Recipe/video presentation, delivery client and `wellness_media_cache.dart`. | Recipe image cache/delivery and wellness video stream/resume tests exist; final run pending. | Cold/warm cache, slow/offline network, route transitions, rotate/resume and full-screen playback on both platforms. | Revert media presentation/cache commit; cached files may be cleared through app cache APIs, not user-content deletion. |
| 22 | **OPEN / RELEASE BLOCKER** | Source has a verified purchase service and guarded button flow, but no source test can prove Apple/Google purchase sheets launch for the exact signed build. | Commerce plan pages, providers, verified purchase service and server verifier. | Billing hardening and entitlement tests exist; StoreKit sandbox and Play license-tester E2E are not yet complete. | Real plan → Continue → sheet; cancel/pending/success/restore/reinstall/renew/grace/hold/refund/revoke on both stores, with server readback and no duplicate entitlement. | Revert bounded client purchase commit. Test purchases are refunded/revoked through store tools; never edit entitlements by hand. |
| 23 | **AUDIT IN PROGRESS** | Goal schedule, active goal resolution and downstream trigger consumers have multiple paths. Source changes exist, but complete traceability from saved schedule to Today/Dashboard/Coach has not been demonstrated. | Nutrition goal schedule repository/pages and downstream goal resolver/adapters. | Goal schedule and intelligence/dashboard tests exist; final cross-feature matrix pending. | Boundary dates/time zones, schedule edits, missing goal, sync/restore and real UI consumers. | Revert goal-resolution commit while retaining backward-compatible stored schedule decoding. |
| 24 | **FIXED IN SOURCE; DEVICE TEST PENDING** | Raw floating-point grams leaked to UI. Candidate centralizes locale-aware macro formatting and avoids excessive precision. | Goal schedule UI and `macro_value_formatter.dart`. | Goal-grams/reference-preferences/macro widget tests exist; final run pending. | Decimal-comma locales, large text and representative fractional targets on devices. | Revert formatter/UI commit; stored precise values remain unchanged. |
| 25 | **FIXED IN SOURCE; DEVICE TEST PENDING** | Navigation state was restored indiscriminately after meaningful absence. Candidate distinguishes short interruption/in-progress input from a long resume that returns to Dashboard. | Responsive app shell/startup/lifecycle routing. | Source/runtime resume contracts exist; final focused run pending. | Short vs long background, process death, deep link, active form, lock/unlock on both platforms. | Revert resume policy commit; no data rollback. |
| 26 | **FIXED IN SOURCE; DEVICE TEST PENDING** | Entitlement hydration briefly rendered an unauthenticated/free gate before cached/server state resolved. Candidate keeps a fail-safe loading surface and prehydrates verified state without indefinite unlock. | Premium route glass gate, commerce providers and startup profile restore. | Commerce hydration/protection tests exist; final run pending. | Paid, expired and revoked accounts after short/long resume, offline start and reinstall on TestFlight/Play-signed builds. | Revert hydration UI/provider commit; never compensate by manually granting entitlement. |
| 27 | **FIXED IN SOURCE; VISUAL ACCEPTANCE PENDING** | Owner requested a slightly larger/wider identity lockup. Header/wordmark sizing was adjusted within responsive constraints. | Dashboard header/top bar and shared wordmark. | Dashboard identity/header layout and wordmark tests exist; final goldens pending. | English/Arabic, narrow phone, large text, tablet and dark mode visual approval. | Revert the small presentation-only sizing commit. |
| 28 | **FIXED IN SOURCE; DEVICE TEST PENDING** | Quick Add reused a Dinner-scoped search route. Candidate opens a general food flow and keeps meal choice explicit/context-aware. | `lib/app/router/bil_quick_add_sheet.dart`, daily-log navigation/search. | Quick-add semantic/barcode/navigation tests exist; final focused run pending. | Launch from every shell state, choose each meal, cancel/back/deep link on iOS/Android. | Revert routing commit; logged food rows are unaffected. |
| 29 | **FIXED IN SOURCE; DEVICE TEST PENDING** | The primary Today label combined consumed and target despite the requested consumed-only hierarchy. Candidate formats the main value as consumed grams and moves target/progress to secondary UI. | Daily-log summary widgets and macro formatter. | Daily-log live macro/meal goal and visual tests exist; final run pending. | Representative zero/fraction/large values, RTL and large text on phone/tablet. | Revert summary presentation commit; nutrition records and targets are unchanged. |
| 30 | **SERVER TEST PASSED; APP E2E PENDING** | Username uniqueness must be case/normalization safe and race-safe at the database, not a client precheck. The live Social v2 migration is present and must not be rebuilt. | Social v2 identity schema/functions and community identity projection/repository. | Local SQL/contracts exist; server reconciliation and a live concurrent-claim canary are pending final record. | Two simultaneous claims differing by case/Unicode normalization; rename/reuse policy and suspended/blocked behavior. | Correct only with a forward migration. Never drop/recreate profiles or expose email. |
| 31 | **SERVER TEST PASSED; APP E2E PENDING** | Username lookup and friend request flows are implemented without email discovery; UX and concurrency still need real accounts. | Community people/connections/friends pages and Social v2 functions. | Community profile discovery/connection/friendship tests exist; final live E2E pending. | Search exact/partial/nonexistent/private/suspended users; request race, duplicate, accept, remove and block. | Revert Flutter discovery UI; backend correction via forward migration only. |
| 32 | **SERVER TEST PASSED; APP E2E PENDING** | BIL public code is identity discovery only, never authentication. Social v2/public projection exists; scanner/share lifecycle must be tested. | Community identity/profile/invite UI and Social v2 QR/public-code resolver. | Community profile identity/discovery and invite/deep-link tests exist; final live scan pending. | Share/scan with Play/TestFlight signing, rotate code if supported, wrong/expired/tampered code, blocked/suspended target, camera denial. | Revert client QR UI. Rotate only the test public code through its normal RPC; never delete the user. |
| 33 | **FIXED IN SOURCE; DEVICE TEST PENDING** | Same root cause as IDs 02/03: list direction/controller and async rebuilds did not preserve the bottom anchor. Both chats now share the same viewport contract. | `chat_history_viewport.dart`, Community chat and AI Coach integrations. | Shared viewport and community chat refresh tests exist; final focused run pending. | Two-account Friend Chat and live AI reply with history prepend, keyboard, near-bottom/reading-history behavior, RTL and rotation. | Revert shared viewport integration; conversation rows remain untouched. |

## Cross-cutting production changes already verified

- The public Community Guidelines page is live in English and Arabic at the
  real BIL domain; Cloudflare Worker version
  `f8023569-4367-4a8a-9f4a-3ce8efbf77e0`.
- Supabase migration `20260908032057_community_policy_v1_activation` created
  exactly one active `community-policy-v1` row. No user acceptance was created.
- A runtime SQL regression exposed and rolled back a bilateral-message-block
  visibility defect. Forward migrations
  `20260908032453_community_message_block_visibility_hardening` and
  `20260908032558_community_block_pair_uuid_lock_fix` corrected it. The final
  rollback test passed and left zero fixture residue.
- Forward migration `20260908141133_harden_public_default_table_privileges`
  passed its transactional pre-probe and post-apply rollback test. It hardens
  future `postgres`-owned `public` relation defaults only; there was no
  business-data, RLS, existing-table ACL, table, or role change.
- Forward migration `20260908175000_community_policy_storage_upload_guard`
  closes pre-acceptance/suspended-user Community Storage uploads with a
  restrictive policy while preserving the existing owner/path policy.
- Forward migrations `20260908180500_community_policy_version_immutability` and
  `20260908181500_community_policy_ledger_postconditions` make policy identities
  append-only and reject delete, reactivation and privileged `TRUNCATE`. The
  final live rollback fixture passed with zero residue; policy v1 remains the
  only active row and production acceptances remain zero.
- Forward migration
  `20260908235044_harden_legacy_community_writes_and_reports` removes broad
  authenticated writes from the legacy posts/messages/reports tables, retains
  only reviewed column-scoped writes, runs the post moderation guard on every
  update, and enforces bounded report writes. It changed no business rows, no
  RLS policy, no Social v2 table, and no user acceptance; fresh readback aligns
  all 124 local and live migration versions.
- The Community Guidelines URL was appended to the existing Apple `en-US` and
  Google Play `en-GB` descriptions. Independent readback and idempotent second
  runs passed; no build, submission, track or release setting changed.

## Store-console audit — current read-only evidence

- Google Play Console currently shows Android version code `8` / `1.0.0` as an
  active Closed testing - Alpha full rollout (177/177 testers; 0.00% install
  base), not a production rollout. Production is inactive while the
  production-access application is under review. Managed publishing is on, and
  one `en-GB` full-description change is ready to publish; it was not
  published. This reinforces, rather than closes, the device/store gates in
  ID 22.
- App Store Connect's retained tab is at the Apple Account sign-in screen with
  `authResult=FAILED`. No login was attempted. Therefore the current Apple
  version/build/review status, subscription blockers, and precise red
  `MISSING_METADATA` text remain unverified; the previous generic status is not
  a safe basis for metadata changes.

## Unresolved external security configuration

- `auth_leaked_password_protection` remains a release/security decision. The
  read-only Supabase console shows `BIL Health` is on the Free plan and labels
  the control as available only on Pro and above. Email provider and secure
  email change are enabled. This is blocked by plan, not a database migration
  defect; no setting was changed.

## Release boundary

IDs 01, 17, 22 and 23 remain open/audit blockers. Every item marked device or
App E2E pending remains a release gate even where source tests pass. The
portable suite and backend reconciliation are complete; the
leaked-password-protection plan decision is unresolved. The app must not be
described as release-ready until signed artifact provenance, the visual and
Gate F/G device/store matrices, live Edge/device-integrity canaries and the
three pre-existing App Attest fixture failures are closed, Google Play
production access is approved, and current Apple review/metadata state is read
from an authenticated console.
