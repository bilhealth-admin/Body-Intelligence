# ADR-001: Canonical BIL Food Identity

## Status

Accepted.

## Context

External food sources use identifiers controlled by their publishers. Barcodes can be reused, corrected, market-specific, conflicting, or absent. Names are mutable and ambiguous. BIL requires durable identity for favorites, recents, aliases, recommendations, catalog updates, and future source expansion.

## Decision

BIL owns an immutable `bil_food_id` for every canonical food identity. USDA IDs, barcodes, source names, and future provider IDs are references linked through evidence tables.

No application feature may use an external identifier as the permanent domain identity.

## Consequences

### Positive

- Sources can be added or replaced without rewriting user-facing identity.
- Conflicts and corrections can be preserved.
- Catalog updates do not invalidate favorites and recents.
- Merge lineage and redirects are possible.
- Historical meal snapshots remain stable.

### Costs

- Identity resolution becomes an explicit build stage.
- Merge and split policies must be governed.
- More lineage tables and tests are required.

## Rejected alternatives

- USDA FDC ID as primary identity: source-coupled and incomplete for future sources.
- Barcode as primary identity: absent for generic foods and not reliably unique across time/market.
- Normalized name as primary identity: ambiguous and unstable.
