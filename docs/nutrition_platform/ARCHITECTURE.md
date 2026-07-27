# Architecture

## Design principles

- **BIL Food ID is canonical.** External IDs are references, never primary identity.
- **Offline first.** Daily search, barcode resolution, portions, and nutrient lookup must work without a network after the appropriate catalog is installed.
- **No direct source coupling.** Application code must not know USDA table shapes or source-specific field names.
- **Evidence over fabrication.** Missing nutrients remain missing; zero is used only when the source explicitly supports zero.
- **Historical truth is immutable.** Existing meal-item nutrient snapshots remain the source of truth for past logs.
- **Master and mobile are different products.** Full source preservation is not the same as device delivery.
- **Every transformation is reproducible.** Inputs, tool version, policy version, counts, rejects, and hashes are recorded.

## Logical layers

```text
External archives
  USDA Foundation / SR Legacy / Branded / future adapters
                |
                v
Source inspection and immutable manifest
                |
                v
Raw staging database
                |
                v
Normalization and evidence mapping
                |
                v
Master source database
                |
                v
Canonical identity resolution
                |
                v
Quality scoring and deduplication
                |
                v
Canonical BIL catalog
                |
        +-------+--------+
        |                |
        v                v
Core delivery DB     Market/branded delivery DBs
        |                |
        +-------+--------+
                v
CatalogRepository / Search / BarcodeResolver
                v
Existing BIL food selection and meal snapshot flow
```

## Physical database roles

### 1. Build manifest

`bil_food_build_manifest.json`

Contains source SHA-256 values, importer version, policy versions, timestamps, row counts, reject counts, and output hashes.

### 2. Raw staging

`bil_food_raw.sqlite`

Temporary, replaceable, and never shipped. Mirrors only the source fields needed for later normalization and audit. It may be recreated from immutable archives.

### 3. Master source catalog

`bil_food_master.sqlite`

Preserves normalized records from every source, source identifiers, evidence rows, portions, brand metadata, barcodes, and source lineage. It is a build artifact, not a mobile asset.

### 4. Canonical catalog

`bil_food_canonical.sqlite`

Contains BIL identities, canonical names, source links, barcode claims, canonical nutrient values with evidence, aliases, categories, quality scores, and merge lineage.

### 5. Delivery databases

- `bil_food_core.sqlite` — compact common foods, Foundation/SR-derived staples, canonical portions, aliases, and search indexes.
- `bil_food_branded_<market>.sqlite` — filtered branded products for a market or language profile.
- Future optional packs may be installed independently.

## Boundary with the current app database

The current Drift database stores user-created foods, favorites, recents, meals, and immutable meal-item nutrient snapshots. The catalog databases are read-only reference catalogs.

A future `CatalogFoodRepository` maps catalog records into the existing `UnifiedFood` domain model. Selecting a catalog food writes or resolves a durable local reference and snapshots nutrients into the meal item. Historical totals never depend on a later catalog update.

## Canonical ownership

- Catalog data: read-only, versioned, replaceable.
- User custom foods: user database, editable, sync candidate.
- Favorites and recents: user database, referencing BIL Food ID where possible.
- Historical meal snapshots: user database, never recalculated silently.
