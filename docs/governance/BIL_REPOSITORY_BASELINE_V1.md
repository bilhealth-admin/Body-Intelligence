# BIL Repository Audit — Baseline Reference v1

## Scope and evidence
Reviewed the uploaded `body_intelligence_log(2).zip` as the current repository baseline.

Static inventory:
- 573 files in the archive.
- 158 production Dart files under `lib/`.
- 50 Dart test files.
- 13 governance/release/science documents.
- 44 tracked Phase 3 ledger items: 40 complete, 4 planned.
- 25 historical ZIP bundles stored inside the repository.
- Archive size: about 467 MB; uncompressed size: about 733 MB.

This report distinguishes:
1. Verified repository facts.
2. Static engineering findings.
3. Product-completion estimates.
4. Proposed future scope.

No claim is made that all runtime paths, platforms, tests, or builds passed in this audit environment because Flutter/Dart SDK execution was not available here.

---

## Executive verdict

BIL is no longer a prototype. It has a serious offline-first architecture, deterministic calculation engines, a mature persistence layer, strong scientific-honesty rules, bilingual localization, adaptive navigation, and an unusually strong automated test base for its stage.

However, it is not yet release-ready or “the best program in the world.” The main gap is not raw feature count; it is consolidation and production hardening:
- Dashboard composition is oversized and difficult to maintain.
- Visual design primitives are still inconsistent in production paths.
- Navigation to secondary pages is incomplete.
- One Dashboard source file contains corrupted Arabic text.
- Historical bundles and backups pollute the repository.
- Several documented milestones remain planned.
- Physical-device and cross-platform release verification remains incomplete.
- Major nutrition-product capabilities such as barcode logging, recipes, exercise, strategic diet modes, and meal planning are absent or partial.

BIL already has a credible foundation to become a differentiated global product, but the next work must be architectural and evidence-driven—not a large unstructured feature dump.

---

## Verified strengths

### Architecture
- Feature-first Flutter layout.
- Riverpod state management.
- Drift/SQLite as the active source of truth.
- Pure Dart engine layer independent of UI and persistence.
- Explicit local-first and privacy-first boundaries.
- External capabilities remain disabled rather than simulated.
- Versioned schema and migration documentation.
- Deterministic insight objects with evidence, confidence, explanation, and suggested action.

### Scientific integrity
- Missing nutrients are not represented as zero.
- Weight change is not automatically labeled fat or muscle change.
- Sparse data lowers confidence.
- Goal-date and trend behavior are gated.
- Extreme deficits, starvation, and dehydration are not rewarded.
- AI is intentionally prevented from silently changing targets or logging data.

### Product systems already present
- Startup and onboarding.
- Profile and goals.
- Weight and measurements.
- Meal and food logging.
- Water logging.
- Daily return and one-best-action logic.
- Trend and analytics engines.
- Decision memory.
- Life context.
- Experiments.
- Private behavior-first challenges.
- Share Studio.
- Adaptive shell for compact and wide layouts.
- Arabic/English support.
- Local export/reset boundaries.

### Quality evidence
- 50 Dart test files cover engines, repositories, migrations, localization, navigation, dashboard states, onboarding recovery, analytics, performance budgets, and scientific safeguards.
- The Phase 3 ledger records 40 of 44 items as complete.

---

## Critical and high-priority findings

### Critical — corrupted Arabic strings in Dashboard
`lib/features/dashboard/widgets/dashboard_grid.dart` contains mojibake sequences such as `Ø`, `Ù`, `Â·`, and `â€”`. This is a production localization defect and can display unreadable Arabic.

Required response:
- Restore every affected Arabic literal from a known-good source.
- Add a repository test that fails when common mojibake byte patterns appear in Dart localization strings.
- Prefer moving remaining inline translations into the canonical localization layer.

### High — secondary navigation can strand users
Routes such as:
- `/challenges`
- `/context`
- `/decision-memory`
- `/plan`
- `/experiments`
- `/share-studio`

are outside the primary `ShellRoute`. Several pages rely on a plain AppBar and do not provide a guaranteed fallback to Dashboard. This explains the observed Challenges page with no obvious way back.

Required response:
- Define a shared `SecondaryPageScaffold`.
- Provide visible Back and Home/Dashboard behavior.
- Use `context.canPop()` when history exists; otherwise route safely to `/dashboard`.
- Test direct-link entry and in-app entry independently.

### High — DashboardGrid is a monolith
`dashboard_grid.dart` is approximately 52 KB and combines:
- provider consumption,
- aggregation,
- engine orchestration,
- localization selection,
- dialogs and actions,
- route decisions,
- and UI composition.

Consequences:
- expensive and broad rebuilds,
- difficult testing,
- higher regression risk,
- slower product iteration,
- unclear ownership of derived state.

Required response:
- Move dashboard aggregation into an immutable `DashboardViewModel`.
- Create one provider/controller that composes canonical engines and repositories.
- Split the UI into section widgets with narrow inputs.
- Keep route actions at page/controller level rather than embedding them throughout the grid.

### High — design-system drift
There are hundreds of direct color references in Dashboard/Onboarding paths, while Dashboard still mixes `Card`, `Container`, and `PremiumSurface`.

Required response:
- Enforce token-only styling in production Dashboard paths.
- Replace default Material cards where they conflict with flagship identity.
- Create canonical surface variants rather than one-off gradients.

### High — repository hygiene
The repository includes roughly 25 ZIP packages plus backup markers and generated/platform caches. This inflated the uploaded archive to about 467 MB.

Required response:
- Remove historical delivery ZIPs and local backup markers from the repository.
- Ignore `.dart_tool`, `build`, `.gradle`, local properties, and generated caches.
- Preserve historical milestones in Git tags/releases or external artifact storage, not inside the source tree.

### High — documented state is inconsistent
`TODO.md` still describes major onboarding/dashboard work as unfinished, while the Phase 3 ledger says most related work is complete and the running product has been manually changed several times.

Required response:
- Declare one authoritative execution ledger.
- Mark stale documents as archived or update them.
- Do not use contradictory TODO files to drive future implementation.

---

## Medium-priority findings

- Some Dashboard widgets still use default `Card`, weakening visual consistency.
- Settings and several pages are unusually large and should be decomposed.
- Runtime error handling sometimes exposes raw `error.toString()` outside trusted debug-only contexts.
- Release bundle identifiers and signing are not production-owned.
- Physical iPhone/Android accessibility and layout validation remain incomplete.
- External account, cloud, commerce, AI, community, coach, and remote-update services are deliberately blocked pending real infrastructure.
- Existing analyzer warnings should be cleaned before release, although they are not current compile blockers.
- The project has duplicated/legacy visual assets from V8/V9/V10; canonical assets should be declared and old ones retired.

---

## Completion estimates

These percentages measure different things and must not be mixed.

### Phase 3 ledger completion
- 40 complete out of 44 tracked items.
- Documented ledger completion: **90.9%**.

This does not mean the whole product is 90.9% ready. It measures only the currently defined Phase 3 ledger.

### Current offline MVP capability
Estimated **70–75%**.

Reasoning:
- Core profile, logging, persistence, analytics, intelligence, experiments, challenges, privacy, and localization exist.
- Important usability and production-hardening defects remain.
- Exercise, barcode, full recipes, strategic diet modes, wearable integration, and richer food acquisition are not complete.

### Store-release readiness
Estimated **50–60%**.

Major remaining items:
- repository cleanup,
- critical Dashboard/localization defects,
- full navigation hardening,
- production identifiers/signing,
- real-device Android/iPhone testing,
- Web persistence validation,
- accessibility sweep,
- release monitoring/privacy review,
- final builds and regression gates.

### Full global vision
Estimated **35–45%**.

The global vision includes a broader nutrition platform, exercise engine, strategic diet plans, meal planning, barcode/camera/voice acquisition, verified food data, richer personalization, commercial infrastructure, and global release operations.

---

## MyFitnessPal feature map to evaluate

Current official MyFitnessPal capability groups include:
- Food and exercise logging.
- Weight/measurement history and progress.
- Custom foods, meals, and recipes.
- Macronutrient views and adjustable goals.
- Barcode scanner.
- Meal scan.
- Voice logging.
- Food timestamps.
- Macros and calorie goals by meal.
- Different goals by day.
- Multi-day logging.
- Net-carbohydrate tracking.
- Intermittent-fasting timer/history.
- Data export.
- Food analysis and nutrient dashboards.
- Recipe discovery.
- Workout routines.
- Meal-plan builder, meal-prep mode, grocery lists, budget/time preferences, and grocery integration.

BIL should not copy this list blindly. Each accepted capability must offer a visible BIL advantage: offline safety, scientific transparency, stronger evidence, lower cognitive load, or more useful personalization.

---

## Recommended product program

### Program A — Dashboard Stabilization and Navigation
1. Repair Arabic corruption.
2. Introduce `DashboardViewModel`.
3. Split DashboardGrid into focused sections.
4. Implement universal secondary-page navigation.
5. Standardize flagship surfaces and tokens.
6. Add compact, wide, RTL, large-text, and direct-route tests.
7. Complete runtime/manual evidence.

### Program B — Food Logging Excellence
1. Verified/local food-source architecture.
2. Professional deduplication.
3. Barcode scanner abstraction.
4. Recipe and meal templates.
5. Favorites, recents, frequent meals, and multi-day copy.
6. Meal-level macro and calorie targets.
7. Timestamp-aware logging.
8. Data provenance and confidence for every nutrition value.

### Program C — Nutrition Strategy Engine
Do not place diet logic directly inside Dashboard widgets.

Create:
- `NutritionStrategy`
- `StrategyEligibility`
- `StrategySchedule`
- `DailyMacroTarget`
- `StrategySafetyGate`
- `StrategyEvidence`
- `StrategyVersion`
- `StrategyAdherenceReport`

Initial strategies:
- Balanced/flexible plan.
- Intermittent fasting.
- Ketogenic plan.
- Carb cycling.
- Protein-sparing modified fast (only if “PSF” means PSMF; exact name must be confirmed).

Safety requirements:
- Never prescribe clinician-directed or high-risk plans automatically.
- Pregnancy, eating-disorder history, relevant medications/conditions, adolescence, and other risk states require exclusion or professional review.
- PSMF must not be treated as a normal lifestyle mode; it is an aggressive intervention requiring strict safeguards.
- Every recommendation must show assumptions, evidence, macro math, minimums, schedule, and uncertainty.
- Plans must be versioned so historical days retain the targets active on those days.

### Program D — Adaptive Strategy Launcher
Add one Dashboard control, tentatively:
- Arabic: `خطتي الغذائية`
- English: `Nutrition Strategy`

Behavior:
- Bottom sheet on phones.
- Adaptive dialog/side sheet on desktop, Web, and large tablets.
- Shows current plan, eligibility, comparison, preview, risks, schedule, and calculated targets.
- Requires explicit confirmation before activation.
- Never silently changes historical or current targets.
- Provides “pause,” “switch,” and “return to balanced” paths.

### Program E — Exercise and Energy
A real exercise engine should precede claims of complete MyFitnessPal superiority:
- strength/cardio/activity logging,
- exercise energy as a range rather than false precision,
- optional policy for eating back exercise calories,
- training-day/rest-day targets,
- interaction with carb cycling,
- wearable boundary designed but disabled until real integrations exist.

---

## Proposed priority order

1. Critical repository and Dashboard repair.
2. Navigation and responsive shell completeness.
3. Dashboard architecture split.
4. Food-data/import/deduplication quality.
5. Exercise engine.
6. Nutrition Strategy Engine.
7. Dashboard strategy launcher.
8. Barcode/meal acquisition.
9. Recipes, meal planning, and grocery workflows.
10. Release infrastructure and store readiness.

Do not begin all diet systems simultaneously. First create the common strategy contract and implement Balanced + one lower-risk strategy end-to-end. Then add the others through the same tested engine.

---

## Baseline decision

The uploaded ZIP is accepted as:

**BIL Repository Baseline Reference v1 — July 2026**

It is the source for the current audit, not an immutable production release. The Phase 3 Constitution remains the governing product standard. Any implementation must preserve verified persistence, engines, migrations, tests, privacy boundaries, and scientific safeguards.

Before modifying code:
- create a clean repository copy,
- remove generated/cache/archive pollution,
- record Git branch and status,
- run format/analyze/test/build gates,
- capture Dashboard screenshots and runtime defects,
- then execute fixes in traceable milestones.
