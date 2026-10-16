# BIL — أمر بناء المرشحين الموقعين Android 33 / iOS 36

تاريخ القرار: 2026-10-16. المالك أذن صراحة ببناء AAB 33 وIPA 36 ورفع iOS إلى TestFlight، دون إرسال App Review أو Google Appeal أو نشر Google.

## أدلة القبول الهندسي للبناء

- الشاملة الموحدة والتحليل: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38826857261 على 36c46e353fafcc3b01451b5fbc122fb1b4875aae؛ 9889 نجاحًا و0 فشل/خطأ/تخطٍ؛ المصدر ثابت.
- بوابة السياسات: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38830053505 على f4a05de5bf9a919f1597199d054d13bda7e0d87a؛ نجحت الأدلة التلقائية والسبعة Goldens. ليست شهادة قبول سياسات نهائية؛ Full Lint/Insights ما زال vendor-blocked.
- CodeQL: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38830053553 ناجح.
- بدء Android المعزول: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38826857225 ناجح، وليس إثبات تشغيل حساب مراجع أو شراء.
- فرق الشاملة إلى f4a05de5 محصور في tooling إصلاح تجهيز wrapper ومهمتي manifests، لا كود التطبيق أو اعتمادياته. التحديث الحالي يجمّد ملفات المرشحين ويحدّث اختبارات حالتها فقط.

## العقود والتوقيع

تُربط متغيرات المصدر للمنصتين بنفس SHA النهائي وتُربط كل وثيقة manifest ببصمة SHA256 مستقلة. الحزم تبقى 1.0.0 مع build 33 / 36 بواسطة مدخلات البناء الصريحة. لا تغيير pubspec أو السحابة أو حسابات حقيقية. أسرار التوقيع وASC المطلوبة موجودة بأسمائها؛ صلاحيتها الفعلية لا تثبت قبل تنفيذ البناء.

الصفر في UNRESOLVED_REVIEW_COUNT يخص مراجعة تجهيز المصدر لبناء مرشح؛ لا يغلق خمس قضايا Google السابقة أو اعتراض Apple أو فحوص الجهاز. قبول المرشح للبناء ليس قبول نشر. STORE_SUBMISSION_APPROVED وPRODUCTION_RELEASE_APPROVED كلاهما NO.

تحقق Workflow الإجباري من AAB و16KB وشهادة رفع Play، ومن IPA والتوقيع وملف provisioning وأهلية التوزيع والتحقق عبر ASC قبل رفع TestFlight يبقى كما هو. بصمات الحزم والشهادات ونتائجها تحفظ في artifacts على GitHub؛ لا أرقام بصمات مختلقة قبل إنتاج الحزم.

## السحابة والمتبقي

دليل Production: BIL_20261016_PRODUCTION_FINALIZATION_AR.md؛ 229 ترحيلًا حيًا، 14 في الدفعة، وأربع دوال منشورة متطابقة مع المصدر بالقراءة اللاحقة. الحسابات والأدوار موثقة في BIL_20261016_REVIEW_AND_OWNER_TEST_ACCOUNTS_ALIGNMENT_AR.md. لا يعاد النشر هنا.

بعد إنتاج الحزم يلزم: جلسات مراجعين فعلية، StoreKit/Play Sandbox، HealthKit/الأجهزة، مطابقة App Privacy/ATT وموافقة مزود AI مع سلوك الحزمة، وحالة Console والتعليق. هذه BLOCKED/NOT YET TESTED وليست PASS. لا تُعتبر قضية Apple أو Google مغلقة رسميًا.

لا إعادة شاملة تلقائية لهذه التغييرات الوثائقية/الاختبارات فقط. تُشغّل الاختبارات المركزة أولًا، ثم البناء الموقع الموجود مع بواباته دون تعطيل فحوصه. إذن TestFlight لا يشمل إرسال التطبيق للمراجعة أو توزيع Production.

التحقق المحلي لتحديث التجميد: 16/16 اختبارًا مركزًا ناجحًا، وتنسيق Dart وفحص whitespace ناجحان. الدليل الخام محفوظ محليًا في build/qa/policy-gate-20261015/final-build-prep-focused.log.
