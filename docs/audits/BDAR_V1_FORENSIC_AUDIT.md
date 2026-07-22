# BDAR v1 — Current Repository and Dashboard Forensic Audit

Audit ID: `BDAR-001`  
Source: latest user-supplied repository archive  
Status: Complete as a static forensic baseline; runtime findings remain to be verified in implementation packages.

## Executive conclusion

The latest repository confirms that the visible dashboard defects are not isolated cosmetic problems. The current dashboard combines a large orchestration surface, embedded scientific explanations, quick actions, metrics, evidence panels, and responsive layout logic in a small number of very large files.

The immediate risks are:

1. production Arabic mojibake;
2. a likely visual layer/leak or clipping/transparency defect around the deep-insights region;
3. excessive dashboard responsibility concentration;
4. fragile wide-screen information distribution;
5. refresh orchestration that can hang or fail as one aggregated operation;
6. stale tests that do not consistently represent the approved V10 product;
7. settings/profile navigation and editing contracts that are incomplete;
8. planned nutrition and exercise systems do not yet have production-grade strategy and scientific contracts.

## Verified repository facts

- The latest archive is the active review baseline.
- `dashboard_page.dart` is 353 lines.
- `dashboard_grid.dart` is 1,221 lines.
- `dashboard_header.dart` is 520 lines.
- The dashboard wide layout uses a 5/7 split between the hero/header region and `DashboardGrid`.
- `DashboardPage` uses one top-level `Stack` for background image, gradient, and foreground content.
- No second dashboard route, `IndexedStack`, or explicit duplicate dashboard page was found in the static dashboard implementation.
- The deep explanation content shown in the user screenshots exists inside the collapsed/expandable `Insights, progress and evidence` area in `dashboard_grid.dart`.
- `dashboard_grid.dart` contains widespread mojibake in Arabic strings and corrupted punctuation.
- Existing governance already identifies Arabic dashboard encoding, refresh, architecture split, and design-system consolidation as open work.

## Critical findings

### BDAR-C01 — Production Arabic text corruption

**Evidence**

`lib/features/dashboard/widgets/dashboard_grid.dart` contains many malformed sequences beginning with `Ø`, `Ù`, `Â`, and `â€`.

**Impact**

- unreadable Arabic;
- broken trust;
- inconsistent RTL experience;
- corrupted punctuation in English;
- inability to approve Arabic goldens.

**Required action**

Repair the source text, migrate user-facing strings toward the canonical localization layer, and add a repository-wide mojibake regression test.

---

### BDAR-C02 — Apparent hidden/leaked insights surface

**Evidence**

The screenshots show faint or partially visible deep-explanation content, including concepts such as evidence, confidence, and rationale, outside the expected visible card boundary.

Static review found no second dashboard page or duplicate `IndexedStack`. The matching content belongs to the nested expandable insights area in `dashboard_grid.dart`.

**Current diagnosis**

The defect is more likely one or more of:

- translucent surface composition exposing content unexpectedly;
- clipping failure;
- horizontal layout escape in RTL;
- nested expansion content painting outside its intended visual boundary;
- stale state leaving an expansion surface visually open;
- a combination of glass transparency and wide-layout geometry.

**Required action**

Create a deterministic reproduction test and inspect paint bounds, clipping, expansion state, and RTL behavior. Do not delete the explainability content; preserve it behind an intentional, accessible interaction.

---

### BDAR-C03 — Dashboard refresh is an all-or-nothing aggregation

`DashboardPage.refresh` awaits several provider futures in a single `Future.wait`.

**Risk**

- one slow or stuck provider delays the entire refresh;
- partial successes are not represented;
- user sees a generic failure state;
- difficult test determinism;
- potential indefinite spinner or timeout behavior.

**Required action**

Introduce bounded refresh orchestration with per-source results, deterministic completion, and partial-success messaging.

---

### BDAR-C04 — Dashboard architecture concentration

`dashboard_grid.dart` currently owns too many responsibilities:

- data interpretation;
- localized strings;
- recommendation text;
- dialogs;
- navigation;
- meal repetition;
- hydration actions;
- insight expansion;
- scientific evidence presentation;
- progress presentation;
- deep explanation;
- visual layout.

**Required action**

Introduce an immutable dashboard view model and split orchestration, actions, sections, and presentation. No calculation should be duplicated during the split.

## High findings

### BDAR-H01 — Wide-screen hierarchy wastes usable space

The current 5/7 wide split can create an underused region depending on header height and grid composition. The screenshots demonstrate poor balance and a large visually empty area.

Required action: design an adaptive content grid based on content priority rather than a fixed hero-vs-grid split alone.

### BDAR-H02 — Explainability is valuable but visually buried

The evidence and confidence content is a genuine BIL differentiator, but it is embedded deep inside one large expansion surface.

Required action: preserve explainability while exposing only the right level of information at the right time.

### BDAR-H03 — Direct strings inside widgets

Many user-facing English and Arabic strings are embedded directly in dashboard widgets.

Required action: migrate incrementally to one localization source, beginning with every dashboard string touched by the repair.

### BDAR-H04 — Settings/profile editing is not yet a product-quality center

The current implementation path and recent candidate package do not yet satisfy:

- correct return-to-settings behavior;
- canonical number controls;
- profile vs plan separation;
- unsaved-change handling;
- real diet-strategy selection;
- exercise frequency/type;
- movement-energy summary.

Required action: reject the primitive candidate and rebuild from explicit product, science, persistence, and navigation contracts.

### BDAR-H05 — Exercise system requires a scientific engine

A binary “I exercise” field is insufficient.

Required action: build activity sessions around activity type, duration, intensity, frequency, user weight, MET evidence, estimated energy, uncertainty, and double-counting prevention.

## Medium findings

- Analyzer warnings remain.
- Some tests target obsolete Material internals or old product text.
- Navigation contracts are inconsistent between shell and secondary pages.
- Appearance naming can be modernized while preserving stored enum values.
- Region/city/timezone needs a proper IANA-based model and cross-platform fallback.
- Dashboard golden coverage should be regenerated only after layout and Arabic repair.

## Product additions formally preserved

The following remain in the program and must not be lost:

- Balanced nutrition
- Mediterranean
- DASH
- Low carbohydrate
- Ketogenic
- Targeted ketogenic
- Cyclical ketogenic
- Carb cycling
- Intermittent fasting
- PSMF
- Refeed
- Diet break
- Maintenance
- Fat loss
- Lean bulk
- Recomposition
- Exercise engine
- Adaptive TDEE
- Weight prediction
- Water-retention interpretation
- Body-composition interpretation
- Explainability
- Recommendation engine
- privacy-first/offline-first operation
- Android, iPhone/iPad, Web, and Windows support

These are program commitments, not permission to implement them without scientific, architectural, persistence, UX, accessibility, and test contracts.

## Static-audit limitation

This audit can identify source-level architecture and likely causes. The exact hidden-layer paint defect must be reproduced in a running build before its root cause is declared final.
