# BIL pre-build repair contracts — 2026-10-04

This is an engineering contract, not a release approval, owner signature, or
evidence of a new mobile artifact. Android 31 and iOS 34 source/manifest bindings
remain protected. The current candidate is on a separate repair branch.

## Backend and privacy

These are candidate source and isolated SQL contracts. All three new forward
migrations remain unapplied in Production at this checkpoint.

- Creator metrics obey the applicable owner/public visibility flags; hidden
  metrics and badges derived from them are absent, not fabricated zeroes.
- Legacy identity search obeys discoverability, privacy, suspension, blocking
  and the canonical search rate bucket. It is not an unmetered alternate route.
- Invitation access takes the canonical member-state lock before the owner
  quota lock. Suspension versus a waiting invitation is tested using separate
  PostgreSQL sessions and the genuine administrative suspension function.
- A suspended owner may clear the location through the narrow deletion contract;
  the exception must not permit general post editing.
- Draft readback re-evaluates present mention/collaborator privacy. Multiline
  drafts retain safe line breaks while unsafe control characters are rejected.
- Single-choice poll writes serialize per owner and post.
- No direct authenticated/anonymous application-table access is added.

## Durable publishing and Storage

- A journal is persisted before begin/upload. Retries retain the same owner,
  operation UUID, post UUID, immutable canonical payload and object paths.
- Post, media, metadata, reference context, poll and draft consumption commit
  atomically. A lost response is not permission to create a second post.
- Journal tables are RPC-only. New identifiers have bounded issuance; retries
  for an existing identifier do not consume that issuance allowance again.
- An authoritative abort is the only authority for media cleanup. Missing,
  contradictory or mismatched receipts never authorize deletion.
- A committed receipt is not success if the current post projection is absent
  or differs. Its explicit, verified `unavailable` response can abandon only
  the local pending journal; it permits no Storage cleanup or success claim.
- Aborted tombstones cannot be reused by a delayed begin/commit. Upload and
  abort races are serialized. Approved post-image paths cannot be replaced
  with unreviewed bytes while preserving an approved post.
- Ordinary moderation approval, counters and poll votes are not immutable
  payload mutations and must not invalidate an otherwise genuine receipt.

## UI and asynchronous state

- Activity filtering/paging is server-authoritative with a stable tuple cursor.
  Late results cannot overwrite a different filter or refreshed state.
- Mark-viewed failures are represented as failures, not successful acknowledgements.
- Voice manual edits update the real acceptance control. Its controller stays
  alive until the dialog's closing route completes; late capture callbacks are
  ignored after closure.
- Replies remain collapsed until requested, with View / Load more / Hide
  controls. Late reply pages cannot overwrite an authoritative refresh.
- Topic/Circle views come from batch server metadata. Missing values are omitted,
  not shown as fabricated zeroes. Paging failures preserve retry state.
- Creator/profile layouts expose full, reachable content at the tested small
  Arabic/English large-text viewports; tested scope is not all-screen certification.
- Profile, Saved, My Posts and Gold history refreshes reject stale pages and
  cursors. The Gold regression reproduced a cursor changing from 72 to 41;
  current Arabic/English tests retain 72 and request the next genuine page.
- Moderator lookup coalesces concurrent cards per authenticated owner, with
  bounded caching, refresh invalidation and stale-positive rejection. Server
  authorization is unchanged; the cache is not mutation authority.

## AI, commerce, profile and catalogs

- A withdrawn AI consent remains owner-scoped and fail-closed until a later
  explicit server write/readback proves renewed permission. UI state alone
  never grants consent; remote memory/context follow the same decision.
- Boost purchase updates are serialized, bounded and idempotent. A replayed
  credited receipt cannot complete or cancel another pending purchase.
- A verified credit is not revoked by an ambiguous native finish response;
  the finish warning remains distinct from the authoritative credit result.
  Three actual Settings host cases now prove zero access before verification,
  rejection without credit, verified page/Coach/Vision reloads despite pending
  native finish, duplicate-receipt idempotency and a second distinct consumable.
  They execute the default service and real SDK/loaders with controlled HTTP
  and public native-platform boundaries, not a real store transaction. Initial
  diagnostics showed the genuine async owner stream's first emission produces
  a fourth initial usage request, not a broken credit refresh. The fixture now
  settles that real owner before mounting the authenticated route; every exact
  three-loader purchase-refresh assertion and original time budget is retained.
  Only after that runtime proof was the stale source-state assertion replaced
  with the real verified-credit revision/listener contract; both file cases pass.
  Setup, auth and owner readiness are now inside failure-safe fixture cleanup;
  the three Settings cases pass again after that test-only correction.
  Two further source-contract failures were traced before changing assertions:
  the Settings v3 write moved into the shared verified-consent coordinator, and
  recipe deep links moved from a raw Free-plan branch to the actual shared
  expiry-aware detail gate. Current coordinator behavior and delayed real-route
  regressions support those contracts; their five preserved/strengthened source
  cases pass. This does not establish mounted consent-write or Production/native
  purchase success. Historical failure logs remain unchanged.
- Recipe deep links use the existing authoritative access gate. Loading is not
  Free, and cannot redirect a Premium user to Plans. Two delayed-repository
  regressions reproduced the previous redirect and passed after the repair;
  eight affected recipe and keyboard-access contracts also passed. These use
  genuine application repositories and route widgets with explicit HTTP/Auth
  fixtures, not current native purchase evidence. Final committed QA remains
  required after subsequent source changes.
- Profile writes validate values and commit as one local transaction; a failed
  write retains the prior canonical state. Hydration errors have bounded retry.
- Macro and exercise-calorie preference writes recheck authoritative access at
  the action boundary. Two actual-page regressions first proved that an expired
  verified subscription could still write through an already mounted control
  before its next frame. The repair rejects those writes; 26 affected host tests
  pass against the current sources, with scoped analysis reporting zero issues.
  Raw subscription rows and the prior Premium-looking widget are not authority.
- Customize Today had the same independently reproduced expiry boundary: a
  stale Premium snapshot opened the paid chooser and an already-open Save wrote
  `fat,fiber` after actual access became Free. Two default-repository/SDK-auth
  host regressions proved both failures and a genuine initial paid save control.
  The page now watches the existing expiry-aware verified access provider and
  rechecks it when opening and saving. Twelve affected cases pass. Two legacy
  fixtures lacked any validity period; only their explicit dates/clock and proper
  page unmount were repaired, retaining all write and navigation assertions.
  Fourteen affected normal golden comparisons now pass against this new source.
  The dated Premium capture additionally proved a test-only nested-scope defect:
  direct fixture reads were Premium, while the unscoped derived access provider
  correctly read its root container's Free default. Moving only this fixture's
  snapshot and clock to the root scope fixes that mismatch, with explicit raw,
  clock and derived-access assertions retained. No production guard or golden
  image was changed for this fixture repair. Capture cleanup now unmounts in
  `finally`, including on assertion failure. All 24 actual-page matrix cases
  subsequently completed successfully against this expiry-hardened source,
  before an independent later test fixture failed in the same portable batch.
  The Low Carb scroll fixture also lacked its period and used the wrong clock
  identifier during its first repair attempt. Its explicit current dates/clock
  and failure-safe unmount now retain all scroll, subscription-count and durable
  save/failure assertions; all four Arabic/English cases pass.
- Catalogs enforce HTTPS, safe paths, bounded compressed/decompressed sizes,
  integrity and safe filesystem publication. Failed installation preserves the
  prior verified catalog. No performance/source thresholds are increased.

## Owner screenshot additions

The owner's four supplied photos add three explicit requirements. Completion
of these additions must be backed by current tests, not by the older Community
matrix or screenshots of a previously built app.

- Sleep presents a verified Apple Watch source as the literal `Apple Watch`
  in every supported locale. Raw source identifiers and stored provenance remain
  unchanged. An unknown HealthKit identifier alone does not prove a watch source;
  other manufacturers must not be mislabeled as Apple Watch.
- Today's Body context shortcut removes its decorative note icon and resolves
  authored context labels in all 25 supported locales. Arbitrary private notes
  and Other text remain the owner's text, not automatically translated or sent
  to a remote service.
- Daily reminder controls and Community push categories have distinct delivery
  contracts and masters. Their layout and effective indicators must reflect
  those contracts without silently opting a user into remote push. Saved category
  selections survive a disabled master, but must not falsely indicate active
  delivery while the master/provider/permission is off or unknown. Saving must
  preserve the page instead of flashing a replacement loading/empty state.
- Before repair, real notification save/load and page tests reproduced 12
  failures: an explicit Friend Accepted opt-out re-enabled itself; corrupt or
  legacy preferences inferred opt-ins; unsuccessful persistence reported success;
  unsupported category controls accepted gestures. These are not closed merely
  because a repair is present. Current regression results are required.

Current Sleep/Body host evidence is recorded separately: 60 actual-page locale
tests passed at 320 x 568 / 200%; 73 affected tests passed, including two genuine
gateway/SQLite cache regressions; and 32 Today route/layout tests passed under
English/Arabic, iOS/Android host themes, widths 320/390/430/600 and 100%/160% text.
The cache regressions first failed because equal-timestamp retained projections
dropped newly read native device metadata. The repair updates only otherwise
identical sleep projections and preserves the deeply identical canonical raw
records and their provenance across gateway relaunch.

These tests use native-channel protocol fixtures, not a physical HealthKit
device. The all-locale page tests use the default light theme, not a full dark
or pixel-golden certification. Private free text is explicitly tested unchanged.
Recipe loading/re-entry regressions now finish within the existing 30-second
per-case budget, without increasing it. Counts overlap and must not be added
together as a unique test total.

The expiry-hardened Customize Today source passed 24 actual-page configurations:
English/Arabic, light/dark, 100%/160%/200%, and 320x568/430x932. The matrix uses
actual pointer gestures for nine switches, real on-disk SQLite commits and
re-entry/reopen, the real Free preview/Plans route and a dated host Premium
fixture for nutrient selection/save. It first exposed a 262-pixel Free-sheet
overflow and a 75-pixel Arabic Premium options viewport unable to contain a
complete option. The repaired existing sheets scroll their full meaning while
retaining the fixed, reachable action and their original gates. The complete
portable batch's exact completed matrix-file scope establishes those 24 cases;
the later independent Low Carb fixture failure remains recorded separately.
This is host behavior evidence, not native pixel,
purchase or all-screen certification.

Notification regressions now cover 14 actual SDK/mocked HTTP transport cases,
45 actual page/controlled platform cases across the scoped final logs, and the
changed source/localization contracts. Before repair, denied OS permission also
made a saved Community master appear OFF and prevented a direct OFF gesture;
the repaired master shows saved opt-in separately from effective delivery, and
the real OFF gesture commits disable while category checks remain inactive.
Ordinary Daily ON no longer invokes an activation notification. Native rollback
is attempted independently when durable persistence and its rollback both fail.
These are host/controlled native-gateway proofs, not physical notification pixels,
APNs/FCM delivery, an all-language/dark-device matrix or Production RPC proof.
No new mobile build has been created to apply these changes to the owner's
installed application.

## Notification server authority

- The exact live queued-retry implementation reproduced a committed opt-out
  bypass for message, friend-request and friend-accepted categories. The same
  three assertions pass against the new forward migration in an isolated
  PostgreSQL17.11 database, not Production PostgreSQL17.6.
- Durable desired categories belong to the authenticated owner, including an
  owner with zero tokens. The private table remains RPC-only with RLS and no
  direct CRUD privileges for anonymous, authenticated or service roles.
- New writes require an owner-scoped revision CAS and an authoritative receipt.
  A stale snapshot fails with 40001; the client must not automatically replay it.
- Registration and retry claims share the owner serialization guard. Rotation
  cannot reset a stored opt-out. A queued retry rechecks current owner, token,
  master and category before claiming, but cannot recall an already-sent provider
  request.
- Unknown, divergent and unsynchronized state is not active verified delivery.
  Recovery must be explicit and preserve the existing server desired categories;
  no local default or hidden master opt-in may authorize it.
- Existing legacy full-snapshot writes retain their compatibility contract and
  are not CAS-safe. No all-client-version race guarantee is asserted.
- Local evidence includes 10 verbatim live function identities, 28 ordinary-role
  security/readback assertions and three actual concurrent-session races. It is
  not Auth-service/JWT, APNs/FCM, physical OS delivery or Production evidence.

The notification migration is unapplied. The focused Production draft inventories
68 tables before and after its rolled-back transaction. It must never invoke a
global claim or registration against real queued notifications or provider tokens.
Its database exception block rolls back all block writes and reports explicit
FAIL, SQLSTATE, error and stack context before the final unconditional ROLLBACK.
Query transport success is not a PASS: require explicit PASS, every genuine
assertion and independent scoped zero-residue readback. Harmless configuration-only
executor probes established the reporting protocol, not application E2E success.

## Reviewer and store declarations

The dedicated Google reviewer uses ordinary authentication and the existing
owner-authorized administrative-gift contract. It is not a fabricated store
receipt or reviewer-only bypass. Its credential is stored privately outside Git.
The existing Apple reviewer credentials/account are not changed. Actual server
subscription, any existing closed-test overlay, and credits are accounted for
separately; none proves a new native purchase.

Current Google and unchanged Apple accounts authenticated against Production
and reached real AI Coach and advanced nutrition host widgets in English normal
text and Arabic 200% small/dark configurations. Google had 2500 credits and the
official administrative gift; Apple had 5000 credits and an existing verified
Google-provider subscription plus its pre-existing closed-test AI overlay.
This proves only those authenticated host paths, not all paid routes, an AI
provider response, device login, StoreKit or a new purchase.

App Store advertising and adult age-rating declarations were reconciled through
the scoped App Store Connect API and read back. Public privacy source now
describes eligible advertising on Android and iOS, including the actual no-script
fallback. A strict fallback regression failed on the old Android-only disclosure;
the current 10 public-copy checks pass. The obsolete one-off wiring helper was
removed from this repair branch after confirming no caller; its committed history
remains recoverable. A later read-only actual Play Sign-in details dialog confirms
the dedicated new Google reviewer is not present in the saved username field;
that dialog was closed without editing or saving credentials. Google sign-in
details, complete Data Safety/App Privacy reconciliation and device boundaries
require separate evidence; this document does not assert their completion.

The public static files were actually published with the existing owner-authorized
Cloudflare session using pinned Wrangler 4.125.0 `--no-bundle --keep-vars`.
This uploaded ready text/static files, without any mobile build or Worker
bundling. Version `0e4a66d2-b99c-4c5c-aa30-3ef24d0e1a5e` was deployed. Independent
GET-only verification at `2026-10-04T12:33:15.784Z` proves exact local/live app.js
byte identity (91,515 bytes, SHA-256
`fe4e2d57c36c870af6a63ae241206bef4b19afe1b1732796e813275c0cf5c533`),
index and app-ads byte identity, and direct HTTP200 for all four legal/support
routes. The immutable dated proof is
`BIL_EPIC15_PUBLICATION_VERIFICATION_2026-10-04.json`; the September proof is
retained unchanged. No legal approval is asserted.

Preflight also reproduced a genuine live/source association mismatch: the old
AASA had both existing auth-return paths but not `/invite/*`, so the current
worker rejected those captured bytes with HTTP503. Only the missing invitation
component was appended to the existing exact BIL app entry. Every existing
identity, auth component and unrelated property was retained; all three Android
certificate fingerprints and the entire assetlinks byte stream were unchanged.
Direct post-deploy GET proves the expected AASA and unchanged assetlinks bytes.
The existing deployment workflow now validates the actually captured documents
before uploading and preserves them byte-for-byte. This is not a signed-device
Universal Link or Android App Link opening test.

Actual Cloud Console readback confirms BIL Health / bil-health is linked to a
paid billing account. Read-only Production secret metadata matches the Vision
provider selector to the public `gemini` enum without disclosing any key. The
deployed key's full SHA256 now matches the existing BIL Vision Vertex Server key
in that actual paid project. The separately named Developer Gemini API Key does
not match; this is not itself a defect. A fresh full SHA256 comparison against the
official Express v1beta1 method now proves the nonempty configured base is
`https://aiplatform.googleapis.com/v1beta1/publishers/google`. Deployed Coach
uses that same Vision override; verified public models are Vision/fallback
`gemini-3.7-flash` and Coach primary `gemini-3.8-flash`. This is Vertex Express,
not an inference from the key label. Applicable signed processor terms and
project-level retention/logging still require verification. No provider request
or regional-processing guarantee is established. No key value/digest is included
in this contract, no key was
exported or changed, and the private display was closed. A genuine consented
provider response remains unproved; no payment/provider request was made here.

## Approval/signature register

| Item | Authority/evidence required | Current limitation |
| --- | --- | --- |
| Engineering source | Exact clean Git commit and current QA run IDs | Final commit/QA pending |
| Production changes | Exact staging Targeted + Candidate success, migration readback and rolled-back E2E | New migrations not yet applied |
| Reviewer UI | Ordinary authentication, authoritative plan/credits and real reachable gates | Two Production-backed host routes passed; native and remaining routes unproved |
| Native billing | Genuine StoreKit / Play transaction, verification, unlock and restore | Not established by mocked/host tests |
| Reference parity | Actual IMG_9451–IMG_9472 and strict element mapping | Original images unavailable in scoped inventory |
| Legal declarations | Owner's truthful review and signature where required | No owner signature fabricated |
| App signing | Later explicit build authorization and artifact verification | No build/sign/upload authorized |

The truncated Urdu FAQ medical disclaimer now retains all three limitations:
no diagnosis, no prescribed treatment and no replacement of a qualified clinician.
Its exact runtime lookup regression and three other locale/platform contracts
passed in the current full visual/architecture/asset invocation.
The historical blanket Data Safety CSV generator now refuses before reading
an input or writing a declaration; its one Node refusal regression passes.
It cannot be used to overwrite current disclosure answers with obsolete claims.

## Current source-gate checkpoint

The prior whole-project Flutter analysis completed with zero issues (145s).
The first exact formatter check identified only the two restored historical
recipe tests; the repository's Dart 3.12.2 formatter was applied to those files.
A subsequent full exact-toolchain readback formatted 2409 files with zero changes
and completed full Flutter analysis with zero issues (15.9s). After the final
repairs, exact formatting covers 2410 files with zero changes (8.72s), and the
current whole-source Flutter analysis reports zero issues (76.4s). These results
precede the clean source commit; later current GitHub runs must bind its exact SHA.

Twenty current pixel failures were inspected against their actual master/test
PNGs and source: four intentional Coach/Community changes, the real Activity
empty-state filters, the fail-closed notification state, and fourteen Customize
Today captures. They were stale references, not permission to hide product
failures. Only those selected goldens were regenerated, with all assertions and
pixel comparisons retained. The subsequent complete two-file visual run passed
185 cases and exposed only two additional 0.59% Body-context differences.
Both exact differences were the owner's explicitly requested icon removal,
already backed by the independent functional/localization tests. After inspecting
both pairs, only those two references were regenerated; both then passed a
normal pixel comparison without the update flag.

That same complete invocation passed four help-locale contracts, five strict
historical recipe asset/seed contracts, the unchanged architecture ceiling and
25 Rewards accessibility/source cases. Its original two pixel failures remain
recorded as failures, not retroactively relabeled. The repository's exact
code-only runner selected 1068 of 1102 files, with 34 policy exclusions and seven
mixed-name filters. Its serial performance budget passed; the historical run
failed on the obsolete Settings source assertion and is retained as failed.
Continuation retains completed unchanged green scopes, never labels unobserved
paths green, and checks source/dependency hashes before reusing them. A second
completed failure batch exposed the undated Low Carb fixture. Current full-file
reruns close those failures and the two subsequently traced stale source
contracts with the evidence described above, and the new actual
Settings regression expands selection to 1069 of 1103 files. All 1069 selected
file scopes are now completed, with zero missing and zero current failures, using
the same timeout, serial policy, 34 exclusions and seven mixed-name filters.
This is a source-bound continuation, not a rewritten historical runner result or
a claim that excluded/native/skipped tests ran. Three final failures were closed:
the genuinely unpublished privacy bytes required actual publication and GET proof;
five new publishing-recovery messages required an additive 25-locale runtime
catalog fix; and the obsolete HealthKit consent source assertion was updated only
after actual write/readback, durable withdrawal and owner/generation race tests
proved the current implementation. It now asserts the strict fail-closed ordering
instead of restoring the obsolete call.

Independent comparison verifies all existing catalog keys/cells/status/resolver
behavior unchanged and exactly 125 new lookups. All 18 localization files, both
runtime Community consumers, the complete Community reading/replies/friends
regression, legal validator, store materials, HealthKit disclosure and architecture
gate passed together (+322). A final normal two-file visual run passed (+190)
without golden updates. The complete Community visual matrix passed eight cases
(Arabic/English, light/dark, 100%/200%); 19 non-golden market-gate cases and the
single actual Settings artwork contract also passed. Case totals overlap earlier
evidence. Native language review, native store transactions and original missing
reference images remain separate unproved boundaries. Exact committed staging
Targeted/Candidate success is not asserted before those runs execute.

Fresh Production readback still contains 200 migration rows with all three new
repairs absent and the mention rate-limit contract present. Production reports
PostgreSQL 17.6; the provider's September 25 notice identifies 17.11 as the
security/correctness upgrade closing 44 upstream CVEs. No application legacy
PGP-cipher reference was found in scoped source or public database functions;
that does not establish that every upstream CVE is inapplicable. Runtime upgrade
and its maintenance impact are a separate unresolved infrastructure/security
decision, not silently performed or excused by PostgreSQL17.11 fixture success.
See the [provider notice](https://supabase.com/changelog/postgres-15-19-17-11-breaking-changes).

The staged Git blobs were compared with all 3517 source-bound working files:
zero byte mismatches. Historical canonical recipe evidence retains its original
51,083 CRLF terminators, explicitly recognized at that exact path by Git's
`cr-at-eol` attribute; neither serialization nor its audited data is rewritten.
Git whitespace diagnostics are not asserted to be zero: four trailing spaces
inside verbatim live function bodies (atomic baseline lines 523/600/2553 and
notification baseline line 10), plus final blank lines in eleven new SQL/fixture
runner files, are INTENTIONAL / ACCEPTED serialization/cosmetic occurrences.
The exact files are the two privacy/notification migrations; atomic live baseline,
atomic live moderation, Production rollback script, push live baseline; privacy
isolated runner/SQL; notification isolated runner/SQL/seed. Their audited raw bytes,
strict baseline SHA/function-MD5 checks and executable statements are preserved.
No wildcard whitespace suppression, gate threshold change or test weakening is
used; the finite diagnostics remain recorded outside Git.

The existing local Android upload certificate was listed without exporting or
using its private key. Its certificate is valid from 2026-08-16 to 2054-01-01;
the exact public fingerprints are recorded in the disclosure reconciliation.
The actual Play Console upload-key SHA-1/SHA-256 match that local certificate.
The distinct actual Console app-signing SHA-256 is present in the independently
fetched HTTP200 www assetlinks JSON. Existing other fingerprints were preserved.
This is not an installed-device deep-link test. Official read-only Apple API
responses also confirm the Distribution certificate/team and one exact-BIL ACTIVE
App Store profile expire on 2027-08-26. An older INVALID profile is preserved,
not treated as the only available profile. GitHub private-keystore/profile identity
and actual native signing remain unverified. No legal-owner signature was made.

Final verdict remains **NOT READY FOR BUILD** until every release-critical
finding and required evidence boundary is closed. Passing a narrower test does
not override this rule.
