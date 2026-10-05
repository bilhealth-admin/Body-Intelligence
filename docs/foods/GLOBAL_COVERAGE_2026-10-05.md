# Evidence-led global barcode and Iraq/Jordan coverage expansion

Development only: feat/foods-arabic-recipes-25-locales-20261005.
Starting point d97cbd119722d92ec83be55a5c9dc03c07887282.
No native store builds, uploads, release-branch changes or Production deployment.

## Competitive research (official product claims, checked 2026-10-05)

- MyFitnessPal: barcode scanning is Premium. Its support page acknowledges
  that new or region-specific products can be missing and supports adding them.
  https://support.myfitnesspal.com/hc/en-us/articles/360032624771-How-to-use-the-Barcode-Scanner
- Cronometer: free unlimited barcode scanning, custom recipes, company claims
  of over one million foods and tracking up to 95 nutrients. Free scanning alone
  is therefore not a unique competitive advantage.
  https://cronometer.com/features/free-nutrition-tracking-app.html
- YAZIO: recipe name/ingredient search and preparation/diet filters; its help
  page claims more than 3,000 recipes, not verified here by independent counting.
  https://help.yazio.com/hc/en-us/articles/12294574525201-How-can-I-apply-a-filter-or-search-through-the-Recipes-tab
- FatSecret Platform: claims 2.3M unique foods, 62+ country datasets, 26
  languages and 19,000+ recipes. Commercial platform access is not an open
  licence to copy its catalog into BIL.
  https://platform.fatsecret.com/platform-api

BIL is NOT certified to exceed those apps in catalog size, accuracy, latency
or scan success. Translated versions and GTIN zero-padding variants must never
be counted as additional unique products or distinct recipes.

## Implemented barcode changes

- Exact identity comparison across valid GTIN-8/12/13/14 zero-padding variants.
  Nonzero package indicators stay distinct. Valid Arabic/Persian digits accepted.
- Upstream OFF code is verified against the requested product, not blindly
  relabelled. USDA checks equivalent exact identifiers, not fuzzy food names.
- Existing cache and OFF partial records no longer preclude a complete exact
  USDA result. Do not blend nutrients from different providers/label versions.
- Cache read/write errors no longer discard a valid live provider response.
- Distinguish a real miss from an upstream outage. Retain partial identity
  without inventing missing nutrient values or a fake verified flag.
- Bounded requests, fixed provider hosts, corrected app/contact User-Agent and
  per-warm-isolate Retry-After cooldown. This is NOT a global rate limiter.
- Preserve all 25 canonical locale tags and only use names actually returned
  by providers; never invent translations for unavailable language variants.
- Keep the original Premium entitlement gate. Data-provider pricing and app
  subscription packaging are separate; this task does not change commerce.

Reference: https://www.gs1.org/edi-xml/technical-user-guide/Item_Numbers
OFF guidance: https://openfoodfacts.github.io/openfoodfacts-server/api/
Current published limits: 15 product reads/min/IP; 10 searches/min/IP. Use
bulk JSONL/CSV daily exports for large ingestion, not API scraping or live
search-as-you-type. Before scaling Production, implement coordinated per-egress
provider budgeting or a locally hosted mirror; a warm-isolate cooldown is insufficient.

## Iraq and Jordan

The additional Iraqi/Jordanian lexicon distinguishes regional dishes rather
than replacing them with generic rice or meat. It extends the previous lexicon
and preserves existing output ordering. Examples: masgouf, kubba Mosul versus
kubba Halab, kleicha, rashouf, makmoura and galyet bandora. These are SEARCH
SPELLINGS ONLY, not newly verified nutrient-bearing recipes or products.

Primary culinary sources used for identifying regional dishes and spellings:
- https://www.iraqicookbook.com/recipes/stew_and_rice
- https://www.iraqicookbook.com/recipes/iraqi_cookies
- https://maryamsculinarywonders.blogspot.com/p/recipe-index.html
- https://maryamsculinarywonders.blogspot.com/2013/12/530-iraqi-thareed-bagilla.html
- https://en.roya.tv/videos/114150
- https://en.roya.tv/videos/114168
- https://www.dibeen.com/products/makmoura-%D9%85%D9%83%D9%85%D9%88%D8%B1%D8%A9
No copyrighted recipe instructions or nutrition numbers were copied from those
pages. Iraqi official food-composition data listed by FAO is restricted-access;
its mere existence is not permission to import it.
https://www.fao.org/food-composition/tables-and-databases/detail/%28iraq%29-food-composition-table-for-iraq/en

## Actual regional product acquisition, separate from names

`tool/catalog/off_regional_import.py` builds a SEPARATE ODbL review database
from a local OFF JSONL export, with bounded memory per source line. Its sample
mode makes only two data-acquisition GET requests, one per target market, up to
50 products each. It is not a complete regional catalog or a runtime dependency.

The importer preserves exact GTINs, real source URLs, source hashes, market tags,
original names and missing nutrient values. Invalid GTINs, non-foods and wrong
markets are rejected; incomplete macros and volume-based records are retained
for review but NOT silently converted to 100g foods. Valid complete mass-basis
records get the existing mobile catalog schema with source quality below the
app's verified threshold. Identical GTIN variants are not double-counted.

Review artifacts contain attribution/licence text, selected public source data,
SQLite catalog and exact counts/digests. No photos or private BIL data. They are
not automatically activated, uploaded to BIL Production or included in a build.
Before activation: preserve ODbL share-alike and visible source attribution,
review real labels and mass/volume basis, and test the installed-pack flow.
The current mobile adapter's generic source label needs attribution handling
before this OFF pack is exposed to end users.

## Acceptance benchmark still required for a superiority claim

Use a frozen independently sourced, deduplicated corpus of real labels/GTINs
from Iraq, Jordan, other Arabic markets and worldwide markets. Test each app
on the same corpus/date/platform. Measure top-1 exact product match, wrong
variant rate, complete-nutrition coverage, missing-product recovery, Arabic
dialect retrieval, p50/p95 latency, repeat offline success and provenance.
Report by country with denominators. Set a goal of zero false verified matches;
never treat missing results, translated aliases or cached copies as extra foods.
No such head-to-head device benchmark has been executed in this checkpoint.

## Evidence status

Read CI logs for the exact HEAD. The initial barcode test run failed on a test
callback RequestInit typing error; corrected without disabling type checking.
Only a subsequent green run validates this change. Source acquisition can fail
independently of code tests; preserve its unavailable result rather than
reporting zero products as a complete market inventory.
