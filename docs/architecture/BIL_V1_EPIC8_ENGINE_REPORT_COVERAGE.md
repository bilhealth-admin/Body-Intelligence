# BIL v1 — Epic 8 engine and report closure

Status is accepted only through the final Epic 8 gate. This matrix is the
targeted evidence index; it does not replace executable tests.

| Capability | End-to-end implementation evidence | Behavioral evidence |
|---|---|---|
| Truth Engine | `productIntelligenceOutputProvider` → `BilLocalIntelligenceRealityRuntime` → `TruthExplainFoundation`/Truth pipeline → local timeline adapter → Drift | `truth_engine_test.dart`, trusted truth pipeline and dashboard truth-loop widget tests |
| Body Twin | Product provider → runtime → consistency/freshness gates → local weight/profile observations → Dashboard adapters/surfaces | Body Twin engine, consistency, freshness, trusted snapshot, and dashboard trust tests |
| One Best Action | Runtime candidates → One Best Action → Safety Engine → integrated brain → Dashboard decision explanation | One Best Action, safety, integration, decision explanation and regression tests |
| Explainable intelligence | Integrated result carries explanation, evidence IDs, provenance and uncertainty; visible Dashboard explanation route | Truth explainer/foundation tests and `epic_e3_truth_decision_loop_widget_test.dart` |
| Confidence/trust/evidence | Coverage-derived confidence, evidence IDs, source timestamps and fail-closed validation | AI evidence/integrity suites plus Epic 8 measured-report and export tests |
| Nutrition engine | Saved meal items and nutrient evidence masks → nutrition/target engines → Daily Log, Dashboard and Analytics | `nutrition_engine_test.dart`, repository and nutrient pipeline tests |
| Metabolism/energy | Profile + measured timeline → BMR/TDEE/adaptive forecast; missing intake/weight abstains | adaptive metabolic forecast, physiological reality, and missing-weight guard tests |
| Goals/trends/recommendations | Persisted profile/plan/weights → plan, progress, trend and recommendation engines → Dashboard/Progress/Analytics | analytics range, weight chart, dashboard composition, plan and engine tests |
| Health and safety rules | `AiSafetyEngine` blocks unsafe, unevidenced and aggressive actions before presentation | safety engine and integration regression suites |
| Privacy first | Runtime reads local Drift only; no LLM/network path; reports require explicit user navigation/export | privacy/recovery and local-intelligence system tests |
| Offline first | Canonical local adapter/repositories remain authoritative; no connectivity required | offline cloud platform and local runtime system tests |
| Persistence/sync | Repositories soft-delete, revision and mark pending sync; conflict resolver and local recovery preserve records | repository, lifecycle, recovery, conflict and Decision Memory store tests |
| Weekly illustrated report | `/weekly-report` → Riverpod repository streams → `WeeklyReportEngine` → seven explicit day slots, measured totals, confidence, sources and limitations | `epic8_engines_reports_behavior_test.dart` covers aggregation, missing days, invalid data, empty/error-safe UI, RTL/LTR, Light/Dark and phone size |
| Charts/time ranges | `/analytics` uses persisted series, explicit selected ranges, measured-point confidence and no causal/tissue claim | analytics range selector, recovery, reuse and weight-chart tests |
| Report formats | Scientific report → validated provenance/confidence → deterministic PDF/XLSX/CSV/JSON | reports runtime, world-class reports system and Epic 8 export validation tests |

## Closure invariants

- No absent day, measurement, meal or nutrient is synthesized.
- Missing evidence produces an empty/insufficient state, never a confident claim.
- Sources and confidence travel with exported facts and estimates.
- Health output is informational, non-diagnostic, and safety-gated.
- Local persistence is usable offline; sync is a transport concern and cannot
  alter deterministic calculations.
- User-visible routes exist for Dashboard, Daily Log, Progress/Analytics,
  Intelligence Center, decision explanation and Weekly Report.
