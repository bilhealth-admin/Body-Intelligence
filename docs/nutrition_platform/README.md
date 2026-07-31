# BIL Nutrition Platform

This directory is the authoritative architecture for BIL food data.

BIL does not treat USDA, GS1, a barcode, or any other external identifier as the permanent identity of a food. The permanent identity is a BIL-controlled `bil_food_id`. External sources are evidence linked to that identity.

The platform separates four concerns:

1. **Source archives** — immutable external input files.
2. **Master data** — complete normalized source coverage for offline build and audit.
3. **Canonical BIL data** — deduplicated, scored, source-aware food identities.
4. **Delivery databases** — compact, versioned, signed databases for a device, market, or capability.

The current Drift `foods` table remains the user-facing local transaction boundary. This architecture does not replace it in one step. Future packages introduce a read-only catalog boundary and adapters while preserving historical meal-item nutrient snapshots.

## Reading order

1. `ARCHITECTURE.md`
2. `DATA_MODEL.md`
3. `IMPORT_PIPELINE.md`
4. `QUALITY_AND_DEDUPLICATION.md`
5. `MOBILE_DELIVERY.md`
6. `VERSIONING_AND_UPDATES.md`
7. `SECURITY_PRIVACY_AND_OPERATIONS.md`
8. `IMPLEMENTATION_PLAN.md`
9. `ADR-001-CANONICAL-BIL-FOOD-IDENTITY.md`
