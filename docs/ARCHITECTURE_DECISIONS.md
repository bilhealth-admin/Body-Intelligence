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
