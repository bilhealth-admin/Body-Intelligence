# BIL final incremental pre-build engineering closeout

**NOT READY FOR BUILD.** This closes the confirmed repair and scoped engineering
work below, not every store, native-device, privacy or privileged-behavior gate.
No app build, upload, review submission, history rewrite or owner's legal
signature was performed. Stop before build.

Snapshot: 2026-10-04, Production evidence through 18:25 UTC; branch reads at
18:28 UTC. Tested executable source:
`3f0085e6e6686f2e87e9cf14789e9e578ea64159`.
The separately pushed documentation-only descendant does not change that source.

## Current branch state

| Branch | Current verified HEAD |
| --- | --- |
| fix/admob-clean-production-2026-10-02 | 555496ebb6d6d3952c9e69e7bb6b9788269b39fa |
| work/community-reference-parity-20261003 | 89c3f87e4a42008cd683a5d5144c529a845f2d47 |
| staging/community-final-qa-20261003 | 3f0085e6e6686f2e87e9cf14789e9e578ea64159 |
| fix/community-acceptance-notifications-20261003 | 5cf93cab3d3826bd92689266766ff19350560bdd |

Work and Community main are ancestors of the tested source: work-only 0 /
candidate-only 8; main-only 0 / candidate-only 18. The protected release remains
untouched. Android 31/iOS 34 frozen manifest hashes are unchanged. Community
main promotion is withheld: the security/privacy/native release gates are not
all acceptable. There was no cherry-pick promotion, force push or rollback.

## Exact-source QA

| Evidence | Run / result |
| --- | --- |
| Targeted | [37222502029](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37222502029) — SUCCESS |
| Candidate | [37222502185](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37222502185) — SUCCESS |
| Store/backend contracts | [37222502031](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37222502031) — SUCCESS; mocked commerce/provider boundaries only |

Flutter 3.44.6 / Dart 3.12.2: exact formatting of 2411 files with zero changes;
full analyzer reports zero issues; unchanged architecture/Rewards accessibility
26 tests and existing performance budget 2 tests pass. Candidate's visual/cloud
job and all four portable shards pass. The downloaded plans/results prove
1069 unique executed portable files with no missing/duplicate assignment,
plus the separate performance file: 1070 selected of 1104 discovered, 34
explicit existing exclusions, **5773 passing portable test cases**.
Names/filters/exclusions and every batch exit code are in the receipt.

The original green runs were retained. These automatic new-source runs were
required by evidenced SQL/source repairs; no test was retried until green,
discarded or weakened, and no size/performance limit was raised. New SQL checks
use actual PostgreSQL 17 functions and ordinary roles in empty loopback fixtures,
including genuine overlapping sessions. Those races are local/CI evidence,
not Production concurrency, provider delivery or native-commerce evidence.

## Confirmed repairs

The [repair checkpoint](BIL_PREBUILD_LATEST_BOUNDARY_REPAIRS_2026-10-04.md)
records before failures, exact narrow changes and qualified local evidence.

| Severity | Confirmed boundary | Current scoped closure |
| --- | --- | --- |
| BLOCKER | Accepted collaborator identity ignores later privacy/block/suspension | Current visibility projection; real Production publish/moderate/accept and third-actor privacy proof below |
| BLOCKER | Cloud RPC/direct owner reads ignore missing/declined consent | Authoritative latest current-policy receipt, shared owner serialization and restrictive SELECT policies; Production negative/positive paths below |
| HIGH | Grant-only host lookup hides newer denial/version | Actual repositories use deterministic latest receipt, explicit ascending denial tie-break and post-await owner recheck; focused host/source tests and current Candidate pass |
| MEDIUM | Five historical auth-user FK lookups lack complete index coverage | Five new nonunique full BTrees; original constraints, indexes, RLS and ACLs unchanged |
| BLOCKER | Cross-version AI refusal completion is stamped before a later-started grant | Per-purpose/owner serialization and post-wait clock; unchanged readers/Edge code; Production receipt/helper paths below |
| LOW | NULL moderator-list limit bypasses 1–100 bound | Predicate-only rejection; genuine local 125-versus-100 before proof and actual Production invalid-limit/auth checks below |

The three screenshot requests remain in this tested source: evidence-backed
watch provenance uses the English brand `Apple Watch` in every locale, without
falsely labeling an unknown/iPhone source as a watch; Today removes the note icon
and localizes authored Body-context selections across 25 supported locales;
daily notifications show effective OFF states while retaining saved choices,
with stable pending/error controls. Sleep stage display labels are localized
rather than exposing provider enums. Personal free text is not machine-translated.
Host/widget regressions are not physical-device Health/notification proof.

## Permanently applied Production migrations

Production has **209 records**. Five approved forward-only literals were applied
only after exact Staging Targeted/Candidate success:

| Source migration | Actual Production version |
| --- | --- |
| 20261004170130_prebuild_remaining_fk_lookup_indexes_v1.sql | 20261004181338 |
| 20261004170806_community_collaborator_projection_privacy_v1.sql | 20261004181339 |
| 20261004171137_cloud_sync_authoritative_consent_boundary_v1.sql | 20261004181340 |
| 20261004173646_ai_consent_receipt_completion_order_v1.sql | 20261004181416 |
| 20261004175339_community_hidden_posts_null_limit_guard_v1.sql | 20261004181419 |

All five entire stored SQL literals match source SHA256, as do the earlier
12 specified reference/mention/repair records: **17 exact literal matches**.
Current compiled repaired functions and unchanged AI readers match approved
fingerprints; existing owners, ACLs and configured paths are preserved.

A managed-tool timestamp collision rejected the first AI application with exact
`23505 schema_migrations_pkey / version20261004181340`. Independent readback
proved 207 records, no AI history entry and the unchanged cloud-stage writer:
the failed attempt rolled back completely. Only that exact AI literal was
reapplied in a later second, then the final application was time-separated.
This is a tool/infra failure, not a product failure or a flaky QA retry.

All 209 Production records now map one-to-one to 209 tracked source files by
version/name or verified generated-version translation. Eleven historical
repeated names are disambiguated by their distinct versions; no history was
edited or replayed. Do not confuse this identity coverage with full historical
byte parity: 27 raw literals match, 62 single-statement literals match after
edge-whitespace trimming, 93 records contain split statements, and 54 historical
single-statement literals still require content/canonical reconciliation.
These are not asserted as 54 semantic/schema defects. Only the stated exact
17-record literal boundary and current scoped behavior are certified.

## Genuine Production rollback evidence

Every suite ran as a separate actual Production transaction with unconditional
ROLLBACK. Independent precheck and post-rollback reads were separate calls.

| Suite | True assertions | Unique relevant residue tables | Result |
| --- | ---: | ---: | --- |
| General Community release boundary | 79 | 68 | PASS / zero residue / zero row-count deltas |
| Collaborator current privacy | 33 | 68 | PASS / zero residue / zero row-count deltas |
| Cloud current consent | 18 | 72 | PASS / zero residue / zero row-count deltas |
| AI receipt/readback/helper | 18 | 69 | PASS / zero residue / zero row-count deltas |
| Hidden-list limit/authority | 12 | 68 | PASS / zero residue / zero row-count deltas |

**160 actual assertions**, including drafts/title/hashtags, mentions/rates,
moderation before invitations, accept/decline/idempotency, Activity/views/rewards,
tier opt-in, owner/block/privacy boundaries and failed media-cleanup authority.
The cloud/AI suites add genuine current deployed RPC, RLS, denial/regrant,
owner isolation and receipt readback; no provider health request was sent.

The small hidden-list proof draft initially assumed no roster trigger. Fresh
catalog/source showed the legitimate suspension-eligibility trigger. Before any
execution, the draft guard was corrected to require that exact enabled trigger,
fingerprint and configuration, still rejecting unknown triggers. No trigger
was disabled, new grant supplied or assertion weakened. This is a documented
draft/test contract defect. Valid default/1/100 calls prove callability only;
the 125-row cap reproduction is isolated PostgreSQL, not Production scale proof.

Inventories explicitly cover Auth users/identities/sessions/refresh tokens,
posts, notifications, rate buckets, drafts, collaboration, reward artifacts and
Storage objects. Dedicated authorized Google reviewer data is permanent and
distinct from these rollback fixtures; it was not deleted.

## Post-apply advisors and security boundaries

The [complete structured receipt](BIL_PREBUILD_INCREMENTAL_CLOSEOUT_RECEIPT_2026-10-04.json)
preserves current catalog, all 277 individual advisor dispositions, exact
migration/function fingerprints, CI partitions and every assertion/inventory.

- 83 RLS-without-policy INFO findings: fresh direct table **and column** checks
  show no anon/authenticated CRUD. Accepted for that narrow RPC-only boundary,
  not as proof that every definer is secure.
- 1 anonymous and 141 authenticated executable-definer warnings remain
  individually recorded. Finite 23-RPC AI/cloud/diary and 11-RPC
  moderation/message/admin source review plus selected real role tests do not
  certify every privileged behavior. No fabricated exposure or blanket PASS.
- Auth leaked-password protection remains disabled: HIGH, not cleared.
- 51 unused-index INFO findings: LOW; original valid/ready indexes and all
  five new full FK indexes retained. No measured speedup or removal claim.

No inventoried public BIL app table lacks RLS; no inventoried public BIL definer
lacks configured search_path. The complete public BIL definer inventory has
74 explicit non-empty paths, including 24 authenticated-executable legacy
paths; this is not a claim that all paths are empty or unqualified SQL is cleared.
Neither API role nor service_role has CREATE in the inspected app schemas.
All eight affected table ACL/owner/RLS identities and original FK/index
definitions are unchanged.

Community images remain private, owner/path/acceptance/operation guarded and
5 MiB JPEG/PNG/WebP; avatars are public with owner-scoped writes and the same
cap/types. Catalogs remain public at 50 MiB without a MIME allowlist and no
authenticated write policy in the inspected list. Nine Storage policies and
Realtime publication metadata were refreshed; HTTP byte cleanup/native
upload/Realtime delivery are not certified from SQL metadata alone.

Fresh authoritative rewards configuration has no quest definitions, zero
quest caps, disabled referral links/progress, and the distinct moderated-post
policy of five tokens / maximum five rewarded posts per owner/day. This is
not fake UI/rewards or proof that quests are release-enabled.

## Google reviewer saved; Apple unchanged

Owner-approved private Google credentials are saved in Play Console App access
with the exact 420-character English instructions. Google displayed
**Change saved. Send for review in Publishing overview.** The reopened form
retained 41 username / 44 password characters. Sensitive values are masked:
byte-for-byte password readback is not claimed. No review submission was made.

At 18:17 UTC, actual ordinary password login to Production and the deployed
Coach returned HTTP 403 `ai_consent_required`, with unchanged usage/credits,
no health context, no consent/entitlement mutation and current-session logout.
Independent 18:25 readback found zero new test sessions/refresh rows and zero
reviewer consent receipts; one pre-existing owner session is intentionally
retained. A consented response/native integrity/all paid-route access is not
proved. Apple identity, credentials and attached store build were unchanged.

![Saved App access without displayed credentials](BIL_GOOGLE_REVIEWER_APP_ACCESS_SAVED_2026-10-04.png)

## Remaining mandatory release gates

| Severity | Unresolved decision/evidence |
| --- | --- |
| BLOCKER | Genuine StoreKit/Play purchase/cancel/pending/restore/verification/entitlement/unlock/persistence/expiry on the exact native artifact; host/mock/server grant cannot substitute |
| BLOCKER | Reviewer must reach every paid route on the reviewed native artifact without an incorrect Plans/paywall; Console/server preflight is partial proof |
| BLOCKER | Remaining Play/Apple privacy field reconciliation, exact installed SDK/tracking behavior and owner attestations; unknown answers are not manufactured |
| HIGH | Paid Vertex Express is Preview; applicable processor agreement/exception and actual logging/cache/retention clearance not evidenced |
| HIGH | Auth leaked-password protection disabled and PostgreSQL 17.6.1.155 security-upgrade/impact decision open |
| HIGH | Finite privileged-RPC/bearer/privacy clearance is not all 141 behaviors; historical content reconciliation is incomplete, not declared a confirmed schema mismatch |
| HIGH | Original IMG_9451–IMG_9472 unavailable; strict reference parity and full native feature/permission/RTL/large-text boundary cannot be certified |
| BLOCKER | Required legal/store attestations remain unsigned; an engineering Git identity is not an owner's signature |

[Disclosure delta map](BIL_STORE_METADATA_DELTA_MAP_2026-10-04.md),
[disclosure reconciliation](BIL_STORE_DATA_DISCLOSURE_RECONCILIATION_2026-10-04.json)
and [permission/evidence contract](BIL_PREBUILD_PERMISSION_AND_EVIDENCE_CONTRACT_2026-10-04.json)
remain qualified, not signed/published completeness claims.
Official [Express terms](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/start/express-mode/overview),
[Cloud service terms](https://cloud.google.com/terms/service-terms),
[Auth password security](https://supabase.com/docs/guides/auth/password-security)
and [PostgreSQL upgrade notice](https://supabase.com/changelog/postgres-15-19-17-11-breaking-changes)
support the remaining decisions.

Available tools do not expose credential-safe Auth configuration changes;
computer-use safety instructions prohibit automating security/privacy settings.
No hidden browser API, token extraction, protection bypass or fabricated
signature was used. Contracts/evidence are prepared in Git; Windows Controlled
Folder Access blocked the prescribed Documents output path and was preserved.

**Final verdict: NOT READY FOR BUILD. Main promotion and all builds remain held.**
