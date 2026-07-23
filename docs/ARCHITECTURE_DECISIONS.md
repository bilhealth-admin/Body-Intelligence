# BIL Architecture Decisions

## ADR — Truth Engine starts as deterministic arithmetic

The initial Truth Engine evaluates BIL-owned signals using explicit strength and reliability values. Inputs are sorted by stable keys, duplicate keys are rejected, and outputs expose normalized score, confidence, rationale, evidence, and missing evidence.

This boundary is deliberately provider-neutral, offline-first, clock-free, random-free, and mutation-free. Later packages may compose domain-specific signals, but must not replace deterministic BIL truth with opaque model output.


## ADR — Validated immutable constructor inputs
Immutable AI domain models that normalize constructor text must accept a plain parameter and assign the normalized value exactly once in the initializer list. Initializing formals must not be combined with a second initializer for the same field.


## ADR — Typed rules compose signals; Truth Engine owns truth arithmetic

Domain-specific deterministic rules may decide whether an evidence-backed signal applies to a typed context. They must not calculate final truth status or confidence. All final arithmetic remains centralized in `TruthEngine`, preserving one source of truth, stable ordering, explainability, offline operation, and provider neutrality.

## ADR — Validating factories for immutable AI domain contracts

When an immutable AI domain object requires input normalization before field initialization, use a public validating factory delegating to a private initializing constructor. This preserves the public API, keeps validation centralized, and satisfies analyzer constructor-formal rules without ignores.
## ADR — Truth resolution may feed explainability but not One Best Action policy

A deterministic bridge may translate a resolved `TruthAssessment` into the provider-neutral `ExplainableAiDecision` contract only when the caller supplies the candidate values. Supported and contradicted assessments may select their corresponding candidate; uncertain and insufficient assessments must abstain. The bridge may not invent actions, call providers, access time or randomness, mutate state, or absorb One Best Action policy.

Numeric Truth Engine confidence is mapped to the existing coarse AI confidence levels using explicit local thresholds: high at 0.75 or above, medium at 0.50 or above, otherwise low. This is a presentation boundary, not medical certainty or statistical calibration.

## ADR — Truth composition must expose immutable provenance

Deterministic truth composition may expose which typed rules were considered and which matched, but must not duplicate Truth Engine arithmetic. `TruthEvaluationTrace` therefore wraps the existing `TruthAssessment` and stable rule identities; `TruthRuleComposer.assess` remains backward compatible.

## ADR — Robust host-timed performance gates
Host-timed microbenchmarks must retain product budgets while resisting isolated scheduler noise. For repeated deterministic operations, BIL gates use an odd-sized sample median, print every observation, and retain a separate catastrophic-outlier ceiling. This decision does not authorize raising product budgets or hiding measurements.


## ADR — Truth conflict analysis is separate from truth resolution

Conflict analysis consumes existing `TruthSignal` values and explains disagreement, but it does not replace `TruthEngine`, change thresholds, or select user actions. This separation preserves deterministic assessment semantics while making opposing evidence auditable.

## AI-006-R1 — Test follows engine contract
Regression fixtures must encode the existing Truth Engine arithmetic and thresholds; verification failures must not be resolved by changing production semantics when the fixture is incorrect.


## ADR — Truth evaluation report is the composition explainability boundary

`TruthEvaluationReport` is the provider-neutral bundle for one proposition evaluation. It joins existing outputs rather than duplicating policy. `TruthRuleComposer.report` is the canonical full-output path; legacy `assess` and `trace` remain compatibility projections. The report performs no action ranking, storage, networking, clock access, randomness, or mutation.

## BIL-AI-007-R1
Corrected AI-007 test fixtures to provide the required local evidence `source`; production contracts and behavior are unchanged.


## ADR — Truth reports are validated without changing evaluation policy

`TruthEvaluationValidator` observes an existing `TruthEvaluationReport` and emits ordered integrity issues. It does not recompute Truth Engine thresholds, rewrite assessments, rank actions, access external providers, or persist data. This keeps validation explainable and prevents a second truth policy from emerging.
