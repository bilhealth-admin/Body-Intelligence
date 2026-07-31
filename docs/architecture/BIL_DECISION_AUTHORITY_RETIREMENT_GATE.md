# BIL Decision Authority Parity and Retirement Gate

Status: Accepted architecture constraint for BIL v1 stabilization.

## Decision

The Dashboard continues to obtain its visible One Best Action exclusively
through `DashboardDecisionAuthority`.

`LegacyDashboardDecisionAuthority` remains the current reference
implementation. It must not be removed, bypassed, or replaced until a candidate
adapter passes `DashboardDecisionAuthorityParityGate` over the approved
canonical matrix with no mismatch in:

- action type;
- title;
- reason;
- ordered evidence.

An empty matrix or duplicate scenario identifiers is not valid parity evidence.

## Why the similarly named engines are not interchangeable

The legacy Dashboard engine implements a product-specific priority policy over
weight check-in, logging completeness, protein, hydration, observation time,
and Decision Memory suppression.

The AI Platform engine ranks caller-supplied candidates only after accepted
Truth context, Body Twin/forecast inputs, evidence thresholds, ranking policy,
and safety eligibility. Its result can be accepted, abstained, or rejected.

These are different contracts and responsibilities. A shared class name is not
proof of behavioral equivalence.

## Retirement rule

Retirement requires all of the following:

1. A candidate explicitly implements `DashboardDecisionAuthority`.
2. The complete canonical matrix passes with zero observable mismatches.
3. Dashboard production code still has exactly one authority call path.
4. AI ranking, Truth, forecast, and safety tests remain green.
5. A separate approved package authorizes the production switch and deletion.

Until then, the advanced AI engine stays isolated from the Dashboard authority
path. This is deliberate containment, not a claim that either engine is
obsolete.

## Package 006 effect

Package 006 adds the reusable parity gate, its canonical regression matrix, and
the static boundary lock. It performs no production switch and deletes no
engine.
