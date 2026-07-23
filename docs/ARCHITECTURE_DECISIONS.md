# BIL Architecture Decisions — BIL-COM-010-R1

## ADR-COM-010-01 — Repository First governs reconciliation

The current repository graph, imports, tests, and runtime contracts are authoritative. Package manifests are delivery aids and never sufficient evidence for deleting or replacing a source file.

## ADR-COM-010-02 — No speculative production rewrite at Epic closure

The audit found no proven runtime defect requiring new Commerce production behavior. Epic closure is implemented through regression evidence, quality gates, and living-knowledge reconciliation.

## ADR-COM-010-03 — Paywall remains non-authoritative

Presentation may select offers and invoke explicit purchase/restore callbacks. It must not construct authoritative subscription state, validate receipts, or grant entitlements.

## ADR-COM-010-04 — Referenced paywall state is part of the repository contract

`paywall_state.dart` is retained because repository imports and tests prove it is an active production contract. Manifest omission is not deletion evidence.
