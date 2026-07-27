# BIL Next Packages

## Authoritative execution baseline

- Branch: `phase-3-product-excellence`
- Baseline HEAD: `9bc3b524a476280209e324637c9ac78de14daa44`

## Closed delivery streams

The following delivery streams are complete and are not future packages:

- Foundation — **Closed**
- Nutrition Platform — **Closed**
- AI Platform — **Closed**
- BIL Intelligence Integration — **Closed**
- BIL Intelligence Reality Closure — **Closed**
- Cloud Platform Core — **Closed**

## Next authorized package

No package is currently authorized by this document.

## Post-Cloud execution boundary

The official next starting point is the **post-Cloud phase** defined by the governing roadmap and authorized by the Product Owner. No completed AI, intelligence-integration, reality-closure, or Cloud Core package is future work.

The next package must belong to that post-Cloud phase. It must use the baseline above (or a later accepted HEAD) and must not re-list or reimplement completed AI, intelligence-integration, reality-closure, or Cloud Core packages.

## Package sequencing rule

When the next phase is authorized:

1. Record its accepted parent HEAD.
2. Define its testable exit criteria.
3. Deliver it through the Package Delivery Contract.
4. Update this document only after Product Owner verification and commit.

## BIL-GLOBAL-001-FINAL verification candidate

- Branch: `phase-3-product-excellence`
- Parent HEAD: `9bc3b524a476280209e324637c9ac78de14daa44`
- Status: **Awaiting Product Owner VERIFY; not yet adopted or committed.**
- Engineering scope: final product composition, wearable payload preservation, native BLE session closure, embedded Arabic reporting, plugin runtime proof, commerce capability honesty, and evidence synchronization.
- External gates: iOS/macOS build and representative device/provider certification remain explicitly separate.
- Samsung wearable integration is not present in the production catalog and remains `Not Implemented`; no readiness claim is made.

## Nutrition Platform

Current candidate: `BIL-FOOD-002`.

After successful full local verification and adoption, the next package is `BIL-FOOD-003 — Canonical Identity and Evidence Model`. Do not start it before the `BIL-FOOD-002` commit HEAD is supplied.


## BIL-FOOD-003 candidate

- Canonical source-neutral schema and stable BIL-owned food identity.
- Source mappings, nutrient evidence, portions, barcode claims, and merge lineage.
- Build-time SQLite only; no mobile database or Flutter integration.

## Nutrition Platform sequence update

Current candidate: `BIL-FOOD-004 — Normalization and Quality Engine`, parent `c1e074c21548ca63c9d48679e7774fcac9ef3512`.

After successful Verify and commit, the next package is `BIL-FOOD-005 — Deduplication and Canonicalization`. Do not begin automatic merge logic before the BIL-FOOD-004 commit HEAD is supplied.

