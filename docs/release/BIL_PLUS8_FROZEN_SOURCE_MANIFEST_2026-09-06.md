# BIL +8 frozen source manifest — 2026-09-06

## Machine-readable release markers

`STAGING_MANIFEST_COMPLETE: NO`

`CANDIDATE_FROZEN_OR_ACCEPTED: NO`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 8`

## Current disposition

This is the current `1.0.0+8` source-manifest target, but it is deliberately
**provisional and not accepted**. The fifteen visual rows inherited from the
2026-09-05 historical staging snapshot have now passed their ordinary current
rerun without rewriting a golden; the current evidence is recorded in
`BIL_VISUAL_REVIEW_15_CURRENT_RECHECK_2026-09-06.md`. The remaining boundary is
the clean-source transfer itself.

This file does not change or replace the historical evidence in
`BIL_PLUS8_STAGING_MANIFEST_2026-09-05.md` or
`BIL_PLUS8_STAGING_MANIFEST_REVIEW_COMPANION_2026-09-05.md`.

## Finalization contract

Only after all writers stop and the exact allowlisted source is transferred to
a clean side worktree may the release owner finalize this file. Finalization
must record all of the following from the read-only preparation plan:

- base HEAD commit and HEAD tree object;
- classification-manifest SHA-256 and classifier SHA-256;
- full dirty-status path-set SHA-256 and source-state SHA-256;
- exact INCLUDE and EXCLUDE counts and path-set SHA-256 values;
- transfer verification with `unexpected=0` and `missing=0`;
- zero unclassified, oversized, high-confidence-secret, or unresolved review
  findings;
- the final whole-source analysis and automated-test evidence selected by the
  release owner.

The finalized document must change the first two markers to `YES`. It must not
embed the candidate commit SHA or its own file SHA-256: the final commit is
bound externally by `BIL_PLUS8_AUDITED_SOURCE_SHA`, and this file's post-commit
digest is bound externally by `BIL_PLUS8_STAGING_MANIFEST_SHA256`. Keeping
those two immutable values outside this commit avoids a self-referential hash.

No build, signing, upload, TestFlight/Play submission, or publication is
authorized merely by editing these markers. The signed build workflows remain
separate gates and must select build `+8`, never build `+7`.
