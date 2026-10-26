# BIL39 Coach completion — scoped evidence, not release approval

Continues PR21 at 66944a1458f80d867bf72d857c7432ae1bf00c82 on an
independent writer branch. No worker branch, protected iOS38, main, cloud,
commerce file, price, credit calculation or purchase control was changed.

Actual defects found by executing the worker's tests:

1. `Review today's nutrition from my saved BIL data` was classified as today's
   plan and admitted unsolicited plan proposals. Review/analysis of today's
   records now remains read-only. Explicit workout and combined plan requests
   retain their existing tools.
2. The explicit Arabic command to set the app language to English did not match
   its normalized target spelling. It now works; a conversation request to reply
   in English still cannot mutate the app's language setting.
3. The default Overview bypassed the approved 2200ms entry welcome. The welcome
   now precedes Overview, including reduced motion. Opening chat does not replay
   it or discard the conversation.

Conversation fixtures now use the real Overview-to-chat button. Their existing
confirmation, readback, Undo, owner-switch, consent, diary and privacy assertions
remain in place. Native SQLite fixture entry drains both async clocks within a
bounded wait. Lazy context invalidation is verified by reading the provider
again: an unchanged cached snapshot cannot satisfy the rebuild assertion.
Source-structure privacy tests follow the newly extracted consent part and
also assert that the page actually includes that part.

The Arabic history widget test now checks the requested in-chat behavior against
dated synthetic 90kg and 88kg readings, the -2kg change and its limitations.
Explicit history action links retain independent exact-route tests. These
changes implement the approved read-in-chat requirement, not automatic diary
writes or a success message supplied by a model.

Observed local verification before this documentation commit:

- Flutter 3.44.6 / Dart 3.12.2; locked dependencies unchanged.
- Full format check: 3247 files, zero formatter changes required.
- Complete `flutter analyze --no-pub`: no issues, 601.4 seconds on this host.
- Intent, plan and language regressions: 55 passed.
- Tool execution, consent-to-write, durable recovery, Undo and conversation
  rename scenarios: 88 passed after fixture entry corrections.
- Full Coach directory rerun and exact-source CI remain required; early failed
  runs were preserved rather than relabeled successful.

See the private central BIL39 register for exact SHA, logs and superseding runs.
These are scoped checks. Golden review, native iPhone/iPad/Android, full merged
QA, live cloud staging and signed Build39 evidence are not certified here.
