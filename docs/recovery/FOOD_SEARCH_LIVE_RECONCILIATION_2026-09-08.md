# Food search live reconciliation — 2026-09-08

## Outcome

The food-search path is hybrid, not local-only. BIL searches the local,
community, and bundled USDA catalogue first. An authenticated miss is then sent
to the trusted Supabase `food-search` Edge Function, which queries USDA and
returns canonical food records for local materialization.

The reported non-local-search failure was reproduced at the source boundary.
The live Edge Function was healthy; the Flutter result pipeline discarded
canonical English USDA results after the Arabic query had already been
translated for USDA. A second issue allowed the valid word/brand `rise` to be
rewritten as `rice`, so a local rice match could prevent the cloud fallback.

Both Flutter-side defects are fixed in source. They are not present in an older
installed TestFlight/Play build until a new signed build is produced and tested.

## Read-only production evidence

- Supabase project: `tgmanzhqulksykhslrzb`.
- Live function: `food-search`, version 15, `ACTIVE`.
- Live/local `index.ts` raw SHA-256:
  `b72e0df5abbd3f6afe4ccb332f1bd131e82b637e8f6bd23d516912c527cebd21`.
- The source was compared byte-for-byte: 12,274 bytes on each side.
- An isolated temporary authenticated account was used only for the canary and
  was deleted successfully afterward. No food, acceptance, entitlement, or
  other production row was inserted for the canary.
- Authenticated invocation results:
  - `teff cooked` (`en`) -> HTTP 200, five results, first
    `Teff, cooked`.
  - `تيف مطبوخ` (`ar`) -> HTTP 200, five results, first
    `Teff, cooked`.
  - `cloud ear mushroom dried` (`en`) -> HTTP 200, four results.
- Read-only inspection of the bundled SQLite asset confirmed that Arabic
  `تيف مطبوخ`, `cloud ear mushroom dried`, and `rise` have no bundled match, so
  these canaries exercise the network-fallback boundary rather than a local hit.

The live Edge Function was not redeployed because production already contained
the newer version. Restoring that exact source locally closed code/cloud drift
without changing production state.

## Source corrections

1. `food_runtime_search_authority.dart` now preserves the trusted gateway order
   for a translated query and does not re-rank/drop the canonical USDA response
   against the original Arabic text.
2. `daily_log_meal_search.dart` no longer hides an explicit trusted USDA search
   result merely because it has no reviewed native display alias. The stricter
   localized-name rule remains in place for anonymous/popular browsing.
3. `food_search_assistance.dart` no longer rewrites `rise` to `rice`.
4. The Daily Log back path reopens the SearchAnchor with the original query and
   result set after leaving a food detail page.
5. The trusted resolver sends the detected typed-script language, with the app
   locale as fallback, to the Edge Function.

## Translation boundary

The production function translates supported non-English search phrases into
English before calling USDA. It does **not** translate every arbitrary USDA
food name. BIL's reviewed common-food and unit aliases cover the 25 app locale
tags; an unreviewed cloud result remains visibly identified by its canonical
USDA English name instead of being hidden or given a fabricated translation.

Therefore the verified claim is: search-query translation plus canonical USDA
results. Full machine translation of every returned identity is not claimed.

## Verification

- Edge/Deno function tests: 6/6 passed.
- Focused Flutter food/search/back-path tests: 70/70 passed in the independent
  review, including Arabic Teff, `rise`, 25-locale presentation, and back-path
  restoration.
- Bundled real-asset checks: 7/7 passed.
- Focused static analysis of Daily Log and nutrition services: no issues.
- Formatting check: no changes required.

One attempted Flutter in-process live-network test was rejected as evidence:
`flutter_test` blocks real HTTP and the test host had no SharedPreferences
plugin registration. Live service behavior was instead verified through the
authenticated production canary above, while the app-side result behavior is
covered with the equivalent deterministic gateway response.

## Remaining boundary

The exact signed iOS and Android app flow still needs device E2E: type an
unbundled English and Arabic food, wait for the authenticated cloud fallback,
open the result, return to the same query/results, and add it to the intended
meal. This remains deliberately after source/test closure and before store
release.
