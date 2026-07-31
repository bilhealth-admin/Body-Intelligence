# Data model

The model is intentionally source-neutral. Names below are canonical concepts; exact SQL is defined in an implementation package.

## Identity

### `canonical_food`

- `bil_food_id` — stable BIL-owned UUID or ULID; immutable.
- `food_kind` — generic, branded, recipe, prepared, ingredient, supplement, or unknown.
- `canonical_name_en`
- `canonical_name_ar`
- `category_id`
- `processing_level`
- `default_portion_id`
- `quality_score`
- `status` — active, deprecated, quarantined, merged.
- `merged_into_bil_food_id` — populated only for retired identities.
- `created_at`, `updated_at`

### `source_record`

One normalized source record per external item.

- `source_record_id`
- `source_system` — USDA_FOUNDATION, USDA_SR_LEGACY, USDA_BRANDED, future adapter.
- `source_version`
- `external_id`
- `bil_food_id` nullable until resolved
- `source_payload_hash`
- `source_modified_at`
- `imported_at`
- `record_status`

Unique: `(source_system, source_version, external_id)`.

## Names and aliases

### `food_name`

- `bil_food_id`
- `language`
- `name`
- `normalized_name`
- `name_type` — canonical, source, brand, alias, transliteration, user-known.
- `source_record_id` nullable
- `confidence`

Search normalization stores derived forms but never overwrites the original display name.

## Brands and barcodes

### `brand`

- `brand_id`
- `display_name`
- `normalized_name`
- `owner_name`

### `barcode_claim`

- `normalized_gtin`
- `bil_food_id`
- `source_record_id`
- `claim_status` — active, conflicting, retired, invalid.
- `confidence`
- `market_code`
- `effective_from`, `effective_to`

A barcode is not globally unique forever. Conflicts are retained and resolved by evidence, market, date, and quality.

## Nutrients

### `nutrient_definition`

- `bil_nutrient_id`
- `canonical_name`
- `unit`
- `nutrient_group`
- `source_mapping`

### `nutrient_evidence`

- `bil_food_id`
- `bil_nutrient_id`
- `amount_per_100g`
- `basis` — per_100g, per_100ml, per_serving, calculated.
- `source_record_id`
- `derivation_method`
- `confidence`
- `is_explicit_zero`
- `measured_at` nullable

### `canonical_nutrient`

Selected current value derived from evidence by a versioned policy.

- `bil_food_id`
- `bil_nutrient_id`
- `amount_per_100g`
- `selected_evidence_id`
- `selection_policy_version`
- `confidence`

Missing is represented as missing. It must not be converted to zero.

## Portions

### `portion`

- `portion_id`
- `bil_food_id`
- `amount`
- `unit_code`
- `gram_weight`
- `description_en`
- `description_ar`
- `source_record_id`
- `confidence`

Canonical calculations normalize to grams or milliliters, while preserving source portions for display.

## Classification and relations

### `category`

Hierarchical BIL-owned taxonomy.

### `food_relation`

- `from_bil_food_id`
- `to_bil_food_id`
- `relation_type` — alternative, variant, same_family, replacement, ingredient_of, successor.
- `confidence`
- `evidence`

## Quality and lineage

### `quality_assessment`

Stores component scores, rules fired, reject/quarantine reasons, policy version, and evaluated timestamp.

### `merge_event`

Records every canonical merge or split, previous identities, chosen survivor, reason, evidence, and policy version. No destructive merge is allowed without lineage.


## Implemented by BIL-FOOD-003

The build-time canonical schema is implemented in `tool/nutrition_platform/canonical_model.py`. Identity generation is BIL-owned and source-neutral; source IDs and barcodes remain evidence references.
