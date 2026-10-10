# BIL Vision — المرجع الجديد وأدلة Flutter المحلية

تاريخ التسليم: 2026-10-10. Flutter **3.44.6** / Dart **3.12.2**، Windows، تشغيل متسلسل.

آخر SHA للكود والاختبارات المختبرة: `b60f4c1710243202187763b30ce444065573bdc6`.
بصمة برنامج التدرج أثناء الاختبار: `cafa4f4cad9bc63fff0b5c3bf862686d02ff24fef4de44085366706c80378a80`.
أي commit لاحق يضيف هذه الأدلة فقط؛ لا تنسب له بوابات جديدة أو Full ناجحًا.

بدأت المهمة tests/tools فقط عند `38a97987bc96cb90ba2e17595cb9295081365676`. بعد طلب المستخدم الصريح «ممكن تخليها مطابقه لهاي بالضبط؟» مع Photo 1.jpg، اتسع النطاق إلى واجهة Vision فقط. تغيرت خمسة ملفات عرض Vision؛ بقي Home وLog Food والشريط السفلي وواجهات الحفظ والخدمات والاشتراكات وTrial ونسخ المتاجر محفوظة. لم يحدث Merge أو Force Push أو Deployment أو تشغيل CI مقصود؛ commits تحمل `[skip ci]`.

## النتيجة المثبتة

| المرحلة | المجموعات | ناجح | فاشل | الحالة |
|---|---:|---:|---:|---|
| Source | 189 ملف تنسيق + تحليل كامل | 189 / تحليل بلا ملاحظات | 0 | GREEN |
| Arabic/Vision | 2 | 84 | 0 | GREEN؛ منها مصفوفة 72 حالة |
| P0 | 11 | 199 | 0 | GREEN |
| Focused | 5 | 272 | 0 | GREEN |
| Broad | 6 | 216 | 33 | RED؛ 2 مجموعات خضراء و4 حمراء |
| Full | 8 shards | 0 | 0 | جميعها SKIPPED؛ لم تُستدعَ بسبب Broad |

الأعداد هي تنفيذات حالات داخل المجموعات، وليست نسبة تغطية أو اختبارات فريدة عبر المراحل. حارس أداة التدرج: **9/9** unit tests ناجحة، بما فيها رفض تجاوز البوابات وتغيّر البصمة، وإلزام صور/مصفوفة Vision قبل P0.

## الصور والمقارنة

هذه PNGs من `RenderRepaintBoundary.toImage` في Flutter، وليست صور جهاز أو لقطات قديمة. [المقارنة](comparison.html) تجمع المرجع المرفوع كما هو والصور الجديدة، ويمكن تنزيل المجلد لعرض HTML.

| الصورة | الإثبات |
|---|---|
| [المراجعة](01_review.png) | صورة TEST الأصلية، الثقة، الزجاج، بطاقات الوجبة/11:30/الكمية، زر التحرير |
| [قبل المطابقة](02_unmatched.png) | لا سعرات أو مغذيات مختلقة؛ غير متوفر حتى اختيار مصدر موثوق |
| [الملخص السريع](03_quick.png) | بيانات سجل TEST موثوق؛ 60g من حصة مصدر مقدارها 60g |
| [التحليل الكامل](04_full.png) | القيم والمعادن والسكر/الصوديوم/الحديد/فيتامين C غير المتوفرة |
| [320 و2×](05_320_2x.png) | شبكة تتكيف مع التكبير، بلا قصّ غير متوفر |
| [الصورة في التكبير](06_original_photo_zoom.png) | الملف نفسه في InteractiveViewer؛ لا صورة بديلة |

صورة الوجبة هي نسخة byte-for-byte من `assets/images/professional/recipes/ful-medames-tahini.png` إلى مسار TEST، وتظهر صفة العينة صراحة. SHA-256: `52543fb18f3bab226211e8bfcee5d630067db9e4a949661fafb157339cbb5512`.
المرجع هو Photo 1.jpg المقدم في الرسالة الأخيرة، SHA-256: `e45419c3a0f5a3b08a54b31c35f75e9a1fc67ea1f52e2b80a814a9d51b8c0981`. لم يتوفر الأرشيف الأصلي BIL_Vision_Premium_Review_20261010.zip؛ لم ننسب إليه هذه المقارنة.

صور/بيانات TEST ليست صورة مستخدم حقيقية أو نتيجة AI أو قيمة مخبرية. قيمة 95 في صورة المرجع الجديدة تأتي من سجل TEST ذي أساس 60g وحصة مراجعة 60g. مصفوفة الحسابات المستقلة تستخدم مصدرًا لكل 100g وتثبت 80g = 76 kcal، 4.1g بروتين، 9.5g كربوهيدرات، 2.7g دهون، 2.8g ألياف، 6.7g صافي كربوهيدرات.

**المطابقة ليست معتمدة 100%.** الصورة والبيانات fixture، وخطوط الأدلة Noto Arabic وRoboto الحقيقية تختلف عن خطوط النظام في الأجهزة. لا توجد صورة مصغرة أصلية أو كمية قابلة للتعديل في شاشة المطابقة كما في الهاتف الثاني؛ واجهة المطابقة الحالية ترجع `Food` فقط، بينما الكمية والصورة بيد مستدعي Log Food. يلزم عقد واضح لتمرير الصورة ونتيجة الكمية والوحدة الجديدة عبر `daily_log_capture_actions.dart:373` و`food_log_actions.dart:416`؛ هذان الملفان محميان بتعليمات المستخدم ولم نغيرهما أو ننشئ cache عام للصورة. تحرير الكمية الحالي في مرحلة مراجعة Vision يعمل ويُختبر. قبول Visual parity يحتاج QA الرئيسي وإذنًا صريحًا لهذا الربط ثم أجهزة فعلية.

## الإخفاقات الأصلية والإصلاحات

- خمسة ملفات V2 غير منسقة في البداية؛ أصلح الاختبار أولًا وحده ضمن test-only. بعد طلب تعديل الواجهة، نُسّقت ملفات Vision الأربعة والتجزئة الجديدة. ثلاث ملاحظات interpolation الأصلية أُزيلت بالتركيب الجديد.
- ثلاثة اختبارات مراجعة ولقطة مراجعة واختبار لغة قرأت حقولًا مطوية قبل الاختيار/الرسم. أضيف `pump` بعد Checkbox، ونُقل تحقق الوحدة بعد الاختيار؛ أبقيت جميع تحققّات البقايا/الصفر/الهوية/الوحدة. بعد تمرير scroll إلى CTA أعيد إظهار شريحة eaten قبل الضغط، دون إسكات hit-test warning.
- فحص القراءة الجديد أثبت **12/36 إخفاقًا في شبكة المغذيات** عند أحجام/تكبيرات معينة: قيمة Not available/غير متوفر كانت ellipsized رغم وجود النص في الشجرة وعدم وجود RenderFlex. أصلح كود Vision ضمن النطاق الجديد بشبكة 3/2/1 أعمدة وإزالة حد السطر القاطع للقيمة/العنوان، مع إبقاء حسابات/evidence masks كما هي. مصفوفة **72/72** الآن خضراء.
- Source على تعديل الواجهة الأول كشف sort-child وprotected setState وif braces؛ صُححت باستخدام wrapper الحالة الموجود، دون تجاهل lint.
- P0 Arabic كشف Overflow 8px في fixture Ahem. الحالة المنفردة بنفس 600×1200 والassertion الأصلية نجحت بخط عربي فعلي؛ theme وassertion عائلة الخط أضيفا. تعليق تحميل الخط داخل FakeAsync صُحح بـ`tester.runAsync`، ومحاولة الاختبار المتوقفة سُجّلت وأُنهِي tester الخاص بهذه المحاولة فقط. فحص التطبيق لم يُعطّل.
- واجهة Vision الجديدة تحافظ على الصورة المدخلة وclock LTR ومرحلة الأكل وعدم تلقائية الاختيار والحفظ. الاسم العربي للسجل يستخدم alias الموجود عند توفره. زر التحرير يُظهر المكونات دون اختيارها. لا تغيّر في عقد Food/المقادير أو الكود الذري للحفظ.

## ما يحتاج QA الرئيسي

1. Home: أربعة إخفاقات EN عند 320/390/430 والpreview، `RenderFlex overflow 1px`. السبب في Column بطاقة السعرات داخل `dashboard_reference_goal_components.dart:194` تحت قيد ارتفاع الكاروسيل `dashboard_reference_phone_components.dart:58-68` مع burn-policy note. المطلوب جعل ارتفاع البطاقة يعترف بالمحتوى الحقيقي، ثم إعادة المجموعة الحمراء وحدها؛ لا ضغط نص أو حذف burn note أو كتم exception. لم يُغيّر Home.
2. 29 Golden اختلافًا: watch 1، weekly/onboarding/dashboard 26، recipe/workout 2. صور المقارنة محفوظة. هي فروق مرجع تحتاج مراجعة واعتماد؛ لم نعاملها كـ29 bug إنتاجيًا مثبتًا ولم نحدّث أي baseline.
3. ربط الهاتف الثاني في المرجع بالصورة والكمية الفعليتين يحتاج تعديل المستدعيين المحميين والعقد الراجع، ثم تحقق atomic/owner/replay جديد. لا editable UI وهمية تقرأ كمية ثم يحفظ المستدعي كمية قديمة.
4. لا Full جديد قبل Broad ناجح على نفس الكود/بصمة البوابات.

## ما لم يُختبر

الأجهزة الفعلية iOS/Android، خطوط النظام وsafe areas الحقيقية، VoiceOver/TalkBack، الإيماءات والpinch الحقيقي، Camera/Gallery والأذونات الأصلية، الشبكة/AI الحقيقي أو المدفوع، تشغيل offline أصلي، حسابات إنتاجية أو Supabase، الدفع/Trial، artifact موقع، TestFlight/المتاجر. viewport/keyboard/safe insets وفتح صورة التكبير مثبتة داخل Flutter test فقط؛ الوحدات/العزل/rollback/replay مثبتة بعينات SQLite/قنوات معزولة. الجديدة UI matrix ar/en؛ نجاح عقود parsing لـ25 لغة لا يثبت كل لغات الواجهة الجديدة على جهاز.

## الملفات البرمجية المعدلة منذ تسليم 38a97987

- `lib/features/nutrition/presentation/meal_vision_premium_glass.dart`
- `lib/features/nutrition/presentation/meal_vision_premium_match.dart`
- `lib/features/nutrition/presentation/meal_vision_premium_reference.dart`
- `lib/features/nutrition/presentation/meal_vision_premium_review.dart`
- `lib/features/nutrition/presentation/meal_vision_premium_visuals.dart`
- `test/features/nutrition/meal_image_language_regression_test.dart`
- `test/features/nutrition/meal_vision_flutter_capture_test.dart`
- `test/features/nutrition/meal_vision_premium_review_test.dart`
- `test/features/nutrition/meal_vision_premium_visual_contract_test.dart`
- `test/features/nutrition/meal_vision_reference_capture_test.dart`
- `test/features/nutrition/meal_vision_v2_interaction_test.dart`
- `test/features/nutrition/meal_vision_v2_matrix_test.dart`
- `test/features/nutrition/vision_v2_test_fixture.dart`
- `tools/qa/bil_codex_test_ladder.py`
- `tools/qa/test_bil_codex_test_ladder.py`

## كل المجموعات والسجلات النهائية

| المجموعة | ناجح | فاشل | السجل |
|---|---:|---:|---|
| arabic-noto-capture | 2 | 0 | [log](logs/arabic-noto-capture.log) |
| arabic-vision-v2 | 82 | 0 | [log](logs/arabic-vision-v2.log) |
| p0-food-owner-atomic | 32 | 0 | [log](logs/p0-food-owner-atomic.log) |
| p0-meal-owner-atomic | 16 | 0 | [log](logs/p0-meal-owner-atomic.log) |
| p0-first-food-commit | 5 | 0 | [log](logs/p0-first-food-commit.log) |
| p0-vision-review | 7 | 0 | [log](logs/p0-vision-review.log) |
| p0-vision-durable-replay | 8 | 0 | [log](logs/p0-vision-durable-replay.log) |
| p0-vision-quantity-basis | 6 | 0 | [log](logs/p0-vision-quantity-basis.log) |
| p0-vision-capture | 2 | 0 | [log](logs/p0-vision-capture.log) |
| p0-architecture | 1 | 0 | [log](logs/p0-architecture.log) |
| p0-coach-photo-bridge | 12 | 0 | [log](logs/p0-coach-photo-bridge.log) |
| p0-coach-image-source | 31 | 0 | [log](logs/p0-coach-image-source.log) |
| p0-vision-arabic | 79 | 0 | [log](logs/p0-vision-arabic.log) |
| focused-store-captures | 44 | 0 | [log](logs/focused-store-captures.log) |
| focused-production-goldens | 126 | 0 | [log](logs/focused-production-goldens.log) |
| focused-data-goldens | 61 | 0 | [log](logs/focused-data-goldens.log) |
| focused-splash-golden | 5 | 0 | [log](logs/focused-splash-golden.log) |
| focused-transaction-queue | 36 | 0 | [log](logs/focused-transaction-queue.log) |
| broad-dashboard-nutrition | 75 | 4 | [log](logs/broad-dashboard-nutrition.log) |
| broad-dashboard-contract-health | 28 | 1 | [log](logs/broad-dashboard-contract-health.log) |
| broad-weekly-onboarding-goldens | 19 | 26 | [log](logs/broad-weekly-onboarding-goldens.log) |
| broad-settings-language-icons | 39 | 0 | [log](logs/broad-settings-language-icons.log) |
| broad-wellness-commerce | 9 | 2 | [log](logs/broad-wellness-commerce.log) |
| broad-community-cold-back | 46 | 0 | [log](logs/broad-community-cold-back.log) |

[تحليل المصدر الكامل](logs/source-analyze.log) · [manifest](ladder-manifest.json) · [الأعداد الآلية](suite-counts.json) · [SHA-256 لكل ملف](sha256.json).

[قبل تعديل المرجع](before-reference.zip): الإخفاقات/الصور في دورة test-only الأولى على V2. [بعد تعديل المرجع](after-reference.zip): كل المحاولات اللاحقة والصور الحالية وفروق Broad التي أنتجها التشغيل الحالي. لا تُحذف أدلة الأحمر بعد نجاح retry. الملفات تحت test/**/failures هي مخرجات تشخيصية، لم تُرفع كتغييرات baseline؛ أُرشفت في ZIP فقط. worktree الأساسي المتسخ محفوظ، ولا cleanup أو reset.
