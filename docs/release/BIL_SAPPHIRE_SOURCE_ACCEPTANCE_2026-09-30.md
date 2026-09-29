# Sapphire Community and daily history — source acceptance evidence

## Provenance

Native Android 29 / iOS 32 base: 9f439cae97d72b784880a1b1ac4ef1d33ede30c1.
Retained functional fixes: 59839c7deb4d1cc860275b9e69578e299cc24d0a.
Verified runtime/test source: 5da2bbf3a3fbb17a05a18106a243b865aa862aa9.
Run: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/36640466225
Its staging commit is 1ccd8b8a263bdd54489406905a48cb67b7e55d47. The prepare job
commits reviewed images and test edits; every later job explicitly checks out
5da2bbf, recorded in its plan. The final docs-only freeze must additionally pass
its own exact-commit QA before build dispatch. Parent results are not inherited.

## Complete discovery and actual counts

1,032 test/**/*_test.dart files discovered. One performance file runs serially
first on Linux; all other 1,031 files run exactly once in eight Windows 2022
shards using Flutter 3.44.6. Zero path exclusions and zero test-name filters.
The assigned-file union equals discovery, no duplicates, all exit codes zero.

| Shard | Files | Passed visible cases | Conditional skips |
| --- | ---: | ---: | ---: |
| 0 | 129 | 599 | 0 |
| 1 | 129 | 716 | 1 |
| 2 | 129 | 738 | 0 |
| 3 | 129 | 942 | 1 |
| 4 | 129 | 645 | 3 |
| 5 | 129 | 839 | 0 |
| 6 | 129 | 549 | 0 |
| 7 | 128 | 624 | 1 |
| Performance | 1 | 2 | 0 |
| Total | 1,032 | 5,654 | 6 |

Zero failed cases and zero error events. Hidden loader/setup/teardown events are
not cases. The separately rerun 294 focused and eight visual matrix cases are
already represented in the full selection; do not add them again. SQL and Deno
are separate. The user's earlier local 5,530 has no matching per-case log here;
do not claim a precise reconciliation based only on arithmetic totals.

## Explicitly NOT executed conditional cases

1. test/launch_readiness/deferred_ios_google_mobile_ads_plugin_test.dart:
   symlinked override parent is rejected (existing Windows host condition).
2. test/features/meal_planner/existing_recipe_canonical_seeds_test.dart:
   content and image fingerprints reject all duplicate seeds.
3. test/features/meal_planner/generated_recipe_assets_test.dart:
   every catalog image is fail-closed or points to a present exact asset.
4. test/features/meal_planner/generated_recipe_assets_test.dart:
   generated image hashes are unique.
5. test/launch_readiness/visual_reference_evidence_truth_contract_test.dart:
   visual evidence check is truthful and read-only.
6. test/features/wellness/wellness_video_stream_live_test.dart:
   live public BIL stream supports pinned native range delivery.

Items 2-6 retain their pre-existing opt-in conditions; no new skip was added.
These files ran, but the conditional cases are not passed. Physical/native
integration_test remains separate from host tests and is not counted here.

## Test environment correction, not weaker assertions

Untouched 59839 was tested on Linux and Windows. Existing image references were
Windows raster output. On Linux the old helper used wrong-case Roboto and
MaterialIcons names and could silently substitute Montserrat. The helper now
loads exact SDK names and rejects silent substitution. Windows checkout uses
core.autocrlf=false to retain bounded/hash-addressed JSON bytes. No asset bound,
pixel tolerance or assertion was relaxed. The architecture marker-prefix scan
is byte-safe; full UTF-8 decoding and all source-size ceilings remain strict.

Only ten intentionally redesigned Community masters changed. Four additional
scoped Community images stayed identical. All other masters, including Watch,
are unchanged. The 14 images were individually reviewed and imported by exact
archive/PNG hashes, never regenerated during acceptance. The import record is
in tool/sapphire/reviewed_community_goldens.json with immutable input objects.

## Evidence artifacts for 5da2bbf

| Artifact | ID | Archive SHA-256 |
| --- | --- | --- |
| Source | 11066406318 | 44eb542611531c289a077302a7bd56ba400dfda0ec1f6454615ae244f55dc16d |
| Focus/performance | 11066711576 | 32a5b426963f7a7f51dbedbe142796b65a0dee878444ecec629bfb3422e6ede6 |
| Visual/SQL/provider | 11066592000 | ee3eb356968171a8aac2f7df77756242c067ac59be0d3159cb65abcd422cfdae |
| Shard 0 | 11066912488 | 240a9fccabc972b13142257a46e686013fe429090a924fc63b34ffbbf579c5eb |
| Shard 1 | 11067125407 | f397b45515a92ef052b33e188e1b9e562e2f7b238b11b20997f949117d9d5d91 |
| Shard 2 | 11066702452 | 84a98da4c1fd3dad83e5f2b7e5c20f083252fdea30b5643b7a85e262603fe721 |
| Shard 3 | 11066288105 | 991fea9537b999c520e0028e775ff2bd09bad5d9a4716c237246717e4ab4cf16 |
| Shard 4 | 11067040774 | f2e3ffbff6c174c8d1d5613ba31ec215f36a7f27bacf41a41dce36e4a6e015b3 |
| Shard 5 | 11067230560 | d765c48f0f18c22ddf96494b473b115c9d74d1ab117dc660848a241911d258c5 |
| Shard 6 | 11066213115 | 45fb5f81db53a0eecb8e7e33f8bee7fad3f77dadcb0fd3dcbd30ac1e909a508b |
| Shard 7 | 11067295222 | 04cde4fcd5993d63427df5c5fcaaf6b19686933a21028132b862adaa380d2111 |

## Implemented changes and boundaries

Community-only Sapphire palette/type/spacing, accessible content-driven inbox,
blue outgoing bubbles, cursor emoji insertion, Messages/action entries and shared
own-account unread badges. The local athlete welcome is scrollable, escapable,
indeterminate and reduced-motion-aware, without a forced timer. Its bundled
existing project athlete asset does not require a network request at entry.
No fake presence, calls, mutual-friend totals or activity is introduced.
120 actual-widget images cover 15 scenes in Arabic/English, light/dark, scale1/2.
Focused tests also cover 320px at scale3. Captures use test fonts and synthetic
accounts, not a real-device accessibility certification. Font files are not exported.

History has one daily energy total, preferring authoritative native day totals
and never adding cumulative snapshots; the imported-interval fallback is labeled.
Heart history shows one recorded-sample mean for completed days, separate from
resting rate, with a >100 informational day marker and first/peak timestamps.
It is not a medical diagnosis or continuous/background alarm. Completed days
refresh on next load/sync, not a guaranteed midnight job. Calendar/DST, repeated
sync, source correction, deletion provenance and raw-data preservation are tested.
Native Watch settings, queries, dashboard and current cards are byte-guarded.
Purchases, iOS/Google native login, Android Facebook/push fixes and QR privacy remain.

The live QR migration 20260929050616 and attention/read migration 20260929074359
were checked read-only. Counts/read RPCs are authenticated own-user only; the
arbitrary-owner badge RPC is service-role-only. No production health records,
messages, friendships or permissions were modified by this verification.
Disposable PostgreSQL:22 passed assertions. Mocked provider transports:12 passed.

No signed Android30 AAB/iOS33 IPA, store upload, repeated physical Facebook login,
real push registration/delivery or terminated-app tap is claimed. These remain
artifact/device acceptance after source freeze. Provider success alone does not
prove that a notification appeared on a phone.
