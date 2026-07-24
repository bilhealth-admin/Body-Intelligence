# BIL Architecture Decisions

## Authoritative execution baseline

- Branch: `phase-3-product-excellence`
- Baseline HEAD: `8f67e0effa480e9af0769ec546973ef0644a32f8`

## Current authoritative decisions

### ADR — Local authority and offline-first operation

The local database is the product source of truth. Product features must remain useful without network availability. Remote systems synchronize with local state and do not silently replace local authority.

### ADR — Privacy-first and provider-neutral boundaries

Core domain, intelligence, and Cloud Platform logic remains provider-neutral. Credentials, vendor SDK details, hosted endpoints, and deployment configuration stay behind explicit adapters and environment boundaries.

### ADR — Canonical local intelligence runtime

`BilLocalIntelligenceRealityRuntime`, obtained through the single product composition root, is the canonical Database-to-Product intelligence path. Compatibility facades may delegate only and must not contain parallel confidence, action, safety, or integration logic.

### ADR — Deterministic, explainable intelligence

BIL engines remain the source of decision truth. Every product decision must preserve evidence, confidence, uncertainty, safety outcome, scientific validation, and a deterministic trace. Language models may assist presentation only when separately authorized; they do not replace BIL decision engines.

### ADR — Safe abstention

Missing or insufficient evidence produces explicit abstention rather than invented data, unsupported forecasts, unsafe actions, or runtime exceptions.

### ADR — Durable Cloud Platform Core

Cloud state is persisted locally with durable outbox, inbox, cursors, tombstones, conflicts, idempotency receipts, dead letters, identity/device state, backups, and redacted audit evidence. Retry, restart recovery, reconciliation, backup/restore, export, deletion, consent withdrawal, and schema negotiation are explicit production capabilities.

### ADR — Closed-stage non-regression

Foundation, Nutrition Platform, AI Platform, BIL Intelligence Integration, BIL Intelligence Reality Closure, and Cloud Platform Core are closed. Any change to these boundaries requires a proven defect or approved requirement and focused regression protection.

## Historical ADR policy

Superseded package-status notes and historical parent HEAD references are retained in Git history and package archives. They are not active architecture decisions.
