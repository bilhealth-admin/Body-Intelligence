# Apple guideline inventory update — 20 October 2026

This document updates four policy mappings for the frozen application source `5da21a5660b26e59e9ead7b0927d4ed7cf2c3996`. It changes documentation only. It does not change the application, native settings, backend, saved store fields or review notes. A separate documentation-branch commit must retain this source association rather than be described as a newly tested application binary.

## Limited inventory delta

| ID | Action | State retained |
|---|---|---|
| A003 — 1.2 | Refresh the official read date and coverage of Community plus AI creation, safeguards and handling obligations; replace generic source references with current paths | BLOCKED / P0 |
| A016 — 2.3.1(a),(b) | Refresh the mapping to specific review notes, accessible changes and truthful marketing; refer concealed-feature review to A101 | BLOCKED / P0 |
| A100 — 2.3.14 | Add the missing creative-asset inventory row | BLOCKED / P0 |
| A101 — 2.5.19 | Add the missing concealed or undocumented functionality row | BLOCKED / P0 |

The official [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) and [App Store asset guidance](https://developer.apple.com/app-store/asset-best-practices/) were reread on 20 October 2026. The refreshed rows contain the concise requirements and evidence locations. No other historical row is redatestamped or upgraded by this delta. The inventory's original `source_base` stays intact as historical provenance; the updated rows and companion association receipt identify the application source for this limited review.

## Source reassociation evidence

The exact GitHub comparison from `6bf23994712ffbdcb2d8179defec5852e5d08ae1` to `5da21a5660b26e59e9ead7b0927d4ed7cf2c3996` contains three commits. Pinned reads confirm unchanged contents and Git blob identities for the AI safety report service/sheet/model, AI Edge entrypoint, app/router entrypoints, the three named removal/visibility tests, policy validator/tests and original policy inventory. The four requirement mappings therefore retain their prior evidence boundaries while associating with the integrated source.

The advertising page now renders `AdvertisingDisclosureRuntimeCopy.forLocale(locale)` at `lib/features/ads/advertising_privacy_page.dart:453`, with authored copy in `lib/app/localization/runtime_copy_advertising_disclosure.dart`. It separates recorded BIL data in ad requests from technical/ad-interaction data that Google's SDK may process, including IP-derived approximate location. This wording correction is relevant to truthful product disclosure under A016. It does not prove absence of tracking or resolve the unchanged privacy rejection.

[Focused advertising run39416387669](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39416387669) completed successfully on the exact integrated source. GitHub reports successful format, Flutter analysis and advertising-regression steps. This is a bounded existing CI result, not a new execution by this documentation task or final-binary/store acceptance. Agent-authored locale copy is not a claim of independent human linguistic review.

## Evidence boundaries

The following existing source tests were inspected at the frozen source: `test/app/router/mobile_admin_removal_contract_test.dart`, `test/app/router/mobile_admin_route_behavior_test.dart` and `test/features/community/community_admin_moderation_visibility_contract_test.dart`. They describe shipping import-closure checks, rejection of removed operator routes, and preservation of member reporting/blocking. No Flutter test was executed as part of this documentation edit. These scoped checks do not establish that every feature, native entrypoint, configuration or remote flag in a final signed binary is documented and reviewable.

Creative assets are a separate App Store format. Repository screenshots and IAP review screenshots do not prove that this format has been supplied, visually reviewed or accepted in the live store. A100 therefore uses conservative applicability while the actual App Store inventory is unknown. Verified absence can support a later not-applicable decision for that specific format; it must not be inferred from missing local files. This update neither removes required IAP review information nor changes in-app price disclosures.

Actual saved Notes for Review, feature access, published handling procedures and final Store assets still require direct reconciliation. There is no new claim of creative-asset compliance, runtime compliance, store acceptance, rejection resolution or release readiness. The existing privacy rejection and A084 status are unchanged.

## Validation

The unchanged policy validator from the frozen source accepts the proposed inventory, preserves its root schema and returns `BLOCKED`. Its nine existing offline unit tests pass. A separate delta check confirms that only A003 and A016 changed and that only A100 and A101 were added; all four remain applicable, `BLOCKED`, P0 and dependent on final device/store evidence. The other136 rows remain identical.

See [association and validation receipt](evidence/policy-gate-20261015/apple-guideline-update-20261020.json) for the precise source association, paths and validation scope. A passing schema check confirms record structure and retained fail-closed behavior; it does not confirm that a policy requirement is satisfied by the app.
