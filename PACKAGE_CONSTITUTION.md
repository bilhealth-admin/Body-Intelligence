# RETIRED — historical record only

This constitution is superseded by
`docs/BIL_V1_FINAL_RELEASE_CONSTITUTION.md`.

# BIL Epic 003 Final R1 Constitution

Purpose: fix the sole verified startup-test lifecycle defect introduced by the
forced-onboarding preference.

## Allowed changes
- Replace the persistent `StreamProvider` for `forceOnboarding` with a one-shot
  auto-disposed `FutureProvider`.
- Isolate the startup widget tests from the real database by overriding this
  dependency explicitly.
- Add a focused contract test.

## Preserved behavior
- The force-onboarding flag remains persisted locally.
- Startup still routes to onboarding when the flag is true.
- Successful onboarding still clears the flag.
- No profile, meal, weight, goal, database schema, scientific engine, UI, or
  location behavior changes.

## Completion gate
No commit until focused tests, full `flutter test`, builds, and manual review
pass.
