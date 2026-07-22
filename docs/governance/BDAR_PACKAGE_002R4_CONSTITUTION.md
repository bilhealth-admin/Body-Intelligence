# BIL Package Constitution

Package: `BDAR-002R4 — Dashboard Theme Consistency Final`
Branch: `phase-3-product-excellence`
Original review baseline SHA-256: `a84fa176baa5ebfc1b9087aac2bc8cc0734a25468bef315a1888fd57119d999d`

This revision is subordinate to all Phase 3, stabilization, Product Excellence,
and BDAR governance documents.

## Frozen scope

Included:

- Correct the unreadable `Today at a glance / ملخص اليوم` heading and subtitle.
- Introduce one reusable explicit-contrast dashboard section-heading component.
- Add regression contracts for readable foreground colors and semantics.
- Verify all previous BDAR-002 integrity tests remain passing.

Excluded:

- BDAR-003A extraction or architecture changes.
- Dashboard layout redesign.
- Provider, engine, database, routing, nutrition, exercise, or scientific changes.
- Unrelated analyzer-warning cleanup.

## Safety rule

BDAR-003A must remain stored and unopened until:

1. R4 analyzer and tests pass;
2. Windows Arabic and English manual review passes;
3. the focused BDAR-002 commit is created;
4. its commit hash is reported and accepted.

## Completion gate

- No analyzer error introduced by R4.
- R4 test passes.
- Every BDAR-002 regression test passes.
- Windows tester confirms title/subtitle readability in Arabic and English.
- One focused commit is created.
