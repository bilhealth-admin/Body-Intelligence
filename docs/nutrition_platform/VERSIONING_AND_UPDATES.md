# Versioning and updates

## Independent version domains

- Importer version.
- Source-adapter version.
- Canonical schema version.
- Quality-policy version.
- Deduplication-policy version.
- Delivery-profile version.
- Data release version.

Changing one domain must not ambiguously change all others.

## Data release identifier

A delivery database manifest includes:

- BIL catalog release version;
- schema version;
- profile ID and market;
- source versions and SHA-256 values;
- canonical build ID;
- record counts;
- database SHA-256;
- minimum compatible app version;
- generated timestamp;
- signature metadata when signing is introduced.

## Update rules

- Full replacement is the initial supported strategy for small core catalogs.
- Delta updates may be introduced only after identity and migration contracts are proven.
- Updates are downloaded to a temporary path, verified, opened, integrity-checked, and atomically activated.
- Previous working catalog remains available until activation succeeds.
- User data is never stored in a replaceable catalog database.

## Identity continuity

`bil_food_id` survives source updates. Source records may be added, deprecated, or remapped. Merge and split events are versioned.

If one identity is merged into another, the old ID remains resolvable through a redirect. If an identity is split, existing historical references remain attached to the original identity unless the user explicitly corrects them.

## Rollback

The runtime retains metadata for the previous installed catalog and may atomically restore it if the new database fails verification or opening.
