# BIL 2026 — سجل كامل للإخفاقات التسعين في الاختبارات الشاملة الثماني

**تاريخ التدقيق:** 10 أكتوبر 2026. **هذا التقرير مصدره سجلات GitHub Actions الفعلية وليس تخمينًا أو اختبارًا منفذًا على الجهاز.**

- المستودع: `bilhealth-admin/Body-Intelligence` — فرع QA فقط `qa/bil-quality-ux-integration-20261009`، PR #11.
- الكوميت الذي شُغّل عليه هذا الاختبار: `1133a0cc7cd1761a6bebe5e2af6ccbcd621549c0`، **وليس كوميت إصلاح التنقل الأحدث**.
- النتيجة: [verify #38007903223](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38007903223) — **8,303 PASS / 90 FAIL / 3 SKIPPED**، من ثماني مجموعات؛ كل واحدة انتهت Failure.
- قبلها: التنسيق والتحليل + المجموعات الخمس المركّزة كلها PASS. هذه ليست علامة على نجاح كامل التطبيق.
- الأعداد من سطور `tests passed, failed, skipped` الرسمية بكل Shard وجرد `❌` حالةً حالة؛ مجموع الإخفاقات = **90**.
- بعض الإخفاقات Golden/Pixels تخص Suites خارج المجموعات الخمس، وبعضها **وظيفي خطير** في ذرّية تسجيل الطعام/عزل الحساب، ومطلوب تشخيص كل حالة من خطّ الخطأ قبل اعتبارها "توقعات قديمة".
- **لا تُعدّل الاختبارات أو الصور المرجعية لمجرد تخضير CI، ولا تورّث نتيجة النجاح للكوميت الجديد.**

## التجميع حسب ملف الاختبار

| ملف الاختبار | الإخفاقات |
|---|---:|
| `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart` | 25 |
| `test/epic8_weekly_report_golden_test.dart` | 13 |
| `test/dashboard_polish/dashboard_polish_layout_review_test.dart` | 12 |
| `test/features/onboarding/onboarding_visual_golden_test.dart` | 9 |
| `test/features/dashboard/composition/dashboard_unknown_nutrition_flow_test.dart` | 4 |
| `test/features/nutrition/coach_food_commit_test.dart` | 4 |
| `test/premium_dashboard_benchmark_test.dart` | 4 |
| `test/features/nutrition/coach_meal_commit_boundary_test.dart` | 2 |
| `test/semantic_icon_badge_spacing_test.dart` | 2 |
| `test/architecture_source_file_size_guard_test.dart` | 1 |
| `test/bil_semantic_icons_test.dart` | 1 |
| `test/dashboard_composition_contract_test.dart` | 1 |
| `test/dashboard_epic_completion_contract_test.dart` | 1 |
| `test/dashboard_polish/dashboard_current_preview_test.dart` | 1 |
| `test/dashboard_polish/dashboard_live_health_hub_contract_test.dart` | 1 |
| `test/dashboard_polish/dashboard_p9_r15_final_visual_contract_test.dart` | 1 |
| `test/dashboard_polish/live_health_watch_layout_golden_test.dart` | 1 |
| `test/dashboard_polish/live_health_watch_visibility_test.dart` | 1 |
| `test/features/commerce/verified_entitlement_surface_contract_test.dart` | 1 |
| `test/features/wellness/recipe_library_polish_test.dart` | 1 |
| `test/features/wellness/workout_reference_golden_test.dart` | 1 |
| `test/launch_readiness/navigation_and_more_master_closure_test.dart` | 1 |
| `test/localization/bil_25_locale_fallback_closure_test.dart` | 1 |
| `test/visual_closure/visual_defect_regression_test.dart` | 1 |

## التفصيل الحرفي لكل Shard

### Shard 0 من 8 — 1006 tests passed, 10 failed.

**[سجل المهمة #114082962015](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38007903223/job/114082962015)** — 10 حالة فاشلة:

1. `test/dashboard_polish/dashboard_polish_layout_review_test.dart: en 320 at 1.0x retains all content and burned calories`
2. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: ar uses reference calorie and macro rows at 1.6x`
3. `test/dashboard_polish/dashboard_polish_layout_review_test.dart: en 320 at 1.6x retains all content and burned calories`
4. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: en uses reference calorie and macro rows at 1.6x`
5. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: fr uses reference calorie and macro rows at 1.6x`
6. `test/epic8_weekly_report_golden_test.dart: weekly report phone LTR light golden`
7. `test/features/commerce/verified_entitlement_surface_contract_test.dart: premium labels and AdGate consume verified entitlement only`
8. `test/features/dashboard/composition/dashboard_unknown_nutrition_flow_test.dart: en real Dashboard shows unknown macros after1905 commit`
9. `test/features/dashboard/composition/dashboard_unknown_nutrition_flow_test.dart: en actual calorie net and remaining stay unknown`
10. `test/features/onboarding/onboarding_visual_golden_test.dart: English LTR small phone light visual`

### Shard 1 من 8 — 1215 tests passed, 10 failed, 1 skipped.

**[سجل المهمة #114082961930](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38007903223/job/114082961930)** — 10 حالة فاشلة:

1. `test/dashboard_polish/dashboard_current_preview_test.dart: en current production dashboard and dock preview`
2. `test/dashboard_polish/dashboard_polish_layout_review_test.dart: en 390 at 1.0x retains all content and burned calories`
3. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: es uses reference calorie and macro rows at 1.6x`
4. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: tr uses reference calorie and macro rows at 1.6x`
5. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: de uses reference calorie and macro rows at 1.6x`
6. `test/dashboard_polish/live_health_watch_visibility_test.dart: connected watch renders only actual supported readings`
7. `test/features/dashboard/composition/dashboard_unknown_nutrition_flow_test.dart: ar real Dashboard shows unknown macros after1905 commit`
8. `test/features/dashboard/composition/dashboard_unknown_nutrition_flow_test.dart: ar actual calorie net and remaining stay unknown`
9. `test/features/onboarding/onboarding_visual_golden_test.dart: Arabic RTL small phone dark visual at 160 percent`
10. `test/localization/bil_25_locale_fallback_closure_test.dart: all tracked 25-locale surfaces close English fallback paths`

### Shard 2 من 8 — 942 tests passed, 8 failed.

**[سجل المهمة #114082961946](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38007903223/job/114082961946)** — 8 حالة فاشلة:

1. `test/dashboard_polish/dashboard_polish_layout_review_test.dart: en 390 at 1.6x retains all content and burned calories`
2. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: it uses reference calorie and macro rows at 1.6x`
3. `test/dashboard_polish/dashboard_polish_layout_review_test.dart: en 430 at 1.0x retains all content and burned calories`
4. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: pt-BR uses reference calorie and macro rows at 1.6x`
5. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: pt-PT uses reference calorie and macro rows at 1.6x`
6. `test/features/nutrition/coach_food_commit_test.dart: Food committed storage closed day blocks a new batch without changing existing snapshots`
7. `test/features/onboarding/onboarding_visual_golden_test.dart: female hip optional page visual`
8. `test/semantic_icon_badge_spacing_test.dart: More secondary navigation rows stay icon-free in rtl`

### Shard 3 من 8 — 1322 tests passed, 12 failed, 1 skipped.

**[سجل المهمة #114082962050](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38007903223/job/114082962050)** — 12 حالة فاشلة:

1. `test/architecture_source_file_size_guard_test.dart: hand-maintained Dart sources stay below the architecture ceiling`
2. `test/dashboard_epic_completion_contract_test.dart: dashboard exposes explicit priority hierarchy`
3. `test/dashboard_polish/dashboard_live_health_hub_contract_test.dart: P9-R9 live Health Hub and paired deck contracts are present`
4. `test/dashboard_polish/dashboard_p9_r15_final_visual_contract_test.dart: P9-R15 consolidated approved dashboard contracts are present`
5. `test/dashboard_polish/dashboard_polish_layout_review_test.dart: en 430 at 1.6x retains all content and burned calories`
6. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: ur uses reference calorie and macro rows at 1.6x`
7. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: fa uses reference calorie and macro rows at 1.6x`
8. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: hi uses reference calorie and macro rows at 1.6x`
9. `test/dashboard_polish/live_health_watch_layout_golden_test.dart: compact watch keeps all four readings below the clock`
10. `test/features/onboarding/onboarding_visual_golden_test.dart: calculated plan visual in dark mode`
11. `test/features/onboarding/onboarding_visual_golden_test.dart: Android final permission choices visual`
12. `test/features/wellness/recipe_library_polish_test.dart: uses exact local art and verified nutrition on a real card`

### Shard 4 من 8 — 832 tests passed, 12 failed.

**[سجل المهمة #114082961999](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38007903223/job/114082961999)** — 12 حالة فاشلة:

1. `test/dashboard_polish/dashboard_polish_layout_review_test.dart: ar 320 at 1.0x retains all content and burned calories`
2. `test/dashboard_polish/dashboard_polish_layout_review_test.dart: ar 320 at 1.6x retains all content and burned calories`
3. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: id uses reference calorie and macro rows at 1.6x`
4. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: ms uses reference calorie and macro rows at 1.6x`
5. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: ja uses reference calorie and macro rows at 1.6x`
6. `test/epic8_weekly_report_golden_test.dart: weekly report calories_anchor evidence`
7. `test/epic8_weekly_report_golden_test.dart: weekly report frequent_anchor evidence`
8. `test/features/nutrition/coach_food_commit_test.dart: Food operation journal fixed per-user source accepts its opaque owner and rejects another user before writes`
9. `test/features/nutrition/coach_food_commit_test.dart: Food operation journal every batch async owner boundary is atomic or reports an already durable commit`
10. `test/features/nutrition/coach_meal_commit_boundary_test.dart: Coach meal journal stale UUID or revision is rejected before item mutation`
11. `test/features/onboarding/onboarding_visual_golden_test.dart: English facts on 320 wide phone at 200 percent`
12. `test/premium_dashboard_benchmark_test.dart: phone premium dashboard golden`

### Shard 5 من 8 — 1136 tests passed, 13 failed, 1 skipped.

**[سجل المهمة #114082962110](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38007903223/job/114082962110)** — 13 حالة فاشلة:

1. `test/dashboard_composition_contract_test.dart: weight and steps use real three-zone crystalline Cartesian bars`
2. `test/dashboard_polish/dashboard_polish_layout_review_test.dart: ar 390 at 1.0x retains all content and burned calories`
3. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: ko uses reference calorie and macro rows at 1.6x`
4. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: zh-Hans uses reference calorie and macro rows at 1.6x`
5. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: zh-Hant uses reference calorie and macro rows at 1.6x`
6. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: ru uses reference calorie and macro rows at 1.6x`
7. `test/epic8_weekly_report_golden_test.dart: weekly report macros_anchor evidence`
8. `test/epic8_weekly_report_golden_test.dart: weekly report exercise_anchor evidence`
9. `test/epic8_weekly_report_golden_test.dart: weekly report alltime_anchor evidence`
10. `test/epic8_weekly_report_golden_test.dart: weekly report macro tooltip evidence`
11. `test/features/onboarding/onboarding_visual_golden_test.dart: height and units photo keeps its focal measurement crop`
12. `test/premium_dashboard_benchmark_test.dart: tablet premium dashboard golden`
13. `test/premium_dashboard_benchmark_test.dart: desktop premium dashboard golden`

### Shard 6 من 8 — 1012 tests passed, 14 failed.

**[سجل المهمة #114082962028](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38007903223/job/114082962028)** — 14 حالة فاشلة:

1. `test/dashboard_polish/dashboard_polish_layout_review_test.dart: ar 390 at 1.6x retains all content and burned calories`
2. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: bn uses reference calorie and macro rows at 1.6x`
3. `test/dashboard_polish/dashboard_polish_layout_review_test.dart: ar 430 at 1.0x retains all content and burned calories`
4. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: vi uses reference calorie and macro rows at 1.6x`
5. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: th uses reference calorie and macro rows at 1.6x`
6. `test/epic8_weekly_report_golden_test.dart: weekly report phone RTL dark golden`
7. `test/epic8_weekly_report_golden_test.dart: weekly report evidence and limits golden`
8. `test/epic8_weekly_report_golden_test.dart: weekly report honest empty state golden`
9. `test/features/onboarding/onboarding_visual_golden_test.dart: Arabic plan on 320 wide phone at 200 percent`
10. `test/features/wellness/workout_reference_golden_test.dart: unconfigured routine library is visibly honest and offline`
11. `test/launch_readiness/navigation_and_more_master_closure_test.dart: More keeps routes, authority gates, RTL and sync boundaries`
12. `test/premium_dashboard_benchmark_test.dart: corrected light morning premium dashboard golden`
13. `test/semantic_icon_badge_spacing_test.dart: More secondary navigation rows stay icon-free in ltr`
14. `test/visual_closure/visual_defect_regression_test.dart: confirmed visual defects stay closed in production source`

### Shard 7 من 8 — 838 tests passed, 11 failed.

**[سجل المهمة #114082962007](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38007903223/job/114082962007)** — 11 حالة فاشلة:

1. `test/bil_semantic_icons_test.dart: major user-facing surfaces use the central badge contract`
2. `test/dashboard_polish/dashboard_polish_layout_review_test.dart: ar 430 at 1.6x retains all content and burned calories`
3. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: pl uses reference calorie and macro rows at 1.6x`
4. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: nl uses reference calorie and macro rows at 1.6x`
5. `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart: uk uses reference calorie and macro rows at 1.6x`
6. `test/epic8_weekly_report_golden_test.dart: weekly report nutrition production section golden`
7. `test/epic8_weekly_report_golden_test.dart: weekly report coverage production section golden`
8. `test/epic8_weekly_report_golden_test.dart: weekly report sources production section golden`
9. `test/features/nutrition/coach_food_commit_test.dart: four foods commit complete immutable evidence and replay after repository recreation`
10. `test/features/nutrition/coach_meal_commit_boundary_test.dart: Coach meal owner atomicity owner cancellation at every commit boundary either rolls back or reports a durable commit`
11. `test/features/onboarding/onboarding_visual_golden_test.dart: Arabic AI choices on 430 wide phone`

## خطة معالجة صارمة لهذا السجل

1. **أولوية سلامة البيانات:** حالات `coach_food_commit_test.dart` (4) و`coach_meal_commit_boundary_test.dart` (2) تحتاج إعادة إنتاج مركّزة وفحص atomics وowner/revision/closed-day؛ لا تغير اختبارات الذرّية لتُخفي فقد البيانات.
2. **الداشبورد والبيانات:** `dashboard_reference_nutrition_cards_test.dart` (25)، `dashboard_polish_layout_review_test.dart` (12)، `dashboard_unknown_nutrition_flow_test.dart` (4)، مع بقية اختبارات التصميم. أمثلة فعلية: العداد الجديد يعرض `640  cal / 2,100` بدل `640 / 2100`، و`1,460` بدل `1460`. ميّز تغيير صياغة مرئيًا معتمدًا من معلومة مغلوطة ولا تتنازل عن إظهار المجهول.
3. **صور خارج البوابة المركّزة:** `epic8_weekly_report_golden_test.dart` (13)، `onboarding_visual_golden_test.dart` (9)، `premium_dashboard_benchmark_test.dart` (4)، وGoldens الصحة/التمرين الأخرى. فحص master/actual/diff فرديًا وموافقة الصورة الأصلية، لا تحديث جماعي.
4. **العقود والعمارة:** فشل حجم الملف، الترجمة 25 لغة، خطة الجهاز/الساعة، عقد الاستحقاق المعتمد من الخادم، عدم الرموز خلف الصفوف، وواجهات Community، تحتاج إصلاح مصدر أو نقل اختبار متقادم فقط بعد دليل واضح.
5. بعد إصلاح كل مجموعة: اختبارات مركزة على SHA جديد → source Format/Analyze → الخمس Goldens → الثماني الشاملة كلها → Gate Flutter المجمّع. لا Cancel لاختبارات جارية بلا حاجة.

**لا يعتبر هذا التقرير أن 90 حالة صُلحت، ولا أن صور QA المحدثة تغطي المراجع الـ146 أو النسختين المرفوعتين للمتاجر.**
