# BIL39 • My Plan full visual-parity audit (BIL-13 / BIL-27)

**Basis:** `work/ios38-safe-fixes-20261025` at `155b079696430919f8272df934371f033fb11be2`.
**Scope:** presentation and already bundled local artwork only. Nothing in commerce, entitlement, diary persistence, nutrition, navigation stack, video playback, Cloud, or App Review is changed.

## Measured design-token comparison (source, not claimed device screenshots)

| Surface/token | Coach Overview source | My Plan before | My Plan in this branch |
|---|---|---|---|
| Scroll edge padding | `16 / 12 / 16 / 24` in `coach_reference_workspace.dart:129` | `16 / 12 / 16 / 30` | `16 / 12 / 16 / 24` |
| Max content width | Source Coach workspace uses route content width, with wrap grids | `760 px` maximum | Preserved `760 px`; small phones shrink naturally |
| Panel radius/edge/shadow | `BilPearlFinish.panel()`: 20 px radius, .8 px edge; 24 px blur / -8 spread | Same pearl tokens, no artwork | Same tokens on every My Plan card; no global theme replacement |
| Photo scrim | Coach meal hero stops `[0,.6,1]`; light opacity roughly `[.98,.95,.66]`, dark `[.95,.77,.12]` | No meaningful category artwork on plan cards | Stops `[0,.6,1]`; light `[.98,.95,.70]`, dark `[.98,.95,.82]` to retain contrast over unknown photos |
| Tabs | Coach text `12 px / w600`, horizontal inset `17`, radius 11 | My Plan inherited text style, same 17 inset/radius | My Plan `12 px / w700`, same geometry and 44 px minimum height |
| Hero hierarchy | Coach meal `15 px / w700` and muted explanatory copy | My Plan titleLarge, unweighted | My Plan titleLarge/w800 + status pill + consistent 12/16 gap scale |
| Metric grid | Coach 2 columns on small/4 on wide, 7 px gap | Plain sentences for plan extent/progress | Semantic My Plan tiles: 1 column <410 px, 2 columns above; 10 px gap |
| Photos | Local Coach hero image + directional tint | None for overview/today/week/progress/session | Reused existing local category covers, never recipe/video-specific claims |
| Accessibility | Visible text, supported locales | Text remains | RTL-aware directional scrim; image excluded from accessibility tree; decorative cover disabled in high-contrast |
| Runtime cost | Coach image background | No new photo cost | `Image.asset(cacheWidth:560)`, no network, no `BackdropFilter`, error fallback, repaint isolation |

## Full My Plan surface map

| Area | Before | After implementation | Behavioral constraints |
|---|---|---|---|
| Header and plan overview | Date/status/prompt in plain card | Atmospheric hero, bolder title, clearly identified status and two factual metrics | Does not change active/draft state |
| Today: strength/home/recovery | Plain text and expansion | Category-specific muted cover + aligned icon/date/typography, same workout steps and action buttons | Original completion/undo/session/library buttons remain |
| Today: suggested meals | List on plain panel | Muted nutrition lifestyle art and accessible section title | Suggestions are not logged intake; meal IDs untouched |
| Schedule | Unframed week arrows + plain daily cards | Separate dated week glass panel + contextual day artwork, bolder dates | Week selection, deferral, recovery limits and click flows untouched |
| Day detail bottom sheet | Bare date/session heading | Muted visual summary with category icon and saved date | Opening exercise/review/defer unchanged |
| Progress | Numbers and bar in plain card | Visual progress hero + 1-/2-column confirmed/scheduled metrics | Completion data unchanged; nothing inferred from suggested meals |
| Progress phases, changes | Existing accordions | Retained within styled Progress, source strings preserved | No automatic training progression |
| Warm-up view | Plain session glass panel | Recovery scene under existing instructions and explicit continue button | No automatic workout logging |
| Exercise session | Plain main session panel | Category strength art + existing progress and prescribed sets/reps/rest | No changes to safety guidance, video references or finish action |
| Empty/loading/error and other settings | Existing states and separate load boundary | Original behaviors retained, use shared pearl panel; error boundary owned by Reliability stream | No loading-state implementation overlap |
| Meal Planner details and grocery/prep | Separate feature/module | NOT modified here: owned by Meal worker | No write to meal-plan or food-log code |

## Asset sourcing and truthful visuals

All references are pre-existing local files already declared by the app's `pubspec.yaml`, not new web images: `nutrition_plans/strength_lifestyle_v1.webp`, `nutrition_plans/balanced_market_lifestyle_v1.webp`, `professional/workouts/full_body_strength.jpg`, `professional/workouts/mobility_flow.jpg`, `professional/workouts/gentle_stretching.jpg`, `workouts/workout_strength_cover_v1.png`, `workouts/workout_kettlebell_cover_v1.png`, `flagship/bil_movement_v1.png`. Their inclusion in the existing app is confirmed; the repository alone does not prove third-party licensing paperwork. Covers are **category-level illustration only**, not an exact recorded exercise, meal, or verified-video still. No user-provided photo or health record is committed.

## Contrast, memory and RTL

The tested worst-case overlay assuming black beneath the light scrim and white beneath the dark scrim computes approximately **6.84:1** (light ink) and **6.82:1** (dark ink) for small text, exceeding WCAG AA 4.5:1. The new widget test checks this mathematically; these are source-derived limits, **not** claims of a full native-screen accessibility audit. RTL respects `AlignmentDirectional.centerStart/End`. High contrast omits the photo entirely, and normal image failures show the original pearl card instead of a blank/error. Images are downsampled to 560 decode pixels with no network fetching, per-row backdrop blur, or new image assets, and the image layers cannot capture taps.

## Tests, evidence, gating

Run `flutter test test/features/smart_plan/bil_smart_plan_visual_surface_test.dart`, existing `bil_smart_plan_page_test.dart`, `bil_smart_plan_states_visual_test.dart`, `bil_smart_plan_session_test.dart`, `bil_smart_plan_overview_finish_test.dart`, plus the repository's Format/Analyze and complete Golden suite on the exact final SHA. The new targeted test covers dark/light conservative contrast, high contrast fallback, RTL/text scaling/narrow width, touch through the decorative layer and local-only category references.

**Before screenshots:** user references `IMG_0984.jpeg` (Overview/Today), `IMG_0983.jpeg` (Today/Meals), `IMG_0993.jpeg` and `IMG_0970.jpeg` (Coach inspiration). These are read-only and never uploaded to GitHub. **After screenshots:** NOT CAPTURED at this source-edit stage. Device comparison for iPhone/iPad, native VoiceOver/Reduce Transparency, video sheet, true meal review, and all Golden approvals remain required. Never auto-rebaseline existing Golden PNGs based only on compile/format success.

## Protection / rollback

Draft PR only, target independent source work branch. To roll back, close the Draft PR or revert its visual-only commit. No checkout, merge, TestFlight upload, iOS38/App Review, production cloud, external images, price/credit gate, or paid CTA changes.

**Acceptance status:** BIL-13 and BIL-27 have visual implementation changes, but mark **UNVERIFIED** until final-source CI, reviewed screenshot diffs, RTL and device QA all pass. PR presence alone does not mean release-ready.
