# BIL 2026 — استلام إصلاح QA الرئيسي واختباراته

HEAD الاستلام: `e5ba6e1677f92b7fe12c92ef84c95858e524d833`. نسخة الاختبارات النهائية: `bd4a95b12bef111ecfef8c0f279f9a29e8b2e83f`. بصمة الكود والعمل: `cecd8d525137ee56e4c613ba236d64d23bd75f7c3c7973198e0ffe3a10a297f8`. الفرع الوحيد `qa/bil-quality-ux-integration-20261009`، Flutter 3.44.6 / Dart 3.12.2. الكوميت اللاحق يضيف أدلة فقط؛ lib مطابق تمامًا لـHEAD الاستلام.

قُرئت التعليمات كاملة من PR #11 / [6101270283](https://github.com/bilhealth-admin/Body-Intelligence/pull/11#issuecomment-6101270283)، ومراجعة [6101211654](https://github.com/bilhealth-admin/Body-Intelligence/pull/11#issuecomment-6101211654). أُجري fast-forward دون rollback أو فقد إصلاح سابق. بقيت ملفات failures التشخيصية المتسخة محفوظة خارج commit. لم يُمس المستودع الأصلي المتسخ أو التطبيق أو Production أو الاشتراكات أو Trial أو المتاجر، ولم يحدث دمج PR أو نشر أو workflow dispatch.

## الإصلاحات المحلية: ثلاثة ملفات اختبار فقط

1. `test/dashboard_polish/dashboard_polish_layout_review_test.dart`: إصلاح تنسيق فقط؛ فشل الفحص الأول في هذا الملف وحده. بقيت الحالات الـ18 وفحص أسفل تنبيه الحرق و`takeException` كما استلمت.
2. `test/features/nutrition/meal_vision_final_portion_test.dart`: انتظار فك FileImage الفعلي في الصورة الأصلية والتكبير، بمهلة محدودة وفشل صريح إذا لم يفك؛ جعل missed tap قاتلًا، والإبقاء على assertion اختفاء InteractiveViewer. نقل فحص وجود/حجم PNG إلى existsSync/lengthSync لأن await File I/O داخل FakeAsync علّق الاختبار. إعادة رسم retained layers التي أضافها QA في fixture محفوظة بلا تغيير.
3. `test/dashboard_polish/live_health_watch_layout_golden_test.dart`: تحميل الخطوط الحقيقية وربط Theme/DefaultTextStyle بوجه RobotoEvidence. مجرد تحميل الوجه لم يعالج fallback النص؛ اللقطة الأولى ظلت مربعات، فأُصلح اختيار الوجه صراحة. **المقارنة ما زالت RED** ولم يتغير golden أو threshold.

## نتائج Home وVision

بدأت بالحالة المنفردة EN/320/1x: PASS واحد. ثم الملف كله: 18/18 PASS (EN/AR ×320/390/430 ×1/1.6/2). حالات 2x الست خضراء. على النسخة النهائية أعيد الملف 18/18، وأصبحت Broad-dashboard-nutrition **85 PASS /0 FAIL**؛ هذا يغلق حالات Home الأربع الأصلية، ومنها current production preview EN. لم يُخف استثناء أو تُقلّص الحروف أو البطاقة.

اختبار كمية Vision: **3/3 PASS** على النسخة النهائية. من حصة100g/95kcal، إدخال «٠٫٠٨ kg» يعرض **76.0kcal** ويعيد80g وservingFactor0.8. فتحت [PNG النهائية](vision-final-80g-76kcal.png) وتحققت من76.0 بصريًا بعد التشغيل النهائي، وليس من find.text وحده. زر إغلاق الصورة يصيب الهدف بعد فك الصورة؛ missed-tap قاتل، وInteractiveViewer يختفي. الصور والبيانات TEST من الملف نفسه، ليست AI حيًا أو صورة مستخدم.

لقطتا [Home EN](home-burn-en-390.png) و[AR matrix](home-burn-ar-390.png) تظهران تنبيه الحرق داخل البطاقة. في لقطة AR matrix بقي fallback Ahem في زر «اليوم» وحده؛ ليست إثبات جودة الخط الكامل. أُرفقت أيضًا [preview AR بخط capture fixture الصريح](home-current-full-ar.png) و[EN](home-current-full-en.png)، باستخدام fixture موجودة تصحح وجه «اليوم» في RenderParagraph للتصوير فقط؛ لم يتغير lib. هذه fixture مختلفة (قيم الاختبار مختلفة)، وليست بديلًا عن مقارنة تصميم أو جهاز. سجل تصوير matrix: 2/2؛ preview: 2/2، في [logs](logs/).

## التحقق النهائي المربوط بالبصمة

Source: تنسيق192 ملف، بلا تغييرات مطلوبة، تحليل كامل No issues found. العربية/Vision: 84 PASS. العقود المتأثرة: Home18 وVision3 PASS. أُعيدت مجموعات Broad الأربع المتأثرة/الحمراء تاريخيًا فقط، تطبيقًا لخطة QA الاقتصادية. الأعداد التالية من السجلات الفعلية وليست نتائج قديمة منقولة:

| المجموعة | ناجح | فاشل | السجل |
|---|---:|---:|---|
| arabic-noto-capture | 2 | 0 | [log](logs/arabic-noto-capture-1791661446790764000.log) |
| arabic-vision-v2 | 82 | 0 | [log](logs/arabic-vision-v2-1791661470435159400.log) |
| affected-contracts-home-card-all | 18 | 0 | [log](logs/affected-contracts-home-card-all-1791661503998836700.log) |
| affected-contracts-vision-final-portion | 3 | 0 | [log](logs/affected-contracts-vision-final-portion-1791661515320398700.log) |
| broad-dashboard-nutrition | 85 | 0 | [log](logs/broad-dashboard-nutrition-1791661524765816800.log) |
| broad-dashboard-contract-health | 28 | 1 | [log](logs/broad-dashboard-contract-health-1791661540791804700.log) |
| broad-weekly-onboarding-goldens | 19 | 26 | [log](logs/broad-weekly-onboarding-goldens-1791661551401918800.log) |
| broad-wellness-commerce | 9 | 2 | [log](logs/broad-wellness-commerce-1791661569379131000.log) |

المجموعات الأربع Broad: **141 PASS /29 FAIL**؛ مجموعة Home خضراء وثلاث مجموعات حمراء. لم أكرر P0 الإحدى عشرة أو Focused الخمس؛ العقود المتأثرة أُعيدت منفردة. مجموعتا Broad settings/community لم تُعيدا لأن مصدرهما لم يتغير وكانتا خضراوين سابقًا؛ لا أدعي اعتمادهما على SHA الجديد. **Full: جميع8 shards متخطاة**، لأن29Golden باقية حمراء ولأن مجموعة المتطلبات الكاملة ليست خضراء على البصمة النهائية. لا cache مصطنع ولا نقل PASS عبر SHA.

[manifest](manifest.json) و[أعداد النتائج](suite-counts.json) و[البرنامج المحدد باستخدام bil_codex_test_ladder.py](scoped-runner.txt) يوضحان ما شُغّل وما تُرك. Source النهائي استغرق وقتًا أطول لكنه انتهى فعليًا؛ لا اعتبار للانتظار نجاحًا.

## التصنيف الفردي لـ29Golden

[مراجعة الصور الفردية الـ29](golden-review.html) و[JSON بكل مسار/كوميت مرجع/بصمة/ملاحظة/قرار](golden-classification.json). لكل حالة master/test/maskedDiff/isolatedDiff الأصلية وروابط منفصلة. فُحص إعداد الفونت والfixture وتاريخ المرجع. طابقت كل master مع baseline المحفوظ في Git؛ جميع baseline hashes سليمة ولم يُعدل واحد.

التصنيف المقترح: **A=1** مرجع/اختبار Ahem للساعة، **B=28** مراجع أقدم مقابل مصدر تغيّر عمدًا (BilCalmVisualScope أو بطاقات Dashboard السابقة). لا C مثبت من مقارنات Golden وحدها. هذه قرارات مقترحة لا اعتماد بصري؛ كل مقارنة تبقى RED. الصور الـ28 الحالية متطابقة بكسليًا مع actual المحاولة السابقة عند8cd07c20/b3fa، فتلك الفروق ليست ناتجة عن إصلاح Home2px الجديد. الساعة وحدها تغيرت بعد إصلاح فونت الاختبار، وتعرض14:22:08 و2198/80/300/4.8 بدل المربعات؛ فرقها22.44%/10860px، لا تطابق مفترض مع مرجع غير صالح.

| # | المرجع | التصنيف | المراجعة والقرار |
|---:|---|---|---|
| 1 | `ai_430x932_ar_light_100` | B | [master/test/diff والسبب](goldens/01-ai_430x932_ar_light_100.html) — HOLD / اعتماد QA فردي |
| 2 | `ar_rtl_small_dark_160` | B | [master/test/diff والسبب](goldens/02-ar_rtl_small_dark_160.html) — HOLD / اعتماد QA فردي |
| 3 | `en_ltr_small_light` | B | [master/test/diff والسبب](goldens/03-en_ltr_small_light.html) — HOLD / اعتماد QA فردي |
| 4 | `epic8_weekly_report_alltime_anchor` | B | [master/test/diff والسبب](goldens/04-epic8_weekly_report_alltime_anchor.html) — HOLD / اعتماد QA فردي |
| 5 | `epic8_weekly_report_calories_anchor` | B | [master/test/diff والسبب](goldens/05-epic8_weekly_report_calories_anchor.html) — HOLD / اعتماد QA فردي |
| 6 | `epic8_weekly_report_coverage_phone` | B | [master/test/diff والسبب](goldens/06-epic8_weekly_report_coverage_phone.html) — HOLD / اعتماد QA فردي |
| 7 | `epic8_weekly_report_empty_phone` | B | [master/test/diff والسبب](goldens/07-epic8_weekly_report_empty_phone.html) — HOLD / اعتماد QA فردي |
| 8 | `epic8_weekly_report_evidence_phone` | B | [master/test/diff والسبب](goldens/08-epic8_weekly_report_evidence_phone.html) — HOLD / اعتماد QA فردي |
| 9 | `epic8_weekly_report_exercise_anchor` | B | [master/test/diff والسبب](goldens/09-epic8_weekly_report_exercise_anchor.html) — HOLD / اعتماد QA فردي |
| 10 | `epic8_weekly_report_frequent_anchor` | B | [master/test/diff والسبب](goldens/10-epic8_weekly_report_frequent_anchor.html) — HOLD / اعتماد QA فردي |
| 11 | `epic8_weekly_report_macro_tooltip` | B | [master/test/diff والسبب](goldens/11-epic8_weekly_report_macro_tooltip.html) — HOLD / اعتماد QA فردي |
| 12 | `epic8_weekly_report_macros_anchor` | B | [master/test/diff والسبب](goldens/12-epic8_weekly_report_macros_anchor.html) — HOLD / اعتماد QA فردي |
| 13 | `epic8_weekly_report_nutrition_phone` | B | [master/test/diff والسبب](goldens/13-epic8_weekly_report_nutrition_phone.html) — HOLD / اعتماد QA فردي |
| 14 | `epic8_weekly_report_phone_ltr_light` | B | [master/test/diff والسبب](goldens/14-epic8_weekly_report_phone_ltr_light.html) — HOLD / اعتماد QA فردي |
| 15 | `epic8_weekly_report_phone_rtl_dark` | B | [master/test/diff والسبب](goldens/15-epic8_weekly_report_phone_rtl_dark.html) — HOLD / اعتماد QA فردي |
| 16 | `epic8_weekly_report_sources_phone` | B | [master/test/diff والسبب](goldens/16-epic8_weekly_report_sources_phone.html) — HOLD / اعتماد QA فردي |
| 17 | `facts_320x568_en_light_200` | B | [master/test/diff والسبب](goldens/17-facts_320x568_en_light_200.html) — HOLD / اعتماد QA فردي |
| 18 | `female_hip_light_160` | B | [master/test/diff والسبب](goldens/18-female_hip_light_160.html) — HOLD / اعتماد QA فردي |
| 19 | `height_units_en_light_100` | B | [master/test/diff والسبب](goldens/19-height_units_en_light_100.html) — HOLD / اعتماد QA فردي |
| 20 | `live_health_watch_compact_all_metrics` | A | [master/test/diff والسبب](goldens/20-live_health_watch_compact_all_metrics.html) — HOLD / اعتماد QA فردي |
| 21 | `permissions_light_160` | B | [master/test/diff والسبب](goldens/21-permissions_light_160.html) — HOLD / اعتماد QA فردي |
| 22 | `plan_320x568_ar_dark_200` | B | [master/test/diff والسبب](goldens/22-plan_320x568_ar_dark_200.html) — HOLD / اعتماد QA فردي |
| 23 | `plan_dark_160` | B | [master/test/diff والسبب](goldens/23-plan_dark_160.html) — HOLD / اعتماد QA فردي |
| 24 | `premium_dashboard_desktop_after` | B | [master/test/diff والسبب](goldens/24-premium_dashboard_desktop_after.html) — HOLD / اعتماد QA فردي |
| 25 | `premium_dashboard_light_corrected` | B | [master/test/diff والسبب](goldens/25-premium_dashboard_light_corrected.html) — HOLD / اعتماد QA فردي |
| 26 | `premium_dashboard_phone_after` | B | [master/test/diff والسبب](goldens/26-premium_dashboard_phone_after.html) — HOLD / اعتماد QA فردي |
| 27 | `premium_dashboard_tablet_after` | B | [master/test/diff والسبب](goldens/27-premium_dashboard_tablet_after.html) — HOLD / اعتماد QA فردي |
| 28 | `recipe_library_polish_phone` | B | [master/test/diff والسبب](goldens/28-recipe_library_polish_phone.html) — HOLD / اعتماد QA فردي |
| 29 | `workout_library_offline_empty_phone` | B | [master/test/diff والسبب](goldens/29-workout_library_offline_empty_phone.html) — HOLD / اعتماد QA فردي |

Weekly عدد13 وOnboarding عدد9 وDashboard benchmark عدد4 =26، إضافة watch1 وRecipes/Workouts2. صفحات Weekly/Onboarding/Recipes/Workouts تستخدم الآن BilCalmVisualScope؛ مصدر لونها/حدودها/typography مذكور لكل حالة. مراجع Dashboard الأربع تخضع لحماية Home؛ اختلافاتها التاريخية في وحدات/صفوف/بطاقات Home لا تُعتمد ضمن إذن2px، ويجب أن يؤكد QA أنها تغييرات مقصودة أو يعيد تصنيفها C. لا تحديث مرجع دون اعتماد الحالة نفسها.

## الإخفاقات الأصلية وأدلتها

- [format.log](logs/format.log): ملف Home test غير منسق، ثم [format-retry.log](logs/format-retry.log) PASS. لم يُعدل المصدر الإنتاجي.
- [vision-original.log](logs/vision-original.log): missed tap على tooltip، ثم تعليق File.exists/length داخل FakeAsync. أوقفت flutter_tester الخاص بهذه المحاولة فقط بعد التحقق من PID ومساره؛ هذا **run interrupted/غير مكتمل** وليس PASS. النقر قبل فك الصورة يمكن أن يصيب barrier ويدفع الاختبار للاعتقاد أن الزر أغلقها؛ لذلك بقي التحذير قاتلًا في الإصلاح النهائي.
- [vision-decoded-retry.log](logs/vision-decoded-retry.log): أول retry تداخل مع الاختبار العالق وواجه Windows file-copy lock/errno183 في fixture. بعد إنهاء العملية العالقة وإعادة الفحص منفردًا نجح [retry2](logs/vision-decoded-retry-2.log) ثم التحقق النهائي. لا تعديل لملف الطعام أو مصدر الحفظ.
- [watch-real-font.log](logs/watch-real-font.log): تسجيل الوجه وحده أبقى النص مربعات؛ [watch-real-font-retry.log](logs/watch-real-font-retry.log) يثبت RED22.44% بعد ربط الوجه صراحة. كلا الإخفاقين محفوظان، إضافة [لقطة الساعة قبل الإصلاح](watch-before-font-repair.png).

## ما يحتاج المحادثة الرئيسية

1. اعتماد بصري فردي أو رفض لكل فرق Golden أعلاه؛ لا baseline جديد في هذا التسليم. خاصة Home benchmark الأربع، المحمية خارج2px.
2. **حافة تحميل الصورة تستحق تدقيق المصدر، وليست عيبًا مثبتًا على جهاز:** في المحاولة الأصلية قبل فك الصورة كان مركز tooltip خارج hit-test الزر. استنتاج المصدر المحتمل: `lib/features/nutrition/presentation/meal_vision_premium_portion.dart:18-32` يجعل Dialog/Stack يعتمد على حجم Image.file دون حدود دنيا، ويمكن أن يتقلص حين لم تفك الصورة بعد. الاقتراح للمحادثة الرئيسية: حدود عرض/ارتفاع واضحة تبقي زر الإغلاق داخل hit region من أول frame، مع حالة تحميل/خطأ. الاختبار النهائي يثبت إغلاق الصورة المفكوكة فقط؛ لم أغير lib أو أخف سجل النقر المبكر.
3. سجل preview AR يحتوي **Missing reviewed runtime translation** لعبارة Body Twin trusted baseline ذات87.0kg. منتج النص `lib/features/ai_platform/services/local_intelligence_reality_runtime.dart:332`. الاقتراح: localization/template مع placeholder ثابت للوزن بدل النص الإنجليزي الديناميكي. هذه ملاحظة سجل وليست assertion فاشلة أو إثبات ظهور النص بالإنجليزية في كل حالة؛ لقطة الصفحة لا تثبت ترجمة رسالة قبول baseline.

## المتخطى وغير المثبت

لا أجهزة فعلية، Camera/Gallery/permissions/lifecycle لملف الصورة، إغلاق أثناء decode بطيء أو file-error على جهاز، AI حي/مدفوع، حفظ شبكة/حسابات حقيقية، backend/Production، signed builds أو iOS Simulator أو Android builds أو TestFlight أو متجر/نشر/دمج. صور Flutter دليل محلي مع وجبات TEST وخطوط evidence، وليست تطابقًا بكسليًا مع هاتف حقيقي. P0/Focused الكاملتان ومجموعتا Broad غير المتأثرتين غير معادتين؛ Full8 غير مشغلة. بعد رفع هذا التسليم وإرساله على PR #11 أتوقف دون دورة أو تطوير جديد.
