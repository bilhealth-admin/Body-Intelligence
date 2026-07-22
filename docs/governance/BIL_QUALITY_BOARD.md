# BIL Quality Board

Project: Body Intelligence Log  
Branch: `phase-3-product-excellence`  
Current Program: `BIL-STAB-002 — Product Stabilization`  
Current Focus: `STAB-202 — Secondary Page Navigation`

---

## Project Health

| Metric | Current State | Target |
|---|---|---|
| Windows Debug Build | Pass | Pass |
| Android Debug APK | Pass | Pass |
| Analyzer | 0 errors / 26 warnings and info | 0 errors; warnings reduced deliberately |
| Welcome V10 Functional Tests | Pass | Pass |
| Welcome V10 Responsive Tests | Pass | Pass |
| Welcome V10 Golden Tests | Pass | Pass |
| Full Test Suite | Known failures remain | All approved contracts pass |
| Repository Baseline | Established | Maintained |
| Stabilization Progress | 2 of 11 tasks complete — 18.2% | 100% |

---

## Critical

| ID | Issue | Classification | Status | Evidence / Commit |
|---|---|---|---|---|
| STAB-201 | Welcome Responsive Overflow | Product regression | Complete | `fix(onboarding): prevent welcome overflow on compact widths` |
| STAB-202 | Secondary Page Navigation | Product regression | Open | Challenges and other secondary pages need guaranteed Back/Dashboard behavior |
| STAB-203 | Dashboard Refresh Timeout and Loading Overflow | Product regression | Open | Full-suite baseline showed refresh-related failure and a 29 px overflow |
| STAB-204 | Arabic Dashboard Encoding | Product regression | Open | Corrupted/mojibake Arabic literals require repair and prevention test |

---

## High

| ID | Issue | Classification | Status | Evidence / Commit |
|---|---|---|---|---|
| STAB-205 | Startup Accessibility and Recovery Contracts | Lost contract / regression | Open | Retry, localized semantics, reduced motion, and redirect behavior require classification |
| STAB-206 | Responsive Shell and Quick Add Contracts | Mixed: regression / outdated tests | Open | NavigationRail, semantics, FAB, and adaptive quick-add behavior require product-contract review |
| STAB-207 | Dashboard Architecture Split | Architecture debt | Open | Introduce immutable DashboardViewModel and decompose monolithic dashboard composition |
| STAB-208 | Dashboard Design-System Consolidation | Design-system debt | Open | Remove unintended default Material primitives and direct one-off styling |
| STAB-211 | Welcome V10 Test Modernization | Outdated tests / golden modernization | Complete | `529f663` — widget, RTL/LTR, persistence, responsive, and V10 goldens pass |

---

## Medium

| ID | Issue | Classification | Status | Evidence / Commit |
|---|---|---|---|---|
| STAB-209 | Remaining Golden Test Modernization | Outdated references | Open | Update only after each affected surface is visually approved and regression-free |
| STAB-210 | Analyzer Warning Cleanup | Code quality | Open | 26 warnings/info remain; no compile errors |
| STAB-212 | PremiumSurface Contract Review | Mixed: implementation change / outdated tests | Open | Existing tests expect Card/InkWell internals no longer present |
| STAB-213 | Onboarding Recovery and Conversation Test Review | Mixed: regression / outdated tests | Open | Tests still reference old button/text contracts |
| STAB-214 | Information Hierarchy Contract Review | Mixed: regression / outdated tests | Open | P3-E1-010 test cannot find expected top-level action |

---

## Completed

| ID | Deliverable | Status | Evidence / Commit |
|---|---|---|---|
| STAB-201 | Welcome Responsive Overflow | Complete | Approved visually on Windows; no overflow in compact/mobile/wide Welcome tests; commit message recorded above |
| STAB-211 | Welcome V10 Test Modernization | Complete | `529f663` |
| GOV-001 | Repository baseline and stabilization governance | Complete | Baseline, execution ledger, Quality Board, and Product Excellence packs established |
| REPO-001 | Ignore local bundles, backups, and runtime evidence | Complete | `6b53f4e` |

---

## Current Execution Order

1. `STAB-202` — Secondary Page Navigation.
2. `STAB-203` — Dashboard Refresh Timeout and loading overflow.
3. `STAB-204` — Arabic Dashboard Encoding.
4. `STAB-205` — Startup Accessibility and Recovery Contracts.
5. `STAB-206` — Responsive Shell and Quick Add Contracts.
6. `STAB-212` / `STAB-213` / `STAB-214` — classify remaining stale or lost contracts.
7. `STAB-207` — Dashboard Architecture Split.
8. `STAB-208` — Dashboard Design-System Consolidation.
9. `STAB-209` — remaining approved Golden modernization.
10. `STAB-210` — analyzer cleanup.
11. Full cross-platform regression gate.

---

## Stabilization Exit Criteria

The stabilization program is not complete until:

- No known critical crash, navigation trap, or overflow remains.
- All approved regression tests pass.
- Outdated tests are updated only after contract classification.
- Startup recovery, localized semantics, and reduced-motion behavior are verified.
- Dashboard refresh completes deterministically.
- Arabic production strings are valid and protected by an automated mojibake test.
- Windows and Android builds pass.
- Web persistence and iPhone/iPad verification are recorded.
- Analyzer has zero errors and remaining warnings are intentionally resolved or documented.
- Every completed task includes tests, a focused commit, and ledger/board updates.

---

## Operating Rules

- No unrelated feature implementation during stabilization.
- No manual edits are required from the Product Owner when a complete replacement file or package can be provided.
- Do not update golden files to conceal layout or rendering defects.
- Do not change approved flagship visuals unless the task explicitly requires it.
- Every failing test must be classified as:
  - product regression;
  - lost contract;
  - outdated test;
  - golden drift;
  - flaky or hanging test.
- Every completed task must include:
  - acceptance evidence;
  - relevant tests;
  - focused commit;
  - Quality Board update;
  - Stabilization Ledger update.
