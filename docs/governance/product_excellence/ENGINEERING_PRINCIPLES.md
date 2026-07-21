# BIL Engineering Principles

## 1. Purpose

BIL must remain maintainable, scientifically trustworthy, privacy-first, offline-first, and cross-platform while growing into a global body-intelligence platform.

Engineering decisions are evaluated by long-term product quality, not by implementation speed alone.

## 2. Architectural Boundaries

### 2.1 Single source of truth
Every business fact must have one authoritative source.

Examples:
- persisted user data: Drift/SQLite;
- derived body metrics: pure calculation engines;
- feature state: Riverpod providers/controllers;
- localization: canonical localization layer;
- design: shared tokens and components.

Duplicating calculations, thresholds, labels, targets, or formatting rules is prohibited.

### 2.2 Separation of concerns
Production features should separate:
- domain models;
- pure engines;
- repositories;
- application state/controllers;
- presentation view models;
- widgets;
- platform adapters.

Widgets must not become business engines.

### 2.3 Pure engines
Scientific and deterministic calculations should be implemented as pure Dart functions or services:
- no widget dependency;
- no navigation dependency;
- no direct database access;
- deterministic inputs and outputs;
- explicit assumptions;
- testable edge cases.

### 2.4 Repository boundaries
UI code must not directly compose SQL queries or mutate tables.

Repositories own persistence behavior and expose stable interfaces.

### 2.5 Feature-first organization
Code should be organized primarily around product features, while shared layers remain genuinely cross-feature.

A shared component is allowed only when:
- at least two real production consumers exist; or
- it represents an approved global design/system contract.

## 3. State Management

Riverpod is the canonical state-management layer.

Rules:
- prefer immutable state;
- keep providers narrow;
- avoid broad provider invalidation without documented reason;
- do not read providers deep inside reusable visual components;
- centralize derived dashboard state in view models;
- distinguish loading, empty, partial, success, and failure states;
- avoid hidden side effects during `build`.

## 4. Dashboard Architecture

The dashboard is an intelligence surface, not a collection of unrelated cards.

Required architecture:
- `DashboardViewModel` as a stable immutable representation;
- one orchestration/controller layer for composing repositories and engines;
- section widgets with narrow typed inputs;
- navigation actions outside calculation code;
- no repeated calculations across cards;
- explicit empty and confidence states;
- bounded rebuild areas.

Large monolithic files must be decomposed without changing approved behavior or visual identity.

## 5. Offline-First and Privacy-First

Core tracking, calculations, and insight generation must work without an account or internet connection.

Rules:
- local data remains authoritative unless a future sync contract explicitly changes that;
- cloud capabilities must never be simulated;
- disabled integrations must be presented honestly;
- no silent upload;
- no hidden analytics collection;
- export and deletion must be explicit and reviewable;
- future sync requires conflict-resolution and encryption design before implementation.

## 6. Cross-Platform Standard

Every production feature must account for:
- Android;
- iPhone/iPad;
- Windows;
- Web.

Responsive behavior is adaptive, not merely scaled.

Required considerations:
- compact, medium, and wide layouts;
- touch, mouse, keyboard, and focus navigation;
- RTL and LTR;
- safe areas;
- text scaling;
- platform-specific persistence constraints;
- route behavior for direct links;
- keyboard shortcuts only where they do not break mobile semantics.

## 7. Design-System Governance

Production UI should use canonical:
- colors;
- spacing;
- typography;
- radii;
- elevations;
- motion timings;
- surfaces.

Direct one-off styling is discouraged and requires justification.

Approved flagship identity must not be duplicated into feature-local constants.

## 8. Accessibility

Accessibility is a release requirement.

Minimum expectations:
- meaningful semantics;
- keyboard/focus support;
- sufficient contrast;
- reduced-motion behavior;
- large-text resilience;
- no color-only meaning;
- logical reading order;
- minimum interactive target sizes;
- no inaccessible custom controls.

## 9. Performance

Performance work begins in architecture, not after release.

Rules:
- minimize broad rebuilds;
- avoid unbounded animations;
- isolate expensive charts and painters;
- paginate or virtualize long content;
- profile before introducing complexity;
- maintain testable performance budgets;
- avoid false optimization that harms clarity.

## 10. Scientific Integrity in Code

Scientific outputs must encode:
- inputs;
- assumptions;
- evidence level;
- confidence;
- limitations;
- explanation;
- suggested action.

Missing data is not zero.

Correlation is not causation.

Estimated values must be labeled as estimates.

No engine may silently diagnose, prescribe, or overstate certainty.

## 11. Error Handling

Errors must be:
- safe;
- localized;
- actionable;
- non-destructive;
- observable in development;
- appropriately redacted in production.

Raw stack traces or `error.toString()` must not be exposed to end users.

Recovery paths should be explicit where recovery is possible.

## 12. Testing Strategy

Required test layers:
- pure unit tests for engines;
- repository/database tests;
- provider/controller tests;
- widget behavior tests;
- navigation tests;
- localization and RTL tests;
- responsive and overflow tests;
- golden tests for approved stable surfaces;
- migration tests;
- release smoke tests.

Tests must verify product contracts, not incidental widget implementation where avoidable.

Golden files are updated only after:
1. layout defects are fixed;
2. visual review is complete;
3. the new reference is intentionally approved.

## 13. Dependency Policy

Dependencies require:
- clear product need;
- maintenance assessment;
- license review;
- platform compatibility;
- privacy/security review;
- size and performance consideration;
- an exit strategy for critical dependencies.

Do not upgrade dependencies solely because newer versions exist.

## 14. Migration and Compatibility

Persisted data is a product asset.

Schema changes require:
- versioned migration;
- migration tests;
- rollback/data-loss assessment;
- explicit default behavior;
- compatibility with existing local records.

Historical records must retain the plan, target, units, and assumptions active when they were created.

## 15. Technical Debt

Technical debt must be visible in:
- `BIL_QUALITY_BOARD.md`;
- the execution ledger;
- code comments only when actionable and linked to an ID.

No hidden temporary architecture.

Every accepted debt item requires:
- owner;
- reason;
- impact;
- target milestone.

## 16. Security

Minimum security practices:
- validate imported data;
- avoid unsafe file paths;
- protect secrets from source control;
- never log sensitive health data unnecessarily;
- treat exported health data as sensitive;
- future network clients require certificate, authentication, and threat-model review.

## 17. Definition of Engineering Quality

A change is not high quality merely because it compiles.

It must also:
- preserve architecture;
- pass applicable tests;
- handle failure states;
- work responsively;
- support RTL/LTR;
- be accessible;
- avoid scientific overclaiming;
- avoid hidden data loss;
- be documented where behavior or architecture changes.
