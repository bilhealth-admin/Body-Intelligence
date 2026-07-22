# BIL Package Constitution

Package: `BDAR-002R5 — Edit Quantity Route Safety`

This critical revision is subordinate to BDAR-002 and all higher BIL governance.

## Root cause

The Edit Quantity dialog was opened with `showDialog`, but both dialog buttons
called `Navigator.pop(context)` using the Daily Log page context rather than the
dialog builder context.

With GoRouter this popped the last routed page from the application stack,
leaving no page to render and producing the black screen.

## Frozen scope

- Correct only the Edit Quantity dialog route ownership.
- Cancel and Update must close the dialog route through `dialogContext`.
- Preserve quantity parsing, repository updates, UI, and navigation elsewhere.
- Add a route-safety regression contract.
- No BDAR-003A files or architectural changes.

## Completion gate

- Analyzer introduces no new errors.
- Route-safety test passes.
- Existing BDAR-002 tests remain passing.
- Manual Windows test confirms Cancel and Update return to Daily Log without a
  black screen or GoRouter assertion.
