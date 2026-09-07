# BIL multilingual food search design — 2026-09-06

## Decision

The app must not ship a manually translated copy of the entire USDA catalog.
FoodData Central is the nutrition authority, but its food descriptions are
source data rather than a 25-language product dictionary. A static dictionary
would be incomplete, expensive to maintain, and unsafe for branded identities.

The search contract is therefore layered:

1. The offline reviewed lexicon handles common foods and synonyms immediately
   in all 25 supported writing systems.
2. An explicit search never hides an authoritative result merely because a
   reviewed display translation is missing. The source name is shown as the
   fallback.
3. When the local catalog has no match, the authenticated `food-search` Edge
   Function translates only the typed phrase to English and then queries USDA.
   The original query is preserved in the response; `search_query` records the
   phrase actually sent to USDA.
4. USDA's authoritative food name and nutrient values remain unchanged. Brand
   and barcode identities are not machine-renamed.

## Production activation

Set the following Supabase Edge Function secret:

```text
BIL_TRANSLATION_API_KEY=<Google Cloud Translation Basic API key>
```

The USDA key remains a separate secret:

```text
BIL_USDA_API_KEY=<USDA FoodData Central key>
```

The translation key is read only by the Edge Function. It must never be added
to Flutter code, an APK/IPA, GitHub source, or a public client configuration.
If it is absent or the provider times out, the function falls back to the
reviewed offline aliases and the original USDA query rather than failing the
whole search.

For the existing Supabase project, the function also accepts the already
stored short secret names `USDA` and `Translation` as compatibility aliases.
New environments should use the canonical `BIL_USDA_API_KEY` and
`BIL_TRANSLATION_API_KEY` names above.

## Future display localization

Query translation makes every supported language eligible to search. Display
translation is a separate concern: generic USDA names can be translated on
demand and cached by `(fdc_id, locale, source_name_hash)` after review, while
branded names and technical variants should remain source-authoritative. This
avoids treating an unreviewed machine translation as a nutrition identity.
