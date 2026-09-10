# Full-suite failure corrections — 10 September 2026

## Observed failures

The completed host-only full-suite run failed in groups 03, 07, and 08.
Serial diagnostic reruns reproduced seven failing tests with three causes:

1. The store-offer test still expected 19 additional Premium benefits after
   friends and private messages were moved into Free. It now expects 17 and
   explicitly checks that both benefits belong to the Free card, not the paid
   additions. Prices, trials, purchases, and the Free product change are preserved.
2. The account-identity source contract required the unconditional remote-name
   overwrite removed by the display-name persistence fix. The contract now checks
   the shared synchronization path and rejects that old overwrite. An additional
   database-backed test verifies cloud-to-local refresh when no user edit is
   pending; the existing pending-edit, offline, ordering, and owner-isolation
   regression tests remain intact.
3. Legal-publication evidence pinned the website asset before the Free Community
   copy update. Its stale byte count caused five legal-proof tests to fail. A new
   dated observation replaces the current metadata pointer, preserving the old
   historical evidence and every hash, route, and content validation. Two new
   tests explicitly reject length changes and same-length content tampering.

## Read-only publication observation

At 2026-09-10T11:43:26.495Z, GET requests confirmed the four required public
routes returned HTTP 200, text/html, without redirects. The deployed app.js and
local public_site/app.js were byte-identical: 88,272 bytes, SHA-256
59d3857dc8846affb3203df55497b12570db4c3bc15a3038f1a8b4447c785855.
All four required English/Arabic adult-age content assertions were present.
The new observation is recorded in
docs/release/BIL_EPIC15_PUBLICATION_VERIFICATION_2026-09-10.json.
No website/store mutation, legal approval, or visual inspection is claimed.

## Verification before full-suite restart

| Gate | Result |
| --- | --- |
| Full Flutter analyzer, --no-pub | PASS — no issues, 29.8 seconds |
| Four affected Flutter test files | PASS — 32 tests, including the seven prior failures |
| Prebuild Python tool tests | PASS — 21 tests, including five fail-fast regressions |
| Portable-runner Python tests | PASS — 15 tests |
| Dart formatting of the five affected Dart files | PASS — no changes |
| Git whitespace validation | PASS |
| Full suite after these corrections | NOT RUN at this verification checkpoint |
| Device/emulator/simulator, screenshots, visual testing | NOT RUN |
| Commit, push, Android/iOS build | NOT RUN |

The full-suite restart uses the same reviewed host-only selection with
`python tool/prebuild/run_code_tests.py final --fail-fast`. The visible runner
streams output and retains logs. On the first failing group, it saves that
group's failed result and stops scheduling further groups; remaining groups are
not claimed as passing. Without the flag, the original collect-all behavior is
unchanged. No test was disabled, skipped, or weakened to hide a defect.

The requested next action is to start that complete run from the beginning and
leave it running for the owner, without committing or building before its result.

## Completed full-suite checkpoint

The subsequent UTF-8 full-suite run completed with exit code 0: all 26 groups
passed, including the sleep-reminder fixes. The evidence verifier confirmed
950/950 selected files covered with no missing, failing, or stale files. The
final full analyzer also passed with no issues. The owner then authorized one
commit, GitHub push, and both mobile builds. Final release-only verification is
recorded in `TESTER_FIXES_RELEASE_GATE_2026-09-10.md`.
