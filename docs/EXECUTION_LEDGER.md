# BIL Execution Ledger

## BIL-AI-002 — Deterministic Truth Assessment Foundation

- Parent HEAD: `25dab7585a9c7db1fa62601cb40f7615ece9b142`
- Team: AI Platform Team
- Scope: deterministic truth signal, assessment, and evaluator contracts.
- Production mutation outside AI Platform: none.
- Provider/network/prompt integration: none.
- Verification: focused Truth Engine tests, AI regression tests, Commerce regression, analyzer, complete project tests, and diff integrity.
- Status: delivered; awaiting Product Owner verification and commit.


## BIL-AI-002-R1
- Parent HEAD: `25dab7585a9c7db1fa62601cb40f7615ece9b142`
- Trigger: focused Truth Engine compilation failure.
- Fix: replace duplicate `this.rationale` initialization with a validated `String rationale` parameter.
- Verification: focused AI tests, AI regression, Commerce regression, analyze, full tests, and diff integrity.


## BIL-AI-003

- Package: Typed Truth Proposition & Rule Composition Foundation.
- Parent: `25dab7585a9c7db1fa62601cb40f7615ece9b142`.
- Scope: AI Platform domain/service contracts and focused/regression tests only.
- Gate: focused composition tests, complete AI Platform tests, Commerce regression, analyze, full tests, and diff check.

## BIL-AI-003-R1 — Analyzer-conformant TruthRule construction

Corrective package over the applied BIL-AI-003 state. Replaced constructor field assignments with a public validating factory and a private positional initializing constructor. Public call sites and deterministic behavior remain unchanged; the three `prefer_initializing_formals` findings are eliminated without lint suppression.
## BIL-AI-004 — Deterministic Truth-to-Decision Explainability Bridge

- Parent HEAD: `3660eceea4e981a2c0e5303724cad61dd05525c4`.
- Team: AI Platform Team.
- Scope: typed truth decision candidates and deterministic TruthAssessment-to-ExplainableAiDecision bridge.
- Production mutation outside AI Platform: none.
- Verification: focused AI-004 tests, complete AI Platform tests, Commerce regression, analyzer, complete project tests, and diff integrity.

## BIL-AI-005 — Issued

- Parent HEAD: `d08db3ca4d375c10d249ac1fa49a4562476040b1`.
- Scope: deterministic Truth Engine provenance trace.
- Compatibility: existing `TruthRuleComposer.assess` delegates to trace generation and returns the same assessment contract.
- Gates: focused trace tests, full AI tests, Commerce regression, analyze, full project tests, and diff integrity.

## BIL-QUALITY-002-R1
- Trigger: BIL-AI-005 verification passed focused AI, complete AI, Commerce, and analyzer gates but the full suite intermittently failed the single-sample food-search budget.
- Classification: test-harness determinism / performance quality gate.
- Scope: `test/performance_budget_test.dart`, reusable test sampling helper, focused regression test, living documents.
- Production behavior: unchanged.
- Budget: unchanged at `<500 ms`; added `1500 ms` catastrophic single-sample ceiling.


## BIL-AI-006

- Parent HEAD: `12250f2f2ac6d7e18993bc32614aee45b25b4be6`
- Scope: deterministic Truth Signal conflict analysis and explanation.
- Production: immutable conflict result plus pure analyzer service.
- Gates: focused tests, complete AI tests, Commerce regression, analyzer, full project tests, diff integrity.
- Status: package issued; pending Product Owner verification and commit.

### BIL-AI-006-R1
- Parent HEAD: `12250f2f2ac6d7e18993bc32614aee45b25b4be6` with BIL-AI-006 applied and uncommitted.
- Corrected the conflict-analysis non-regression test expectation from `supported` to `uncertain`.
- Reason: Truth Engine computes `(0.8 - 0.2) / 2.0 = 0.3`, below the existing `0.35` support threshold.
- Production changes: none.


## BIL-AI-007 — issued

- Parent HEAD: `0afa164fce065c07ac3d85d89a6350a2271f1bcc`.
- Added an immutable explainability report combining trace, assessment, and conflict analysis.
- Refactored rule composition to evaluate rules once per requested output.
- Added focused and regression coverage for determinism and API preservation.

## BIL-AI-007-R1
Corrected AI-007 test fixtures to provide the required local evidence `source`; production contracts and behavior are unchanged.


## BIL-AI-008

- Parent HEAD: `396c3c1d091e60551e3e64ab16a945af4a6efcf6`
- Scope: deterministic truth report integrity validation.
- Production: immutable issue/result contracts and pure validator.
- Verification: focused tests, complete AI tests, Commerce regressions, analyze, full tests, and diff integrity.


## BIL-AI-009

- Parent HEAD: `0bd4cb3c38be919ae6d139bba6700a1dd8ed394a`
- Scope: immutable truth evaluation gate result and pure gate service.
- Production mutation outside AI Platform: none.
- Verification: focused gate tests, complete AI tests, Commerce regression, analyzer, full project tests, and diff integrity.
- Status: package issued; pending Product Owner verification and commit.


## BIL-AI-009-R1

Corrected the AI-009 regression fixture to use the repository-owned `TruthSignalDirection.supports` enum member. Production contracts and behavior are unchanged.


## BIL-AI-010

- Parent HEAD: `8deff82d1eb41fa5d9d9959a5d2a5ebf274a4283`
- Scope: immutable decision-gate result and pure integrity-gated decision service.
- Production mutation outside AI Platform: none.
- Status: package issued; pending Product Owner verification and commit.

## BIL-AI-010-R1
- Parent HEAD: `8deff82d1eb41fa5d9d9959a5d2a5ebf274a4283`
- Trigger: focused tests exposed stale constructor fixtures.
- Change: tests only; add required `rationale`, `missingEvidence`, proposition `description`, and rule `strength`.
- Production behavior: unchanged.
- Status: pending Product Owner verification.

## BIL-AI-011 — Issued

- Parent HEAD: `14346ea4ea98033f6eab07dade96234cc6e9d7cd`
- Scope: truth-decision integrity result and pure validator.
- Production changes are isolated to `lib/features/ai_platform/`.
- Focused tests cover valid action, valid abstention, rejected gates, and forged mismatches.
- Full AI, Commerce, analyzer, full-project, and diff gates remain mandatory.


## BIL-AI-011-R1
- Corrected the focused validator test fixture to provide the repository-required `TruthIntegrityIssue.subjectKey`.
- No production behavior or architecture changed.

## BIL-AI-012

- Parent HEAD: `686799297af64ddc77f78f1e0ec5d668a0983238`
- Scope: post-decision integrity consumption gate.
- Production: `TruthDecisionValidationGateResult`, `TruthDecisionValidationGate`.
- Verification: focused AI-012 tests, complete AI Platform tests, Commerce regression, analyzer, full project tests, diff integrity.
- Non-scope: Body Twin, Decision Memory, One Best Action ranking, AI Coach, prompts, providers, cloud, persistence, and UI.

## BIL-AI-013

- Parent: `bbd0f86512658f21b68ccae77d78d4c87dd5d1f0`
- Scope: trusted Truth decision pipeline orchestration.
- Production: immutable pipeline result plus pure local pipeline service.
- Gates: focused tests, complete AI tests, Commerce regression, analyze, full project tests, diff integrity.


## BIL-AI-014 — Issued

- Parent HEAD: `3419142b5be77f1e7a7ed24516461c13e8886817`
- Scope: trusted pipeline integrity validation and consumption gate.
- Production: AI Platform only.
- Non-Regression: complete AI Platform, Commerce, Nutrition, Daily Log, Dashboard, Offline First, Privacy First, full analyze and full project tests.

## BIL-AI-015 — Issued

- Parent HEAD: `022911ef3524eda159203be6c1294bb5ff7c009d`.
- Package: Trusted Truth Decision Orchestrator Foundation.
- Scope: AI Platform domain/service orchestration plus focused and regression tests.
- Production mutation outside AI Platform: none.
- Verification: package format, focused AI-015 tests, complete AI Platform tests, Commerce regression, analyzer, complete project tests, and diff integrity.

## BIL-AI-016 — Truth/Explain Foundation Public Boundary and Reconciliation

- Parent HEAD: `50f450ee4b01ee0bfef3d21cf4222becfe85493c`.
- Adds a stable public facade over the trusted AI-015 orchestration boundary.
- Adds immutable public outcome classification: action, abstention, rejected.
- Preserves the complete underlying trusted result for explainability and diagnostics.
- Non-scope: Body Twin state, Decision Memory, One Best Action ranking, AI Coach, prompts, providers, cloud, persistence, UI, and medical inference.
- Next after successful verification and commit: first repository-defined Body Twin foundation package.

## BIL-AI-017 — Body Twin Observation & Snapshot Foundation

- Parent HEAD: `83dff08434af4e99504976c1b7cd5a715223e995`.
- Team: AI Platform Team.
- Scope: immutable Body Twin observation/snapshot contracts and deterministic local latest-known-state assembly.
- Production mutation outside AI Platform: none.
- Provider/network/prompt/persistence integration: none.
- Safety: future observations are excluded; equal-time conflicting values are rejected; missing required metrics remain explicit.
- Verification: focused AI-017 tests, complete AI Platform tests, Commerce regression, analyzer, full project tests, and exact diff integrity.
- Status: delivered; awaiting Product Owner verification and commit.

## BIL-AI-018 — Body Twin Snapshot Integrity and Provenance Foundation

- Parent HEAD: `30008d1f5558375b02aad9f05a98272725d8ad34`
- Adds immutable metric provenance, explainable integrity issue/result types, and a pure snapshot validator.
- Non-scope: prediction, scientific inference, Decision Memory, One Best Action, AI Coach, prompts/providers, cloud, persistence, and UI.
- Next after successful verification and commit: next smallest repository-defined Body Twin package.
