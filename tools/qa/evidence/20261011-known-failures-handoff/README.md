# BIL QA — إغلاق المعروف قبل Full، تسليم 11 أكتوبر 2026

**Full لم يبدأ. بقيت 29 Golden غير معتمدة وعيبا تطبيق مثبتان.**

أمر العمل: [تعليق QA الجديد](https://github.com/bilhealth-admin/Body-Intelligence/pull/11#issuecomment-6102424340).

## النسخة والنطاق

- SHA المختبر فعلًا: `908531cbcf344e4145e1fec8447fe61bd280c7e0`، على أصل QA `570919acb9086c6a3d910bebfffacd43e7255f98`.
- بصمة ladder قبل/بعد: `23967aa51e274ae0992b98591b915774fc981be9bcf62843344a17fedd31d542` / `23967aa51e274ae0992b98591b915774fc981be9bcf62843344a17fedd31d542`؛ متطابقتان.
- بصمة محتوى الكود والإعدادات: `de6918c327605d86613bc6fa591302f3a74b76a466d703b69ecaae07cde96da8`؛ [كل ملف](code-input-sha256.json).
- Flutter 3.44.6. worktree منفصل على G؛ المستودع الأصلي وعمل First Use المتسخ لم يُعدّلا.
- كوميت التسليم التالي يضيف الأدلة فقط؛ لا ننسب إليه تشغيلًا جديدًا. آخر SHA بعد رفع الأدلة مذكور في تعليق PR.
- لا تعديل lib أو Home أو Log Food أو الساعة أو خمس وجهات التنقل أو أي Golden Master/threshold. لا Merge أو Build متاجر أو workflow أو نشر.

## الإصلاحات والاختبارات الجديدة

1. أداة ladder: منع Full بأكثر من مجموعتين متزامنتين وإضافة `--concurrency=1` لكل shard. اختبارا جدولة ورفض مع التسعة السابقين: 11/11. استدعاءات Full في هذه الاختبارات mocks فقط؛ لم تُشغّل shards. بقيت بوابات المصدر والبصمة ورفض اختبارات Full قبل نجاح المراحل محفوظة.
2. اختبار منتج قبل فك صورة Vision: يمسك stream الأصلي pending دون صورة بديلة؛ تحذير hit-test قاتل. **فشل حقيقي**؛ لم نغير التطبيق أو نخفيه. الاختبار السابق بعد decode ما زال يمر ويثبت إغلاق التكبير.
3. اختبار رسالة Body Twin: قاعدة محلية فعلية ومحرك الإنتاج ومترجم الإنتاج؛ **فشل حقيقي** لأن النص يبقى إنجليزيًا في العربية. ليس مجرد استنتاج من debugPrint.
4. إصلاحات التنسيق، انتظار FileImage وعمليات PNG المتزامنة وخط الساعة المنجزة سابقًا محفوظة؛ لا إعادة تطبيق أو رجوع إلى SHA قديم.

## النتائج الحالية

التنسيق: 193 ملفًا، خمس دفعات PASS. التحليل الكامل: No issues found، 293.9 ثانية من Flutter (296.5 ثانية زمن التنفيذ).

| المجموعة المحلية | PASS | FAIL | SKIP | السجل |
|---|---:|---:|---:|---|
| affected-quantity | 9 | 1 | 0 | [log](logs/affected-quantity-1791668786491741800.log) |
| affected-runtime | 1 | 1 | 0 | [log](logs/affected-runtime-1791668802445608600.log) |
| broad-dashboard-nutrition | 85 | 0 | 0 | [log](logs/broad-dashboard-nutrition-1791668812302547500.log) |
| broad-dashboard-contract-health | 28 | 1 | 0 | [log](logs/broad-dashboard-contract-health-1791668848666232700.log) |
| broad-weekly-onboarding-goldens | 19 | 26 | 0 | [log](logs/broad-weekly-onboarding-goldens-1791668862034597000.log) |
| broad-settings-language-icons | 39 | 0 | 0 | [log](logs/broad-settings-language-icons-1791668889920439900.log) |
| broad-wellness-commerce | 9 | 2 | 0 | [log](logs/broad-wellness-commerce-1791668911082141700.log) |
| broad-community-cold-back | 46 | 0 | 0 | [log](logs/broad-community-cold-back-1791668924998795600.log) |
| affected-p0-food-owner-atomic | 32 | 0 | 0 | [log](logs/affected-p0-food-owner-atomic-1791668944030404800.log) |
| affected-p0-meal-owner-atomic | 16 | 0 | 0 | [log](logs/affected-p0-meal-owner-atomic-1791668952012870900.log) |
| affected-p0-architecture | 1 | 0 | 0 | [log](logs/affected-p0-architecture-1791668959844866500.log) |

الجولة المثبتة على هذه البصمة: **285 PASS /31 FAIL /0 SKIP من 316 حالة Flutter**. مع Python11/11: **296 PASS /31 FAIL /0 SKIP، إجمالي 327 حالة**. لا تدخل setup/teardown المخفية في العد.
كل ملف JSON انتهى بحدث `done` وexit متوافق؛ لا timeout أو إيقاف أو compile/resource failure. [تفصيل العد](suite-counts.json)، [كل الإخفاقات](failures.json).
محاولتا إثبات العيبين منفردًا قبل تثبيت SHA محفوظتان (1 FAIL لكل محاولة)؛ وفحص الأداة الأول 11/11 قبل تثبيت SHA. هذه محاولات تكرار لا حالات فريدة إضافية في الإجمالي المعتمد.
Broad الست: 226 PASS /29 FAIL /0 SKIP؛ كلها اختلافات Golden المعروفة. لم تُعلن Broad خضراء.
لم تُعد Arabic84 أو P0 كامل11 أو Focused5 في هذه الجولة؛ هذا ليس اعتمادًا جديدًا لها. اختُبرت المجموعات المتأثرة/الملفات القديمة اللازمة فقط لتوفير الوقت.

## سجل العوائق الوحيد

[المصفوفة الموحدة](blocker-matrix.json) تشمل كل29 صورة، كل24 ملفًا في سجل90 القديم، الأداة، العيبين، First Use، البوابات والأجهزة. [مصدر90 التاريخي](../../../../docs/qa_next/BIL_20261010_FULL_SHARDS_90_FAILURES_AR.md) على1133a0cc، وليس نتيجة Full الحالية. جميع ملفاته24 نُفذت الآن كاملة؛ الملفات غير Golden خضراء. لا نعلن إعادة Full أو نجاح أعداد8303 القديمة.

| ملف السجل القديم | FAIL القديم | PASS/FAIL/SKIP الآن | قرار |
|---|---:|---|---|
| `test/dashboard_polish/dashboard_reference_nutrition_cards_test.dart` | 25 | 50/0/0 | CURRENT FILE PASS |
| `test/epic8_weekly_report_golden_test.dart` | 13 | 13/13/0 | HOLD GOLDEN |
| `test/dashboard_polish/dashboard_polish_layout_review_test.dart` | 12 | 18/0/0 | CURRENT FILE PASS |
| `test/features/onboarding/onboarding_visual_golden_test.dart` | 9 | 0/9/0 | HOLD GOLDEN |
| `test/features/dashboard/composition/dashboard_unknown_nutrition_flow_test.dart` | 4 | 15/0/0 | CURRENT FILE PASS |
| `test/features/nutrition/coach_food_commit_test.dart` | 4 | 32/0/0 | CURRENT FILE PASS |
| `test/premium_dashboard_benchmark_test.dart` | 4 | 6/4/0 | HOLD GOLDEN |
| `test/features/nutrition/coach_meal_commit_boundary_test.dart` | 2 | 16/0/0 | CURRENT FILE PASS |
| `test/semantic_icon_badge_spacing_test.dart` | 2 | 10/0/0 | CURRENT FILE PASS |
| `test/architecture_source_file_size_guard_test.dart` | 1 | 1/0/0 | CURRENT FILE PASS |
| `test/bil_semantic_icons_test.dart` | 1 | 8/0/0 | CURRENT FILE PASS |
| `test/dashboard_composition_contract_test.dart` | 1 | 2/0/0 | CURRENT FILE PASS |
| `test/dashboard_epic_completion_contract_test.dart` | 1 | 1/0/0 | CURRENT FILE PASS |
| `test/dashboard_polish/dashboard_current_preview_test.dart` | 1 | 2/0/0 | CURRENT FILE PASS |
| `test/dashboard_polish/dashboard_live_health_hub_contract_test.dart` | 1 | 1/0/0 | CURRENT FILE PASS |
| `test/dashboard_polish/dashboard_p9_r15_final_visual_contract_test.dart` | 1 | 1/0/0 | CURRENT FILE PASS |
| `test/dashboard_polish/live_health_watch_layout_golden_test.dart` | 1 | 0/1/0 | HOLD GOLDEN |
| `test/dashboard_polish/live_health_watch_visibility_test.dart` | 1 | 23/0/0 | CURRENT FILE PASS |
| `test/features/commerce/verified_entitlement_surface_contract_test.dart` | 1 | 5/0/0 | CURRENT FILE PASS |
| `test/features/wellness/recipe_library_polish_test.dart` | 1 | 2/1/0 | HOLD GOLDEN |
| `test/features/wellness/workout_reference_golden_test.dart` | 1 | 2/1/0 | HOLD GOLDEN |
| `test/launch_readiness/navigation_and_more_master_closure_test.dart` | 1 | 3/0/0 | CURRENT FILE PASS |
| `test/localization/bil_25_locale_fallback_closure_test.dart` | 1 | 9/0/0 | CURRENT FILE PASS |
| `test/visual_closure/visual_defect_regression_test.dart` | 1 | 9/0/0 | CURRENT FILE PASS |

## مراجعة29 Golden فرديًا

راجعت master/actual/diff لكل صورة في ست لوحات مقارنة؛ صور Home الأربع فُحصت أيضًا بحجمها الكامل. خطوط AR/Latin الفعلية ظاهرة، ومرجع الساعة القديم يحتوي مربعات Ahem؛ الرسم المعدني الفضي الحالي محفوظ.
أُعيد إنتاج29 actual في Broad علىSHA المختبر، وكل29 **متطابقة بكسليًا وبايتًا** مع أدلة الجولة السابقة؛ كل29 Master لم يتغير. لذا الروابط أدناه تستعمل ملفات الأدلة السابقة التي تحققت بصمتها الآن، وليست صورًا تُقدّم بلا تحقق على كود جديد. [SHA والقرارات الفردية](golden-decisions.json).
المصنفات: 24 `OUTDATED GOLDEN` مرشحًا لانحراف تاريخي غير معتمد، 1 `TEST/HARNESS` لمرجع Ahem، 4 `NOT VERIFIED` لـHome المحمية. **التصنيف ليس موافقة أو حكمًا آليًا بأن كل تغيير المنتج صحيح.** لم يوجد تداخل مع145 صورة في manifest الترقية القديم؛ ولا يوجد إذن فردي لهذه29 في أمر QA الجديد.

| ID / الصورة | تصنيف / القرار | الملاحظة الفردية والدليل |
|---|---|---|
| G01 `ai_430x932_ar_light_100` | OUTDATED GOLDEN / HOLD RED | اختيارات AI العربية: الخلفية الخضراء الخفيفة أصبحت محايدة، وحواف الصفوف والأيقونات أخف؛ نفس الخيارات المختارة والصورة. نافذة الموافقة ليست داخل هذه اللقطة. [master/actual/diff](../20261010-main-qa-intake/goldens/01-ai_430x932_ar_light_100.html) |
| G02 `ar_rtl_small_dark_160` | OUTDATED GOLDEN / HOLD RED | Waist بالعربية 1.6x: سطح داكن محايد بدل الأخضر/الأسود، وحقل إدخال وحدود أكثر هدوءًا؛ نص التخطي والنطاق والصورة موجودة. [master/actual/diff](../20261010-main-qa-intake/goldens/02-ar_rtl_small_dark_160.html) |
| G03 `en_ltr_small_light` | OUTDATED GOLDEN / HOLD RED | Waist EN: F8F9FB بدل الخلفية الخضراء، وحقل/تنبيه بخط وحدود أخف؛ عنوان Optional والصورة وSkip/Continue محفوظة. [master/actual/diff](../20261010-main-qa-intake/goldens/03-en_ltr_small_light.html) |
| G04 `epic8_weekly_report_alltime_anchor` | OUTDATED GOLDEN / HOLD RED | All-time: Header والحدود الثقيلة صارت أهدأ؛ Member since=Unavailable، meals=0 وstreak=0days محفوظة. المرجع السابق outlined cards. [master/actual/diff](../20261010-main-qa-intake/goldens/04-epic8_weekly_report_alltime_anchor.html) |
| G05 `epic8_weekly_report_calories_anchor` | OUTDATED GOLDEN / HOLD RED | Calories anchor: بطاقة السعرات خلفيتها بيضاء وحدود أفتح والعناوين تغيرت؛ logged0kcal/nofoods وgoal غير متوفر محفوظة. [master/actual/diff](../20261010-main-qa-intake/goldens/05-epic8_weekly_report_calories_anchor.html) |
| G06 `epic8_weekly_report_coverage_phone` | OUTDATED GOLDEN / HOLD RED | Coverage: بطاقتا Proteins/Sweet snacks وصف feedback تغيّر خطهما وهوامشهما؛ counts=1 وWater4.7L/Weight92.8kg باقية. [master/actual/diff](../20261010-main-qa-intake/goldens/06-epic8_weekly_report_coverage_phone.html) |
| G07 `epic8_weekly_report_empty_phone` | OUTDATED GOLDEN / HOLD RED | Empty state: بطاقات Calories/Frequent foods أفتح، وأيقونة طبق فارغ تغير وزنها؛ nofoods/goal— محفوظان. [master/actual/diff](../20261010-main-qa-intake/goldens/07-epic8_weekly_report_empty_phone.html) |
| G08 `epic8_weekly_report_evidence_phone` | OUTDATED GOLDEN / HOLD RED | Evidence: حدود/خط بطاقات Proteins/Sweet snacks والfeedback تغيّرت؛ counts=1 و4.7L/92.8kg كما فيfixture. تغير scroll framing ناتج عن مقاييس النص. [master/actual/diff](../20261010-main-qa-intake/goldens/08-epic8_weekly_report_evidence_phone.html) |
| G09 `epic8_weekly_report_exercise_anchor` | OUTDATED GOLDEN / HOLD RED | Exercise: نفس noexercise/no steps وصف المصدر، وحدود وترويسة أهدأ ونصوص أصغر؛ All-time section موجود. [master/actual/diff](../20261010-main-qa-intake/goldens/09-epic8_weekly_report_exercise_anchor.html) |
| G10 `epic8_weekly_report_frequent_anchor` | OUTDATED GOLDEN / HOLD RED | Frequent foods: أيقونة الطبق تغيرت، وحدود Frequent/Advanced/Macros أهدأ؛ nofoods و0g محفوظة. [master/actual/diff](../20261010-main-qa-intake/goldens/10-epic8_weekly_report_frequent_anchor.html) |
| G11 `epic8_weekly_report_macro_tooltip` | OUTDATED GOLDEN / HOLD RED | Tooltip: نفس macronutrients/0g وNo macrodata، لكن سمك الحدود والخط وموقع tooltip مقارنة بسياق الصفحة تغير؛ يحتاج قرارtooltip فردي. [master/actual/diff](../20261010-main-qa-intake/goldens/11-epic8_weekly_report_macro_tooltip.html) |
| G12 `epic8_weekly_report_macros_anchor` | OUTDATED GOLDEN / HOLD RED | Macros: نفس 0g/no macrodata وخيارNutrition importer؛ حدود البطاقة/الترويسة ومسافة قسمExercise تغيرت. [master/actual/diff](../20261010-main-qa-intake/goldens/12-epic8_weekly_report_macros_anchor.html) |
| G13 `epic8_weekly_report_nutrition_phone` | OUTDATED GOLDEN / HOLD RED | Nutrition: نفس الخضار والفواكه والبروتين/Sweet snacks وcounts1؛ أسطح وحواف وخط/أيقونات جديدة منcalm scope. [master/actual/diff](../20261010-main-qa-intake/goldens/13-epic8_weekly_report_nutrition_phone.html) |
| G14 `epic8_weekly_report_phone_ltr_light` | OUTDATED GOLDEN / HOLD RED | LTR phone: Heroweek dates3/7 وFoodInsights نفسfixture؛ لونCanvas أبيض محايد، وخطAppBar أصغر وصورةhero/رموز أدق. [master/actual/diff](../20261010-main-qa-intake/goldens/14-epic8_weekly_report_phone_ltr_light.html) |
| G15 `epic8_weekly_report_phone_rtl_dark` | OUTDATED GOLDEN / HOLD RED | RTL dark: Week3/7 والتواريخ والعدد محفوظة؛ خلفيةداكنة محايدة وخط عربي/أيقونات أنحف منالمرجع. [master/actual/diff](../20261010-main-qa-intake/goldens/15-epic8_weekly_report_phone_rtl_dark.html) |
| G16 `epic8_weekly_report_sources_phone` | OUTDATED GOLDEN / HOLD RED | Sources: feedback و4.7L/92.8kg ثم3900kcal/14700goal محفوظة؛ framing والأحجام والحدود بعدcalm scope تغيرت. [master/actual/diff](../20261010-main-qa-intake/goldens/16-epic8_weekly_report_sources_phone.html) |
| G17 `facts_320x568_en_light_200` | OUTDATED GOLDEN / HOLD RED | Facts EN 320/2x: الخلفية والفونت والهوامش تغيرت؛ النص الطويل يمتد تحت viewport القابل للتمرير في المرجعين، والزر ثابت؛ ليس إثبات قص غير قابل للوصول. [master/actual/diff](../20261010-main-qa-intake/goldens/17-facts_320x568_en_light_200.html) |
| G18 `female_hip_light_160` | OUTDATED GOLDEN / HOLD RED | Hip 1.6x: سطح محايد وحقل أفتح وأيقونات أدق، مع الصورة والعنوان وخيارات التنقل نفسها؛ footer والتمرير يحتاجان تحقق جهاز. [master/actual/diff](../20261010-main-qa-intake/goldens/18-female_hip_light_160.html) |
| G19 `height_units_en_light_100` | OUTDATED GOLDEN / HOLD RED | Height EN: الحقل والسطح أخف، وصورة القياس نفسها مع recrop مختلف قليلًا؛ 170 cm والنطاق120–250 باقيان، يلزم اعتماد crop فردي. [master/actual/diff](../20261010-main-qa-intake/goldens/19-height_units_en_light_100.html) |
| G20 `live_health_watch_compact_all_metrics` | TEST/HARNESS / HOLD RED | المرجع واللقطة التاريخية كاناAhem (مربعات بدل14:22 وقراءات). الاختبارلايحمّل وجهًا صريحًا. بعدإصلاحtest يظهر14:22:08 و2198/80/300/4.8. يبقىفرقهيكلالساعةبالإضافةللخط؛ لايصلحمرجعAhem للقبولالتلقائي. [master/actual/diff](../20261010-main-qa-intake/goldens/20-live_health_watch_compact_all_metrics.html) |
| G21 `permissions_light_160` | OUTDATED GOLDEN / HOLD RED | Permissions Android: نفس Health Connect وNot requested؛ إطار البطاقة والسطح والأيقونة والهوامش تغيرت، لا وصول لشبكة/صلاحية فعلية. [master/actual/diff](../20261010-main-qa-intake/goldens/21-permissions_light_160.html) |
| G22 `plan_320x568_ar_dark_200` | OUTDATED GOLDEN / HOLD RED | Plan AR 320/2x: نفس عنوان خطة البداية وصورة الاختبار، مع سطح وخط محايدين؛ المحتوى تحت viewport قابل للتمرير ولا يمثل وحده خللًا. [master/actual/diff](../20261010-main-qa-intake/goldens/22-plan_320x568_ar_dark_200.html) |
| G23 `plan_dark_160` | OUTDATED GOLDEN / HOLD RED | Plan EN 1.6x: نفس1808kcal و126g في خطة الاختبار؛ خلفية/حدود وخط البطاقة تغيرت. يلزم مراجعة الصورة كاملة قبل أي اعتماد. [master/actual/diff](../20261010-main-qa-intake/goldens/23-plan_dark_160.html) |
| G24 `premium_dashboard_desktop_after` | NOT VERIFIED / HOLD RED | Desktop1440: وحدةcal والعرض الموثق للشريط/صفوفFood-Water-Weight وأبعادDiscover تغيّرت تاريخيًا؛ لاAhem. هذهHome محمية ويجب تأكيد اعتماد التغييرات السابقة فرديًا. [master/actual/diff](../20261010-main-qa-intake/goldens/24-premium_dashboard_desktop_after.html) |
| G25 `premium_dashboard_light_corrected` | NOT VERIFIED / HOLD RED | Light1024: نفس 0 واختبارالبيانات الفارغة؛ صفالقيم والWeight وأزرارFood-Water-Weight وDiscover تحركت مع مصدرالبطاقة الأحدث؛ ليستزيادة2px وحدها. [master/actual/diff](../20261010-main-qa-intake/goldens/25-premium_dashboard_light_corrected.html) |
| G26 `premium_dashboard_phone_after` | NOT VERIFIED / HOLD RED | Phone390: 0cal/— بدل0/— وrowheight/food-water-weight تبدلت مقارنةبمرجع5f026c؛ تغييراتأقدم منإصلاحHome2px، لا موافقةضمنية عليها. [master/actual/diff](../20261010-main-qa-intake/goldens/26-premium_dashboard_phone_after.html) |
| G27 `premium_dashboard_tablet_after` | NOT VERIFIED / HOLD RED | Tablet1024: تغيّر صفالسعرات ووحدته ومسافاتWeight/Actions وDiscover، والقيم الأساسية باقية؛ يحتاجقرارHome محمي فردي. [master/actual/diff](../20261010-main-qa-intake/goldens/27-premium_dashboard_tablet_after.html) |
| G28 `recipe_library_polish_phone` | OUTDATED GOLDEN / HOLD RED | Recipes: صورةShakshuka ومقادير225kcal/15.4g و25min/2 servings محفوظة؛ CalmCanvas وSearch/Chips/Card وحدودها تغيرت. [master/actual/diff](../20261010-main-qa-intake/goldens/28-recipe_library_polish_phone.html) |
| G29 `workout_library_offline_empty_phone` | OUTDATED GOLDEN / HOLD RED | Workouts offline: tabs وأمانoffline والجمهور وكارتCardio محفوظة؛ الخطوط/أيقوناتالتبويب وحوافSearch/Card تغييرcalm scope، لا تحميلفيديوحي. [master/actual/diff](../20261010-main-qa-intake/goldens/29-workout_library_offline_empty_phone.html) |

## عيبا التطبيق المطلوب إصلاحهما لدى QA الرئيسي

**P01 — زر إغلاق الصورة قبل decode:** `lib/features/nutrition/presentation/meal_vision_premium_portion.dart:18-32`. Dialog/Stack يعتمد على امتداد Image.file؛ عند stream pending يقع مركز زر الإغلاق311/446 في الحاجز. [الفشل المنفرد](logs/zoom-pending-regression.jsonl)، والفشل المعاد في مجموعة quantity. الإصلاح المقترح: bounds واضحة مع حالات loading/error تبقي close داخل hit region منذ أولframe، دون استبدال الطعام أو الصورة.

**P02 — الرسالة الديناميكية العربية:** منتج النص `lib/features/ai_platform/services/local_intelligence_reality_runtime.dart:332`؛ المترجم `lib/app/localization/app_localizations.dart:184,272` يعود بالإنجليزية. مستهلك الصفحة `lib/features/dashboard/widgets/dashboard_grid.dart:372`. [الفشل المنفرد](logs/body-twin-arabic-regression.jsonl). المقترح: قالب ترجمة مراجع مع placeholder للوزن؛ لا hardcode للـ87 فقط. الاختبار يثبت نقص ترجمة الرسالة، ولا يدّعي تصوير كل حالة ظهورها على Home.

[صورة Flutter الجديدة](vision-final-80g-76kcal.png) تُظهر76.0 kcal في مراجعة مقدار0.08kg=80g؛ مصدر الغذاء TEST معلّم. الاختبار النهائي بعدdecode يؤكد مسار FileImage الأصلي وإغلاق zoom والقيم المرسلة لكل مدخلي السجل.
[لقطة انتظار الصورة](vision-underlying-review-while-decode-pending.png) تخص سطح المراجعة الأساسي فقط؛ capture boundary لا يشمل overlay التكبير، **فليست دليلًا بصريًا للزر داخل modal**. دليل الخطأ هو اختبار hit-test القاتل وسجله.

## First Use والأجهزة والخطوة التالية

العمل المحلي عند`G:/BIL_Project/worktrees/bil-test-only-20261010` بقي عند944973ed وبصمات ملفاته10 مطابقة للmanifest السابق. [فحص المحافظة](first-use-preservation-before.json). نتائج175 السابقة تخص العمل المحلي غير المدموج فقط؛ لا تُحسب ضمن QA الحالي. يلزم جمعه ومراجعته لدى المحادثة الرئيسية، أو قرار صريح باستبعاده واعتبار Full تشخيصيًا. عيبا controller/Overflow المحليان الموثقان ضمن تلك الرحلة ليسا إصلاحين مدموجين في هذا الفرع.
لم تختبر هذه الجولة أجهزة فعلية أو كاميرا/معرض حقيقيين أو lifecycle أو قراءة شاشة أو AI/backend حي أو نسخة متجر. لم تُغيّر أي بيانات Production أو اشتراكات.
على QA الرئيسي إصلاح P01/P02 واتخاذ قرار كلGolden على حدة وجمع First Use، ثم فحص البوابات اللازمة على SHA وبصمة نهائيين. بعد ذلك فقط Full واحد بثماني shards في طابور، مجموعتان متزامنتان وعامل1 لكلshard، مع إعادة فحص RAM وعزل الأدلة. **لا Full الآن.**
بعد رفع هذا التسليم توقف العمل؛ لا إعادة دورة أو تطوير إضافي.
