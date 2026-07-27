# Mobile delivery

## Principle

The mobile catalog is a product derived from canonical data, not a copy of the master database.

## Delivery profiles

### Core profile

Contains common generic foods, high-quality Foundation/SR records, essential aliases, portions, macro and selected micronutrients, categories, and search indexes.

Target characteristics:

- usable offline on first launch;
- compact enough for application delivery or first-run installation;
- multilingual search-ready;
- no dependence on network availability.

### Branded market profile

Contains branded foods selected by explicit market and quality rules:

- valid identity;
- valid or explainably absent barcode;
- adequate nutrient evidence;
- supported market/language;
- deduplicated canonical identity;
- active source status;
- delivery quality threshold.

Profiles may be split by market, region, language, or category. Two million raw branded records are not shipped automatically.

## Packaging options

- Small core DB bundled with the application.
- Optional branded packs downloaded after installation.
- Delta updates for installed packs.
- Server or CDN distribution is future work and requires integrity/signature verification.

## Runtime integration

A catalog database is opened read-only. The app queries through a repository boundary and maps results into `UnifiedFood`.

On selection:

1. Resolve `bil_food_id`.
2. Store favorites/recents by canonical identity where supported.
3. Snapshot serving and nutrient values into the meal item.
4. Historical logs remain unchanged after catalog updates.

## Search indexes

Delivery databases should include only indexes required at runtime:

- FTS for names and aliases;
- normalized exact name index;
- barcode index;
- brand/category filters;
- quality/rank fields.

Build-only lineage and raw evidence payloads remain outside the mobile database unless required for explanation.

## Size budget

No fixed size is approved in this architecture package. Each delivery package must publish:

- uncompressed and compressed size;
- row counts;
- index size;
- representative query latency;
- cold-open latency;
- memory impact;
- device storage impact.

A later package sets release budgets based on measured iPhone, Android, and Windows behavior.
