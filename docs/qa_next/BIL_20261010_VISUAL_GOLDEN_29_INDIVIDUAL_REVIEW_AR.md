# BIL 2026 — تدقيق بصري فردي لـ29 لقطة Golden فاشلة، لا اعتماد تلقائي
**مصدر الأدلة:** [verify #38039168562](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38039168562) على `aca278eb6e...`، artifacts `golden-failures-shard-{0..7}`. **ليست لقطات أجهزة فعلية.**

## ما فُحص فعليًا
- نُزّلت أرشيفات PNG الثمانية من GitHub Actions، واستُخرجت لكل Golden ثلاث مجموعات evidence: `masterImage`, `testImage`, `maskedDiff / isolatedDiff` وفق المتاح.
- تمت مطابقة صور `masterImage` و`testImage` معًا بصريًا بواسطة Contact Sheets، مع قياس نسبة البكسلات المختلفة (RGB exact, 0 tolerance) بدقة على الأبعاد ذاتها.
- عدد الصور الفاشلة ذات الدليل الزوجي = **29 صورة**، موزعة: report-weekly 13، wellness 2، onboarding 9، dashboard 4، connected-health 1.
- **تنبيه منهجي:** الفرق البكسلي العالي لا يعني تلقائيًا تحوّلًا وظيفيًا كبيرًا: تلوين الخلفية بكامل الشاشة قد يغيّر أكثر من 90% من البكسلات رغم ثبات الأرقام والمحتوى.
- **قرار:** لا تُرقِّ أي baseline جماعيًا ولا تعِد الصور الجديدة production-ready. يجب التصديق الفردي على هوية BIL وأمان المحتوى وتجربة المستخدم وRTL. مراجعة الأمثلة وحدها لا تعطي موافقة آلية لجميع البنود.

## سجل كل صورة باسمها وفرقها الكامل
| المجال | اسم اللقطة | نسبة البكسلات المختلفة |
|---|---|---:|
| report-weekly | `epic8_weekly_report_nutrition_phone` | 99.85% |
| wellness | `recipe_library_polish_phone` | 98.45% |
| report-weekly | `epic8_weekly_report_empty_phone` | 96.86% |
| onboarding | `height_units_en_light_100` | 94.30% |
| report-weekly | `epic8_weekly_report_evidence_phone` | 93.58% |
| report-weekly | `epic8_weekly_report_sources_phone` | 93.58% |
| report-weekly | `epic8_weekly_report_coverage_phone` | 93.55% |
| report-weekly | `epic8_weekly_report_macro_tooltip` | 91.24% |
| wellness | `workout_library_offline_empty_phone` | 90.83% |
| report-weekly | `epic8_weekly_report_calories_anchor` | 90.59% |
| report-weekly | `epic8_weekly_report_macros_anchor` | 89.17% |
| report-weekly | `epic8_weekly_report_exercise_anchor` | 89.14% |
| report-weekly | `epic8_weekly_report_alltime_anchor` | 88.58% |
| onboarding | `female_hip_light_160` | 87.71% |
| onboarding | `ar_rtl_small_dark_160` | 87.56% |
| onboarding | `en_ltr_small_light` | 86.71% |
| onboarding | `permissions_light_160` | 85.61% |
| onboarding | `plan_320x568_ar_dark_200` | 85.59% |
| onboarding | `facts_320x568_en_light_200` | 85.27% |
| report-weekly | `epic8_weekly_report_frequent_anchor` | 84.73% |
| report-weekly | `epic8_weekly_report_phone_ltr_light` | 79.96% |
| report-weekly | `epic8_weekly_report_phone_rtl_dark` | 79.44% |
| onboarding | `ai_430x932_ar_light_100` | 78.38% |
| onboarding | `plan_dark_160` | 75.42% |
| dashboard | `premium_dashboard_light_corrected` | 33.45% |
| dashboard | `premium_dashboard_tablet_after` | 33.44% |
| dashboard | `premium_dashboard_desktop_after` | 13.63% |
| dashboard | `premium_dashboard_phone_after` | 13.13% |
| connected-health | `live_health_watch_compact_all_metrics` | 9.71% |

## تشخيص بصري أولي قابل للمراجعة
1. `epic8_weekly_report_*`: معظم الاختلافات خلفيات وأطُر بطاقات البنود بعد UX، مع إزاحة طفيفة للمقاطع. قارنت تفاصيل nutrition/sources/macros في اللقطات الأصلية والفعلية؛ المحتوى الأساسي حاضر، لكن **يجب إعادة اعتماد مقاييس التمرير والـsection semantics قبل تحديث Master**.
2. `onboarding_*`: اختلاف خلفية فاتحة/داكنة، مساحات الصورة والـpadding وأزرار متابعة. بعض صور `320px/200%` قد تتطلب فحص انقطاع المحتوى على جهاز حقيقي؛ لا يُغطّي هذا بمجرد تغيير baseline.
3. `premium_dashboard_*`: اختلاف مناطق Discover/الصور والمواءمة (13–33%) مع الحفاظ على الخمس وجهات. **Home/Dashboard محمي وفق موافقة المالك، فلا يُعدّل المصدر أو الصورة دون مراجعة خاصة**.
4. `live_health_watch_compact_all_metrics`: اختلاف 9.71% بصري في إطار الساعة المعدني بينما بيانات الساعة ضمن هيئة العرض الحالية. التغيير قد يكون مقصودًا، لكن نحتاج اعتماد تفاصيل الواجهة.
5. `recipe_library_polish_phone` و`workout_library_offline_empty_phone`: في المقارنة البصرية، المحتوى الأساسي لم يُحذف؛ اللون وخلفيات الصفحات تبدلوا. راجع بيانات التغذية الأصلية والأصول المرئية قبل أي اعتماد.

**التالي:** حالات Golden هذه جزء من مجموعة `broad-regressions` المعززة وليست من الخمس focused التقليدية. لا يُعد اختفاء فشل Golden بتحديث PNG وحده إثباتًا لاختبارات سلامة حسابية أو عرض فعلي على أجهزة iOS/Android.
