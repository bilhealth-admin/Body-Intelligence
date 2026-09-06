# BIL R-074 classifier and freeze recheck — 2026-09-06

## Boundary and verdict

This is release-hygiene evidence for the future `1.0.0+8` clean candidate. It
does not stage, commit, create a worktree, build, upload, delete, accept the
staging manifest, or rewrite the historical disposition of the fifteen visual
rows in the 2026-09-05 companion.

The pre-correction status snapshot at `2026-09-06T04:56:00Z` was:

- HEAD `21f16767fad82d625ced9b6da2146b66b4b27953` on
  `release/store-rc-20260831`;
- 2,085 dirty leaf paths: 609 tracked worktree changes and 1,476 untracked;
- zero staged paths and zero conflicts;
- old classifier result: 791 `INCLUDE`, 1,159 `EXCLUDE`, and 135
  unclassified paths.

The approval-safe interpretation of that 2,085-path snapshot is **795
candidate paths + 15 REVIEW paths + 1,275 preserve-only paths**. The mechanical
classifier's preliminary include count is 810 because it necessarily contains
the fifteen still-unaccepted golden paths. It must not be reported as 810
accepted paths plus another fifteen.

## Exact classifier correction

`tool/release_hygiene/release_source_staging_dry_run.ps1` now resolves only the
audited paths below. It deliberately adds no broad root allowlist.

| Decision | Exact boundary | Paths |
|---|---|---:|
| `INCLUDE` | `.gitignore`, `.gitattributes`, `wrangler.site.jsonc` | 3 |
| `INCLUDE` | exact already-dirty owner-controlled brand/store evidence list | 21 |
| `EXCLUDE` | `.codex_supabase_fetch_probe_20260901_2320/**` | 91 |
| `EXCLUDE` | `videos/bil-product-launch/**` | 19 |
| `EXCLUDE` | `macos/Flutter/GeneratedPluginRegistrant.swift` | 1 |
| `EXCLUDE` | five exact `tool/bil_mic_*_preview.wav` paths | 5 |

The WAV rule precedes the generic `tool/**` include rule. This fixes the prior
contradiction with the staging-manifest review companion. Exclusion means
preserve in the shared workspace and keep out of the candidate; it is not
authorization to delete anything.

The owner's latest direction that the approved current BIL green-leaf store
logos are correct is controlling. These 21 rows classify an existing dirty
delta only; they do not describe an approved logo as wrong and do not authorize
deleting, restoring, rewriting, or replacing any logo, graphic, or store asset.

The companion's fifteen visual rows remain recorded as `REVIEW` in the
historical snapshot
`docs/release/BIL_PLUS8_STAGING_MANIFEST_REVIEW_COMPANION_2026-09-05.md`.
That wording is not a permanent requirement that the current tree remain under
review. The current ordinary rerun resolved all fifteen without updating a
golden: root session `60250` passed **15/15**, and its two iOS Quick Add adjunct
scenarios made the current visual batch **17/17 PASS with no flags**. The
supporting current-tree dispositions and evidence boundary are recorded in
`docs/release/BIL_VISUAL_REVIEW_15_CURRENT_RECHECK_2026-09-06.md`. Root session
`41866` independently passed the associated **39/39 behavior tests**.

The historical staging manifest still says
`CANDIDATE_FROZEN_OR_ACCEPTED: NO`; neither historical file is rewritten or
retroactively accepted by this correction. The fifteen visual decisions are
therefore resolved for the current source, while R-074 remains open solely for
the clean, immutable source-candidate freeze and its new current disposition.

## Dry-run result

The source-hygiene `-NoWrite` result is recorded after this document is added,
so its status-entry count is expected to be one higher than the snapshot above.
No output manifest is written in `-NoWrite` mode.

<!-- R074_DRY_RUN_RESULT -->

At `2026-09-06T05:22:02Z`, after adding this report, the synthetic scanner
fixture, and one concurrent release-audit document, the tree contained 2,088
dirty paths: 609 tracked worktree changes and 1,479 untracked, with zero staged
paths and zero conflicts. The final `-NoWrite` invocation passed with:

- `RELEASE_SOURCE_STATUS_ENTRIES=2088`;
- `RELEASE_SOURCE_INCLUDE=813`;
- `RELEASE_SOURCE_EXCLUDE=1275`;
- `RELEASE_SOURCE_STAGING_DRY_RUN=PASS`.

There are zero unclassified paths. The approval-safe split is **798 candidate +
15 REVIEW + 1,275 preserve-only = 2,088**; the mechanical 813 include total
contains the fifteen unaccepted visual rows.

The scanner exception is limited to a delimiter-only quoted literal used as the
sole argument of the matching `startsWith`/begin or `endsWith`/end validation
call. Nine synthetic base64-encoded fixtures passed: two allowed checks and seven
blocked cases covering a standalone begin marker, a PEM-shaped body, escaped
multi-line text, concatenated key text, a non-exact validation argument, and a
begin marker incorrectly passed to `endsWith`, plus a different secret pattern
elsewhere beside an allowed check. No production file is whitelisted, and no
secret value is stored or printed by the fixtures.

The run emitted Git's non-blocking warning about a temporary pack file under
`.git/objects/pack`. No repository object was altered or removed. Recheck this
warning only after all concurrent Git writers stop. No output manifest was
written.

## Deterministic clean-transfer preparation

`tool/release_hygiene/prepare_clean_source_freeze.ps1` is a read-only consumer
of a freshly generated classifier manifest. It performs no worktree creation,
copy, delete, stage, commit, build, upload, reset, clean, or stash operation.
It fails closed unless:

- the source index is clean and the exact HEAD commit/tree are readable;
- the manifest and current exhaustive `git status` have identical literal
  path/status sets;
- every present path still has its recorded SHA-256 and every deletion still
  has its recorded HEAD blob identity;
- every decision is exactly `INCLUDE` or `EXCLUDE`, and there are no conflicts,
  renames, copies, duplicate paths, path escapes, or reparse points.

Its output binds the HEAD commit/tree, classifier and classification-manifest
hashes, full status path-set/source-state hashes, INCLUDE path-set hash, EXCLUDE
path-set hash, and one literal `copy` or `delete` operation for every INCLUDE
path. Two consecutive runs against one fresh manifest must return identical
hashes after all writers stop.

The later authorized operator must create the side worktree at the recorded
HEAD, apply only those literal operations, and validate the candidate's status
paths against the INCLUDE path set. Present files are copied byte-for-byte;
recorded deletions are removed only from the separately verified candidate
root. The 1,275 historical EXCLUDE paths stay untouched in the source
workspace. The current provisional manifest
`docs/release/BIL_PLUS8_FROZEN_SOURCE_MANIFEST_2026-09-06.md` is the only file
whose release markers may be finalized after that exact transfer succeeds.
The candidate commit and the finalized manifest digest remain externally bound
to separate protected values, avoiding a self-referential commit or manifest
hash.

`tool/release_hygiene/verify_clean_source_freeze_transfer.ps1` independently
reconstructs the complete expected candidate as **HEAD overlaid by the exact
INCLUDE operations**. It checks every filesystem leaf and byte identity, the
literal Git status path/code set, and the EXCLUDE boundary. Its post-finalization
phase permits a content change only to the named current manifest and then
requires its exact accepted version/build markers; it does not stage, commit, or
build. A synthetic source plus registered side-worktree under
`G:/BIL_Temp/plus8-preflight-20260906/synthetic-freeze-verifier-02` passed all
seven proof cases: the exact overlay and the accepted-manifest phase passed;
untracked EXCLUDE crossover, tracked EXCLUDE tampering, INCLUDE hash tampering,
restoring a planned deletion, and changing the manifest before the phase switch
were each blocked as required. This exercise did not read or mutate the BIL
source worktree.

The separately prepared operator
`G:/BIL_Temp/plus8-preflight-20260906/freeze-tools/invoke_clean_source_freeze_transfer.ps1`
is intentionally outside the repository and has not been invoked. It is bounded
to an explicit empty destination below the approved temporary parent, re-runs
the read-only planner and matches every recorded digest before creating a side
worktree, applies only literal INCLUDE operations, and calls the full verifier.
It never stages, commits, builds, publishes, resets, cleans, or deletes the dirty
source workspace. A second isolated fixture at
`G:/BIL_Temp/plus8-preflight-20260906/synthetic-freeze-executor-01` invoked the
planner and executor through fresh external PowerShell processes. It proved that
`-EmitJson` writes pure parseable JSON with no diagnostic text, completed the
full literal transfer and verifier, left the dirty source status byte-for-byte
unchanged, retained the tracked EXCLUDE file at HEAD, and did not copy the
untracked EXCLUDE file.

## Current freeze gate after visual resolution

1. Stop all writers and require two identical full status/path-set snapshots.
2. Re-run the classifier contract and the full source-hygiene `-NoWrite` check;
   require zero unclassified, oversized, or high-confidence secret findings.
3. Generate a fresh classifier manifest, run the read-only clean-freeze helper
   twice, and require identical HEAD/path-set/source-state hashes.
4. Create a clean side worktree at the audited HEAD, transfer only the frozen
   allowlist, prove `unexpected=0` and `missing=0`, finalize the new current
   manifest without embedding its own hash or candidate commit, and only then
   stage via an exact literal pathspec and run the release gates.

Never use bulk add, reset, clean, or a copy of ignored/generated workspace
content for the release candidate.
