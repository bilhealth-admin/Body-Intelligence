# BIL 2026 — تسليم P0: مصدر الغذاء المحلي الموثق ومنع تكرار سجل AI Vision

**النطاق:** فرع `qa/bil-quality-ux-integration-20261009` فقط، PR #11 Draft. لا دمج، ولا نسخ متاجر، ولا Supabase Production، ولا تغيير اشتراكات أو AI Boost أو Trial.

## دليل الفشل قبل هذه الدفعة
- [GitHub P0 #38049330447](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38049330447) على `5f174189`:
  - Source Format/Analyze **PASS**؛ first-food, food owner/atomic, coach meal owner, Premium Vision review, Arabic Vision, render capture, architecture, Coach image source **PASS**.
  - `coach-photo-bridge` **FAIL** بست حالات و6 ناجحة في نفس الملف. خمسة إخفاقات كانت لأن زر اختيار `Food.verified=false` لم يفعّل رغم سلامة immutable modern `FoodBasisEvidence` ذي المصدر `coach_food_v2:label`. والحالة السادسة كانت `find.text` يطابق العنوان والصف معًا بعد اعتماد Premium UI، بدل تحديد ListTile الحقيقي.
  - النجاح البرمجي ليس شهادة تصوير على جهاز حقيقي.

## إصلاح مصدر الغذاء
- معايير شاشة Vision العادية لم تتغير: **المطابقة العامة تتطلب Food.verified**.
- Coach يستلم `CoachMediaCatalogEntry.fromLocalFood` الذي يتحقق مسبقًا من قاعدة محلية حقيقية، وصاحب الحساب، ومصدر evidence، ومنع المصدر التقديري/الفاسد/غير المملوك.
- يعبر `evidenceOwnerKey` فقط من Coach إلى حوار المطابقة. تسمح واجهة Premium بمصدر غير `verified` **فقط إذا** كانت `FoodBasisEvidence.read(food, ownerKey: evidenceOwnerKey)` حديثة وسليمة. القيمة لا تُستنبط من الصورة ولا تُرفع حالة `verified`.
- يظهر في القائمة وصف صريح أن مصدر الملصق الغذائي **غير موثّق كتالوجيًا**؛ مصدر وأرقام الغذاء يحتفظان بوصفهما الأصلي. مسار أقل من 320px يستعمل نفس قاعدة الموافقة، فلا توجد ثغرة fallback.
- `coach_media_page_overlay_test.dart` يختار صف `ListTile` الحقيقي، لا أول نص مطابق، ويحافظ على اختبارات إلغاء/قراءة فقط/تغيير المالك/إعادة المحاولة.

## منع التكرار الدائم عند تسجيل نفس صورة الوجبة
- إضافة المعامل الاختياري `visionRequestId` إلى `MealRepository.addReviewedMealItemsAtomically`، واستدعاؤه من **Food Log وDaily Log** برقم `MealImageAnalysis.requestId` القادم من استجابة التحليل الصالحة.
- إن لم يُقدّم رقم صورة، يحتفظ الإدخال اليدوي والسابقان بسلوكهما الأصلي: لا تمنع عملية حفظ جديدة مختلفة.
- داخل **نفس معاملة Drift** الخاصة بالوجبة، يُقرأ مفتاح `visionMealCommitV1.<hashedOwner>.<hashedRequestId>` ويُتحقق من بصمة اليوم، نوع الوجبة، العناصر، الكميات والوحدات. إعادة نفس الطلب تعيد receipt الأصلي **دون إنشاء صف جديد**. تغيّر مدخلات الطلب نفسه أو تلف التفضيل يُرفض قبل أي كتابة. الصفوف والتفضيل يلتزمان معًا أو يتراجعان معًا.
- يدعم الاختبار: إعادة استعمال repository، طلبين متزامنين بنفس id، منع نفس id بكمية مختلفة، وفشل وسط دفعة لا يترك بيانات أو receipt. تُحفظ اختبارات Closed Day/Atomicity/Owner التقليدية كاملة.
- إذا فشل العثور على سجل غذائي موثوق في Food Log، يظهر `visionCopy.text('no_match')` بدل التجاهل الصامت. Daily Log كان يعرضه بالفعل.

## اختبارات قبول ملزمة على SHA النهائي
- Flutter Format/Analyze الكامل؛ اختبارَي Coach bridge ومطابقة العربية ومراجع Vision المصدرية؛ أربعة اختبارات durable replay الجديدة؛ 8/10 P0 targeted؛ test/architecture_source_file_size_guard_test.dart؛ اختبار أول وجبة وعزل المستخدم. **لا ادعاء نجاح قبل صدور CI على SHA الذي يحتوي هذا الكود**.
- بعد اجتياز P0، توسيع محدد إلى 5 focused + 6 broad؛ تشغيل 8 shards فقط عند الخضرة، وبناء iOS 26 SDK/Android على SHA نفسه. الـ25 حالة Vision واللغات والـGoldens والأجهزة الفعلية لا تُعتبر مغلقة من هذه الدفعة وحدها.

**مرجعية التصميم:** لا تعديل Dashboard المحمي، ولا الأيقونات السفلية الخمس، ولا هوية كابتن AI Coach، ولا سياسة الخصوصية/رفع الصورة.
