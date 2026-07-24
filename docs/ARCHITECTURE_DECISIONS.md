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


## ADR — Integrity validation must become an explicit consumption gate

Truth report validation remains a pure diagnostic operation. AI-009 adds a separate gate result whose status is derived only from the validator output. The original report and all integrity issues are preserved; the gate does not repair, reinterpret, rank, or mutate truth output. This keeps validation explainable and prevents silent consumption of inconsistent reports.


## BIL-AI-009-R1

Corrected the AI-009 regression fixture to use the repository-owned `TruthSignalDirection.supports` enum member. Production contracts and behavior are unchanged.


## ADR — Truth decisions must consume only integrity-accepted reports

AI-010 composes the existing truth evaluation gate and decision explainer without changing either contract. Invalid reports are preserved for diagnostics and never forwarded to decision selection. Accepted reports retain the established deterministic action-or-abstain semantics.

## ADR — Test fixtures must instantiate current domain contracts
AI Platform verification fixtures must use the exact repository-owned constructor contracts. A fixture mismatch is corrected in tests; production models are never weakened to accommodate stale tests.

## ADR — Validate decision fidelity after the integrity gate

The Truth pipeline now has two independent safety boundaries: report integrity before decision production, and decision fidelity after production. The second validator is observational only: it never repairs, replaces, ranks, persists, or forwards a decision. This preserves deterministic explainability and allows later consumers to reject inconsistent output explicitly.


### AI-011-R1 — Preserve integrity issue subject identity
Tests constructing `TruthIntegrityIssue` must provide the same explicit `subjectKey` required by production. The production contract is not weakened for fixture convenience.

## ADR — Decision fidelity validation must become an explicit exposure gate

AI-011 remains the single observational fidelity validator. AI-012 adds a separate immutable gate whose integrity status derives only from that validator. Downstream code may expose a decision only when fidelity is accepted and the upstream decision gate produced an explainable output. A valid upstream rejection remains a safe rejection. The gate never repairs, replaces, ranks, persists, or forwards inconsistent decisions.

## ADR — Compose established Truth/Explain gates without duplicating policy

AI-013 introduces a thin orchestration service rather than merging existing engines. The composer remains the only rule evaluation path; evaluation integrity, decision production, and decision fidelity remain delegated to their existing gates. This prevents policy duplication and keeps every stage independently testable.


## ADR — AI-014 trusted pipeline envelope is integrity-gated

The AI-013 pipeline result is not treated as an implicitly trusted transport object. AI-014 validates that the top-level report is the exact report instance used by the established decision gates and exposes an explicit accept/reject consumption boundary. The validator is observational only and never repairs or replaces output.

## ADR — AI-015 final trusted orchestration remains policy-free

AI-015 composes the existing AI-013 pipeline and AI-014 integrity gate rather than duplicating any evaluator, validator, or decision policy. The final result exposes a value only when the complete established chain permits it; safe abstention remains explicit and inspectable.

## ADR — Close Truth/Explain behind one stable public foundation boundary

Downstream AI components must depend on `TruthExplainFoundation` rather than reconstructing the internal AI-001 through AI-015 pipeline. The facade remains a thin delegate and may classify only the already validated trusted outcome as action, abstention, or rejection. It may not rank candidates, infer new facts, mutate state, use providers, persist data, or bypass any integrity gate.

## ADR — Body Twin starts as an immutable evidence snapshot, not an inferred model

BIL-AI-017 represents the Body Twin as caller-supplied local observations assembled into a deterministic latest-known snapshot at an explicit `asOf` time. Feature engines retain ownership of measurement production and scientific interpretation. The AI Platform must not fill missing values, average conflicting measurements, consult a provider, or silently resolve equal-time conflicts. This keeps the first Body Twin boundary testable, offline-only, explainable, and safe for later composition with Truth Engine.

## ADR — BIL-AI-018 Body Twin provenance is derived and validated locally

Body Twin provenance is projected directly from accepted immutable observations and validated against the snapshot before downstream consumption. Mismatches are surfaced as stable typed issues; the validator never repairs data or consults a provider.


## ADR — Body Twin snapshot validation becomes an explicit consumption gate

AI-019 keeps AI-018 as the single structural and provenance validator. The new gate derives acceptance exclusively from that validator, preserves the original snapshot and validation evidence for diagnostics, and exposes accepted snapshot/provenance values only when integrity succeeds. It never repairs data, estimates missing metrics, changes freshness policy, invokes providers, or introduces recommendation behavior.

## ADR — Body Twin snapshot consumers use one stable gated facade

BIL-AI-020 exposes deterministic snapshot construction and the existing integrity gate through one public local facade. The facade does not duplicate validation or create scientific policy. It returns the complete gate envelope for explainability and exposes a snapshot only after acceptance, keeping later AI capabilities dependent on one testable offline boundary.


## ADR — Body Twin freshness is explicit caller-owned policy

BIL-AI-021 does not embed universal freshness assumptions inside the AI Platform. Callers supply normalized per-metric maximum ages, while the local gate compares each accepted observation with the snapshot's explicit `asOf` time. Missing policy is surfaced as `unconfigured`, stale evidence remains inspectable, and neither condition may silently pass downstream.

## ADR — Body Twin consistency remains caller-owned deterministic policy

BIL-AI-022 layers a pure local consistency gate over the already integrity- and freshness-accepted Body Twin snapshot. Metric units and optional minimum/maximum bounds are supplied by the caller; the AI Platform does not invent physiological ranges, convert units, repair values, diagnose conditions, or infer trends. Missing policy, unit mismatch, and out-of-bound values remain explicit and block downstream consumption.

## ADR — Compose Body Twin trust gates without duplicating policy
BIL-AI-023 introduces a pure composition root that delegates to the existing foundation, freshness, and consistency engines. The pipeline preserves their evidence objects and does not recreate or weaken policy.

## ADR — Public Body Twin consumption boundary
The AI Platform exposes the composed Body Twin trust chain through a thin facade. Consumers receive an explicit accepted, incomplete, or rejected outcome; only accepted outcomes expose a snapshot. All upstream evidence remains available for explainability.

## ADR — Decision Memory starts as a local immutable contract
Decision records preserve evidence identifiers, selected action, rationale, confidence, timestamp, and outcome state. The first repository is deterministic and in-memory; persistence remains a later adapter concern.

## ADR — Decision outcomes are append-only transitions

BIL-AI-028-R1 preserves every `DecisionMemoryRecord` as immutable history. Outcome reconciliation is represented by separate immutable transitions with explicit from/to states, local evidence, and caller-supplied timestamps. Only `pending` may transition, and only to a terminal state (`succeeded`, `failed`, or `abandoned`). Terminal outcomes cannot be rewritten. The reconciler is local-only, provider-independent, persistence-neutral, and does not evaluate medical truth or select actions.

## ADR — Decision Memory consumers use one stable local facade

BIL-AI-029-R2 composes the existing immutable record store and append-only outcome reconciler behind a stable public boundary. The facade projects each record with its validated transition history and current state, but does not duplicate transition policy or introduce persistence, ranking, forecasting, provider, prompt, cloud, or medical behavior.

## ADR — Decision Memory persistence-neutral archive boundary

Decision Memory exports a schema-versioned primitive map and reconstructs through the existing `DecisionMemory` facade. Import deliberately reuses established record duplicate rejection and outcome-transition policy instead of bypassing domain rules. No storage adapter is selected in AI Platform.


## ADR — Decision Memory retention is lossless movement, never deletion

Decision Memory compaction separates active records from immutable audit records while preserving every record and transition exactly once. Retention policy is caller-owned and deterministic. The domain exposes no silent deletion operation; database, filesystem, encryption, synchronization, and cloud adapters remain outside the engine boundary.

## ADR — Body Twin closes through snapshot/history reconciliation

BIL-AI-032 closes the local Body Twin Engine by composing, not replacing, the accepted snapshot trust pipeline and trend-ready factual history. The closure validator requires the latest observation for every accepted snapshot metric to match the trend state exactly and rejects unexpected or missing trend projections. This boundary remains deterministic and offline-only and deliberately excludes interpolation, forecasting, tissue/water interpretation, recommendation, persistence, providers, and medical inference.

## ADR — AI Context remains a local deterministic projection

AI Context may consume only accepted local engine outputs. Missing inputs are evidence, not values to infer. Decision history is caller-bounded and future records are excluded. LLMs, prompts, providers, persistence, cloud services, recommendations, forecasts, diagnosis, and UI mutation remain outside this engine boundary.

## ADR — Caller-supported tissue estimate and residual water/noise isolation

BIL-AI-034-R2 does not invent physiological tissue change. It accepts a caller-supported tissue-change estimate with evidence identifiers, computes the residual against observed accepted weight change, and classifies dominance using caller-owned policy. Missing or stale evidence produces insufficiency rather than false precision.

## ADR — Forecasting remains evidence-bound and caller-policy-owned

Adaptive forecasts may project only an explicitly supplied supported energy balance through caller-owned conversion and horizon policies. Missing evidence, low confidence, or rejected upstream context must abstain or reject rather than infer metabolism.

## ADR — One Best Action remains a deterministic selector

One Best Action does not invent actions or safety policy. It ranks caller-supplied candidates only after accepted AI Context and forecasting boundaries, excludes candidates not marked safety-eligible, preserves evidence, and abstains when no candidate crosses caller-owned thresholds.

## ADR — AI Safety policy remains caller-owned

AI Safety evaluates explicit caller-supplied rules over accepted One Best Action output. The platform does not invent clinical thresholds, emergency advice, diagnosis, or user-specific policy. Blocking rules reject; advisory rules remain explainable and may trigger caller-configured abstention.

## BIL-AI-038 — Automated Health Insight Summaries
Deterministic bounded health summaries with provenance, uncertainty preservation, explicit safety gating, abstention, immutable evidence, and no diagnostic claims. Product Owner verification remains required.

## ADR — AI Coach remains a deterministic composition boundary
AI Coach may only compose trusted local outputs already approved by the AI Safety Layer. It does not generate candidate actions, invent evidence, diagnose, call an LLM/provider, or mutate user state. Prompt-driven language generation remains the responsibility of the later Prompt Engine.

## BIL-AI-040 — Prompt Engine closure

Prompt Engine is delivered as a provider-neutral deterministic boundary that projects only approved AI Coach output into bounded context, preserves evidence, uncertainty, and safety requirements, refuses non-approved coaching output, performs no provider call, and does not treat an LLM as a source of truth. Final acceptance remains subject to Product Owner verification on parent HEAD 5ae4c8840e183bcf72461d7b1cdcbfce9961a81c.
