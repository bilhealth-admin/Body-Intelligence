# BIL-FOOD-009 — End-to-End Nutrition Closure

- One delivery schema contract uses `food`.
- Nutrient delivery selects a deterministic complete evidence row.
- Catalog versions are immutable by version and SHA-256.
- Search and barcode resolution use SQLite indexes/FTS.
- Hashing is streamed.
- Flutter resolves the active catalog through `catalog_registry.json`.
