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

## BIL-FOOD-004 implemented boundary

BIL-FOOD-004 implements normalization and explainable quality assessment only. It does not create duplicate candidates or merge records; deduplication remains BIL-FOOD-005.

Policy `bil-food-quality-v1` stores every weighted component, threshold, warning, rejection reason, eligibility decision, and policy version. Hard rejects exclude records from delivery but do not delete source or canonical evidence from the master database.

Canonical normalization covers Unicode/whitespace normalization, search keys, documented unit aliases, and GTIN checksum validation. Unknown units remain unresolved rather than being guessed. Missing barcode is not treated as an error.


## BIL-FOOD-005 implemented boundary

BIL-FOOD-005 adds versioned, explainable duplicate decisions and canonical field selection. Automatic merges are limited to documented high-confidence evidence: the same stable source record, compatible valid GTIN/brand/package/profile evidence, or an exact compatible generic identity. Name similarity alone never auto-merges.

Every decision stores reasons, conflicts, confidence, policy version, and time. Applied merges retire but never delete a BIL identity, preserve source records, and write merge lineage. Mobile catalog generation, search, Flutter integration, and delivery databases remain outside this package.
