# BIL 2026 — وثيقة التسليم الرسمية والشاملة إلى مسؤول QA: AI Food Vision / Meal Analysis

**التاريخ:** 10 أكتوبر 2026. **الحالة:** تنفيذ جزئي على الشيفرة الحقيقية، غير جاهز للدمج أو الإنتاج، بوابات QA حمراء. **المالك التالي:** BIL QA الرئيسي.  
**Repository:** bilhealth-admin/Body-Intelligence  
**فرع العمل المشترك:** qa/bil-quality-ux-integration-20261009  
**PR الدمج القائم:** [PR #11 (Draft — غير قابل للدمج الآن)](https://github.com/bilhealth-admin/Body-Intelligence/pull/11)، أساسه qa/coach-community-next-20261005.  
**HEAD الأصلي للحزمة ونقطة المقارنة:** aca278eb6ec1a094c51e5967ecd86b1ec63e32ca  
**آخر HEAD للشيفرة وقت إعداد هذه الوثيقة، قبل Commit الوثيقة نفسها:** 7b69ec331b95c31e951f2275170b8a6f6f6d9391  
**آخر Commit لإصلاح أربع ملاحظات محلل Dart، لم يُثبت بعد تشغيل تحليل ناجح بعده:** [7b69ec33](https://github.com/bilhealth-admin/Body-Intelligence/commit/7b69ec331b95c31e951f2275170b8a6f6f6d9391)  
**نتائج CI الكاملة التي جرى تدقيقها تعود إلى SHA أقدم:** f70b5bd9a10a4ec58260c03d61d4bb9098ca49d5. **لا تنسب نتائج هذا SHA إلى 7b69ec33 أو Commit الوثيقة.**  
**مصادر الحقيقة:** GitHub code + GitHub Actions jobs/logs، وليس عبارة «تم التنفيذ» أو مجرد وجود الاختبارات في المستودع.

> **أمر استلام:** اقرأ الوثيقة من أولها إلى آخرها، ثم افحص HEAD من جديد؛ استكمل إصلاح العوائق من الشيفرة الحالية دون إعادة من الصفر، ودون خلط هذا العمل مع PR #10 أو PR #9 أو استبدال تغييرات QA الأخرى. لا تعتبر وجود UI أو Android APK دليلًا على نجاح اختبار المستخدم النهائي. ممنوع الدمج التلقائي/force-push أو نشر Supabase أو بناء المتاجر.

## 1. حدود الصلاحية والأعمال المحمية

- التغييرات تخص مراجعة صورة الطعام، التأكد من الكمية المأكولة، اختيار سجل غذائي موثوق وعرض القيم الغذائية، وربط المسارين الموجودين في Food Log وDaily Log.
- **محظور:** تعديل main؛ الدمج دون موافقة؛ Production Supabase؛ تغييرات الأسعار/الدفع/الاشتراكات/Trial/حصص AI Vision أو AI Boost؛ النشر على Apple أو Google؛ تعديل Dashboard أو شريط التنقل السفلي أو منطق AI Coach/Community خارج نطاق تكامل Vision المتفق عليه.
- هذا الفرع يحتوي أعمال QA أخرى تتزامن مع Vision. **لا تعكس الملفات غير المتعلقة بـ Vision، ولا تمس إرشادات الاستخدام الأولى أو الاحتفال أو Back-navigation أو Golden المعتمدة.** ابحث عن الفروقات الحالية قبل أي Commit.
- لا تغيّر سياسة **ensureMealVisionConsent** الحالية دون مراجعة خصوصية مستقلة؛ رفض الموافقة يعني عدم إرسال الصورة، مع استمرار مسار إدخال الطعام اليدوي.
- لا تختلق قيمًا غذائية من الصورة، ولا تفسر نسبة ثقة التعرف على الطعام كدقة للسعرات، ولا تعرض 0 عندما لا توجد أدلة على المغذي.

## 2. المادة الأصلية وسلسلة التنفيذ

**حزمة الإدخال المرفقة للمحادثة الأصلية**: BIL_Vision_Premium_Review_20261010.zip وتضم MANIFEST.json وREADME_AR.md وQA_REPORT_AR.md وdesign/BIL_Vision_Concept.png وlib/features/nutrition/presentation/meal_vision_premium_review.dart وpatches/0001-integrate-premium-review.patch وtest/features/nutrition/meal_vision_premium_review_test.dart. هي نقطة انطلاق فقط؛ **الصورة Concept وليست لقطة Flutter**، ولم تكن الحزمة الأصلية مبنية أو مختبرة.
**حزمة تسليم محلية أُنشئت بعد التطوير**: BIL_Vision_Premium_Implementation_20261010.zip كانت متاحة كمرفق بالمحادثة. لا تدّع وجود ملف ZIP النهائي داخل المستودع إلا بعد رفعه والتحقق من بصمته. شيفرة GitHub المحدثة هي المصدر المعتمد.
**سلسلة عمل مثبتة على GitHub:** نقل مصدر الحزمة إلى تسعة أجزاء .github/vision_payload.part01.txt إلى part09.txt ببصمات تحقق؛ إعداد GitHub workflow للدمج؛ تطبيق الشيفرة وتنسيقها في Commit e4a4d5c4a39af2a7c4086f0f49516f39bca06c7d؛ جولات إصلاح لاحقة منها 97b2f00f96ab0eb32a067ee14b0fb7f0234e714f؛ إضافة اختبارات/تجهيز صور عند a24f7270c1b1a61bcf0f4d0c24e1fe191a5100c0؛ تنسيق لاحق؛ ثم توثيق أول استخدام عند c3c61339b284d480072ed454bb99a1657f2ebf19؛ وأخيرًا إصلاح أربع ملاحظات this عند 7b69ec33. **تحقق من التاريخ الكامل عبر git log بدل اعتبار هذه قائمة لكل Commit على الفرع.**

## 3. الجرد الدقيق للملفات ومسارات الاستدعاء

### ملفات Vision التي تغيّرت فعليًا

| الملف | ما حصل |
|---|---|
| lib/features/nutrition/presentation/meal_image_review_dialog.dart | تعديل واجهتي الدوال الأصليتين: تحويل إلى Premium عند عرض شاشة لا يقل عن 320px، مع fallback قديم للشاشات الأصغر. الحفاظ على نوع الإرجاع MealImageReviewSelection وFood. |
| lib/features/nutrition/presentation/meal_vision_premium_review.dart | **جديد**: نموذج المراجعة وحالة المكونات والكمية والمرحلة والنتيجة وGlass shell ومفاتيح Widget. |
| lib/features/nutrition/presentation/meal_vision_premium_visuals.dart | **جديد**: part من الملف السابق؛ عرض الصورة والمرحلة وبطاقات المرشحين والثقة والكمية والأزرار. |
| lib/features/nutrition/presentation/meal_vision_premium_match.dart | **جديد**: اختيار السجل الموثوق، الملخص والتحليل الكامل والمغذيات وقناع الإثبات. |
| lib/features/daily_log/food_log_actions.dart | **معدّل**: تمرير image.path وmealType وDateTime.now إلى المراجعة، ثم مقدار/وحدة الكمية إلى المطابقة، مع استمرار الحفظ الذري والإبطال السابقين. |
| lib/features/daily_log/daily_log_capture_actions.dart | **معدّل**: الربط نفسه لمسار Daily Log؛ الاحتفاظ بالتحقق من اليوم المفتوح ومعالجة الحفظ القائمة. |

### اختبارات Vision المضافة

- test/features/nutrition/meal_vision_premium_review_test.dart — خمسة اختبارات Widget (3 نجحت، 2 فشلت في آخر جولة مدققة).
- test/features/nutrition/meal_vision_verified_commit_test.dart — حفظ 80غ وقراءة سجل SQLite وإثبات السعرات والبوتاسيوم والمصدر وقناع المغذيات؛ رفض إدخال 0 دون وجبة جزئية (نجح على f70b5bd9).
- test/features/nutrition/meal_vision_flutter_capture_test.dart — هدفه تصوير أربع حالات من **Flutter widget renderer**؛ فشل اختبارا التصوير ولم ينتج Artifact صالحًا في آخر تشغيل.

### ملفات CI/توثيق تقنية

- .github/workflows/bil_vision_premium_20261010.yml (تشغيل دمج الحزمة الأولي، انتهى بفشل).
- .github/workflows/bil_vision_postintegration_20261010.yml (تحليل، اختبارات مركزة، صور Flutter، وبناء Android/iOS المشروط).
- .github/workflows/bil_vision_formatter_once_20261010.yml (أداة تنسيق مؤقتة؛ لا تُكرر بغير ضرورة).
- .github/vision_payload.part01.txt إلى .github/vision_payload.part09.txt (أجزاء نقل الحزمة؛ لا تعتبرها شيفرة تشغيلية ولا تحذف قبل فحص المراجع).
- docs/qa_next/BIL_VISION_20261010_IMPLEMENTATION.md (تقرير أولي قديم؛ هذه الوثيقة أحدث منه).
- docs/qa_next/BIL_20261010_FIRST_USE_HANDOFF_TO_NEXT_CHAT_AR.md (ملف آخر من أعمال QA العامة؛ **لا يُستبدل**).
- لم يكن تعديل test/features/community/community_message_retry_cases.dart أو workflow الخاص بعودة Community جزءًا من نطاق Vision؛ هذه أعمال أخرى على الفرع ويجب الحفاظ عليها.

### ملفات/عقود تمت مراجعتها ولا يصح افتراض تعديلها

- lib/features/nutrition/presentation/meal_vision_ui_copy.dart
- lib/features/nutrition/presentation/meal_image_guide_page.dart
- lib/features/nutrition/presentation/meal_image_guide_widgets.dart
- lib/features/nutrition/presentation/meal_vision_consent_gate.dart
- lib/features/nutrition/services/meal_image_analysis_service.dart
- lib/features/nutrition/services/meal_image_gateway_contract.dart
- lib/features/nutrition/domain/unified_food.dart
- lib/features/nutrition/presentation/food_nutrient_values.dart
- lib/features/daily_log/quick_add_meal_camera_page.dart
- lib/features/daily_log/food_log_page.dart وdaily_log_page.dart وdata/repositories/meal_repository.dart، وأي مدخل آخر عبر البحث في المستودع.

**السلسلة الحقيقية:** camera/gallery أو Quick Add → موافقة الصور وحصة AI → MealImageAnalysisService → showMealImageReviewDialog → foodRuntimeSearchAuthorityProvider (findExact أو search، تحقق verified) → showTrustedVisionFoodMatchDialog → mealImageAmountInGrams → mealRepositoryProvider.addReviewedMealItemsAtomically → إبطال مزود السجل/تحديث العرض + رسالة النجاح الأصلية. مسار Food Log يتضمن first-food celebration بعد نجاح الحفظ. لا تكتب إلى السجل من Widget المراجعة وحده؛ الكتابة ما زالت في المستدعيين. تتبع كل الاستدعاءات قبل تعديل التوقيعات.

## 4. الميزات الموجودة في الشيفرة مقابل مستوى اعتمادها

| مطلب المستخدم | حالة الكود الحالية | ما ينقص لاعتماد QA |
|---|---|---|
| زجاج BIL داكن وفاتح، حدود وإضاءة محدودة بلا ظلال أيقونات | موجود في Glass shell والبطاقات | مقارنة شاشة فعلية مع Concept ومع AI Coach؛ RTL/LTR وتباين |
| الرأس BIL Vision وعنوان «تحليل وجبتك» والإغلاق | موجود | تجربة الرجوع مستقلة عن الإغلاق واختبار focus |
| صورة المستخدم الأصلية/تكبيرها وغياب صورة بديلة | تمرير image.path، Image.file + InteractiveViewer وتحذير عند غياب المسار | لقطة فعلية، الصور الرأسية والأفقية، انقطاع مسار الملف، الرجوع دون فقدان المسودة |
| اسم كل صنف/تعدد المكونات | بطاقات مستقلة لكل مرشح | الشكل الدقيق لشارات المكونات والتجميع ومحتوى متعدد الأطعمة |
| مؤشر ثقة التعرف الدائري | TweenAnimationBuilder + تسمية «ثقة التعرف فقط»، مدة 600ms أو صفر عند disableAnimations | اختبار سلاسة/قارئ شاشة، وعدم خلطه بمصداقية السعرات/الكمية |
| بطاقة نوع الوجبة والوقت | موجودة | الوقت المرسل DateTime.now **وقت عرض النتيجة، وليس بالضرورة وقت الالتقاط الحقيقي** |
| تحديد قبل/أثناء/بعد الأكل | ChoiceChips **يدوية** | **لا يوجد كشف آلي مثبت لمرحلة الصورة**؛ تحقق من إدخال المستخدم |
| الفرق بين المأكول والبقايا | «أكلت هذه الكمية»/«الكمية المتبقية»؛ اختيار المتبقي يمسح المقدار ويتطلب إدخال المأكول | اختبار Widget المعني فاشل؛ لا تعتبر القاعدة مثبتة عمليًا |
| تعديل الكمية + و− والرقم والوحدة | TextEditingControllers، تحقق موجب وحتى 100000، تطبيع أرقام عربية/فارسية؛ قائمة g/kg/oz/lb/serving | اختبار لوحة المفاتيح والسلبي/NaN/صفر/تحويل الحصة؛ لا تفترض تحويل cup إلى g دون مصدر |
| إضافة/استبعاد/استعادة الطعام | موجودة في المراجعة؛ الإضافة اليدوية تتطلب مطابقة جديدة | E2E لمصدر غير معروف وفشل المطابقة وعدم فقدان التعديلات |
| البدائل | اختيار البديل يزيل أي verifiedFoodRecordId قديم ويعيد مطابقة الاسم | **اختبار البديل فاشل** ويجب فحص عدم حفظ سجل قديم |
| عرض المصدر الغذائي | اختيار Food.verified وإظهار food.source بصورة منفصلة عن نموذج الصورة | صقل تصنيف branded/foundation/custom وتوثيق الهوية والموثوقية في واجهة حقيقية |
| السعرات والبروتين والدهون والكربوهيدرات والألياف والسكر وصافي الكارب | موجودة في شاشة السجل الموثوق، وتُضرب في العامل فقط بعد تحويل وحدة موثوق | اختبار القيم، ترتيب السعرات بصريًا، عدم اعتبار أي مقدار بالصورة دليلًا |
| بوتاسيوم وصوديوم ومغنيسيوم وكالسيوم وفوسفور وحديد وفيتامين C | موجودة من حقول Food؛ المفقود يعرض «غير متوفر» استنادًا إلى mask أو قيمة nonzero | لا توجد كل الفيتامينات المحتملة في نموذج Food؛ راجع توسعة العقد قبل طلب أرقام إضافية |
| الملخص/التحليل الكامل | Switch بعد اختيار مصدر موثوق | فشل التقاط صور Flutter؛ احتياج تدقيق التنقل والتمرير والقياسات |
| مطابقة ثم حفظ فعلي | دالة الحفظ الذري الأصلية تعمل، واختبار SQLite الجديد نجح | اختبار كامل من صورة حقيقية حتى قراءة سجل اليوم والتحديث عبر المزود؛ لا يوجد زر حفظ نهائي مستقل داخل حوار Premium |
| منع الحفظ المكرر | mealImageBusy يمنع الطلب المتداخل داخل الشاشة؛ الحفظ ذري | **لا توجد idempotency دائمة حسب requestId عبر إعادة المحاولة/إعادة تشغيل التطبيق** |
| AI Coach natural response | لم تُعدل محادثة AI Coach | ما زالت رسائل Snackbar الأصلية؛ مطلوب تصميم حدث موثوق وتأكيد قراءة السجل قبل الرسالة، دون تعديل خارج النطاق بصمت |
| التحليل/المسح الضوئي/أنيميشن النجاح | حركة مؤشر التعرف موجودة | لا يوجد Scan overlay احترافي ولا stagger لكل صنف ولا حركة نجاح خاصة ولا re-analysis داخل المراجعة |
| 25 لغة/RTL/حجم الخط وإمكانية الوصول | عربي وإنجليزي عبر _word، بقية اللغات RuntimeCopy fallback؛ قيم Semantics محدودة | **لا يوجد إثبات بصري/سلوكي لجميع 25 لغة** ولا فحص تكبير خط وقارئ شاشة/contrast مكتمل |
| شاشة هاتف صغيرة | Premium فقط عند عرض 320px أو أكثر؛ دونها يعود AlertDialog القديم | يخالف مبدأ توحيد الفخامة في جميع المقاسات؛ اختبار الشاشات الصغيرة والطي/الأجهزة اللوحية |
| جميع حالات الفشل والتحميل | الخطوات القديمة بها رسائل واستثناءات وحصة/خصوصية | **لا توجد معالجة Premium مصممة ومختبرة لكل الحالات الـ25** أدناه |

> «موجود في الشيفرة» يعني تنفيذًا قابلًا للفحص، لا يعني أنه مرّ في اختبار Flutter أو جهاز أو مستوى التصميم المرجعي. الوضع النهائي: **غير مقبول للإنتاج حتى الآن**.

## 5. نتائج CI الحقيقية وروابط الإثبات

**بصمة الاختبار الأساسي:** f70b5bd9a10a4ec58260c03d61d4bb9098ca49d5.  
**[تشغيل Vision post-integration #38043774747](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38043774747): فشل نهائي.**  
**[تشغيل verify #38043778775](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38043778775): فشل source-checks في Analyze، وتخطي الخمس focused والثماني full.**  
**[تشغيل android-debug-build #38043778750](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38043778750): نجاح بناء ورفع APK تجريبي، فقط على f70b5bd9.** لا يُعد تجربة جهاز أو اعتماد نسخة المتاجر.

| فحص على f70b5bd9 | النتيجة الدقيقة |
|---|---|
| dart format لستة ملفات Vision | **نجح**: 0 changes |
| flutter analyze --no-pub | **فشل** بسبب أربع معلومات lint من unnecessary_this في meal_vision_premium_review.dart (السابق: الأسطر 497، 515، 529، 535) |
| test/features/nutrition/meal_vision_premium_review_test.dart | **3 نجاح / 2 فشل**؛ فشل اختبار البقايا واختبار تغيير البديل؛ Null check operator used on a null value عند test.dart:152 و:210. لا يوجد إثبات أيهما سبب فشل السلوك مقابل مشكلة harness حتى الإصلاح وإعادة التشغيل. |
| test/features/nutrition/meal_vision_flutter_capture_test.dart | **0 نجاح / 2 فشل**؛ انتهت كل حالة بعد 10 دقائق؛ ظهر Flutter assertion «ListTile background color or ink splashes may be invisible» لأن ListTile ضمن DecoratedBox ملوّن بلا Material مناسب؛ **0 صور PNG معتمدة، 0 Artifacts** |
| test/architecture_source_file_size_guard_test.dart | **فشل** بسبب food_log_page.dart (716 سطر) وmeal_repository.dart (726 سطر) وفق حارس المشروع (الحد 700). **الملفان كانا متجاوزين أصلًا عند HEAD الأصلي aca278eb6، فلا تنسب السبب إلى Vision**، لكن لا تتجاوز البوابة دون إصلاح/استثناء مصادق عليه. |
| test/features/nutrition/meal_vision_verified_commit_test.dart | **نجح**: حفظ وقراءة 80g، 76kcal، 136mg potassium، إثبات source/verified/mask، ورفض صفر |
| test/features/nutrition/meal_image_unified_review_contract_test.dart | **نجح** |
| test/features/nutrition/meal_vision_domain_contract_test.dart | **نجح** |
| test/features/nutrition/meal_declared_unit_commit_test.dart | **نجح** |
| test/features/nutrition/meal_item_evidence_snapshot_test.dart | **نجح** |
| test/features/daily_log/daily_log_nutrition_evidence_test.dart | **نجح** |
| test/features/daily_log/meal_photo_initial_action_test.dart | **نجح** |
| Android داخل Workflow Vision وiOS داخل Workflow Vision | **Skipped** لأن بوابات needs لم تنجح؛ Android debug مستقل نجح كما أعلاه |
| جميع اختبارات التطبيق الثمانية/Golden/الأجهزة الحقيقية | **لم تُستوفَ على SHA Vision النهائي** |

**المجموع الدقيق للثمانية focused في Workflow Vision:** 7 ناجحة و1 فاشلة. خارجها: architecture فاشل، analyze فاشل، capture فاشل. لا تُحوّل حالة إلغاء أو تخطي إلى نجاح.

**بعد هذه النتائج:** Commit 7b69ec33 حذف استعمالات this الأربع دون تغيير سلوك مقصود. **لم يتم التحقق من flutter analyze ناجح على 7b69ec33** وقت كتابة الوثيقة. أعد جميع البوابات بعد تثبيت أحدث HEAD؛ لا تعتمد اختبارات f70b5bd9 بدلًا منها.

## 6. العوائق الحرجة — أولويات QA الصارمة

### P0 (تمنع القبول)
1. أعد تشغيل flutter analyze على آخر HEAD: تحقق من اختفاء الأربع معلومات؛ أصلح أي جديد دون تعطيل lint.
2. أصلح اختباري Widget الفاشلين: البقايا/الكمية الفعلية والبديل/record-id؛ افحص منطق الحفظ والـ finder/scroll/focus في الاختبار؛ **لا تُضعف assertions** ولا تعتبر Null check فشلًا متوقعًا.
3. أصلح شاشة السجل الموثوق التي تضع ListTile تحت DecoratedBox بخلفية دون Material مناسب، واختبري تصوير Flutter اللذين انتهيا 10 دقائق؛ أصلح انتظار الرسوم/تنقل الـ dialogs/التصوير؛ تحقق من إنشاء PNG حقيقي لا صورة Concept.
4. اختبر المسار الكامل: صورة أصلية → موافقة صريحة → تحليل → تحديد قبل/أثناء/بعد → كمية **مأكولة** صحيحة → سجل غذائي موثوق → حفظ ذري → قراءة meal item وnutrientEvidenceMask والمصدر → تحديث Food Log وDaily Log والداشبورد، ثم التأكد من عدم التكرار عند ضغطين أو retry.
5. حسم حارس 700 سطر للفيلمين الموجودين من baseline بتقسيم مدروس أو استثناء رسمي مصادق عليه؛ **لا تحذف الاختبار ولا ترفع الحد فقط لتلوين CI بالأخضر.**

### P1 (قبل التصديق البصري/الإطلاق)
- اختبر RTL/LTR واللغات الإنتاجية الـ25 وتكبير الخط/قارئ الشاشة/مناطق الضغط والتباين والوضعين.
- اضبط حالات الخطأ ضمن التصميم الزجاجي بدل الاعتماد على Snackbar قديم في كل الحالات.
- أكمل مراحل التحليل/مسح الصورة/المؤشر/الانتقال الهادئ والنجاح، مع احترام reduced motion وبدون وميض.
- أضف Back واضحًا عند الحاجة وفحص keyboard/back/close وإلغاء المطابقة واستعادة المسودة.
- تأكد من وقت الالتقاط الحقيقي بدل DateTime.now إذا كان المعروض للمستخدم وقت التصوير.
- راجع fallback تحت 320px حتى لا تظهر واجهة قديمة في أجهزة صغيرة.
- حسم تصميم التأكيد النهائي قبل commit؛ فصل مصدر التعرف عن مصدر الأرقام.
- لا تطلق طلب إعادة تحليل يتسبب بخصم حصة إضافية إلا بموافقة واضحة وحارس idempotency.
- عقد AI Coach: لا تكتب «تم الحفظ» حتى نجاح Read-back، ولا تغيّر AI Coach السحابي من عمل QA البصري دون فصل المهمة وإثباتها.
- أثبت iOS simulator + Android debug وعلى أجهزة فعلية؛ استخرج صور Before/After حقيقية ووثّق المقارنة بكل عناصر المرجع.

## 7. الحالات الـ25 المطلوب إغلاقها باختبار واضح

**الوضع الافتراضي لكل صف: غير معتمد End-to-End حتى يرفق QA دليل تشغيل**؛ وجود partial UI أو اختبار عقد سابق ليس اعتمادًا لهذه الحالة.

| # | الحالة الإلزامية | المطلوب من QA |
|---|---|---|
| 01 | صورة واضحة وطعام واحد | نتيجة واسم ومطابقة وقراءة سجل |
| 02 | صورة متعددة الأطعمة | اختيار/استبعاد كل عنصر وحفظ متعدد ذري |
| 03 | طبق مأكول جزئيًا | لا تختلط البقايا بالمأكول؛ Widget فاشل حاليًا |
| 04 | كمية غير معروفة | لا حفظ دون تحديد المأكول والوحدة |
| 05 | طعام غير معروف | إضافة يدويًا أو إلغاء دون إيهام بمصدر |
| 06 | بدائل متعددة | تغيير هوية العنصر وإلغاء exact-id القديم؛ Widget فاشل |
| 07 | ثقة تعرف منخفضة | تحذير وقرار بشري لا يقيس دقة السعرات |
| 08 | عنصر دون سجل غذائي موثوق | لا قيمة مختلقة؛ ابحث/أضف/ألغِ؛ راجع الصمت المحتمل في Food Log عند foods.isEmpty |
| 09 | نقص بعض المعادن | «غير متوفر» وعدم عرض 0 بلا evidence |
| 10 | تحليل لا يعيد نتائج | حالة UI واضحة لا شاشة فارغة |
| 11 | فشل الاتصال بالخدمة | Retry آمن دون مضاعفة الحصة |
| 12 | انتهاء مهلة الشبكة | رسالة واضحة وفحص عدم حفظ جزئي |
| 13 | تعذر فتح الكاميرا | رجوع آمن ومسار يدوي |
| 14 | رفض إذن الصور | مسار يدوي وتعليمات الإذن |
| 15 | رفض موافقة إرسال الصورة | **لا إرسال إلى Gemini** ولا حفظ |
| 16 | انتهاء حصة AI Vision | العرض القائم دون تعديل الاشتراكات/AI Boost |
| 17 | وضع دون إنترنت | حالة واضحة بدون طلب صوري عالق |
| 18 | ضغط مزدوج على إضافة الوجبة | إدخال واحد فقط واختبار race |
| 19 | تراجع/إغلاق قبل الحفظ | صفر تغييرات في السجل وعدم فقدان Navigation |
| 20 | فشل حفظ الطعام | Rollback ذري ورسالة فشل صحيحة |
| 21 | الرجوع بعد فتح لوحة المفاتيح | عدم قفز الواجهة وعدم فقدان تعديلات الكمية |
| 22 | أحجام شاشة مختلفة | أقل من 320، هاتف عادي، جهاز لوحي |
| 23 | تكبير الخط | لا Overflow ولا قص البطاقة أو زر الحفظ |
| 24 | العربية RTL وكل اللغات الأخرى | حروف واتجاه وأرقام ووحدات وقارئ شاشة |
| 25 | نجاح الحفظ الفعلي | إثبات Read-back في السجل وDaily totals ولوحة العرض |

## 8. قائمة القبول الأصلية: حالة كل بند بلا إسقاط

الترميز: **C = موجود أو جزئي في الشيفرة لكن غير معتمد بصريًا/وظيفيًا**؛ **F = فشل اختبار معلوم**؛ **M = مفقود أو غير منفذ**؛ **T = بحاجة دليل اختبار حقيقي**؛ **P = مثبت في اختبار محدود على SHA f70 فقط**.

| البند الأصلي | الحالة |
|---|---|
| رأس BIL Vision الفخم | C/T |
| صورة الوجبة الأصلية | C/T |
| اسم الطعام | C/T |
| شارات المكونات | C/T (بطاقات لا اعتماد لشارات المرجع) |
| مؤشر ثقة التعرف | C/T |
| بطاقة الوقت ونوع الوجبة | C/T (وقت نتيجة لا EXIF) |
| بطاقة الكمية والوحدة | C/T |
| تحذير الطبق المأكول جزئيًا | C/F |
| تعديل الوزن | C/T |
| أزرار زيادة وتقليل الوزن | C/T |
| إضافة وحذف المكونات | C/T (استبعاد/استعادة) |
| عرض البدائل | C/F |
| الماكروز والسعرات من مصدر موثوق | C/T |
| الألياف وصافي الكارب والسكر | C/T |
| جميع المعادن المتوفرة | C/T (القيم التي يدعمها نموذج Food) |
| بيان القيم المفقودة | C/T |
| بيان مصدر التغذية | C/T |
| الملخص السريع | C/T |
| التحليل الكامل | C/T |
| زر إضافة إلى السجل | M (الحفظ بالمستدعي بعد المطابقة، لا زر نهائي مستقل داخل Premium) |
| زر إلغاء | C/T |
| زر الرجوع | M/T (إغلاق ونظام تنقل؛ زر Back مستقل غير مثبت) |
| زر الإغلاق | C/T |
| جميع حالات الخطأ | M/T |
| جميع حالات التحميل | M/T |
| الأنيميشن | C/T (مؤشر الثقة فقط، بقية المسار ناقصة) |
| دعم RTL | C/T |
| الوضعان الفاتح والداكن | C/T |
| إمكانية الوصول | C/T |
| تحديث السجل الحقيقي | P/T (اختبار repository نجح؛ لا E2E UI/داشبورد) |
| منع التسجيل المكرر | C/M/T (in-flight only، بلا idempotency دائمة) |
| منع القيم الغذائية المختلقة | C/P/T (عقد المصدر والمغذيات، يحتاج مصفوفة حالات) |
| اختبارات Flutter | F (بعض focused ناجح والبعض فاشل) |
| لقطات فعلية من التطبيق | F/M (محاولة فشلت، لا PNG موثوق) |
| تقرير نهائي بالإنجازات والإخفاقات | C (هذه الوثيقة تسليم للحالة الحالية، وليست شهادة إغلاق) |

**يُضاف من الأمر الأصلي ولا يُسقط:** التمييز الثلاثي بين ثقة التعرف/ثقة تقدير الكمية/موثوقية مصدر المغذيات، مصدر التعرف ومراجعة المكونات ومصدر كل عنصر، اختيار/تعديل الوحدة، رسالة واضحة لزر حفظ معطل، إعادة التحليل الآمنة، مؤشرات التحميل الحقيقية، دعم الصور الرأسية والأفقية، وتطابق المرجع وAI Coach بصريًا. لا يوجد إثبات قبول كامل لهذه التفاصيل.

## 9. أوامر QA المقترحة (على SHA واحد ثابت)

ابدأ بتثبيت HEAD وتسجيله وقارن مع أساس الحزمة؛ **لا تشغّل الاختبارات على Commit يتغير أثناء الجولات**:

    git fetch origin
    git switch qa/bil-quality-ux-integration-20261009
    git pull --ff-only
    git rev-parse HEAD
    git diff --stat aca278eb6ec1a094c51e5967ecd86b1ec63e32ca HEAD
    flutter --version
    flutter pub get
    dart format --output=none --set-exit-if-changed lib/features/nutrition/presentation/meal_image_review_dialog.dart lib/features/nutrition/presentation/meal_vision_premium_review.dart lib/features/nutrition/presentation/meal_vision_premium_visuals.dart lib/features/nutrition/presentation/meal_vision_premium_match.dart lib/features/daily_log/food_log_actions.dart lib/features/daily_log/daily_log_capture_actions.dart test/features/nutrition/meal_vision_premium_review_test.dart test/features/nutrition/meal_vision_verified_commit_test.dart test/features/nutrition/meal_vision_flutter_capture_test.dart
    flutter analyze --no-pub

بعد نجاح format/analyze، شغّل الاختبارات المركزة منفصلة أو متوازية مع **fail-fast = false** وسجل لكل ملف Pass/Fail/SHA:

    flutter test --no-pub --timeout=2m test/features/nutrition/meal_vision_premium_review_test.dart
    flutter test --no-pub --timeout=2m test/features/nutrition/meal_vision_verified_commit_test.dart
    flutter test --no-pub --timeout=2m test/features/nutrition/meal_vision_flutter_capture_test.dart
    flutter test --no-pub --timeout=2m test/features/nutrition/meal_image_unified_review_contract_test.dart
    flutter test --no-pub --timeout=2m test/features/nutrition/meal_vision_domain_contract_test.dart
    flutter test --no-pub --timeout=2m test/features/nutrition/epic6_voice_vision_gateway_test.dart
    flutter test --no-pub --timeout=2m test/features/nutrition/meal_declared_unit_commit_test.dart
    flutter test --no-pub --timeout=2m test/features/nutrition/meal_item_evidence_snapshot_test.dart
    flutter test --no-pub --timeout=2m test/features/daily_log/daily_log_nutrition_evidence_test.dart
    flutter test --no-pub --timeout=2m test/features/daily_log/meal_photo_initial_action_test.dart
    flutter test --no-pub --timeout=2m test/architecture_source_file_size_guard_test.dart
    flutter test --no-pub --timeout=2m test/features/daily_log/quick_add_meal_camera_contract_test.dart

ثم E2E حقيقي/Widget integration بالـ25 حالة، اختبارات الرجوع والكيبورد وقارئ الشاشة، وخمس focused الخاصة بالمشروع ثم **الثماني full shards** من verify.yml بلا تعطيل أو حذف أو استثناء إخفاقات. بعد ذلك:

    flutter build apk --debug --no-pub
    flutter build ios --simulator --no-codesign --no-pub

اختبار iOS يحتاج Runner macOS/SDK صالحًا؛ هذا البناء **ليس** نسخة App Store. اختبر أجهزة فعلية منفصلة بعد البناء. حافظ على لقطات PNG من Flutter الحقيقي، بالمقاس واللغة والثيم والـ commit ونوع العينة، وقارن بكل عنصر في المرجع. لا ترفع إصدار متجر.

## 10. قواعد الدمج، التوثيق، والتراجع

- لا تدمج PR #11 ما دام Draft أو CI أحمر أو ماتت اختبارات E2E/الأجهزة. PR #10 وPR #9 غير جزء من تغيير Vision.
- قبل كل تعديل: ابدأ من HEAD الحالي وراجِع الملفات المتعارضة؛ ممنوع force-push وممنوع إسقاط تعديلات First-use أو QA الأخرى.
- بعد إصلاح كل مجموعة، شغّل اختبارها أولًا، ثم مجموعة العقود المجاورة، ثم الكامل عند خلو المشكلات المانعة؛ لا تعيد 8 shards المكلفة بعد كل تعديل صغير.
- اربط في PR #11 لكل مجموعة: SHA، قائمة الملفات، أوامر التشغيل، Pass/Fail، روابط GitHub Actions، artifact/screenshots، والمشكلات المفتوحة. لا تكتب «نجح» إذا لم يعمل.
- **Rollback:** أنشئ فرع إنقاذ أو commit revert انتقائي لتعديلات Vision المحددة فقط بعد مراجعة git log/diff. لا تستخدم git reset --hard + force-push على الفرع المشترك، ولا ترجع Commit عام يحتوي أعمال QA أخرى؛ أعد تشغيل tests بعد أي revert.
- أنشئ في النهاية ZIP للملفات المعدلة **المتحقق منها** مع SHA-256 وmanifest/file inventory ودليل build/test. لا تُسميها «جاهزة للبناء» أو «production ready» إلا بعد نجاح البوابات اللازمة.

## 11. تعليمات الاستلام الفورية لمسؤول QA

1. تحقق من أحدث HEAD وPR #11 أولًا؛ آخر SHA للكود سجلته هذه الوثيقة هو 7b69ec33 فقط قبل Commit التسليم.
2. اقرأ الوثيقة وملفات Vision الستة والاختبارات الثلاثة وسجلات #38043774747/#38043778775/#38043778750؛ **لا تعِد إنشاء الشاشات من الصفر**.
3. **ابدأ بالبوابات الحمراء:** إعادة analyze بعد إصلاح this، اختبارَي Widget البقايا والبديل، assertion ListTile وتصوير Flutter، وحارس الملفّين 700 سطر؛ ثم أعد المجموعة المركزة على SHA واحد.
4. عالج الـ25 حالة ومصفوفة القبول كلها، خاصة الحفظ/read-back والـidempotency وخصوصية Gemini وRTL وبدون بيانات مختلقة.
5. أبقِ أعمال First-use/الاحتفال وDashboard/Bottom nav/Production والأسعار وحصص AI خارج التعديل. أبلغ عبر PR #11 بما اكتمل وبما لا يزال أحمر، ولا تعلن الدمج أو الاكتمال قبل الإثبات.

**الحكم الفني عند التسليم: FEATURE IMPLEMENTED PARTIALLY / QA FAILING / NOT MERGE-READY.**
