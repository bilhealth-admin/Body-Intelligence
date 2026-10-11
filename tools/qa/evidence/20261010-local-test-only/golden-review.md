# Individual Golden review - local test-only handoff

Tested source: `c3acb5c79d80f65488f3f048ab307b61aabb0ca3`. All 29 current local MASTER/TEST pairs match the individually inspected historical pairs exactly in decoded RGBA pixels. Historical source: [run 38039168562](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38039168562).

None is approved; no golden baseline, assertion or threshold was changed. Comparisons and original generated PNGs are in local-evidence.zip.

| # | Golden | Individual observation | Decision |
|---|---|---|---|
| 1 | `epic8_weekly_report_phone_ltr_light` | Background, app-bar typography and paragraph wrapping shift card positions; week dates and 3/7 preserved. | Keep red pending reference/QA approval |
| 2 | `en_ltr_small_light` | Background, input outline and privacy panel changed; Skip/Continue and measurement range preserved. | Keep red pending reference/QA approval |
| 3 | `ar_rtl_small_dark_160` | Dark palette, Arabic/Body Twin wrapping and input outline changed; connected Arabic and Skip/Continue remain visible. | Keep red pending reference/QA approval |
| 4 | `female_hip_light_160` | Light palette, outline and text color changed; hip image and controls preserved. Privacy panel is partly outside viewport in both; needs scroll/device check. | Keep red pending reference/QA approval |
| 5 | `live_health_watch_compact_all_metrics` | Watch case changes dark to metallic silver. Both historical images contain block/tofu glyphs; cannot certify readable metrics or icons from these captures. | Keep red pending reference/QA approval |
| 6 | `permissions_light_160` | Light background/card surfaces and text colors changed; Health Connect Not requested and Skip/Continue preserved; lower content outside viewport. | Keep red pending reference/QA approval |
| 7 | `plan_dark_160` | Dark palette and paragraph wrapping changed; 1808 kcal and 126g protein remain. Protein card is partly below dock in both. | Keep red pending reference/QA approval |
| 8 | `recipe_library_polish_phone` | App-bar icons, chip spacing, recipe-card background/border and bookmark shape changed; shakshuka, 25min, 2 servings, 225kcal and 15.4g preserved. | Keep red pending reference/QA approval |
| 9 | `epic8_weekly_report_calories_anchor` | Background, card outline, app-bar font and paragraph wrapping changed, shifting chart/card heights; empty-data values and seven weekday ticks preserved. | Keep red pending reference/QA approval |
| 10 | `epic8_weekly_report_frequent_anchor` | Card borders/surfaces, icon color and app-bar typography changed; no-food text and three zero macro values preserved. | Keep red pending reference/QA approval |
| 11 | `premium_dashboard_phone_after` | Protected Home: calorie unit/bar/equation order and card heights differ; Coach/empty states remain. Today button appears as a block in both historical images; visual approval withheld. | Keep red pending reference/QA approval |
| 12 | `facts_320x568_en_light_200` | Light background/text color changed at 320px/200%; facts text extends behind/below bottom dock in both captures. Scroll/accessibility requires real-device review. | Keep red pending reference/QA approval |
| 13 | `epic8_weekly_report_alltime_anchor` | Card backgrounds/outlines and icon/app-bar styling differ; unavailable/zero all-time values, no steps and 0-day streak preserved. | Keep red pending reference/QA approval |
| 14 | `epic8_weekly_report_exercise_anchor` | Exercise/all-time card surfaces/outlines and icon colors changed; connection action, unavailable goals and zero exercise days preserved. | Keep red pending reference/QA approval |
| 15 | `epic8_weekly_report_macro_tooltip` | Tooltip border, card surfaces and app-bar styling differ; Protein 0.0g/carbs 0.0g/fat 0.0g and no-data notice preserved. | Keep red pending reference/QA approval |
| 16 | `epic8_weekly_report_macros_anchor` | Macro card border/surface and chart grid color changed; zero macros, no-data notice and nutrition-import action preserved. | Keep red pending reference/QA approval |
| 17 | `premium_dashboard_desktop_after` | Protected desktop Home: calorie unit/bar/equation ordering and vertical spacing change. Today control is a block in historical captures; no baseline approval. | Keep red pending reference/QA approval |
| 18 | `premium_dashboard_tablet_after` | Protected tablet Home: calorie equation order, larger weight card, Body Twin/Discover image crop and vertical positions differ; source/reference/device review required. | Keep red pending reference/QA approval |
| 19 | `height_units_en_light_100` | Light palette/input border and paragraph wrap reduce image offset; 170cm and 120-250cm range preserved. | Keep red pending reference/QA approval |
| 20 | `epic8_weekly_report_empty_phone` | Empty report background/card outlines and text wrapping shift scroll content so logged-calories row is above viewport in TEST; not evidence of data removal. | Keep red pending reference/QA approval |
| 21 | `epic8_weekly_report_evidence_phone` | Background/icon styling and cumulative scroll offsets shift feedback/grid cards; 4.7L,92.8kg,missing sleep/energy and zero fasting/body-context preserved. | Keep red pending reference/QA approval |
| 22 | `epic8_weekly_report_phone_rtl_dark` | Dark background, Arabic app-bar typography and card offsets differ; connected Arabic, RTL, dates and 3/7 preserved. | Keep red pending reference/QA approval |
| 23 | `premium_dashboard_light_corrected` | Protected light Home: calorie order, weight height and Body Twin/Discover image composition differ; keep baseline red pending owner/QA approval. | Keep red pending reference/QA approval |
| 24 | `plan_320x568_ar_dark_200` | Dark palette changed; connected Arabic title and Continue visible at 320px/200%; plan numbers are below viewport and cannot be verified from this capture. | Keep red pending reference/QA approval |
| 25 | `workout_library_offline_empty_phone` | Background, icon sizes/colors, rounded search field, chip borders and Cardio tile border changed; offline notice and audience safety copy preserved. | Keep red pending reference/QA approval |
| 26 | `epic8_weekly_report_coverage_phone` | Background, wrapping and feedback icons differ, moving cards upward; protein/snack count 1 and 4.7L/92.8kg preserved. | Keep red pending reference/QA approval |
| 27 | `epic8_weekly_report_nutrition_phone` | Background and paragraph wrapping shift accumulated scroll position; vegetables/fruit/protein/snack content preserved. No reference approval inferred. | Keep red pending reference/QA approval |
| 28 | `epic8_weekly_report_sources_phone` | Background, card outlines, feedback icons and paragraph wrapping shift scroll layout; 4.7L/92.8kg/3-of-7 and 3900/14700kcal preserved. | Keep red pending reference/QA approval |
| 29 | `ai_430x932_ar_light_100` | Light palette, option outlines, icon color/size and mixed Arabic/Latin wrapping differ; Coach image, selected options, consent copy, Skip/Continue preserved. | Keep red pending reference/QA approval |
