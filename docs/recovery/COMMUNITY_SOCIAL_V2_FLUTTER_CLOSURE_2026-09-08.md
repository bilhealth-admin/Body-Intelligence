# Community Social v2 Flutter closure — 8 September 2026

## Scope and evidence boundary

This report records the non-visual Flutter closure for Community, Friends, post
detail, and the shared chat viewport. It covers source inspection, local host
tests, and a read-only review of the four Social v2 forward migrations named
below.

This closure did **not**:

- execute SQL, replay a migration, or write to production Supabase;
- create a friendship, policy acceptance, entitlement, save, public code, or
  any other production row;
- run, inspect, or update a Golden test image;
- run on a signed iOS or Android device; or
- perform a real multi-account production session.

The parent reconciliation identified migrations `20260908181700`,
`20260908181900`, `20260908182000`, and `20260908182100` as applied. That live
application status is an upstream result, not an independent backend readback
performed by this Flutter closure.

## Outcome

The requested non-visual client surfaces are implemented and pass the local
host regression boundary:

- the feed has authoritative likes, comment counts, saved state, author handle
  and relationship hydration;
- feed pagination uses a stable `(created_at, id)` cursor rather than offset
  pagination;
- post detail supports likes, comments, one-level replies, comment likes,
  delete, report, block, pagination, selectable text, and a bottom composer;
- a stable caller-supplied UUID is retained across a failed comment retry, so a
  retry cannot create a second logical comment;
- saved posts are a private repository-backed collection with pagination and
  explicit unsave;
- post sharing uses the native share sheet with the real post text. It does not
  invent a public post URL;
- profiles support a validated, unique Social v2 handle, while People searches
  handles and exposes explicit friend-request state;
- a BIL public code renders as a real QR containing only
  `bil://community/member/<32-lowercase-hex-code>`, supports explicit rotation,
  scans only the exact allowlisted payload, resolves through the server, and
  requires a separate **Add Friend** action;
- invalid, rotated, private, blocked, and suspended public codes share the same
  unavailable state instead of becoming an enumeration oracle;
- the frozen relationship contract is
  `self | accepted | pending | incoming | none`. A declined record is presented
  as `none` with `can_request=false`, which the client renders as unavailable;
- the moderator route remains outside the customer Premium gate and still
  relies on the server moderator-role check; and
- Community friend chat and AI Coach both use the shared bottom-anchored
  `ChatHistoryViewport`, including near-bottom follow, jump-to-latest behavior,
  history retention, and protection against yanking a reader to the newest
  message while older history is being read.

## Flutter contracts

### Data and domain

`community_social_repository_mixin.dart` is the typed boundary for Social v2.
It calls the existing base Social v2 RPCs for identity, handle search and claim,
post/comment likes, comments, reports, and friend requests, plus the forward
RPCs for saves, public codes, and post-author relationship metadata. UUIDs,
handles, public codes, relationships, response shapes, and input limits are
validated before data reaches presentation code.

`community_feed_repository_mixin.dart` composes post rows with three
authoritative batches: Social stats, private saved state, and visible author
metadata. A missing legacy handle does not break the entire feed and the client
does not fabricate an identity. The handle backfill migration closes that
legacy gap at the database boundary.

`community_post_cloud_store.dart` adds lookup-by-ID for private saved-post
references and cursor-based feed pagination. The new Social tables remain
RPC-only; Flutter does not add direct table joins or grants for saves, public
codes, handles, likes, comments, or friendship relationship metadata.

The domain models include typed Social identity, post statistics, comments,
saved-state/reference batches, public codes, resolved members, relationships,
and author Social metadata. `CommunityPost` can be hydrated without losing the
canonical base post fields.

### Presentation and routing

The feed, post detail, saved-post list, profile, People search, public-code QR,
scanner, and resolved-member screens are connected to those repository
contracts. Report, delete, block, rotate-code, and friend-request actions remain
explicit user actions.

The router exposes:

- `/community/code`
- `/community/code/scan`
- `/community/member/:code`

The deep-link parser accepts only the exact BIL member-code form. Customer
Community routes keep their existing Premium server-gated boundary. The
moderation route remains a separate non-paid role-gated entry point.

## Read-only review of the applied forward migrations

No migration was edited or executed during preparation of this report.

### `20260908181700_community_social_saves_and_public_codes.sql`

- Adds private post-save and opaque public-code tables without replacing Social
  v2 tables.
- Enables RLS and revokes direct table privileges from `PUBLIC`, `anon`,
  `authenticated`, and `service_role`.
- Exposes only authenticated, caller-scoped RPCs for save/set state, saved-post
  pagination, public-code load/rotation, and code resolution.
- Uses the real BIL URI scheme and a revocable random 32-hex code; it does not
  encode a user UUID, email, token, or health value.
- Preserves visibility, block, suspension, Community-access, rate-limit, and
  profile-discoverability checks.

### `20260908181900_community_social_post_authors_v2.sql`

- Adds `bil_social_post_authors_v2(p_user_ids uuid[])` with a maximum of 100
  requested users.
- Reuses the canonical profile-visibility and Community-access predicates.
- Returns only `user_id`, `handle`, `relationship`, and `can_request`.
- Does not expose profile/relationship tables directly to Flutter.
- Grants execute only to `authenticated` after explicitly revoking default and
  excess execution privileges.

### `20260908182000_community_social_post_authors_volatility.sql`

- Changes the post-author RPC to `VOLATILE` because its authorization result
  depends on current suspension and policy-acceptance state.
- Asserts that the `SECURITY DEFINER` and restricted execution-ACL contract was
  preserved.

### `20260908182100_community_social_handle_backfill_and_reply_visibility.sql`

- Generates only missing `chosen=false` handles and installs an insert trigger
  so every new public profile receives a generated handle.
- Does not rewrite existing chosen/generated handles and does not touch policy
  acceptances or entitlements.
- Makes comment statistics, comment listing, comment likes, and comment reports
  treat a reply as unavailable when its root comment is deleted, removed, or
  no longer visible.
- Reasserts authenticated-only execution and the empty `search_path`
  `SECURITY DEFINER` contract for the replaced RPCs.

The data effect attributable to the fourth migration is therefore limited to
generated rows for profiles that lacked a Social handle, plus future generated
handles from the trigger. This Flutter closure did not execute that backfill
and did not independently count its live affected rows.

## Verification

### Full analyzer

```powershell
C:\develop\flutter\bin\flutter.bat analyze
```

Result: **PASS**, `No issues found` (32.7 seconds).

### Focused Community Social v2 boundary

```powershell
C:\develop\flutter\bin\flutter.bat test `
  test\features\community\community_social_v2_ui_test.dart `
  test\features\community\community_bil_code_and_saves_contract_test.dart `
  test\features\community\community_feed_pagination_contract_test.dart `
  test\architecture_source_file_size_guard_test.dart `
  test\launch_readiness\deep_link_exhaustive_source_contract_test.dart `
  --reporter expanded
```

Result: **17 PASS / 0 FAIL / 0 SKIP**.

This boundary covers native save-state behavior, the private saved collection,
post detail, likes, comments, replies, reporting, blocking, retry-safe comment
identity, author handle/relationship presentation, strict BIL-code parsing and
routing, QR rendering and rotation, explicit friend request, unavailable code,
feed cursor/hydration, the deep-link allowlist, and source-size architecture
limits.

### Expanded non-visual regression boundary

The expanded command selected every `*_test.dart` file under
`test/features/community` except filenames containing `visual` or `golden`,
then added:

- the two Community moderator/member-access admin contract files;
- the shared chat viewport regression;
- AI Coach conversation/routing, message-text, history-retention, and
  answer-with-action regressions;
- the exhaustive deep-link source contract; and
- the architecture source-size guard.

It executed 34 files and finished with **224 PASS / 0 FAIL / 0 SKIP** in 1:27.
The selected sources contain no explicit `skip:` declaration. No Golden file or
Golden image was selected.

`git diff --check` also passed for the Community/router/deep-link/test change
set. The architecture guard passed with the reviewed large files below their
limits: `community_models.dart` 684 lines, `community_repository.dart` 689,
`community_feed_tab.dart` 697, and `community_post_detail_page.dart` 698.

## Deferred or unavailable evidence

The following are not closed by host Flutter tests and must not be described as
device- or production-certified:

- the intentionally deferred 29 visual/Golden tests and human visual review;
- signed iOS and Android runs, including camera permission/denial, QR scanning,
  keyboard insets, lifecycle resume, native share destinations, accessibility,
  and representative small/large screens;
- a real authenticated multi-account matrix covering post visibility, pending
  and accepted friendships, declined/unavailable requests, blocks, suspension,
  reports, comments/replies, saved posts, code rotation, and new policy-version
  acceptance;
- post-deployment live RPC smoke tests and a fresh production readback of the
  four migration versions and their postconditions; and
- realtime/push behavior under two physical accounts and adverse network
  conditions.

Consequently this report closes the assigned **non-visual local Flutter** scope.
It does not by itself open the signed-device, Golden, store, or production
release gates.

## Files in this Flutter closure

### Application source

- `lib/app/router/app_router.dart`
- `lib/features/community/data/community_feed_repository_mixin.dart`
- `lib/features/community/data/community_post_cloud_store.dart`
- `lib/features/community/data/community_repository.dart`
- `lib/features/community/data/community_social_repository_mixin.dart`
- `lib/features/community/domain/community_models.dart`
- `lib/features/community/domain/community_post_author_social.dart`
- `lib/features/community/domain/community_text_policy.dart`
- `lib/features/community/presentation/community_bil_code_page.dart`
- `lib/features/community/presentation/community_feed_pagination.dart`
- `lib/features/community/presentation/community_feed_tab.dart`
- `lib/features/community/presentation/community_hub_page.dart`
- `lib/features/community/presentation/community_people_page.dart`
- `lib/features/community/presentation/community_people_widgets.dart`
- `lib/features/community/presentation/community_post_detail_page.dart`
- `lib/features/community/presentation/community_post_widgets.dart`
- `lib/features/community/presentation/community_profile_page.dart`
- `lib/features/community/presentation/community_saved_posts_page.dart`
- `lib/features/notifications/domain/community_deep_link.dart`

### Tests

- `test/features/community/community_authenticated_interaction_test.dart`
- `test/features/community/community_bil_code_and_saves_contract_test.dart`
- `test/features/community/community_feed_pagination_contract_test.dart`
- `test/features/community/community_profile_discovery_contract_test.dart`
- `test/features/community/community_social_v2_ui_test.dart`
- `test/features/community/premium_friendship_server_gate_contract_test.dart`
- `test/visual_closure/actual_production_pages_golden_test.dart` — compile-only
  fake signature update; the Golden test was not run or reviewed.

The shared chat implementation and its existing tests were verified but were
not modified in this closure. The four migrations reviewed above were also not
modified by this Flutter closure.
