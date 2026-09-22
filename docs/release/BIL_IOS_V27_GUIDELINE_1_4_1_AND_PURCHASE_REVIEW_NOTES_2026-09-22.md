# BIL iOS 1.0.0 (27) — Health References and Purchase Review Notes

Date: 2026-09-22
Baseline reviewed by Apple: iOS 1.0.0 (20), commit `fb36b90376222c105096b15b89c52a12b8242a76`
Candidate source branch: `codex/release-19-16-premium-health-fix`
Candidate base commit: `1269bd3e81db2c007fdd8fac7629277c29ce3110`

## Guideline 1.4.1 correction

The candidate does not rely on a disclaimer alone. Health guidance surfaces now provide a visible, tappable route to the supporting references at the point where the recommendation is shown.

Reviewer paths:

1. **More → Health sources & methodology**
2. **More → Help → Health information sources**
3. **Nutrition Pathways → Pregnancy nutrition → Maternal nutrition guide → WHO and pregnancy energy references**
4. **Targets and plan → References for these recommended targets**
5. **Nutrition Analytics → source icon**
6. **Weekly Report → source icon**
7. **AI Coach → References for this health guidance** beneath a coach answer

Pregnancy guidance links the displayed values to the following primary references:

- WHO daily iron and folic-acid supplementation in pregnancy: <https://www.who.int/publications/i/item/9789241501996>
- WHO calcium supplementation during pregnancy: <https://www.who.int/publications/i/item/9789241550451>
- WHO/UNICEF iodine recommendations for pregnant and lactating women: <https://www.who.int/publications/m/item/WHO-statement-IDD-pregnantwomen-children>
- National Academies pregnancy energy requirements: <https://www.ncbi.nlm.nih.gov/sites/books/NBK32812/>

Body-screening guidance links directly to:

- CDC adult BMI categories: <https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html>
- NICE BMI and waist-to-height guidance: <https://www.nice.org.uk/guidance/ng246/chapter/Recommendations#using-body-mass-index-bmi-and-waist-to-height-ratio-to-assess-overweight-obesity-and-central-adiposity>

The references page also explains that targets are formula-based educational starting points, not diagnosis or individualized medical treatment, and advises users to consult a qualified clinician for pregnancy, medical conditions, medication, symptoms, or individualized supplement dosing.

AI Coach has an additional server contract: health claims must name the supporting organization, numeric health guidance may use only the approved in-app reference catalog, and the model must not invent a source, dose, or threshold. The user-data `evidence` field is explicitly not represented as a scientific citation.

## Purchase comparison: Build 20 versus candidate 27

The candidate preserves the same five production product identifiers used by Build 20:

- `bil_premium`
- `bil_premium_annual`
- `bil_premium_ai_coach`
- `bil_premium_ai_coach_annual`
- `bil_ai_boost`

The candidate retains the successful Build 20 purchase model and adds the following safeguards:

- Restore waits for StoreKit/Play callbacks and server verification before publishing a result.
- Apple ownership is bound to the authenticated BIL owner and signed app-account token; a purchase owned by another BIL account is never transferred or acknowledged as restored.
- Account changes fence in-flight purchase and restore work so an old owner cannot receive a new owner's result.
- A late StoreKit stream error cannot replace a purchase or entitlement that already verified successfully.
- Empty or malformed entitlement refreshes do not erase a still-valid, previously verified entitlement.
- Refund, revocation, expiry, grace-period, cancellation, and renewal reconciliation use canonical store state and remain idempotent.
- `bil_ai_boost` is treated as the exact consumable product, uses a shared owner-scoped balance, and does not grant a subscription tier.
- Sensitive entitlement and Boost persistence is available only through service-role RPCs; direct client execution is revoked from `PUBLIC`, `anon`, and `authenticated`.
- Store prices, currency, offers, and trial eligibility remain storefront-derived; the app does not invent a price or trial.
- Gift and compensation notices use a centered, owner-scoped acknowledgement modal. They never invoke or incentivize an App Store or Google Play rating; the audited native review prompt remains a separate post-success flow governed by each store.

## Verification evidence

- Flutter commerce suite: **315 passed, 0 failed**
- Store backend Deno suite: **132 passed, 0 failed**
- Launch-readiness store/Boost/privacy contracts: **14 passed, 0 failed**
- App Store rejection compliance contract: **4 passed, 0 failed**
- Deno type-check: `store_backend.ts` and `ai-coach/server.ts` passed
- Full Flutter analysis: **no issues found**
- Full Flutter suite after the final fixes: **5,456 passed, 6 intentionally skipped, 0 failed**
- Store transaction queue: **32 passed, 0 failed**, including ten repeated passes of the previously timing-sensitive startup-fault scenario

These are source and automated-test results. Signed-build, TestFlight-device, and App Review results must be recorded separately after the release workflow runs.
