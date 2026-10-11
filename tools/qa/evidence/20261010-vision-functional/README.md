# BIL AI Vision V2 — التسليم الوظيفي المحلي

الفرع: `qa/bil-quality-ux-integration-20261009`، PR #11. نسخة الكود المختبرة: `b3fa731fc4a4be5d8308e06fddb54299bdbd4d45`. البصمة: `9bfb464ddede39bb5199afe67b641560b7822df1e71aaf75195faa5caae1a6ff`. Flutter 3.44.6 / Dart 3.12.2. الكوميت اللاحق يضيف هذه الأدلة فقط؛ لم تُغيّر ملفات الكود بعد البوابات.

استكمال مباشر بعد موافقة المستخدم «طبعا اي شي وضيفي يجب انهائه». هذا التسليم يتضمن ربطًا وظيفيًا محدودًا في مساري Daily Log / Log Food، وليس إصلاح اختبارات فقط. لم يتغير Home أو الشريط السفلي أو خدمات الحفظ أو Production أو الاشتراكات أو Trial أو نسخ المتاجر. جميع الإصلاحات السابقة محفوظة، ولم يُحدّث Golden أو يُعطّل assertion.

## الوظيفة المنجزة

- شاشة المراجعة النهائية تستقبل مسار الصورة الأصلية الخاص بهذه العملية وتعرضها وتكبّر الملف نفسه. لا يوجد مسار عام أو صورة بديلة.
- الكمية المأكولة والوحدة قابلتان للتعديل مع +/- وخيارات الوحدة، وتُعاد نتيجة مهيكلة تشمل Food والكمية والوحدة.
- مسارا التسجيل يحوّلان **القيم النهائية** وفق أساس حصة سجل الطعام ويُرسلانها إلى `addReviewedVisionItemsAtomically` الموجود. لا يستخدمان كمية الشاشة الأولى بعد تعديل الشاشة الثانية.
- التعديل يحدّث المعاينة الغذائية من السجل الموثوق وأقنعة الأدلة؛ لم تُستنتج تغذية من بكسلات الصورة أو يُخترع وزن للقطعة أو تقسيم 45/15 غرامًا.
- صفر/سالب/NaN/Infinity/كمية فارغة أو وحدة غير متوافقة تمنع التأكيد. الإلغاء يعيد null. اختيار المصدر يدوي، والتحقق من الملكية الموجود باقٍ. API القديم المستخدم في Coach لم يُستبدل؛ تبقى مرحلة الكمية الخاصة به كما كانت.

## الملفات العشرة المعدلة منذ آخر تسليم

- `lib/features/daily_log/daily_log_capture_actions.dart`
- `lib/features/daily_log/food_log_actions.dart`
- `lib/features/nutrition/presentation/meal_image_review_dialog.dart`
- `lib/features/nutrition/presentation/meal_vision_premium_match.dart`
- `lib/features/nutrition/presentation/meal_vision_premium_portion.dart`
- `lib/features/nutrition/presentation/meal_vision_premium_review.dart`
- `test/features/nutrition/meal_vision_final_portion_test.dart`
- `test/features/nutrition/meal_vision_reference_capture_test.dart`
- `test/features/nutrition/meal_vision_v2_matrix_test.dart`
- `tools/qa/bil_codex_test_ladder.py`

## النتائج على نسخة الكود والبصمة أعلاه

Source: 191 ملف تنسيق، صفر تغييرات مطلوبة، تحليل المستودع: No issues found. اختبار أداة التدرج: 9/9. العربية/Vision: مجموعتان، 84 ناجحًا. P0: 11 مجموعة، 202 ناجحًا. Focused: 5 مجموعات، 272 ناجحًا. Broad: 6 مجموعات، 216 ناجحًا و33 فاشلًا؛ مجموعتان خضراوان وأربع حمراء. **Full: الثماني shards متخطاة، لم تُشغّل** لأن Broad حمراء. لا تُستخدم نتائج التسليم السابق لتصديق الكود الجديد.

| المجموعة | ناجح | فاشل | السجل |
|---|---:|---:|---|
| arabic-noto-capture | 2 | 0 | [log](logs/arabic-noto-capture.log) |
| arabic-vision-v2 | 82 | 0 | [log](logs/arabic-vision-v2.log) |
| p0-food-owner-atomic | 32 | 0 | [log](logs/p0-food-owner-atomic.log) |
| p0-meal-owner-atomic | 16 | 0 | [log](logs/p0-meal-owner-atomic.log) |
| p0-first-food-commit | 5 | 0 | [log](logs/p0-first-food-commit.log) |
| p0-vision-review | 7 | 0 | [log](logs/p0-vision-review.log) |
| p0-vision-durable-replay | 8 | 0 | [log](logs/p0-vision-durable-replay.log) |
| p0-vision-quantity-basis | 9 | 0 | [log](logs/p0-vision-quantity-basis.log) |
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

## الأدلة والإصلاحات المحلية

اختبارات الوظيفة الجديدة: 3 حالات داخل مجموعة P0 الخاصة بأساس الكمية. اختبار Widget يستخدم الرقم العربي «٠٫٠٨ kg»، ويتحقق من عرض 76 kcal ثم النتيجة الفعلية 80 غرامًا / عامل حصة 0.8. فحص call sites يثبت تمرير هذه القيم إلى مساري الحفظ؛ هذا فحص مصدر، وليس تشغيلًا كاملًا لصفحات التسجيل عبر الكاميرا. اختبارات المستودع الذرية/عزل الحسابات/التكرار منفصلة ضمن P0.

تضم مصفوفة Vision: RTL/LTR، الداكن/الفاتح، 320/390/430، تكبير 1/1.8/2، والتفاعل والصورة والساعة 11:30. نجاح 6 لقطات إضافية لجزء الصورة/الكمية في شاشة المراجعة النهائية مسجل في [capture.log](logs/capture.log). [capture-script.txt](capture-script.txt) يحتوي برنامج إعادة إنتاجها. ينتظر البرنامج فك الصورة الفعلي ويطلب إعادة رسم شجرة RenderObject كاملة قبل raster لتجنب طبقات جزئية من retained painting؛ لا يعدل التطبيق أو بكسلات الصورة.

[مقارنة المرجع والصور](comparison.html)، [جميع صور Flutter](flutter-captures.zip)، [صور إخفاقات Broad](broad-failure-images.zip)، [manifest](ladder-manifest.json)، [أعداد النتائج](suite-counts.json)، [SHA-256](sha256.json). كل صورة غذاء هنا عينة TEST من أصل المشروع، وليست صورة مستخدم أو نتيجة AI حية. لا نزعم تطابقًا بكسليًا مع المرجع أو مع جهاز فعلي؛ إظهار المصدر والتحذيرات والقيم غير المتوفرة محفوظ.

أثناء بناء الربط الجديد ظهر خطأ compile بسبب استدعاء تطبيع الأرقام خارج صنفه وawait على hide() الذي يعيد void؛ أصلحا قبل نسخة البوابات. المصفوفة الضيقة وجدت حالتين EN/320/2× لا تجد فيهما الاختبارات المصدر لأن المحرر الجديد يدفعه خارج viewport؛ أُضيف تمرير فعلي إليه وبقي assertion واختبار overflow. السجلات الأصلية `final-portion-probe.log` و`final-portion-matrix.log` ومحاولات الإصلاح موجودة في logs، ولم يُخفَ إخفاق. مراجعة بعض لقطات الرسم الجزئي أدت إلى إعادة إنتاج اللقطات الإضافية كاملة بالشيفرة المرفقة.

## ما يحتاج QA الرئيسي

1. أربع إخفاقات Home: تجاوز رأسي بمقدار 1px في `lib/features/dashboard/widgets/dashboard_reference_goal_components.dart:194` داخل الارتفاع المحدود في `dashboard_reference_phone_components.dart:58-68`. المحتوى يحتاج ارتفاعًا مرنًا يراعي النص/ملاحظة الحرق؛ لا إخفاء محتوى ولا تقليل النص. لم يُعدّل Home.
2. 29 إخفاق Golden قديم: watch واحد، weekly/onboarding عدد26، wellness عدد2. هذه فروق صور تحتاج قرار مراجعة بيئة الخطوط/المنصة والمرجع، وليست 29 عيب تطبيق مثبتًا. محفوظة بصور actual/master/diff وسجلاتها؛ لا baselines جديدة تلقائيًا.
3. Full محجوب حتى تصبح Broad خضراء على بصمة كود واحدة. لا تتعامل مع تسليم Vision على أنه اجتياز QA شامل.

## ما لم يُختبر

لا أجهزة iOS/Android فعلية، كاميرا/صلاحيات/ملف صورة على الجهاز، AI مدفوع أو حي، حفظ شبكة أو حسابات حقيقية، backend/Production، TestFlight/متجر/نشر/دمج. صور Flutter وwidget/database tests أدلة محلية فقط؛ تحقق end-to-end من الكاميرا حتى حفظ الوجبة على الجهاز بقي لـQA الرئيسي. واجهة تتصرف جيدًا محليًا لا تثبت التطابق البكسلي مع المرجع على جهاز فعلي.

أُعيد التدرج لأن تغيّر الربط الوظيفي غيّر بصمة الكود، مع إعادة الاختبار الضيق الفاشل أولًا. بقيت ملفات failures التشخيصية المولدة خارج commit (4 tracked modified و4 untracked)، ومحتواها محفوظ في الأرشيف. المستودع الأصلي المتسخ لم يُمسّ. بعد رفع هذا التسليم والتعليق على PR يتوقف العمل؛ لا دورة جديدة أو تطوير إضافي.
