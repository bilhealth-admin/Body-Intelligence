# Free Community and friendships — 2026-09-10

Owner request: make Community and friends Free. This is a feature-access change,
not a complimentary Premium grant and not a change to AI tokens or store plans.

## Implementation and deployment

- All 13 existing Community route-gate callers now return their content without
  consulting subscription, storefront or administrator providers.
- People search and incoming friendship requests expose their real actions to
  Free accounts. The paid fallback buttons and unused locked-request card were
  removed. Sign-in, repository error handling and single-flight actions remain.
- `communityFriends` belongs to `FreePlan`; paid plans inherit it. Existing
  localized friends/messages labels appear under Free, not paid-only benefits.
- Supabase migration `20260910090403_community_and_friendships_free` was applied
  successfully to `tgmanzhqulksykhslrzb`. The local migration uses the verified
  server-ledger version.
- Only `bil_friendships_require_premium` and its trigger function were removed.
  The migration requires the ownership and suspension guards, RLS and correct
  authenticated/anonymous RPC grants before removing the payment gate. Historical
  migrations retain the former implementation; no relationship data was deleted.
- Before/after catalog fingerprints were identical for Community table RLS/ACLs,
  Community policies and every other public/private function. Post-deployment
  reads confirmed the payment trigger/function absent. No customer account,
  relationship, purchase, entitlement, policy acceptance or token data was edited.

## Verification

| Check | Result | Evidence |
| --- | --- | --- |
| Requested Free behavior, before implementation | FAIL | Four new/updated expectations exposed the old route, request, acceptance and entitlement gates |
| Final Flutter tests | PASS | 332 tests; all Community tests plus selected commerce/entitlement and SQL contracts |
| Isolated PostgreSQL tests | PASS | 45 checks: 21 admin subscription, 10 token reset, 14 Free friendship checks |
| Final targeted Flutter analyzer | PASS | Seven paths/groups, no issues; 20.3 seconds |
| Formatting | PASS | 12 changed Dart files, zero formatting changes |
| Node syntax | PASS | `node --check supabase/tests/community_free_access_test.mjs` |
| Git whitespace validation | PASS | `git diff --check` |
| Live migration and unchanged security boundaries | PASS | Deployment success, server ledger and matching pre/post catalog fingerprints |
| New signed build / device verification | NOT RUN | No build, simulator, emulator or device run for this change |

The 14 PostgreSQL checks execute actual repository friendship RPCs, RLS and
triggers in isolated PGlite, without live accounts. They prove Free requests,
duplicate handling, recipient-only acceptance/decline, server timestamps,
anonymous denial, anti-impersonation, blocks, suspension, opt-out and rate limits.
The fixture covers friendship dependencies, not the entire production schema or
independent-session lock contention. Flutter checks additionally cover Community
policy acceptance, moderation, account switching, messages and BIL friend codes.

Final Flutter command: `flutter test --no-pub --concurrency=1` with
`test/features/community`, selected commerce tests and the friendship/social SQL
contract tests; `--name '^(?!.*visual proof)'` excludes the existing golden case.
Log: `G:/BIL_Temp/community-free-20260910/flutter-tests-final.log`.
Database command: `npm test --prefix supabase/tests`.

The first baseline invocation of the legacy gate-test file also ran its existing
golden comparison. Final verification excludes that case; no device behavior is
claimed from any of these tests.

## Existing security notices and release boundary

Supabase advisor results were unchanged before/after: 44 INFO notices for
[RLS-enabled internal tables without client policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
67 WARN notices for callable
[security-definer RPCs](https://supabase.com/docs/guides/database/postgres/row-level-security#use-security-definer-functions),
and one existing warning for disabled
[leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
This targeted change does not claim to close those broader security notices.

The server change is live. Installed mobile builds still contain their old UI
gates and require a new application build. No commit, build, store-price change
or TestFlight upload was performed here. Pre-existing Coach-scroll and More
section-heading changes were preserved untouched.
