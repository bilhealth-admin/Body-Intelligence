# BIL v1 — Epic 5 Food Trust Coverage

- **Complete/proven:** validated GTIN handling; local, downloadable, and network
  lookup order; Arabic/English search; USDA and regional catalog packs;
  source/confidence propagation; missing nutrients remain missing; food versus
  beverage, alcohol, supplement, medicine, tobacco, personal care, pet food,
  household, general product, and unknown classification.
- **Completed in Epic 5:** signed-in identity-only product submissions from both
  barcode entry journeys; no inferred nutrient payload; original observed
  source/confidence retained; moderator-only review queue and final decision;
  identity-only review UI handles absent nutrients safely.
- **External operations:** deploy the Supabase migration and monitor live catalog
  endpoints/manifests. Network providers and user evidence can be unavailable;
  BIL then reports degradation or unknown identity and does not fabricate data.
- **Mocks:** none are authoritative runtime catalog or nutrition sources.
