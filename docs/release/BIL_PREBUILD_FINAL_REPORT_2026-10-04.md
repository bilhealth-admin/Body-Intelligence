# BIL prebuild audit results

Historical checkpoint: source `57989acd`, Production readback through
16:51 UTC. The later [incremental boundary repairs and reviewer save](BIL_PREBUILD_LATEST_BOUNDARY_REPAIRS_2026-10-04.md)
supersede the pending App access, collaborator and five-FK findings below.
The dated evidence receipt remains unchanged; it does not certify later source
changes or migration applications. Consult the incremental checkpoint for
the latest exact-SHA QA/application status and unresolved release decisions.

**NOT READY FOR BUILD.** Source fixes, comprehensive code-only QA and focused
Production RPC tests have current passing evidence. Mandatory native purchase,
store disclosure/reviewer and remaining security/privacy clearance boundaries
are still open. No mobile build, upload, review submission or owner legal
signature was made. This is a partial engineering closure, not a claim that
every owner request or hostile release-audit requirement is complete.

## Current source and branches

Direct GitHub reads confirm these heads. The separately pushed report-only
commit will descend from the tested repair SHA without changing executable
source, migrations, tests, dependencies or workflows.

| Branch | Verified head |
| --- | --- |
| fix/admob-clean-production-2026-10-02 | 555496ebb6d6d3952c9e69e7bb6b9788269b39fa |
| work/community-reference-parity-20261003 | 89c3f87e4a42008cd683a5d5144c529a845f2d47 |
| staging/community-final-qa-20261003 | 57989acdb9ebd310ba8bc41a456e9766dc8d4c7b |
| fix/community-acceptance-notifications-20261003 | 5cf93cab3d3826bd92689266766ff19350560bdd |

The audited release and frozen Android 31/iOS 34 manifests are unchanged. Work
is an ancestor of the tested repair, with zero work-only commits; Community
main is also an ancestor. Main promotion is withheld because its release gates
are not all satisfied. There was no force push, rollback, revert or PR that
could trigger a forbidden application build.

## Exact SHA QA is green

All these completed runs bind `57989acdb9ebd310ba8bc41a456e9766dc8d4c7b` on Staging:

- [Targeted 37205461804](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37205461804): SUCCESS.
- [Candidate 37205461778](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37205461778): SUCCESS,
  including source/performance, visual/cloud and all four portable shards.
- [Store and backend 37205461803](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37205461803): SUCCESS;
  the store/provider contract boundary remains mocked, not a genuine purchase.

The exact pinned Flutter 3.44.6/Dart 3.12.2 toolchain reported 2410 files with
zero format changes, zero analyzer issues, unchanged architecture/source-size
and performance limits. Current SQL CI proved the original genuine draft CHECK
failure before the fourth correction, then 98 assertions and three real
overlapping sessions; atomic publication also passed 11 genuine races.
Previously green unmodified local Flutter suites were not rerun unnecessarily.
No failing test was discarded, blanket retry manufactured or threshold raised.

The requested screen repairs are in this tested executable tree: evidenced
watch sources display the unlocalized brand `Apple Watch`; Today Body context
removes the note icon and localizes authored selection labels across all 25
supported locales; notification controls distinguish saved choices from
effective delivery and keep unrelated controls stable during pending changes.
Host regressions cover those states, failure/permission paths and relevant
large-text layouts. Arbitrary personal free text is not machine-translated, an
iPhone/unknown source is not falsely labelled as a watch, and controlled native
gateway/host tests are not physical-device notification delivery evidence.

## Production now has 204 migrations and the focused transaction passed

After exact Staging success, four new forward repairs were permanently applied.
The last application has actual Production version `20261004165024`, not its
source filename timestamp. All four stored entire SQL literals matched their
source at application readback. Subsequent SHA256 comparison also matched all
12 inspected records: these four plus the eight specified reference/mention
migrations. No historical migration or history entry was modified.

At 16:50:54 UTC the focused genuine Production transaction passed **79
assertions**, including multiline Arabic/English drafts, title/hashtags,
owner isolation, rate limiting, moderation-before-collaboration, accept/decline
and retry idempotency, authoritative Activity/views/polls/rewards, tier opt-in,
private projections, block boundaries and failed media cleanup authority.
The transaction unconditionally rolled back. At 16:51:05 UTC a separate read
found **zero synthetic rows across all 68 inventoried tables and no total-row
count deltas** relative to the independent precheck.

This proves the selected Production SQL/RPC and role boundary. It is not
Auth-service HTTP login, a third-actor collaborator privacy proof, genuine
push/provider delivery, physical Storage upload or native commerce evidence.
The dedicated permanent Google reviewer is intentional and distinct from the
rollback fixture; zero synthetic residue does not mean that authorized account
was deleted. Historical `42P10` test-defect and `23514` product-defect logs and
their exact investigation remain recorded in the preceding checkpoint.

## Advisor and catalog dispositions

The post-apply refresh and all individual notices are preserved in
[the structured evidence receipt](BIL_PREBUILD_FINAL_EVIDENCE_RECEIPT_2026-10-04.json).
It includes the 12 migration hashes/versions, every Production assertion,
68-table inventories, exact Storage policies/bucket limits, grants, publications,
FK/index metadata and every remaining advisor item. The finite diagnostic
whitespace exceptions in the earlier source contracts remain explicit; this
report does not claim a global Git whitespace gate is zero.

There are 83 RLS-without-policy INFO notices. Direct table and column privileges
were rechecked: none grants anonymous or authenticated CRUD. Those RPC-only
table notices are INTENTIONAL / ACCEPTED for that narrow boundary, not a pass
for every privileged function. No public BIL app table has RLS disabled and no
inspected definer lacks configured search_path; 24 legacy functions use explicit
non-empty paths, so catalog-wide empty paths are not claimed. Neither API role
nor service_role has CREATE privilege in public.

The sole anonymous executable definer is a token-based invite preview, currently
disabled by authoritative referral configuration. Its token, expiry, revocation
and suspension checks were read; the private-profile/bearer contract is not
declared cleared. All 141 authenticated definer signatures/grants were
inventoried, but individual behavioral clearance is incomplete after the audit
agents hit their usage limit. EXECUTE and SECURITY DEFINER alone are neither
proof of a vulnerability nor proof of security. Accepted-collaborator metadata
still needs an explicit third-actor/current-block/privacy decision and test;
the existing two-owner Production success does not certify that different case.

The 46 unused-index INFO notices are LOW: the actual query/FK/ordering indexes
were retained, with their valid/ready definitions and current statistics
recorded. Zero scans on low-cardinality current tables do not justify deletion.
Five apparent FK gaps are actually covered by non-null partial indexes; five
others lack a full historical FK lookup index and remain MEDIUM structural
findings, not a fabricated measured latency failure. No index was dropped and
no performance limit was raised to silence the findings.

Community images remain private, owner/path/acceptance/operation guarded and
limited to 5 MiB JPEG/PNG/WebP. Avatars are public with owner-scoped writes and
the same cap/types. Catalogs remain public, 50 MiB and without a MIME allowlist;
they have no authenticated write policy in the inspected policy list. Catalog
content classification, HTTP byte cleanup and native Realtime behavior are not
certified merely from catalog/RLS reads.

## Open release-critical work

| Severity | Evidence-backed finding or mandatory gap |
| --- | --- |
| BLOCKER | Genuine StoreKit/Play purchase, verification, entitlement unlock, restore and persistence/expiry chain has not been executed; mocked/host success cannot replace it. |
| BLOCKER | The latest saved Play App access did not include the newly created reviewer credentials. Explicit approval to transmit those specific credentials to that Console field is pending; Apple reviewer identity remains unchanged. |
| BLOCKER | Actual Play Data Safety and Apple privacy mismatches are documented but remaining declarations/SDK tracking decisions and required owner attestations are not finalized. See the field-level store delta map. |
| HIGH | Production PostgreSQL 17.6.1.155 requires a supported security-upgrade/impact decision; no downtime-bearing runtime upgrade was performed. Auth leaked-password protection remains disabled and cannot be changed through prohibited computer-use security automation. |
| HIGH | Remaining privileged RPC and third-actor collaborator privacy/block clearance is incomplete, not labelled PASS and not invented as confirmed exposure. |
| HIGH | Gemini endpoint/project are identified, but processing terms/logging/retention and a genuine consented provider response remain unproved. |
| HIGH | Original IMG_9451 through IMG_9472 were unavailable, so strict screenshot-reference parity cannot be certified. |

Production quest caps are intentionally zero with no active quest definitions,
and referral links/progress intentionally disabled by server configuration.
The UI shows an empty/no-active-quests state rather than fabricated rewards.
The existing distinct moderated-post token policy is five per approval, capped
at five rewarded posts per owner/day; it is not the quest/Gold policy.

Contracts, certificate-readback evidence and store editing maps are prepared,
but legal-owner signatures and store attestations are not executed for the
owner. Windows Defender Controlled Folder Access prevented copying reports
into the prescribed Documents output folder; protection was not bypassed.
Repository documentation remains available for review. **Stop before build.**
