# BIL Known Limitations

## Authoritative execution baseline

- Branch: `phase-3-product-excellence`
- Baseline HEAD: `9bc3b524a476280209e324637c9ac78de14daa44`

## Current limitations and activation boundaries

### Scientific and product interpretation

- BIL intelligence is evidence-driven and explainable, but it is not a substitute for clinical diagnosis or emergency medical care.
- Confidence describes the quality and coverage of available evidence; it is not absolute medical certainty.
- Missing or stale evidence can reduce confidence or force safe abstention.

### Local logging completeness

- Forecasts and actions depend on factual local measurements and recorded nutrition, hydration, activity, sleep, and decision history when those inputs are required.
- Unlogged intake, supplements, measurements, activity, or symptoms are not invented.
- A supported projected weight or weight-based action requires factual weight-event provenance within the accepted analysis window.

### External Cloud activation

Cloud Platform Core is closed at the provider-neutral production boundary. Hosted operation still requires Product Owner-controlled infrastructure and configuration, including as applicable:

- owned authentication and transport services;
- server-side authorization and row-level security;
- encryption-key custody and secure device storage;
- deployment credentials and environment configuration;
- production monitoring, alerting, backup drills, and disaster recovery;
- platform-specific background execution and physical-device validation.

These are deployment and operational activation boundaries, not unfinished Cloud Core architecture. The application must remain honestly local-only when those external ports are not configured.

### Release readiness

Owned application identifiers, signing material, store records, privacy disclosures, physical-device validation, and current platform-policy review remain required before public release where they are not already completed.

## Closed-stage status

- Foundation — **Closed**
- Nutrition Platform — **Closed**
- AI Platform — **Closed**
- BIL Intelligence Integration — **Closed**
- BIL Intelligence Reality Closure — **Closed**
- Cloud Platform Core — **Closed**

Historical package limitations and delivery-candidate notes are available through Git history and package archives and are not current limitations.

## BIL-GLOBAL-001-FINAL verification candidate

- Branch: `phase-3-product-excellence`
- Parent HEAD: `9bc3b524a476280209e324637c9ac78de14daa44`
- Status: **Awaiting Product Owner VERIFY; not yet adopted or committed.**
- Engineering scope: final product composition, wearable payload preservation, native BLE session closure, embedded Arabic reporting, plugin runtime proof, commerce capability honesty, and evidence synchronization.
- External gates: iOS/macOS build and representative device/provider certification remain explicitly separate.
- Samsung wearable integration is not present in the production catalog and remains `Not Implemented`; no readiness claim is made.

## BIL-FOOD-002 limitations

- The package verifies archive structure and headers against the supplied USDA ZIPs but does not claim completion of the full multi-million-row import.
- Resume currently replays CSV parsing from the beginning of an archive member and skips rows through the last committed row. It avoids duplicate database work but ZIP/CSV streams do not provide constant-time random row seeking.
- Raw payloads are retained as JSON in staging for source fidelity; normalized typed master tables are intentionally deferred to `BIL-FOOD-003` and later packages.
- Generated SQLite databases and large reports are local build outputs and must not be committed.


## BIL-FOOD-003 candidate

- Canonical source-neutral schema and stable BIL-owned food identity.
- Source mappings, nutrient evidence, portions, barcode claims, and merge lineage.
- Build-time SQLite only; no mobile database or Flutter integration.

## BIL-FOOD-004 limitations

- Policy v1 thresholds are documented defaults and require later full-data distribution review; they are not silently tuned from synthetic tests.
- No duplicate candidate generation or automatic merge is implemented.
- No mobile catalog is produced.
- Unknown units are left unresolved rather than guessed.
- Full USDA-wide quality distribution has not been run by this package.


## BIL-FOOD-005 — Deduplication and Canonicalization

Implemented explainable duplicate decisions, conservative automatic merge gates, conflict preservation, deterministic survivor/field selection, and merge lineage. No mobile catalog, search, or Flutter integration is introduced. Next package: BIL-FOOD-006 — Mobile Catalog Builder.


## BIL-FOOD-006 — Mobile Catalog Builder

Build-time derivation of compact, profile-driven mobile catalogs from accepted canonical foods. Master evidence remains outside delivery databases. Parent baseline: `14c6cdce71a23b22d9304b2e7b32d1270050da8c`. Next package: BIL-FOOD-007 — FoodRepository and Offline Search Foundation.
