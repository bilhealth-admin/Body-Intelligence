# BIL-UX 2026 — design decisions and verification boundaries

**Baseline**: \`qa/coach-community-next-20261005\` at \`bfe71232a622c70ba95089f5025aa8a04fcdebf7\` (captured October 8, 2026). **Working branch**: \`qa/bil-premium-visual-2026\`. Scope: every eligible secondary Flutter surface; **do not** modify Dashboard/Home, Community, AI Coach, their shared style dependencies, billing entitlement/pricing/trial, or release processes.

## References, identity, and method

- \`مقترح جديد .zip\` contains 146 numbered screenshots (\`IMG_9637.PNG\` to \`IMG_9782.PNG\`). \`reference_146_inventory.csv\` records every image without copying any MyFitnessPal brand assets into the app.
- \`flutter_route_coverage.csv\` independently inventories 116 GoRouter destinations (many lack a direct visual reference). The mappings marked “guess”, “candidate”, or “requires manual trace” need manual verification, and both inventories **explicitly state when native screenshots do not exist**.
- Inspired by the reference's restrained, readable list hierarchy — **not** its colors, imagery, logo, special compositions, distinctive symbols, slogans, or screen structure.
- BIL-specific visual direction: calm editorial, system typography, neutral gray outline symbols, one primary action per focus area, real nutrition evidence, predictable text hierarchy.

## Official sources checked as of October 8, 2026

| Guidance | Documented decision |
|---|---|
| [Apple HIG: Branding (updated 2026-09-09)](https://developer.apple.com/design/human-interface-guidelines/branding) | Reserve BIL accent for important actions, status, and content; don't flood menus with chromatic icons. |
| [Apple HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Allow increased text; avoid clipped line boxes and fixed small tap targets. |
| [Apple HIG: Layout](https://developer.apple.com/design/human-interface-guidelines/layout) | Validate multiple widths, localizations, long text, and dynamic type. |
| [Apple HIG: RTL](https://developer.apple.com/design/human-interface-guidelines/right-to-left) | Mirror directional chevrons while preserving meaningful number and brand direction. |
| [Apple HIG: Labels](https://developer.apple.com/design/human-interface-guidelines/labels) | Use native system type/colors to encode hierarchy. |
| [Material Design 3: typography](https://m3.material.io/styles/typography/overview) | Use roles/consistent weights rather than w900 headings on every row. |
| [Material Design 3: accessibility](https://m3.material.io/foundations/accessible-design/overview) | Ensure icon glyph size does not reduce actionable hit size; target at least ~48 logical pixels for icon buttons. |
| [Flutter: Themes](https://docs.flutter.dev/cookbook/design/themes) | Use a local \`Theme\` subtree; never modify app-wide \`ThemeData\` for this project. |
| [Flutter: responsive adaptive design](https://docs.flutter.dev/ui/adaptive-responsive/best-practices) | Test widths 320/390/430 and avoid fragile fixed column layouts. |
| [Flutter: accessibility](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling) | Include semantics, text scaling, contrast and focus states. |

## Modern health/product design comparisons (patterns only)

| Product | Relevant, non-copied pattern |
|---|---|
| [MyFitnessPal](https://www.myfitnesspal.com/) | Information density, focused food entry, divided settings rows; screenshots privately supplied by product owner. |
| [MacroFactor](https://macrofactorapp.com/) | Low-friction food log and coherent nutrition interaction. |
| [Lifesum](https://lifesum.com/features/) | Shortcuts for real repeat actions rather than decoration; recipe-to-log continuity. |
| [Cronometer](https://cronometer.com/) | Evidence-first nutrients and macros, transparent nutrition analysis. |
| [Apple Health](https://www.apple.com/health/) | Familiar platform text and clear data grouping. |
| [Oura](https://ouraring.com/) | Trends/recovery readability; calm presentation. |
| [WHOOP](https://www.whoop.com/) | Behavior-to-insight hierarchy; one primary metric per focus. |
| [Fitbod](https://help.fitbod.me/hc/en-us/articles/360004429814-How-Fitbod-Creates-Your-Workout) | Structured workout details tied to real exercise data. |
| [Hevy](https://www.hevyapp.com/) | Workout-log readability and controllable action density. |

The external sites provide examples/principles, not a statement that their private source code or exact 2026 mobile UI was inspected. No third-party screenshots are shipped as app assets.

## Scoped tokens

\`lib/features/visual_2026/bil_calm_visual_scope.dart\` owns the non-global scale:

- Native system font family (not bundled third-party font). iOS native SF-like system fallback, Android native system sans; Arabic gets native locale fallback and **0 letter-spacing adjustment** to avoid disrupting connected script.
- Titles: 22/19/16/14 logical pixels, with W600 only for major titles, W500 for labels; body 16/14/12.5, regular.
- Hairline borders and neutral surfaces with distinct verified light/dark colors.
- 16px horizontal page inset, 52px default row minimum; 18px necessary icon glyphs with **48px button targets**, 12–14px radii.
- Theme is created inside each unprotected route via \`BilCalmVisualScope\`. No global theme modification or shared navigation mutation.

## Code changes on this branch (not yet UI-certified)

**Read \`flutter_route_coverage.csv\` for route-level current status and \`reference_146_inventory.csv\` for all 146 reference images.**

The applied \`BilCalmVisualScope\` is expressly **route-local**: none of the three protected feature trees, global app theme or shared navigation has been edited. Its \`enabled: !widget.embedded\` option protects contexts where the Food Catalog is embedded in a different parent route. No third-party fonts or assets are bundled; script-native font fallback, semantic icon sizes, line height and text scaling remain configurable by OS.

### Completed source-level work (not screenshots/tests)

- Food Diary, focused Food Search and Add Food context: route typography; selected food saving and food evidence untouched; small neutral search add glyph inside unchanged 54/58px tapping surface.
- Food Catalog, Meals/Recipes/Foods, barcode search, Meal Scan guide: standalone route themes, embedded Food Catalog opts out.
- Progress/Measurement charts, Weight History, Nutrition Analytics/Reports, Weekly Digest: local text/card treatment; progress metric selection now text-first, chart gradient removed.
- Settings and More: text-only eligible destinations instead of colorful badges; existing Community and AI Coach destination rows retain their original appearance and notification count; Grouped Settings/Help/FAQ made lighter; preferences, privacy, legal, email-related parent pages, support, account removal and location scoped.
- Water, steps/Connected Health, Fasting, Sleep, routines and exercise library, recipe discovery: route-local theme; workout rows no longer include decorative CircleAvatar badges; important recording actions remain.
- Profile, Goals, Onboarding, Notification Settings: isolated main-route styling; no data storage, signup or subscription logic modified.
- Actual review scope still incomplete: inner overlays, permissions, forms, empty/error/loading, 125 eligible reference frames and many unrelated non-reference routes have **not** passed visual parity inspection.

### Evidence limitations

- **Not yet met:** full Flutter analyze and full widget/integration/golden tests, mobile-native matching before/after screenshots, real 320/390/430 AR/EN light/dark visual regression matrix, verified protected-route pixel invariance, 100% of eligible routes/states and error flows, checkout/payment untouched review, independent PR integration review.
- Flutter tests were authored for scope isolation (including AR/EN light/dark with text scaling), but **passing results must be captured from GitHub Actions; do not assume they pass.**
- Old / unrelated Library screenshots do not prove native BIL baseline for the exact branch. No fake body measurements or calories have been injected; no fabricated mock screenshot accepted as native.

## Non-negotiable QA

- Verify full diff contains no changes to \`lib/features/dashboard/**\`, \`lib/features/community/**\`, \`lib/features/intelligence_center/**\`, app-wide \`lib/app/theme/**\`, \`lib/shared/**\`, router/shell, \`lib/features/commerce/**\`, paywall and production.
- Check Flutter formatting, analyzer, source/contract/widget tests and actual iOS/Android native screenshots. Test 320/390/430; Arabic and English; light and dark; normal and >=1.8x text scale; error, loading, empty, editing and saving.
- Preserve every key, route callback, provider, repository write, entitlement and permission check.
- If no emulator/desktop is connected, no screenshot claim may be made from screenshot references, Flutter goldens or mock-ups.

## Collision management

Other agent BIL-00 owns integration branch \`qa/coach-community-next-20261005\`. Use an **unmerged draft PR** with this working branch as head and that branch as base, highlight base branch drift, and ask for non-protected changes to be reviewed/rebased manually. Do not auto-merge.