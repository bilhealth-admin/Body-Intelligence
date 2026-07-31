# BIL Architecture Decisions

## Authoritative execution baseline

- Branch: `phase-3-product-excellence`
- Baseline HEAD: `9bc3b524a476280209e324637c9ac78de14daa44`

## Current authoritative decisions

### ADR — Local authority and offline-first operation

The local database is the product source of truth. Product features must remain useful without network availability. Remote systems synchronize with local state and do not silently replace local authority.

### ADR — Privacy-first and provider-neutral boundaries

Core domain, intelligence, and Cloud Platform logic remains provider-neutral. Credentials, vendor SDK details, hosted endpoints, and deployment configuration stay behind explicit adapters and environment boundaries.

### ADR — Canonical local intelligence runtime

`BilLocalIntelligenceRealityRuntime`, obtained through the single product composition root, is the canonical Database-to-Product intelligence path. Compatibility facades may delegate only and must not contain parallel confidence, action, safety, or integration logic.

### ADR — Deterministic, explainable intelligence

BIL engines remain the source of decision truth. Every product decision must preserve evidence, confidence, uncertainty, safety outcome, scientific validation, and a deterministic trace. Language models may assist presentation only when separately authorized; they do not replace BIL decision engines.

### ADR — Safe abstention

Missing or insufficient evidence produces explicit abstention rather than invented data, unsupported forecasts, unsafe actions, or runtime exceptions.

### ADR — Durable Cloud Platform Core

Cloud state is persisted locally with durable outbox, inbox, cursors, tombstones, conflicts, idempotency receipts, dead letters, identity/device state, backups, and redacted audit evidence. Retry, restart recovery, reconciliation, backup/restore, export, deletion, consent withdrawal, and schema negotiation are explicit production capabilities.

### ADR — Closed-stage non-regression

Foundation, Nutrition Platform, AI Platform, BIL Intelligence Integration, BIL Intelligence Reality Closure, and Cloud Platform Core are closed. Any change to these boundaries requires a proven defect or approved requirement and focused regression protection.

## Historical ADR policy

Superseded package-status notes and historical parent HEAD references are retained in Git history and package archives. They are not active architecture decisions.

## BIL-GLOBAL-001-FINAL verification candidate

- Branch: `phase-3-product-excellence`
- Parent HEAD: `9bc3b524a476280209e324637c9ac78de14daa44`
- Status: **Awaiting Product Owner VERIFY; not yet adopted or committed.**
- Engineering scope: final product composition, wearable payload preservation, native BLE session closure, embedded Arabic reporting, plugin runtime proof, commerce capability honesty, and evidence synchronization.
- External gates: iOS/macOS build and representative device/provider certification remain explicitly separate.
- Samsung wearable integration is not present in the production catalog and remains `Not Implemented`; no readiness claim is made.

## ADR — USDA raw staging checkpoint identity

For `BIL-FOOD-002`, the durable checkpoint key is `(dataset, archive member name)` and progress is the last committed CSV data-row number. Raw staging records are uniquely keyed by `(dataset, member name, source row number)`. This makes each committed batch idempotent and allows a restarted process to skip already committed rows without creating duplicate records. Source archive SHA-256 is pinned; changing an archive after progress exists requires a new staging database or an explicit future reset operation.


## BIL-FOOD-003 candidate

- Canonical source-neutral schema and stable BIL-owned food identity.
- Source mappings, nutrient evidence, portions, barcode claims, and merge lineage.
- Build-time SQLite only; no mobile database or Flutter integration.

## ADR — Versioned explainable nutrition quality policy

BIL quality is a deterministic, versioned policy rather than an opaque probability. Every assessment persists component scores, final score, policy version, validation status, delivery eligibility, warnings, and rejection reasons. Exclusion from delivery never deletes master evidence. Deduplication and merging are a separate architectural stage owned by BIL-FOOD-005.


## BIL-FOOD-005 — Deduplication and Canonicalization

Implemented explainable duplicate decisions, conservative automatic merge gates, conflict preservation, deterministic survivor/field selection, and merge lineage. No mobile catalog, search, or Flutter integration is introduced. Next package: BIL-FOOD-006 — Mobile Catalog Builder.


## BIL-FOOD-006 — Mobile Catalog Builder

Build-time derivation of compact, profile-driven mobile catalogs from accepted canonical foods. Master evidence remains outside delivery databases. Parent baseline: `14c6cdce71a23b22d9304b2e7b32d1270050da8c`. Next package: BIL-FOOD-007 — FoodRepository and Offline Search Foundation.

## ADR — Application catalog ownership

The application owns a read-only repository boundary over the BIL delivery schema. It does not depend on USDA identifiers or master-build tables. Search and barcode resolution consume `UnifiedFood`; catalog version activation is a separate responsibility.

## BIL-FOOD-008

Catalog activation and version management added: integrity-gated activation, immutable version directories, atomic registry replacement, compatibility checks, and rollback. Cloud distribution and remote update transport remain out of scope.
