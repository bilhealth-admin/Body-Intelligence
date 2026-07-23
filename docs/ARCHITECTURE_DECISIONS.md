# BIL Architecture Decisions — BIL-AI-001

## ADR-AI-001-01 — Deterministic engines remain authoritative

AI contracts cite evidence produced by BIL-owned deterministic engines. No AI provider output becomes a source of health truth.

## ADR-AI-001-02 — Explainability is structural

Rationale, evidence, confidence, alternatives, and missing evidence are first-class fields rather than optional presentation text.

## ADR-AI-001-03 — Safe abstention is mandatory

When evidence is insufficient, the contract carries no action and must identify the missing evidence. Invented recommendations are invalid.

## ADR-AI-001-04 — Provider neutrality and offline-first foundation

The first AI package is pure Dart and contains no network, provider SDK, cloud, storage, or Commerce dependency.

## ADR-AI-001-05 — One action per decision envelope

An action decision contains exactly one typed value. Alternatives are explanatory records and cannot become simultaneous recommendations.
