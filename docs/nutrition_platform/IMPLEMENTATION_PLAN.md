# Implementation plan

This architecture is one Epic delivered through reviewable packages.

## BIL-FOOD-002 — resumable raw/master importer

- Source inspection and manifest.
- Streaming raw staging.
- Resumable checkpoints.
- Master database only.
- Full audit report.
- No mobile database.

Acceptance: interruption and resume tests, deterministic counts, no false-complete output.

## BIL-FOOD-003 — canonical identity and evidence model

- BIL Food ID generation.
- Source links.
- Nutrient definitions and evidence.
- Portions, names, brands, barcode claims.
- Merge lineage.

## BIL-FOOD-004 — quality and deduplication engine

- Versioned scoring policy.
- Barcode conflicts.
- Candidate generation.
- Safe automatic merge rules.
- Quarantine and reject reports.

## BIL-FOOD-005 — core delivery database

- Foundation/SR-oriented compact catalog.
- Arabic/English aliases foundation.
- Runtime indexes and FTS.
- Size and performance measurements.

## BIL-FOOD-006 — branded delivery profile

- Market profile rules.
- Quality threshold.
- Deduplicated branded output.
- Barcode coverage report.
- No automatic inclusion of all master records.

## BIL-FOOD-007 — application catalog repository

- Read-only catalog opening.
- UnifiedFood adapter.
- Search and barcode resolver.
- Existing meal snapshot preservation.
- No historical recalculation.

## BIL-FOOD-008 — catalog versioning and atomic updates

- Manifest parsing.
- Hash verification.
- Atomic activation and rollback.
- App compatibility gate.

## Deferred

- Remote distribution and signed manifests.
- Arabic commercial data acquisition.
- Community verification.
- Images.
- Knowledge-graph recommendations.
- User-learning ranking.

These are not silently included in the first importer.
