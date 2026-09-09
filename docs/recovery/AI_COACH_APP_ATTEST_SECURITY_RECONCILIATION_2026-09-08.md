# AI Coach, mobile integrity, and backend security reconciliation

> Supersession note (2026-09-09): this document preserves the historical v49
> security readback. The current active `ai-coach` is v51; all five downloaded
> bundle files exactly match the local source after newline normalization. The
> v51 delta adds explicit Gemini safety settings and fail-closed safety metadata
> handling only. App Attest remains v12 and was not changed by that deployment.

Date: 2026-09-08
Project: `tgmanzhqulksykhslrzb`
Working tree: `G:\BIL_Project\worktrees\bil-community-policy-recovery-20260908`

## Outcome

- The live `ai-coach` function is active at version 49. Its `index.ts`,
  `server.ts`, `deno.json`, and shared `mobile_integrity.ts` are byte-for-byte
  identical to the reviewed local sources.
- The live `app-attest` function is active at version 12. Its implementation is
  identical to the reviewed local source after ignoring one terminal LF byte.
- The live `play-integrity` function is active at version 23.
- No Edge Function deployment is needed from this lane, and none was made.
- The AI Coach answer-plus-action regression is fixed in the current source:
  a non-empty model answer is preserved together with its action, provenance,
  spoken answer, confidence, runtime, response ID, and service status.
- Conversation persistence, stable message/action identity, selectable text,
  timestamps, reverse-list bottom anchoring, and the near-latest-only scroll
  behavior are present and covered by passing Flutter tests.
- The three historical App Attest test failures were stale/incorrect fixtures,
  not evidence that the live verifier should be weakened. The fixtures were
  corrected, and all App Attest tests now pass.
- Live database security advisors currently return 103 findings: 40 INFO
  `rls_enabled_no_policy`, 62 WARN
  `authenticated_security_definer_function_executable`, and one WARN
  `auth_leaked_password_protection`.
- The arbitrary-key write-amplification risk in the legacy rate-limit RPC was
  identified during this review. A separate forward hardening migration is now
  staged as `20260908181600_harden_rate_limit_contract.sql`; it validates every
  reviewed action/limit/window tuple without mass-revoking callers.

This does **not** make Gate E complete. Signed-device canaries are deferred,
global integrity enforcement remains off, legacy App Attest compatibility is
still enabled, and leaked-password protection remains disabled.

## Live/local reconciliation

The source comparison used a Supabase API download into a temporary local
directory. It did not modify production.

| Source | Live/local result |
|---|---|
| `ai-coach/index.ts` | exact, SHA-256 `6A9B3B2F...61CE335` |
| `ai-coach/server.ts` | exact, SHA-256 `4DD94AA5...601369` |
| `ai-coach/deno.json` | exact, SHA-256 `D2DC61F6...63411` |
| `_shared/mobile_integrity.ts` | exact, SHA-256 `1EB46788...9DC69` |
| `app-attest/index.ts` | semantically exact; local has one additional terminal LF |

Live function metadata:

| Function | Version | Status | Gateway JWT setting |
|---|---:|---|---|
| `ai-coach` | 49 | ACTIVE | false |
| `app-attest` | 12 | ACTIVE | true |
| `play-integrity` | 23 | ACTIVE | true |

`ai-coach` validates the bearer token itself with `auth.getUser()` before
integrity checks, reservations, or provider calls. The gateway setting therefore
does not create an unauthenticated execution path in the reviewed handler.

The required App Attest and Play Integrity secret names are present. Values
were not printed. One-way fingerprint comparison confirms the two rollout
settings below:

- `BIL_MOBILE_INTEGRITY_ENFORCEMENT=off`
- `BIL_APP_ATTEST_ALLOW_LEGACY=true`

These are deliberate rollout settings, but they remain production risks. Do
not switch enforcement on or disable legacy compatibility without signed iOS
and Android canaries and an old-client transition decision.

## App Attest fixture correction

Only this lane's test fixture was edited:

- `supabase/functions/app-attest/index_test.ts`

That file was already untracked in the shared worktree before this lane edited
it. No production verifier source was changed.

The three failures and their confirmed causes were:

1. Apple's published sample attestation has validation category 1, which is an
   Apple OS executable, and bundle version `1.0`. A third-party BIL app must
   reject it; treating it as a positive production fixture was unsafe.
2. The synthetic assertions used a 37-byte legacy authenticator-data shape,
   while the verifier correctly defaults legacy compatibility to false.
3. The synthetic signatures signed raw authenticator data plus client hash,
   while the reviewed verifier binds the signature to
   `SHA256(authenticatorData || SHA256(clientData))`.

The corrected tests now:

- assert that the Apple category-1 sample is rejected with
  `invalid_validation_category`;
- encode the BIL bundle-version and validation-category extensions for positive
  third-party-app assertions;
- sign the exact nonce expected by the verifier;
- prove legacy assertion data is rejected by default and accepted only with an
  explicit compatibility opt-in;
- preserve rate-limit-before-persistence failure checks.

No legacy verifier behavior was promoted or deployed.

## AI Coach and conversation behavior

The current `IntelligenceCenterEngine.answer` checks whether a real answer is
present before using action-only local copy. Consequently:

- answer plus action returns both;
- answer-only remains unchanged;
- action-only retains the safe confirmation wording;
- blank-answer fallbacks still expose unavailable/degraded states;
- destructive/confirmation flags remain attached to the same action;
- urgent safety handling still precedes model/action routing.

The reviewed UI integration uses:

- a reversed conversation list with the composer outside the viewport;
- a shared viewport controller that follows the latest message only while the
  user is already near the latest end;
- no forced jump while the user is reading older history;
- a visible "latest messages" affordance when scrolled away;
- stable message IDs and persisted safe action links;
- queued, epoch-protected persistence so stale saves cannot replace the active
  conversation;
- local conversation archive migration without the old 20-conversation loss;
- selectable message text and timestamps on both iOS and Android widget paths.

The engine is 552 lines, under the 700-line architecture ceiling.

## Tests

Latest passing results on the current shared working state:

| Gate | Result |
|---|---:|
| Non-purchase Deno suite, 15 files | 100 passed, 0 failed |
| Flutter AI/conversation/integrity/admin suite | 234 passed, 0 failed |
| App Attest focused tests (included above) | 5 passed, 0 failed |
| AI Coach global reset focused test | 22 passed, 0 failed |
| Architecture source-size guard | 1 passed, 0 failed |
| Social saves/public-code static SQL contract | 3 passed, 0 failed |
| Rate-limit hardening static contract | 3 passed, 0 failed |
| Deno format check for App Attest fixture | passed |
| Deno lint for App Attest fixture | passed |

The Deno suite explicitly excluded `verify-store-purchase`, matching the owner
scope that purchases remain deferred. It covered App Attest, Play Integrity,
shared grant consumption, AI Coach, admin reset, push dispatch, food search,
account-deletion storage, Apple sign-in token lifecycle, locale, and GTIN logic.

No signed device test, StoreKit/Play Billing test, golden test, TestFlight run,
or store operation was performed by this lane.

## Security advisor audit

### RLS enabled with no policy: 40 INFO

The set contains 9 `private` and 31 `public` tables. All 40 have:

- RLS enabled;
- zero policies;
- zero `anon` table privileges;
- zero `authenticated` table privileges.

This is an intentional fail-closed RPC/server-only pattern, not an accidental
public exposure. Relevant mobile-integrity tables are
`bil_app_attest_keys`, `bil_mobile_integrity_challenges`,
`bil_mobile_integrity_grants`, and `bil_play_integrity_events`. They give no
client DML access; the exact bounded service-role grants are used by the Edge
Functions.

### Authenticated executable security-definer functions: 62 WARN

Read-only catalog inspection and local caller reconciliation found:

- `anon` can execute 0 of 62;
- all 62 have an explicit `search_path`;
- `PUBLIC`, `anon`, and `authenticated` cannot create in `public`,
  `extensions`, or `vault`, preventing caller-owned shadow objects there;
- 60 functions directly reference `auth.uid()`;
- the two exceptions are bounded boolean helpers used by a message RLS policy
  and moderation trigger:
  `bil_recipient_allows_community_message(uuid)` and
  `bil_has_community_moderators(uuid)`;
- no function contains dynamic SQL, `SET ROLE`, `ALTER ROLE`, dblink, or network
  execution;
- all are owned by `postgres`;
- every function has a local caller or database policy/trigger definition:
  45 Flutter-facing RPCs, 2 Edge-facing RPCs, and 15 DB-policy/trigger/nested
  RPC functions.

For the AI/mobile-integrity subset, all reviewed functions are caller-scoped,
have no anon execute grant, and are required by current app/Edge paths. A mass
revoke would break production. The current Supabase guidance nevertheless
prefers security-definer helpers outside exposed schemas, so these warnings
should not be declared "fixed" merely because their bodies are bounded. Any
wrapper/private-core redesign must be staged by domain with caller tests.

### Leaked password protection: 1 WARN

The advisor confirms leaked-password protection is disabled. Supabase documents
this feature as available on Pro plans and above. Enabling it is an Auth setting
change that requires plan confirmation and signup/password-reset regression
testing; it was not changed silently in this lane.

### Confirmed rate-limit defect and forward fix

The live `bil_consume_rate_limit(text, integer, integer)` accepted arbitrary
action names. Although a caller could not raise the real limit used by a
protected RPC, an authenticated account could create an unbounded number of
distinct bucket keys and amplify database writes.

The staged forward migration
`20260908181600_harden_rate_limit_contract.sql` fixes this without a mass revoke:

- preserves the existing function signature and authenticated/service callers;
- pins `search_path=''`;
- accepts only reviewed action/limit/window tuples;
- bounds the action string;
- preserves existing rows and business data;
- rejects unknown tuples with `invalid_rate_limit_contract`;
- retains explicit anon/PUBLIC denial.

The allow-list was reconciled against every live database body and every local
Edge caller. The migration intentionally aborts if historical bucket actions
outside the reviewed set exist, so its production preflight must be observed
before applying it.

## Read-only review of Social saves and public codes

The additive migration was renamed to
`20260908181700_community_social_saves_and_public_codes.sql` after the rate-limit
hardening migration was inserted before it.

Review result:

- two new tables are RLS-enabled, policy-free, and explicitly revoked from
  `PUBLIC`, `anon`, `authenticated`, and `service_role`;
- saves are keyed by `(user_id, post_id)` and every save/list/state RPC binds to
  `auth.uid()` and post visibility;
- six public RPCs use `SECURITY DEFINER`, `search_path=''`, and authenticated-only
  execute grants;
- the private helper is `SECURITY INVOKER` and not executable by API roles;
- public codes are random 32-hex UUID-derived identifiers with a unique index,
  rotation, and old-code invalidation;
- the resolver rate-limits first, bounds input to 32 bytes/characters, and
  returns the same null shape for invalid, rotated, private, undiscoverable,
  blocked, or suspended targets;
- relationship output is bounded to self/none/pending/incoming/accepted;
- no email, phone, health data, token, or acceptance receipt is returned or
  fabricated;
- the transactional SQL probe uses `BEGIN ... ROLLBACK` and covers save
  round-trip, rotation, privacy, blocks, suspension, and direct table denial.

Applying this migration will predictably add two intentional RLS/no-policy INFO
findings and six authenticated security-definer WARN findings unless the
advisor rules or architecture are changed. The functions themselves passed the
manual fixed-search-path, ACL, ownership, and enumeration review.

## Production changes and remaining blockers

This lane made no production data change, no migration application, no secret
change, no grant/RLS change, and no deployment.

Remaining blockers before Gate E can be called complete:

1. Apply and transactionally verify the rate-limit hardening and Social
   extension migrations only after their read-only production preflights pass.
2. Run signed-device App Attest and Play Integrity canaries before changing the
   two live rollout settings.
3. Decide and test the retirement window for legacy App Attest assertions.
4. Enable Supabase leaked-password protection only after confirming plan
   support and exercising Auth regression flows.
5. Treat the 62 existing security-definer warnings as reviewed-but-open
   architecture debt, not as cleared advisor findings.

## Official references used

- Apple, Validating apps that connect to your server:
  https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server
- Apple, Attestation Object Validation Guide:
  https://developer.apple.com/documentation/devicecheck/attestation-object-validation-guide
- Apple, Preparing to use App Attest:
  https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service
- Google, Standard Play Integrity requests:
  https://developer.android.com/google/play/integrity/standard
- Google, Integrity verdicts:
  https://developer.android.com/google/play/integrity/verdicts
- Supabase, Row Level Security:
  https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase, Database Functions:
  https://supabase.com/docs/guides/database/functions
- Supabase, Securing your API:
  https://supabase.com/docs/guides/api/securing-your-api
- Supabase, Password security:
  https://supabase.com/docs/guides/auth/password-security
- Supabase changelog snapshot reviewed on 2026-09-08:
  https://supabase.com/changelog.md
