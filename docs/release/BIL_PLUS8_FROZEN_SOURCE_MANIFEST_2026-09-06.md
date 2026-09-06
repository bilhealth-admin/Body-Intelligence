# BIL +8 frozen source manifest — 2026-09-06

## Machine-readable release markers

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 8`

## Current disposition

The `1.0.0+8` source candidate is frozen and accepted for signed CI builds.
The full isolated worktree passed PreFinalization transfer verification:
4,798 files, 863 exact INCLUDE changes, and 1,275 excluded changes protected.
This accepts source, not an unbuilt IPA/AAB, an unperformed native test, or a
store review. The fifteen historical visual rows passed their ordinary current
rerun without rewriting goldens, as documented in
`BIL_VISUAL_REVIEW_15_CURRENT_RECHECK_2026-09-06.md`.

This file does not change or replace the historical evidence in
`BIL_PLUS8_STAGING_MANIFEST_2026-09-05.md` or
`BIL_PLUS8_STAGING_MANIFEST_REVIEW_COMPANION_2026-09-05.md`.

## Verified source identity

| Property | Value |
| --- | --- |
| Base HEAD | `21f16767fad82d625ced9b6da2146b66b4b27953` |
| Base HEAD tree | `7d21c909d65717cc61840bfcb2ccf898d6a9f6ec` |
| Classification manifest SHA-256 | `444b3208294fa2010ddcf5dbb3706a4aea2ee70940630273e7b6491a6a8ab203` |
| Classifier SHA-256 | `a99b9caee8ad12df94794feb120d03d601387f3fa5abcbd842a41f71eeb32849` |
| Dirty source status paths | 2,138 |
| Source status path-set SHA-256 | `6bd2e12874d60f15784e5724cc4ecdcc1c4694dbbcdf1e578b7586bcabe15cc9` |
| Source-state SHA-256 | `657ac4a257ae7731d77fe0ba5f90f776982410f905f2129b32450c87054e3b17` |
| INCLUDE count | 863 |
| INCLUDE path-set SHA-256 | `018bac2a8c30b870a930746c46324914ec4d5da69528ea63667db1badc19a7f4` |
| EXCLUDE count | 1,275 |
| EXCLUDE path-set SHA-256 | `5a7e59708e8caafefaaa1192f80146e5d0aade7f8ab49ec62dffbae2167d44ec` |
| Full transferred file count | 4,798 |
| Full transferred path-set SHA-256 | `a021aec6ae7e6b8308b87fbe35bf8d752560d174c54456e17ff1f9279f34c39c` |
| PreFinalization full-state SHA-256 | `413e286eba4a4de4aba0026fb5ec6a7cb9a25c72cc86d21d0cb03a69f9417cd9` |
| PreFinalization log SHA-256 | `6c278558e355b794bf1abeca5884d46a84899be3d615f09fdb2a7b3e6501d823` |

`CLEAN_TRANSFER_UNEXPECTED: 0`

`CLEAN_TRANSFER_MISSING: 0`

`CLEAN_TRANSFER_HASH_MISMATCH: 0`

`CLEAN_TRANSFER_EXCLUDE_VIOLATION: 0`

The 25 tracked EXCLUDE paths retain their exact HEAD baseline; all 1,250
untracked EXCLUDE paths are absent from the candidate and remain preserved in
the original workspace. The classifier reported no unclassified, oversized,
high-confidence-secret, or unresolved-review findings. Its nine-case secret
scanner contract passed. Twelve initially reported source changes were proved
byte-identical to HEAD and the candidate, then their stale Git index metadata
was repaired without staging any content change; they are not counted as
release changes.

The worktree checkout completed, but its Windows sh post-checkout wrapper could
not fork. The actual Git LFS post-checkout operation was run directly and
returned exit 0; no hook was disabled or deleted. A fresh preparation and the
full transfer verifier then passed against the corrected exact path set.

## Automated acceptance evidence

See `BIL_PLUS8_AUTOMATED_PREFLIGHT_2026-09-06.md` for commands, honest initial
failures, corrections, reruns, and raw-log SHA-256 values. The complete portable
inventory contains 860 of 889 Flutter test files, retaining exactly 29 reviewed
exclusions (not counted as passes). All initial failures were addressed and
their containing focused tests rerun: 30/30 passed; isolated unchanged-budget
performance passed 2/2 in each of three runs; runner/live-network tests passed
4/4 with the live public video range check explicitly enabled; Python runner
tests passed 8/8. Final formatting checked 1,970 files with zero changes, and
whole-source Flutter analysis reported no issues.

`BIL_PLUS8_BACKEND_DEPLOYED_PARITY_AUDIT_2026-09-06.md` records exact deployed
backend parity for the client paths and the production App Attest build-8
allowlist. Remote push remains explicitly disabled. Native simulator runs are
owner-waived and must remain `NOT_RUN_OWNER_WAIVED`, not relabeled as passed.

## Finalization and immutable binding contract

All source writers stopped before the verified transfer. The fields above are
recorded from the read-only preparation plan, including:

- base HEAD commit and HEAD tree object;
- classification-manifest SHA-256 and classifier SHA-256;
- full dirty-status path-set SHA-256 and source-state SHA-256;
- exact INCLUDE and EXCLUDE counts and path-set SHA-256 values;
- transfer verification with `unexpected=0` and `missing=0`;
- zero unclassified, oversized, high-confidence-secret, or unresolved review
  findings;
- the final whole-source analysis and automated-test evidence selected by the
  release owner.

The first two markers are now `YES`. This document must not
embed the candidate commit SHA or its own file SHA-256: the final commit is
bound externally by `BIL_PLUS8_AUDITED_SOURCE_SHA`, and this file's post-commit
digest is bound externally by `BIL_PLUS8_STAGING_MANIFEST_SHA256`. Keeping
those two immutable values outside this commit avoids a self-referential hash.

No build, signing, upload, TestFlight/Play submission, or publication is
authorized merely by editing these markers. The signed build workflows remain
separate gates and must select build `+8`, never build `+7`.

The owner's explicit instruction authorizes signed builds and subsequent
publication after verification. Run PostFinalization full-tree verification
before staging; bind this exact finalized file and the resulting commit in the
two external GitHub variables before dispatch. Both CI jobs rerun source tests
and verify real signatures, capabilities, and artifact identities. Apple
public release remains manual; Google production access is under review.

## Verified CI follow-up to the initial frozen candidate

The initial accepted commit `1888807bd2011f1970f16eee5effdeb882aff639`
reached the full portable suite on both GitHub platforms. Android run
`34021076234` and iOS run `34021077842` each reported 3,958 passing tests,
one failing test, and one intentional live-network skip in that suite. Neither
run reached artifact construction or store upload. The source-transfer hashes
above describe that initial transfer, not a claim that its CI build passed.

The one failure was the old visible-Premium assertion in
`test/features/nutrition_plans/nutrition_pathway_access_badge_test.dart`.
The application already renders Premium once at page level and exposes each
paid badge through its localized semantic icon label. The reviewed follow-up
changes only this test and these two release-evidence documents. Application
code, native code, assets, dependencies, signing configuration, workflow code,
test exclusions, and performance budgets remain byte-identical to the initial
accepted commit.

The corrected test checks the single visible page label, no repeated visible
paid-card label, exact localized icon labels, and one access-label line in the
actual merged card semantics. It preserves English/Arabic, hero/compact badges,
free-plan labels/icons, large text, scrolling, and exception checks. Flutter
owns the semantic-handle lifecycle through `semanticsEnabled: true`.

The four-file focused rerun passed **19/19**, the modified-file Dart analysis
reported **No issues found**, formatting reported zero changes, and the follow-up
diff passed whitespace checking. Raw-log hashes and honest intermediate test
corrections are recorded in `BIL_PLUS8_AUTOMATED_PREFLIGHT_2026-09-06.md`.
The exact three-path delta is reviewed before commit; its new commit and this
new manifest digest must replace the external bindings before both complete
signed CI workflows are dispatched again. No test was removed or skipped to
make this correction, and no application UI was reverted.
