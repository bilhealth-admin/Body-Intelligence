# BIL Known Limitations

## AI Platform after BIL-AI-002

- Truth signals are contracts; no production domain engine emits them yet.
- Thresholds are deterministic defaults and are not a medical calibration policy.
- Confidence represents evidence reliability coverage, not medical certainty or statistical probability.
- No Body Twin, Decision Memory, One Best Action, provider, prompt, cloud, UI, or persistence integration exists.
- The engine does not diagnose, prescribe, or mutate health state.


## BIL-AI-002-R1
No new functional limitation. This package is a compilation repair only. Truth assessments remain deterministic, offline, provider-neutral, and non-medical.


## BIL-AI-003 limitations

- Rules are in-memory pure contracts; no persistence or registry is introduced.
- Proposition contexts remain feature-owned and are not connected to Body Twin or Daily Log.
- Rule calibration values are explicit inputs and are not learned or remotely configured.

### BIL-AI-003-R1

No new functional limitation. This package is a constructor-structure correction only; it adds no provider, cloud, UI, medical inference, or persistence behavior.
## BIL-AI-004 limitations

- The bridge does not generate candidates; domain packages must provide them explicitly.
- No One Best Action ranking, Body Twin integration, Decision Memory, AI Coach, prompts, providers, cloud transport, or UI is included.
- Confidence mapping is a deterministic coarse presentation policy and is not medical or probabilistic calibration.
- Uncertain and insufficient assessments always abstain.

## BIL-AI-005 limitations

The trace records rule identity and match provenance only. It does not persist history, rank actions, infer user intent, calibrate medical certainty, call providers, or expose UI. Those capabilities require later explicitly authorized packages.

## Host timing variability
Wall-clock tests can still reflect sustained machine contention. `BIL-QUALITY-002-R1` removes isolated single-sample noise but intentionally fails when the median reaches 500 ms or any sample reaches 1500 ms. It does not replace device profiling or release-mode benchmarking.


## BIL-AI-006 limitations

- Conflict analysis explains signal disagreement but does not decide clinical truth, recommend an action, or replace Truth Engine thresholds.
- No persistence, provider, prompt, cloud, UI, Body Twin, Decision Memory, or One Best Action integration is included.

## Resolved by BIL-AI-006-R1
The original AI-006 regression fixture incorrectly expected `supported` for score `0.300`. R1 aligns the test with the established threshold without altering production.


## BIL-AI-007 limitations

- The report explains one deterministic proposition evaluation only.
- It does not rank actions or create recommendations.
- It has no persistence, provider, prompt, network, cloud, clock, randomness, UI, or medical inference integration.

## BIL-AI-007-R1
Corrected AI-007 test fixtures to provide the required local evidence `source`; production contracts and behavior are unchanged.


## BIL-AI-008 limitations

- Validation checks internal report consistency only; it does not certify scientific correctness of rule definitions.
- Balanced conflict tolerance remains owned by `TruthConflictAnalyzer`; AI-008 validates structural consistency rather than introducing a duplicate tolerance policy.
- No persistence, telemetry, provider integration, recommendation ranking, UI, or medical inference is included.


## BIL-AI-009 limitations

- The gate validates internal report consistency only; it does not establish medical truth.
- It does not repair rejected reports or choose fallback recommendations.
- It is local, in-memory, provider-neutral, clock-free, random-free, and persistence-free.


## BIL-AI-009-R1

Corrected the AI-009 regression fixture to use the repository-owned `TruthSignalDirection.supports` enum member. Production contracts and behavior are unchanged.


## BIL-AI-010 limitations

- The gate establishes structural integrity, not medical truth.
- Candidate actions remain caller-owned; no One Best Action ranking is introduced.
- The pipeline is local, in-memory, deterministic, provider-neutral, clock-free, random-free, and persistence-free.

## AI-010 R1
No new production limitation. The original AI-010 focused tests contained stale constructor arguments and could not compile; R1 corrects those fixtures without changing runtime behavior.

## BIL-AI-011 limitations

- Validation is structural and deterministic; it is not clinical validation.
- Candidate identity and ranking are intentionally outside scope.
- No persistence, audit store, provider integration, prompt execution, UI, or user-state mutation is included.
- Evidence values are compared with their existing Dart equality semantics.


### BIL-AI-011-R1
No new product limitation. This revision only repairs a compile-time test-fixture mismatch.

## BIL-AI-012 limitations

The validation gate does not rank actions, determine One Best Action, persist decisions, invoke providers, access cloud services, or present UI. It only exposes whether the existing truth-decision result passed fidelity validation. Calibration and medical inference remain explicitly out of scope.

## BIL-AI-013 limitations

The pipeline accepts caller-owned supported and contradicted candidates but does not rank alternatives or implement One Best Action policy. It has no persistence, clock, randomness, provider, prompt, network, UI, or user-state mutation.


## AI-014 limitations

- Validates pipeline-envelope provenance and exposure invariants only.
- Does not rank candidates, model a user, persist decisions, call providers, or introduce recommendation policy.
- Uses object identity for report provenance because AI-013 intentionally preserves one immutable report instance through all gates.

## BIL-AI-015 limitations

- The trusted orchestrator composes existing local contracts only; it does not rank actions or introduce product policy.
- No production feature currently supplies real user-domain Truth rules to this boundary.
- Body Twin, Decision Memory, One Best Action, AI Coach, providers, prompts, cloud, persistence, and UI remain outside scope.

## BIL-AI-016 limitations

The stable Truth/Explain facade classifies only outcomes already validated by AI-001 through AI-015. It does not create or persist a Body Twin, remember decisions, rank alternatives, select One Best Action, coach the user, invoke prompts/providers, access cloud services, or present UI. Candidate actions remain caller-owned.

## BIL-AI-017 limitations

- The snapshot contains only caller-supplied observations and does not estimate missing metrics.
- It selects the latest observation per metric but does not compute trends, deltas, tissue state, water-noise isolation, metabolic forecasts, or recommendations.
- Metric keys and units are feature-owned strings in this first foundation; cross-metric unit normalization is not included.
- No repository adapter, persistence, UI, provider, prompt, network, telemetry, diagnosis, or medical interpretation is included.
- Equal-time observations with different payloads are rejected rather than resolved automatically.

## BIL-AI-018 limitations

The validator checks structural and provenance consistency only. It does not judge physiological plausibility, freshness policy, unit conversion, trends, predictions, medical meaning, persistence, UI, or provider output.


## BIL-AI-019 limitations

The gate establishes structural and provenance acceptance only. It does not certify physiological plausibility or scientific correctness, normalize units, assess freshness, calculate trends, isolate tissue or water noise, forecast metabolism, persist state, call providers, rank actions, or present UI.

## BIL-AI-020 limitations

The public Body Twin snapshot facade assembles and integrity-gates caller-supplied observations only. It does not determine physiological plausibility, data freshness, trends, tissue or water effects, forecasts, health insights, recommendations, medical meaning, persistence, provider use, prompts, cloud transport, or UI behavior.


## BIL-AI-021 limitation

The freshness gate evaluates only caller-supplied maximum ages against the accepted snapshot's explicit timestamps. It does not define medically correct freshness windows, infer physiological plausibility, normalize units, calculate trends, isolate tissue or water noise, forecast metabolism, persist state, call providers, rank actions, or present UI. Metrics without explicit policy are blocked as unconfigured.

## BIL-AI-022 limitations

- Consistency rules are caller supplied and are not universal physiological or diagnostic ranges.
- Units are compared exactly; no conversion or normalization is performed.
- The engine evaluates one snapshot only and does not infer trends, tissue state, water noise, or forecasts.

## BIL-AI-023 limitations
The trusted snapshot pipeline performs no unit conversion, trend inference, tissue/water isolation, forecasting, persistence, provider access, recommendation, or medical inference. Policies remain caller-owned.

## BIL-AI-024 limitations
The public facade does not infer trends, normalize units, repair observations, persist state, access providers, recommend actions, or perform medical interpretation. Caller-owned freshness and consistency policy remains mandatory.

- BIL-AI-027 Decision Memory is in-memory only; durable persistence, outcome transitions, retention policy, and cross-session retrieval are not yet implemented.

## BIL-AI-028-R1 limitations

Outcome reconciliation is in-memory and persistence-neutral. It does not ingest real user outcomes, infer causality, grade clinical benefit, reopen terminal outcomes, synchronize across devices, or drive One Best Action. The initial state is parsed from the existing record string and unsupported values are rejected explicitly.

## BIL-AI-029-R2 limitations

The public facade is local and in-memory. It does not provide durable persistence, serialization, migrations, retention policy, cross-device synchronization, outcome ingestion, causal inference, recommendation selection, forecasting, provider access, prompts, cloud transport, UI, or medical interpretation.

## BIL-AI-030-R1 limitations

- The archive contract does not persist data by itself.
- No database, filesystem, encryption, retention, migration beyond schema version 1, sync, or cloud adapter is selected.
- Import is intentionally fail-fast and atomic only with respect to the newly constructed in-memory facade.


## BIL-AI-031 limitations

Decision Memory is complete as a deterministic local domain engine, but this package intentionally does not choose a database, filesystem, encryption mechanism, synchronization protocol, cloud adapter, UI, or causal outcome inference. Retention compaction never deletes audit evidence; external lifecycle deletion requires a separate user-data governance boundary.

## BIL-AI-032 Body Twin closure boundary

Body Twin is closed only at the deterministic local evidence engine boundary. It assembles and validates caller-provided observations, applies caller-owned freshness and consistency policy, preserves trend-ready factual history, and verifies snapshot/history reconciliation. It does not isolate tissue or water noise, interpolate missing values, forecast metabolism, infer medical meaning, rank actions, persist data, invoke providers/prompts, use cloud transport, or present UI.

## AI Context Engine boundary after BIL-AI-033

AI Context is local, deterministic, immutable, and provider-neutral. It does not persist data, call an LLM, generate prompts, forecast physiology, isolate tissue/water noise, recommend actions, diagnose conditions, or mutate product state. Context completeness depends on accepted upstream engine outputs and caller-declared required keys.

## BIL-AI-034-R2 limitations

The engine isolates a residual water/noise component only from accepted factual weight observations and a caller-supported tissue-change estimate. It does not diagnose fluid disorders, infer sodium/glycogen physiology, create a tissue estimate, interpolate missing values, forecast metabolism, persist results, call providers, or recommend actions.

## Adaptive Metabolic Forecasting boundary

The engine does not estimate energy expenditure, infer adherence, diagnose metabolic adaptation, select clinical targets, or model nonlinear physiology. Energy balance, conversion factors, horizons, and confidence thresholds remain caller-owned and evidence-backed.

## One Best Action boundaries

The engine does not generate candidate actions, diagnose conditions, replace AI Safety Layer, call providers, persist decisions, or mutate user state. Safety eligibility and thresholds are caller-owned until the dedicated AI Safety Layer is closed.

## AI Safety Layer

The engine does not author medical policy, diagnose conditions, contact emergency services, replace professional judgment, generate action candidates, persist results, or call remote providers. Rules and their clinical governance remain caller-owned.

## BIL-AI-038 — Automated Health Insight Summaries
Deterministic bounded health summaries with provenance, uncertainty preservation, explicit safety gating, abstention, immutable evidence, and no diagnostic claims. Product Owner verification remains required.

## AI Coach limitations after BIL-AI-039
The engine produces deterministic bounded coaching copy from trusted local outputs only. Personal conversational adaptation, prompt execution, provider integration, long-form dialogue, notifications, and UI delivery remain outside this package.

## BIL-AI-040 — Prompt Engine closure

Prompt Engine is delivered as a provider-neutral deterministic boundary that projects only approved AI Coach output into bounded context, preserves evidence, uncertainty, and safety requirements, refuses non-approved coaching output, performs no provider call, and does not treat an LLM as a source of truth. Final acceptance remains subject to Product Owner verification on parent HEAD 5ae4c8840e183bcf72461d7b1cdcbfce9961a81c.


## BIL-AI-041
AI Cost Optimizer closed with deterministic local-first routing, explicit budgets, provider-neutral remote eligibility, and abstention on invalid or over-budget requests. No billing provider integration is included. Next: BIL-AI-042 Proprietary BIL Intelligence.
