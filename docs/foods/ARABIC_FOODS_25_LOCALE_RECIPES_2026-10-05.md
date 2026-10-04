# Arabic food search and 25-locale recipes: additive development checkpoint

Scope: owner-approved food/recipe coverage expansion. Isolated development
branch `feat/foods-arabic-recipes-25-locales-20261005`, based on
`1eca2b39bd50591930e5c8f0eccdd96932745317`. Store iOS35/Android32,
audited release branches, Production data and services are not modified.
No signed build, TestFlight upload, Play upload or automatic deployment.

## Existing assets inspected, not newly added

The signed iOS35 artifact and existing recipe release index/shards contain:
- 1,500 distinct recipes, including 300 with Arabic as their primary locale.
- Every recipe has nonempty titles, ingredient strings and steps in the 25
  application locale tags (37,500 localized records, NOT 37,500 recipes).
- Primary-locale counts are 300 each for ar/en/es/fr/tr; this is NOT a claim of
  25 independently native cuisines or all recipes from every country.
- Translation metadata declares 30,381 machine-translated, 5,631
  deterministic-localized and 1,488 native-reviewed entries. These labels are
  provenance, not independent certification of translation or recipe quality.
- 30 recipe shards and index SHA256
  `6c9f4773f6221f5468c28e02d3897271009e6e36c3f0d9dd6bdca2fe66628638`.
- Bundled USDA core: 101,207 food rows; 8,170 have all four primary energy/
  protein/fat/carbohydrate columns populated. Do not advertise complete
  nutrition for every row or equate these rows to branded products.

The existing barcode backend already queries Open Food Facts and USDA.
The text-search backend currently accepts/normalizes USDA records. A new OFF
text-search response cannot safely be labelled as USDA or given invented FDC
identifiers merely to pass the existing client decoder.

## Additions implemented

- 89 regional food/dish/brand concepts with 298 authored alternative spellings.
- Whole-phrase longest-match expansion, Arabic diacritics/digits/spelling
  normalization, and preserved quantities/remaining query tokens.
- Original multilingual lexicon preserved byte-for-byte as
  `food_multilingual_core_lexicon.dart` (Git blob
  `70086ed2fb715f76c9630a7551d18f522314babd`); the public wrapper appends the
  regional expansion without deleting the previous results.
- Existing FoodSearchAssistance consumes that wrapper, including the existing
  local/online search flow. Prefer more-specific translated outbound hints so
  a known brand plus food does not reduce to the generic food alone.
- Ten Python validator tests and a full structure/hash/index consistency audit
  for all 25 recipe locales; focused Dart tests for regional spellings,
  isolation, legacy language preservation and actual outbound search hints.

Initial checkpoint `ca67e670c3128c414287967a4487abe9c353a89e` passed GitHub
Actions run `37244037942`: 10 Python tests, the full actual recipe audit, and
8 Dart tests. The follow-up hint-selection change adds 3 regressions; its own
workflow result, not that earlier run, determines validation of the follow-up.

## Boundaries and remaining work

These changes add SEARCH ALIASES, not new nutrient-bearing product records or
new recipes. No brand spelling proves that any particular SKU is present in
an upstream database. Missing nutrients stay missing; no invented barcodes,
provider IDs, or verified flags were added.

Broad branded-food ingestion and OFF name search remain a separate step:
respect API quotas/custom User-Agent and ODbL attribution/share-alike; keep
provider provenance and GTIN identity distinct, reject non-food and incomplete
nutrition appropriately, and test any new client/backend contract before
release. Never use a public OFF search endpoint as unbounded search-as-you-type
or combine databases without resolving the licence obligations.

Recipe text exists in all 25 locales, but linguistic/culinary quality review
and expansion with additional genuinely sourced regional dishes remain open.
This checkpoint does not certify all 25 translations as correct.

Client search changes require inclusion in a later app build to reach users.
Existing iOS35/Android32 are unchanged and need not be rebuilt just to retain
current functionality. No public release readiness claim is made here.
