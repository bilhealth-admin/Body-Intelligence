# BIL 2026 — تنفيذ الإرشادات الزجاجية والاحتفال المتحرك

**الفرع الوحيد:** `qa/bil-quality-ux-integration-20261009` — **PR #11 مسودة وغير مدموج**.

## المرجع والحدود
- راجعنا فيديو الشاشة المرفق `الاحتفال والالارشادات.zip`: يبدأ بتلميح تسجيل الوجبة من Home، ثم البحث، اختيار النتيجة، تعديل الكمية، نجاح التسجيل، ومتابعة الأيام.
- لا ننقل هوية أو ألوان أو ملفات MyFitnessPal إلى BIL؛ يقتصر الاقتباس على مفهوم التعليم بجوار العنصر الحقيقي وتسلسل رحلة التسجيل.
- شاشتا `DailyLogPage` و`FoodLogPage` ليستا الشاشة نفسها: `/daily-log?foodLog=1` يفتح `FoodLogPage`. لذلك يوجّه تعليم Home إلى الشاشة الصحيحة.
- **حماية:** لا تغيّر حسابات التغذية والحفظ ولا مخطط قاعدة البيانات أو خمس وجهات الشريط السفلي أو كابتن AI Coach؛ ولا `main` أو Production أو الدفع/Trial أو المتاجر.

## التنفيذ المرفوع على QA
1. سطح `FirstUseGlassSurface` حقيقي بتعتيم وBlur وحدود مضيئة وعناصر دقيقة وعناصر زجاجية قابلة للتكيّف.
2. `FirstUseContextCoachmark` يعرض شرحًا سياقيًا مختصرًا بإضاءة BIL، سهم توجيه، انتقال دخول ناعم، مؤشر تقدم عند الحاجة، و**تخطي أسفل البطاقة نفسها**. المكوّن غير Modal ويترك المحتوى متاحًا للمس والتمرير.
3. على Home: إرشادان (أول وجبة → البحث)، ثم زر ينقل إلى Food Log الفعلي مع حالة `started` مفصولة عن `dismissed`؛ لا يُسجَّل الطعام تلقائيًا ولا يتطلب حسابًا مدفوعًا.
4. في Food Log: إرشاد بجوار البحث، ثم اختيار نتيجة، ثم كمية داخل النافذة الموجودة، دون تغيير منطق `addReviewedMealItemsAtomically` أو حقول الحفظ الحقيقية. «تخطي» داخل نافذة الكمية يخفي التلميح لكنه لا يلغي اختيار الكمية ولا يحفظ شيئًا.
5. أثر أول وجبة: بعد المعاملة الحقيقية فقط، claim ذرّي من `ready` إلى `done`، وانفجار هندسي من 72 جزيئًا مع إيموجي أصلية إضافية، اختلاف اتجاهات وأحجام وتسارع، وتهنئة زجاجية تظهر وتختفي. لا يمنع اللمس ولا يفرض صوتًا ولا شراءً. وضع تقليل الحركة يعرض التهنئة بلا انفجار.
6. بمجرد استحقاق الاحتفال، ينشأ `experience.first_food_streak.v1 = ready` في عملية claim نفسها؛ يظهر تلميح متابعة الأيام لدى العودة إلى Home بعد وجود طعام حقيقي، ويختفي بعد «تخطي» أو «فهمت» ويُحفظ قرار الإخفاء محليًا.
7. بطاقة أول قياس أصبحت سطحًا زجاجيًا مع زر «تخطي» خارجه في الأسفل.

## اختبارات صريحة
- `test/features/dashboard/dashboard_first_use_guidance_test.dart` — التخطي، عدم تغطية Home، والانتقال إلى Food Log مع حالة `started`.
- `test/features/dashboard/first_use_context_coachmark_test.dart` — نجاح التفاعل، إمكانية التخطي، والعرض مع تقليل الحركة.
- `test/features/daily_log/food_log_first_use_coachmark_test.dart` — بحث Food Log واختيار الكمية، زر تخطي لا يغلق حوار الكمية، وفصل قرار الإخفاء لكل مالك.
- `test/features/dashboard/first_meal_celebration_visual_test.dart` — Claim مرة واحدة، إنشاء تلميح متابعة الأيام، واختفاء طبقة الاحتفال.
- اختبارات سلامة البيانات القديمة `test/data/repositories/first_food_milestone_commit_test.dart` **تبقى إلزامية**.

## لائحة الاعتماد المتبقية
- يجب أن ينجح على SHA واحد: Dart Format، Flutter Analyze، اختبارات أعلاه، اختبارات الإشعارات والرجوع، الخمس focused، والثماني full shards ثم aggregate، ثم Android Debug.
- مراجعة الصور على أجهزة iOS وAndroid حقيقية بالعربية والإنجليزية والضوء والظلام، عرض 320/390/430 وتكبير نص 1.8×، مع فحص لوحة المفاتيح وحوار الكمية وRTL.
- لا اعتماد تلقائي لصور Golden بتغيير baselines، ولا إعلان Play Reviewer أو رفع تعليق Google من كود QA.
- لا نشر نسخ ولا دمج PR11 قبل موافقة مالك التطبيق ونجاح البوابات.

## أفكار حركية مقترحة لاحقًا، **غير منفّذة**
- هالة تنفّس خافتة حول **الكابتن المعتمد نفسه** في AI Coach دون تغيير هويته.
- رسم خط الوزن الأخضر بسلاسة عند ظهور **عينات حقيقية فقط**، لا قيم وهمية.
- ملء عداد السعرات عند تحديث سجل فعلي، دون وميض أو إعادة بدء عند أي إعادة بناء.
- بريق اتصال صغير على إطار الساعة عندما تكون البيانات الصحية متصلة ومؤكدة.
- انتقالات Body Twin ببيانات صور فعلية متاحة، وليس صورًا مجهولة المصدر.
- حركة نجاح قصيرة عند إنجاز هدف حقيقي، مع احترام وضع تقليل الحركة.

## CI triage — first pass
- [Verify #38033226049](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38033226049): اكتشف ثمانية ملفات تحتاج Dart Format وتحذير analyzer واحد على BuildContext في `food_log_actions.dart`. تم تطبيق patch التنسيق الأصلي للمصدر والاحتفال واختبار Home وتصحيح حارس BuildContext. ما زالت بقية ملفات التنسيق بحاجة إلى إعادة تشغيل وتقرير patch الكامل.
- [Android debug #38033226046](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38033226046) كان قيد التنفيذ عند إضافة هذا التحديث؛ لا يُنقل نجاحه لآخر SHA.
- يرفض هذا التقرير اعتبار المصدر جاهزًا قبل وصول check أخضر **على SHA واحد**.

### الجولة الثانية من التحقق
- [Verify #38033657383](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38033657383): **Flutter Analyze PASS**، فشل Dart Format بسبب 5 ملفات، وخمس focused وثماني full لم تُشغّل بسبب بوابة المصدر.
- طُبّقت فروق Dart formatter الحقيقية للخمسة مع احترام اختبار تمرير Food Log، وأضيفت محلية التوجيه للعربية والإنجليزية والفرنسية والإسبانية والتركية، وحماية `BuildContext`.
- هذه الصفحة تسجل ما تم التحقق منه، **لا تشهد نجاح الكوميت الجديد مسبقًا**.

### الجولة الثالثة من التحقق
- [Verify #38034112091](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38034112091): **Flutter Analyze PASS (No issues found)**؛ تنسيق ملف اختبار 320px/RTL وحده كان متبقيًا وصُحح بالـpatch الحقيقي من Dart Format.
- طلبنا تحققًا جديدًا على نفس المصادر المعدّلة؛ نجاح Flutter Analyze على SHA سابق لا يساوي نجاح التحقق الجديد.

### الجولة الرابعة: نتائج فحوص المصدر واختبارات UI
- [Verify #38034374568](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38034374568): **Dart Format PASS / Flutter Analyze PASS** على SHA `e3b88875`، لكن **12 اختبار PASS / 4 FAIL** في الفحص المركّز الأول؛ الخمس focused والثماني الشاملة غير معتمدة.
- فشل اختبارين للنص العربي «تخطي»: `MaterialApp` في Fixture لم يعلن `supportedLocales` ولا delegates للعربية، لذلك أعاد Flutter لغة واجهة افتراضية مختلفة. أُصلحت بيئة اختبار العربية الحقيقية، دون تغيير النَص المنتج أو تخفيف توقع «تخطي».
- فشل اختبارا Food Log بسبب `AppLocalizations.of(context)!` حين أغفل اختبار الشاشة نفسها `AppLocalizations.delegate`، فانهار العرض قبل ظهور البطاقة؛ تمت إضافة delegate الحقيقي لنسختي الاختبار.
- تُعاد اختبارات المصدر أولاً ثم المجموعات المركزة، دون القول إن هذه الإصلاحات ناجحة حتى يثبت CI على HEAD الجديد.

### إصلاح التنسيق النهائي
- [Verify #38034812740](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38034812740): Dart Format أحمر في **مسافة بادئة واحدة** ضمن Fixture اللغة العربية، Flutter Analyze أخضر دون مشكلات. لم تُشغّل اختبارات المصدر بسبب الحاجز.
- طُبّق الآن فرق التنسيق كما أخرجه Flutter 3.44.6 حرفيًا. يعاد التحقق دون تخفيف أي شرط.

## Fifth CI pass
Verify run 38035105337: format and analyzer passed; 14 functional tests passed and 2 failed because the test finder chose multiple nested scrollables. The test now uses ensureVisible on the exact food action key. Android debug run 38035105330 passed for its older commit; it does not certify the latest HEAD.

## Latest source-gate correction
The first-use source gate for SHA `108cc7a4` passed Dart Format and Flutter Analyze. It passed 15 targeted tests but failed the lazy Food Log serving-guide test because `ensureVisible` could not locate an unmounted off-screen row. The test now drives the Food Log ListView's exact Scrollable using `scrollUntilVisible` rather than touching application code or weakening assertions. The new commit must still pass the strict source gate and all downstream checks.

## Source gate on 2b9a8435
The strict CI format gate identified one final Dart formatter change in the Food Log scroll finder. Flutter Analyze passed with zero issues. The exact SDK formatting patch was applied. The source now also triggers the milestone after successfully committed photo and quick-macro entries, without changing transactional writes. This branch still requires a fresh green source gate, all five focused suites, eight full shards, and native visual inspection before release readiness.
