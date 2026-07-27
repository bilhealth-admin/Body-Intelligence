# Import pipeline

## Stage 0 — preflight

- Verify branch and HEAD for the package.
- Verify source archives exist and are readable.
- Record SHA-256 and exact archive member names.
- Reject partial archives or unexpected schema versions.
- Verify disk-space and temporary-directory requirements.

## Stage 1 — inspect

Read headers and source manifests without importing all rows. Produce a source inspection report containing required files, row estimates, column differences, and unsupported fields.

## Stage 2 — raw staging

Stream archives into `bil_food_raw.sqlite` in bounded transactions. Never load an entire branded source into memory.

Requirements:

- Resumable checkpoints per source file and row offset.
- WAL disabled for final immutable outputs but allowed during staging.
- Batch commits with explicit progress.
- Idempotent restart: a resumed run must not duplicate records.
- Cancellation leaves a clearly incomplete build state, never a file named as complete.

## Stage 3 — normalization

Normalize:

- whitespace and Unicode;
- language-independent search forms;
- GTIN padding and check digits;
- units and nutrient identifiers;
- brand names;
- dates and source statuses;
- portions to gram weights when evidence supports conversion.

Original source text is retained.

## Stage 4 — evidence mapping

Map source nutrient rows into BIL nutrient definitions. Record amount, source unit, converted unit, conversion method, and confidence.

No canonical nutrient value is chosen in this stage.

## Stage 5 — source master

Create `bil_food_master.sqlite` containing complete normalized source records and lineage. This database may preserve nearly all two million branded rows because it is a build artifact, not a phone database.

## Stage 6 — identity resolution

Resolve records into existing or new `bil_food_id` values using deterministic rules:

1. Existing source-link match.
2. Valid non-conflicting GTIN match.
3. High-confidence exact normalized product/brand/size match.
4. Controlled fuzzy candidate generation followed by strict acceptance rules.
5. Otherwise create a distinct identity.

## Stage 7 — quality and deduplication

Evaluate every candidate using the policy in `QUALITY_AND_DEDUPLICATION.md`. Low-quality records remain in master but may be quarantined or excluded from canonical delivery.

## Stage 8 — canonical selection

Select canonical display names, portions, and nutrient evidence. Produce merge lineage and conflict tables.

## Stage 9 — delivery build

Build compact read-only databases from canonical records using explicit delivery profiles. Full branded master data is never automatically shipped.

## Stage 10 — verification

Every output must pass:

- SQLite `integrity_check` and `foreign_key_check`;
- row-count reconciliation;
- uniqueness constraints;
- barcode conflict report;
- missing-required-field report;
- deterministic sample queries;
- output SHA-256;
- reproducibility comparison for identical inputs and tool versions.

## Stage 11 — publish

Rename temporary outputs to final names only after verification succeeds. Generate a signed-ready manifest. Publishing to an application asset or download service is a separate approved package.

## BIL-FOOD-002 implementation contract

The importer implementation lives under `tool/nutrition_platform/` and stores raw source rows in a build-time SQLite staging database. Checkpoints are committed per bounded batch and keyed by dataset plus ZIP member. A source SHA-256 mismatch after progress exists is rejected. `KeyboardInterrupt` and termination signals mark the active member interrupted after committing the current bounded batch, preserving a resumable checkpoint. This package does not publish a final master or mobile database.
