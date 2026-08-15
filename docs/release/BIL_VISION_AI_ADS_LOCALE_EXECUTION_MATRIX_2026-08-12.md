# BIL Vision, AI Coach, Barcode, Ads, and Locale Execution Matrix

Evidence captured on 2026-08-12 against linked Supabase project
`tgmanzhqulksykhslrzb`. This matrix records verified state, not intent.

| Surface | Current evidence | State |
|---|---|---|
| AI Coach server | Deno contract tests 3/3; Deno type-check; deployed `ai-coach` ACTIVE v9, SHA `29bf7656...` | Verified |
| AI Coach authentication | Live unauthenticated POST returned HTTP 401 `authentication_required` | Verified |
| AI Coach tools | Explicit 21-tool allow-list; unknown actions discarded; arguments capped; all provider proposals forced through confirmation | Verified |
| AI Coach text safety | 12-message/4,000-character bounds, 20 KB context bound, 8,000-character reply bound, valid request-id required | Verified |
| AI Coach voice | Existing OS speech bridge, locale resolver, compact spoken reply, actual-seconds reservation/settlement contracts | Covered by repository contracts; live hardware remains final gate |
| Vision server locale | Shared exact BCP-47 resolver; deployed `analyze-meal` ACTIVE v37, SHA `0c154719...` | Verified |
| Barcode server | Exact GTIN-8/12/13/14 validation, 4 KB request bound, premium/auth/cache gates; deployed ACTIVE v6, SHA `e4d90bb...` | Verified |
| Barcode authentication | Live unauthenticated POST returned HTTP 401 `invalid_session` | Verified |
| BCP-47 | Shared helper tests 3/3; exact 25 tags; case/underscore canonicalization; ambiguous Portuguese and unsafe extensions fail closed | Verified |
| AdMob policy | Contextual-only, non-sensitive, eligible adult/region, free-plan policy; targeted tests 12/12 | Verified |
| AdMob lifecycle | Generation invalidation prevents stale loads after consent, provider, placement, or app lifecycle changes; stale native handles disposed and failed loads do not retry-loop | Verified; independent Flutter QA 14/14 |
| Locale target identity | Client `releaseTargets25` and server exact tag allow-list encode independent `pt-BR`/`pt-PT` and `zh-Hans`/`zh-Hant` targets | Verified |
| Locale full catalogs | 20 additional catalogs × 276 runtime/base/feature keys = 5,520 translated values; blanks 0, generator-token leaks 0, Unicode replacement characters 0 | Automated catalog gate PASS |
| Locale target quality | Target-script coverage 275–276/276 for script locales; English identity 0–9/276; `pt-BR`/`pt-PT` differ on 88 keys and `zh-Hans`/`zh-Hant` on 233 | Automated linguistic-structure gate PASS |
| Locale production promotion | All 25 exact tags are wired through runtime lookup, persistence, selector, RTL, AI Coach, Vision, and `set_language` validation | Flutter full-device smoke pending shared build lock |
| Webcam/equipment | Explicitly deferred until all non-hardware work is complete | Pending final gate |

## External production inputs still absent

These are fail-closed owner/provider inputs; no synthetic value was inserted:

| Input | Verified current effect |
|---|---|
| `BIL_USDA_API_KEY` Supabase secret | Not present. Barcode serves trusted cache hits and otherwise returns the label-capture fallback; it cannot perform a new USDA lookup. |
| Production AdMob publisher/app/banner IDs | Repository release values remain placeholders/empty. `productionConfigured` is false and release ads remain disabled. |
| Independent professional human review | Not present. Automated catalogs and QA are production-wired; this remains a post-automation linguistic sign-off, not a missing software implementation. |

## Exact locale targets

`ar`, `en`, `fr`, `es`, `tr`, `de`, `it`, `pt-BR`, `pt-PT`, `ur`, `fa`,
`hi`, `id`, `ms`, `ja`, `ko`, `zh-Hans`, `zh-Hant`, `ru`, `bn`, `vi`, `th`,
`pl`, `nl`, `uk`.

Production identity is deliberately per exact tag. Generic `pt` and `zh` are
rejected by persistence/server boundaries, so they cannot collapse the two
Portuguese regions or Chinese scripts. The automated catalog gate covers the
complete runtime surface; independent professional review remains separately
recordable without hiding an otherwise complete locale implementation.

## Commands used as evidence

```text
npx deno-bin@2.2.7 test --config supabase/functions/deno.json ...
  BCP-47 + AI Coach + GTIN: 8 passed, 0 failed

npx deno-bin@2.2.7 check --config supabase/functions/deno.json ...
  ai-coach, analyze-meal, barcode-lookup: PASS

flutter test test/features/ads/admob_and_policy_test.dart \
  test/launch_readiness/epic16_ad_privacy_contract_test.dart
  AdMob/AI server/tool parity/epic16 privacy independent QA rerun:
  14 passed, 0 failed

flutter test test/localization/...
  Locale rollout/release evidence batch: 8 passed, 0 failed

flutter test test/launch_readiness/ai_coach_usage_and_boost_contract_test.dart \
  test/launch_readiness/ai_coach_spoken_reply_contract_test.dart
  2 passed, 0 failed

tool/localization/audit_extended_runtime_copy.ps1
  catalogs=20, keys=276, translation_rows=5520, passed=true
```
