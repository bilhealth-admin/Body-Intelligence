# BIL Project State

## Baseline for this package

- Branch: `phase-3-product-excellence`
- Parent HEAD: `25dab7585a9c7db1fa62601cb40f7615ece9b142`

## AI Platform

- `BIL-AI-001`: complete and Non-Regression.
- `BIL-AI-002`: implemented pending Product Owner verification and commit.

The AI layer now has immutable explainable-decision contracts plus a deterministic, offline-only Truth Engine assessment foundation. No cloud/provider integration or medical inference has been introduced.

## Protected systems

Nutrition, Explainable Nutrition, Daily Log, Dashboard, Commerce, Offline First, and Privacy First remain protected by full-project and targeted regression gates.


## BIL-AI-002-R1 State
BIL-AI-002 required a focused R1 because `TruthAssessment.rationale` was declared as an initializing formal and also normalized in the initializer list. R1 preserves normalization by accepting a constructor parameter and assigning the validated value once.


## BIL-AI-003 State

- Parent HEAD: `25dab7585a9c7db1fa62601cb40f7615ece9b142`.
- Adds typed proposition and deterministic rule-composition contracts.
- Reuses the existing Truth Engine as the only arithmetic truth evaluator.
- Introduces no provider, prompt, cloud, UI, persistence, medical diagnosis, or cross-feature mutation.

### BIL-AI-003 corrective status

`BIL-AI-003-R1` resolves the three analyzer findings in `TruthRule` while preserving the typed rule-composition contract and all existing tests. AI-003 remains the active package until R1 verification and commit succeed.
## BIL-AI-004 State

`BIL-AI-004` extends the explainability boundary without widening the AI platform into recommendation policy. `TruthDecisionExplainer` selects only between caller-supplied candidates when Truth Engine output is supported or contradicted, and safely abstains when the assessment is uncertain or evidence is insufficient. The bridge remains deterministic, offline-only, provider-neutral, clock-free, random-free, and mutation-free.

## BIL-AI-005 State

Parent HEAD: `d08db3ca4d375c10d249ac1fa49a4562476040b1`. AI-005 adds an immutable evaluation trace containing the proposition key, sorted considered rule keys, matched rule keys, unmatched rule derivation, and the existing `TruthAssessment`. The trace is deterministic, offline-only, provider-neutral, clock-free, random-free, and mutation-free.

## Global quality unblock for BIL-AI-005
`BIL-QUALITY-002-R1` stabilizes the performance gate that intermittently reported 358–615 ms for identical code and data. The 500 ms budget remains unchanged; the gate now evaluates a five-sample median and retains full per-sample evidence.
