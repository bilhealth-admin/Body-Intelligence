# Sleep daily-reminder state correction

## Proven causes and fixes

- Historical six-hour goals remain readable, but both the page and the store
  previously required the current seven-hour planning floor even when disabling
  reminders. Disabled, structurally valid historical schedules can now be saved
  unchanged; enabling still requires a valid current planning goal and window.
- The permission request previously ran before the busy guard was acquired.
  One guarded operation now covers permission, native scheduling/cancellation,
  and persistence. Repeated/same-value callbacks cannot start another attempt.
- The adaptive switch now displays the requested pending state while disabled
  during the operation. Its card remains mounted, with a fixed progress slot.
- Native scheduling/cancellation now succeeds before the new preference is
  committed. Failures attempt to restore the prior native schedule, retain the
  last persisted preference, report failure, and clear the busy/pending state.
- Loading does not validate or resave a historical schedule, request permission,
  schedule notifications, or display an unsolicited validation error.

Manual sleep records and the user's existing goal and clock values are not
rewritten. Adult planning validation is not weakened for enabling reminders.

## Verification

- PASS: targeted Dart analyzer for the domain, shared wellness library, schedule
  presentation, and both affected test files; no issues.
- PASS: 22 tests in sleep_schedule_test.dart and sleep_tracker_page_test.dart.
  Includes historical disable/reopen on iOS and Android widget themes, idle
  stability, duplicate callbacks during a pending permission request, denied
  permission, failed native scheduling, and explicit-only legacy validation.
- PASS: Dart formatting and git diff whitespace checks.
- Final status inspection found that the earlier full-suite launcher had
  aborted while relaying an Arabic test name through Windows CP1252 stdout.
  This was a launcher exception, not a failing Flutter assertion. Its partial
  run is not a full-suite pass. The launcher now explicitly streams UTF-8; the
  next full run starts from the beginning and includes the sleep corrections.
- NOT RUN: real iOS/Android notification delivery, device interaction, simulator,
  emulator, screenshots, or visual confirmation of the reported flicker.
- No commit, push, or mobile build was performed for this correction.

The native notification boundary is controlled in the host widget tests; these
results do not claim actual OS delivery or that the installed build is updated.

## Final code checkpoint

The fresh UTF-8 full-suite run including this correction completed successfully:
all 26 groups passed and the verifier confirmed all 950 selected test files,
with no missing, failing, or stale files. Full Flutter analysis also passed.
The earlier partial-run and no-commit statements describe the checkpoint above,
not the subsequent owner-authorized release preparation.
