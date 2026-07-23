# BIL Architecture Decisions

## ADR — Truth Engine starts as deterministic arithmetic

The initial Truth Engine evaluates BIL-owned signals using explicit strength and reliability values. Inputs are sorted by stable keys, duplicate keys are rejected, and outputs expose normalized score, confidence, rationale, evidence, and missing evidence.

This boundary is deliberately provider-neutral, offline-first, clock-free, random-free, and mutation-free. Later packages may compose domain-specific signals, but must not replace deterministic BIL truth with opaque model output.


## ADR — Validated immutable constructor inputs
Immutable AI domain models that normalize constructor text must accept a plain parameter and assign the normalized value exactly once in the initializer list. Initializing formals must not be combined with a second initializer for the same field.
