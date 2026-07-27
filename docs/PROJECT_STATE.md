# BIL Project State

## Authoritative execution baseline

- Branch: `phase-3-product-excellence`
- Baseline HEAD: `9bc3b524a476280209e324637c9ac78de14daa44`
- Documentation synchronized by: `BIL-DOC-001`

This document is the authoritative current-state reference. Package-level parent HEAD values belong only in archived package records and must not be interpreted as the active project baseline.

## Current execution state

| Platform / phase | Status |
|---|---|
| Foundation | **Closed** |
| Nutrition Platform | **Closed** |
| AI Platform | **Closed** |
| BIL Intelligence Integration | **Closed** |
| BIL Intelligence Reality Closure | **Closed** |
| Cloud Platform Core | **Closed** |

## Current product boundary

The repository contains the accepted local-first product foundations, nutrition platform, deterministic AI engines, unified intelligence integration, canonical local intelligence runtime, reality and behavioral safety gates, and the provider-neutral offline-first Cloud Platform Core.

The Cloud Platform Core remains local-authoritative and provider-neutral. External infrastructure activation, credentials, hosted transport configuration, server-side authorization, deployment, and operational monitoring remain environment work rather than unfinished Cloud Core architecture.

## Non-regression declaration

All closed phases above are protected as Non-Regression. They must not be reimplemented, redesigned, or reopened without a proven defect, an approved requirement, and a focused package scoped to that evidence.

## Official next boundary

No AI, Intelligence Reality, or Cloud Core package is pending. The next project phase is the first post-Cloud stage authorized by the Product Owner from the governing roadmap. It must begin from the authoritative baseline recorded above and must not recreate closed work.

## BIL-GLOBAL-001-FINAL verification candidate

- Branch: `phase-3-product-excellence`
- Parent HEAD: `9bc3b524a476280209e324637c9ac78de14daa44`
- Status: **Awaiting Product Owner VERIFY; not yet adopted or committed.**
- Engineering scope: final product composition, wearable payload preservation, native BLE session closure, embedded Arabic reporting, plugin runtime proof, commerce capability honesty, and evidence synchronization.
- External gates: iOS/macOS build and representative device/provider certification remain explicitly separate.
- Samsung wearable integration is not present in the production catalog and remains `Not Implemented`; no readiness claim is made.

## BIL-FOOD-002 candidate state

`BIL-FOOD-002` introduces build-time Python tooling for direct ZIP inspection and resumable SQLite staging. It is not adopted until Preflight, Apply, and Verify pass on the official baseline and the Product Owner authorizes the selective commit. No full USDA import is claimed by this package delivery.


## BIL-FOOD-003 candidate

- Canonical source-neutral schema and stable BIL-owned food identity.
- Source mappings, nutrient evidence, portions, barcode claims, and merge lineage.
- Build-time SQLite only; no mobile database or Flutter integration.

## BIL-FOOD-004 candidate

BIL-FOOD-004 adds the build-time normalization and quality layer on top of the canonical identity model. Verification must prove deterministic normalization, versioned scoring, explainable hard rejects, master-evidence preservation, and absence of deduplication or delivery tables. Not adopted until Product Owner Verify and commit.


## BIL-FOOD-005 — Deduplication and Canonicalization

Implemented explainable duplicate decisions, conservative automatic merge gates, conflict preservation, deterministic survivor/field selection, and merge lineage. No mobile catalog, search, or Flutter integration is introduced. Next package: BIL-FOOD-006 — Mobile Catalog Builder.


## BIL-FOOD-006 — Mobile Catalog Builder

Build-time derivation of compact, profile-driven mobile catalogs from accepted canonical foods. Master evidence remains outside delivery databases. Parent baseline: `14c6cdce71a23b22d9304b2e7b32d1270050da8c`. Next package: BIL-FOOD-007 — FoodRepository and Offline Search Foundation.

## Nutrition Platform — BIL-FOOD-007 candidate

Read-only mobile catalog repository and offline search/barcode integration prepared on baseline `a60ceb33ca548fea966cea50a8b98818744d899b`. No catalog update activation or rollback is included.
