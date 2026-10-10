# BIL 2026 — التسليم الموحّد الشامل والنهائي للمحادثة القادمة
**10 أكتوبر 2026 — وثيقة QA فقط، وليست شهادة نجاح نهائي أو تصريح نشر.**

## نقطة الاستلام المؤكدة
- المستودع: \`bilhealth-admin/Body-Intelligence\`، فرع العمل الوحيد: \`qa/bil-quality-ux-integration-20261009\`، [PR #11](https://github.com/bilhealth-admin/Body-Intelligence/pull/11) **Open / Draft / Unmerged**، قاعدة \`qa/coach-community-next-20261005\`.
- **آخر كوميت كود قبل هذا التوثيق:** \`405a2ae503aafbde20814280a846733fcb288135\`، ثم يأتي كوميت وثائق جديد يجب قراءته كـHEAD حديث.
- PR #10 QUALITY: [المسودة](https://github.com/bilhealth-admin/Body-Intelligence/pull/10)، الفرع \`qa/bil-stability-flicker-data-20261008\`، HEAD \`386d00a65943c3394e99d5e37de98cc8a43ddc20\`، لم يُدمج. PR #9 UX: [المسودة](https://github.com/bilhealth-admin/Body-Intelligence/pull/9)، الفرع \`qa/bil-premium-visual-2026\`، HEAD \`bccce73cae261e867cce6bf4a5ec08e58c597e62\`، لم يُدمج. **لا تعُد لدمج هذه الفروع أو حزم BIL-01…08 مرة ثانية**؛ العمل الموحد في PR11.
- ممنوع \`main\`، Supabase Production، السعر/الدفع/Trial، المتاجر/استئناف Google، تغيير iOS build 35/Android code 32، دمج PR، تبديل شريط التبويبات الخمس، تخريب Log Food، استبدال كابتن AI Coach المعتمد، أو خفض شروط اختبارات Golden.

## التقارير القديمة الرسمية الواجب قراءتها كاملة
- [تسليم QUALITY الأول PR10](https://github.com/bilhealth-admin/Body-Intelligence/pull/10#issuecomment-6079115396).
- [تسليم QUALITY + UX الثاني PR10](https://github.com/bilhealth-admin/Body-Intelligence/pull/10#issuecomment-6079189662).
- [تسليم PR11 الأول](https://github.com/bilhealth-admin/Body-Intelligence/pull/11#issuecomment-6089010807).
- \`docs/qa_next/BIL_20261009_DASHBOARD_GOOGLE_FIRST_USE_UNIFIED_HANDOFF_AR.md\`.
- \`docs/qa/BIL_PR11_GOLDEN_TRIAGE_20261009.md\`.
- \`docs/qa_next/BIL_20261010_FIRST_USE_STATIC_SOURCE_REVIEW_AND_GOOGLE_STATUS_AR.md\`.
- \`docs/qa_next/BIL_20261010_COMMUNITY_NOTIFICATION_BACK_NAV_AUDIT_AR.md\`.
- **الملحق الجديد:** \`docs/qa_next/BIL_20261010_FULL_SHARDS_90_FAILURES_AR.md\` يسرد **كل حالة فشل في الثماني مجموعات بأسماء الاختبارات وروابط وظائف GitHub**.

## المنجز القديم: QUALITY + UX
1. **AI Coach:** تثبيت هندسة الرد المتدرج وصف الإعجاب/المصادر/الأيقونات أثناء الكتابة، وتثبيت التمرير، وتحسين Settings والـRetry/rollback، مع اختبارات تغطية؛ فحص iPhone فعلي ما زال مطلوبًا.
2. **Customize Today:** معالجة وميض مفاتيح التخصيص وDone Editing عبر pending optimistic state وrollback. **Community:** تثبيت Publish ومنع النشر المكرر وتحسين مفاتيح الرسائل؛ Source/Widget tests ليست شهادة Production.
3. **Connected Health / Sleep:** معالجة عرض JSON/Map خام بدل اسم مصدر صحي موثوق ومترجم، وتحسين التسميات وتجربة الخطأ/إعادة المحاولة. **التنقل/اللغة:** Home/الرئيسية بدل Dashboard المرئية، مع إبقاء route \`/dashboard\`، وفحوص 25 لغة.
4. **الواجهة:** أيقونات SF-style/Material مسطحة اختيارية بلا هالات/ظلال في More/Community/Wellness وغيرها، ولا تُفرض أيقونات على الصفوف التي تكفي فيها الكتابة والسهام. More تم تبسيط خطه وأقسامه وإظهار Premium Link بشكل ذهبي صغير.
5. **اختبارات وبنية:** فحوص True Free server fixtures للاختبارات فقط، وصور Splash وأعمال Coach/Community/Transaction. صار CI: تنسيق + تحليل → **5 مجموعات مركزة متوازية** → **8 شظايا Flutter متوازية عند نجاح الخمس** → بوابة \`flutter\` جامعة. لا تقل إن كل الاختبارات نجحت تاريخيًا.
6. جرد UX التاريخي: **146 صورة مرجعية، 116 مسارًا، 20 مرجعًا محميًا، 125 حالة تحتاج تحسينًا، صورة بلا مقابل؛ لم يتم إثبات 146/146 مطابقات على أجهزة حقيقية**. المصدر \`docs/visual_2026/reference_146_inventory.csv\`.

## المنجز في PR11 الحالي: Home وFirst Use
- \`08631043\`: عداد السعرات كمرجع \`IMG_9648/9649\` (مستهلك/هدف/متبق أو «زيادة» وخط مائل)، بصورة مدرب BIL الحقيقي نفسه في AI Coach، ساعة صحية معدنية بأرقام مصدرها حقيقي، وزن بخط أخضر وظل وتغير فترة عند ثبوت القياسات، Body Twin يندمج، Discover بصورة واحدة \`BoxFit.contain\`.
- \`d43fe95b\`، \`b4b4253\`، \`47edaae3\`: دليل «سجل أول وجبة» و«ابحث عن الطعام» **غير إجباري وبزر Skip مستقل في كل خطوة**، وتفضيل لكل مالك؛ الاحتفال مرة واحدة **بعد الحفظ الذري** في \`MealRepository\`، ويشمل Coach وQuick Macros والوصفات، ولا يعيد الاحتفال عند التعديل/الحذف.
- \`a9ef85f\`، \`836bf3e\`: إصلاح \`nullable calories\` والتنسيق. \`7c30442\`، \`b1f5f7d\`: اختبارات أول وجبة/فشل الحفظ/Skip/Google reviewer.
- \`6e3a4a5\` و\`8bd8a4f\`: منع بطاقة الإرشاد من تغطية السعرات والوزن، وإظهارها داخل Home القابل للتمرير مع اختبار عدم التراكب. \`66c3ba0\`: Fixture Screenshots للمستخدم العائد لا يُظهر تعليم أول استخدام. \`5d703bc\` و\`6c2e133\`: رموز احتفال رسومية بدل emoji قد تظهر مربعات، مع Respect Reduce Motion. **هذه تغييرات QA مرئية، لم تُعتمد بصريًا على 146 صورة جهاز حقيقي.**

## Google Play — أحدث حالة رسمية موثّقة
- 8 أكتوبر 2026، 10:01 صباحًا: **Rejected** لـAndroid code 32 لأن محتوى التطبيق محجوب عن المراجع بـPaywall.
- 8 أكتوبر، 7:38 مساءً: قرار أحدث **Suspended / Removed** بسبب \`Enforcement Process\` و\`Repeated app rejections\`. **لا دليل على إعادة التفعيل**.
- QA يحتوي إصلاح Verified Entitlement/Goals/Gates وتهيئة reviewer fixtures، لكنه **ليس دليلًا على مرور حساب مراجع حقيقي أو استعادة Google Play**. لا استئناف ولا نسخة متجر دون إذن صريح. راجع \`docs/google_play_preparation/BIL_GOOGLE_SUSPENSION_20261008_APPEAL_READINESS_AR.md\`.

## نتائج CI الحاسمة (لا تخلط الكوميتات)
- في \`6c2e133\`: **145 إخفاق مقارنة صورة** (88 Production + 32 Data + 25 Store)، رغم نجاح التحليل والفحوص الوظيفية المركزة.
- نُقلت هذه الصور من Captures Windows Flutter QA إلى مرجع الاختبار على نفس فرع QA، مع Manifest لـ145 SHA-256: \`docs/qa_next/BIL_20261010_REVIEWED_GOLDEN_SHA_MANIFEST.json\`، مصدر \`38003344769\`، مهمة النقل [38007710062](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38007710062) SUCCESS؛ الصور القديمة باقية في Git.
- على \`1133a0cc\`: [verify #38007903223](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38007903223) **source-checks PASS، والمجموعات الخمس المركزة PASS جميعها، وAndroid Debug PASS**؛ لكن **الثماني الشاملة FAIL جميعها**: **8303 نجح / 90 فشل / 3 تخطت**. بوابة Flutter الجامعة FAIL.
- **تحذير مصداقية:** نجاح 145 مقارنة بعد نقل الصور الحالية إلى Master الجديد يثبت تطابق محاكي CI مع تلك الصور فقط، **لا يثبت مطابقة التصميم المرجعي الذي وافق عليه المالك أو جودة أجهزة Apple/Google**.
- تفاصيل الـ90 موزعة على 24 ملف اختبار في الملحق الجديد؛ أهمها 25 توقعًا قديمًا في \`dashboard_reference_nutrition_cards_test.dart\`، 12 في \`dashboard_polish_layout_review_test.dart\`، 13 Weekly Report Goldens، 9 Onboarding Goldens، **6 اختبارات سلامة غذائية عالية الأولوية** (4 \`coach_food_commit\` + 2 \`coach_meal_commit_boundary\`)، وWatch/RTL/Localization/More/Subscription/Architecture. **لا تعالج اختبارات سلامة الغذاء بإضعافها.**

## آخر إصلاح: الرجوع من الرسائل والموافقات وإشعارات المجتمع
- \`c447fb7\` ثم \`405a2ae\`: إدخال \`BilExternalRouteNavigator\` لحفظ الصفحة السابقة عند فتح الإشعارات والروابط الآمنة، وأزرار \`CommunityReturnButton\`/\`BilSafeReturnButton\` لصندوق الرسائل والمحادثة والموافقات والأصدقاء والملف الشخصي وصفحات Community والمساعدة/الخصوصية؛ منع ترك المستخدم بلا رجوع عند الفتح البارد. جرد 42 ملف صفحة/عرض Community مع اختبارين جديدين للـRouter وتدقيق للمسارات.
- **هذه الإصلاحات مرفوعة لكنها لم تجتز بوابة التنقل حتى الآن**. أحدث [verify #38028424488](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38028424488) على \`405a2ae\`: **Dart Format وFlutter Analyze PASS؛ 26 اختبار تنقل نجح و3 فشلت**:
  1. Cold private message: المتوقع \`/community/chat/<uuid>\`، الفعلي \`/community/messages\`.
  2. Warm friend notification: المتوقع \`/community/connections\`، الفعلي \`/settings\`.
  3. Cold external alias: المتوقع \`/connected-health\`، الفعلي \`/dashboard\`.
- افحص توقيت \`router.go(parent)\` ثم \`router.push(target)\` والتزامن مع GoRouter، لكن **لا تفترض أن هذا السبب مؤكد**؛ أصلح مع Fixture واقعي ويجب أن تنجح حالات cold/warm/Back. بسبب فشل المصدر، اختبارات الـ5 والـ8 **SKIPPED على 405a**، لا تورّث نجاح 1133.
- [Android Debug #38028424514](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38028424514) **SUCCESS مؤكد على كود HEAD 405a2ae**؛ هذا بناء APK Debug فقط، وليس جهازًا حقيقيًا أو إصدار متجر.

## ما بقي — أولوية الاستكمال
1. **P0:** حل **3 إخفاقات تنقل** ومراجعة الرجوع عند فتح إشعار قبول صداقة/رسالة من تطبيق مغلق/خلفية/مفتوح، ثم العودة Inbox→Community/Home أو للشاشة السابقة، iOS swipe/Android Back. لا فقد مسودات ولا تجاوز Allow-list.
2. **P0:** معالجة **6 اختبارات ذرية غذائية** (owner، journal، closed day، retry/rollback) دون استخدام Production.
3. **P1:** تصنيف وإصلاح **90 إخفاقًا شاملًا** واحدًا واحدًا من الملحق: حقيقة السعرات/القيم المجهولة أولًا، RTL/25 لغة/الساعة ثم صور Weekly/Onboarding/Benchmark التي لم تكن ضمن الخمس.
4. **P1:** ضمان نجاح **Format/Analyze → اختبارات الرجوع وFirst Use/Reviewer → الخمس المركزة → 8 shards → aggregate flutter** على **HEAD واحد**، ثم Android Debug. لا تعطل اختبارًا أو تحدث Golden جماعيًا.
5. **P2:** توثيق 146 مرجعًا بصور حقيقية على أجهزة Apple/Android، فحص Staging لحفظ Coach وCommunity، رحلة المراجع الحقيقية وحالة Play Console قبل أي استئناف أو نشر. بقاء PR11 Draft حتى موافقة المالك.

**لا تعِد العمل من الصفر. لا دمج أو نشر. فرّق بين مرفوع ومختبر ومقبول على جهاز.**
