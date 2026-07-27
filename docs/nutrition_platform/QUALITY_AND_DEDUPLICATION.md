# Quality and deduplication

## Quality score

The score is explainable and versioned. It is not a hidden machine-learning probability.

Recommended components, each normalized to 0–100:

- Source authority.
- Identity completeness.
- Nutrient completeness.
- Portion quality.
- Barcode validity.
- Recency.
- Internal consistency.
- Conflict penalty.

The final score and every component are stored with the policy version.

## Source authority baseline

Initial ordering, subject to evidence:

1. Laboratory/analytical Foundation evidence.
2. Curated SR Legacy evidence.
3. Manufacturer-labelled branded evidence.
4. Community-verified evidence.
5. User-entered evidence.

Source authority does not automatically override a newer, more complete record. Selection rules remain nutrient-specific and explainable.

## Hard rejects from delivery

Examples:

- Missing or unusable name.
- Invalid numeric values or impossible units.
- All key macronutrients missing.
- Corrupted encoding that cannot be recovered.
- Explicitly withdrawn or deleted source record with no historical requirement.
- Invalid barcode when barcode is the sole identity evidence.

Rejected rows remain counted in the build report. Depending on severity, source rows may remain in master quarantine.

## Deduplication rules

### Safe automatic merge

Allowed only when evidence is strong, for example:

- Same stable external record across source versions.
- Same valid GTIN, same brand, compatible package description, and no active conflict.
- Exact normalized generic food identity with compatible category and nutrient profile.

### Candidate only, no automatic merge

- Similar name but different brand.
- Same product name with different package sizes or formulations.
- Barcode conflict across markets or time.
- Nutrient values materially disagree.
- Generic and branded products appear similar.

### Never merge solely by

- Fuzzy name similarity.
- Calories alone.
- Brand alone.
- Shared category.
- A truncated or invalid barcode.

## Duplicate selection

When multiple source records map to one BIL identity:

- retain all source links;
- select canonical fields independently;
- preserve contradictory evidence;
- record why the selected value won;
- never delete lineage.

## Conflict handling

Conflicts produce explicit records. Delivery can choose the highest-quality active claim while retaining alternatives for later correction. A conflict must never silently overwrite another claim.
