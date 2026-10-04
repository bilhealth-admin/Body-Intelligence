# BIL Production prebuild checkpoint

This engineering record binds the source, current CI and actual Production
boundaries inspected on 4 October 2026. It is not an owner signature or release
approval. **Verdict at this checkpoint: NOT READY FOR BUILD.** No mobile build,
store upload or submission was executed. The protected release remains
`555496ebb6d6d3952c9e69e7bb6b9788269b39fa`; Android 31 and iOS 34 bindings remain
unchanged. This document records a checkpoint, not an assertion that later work
has already succeeded.

## Exact committed source and CI

The repair source at `e82858bc75a45e1ae65617a34aa1d72389bb1d72` was pushed without
force to the separate repair branch and Staging. All three exact-SHA runs finished
SUCCESS: [Targeted 37203326213](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37203326213),
[Candidate 37203326160](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37203326160)
and [store backend 37203326148](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37203326148).
Candidate directly reported zero formatting changes, zero analyzer issues,
unchanged architecture/source/performance gates, visual/cloud checks and all four
portable shards green. The shards executed 1068 distinct assigned files with zero
missing, duplicate or current failed files. The separately executed performance
file makes 1069 selected files; 34 repository-defined excluded files were not run.
There were 5768 selected portable case successes, not 5768 native/device cases.
Store backend contracts remain mocked, not genuine store purchases.

The subsequent draft constraint correction changes SQL tests, one new forward
migration and documentation only. It must obtain its own green exact-SHA Staging
Targeted and Candidate results before Production application. Existing successful
evidence is not promoted to proof of the new SQL boundary.

## Permanent Production migration readback

Immediately before application, all 66 checked historical dependency function
bodies/signatures/grants matched the approved snapshots. Production contained
200 migration records. After the three applications, direct
`supabase_migrations.schema_migrations` readback at 13:04:36 UTC contained 203.
Each name appeared once, each entire stored SQL statement matched its source
literal, and the 24 candidate function bodies matched the source. MCP generated
the actual Production versions below; source filenames are not those versions.

| Forward source | Actual Production version | Source SHA256 |
| --- | --- | --- |
| community_prebuild_privacy_write_hardening_v1 | 20261004130400 | 625dedc4ace4c76267677c5fa2ea0849892f0d0699b6fbd7434aeef9d51d2951 |
| community_atomic_publish_operation_v1 | 20261004130406 | d7f830445bb172164d5146e2af69b01c03c5c0e7f79463a5249a1d96f277d15a |
| notification_delivery_preferences_authority_v1 | 20261004130413 | 80d86484d24e84b0e6b4e167c84d75021116beefcfb5b20167da67a92c3c32a4 |

New journal and notification-desired-state tables remained RLS-enabled and
RPC-only, without anonymous/authenticated/service-role CRUD. Public owner RPCs
and private helpers had their checked restricted grants and empty definer
search paths. No historical migration or Production migration history was edited.

## Production failures were investigated before any test change

The first focused Production SQL transaction failed at 13:05:54 UTC with
`42P10`: the test incorrectly used `ON CONFLICT(user_id)` for the actual
composite primary key `(user_id, policy_version)`. Before editing the test,
the actual application's default upsert was traced through its locked SDK:
it supplies no `onConflict`, so PostgREST uses all primary-key columns
([official contract](https://docs.postgrest.org/en/v13/references/api/tables_views.html#upsert)).
A separate ordinary-role Production SQL transaction at 13:08:04 UTC performed
that correct composite-key write twice and obtained authoritative accepted
policy readback with one row. It passed. Only then was the test corrected.
This proves the SQL policy boundary, not an HTTP/native sign-in boundary.

The corrected full transaction failed at 13:09:35 UTC with `23514` on the genuine
multiline draft RPC. The validated Production table CHECK rejected every control
character, while the genuine RPC explicitly permits LF, CR and TAB. This is a
**product defect**, not permission to remove multiline coverage. The original
isolated privacy fixture had omitted this table constraint and therefore could
not prove that Production boundary. Historical failure logs are retained.

Each failed full transaction and the focused policy proof unconditionally rolled
back. Separate precheck/residue calls inspected all 68 relevant tables and
reported zero synthetic residue, including Auth, posts, notifications, rate
buckets, drafts, collaboration, rewards and Storage metadata. No usable test
password or provider notification was created inside these transactions.

## Fourth forward correction and its limits

`20261004131411_community_draft_body_whitespace_contract_v1.sql` was created with
the repository's available Supabase CLI and has source SHA256
`405d9b859663158c66e3fd66acbfa4919df9af4b9a6d3ef7bfc19b8b76374cf9`.
It locks the single drafts table, requires the exact observed validated old
constraint, and changes only the CHECK to accept LF/CR/TAB. The 1200-character
limit and rejection of other controls remain intact. It adds no grants, rewrites
no rows and changes no function, RLS policy or historical migration.

The strengthened isolated PostgreSQL 17.11 tests first reproduce the exact old
`23514`, then apply the literal forward SQL. They passed 98 assertions and three
real overlapping role-session races; the atomic-publish suite passed its genuine
assertions and 11 real races with the same forward loaded explicitly. Tests cover
exact Arabic/English whitespace readback, 1200/1201 limits, all 29 remaining C0/DEL
controls at both RPC and CHECK boundaries and unchanged no-direct-CRUD contracts.
Production was PostgreSQL 17.6 at inspection: isolated success is not Production
success or a security upgrade. At this authored checkpoint the fourth migration
is unapplied and the full Production transaction has not yet passed.

## Release boundaries still unresolved

- Genuine StoreKit/Google Play purchase, pending/cancellation/failure, restore,
  backend verification, UI unlock and relaunch/expiry remain unproved by native
  store transactions. Contract/widget success is not substituted for that chain.
- The new ordinary Google reviewer account has a server-authoritative official
  gift and credits, but the latest inspected saved Play App access still lacked
  its credentials. Explicit destination approval is pending. Apple reviewer
  identity was not changed. Neither fact certifies every native paid route.
- Play Data Safety and Apple privacy field deltas are documented against actual
  declarations/source; remaining SDK traffic, tracking and owner attestations
  are not silently guessed or signed. Applied Apple advertising/adult-age fields
  are distinct from unsubmitted privacy declarations.
- Gemini's inspected actual endpoint is
  `https://aiplatform.googleapis.com/v1beta1/publishers/google` in paid project
  `bil-health`. Processor terms, retention/logging and a genuine consented remote
  response remain unproved; no secret is included here.
- Original Community reference images IMG_9451 through IMG_9472 were unavailable.
  Tested host layouts do not establish strict image-reference parity.
- Production PostgreSQL 17.6 needs a separate supported upgrade/impact decision
  against the published [Supabase 17.11 security notice](https://supabase.com/changelog/postgres-15-19-17-11-breaking-changes).
  No Production runtime upgrade/restart was performed. Leaked-password protection
  and refreshed advisors require explicit technical disposition, not blanket
  acceptance of warnings.

Community main promotion remains withheld until all stated release gates are
actually satisfied. Git commit authorship, public certificate hashes and this
engineering record are not legal-owner signatures or signed application artifacts.
