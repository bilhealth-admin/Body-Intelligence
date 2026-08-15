# BIL MFP exhaustive emulator runtime — 2026-08-12

Build SHA: `D0CB6523E09CE7201C33A452E2AA315CAA6465C28878F76681E6D8607A036250`.

## Strict33

- 33/33 cold routes rendered on emulator with fresh XML.
- 30 `EMULATOR_PASS_ROUTE`; 3 `PHYSICAL_REQUIRED`: Meal Scan recognition accuracy, physical regional GTIN recognition set, and live speech provider/dialect run.
- Four original interaction captures plus 18 safe interaction/readback rows now exist. Batches 2–4 cover logging, weight/history, nutrition, fasting, meal planner, goals/preferences, sharing, connected health, dashboards and weekly report. All 18 changed from base; 16 reproduced the same hierarchy after restart and 2 remain action-only. This proves state response/hierarchy persistence, not the semantic correctness of every stored value.
- Matrix: `artifacts/runtime_evidence/strict33_runtime/matrix.csv` with explicit entitlement name, route, required state, action, result, SHA and evidence.

## Settings84

- 84/84 row routes rendered; 35 routes and 33 unique base XML hashes.
- 32 `EMULATOR_PERSISTENCE_PASS`, 1 `EMULATOR_PASS_ACTION`, 51 `EMULATOR_PASS_ROUTE` after four additional mutation/readback batches. Only rows whose action XML differed from base were promoted; unchanged taps remained route-only.
- This is not a claim that all 84 editor mutations were saved/read back.
- Matrix: `artifacts/runtime_evidence/settings84_runtime/matrix.csv`.

## Exact177

- 177/177 reference routes rendered; 25 routes and 22 unique base hashes.
- 48 `EMULATOR_PASS_STATE_ACTION`, 3 `EMULATOR_PASS_ROUTE_UNIQUE`, 126 `PARTIAL_STATE_NOT_REPRODUCED`, 0 route-render failures after action batches 3–7.
- Remaining PARTIAL reasons are recorded per row in `artifacts/runtime_evidence/exact177_runtime/partial_reason_classification.csv`: 115 reference-data/scroll states, 10 auth/two-account data states and 1 store-entitlement state.
- Repeated hashes are deliberately PARTIAL because the distinct required visual states were not reproduced by route opening alone.
- Matrix: `artifacts/runtime_evidence/exact177_runtime/matrix.csv`.

## Runtime defects

No crash or blank-route defect was exposed during traversal. The principal gap is state reproduction/action-readback coverage, not route availability. No static test or inventory row was substituted for emulator evidence.

No video under G was touched or generated. Emulator remains open.
