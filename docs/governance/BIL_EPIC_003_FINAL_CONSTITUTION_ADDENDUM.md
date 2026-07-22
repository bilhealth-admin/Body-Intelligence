# BIL Epic 003 Final Constitution Addendum

Status: Binding for BIL Epic 003 final verification and commit.

This addendum is subordinate to the authoritative
`BIL_PHASE_3_BLACKBOX_CONSTITUTION.md` and the repository's existing
`docs/PHASE_3_CONSTITUTION.md`.

## Non-negotiable preservation

- Preserve Foundation V2, migrations, historical data, verified tests,
  repositories, deterministic engines, localization logic, and state
  management.
- Do not reset, clean, stash, discard, switch branches, rewrite history, push,
  merge, or force-push.
- Do not duplicate business logic or bypass repository boundaries.
- Do not hardcode scientific results or represent unavailable evidence as zero.
- Do not claim capability, certainty, global completeness, or physical-device
  validation without evidence.
- Keep privacy-first and offline-first behavior.
- Keep Arabic/English, RTL/LTR, accessibility, responsive behavior, error
  recovery, and honest sparse-data behavior within the completion gate.

## Epic 003 honest scope

- Country selection is globally searchable through `country_picker`.
- The embedded city catalog is a curated offline suggestion set, not a complete
  global city database.
- Any city may be entered manually.
- Device detection uses locale and system timezone only; it does not request
  GPS, track location, or upload location.
- Exercise frequency, exercise type, and diet approach are preferences only;
  they do not silently alter scientific targets or claim calorie burn.
- Dashboard changes preserve deterministic providers and engines.

## Epic 003 completion gate

Epic 003 must not be marked complete until all of the following are true:

- focused package tests pass;
- all BDAR-002/003 regression tests pass;
- full `flutter test` passes;
- `flutter analyze --no-pub` has no errors;
- Arabic and English manual journeys pass;
- RTL/LTR and responsive layouts are checked;
- country, city, timezone, save, back, profile, exercise, and diet-style flows
  work end to end;
- supported builds are run at the Epic boundary;
- the execution ledger and Quality Board are reconciled;
- the worktree is clean after one focused green commit;
- no completion claim exceeds the available evidence.
