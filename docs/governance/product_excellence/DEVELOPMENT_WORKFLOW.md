# BIL Development Workflow

## 1. Work Intake

Every meaningful task must have an ID and belong to an approved program, epic, or stabilization item.

Minimum task definition:
- objective;
- scope;
- exclusions;
- affected files/modules;
- acceptance criteria;
- required tests;
- risks;
- documentation impact.

Unscoped feature work is not accepted.

## 2. Source of Truth

Before implementation, consult:
1. Phase 3 Constitution;
2. repository baseline;
3. stabilization execution ledger;
4. quality board;
5. relevant Product Excellence documents;
6. feature-specific architecture/science documents.

Chat history is not the permanent source of truth.

## 3. Branch and History Safety

Current stabilization work remains on the approved branch unless governance explicitly changes it.

Prohibited without explicit approval:
- destructive reset;
- history rewrite;
- force push;
- deleting unknown work;
- bulk restore;
- dropping migrations;
- replacing the repository with an archive.

Before risky work:
- inspect `git status`;
- preserve a commit or backup;
- document the reason.

## 4. Task Lifecycle

Statuses:
- Planned
- Ready
- In Progress
- Blocked
- Verification
- Complete

A task enters `In Progress` only when:
- scope is understood;
- dependencies are available;
- acceptance criteria exist;
- baseline behavior is known.

## 5. Implementation Sequence

For each task:

### 5.1 Reproduce or establish baseline
- run the smallest relevant test;
- capture exact failure;
- identify whether product or test contract is wrong;
- avoid guessing.

### 5.2 Design
- choose the smallest durable architectural change;
- protect single sources of truth;
- identify cross-platform implications;
- identify migration and scientific implications.

### 5.3 Implement
- make focused changes;
- avoid unrelated cleanup;
- keep business logic out of widgets;
- update localization and accessibility together with UI.

### 5.4 Verify
Run the narrowest checks first, then broader gates:
- formatter;
- targeted test;
- feature test group;
- analyzer;
- full test suite when appropriate;
- platform build;
- manual verification.

### 5.5 Document
Update:
- Quality Board;
- Stabilization Ledger;
- architecture/science docs if contracts changed;
- acceptance evidence.

### 5.6 Commit
Use one coherent commit per completed task or tightly coupled milestone.

## 6. Test Triage Rules

A failing test must be classified before modification:

### Product regression
The product violates an intended contract.
Action: fix product first.

### Lost contract
An important behavior disappeared during redesign.
Action: restore contract unless governance intentionally superseded it.

### Outdated test
Product behavior intentionally changed and the old expectation is no longer valid.
Action: update the test to the approved contract.

### Golden drift
Visual reference differs.
Action: never regenerate until responsive/layout defects are resolved and visual approval is recorded.

### Flaky or hanging test
Action:
- isolate asynchronous source;
- use deterministic clocks/data;
- avoid blind timeout increases;
- fix infinite animation/pump behavior;
- record root cause.

## 7. Commit Policy

Commit format:

```text
type(scope): imperative summary
```

Common types:
- `fix`
- `feat`
- `refactor`
- `test`
- `docs`
- `chore`
- `perf`

Examples:
- `fix(onboarding): prevent welcome overflow on compact widths`
- `fix(navigation): add dashboard fallback for secondary routes`
- `refactor(dashboard): introduce immutable dashboard view model`
- `test(startup): restore localized recovery contracts`

Commit rules:
- no generated build output;
- no local ZIP bundles;
- no runtime logs;
- no unrelated formatting;
- no misleading “final” wording;
- commit only after applicable acceptance criteria pass.

## 8. Review Checklist

Every code review checks:

### Product
- Does it solve the stated user problem?
- Is behavior coherent with BIL vision?

### Architecture
- Is logic in the correct layer?
- Is there duplication?
- Is the solution extensible?

### Science
- Are claims bounded and explainable?
- Are missing data and uncertainty handled?

### Privacy
- Is user data kept local by default?
- Is any transfer explicit?

### UX
- Compact/wide?
- RTL/LTR?
- Loading/empty/failure?
- Keyboard/touch?
- Accessibility?

### Quality
- Tests?
- Analyzer?
- Build?
- Documentation?
- Migration safety?

## 9. Definition of Done

A task is complete only when:
- acceptance criteria pass;
- relevant tests pass;
- no new analyzer errors;
- no known crash or overflow introduced;
- localization is complete;
- accessibility behavior is checked;
- required platforms are verified or explicitly recorded as pending;
- Quality Board is updated;
- Ledger is updated;
- commit hash is recorded.

“Looks correct on one machine” is not Done.

## 10. Sprint Exit Criteria

A stabilization sprint cannot close with:
- unexplained failing regression tests;
- known data-loss risk;
- known navigation traps;
- known critical overflows;
- unreviewed schema changes;
- undocumented scientific behavior.

Deferred issues require explicit board entries and rationale.

## 11. Feature Freeze During Stabilization

While the stabilization program is active:
- no unrelated new feature implementation;
- no diet-strategy UI;
- no barcode/AI expansion;
- no cosmetic redesign of locked surfaces.

Allowed:
- bug fixes;
- contract restoration;
- test updates after classification;
- architecture refactors required for stability;
- documentation and repository hygiene.

## 12. Release Evidence

Before release candidate:
- clean working tree;
- analyzer report;
- complete test report;
- Windows build;
- Android build;
- Web build and persistence check;
- iOS build/device evidence;
- accessibility checklist;
- privacy checklist;
- migration evidence;
- release notes.

## 13. Escalation Rules

Stop and request Product Owner approval for:
- destructive data behavior;
- fundamental product-policy decisions;
- changing scientific recommendations;
- introducing external services;
- authentication/sync architecture;
- monetization changes;
- legal/privacy changes;
- history rewrite;
- unsupported infrastructure or credentials.

Routine engineering decisions proceed without interruption when governed by these documents.
