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
