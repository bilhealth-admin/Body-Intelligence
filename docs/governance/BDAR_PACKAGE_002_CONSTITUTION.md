# BIL Package Constitution

Package: `BDAR-002 — Emergency Dashboard Integrity`  
Baseline archive: `BIL_Review_Latest.zip`  
Baseline SHA-256: `a84fa176baa5ebfc1b9087aac2bc8cc0734a25468bef315a1888fd57119d999d`  
Branch: `phase-3-product-excellence`

## Governing authority

This package is subordinate to the Phase 3 Constitution, repository baseline,
stabilization ledger, Quality Board, Product Excellence governance, and the
BDAR program constitution.

## Permanent rules

- Preserve all verified Phase 3 work and scientific calculations.
- Do not reset, clean, restore, rewrite history, force-push, merge, or push.
- No unrelated feature work is included.
- Any bug found outside this frozen scope is recorded and deferred.
- Explainability content is preserved, not removed.
- Missing evidence is never represented as zero.
- Privacy-first, offline-first, accessibility, RTL/LTR, responsive behavior,
  and cross-platform compatibility remain mandatory.
- Every changed production behavior requires targeted regression coverage.
- The package must remain independently testable and revertible.

## Frozen scope

Included:

1. repair dashboard mojibake and corrupted punctuation;
2. prevent collapsed deep-insight content from remaining in widget, render,
   semantics, or paint trees;
3. add explicit clipping and repaint containment;
4. add source, responsive widget, semantics, and text-integrity tests;
5. update governance status.

Excluded:

- refresh redesign;
- dashboard view-model decomposition;
- visual redesign;
- settings/profile;
- nutrition strategies;
- exercise engine;
- location/timezone;
- schema or database changes.

## Completion gate

Analyzer, all three targeted tests, Windows Arabic/English inspection at compact
and wide sizes, and one focused commit must pass.
> **RETIRED — historical record only.** This file is not an execution
> authority. The sole current authority is
> `docs/BIL_V1_FINAL_RELEASE_CONSTITUTION.md`.
