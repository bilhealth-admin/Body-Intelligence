# BDAR Decision Log

## D-001 — Latest archive is the official audit baseline

Accepted.

Archive: `BIL_Review_Latest.zip`  
SHA-256: `a84fa176baa5ebfc1b9087aac2bc8cc0734a25468bef315a1888fd57119d999d`

## D-002 — No single giant implementation package

Accepted.

Reason: a package combining stabilization, dashboard reconstruction, exercise, nutrition strategies, location, and AI would be unreviewable, difficult to test, and unsafe to revert.

The full vision remains preserved through a sequenced program.

## D-003 — Every package carries its governing constitution

Accepted.

Each package must include:

- `PACKAGE_CONSTITUTION.md`;
- `PACKAGE_MANIFEST.md`;
- scoped implementation notes;
- preflight;
- verification commands;
- rollback guidance;
- Quality Board and ledger updates when status changes.

## D-004 — Apparent hidden dashboard screen is not yet declared a duplicate page

Accepted.

Static review found no second dashboard route or duplicate `IndexedStack`. Runtime reproduction is required before final root-cause classification.

## D-005 — Explainability content is preserved

Accepted.

Evidence, confidence, missing evidence, and rationale are core BIL differentiators. The implementation may be reorganized but not silently removed.

## D-006 — The primitive profile-plan candidate is rejected

Accepted.

A production replacement must use existing persistence, canonical number controls, correct navigation, unsaved-change protection, and clear separation of profile, nutrition strategy, and movement.
