# استمرار QA: إغلاق توافق اختبارات الدردشة وحالة بيئة التنفيذ

## مصدر التطبيق الذي تصفه الأدلة

- الفرع الوحيد: `qa/coach-community-next-20261005`.
- Application source: `6f4ccc1374d643678bee02db39951cab14c573a4`.
- Tree: `46672844386b5cfc97d6eed3bf3a7f1066312b8f`.
- هذا checkpoint يغيّر خمسة ملفات اختبار ووثيقتي دليل فقط. لا يغيّر مصدر التطبيق أو مدة dwell أو سياسة الحسابات.
- نتائج CI أدناه هي النتائج المكتملة على المصدر السابق المحدد؛ تصحيح الاختبارات الجديد ينتظر CI الخاص بكوميته، ولا يُعد ناجحًا بمجرد نشره.

## نتائج GitHub المكتملة على 6f4ccc1

[مسار R5](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37542235662):

| الفحص | النتيجة الفعلية |
|---|---|
| تنسيق الملفات المغيّرة | 353 ملفًا، 0 تغيير |
| التحليل الكامل | 0 ملاحظات |
| Entry persistence/privacy/retry/account lifecycle/routes | 276 PASS |
| حالات التقاط دخول Community | 4 PASS |
| Regression 0 | الجولة الأساسية 1731 PASS / 2 FAIL؛ المرور المتسلسل الإضافي 1 PASS |
| Regression 1 | الجولة الأساسية 1704 PASS؛ المروران المتسلسلان 4 و1 PASS |
| Regression 2 | الجولة الأساسية 1695 PASS؛ المروران المتسلسلان 1 و3 PASS |
| Regression 3 | الجولة الأساسية 1826 PASS / 4 FAIL؛ المروران المتسلسلان 11 و2 PASS |

[مسار QA العام](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37542235704) تجاوز checkout والتنسيق والتحليل، ثم سجّل 87 PASS / 2 FAIL في focused tests. المرحلتان الفاشلتان هما نفس اختباري visible read في regression، وليستا فشلين إضافيين مستقلين.

[مسار الالتقاط المرجعي Native](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37542235602) نجح. هذا نجاح تنفيذ الالتقاط، ولا يثبت مطابقة بصرية كاملة للمرجع.

## أسباب الحالات الست والتصحيح المحدود

1. اختبرا `community_visible_read_receipts_test.dart` كانا ينتظران استقرار الإطارات دون مرور مدة الظهور 600ms ثم التجميع 16ms. الـfixture يقدم الآن readback من المجموعة التي سُجلت لديه فعليًا، وينتظر المدة صراحة. بقيت شروط visible/offscreen/background، وأضيفت شروط أن fetch وحده لا يعلّم read وأن زمن الخلفية لا يُحتسب.
2. Fixture تخطيط New Message لم يعرّف مالكًا حاليًا، فأغلق owner guard الصحيح عناصر الرسالة الخاصة. يقدم fixture الآن هوية الاختبار عبر seam المستودع الموجود؛ لا تغيير في guard التطبيق. بقيت كل فحوص 25 لغة و160% والكيبورد ومواقع العناصر.
3. اختبار Epic9 يقرأ الآن `CommunityVisibleActivityScope` المستقل الذي صار ينفذ فحص الظهور، مع إثبات أن Chat يركّبه ويستدعي acknowledgement من خلاله. فحص التقاطع يتبع أسماء المتغيرات الحالية، ويثبت أيضًا clipping للشاشة وظهور 50% في البعدين. لا تضاف أسماء قديمة إلى التطبيق لإرضاء اختبار نصّي.
4. اختبارات accessible Send message و25-locale delegation تقرأ مكتبة `community_people_page.dart` مع أجزائها، حيث يوجد renderer الحالي. Assertions الخاصة بالتسمية والتوطين باقية دون تغيير.

دورة حياة عميل Supabase/JSON الخاصة بالـfixtures أصبحت في runner الحقيقي عبر setUp/tearDown، مع إزالة الصفحة قبل التخلص من العميل. لا يفتح ذلك اتصال Production؛ العناوين الوهمية للاختبار باقية.

عدد assertions في الملفات الخمسة: visible-read 7→10؛ visual contract 37→37؛ Epic9 25→30؛ accessibility 17→17؛ localization 79→79. لم تتغير partitions أو exclusions أو أي workflow في هذا التصحيح.

## عمل غذائي محلي مثبت لم يُدمج في GitHub بعد

آخر جولة مكتملة في `verification/food-native-flow/host-r9`:

- 99 PASS / 0 FAIL.
- Full flutter analyze: 0 issues.
- المصدر لم يتغير أثناء التحليل أو الاختبارات.
- Source digest: `4f2d44b62fd676a2ff63450eb8eea901a64beb65cf1f73b6f3e43ad21b2fe77a`.

هذه الأدلة تخص WIP في `bil_qa_food_flow`، ولا تخص source SHA 6f4ccc1 وحده. تشمل ربط native food review/commit/readback، تصحيح هوية الصنف والتاريخ بالعربية والإنجليزية، اختيار هدف التصحيح داخل وجبة متعددة، حفظ سياق الصنف بعد نقله إلى يوم/وجبة أخرى، وربط Personal BIL من قائمة Coach وسؤال التوضيح.

تثبيت viewport بعد اختيار جواب المستخدم هو تعديل التطبيق المحلي: ينتقل إلى نتيجة المراجعة الجديدة بعد الإجابة الصريحة. اختبار نقل صنف من وجبة متعددة ثم «نصفها» يثبت أن السياق التالي يخص وجبته الجديدة وأن الصنف الآخر لا يتغير.

مصدر التحضير وPersonal BIL المجمد محفوظ في `verification/food-native-flow/preparation-chain` و`verification/food-preparation/personal-ui-final-snapshot`. شريحة destination repository محفوظة في `verification/food-replacement-destination` وأثبتت سابقًا 80 PASS / analyze 0. يجب دمج الدلتا المملوكة فقط فوق HEAD الحالي؛ لا تنسخ worktree القديمة كاملة فوق عمل أحدث.

## عائق التنفيذ ونقطة الاستئناف

أعادت البيئة المحلية خطأً صريحًا:
`409 Conflict, environment_offline — Environment is not connected`.

لا تُعتبر كتابة fixture صور Coach الكاملة، أو تشغيل Moderation/Earn session52646، أو إصلاح Home/Activity الأخير، أو توسيع جرد القدرات ناجحة لمجرد أن الأمر أُرسل. حالتها تحتاج فحصًا قراءةً فقط عند عودة الاتصال.

آخر أدلة الشرائح الأخرى قبل الانقطاع:

- Moderation/Earn: 52 PASS / 0 FAIL وتحليل كامل 0، قبل بنك الترجمة وربط Earn→Composer الجديد ذي الست حالات. لم تُلتقط صوره الجديدة.
- Home/Activity: 19 PASS قبل تعديل mixin الأخير لعلاج analyzer lints؛ يحتاج تشغيل موحد جديد وفحص سياسة modal الملتقطة للحساب.
- أحدث فرع QA الفعلي يبقى هو المرجع قبل أي كتابة أو دمج لاحق، ولا يُسترجع إلى SHA أقدم.

الخطوات التالية: استعادة القراءة للملفات والعمليات المحلية، التحقق من آخر الكتابات المعلّقة، استكمال Flutter host food captures وقياسها بالمرجع الأصلي، دمج الشرائح المجمدة مع اتحاد ملفات التوطين، ثم فحوص focused/analyze/full portable regression على المصدر المدمج.

جرد AI Coach صنّف 25 canonical tools إلى 11 كتابة محلية بمعاملة، وكتابتي إعدادات تحتاجان CAS/journal/readback، وقراءتين، و9 مسارات تنقل، وأثر auth واحد. لا يُحسب فتح صفحة تنفيذًا لمهمتها. فجوات تالية مثبتة بالمصدر: Coach nutrition context ما زال يحتاج MealFoodEvidence/owner/name snapshot؛ استعادة Undo لغير الطعام بعد إعادة فتح المحادثة؛ تصحيح التاريخ/نوع الوجبة وحدهما؛ «مثل أمس»؛ وربط نتيجة الصورة بمراجعة Food V2 الفعلية بعد التحقق المحلي.

لا توجد شهادة 100% أو تصريح نشر. المراجع الأصلية تظل ملزمة، والالتقاط الحقيقي لا يصبح golden تلقائيًا.
