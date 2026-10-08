# BIL-00 — ملف التسليم الرسمي للمحادثة التالية
**Integration & Visual | 2026-10-08 | QA ONLY**

> اقرأ هذا الملف أولًا، ثم افحص HEAD الحقيقي قبل أي كتابة. هذه الوثيقة تفصل بين ما هو محفوظ في GitHub وما قيل عن تشغيل محلي سابق، ولا تعتبر اعتمادًا نهائيًا للإصدار.

## 1. المشروع والحدود الملزمة

- المستودع: **bilhealth-admin/Body-Intelligence**
- الفرع الوحيد المسموح عليه بالكتابة: **qa/coach-community-next-20261005**
- الأساس الأصلي للحزم الثمانية: \`1744788e6bfbdffc3a168bbaf36b3abf3e2c698a\`
- HEAD معروف قبل إضافة وثيقة التسليم: \`2985fc5f01a63fa063f123a6ecfc7e27e2a55f3f\` — **ليس ضمانًا لبقاء HEAD نفسه لاحقًا**.
- كوميت الدمج الحقيقي الموجود على GitHub: \`c653fb55485369da62915953ccc0c721dd4cc9ed\`
  - الرسالة: \`feat(qa): integrate BIL-01..08 on protected QA-only source\`.
  - الأب: \`425fa4c16043c5f325db7b89530050e3ae57fdcd\`.
  - Tree SHA: \`3e25fb7444c5c3da2252267918abeabceb624510\`.
  - [فتح كوميت دمج 01–08](https://github.com/bilhealth-admin/Body-Intelligence/commit/c653fb55485369da62915953ccc0c721dd4cc9ed)
- بعد الدمج، أضيف فقط ملف توثيق QA للتحفيز على تشغيل CI عند \`2985fc5...\`، دون تعديل تطبيقي:
  - \`docs/qa_next/POST_INTEGRATION_CI_SCOPE_20261008.md\`

**ممنوع منعًا باتًا:** لمس \`main\`؛ أي Production؛ نشر/ترحيل Supabase؛ رفع IPA/AAB أو builds للمتاجر؛ تغيير iOS build 35 / Android build 32؛ الأسعار، الدفع، الاشتراكات أو Trial. لا تنشر Universal Links على Production. لا تُعد تصميم Dashboard.

## 2. ماذا تم فعليًا وحُفظ؟

**المثبت من GitHub:** تم رفع تكامل BIL-01 إلى BIL-08 في كوميت واحد على فرع QA المسموح، ولم تضِع نقطة الدمج. التحقق من GitHub يثبت وجود الكوميت والفرع، **ولا يثبت وحده** اكتمال كل اختبار أو مطابقة التصميم.

الحزم التي دخلت التكامل:

| الحزمة | المجال | حالة التسليم عند الدمج |
|---|---|---|
| BIL-01 | Food & Personal V2 | موجودة في دمج 01–08؛ تأكيد التحقق الجديد مطلوب |
| BIL-02 | Media Bridge: image/barcode/voice | موجودة؛ تأكيد E2E مطلوب |
| BIL-03 | Settings & Privacy | موجودة؛ راجع عقود الحساب والخصوصية |
| BIL-04 | Health Commands | موجودة؛ راجع أولوية intent مقابل Food |
| BIL-05 | Activity, moderation, AI rewards/receipts | موجودة؛ كانت بها مشاكل formatter/compile وعولجت محليًا في جولات سابقة |
| BIL-06 | Circles | موجودة؛ راجع idempotency وتغير الحساب |
| BIL-07 | Community Channels | موجودة؛ يلزم إغلاق المطابقة البصرية |
| BIL-08 | Home & Profile | موجودة؛ كانت بها مشاكل compile/runtime وعولجت محليًا في جولات سابقة |

وثائق داخل المصدر المدمج يمكن الرجوع إليها: \`docs/qa_parallel/bil02/\`, \`bil03/\`, \`bil04/\`, \`bil05/\`, \`bil06/\`, \`bil07/\`, \`bil08/\`، إضافةً إلى \`docs/qa_next/\`. أبرز ملفات التسليم الفرعية: \`docs/qa_parallel/bil04/HANDOFF_AR.md\` و\`docs/qa_parallel/bil07/HANDOFF_AR.md\` و\`docs/qa_parallel/bil03/IMPLEMENTATION_EVIDENCE_AR.md\`.

### سلوكيات جوهرية لا تفقدها أو تتراجع عنها

1. **Dashboard مجمّد بصريًا بالكامل:** لا تغيير تصميم أو ترتيب أو أيقونات أو أبعاد أو خطوط أو مسافات أو بطاقات. فقط إصلاح وظيفي/بيانات دون تغيير الشكل. إصلاح \`NutrientDashboardEvidence.total()\`: يجب الاحتفاظ بمجموع المكونات ذات evidence المعروفة، مع \`partial/complete\` صادق، بدل إعادة \`null\` لمجرد أن عنصرًا واحدًا ناقص. افحص fiber/potassium/sodium/sugar وغيرها. لا تخترع قيمًا.
2. **Food Search:** زر نتيجة الطعام \`+\` دائري فقط؛ **ممنوع الرجوع إلى \`+ Add\`**. تحقق من القطر والأيقونة وRTL/LTR وverified badge وserving/calories والضغط. الإصلاح السابق دخل أولًا في \`b1223c8f6e96e7c42cefa667d0604dcfe7df09a0\`.
3. **Customize Today:** المطلوب \`Log out / تسجيل الخروج\` لا Log in. الإصلاح السابق في \`75c492c187ee6bf2d0facefb7a1abc912e038d77\`. حافظ على تسجيل الخروج والتحقق من owner/session والتوجيه.
4. **Exercise JSON:** لا تُعرض \`{"kind":"custom_workout_routine"...}\` نصًا للمستخدم. أظهر اسم الروتين فقط مثل \`CV\`، واحتفظ بـJSON/id/movementIds داخليًا، مع فصل الملاحظات اليدوية. البيانات المشوهة لا تظهر كواجهة. الإصلاحان الأصليان \`f8a0362...\` و\`6949a88...\`؛ تحقق منهما ضمن المصدر المدمج.
5. **AI Coach:** تسجيل الطعام والأوزان يجب أن يكتب فعليًا إلى قاعدة السجل/الداشبورد مع إيصالات صادقة وUndo دون تكرار؛ تأكيد permission/owner/date. طلب «استعرض سجل أوزاني» لا يجب أن يُختطف بواسطة food intent. يحترم الوحدات وتقديرات الكميات المعلمة بوضوح.
6. **Community / Reviews / Circles:** خصوصية المستخدم، fetch/pagination، read receipts وidempotency، تغيّر الحساب A→B→A والطلبات المعلقة. لا تضعف العقود لإرضاء الاختبارات.
7. **BIL Code / WhatsApp:** رابط مشاركة HTTPS قابل للنقر من نطاق BIL مع رمز عضو عام، وليس \`bil://community/member/...\` وحده. افتح العضو عند تثبيت التطبيق، وصفحة تحميل عند عدم التثبيت، **بعد** تجهيز وربط Universal Links بموافقة لاحقة. لا تستخدم رابطًا مزيفًا؛ حافظ على QR/deep-link safety.
8. **First-use UX:** coachmarks وempty states وonboarding وعناصر صغيرة وحركات واحتفالات first-success فقط، بلا إزعاج متكرر.

## 3. نتائج اختبارات الجولات المحلية السابقة — أدلة مرحلية فقط

هذه أرقام أُبلغ بها في سجل العمل السابق وليست شهادة حديثة من GitHub على آخر HEAD؛ **لا تنسبها آليًا لكوميت التسليم الجديد**:

- اختبارات الحزم الثمانية مجتمعة على شجرة دمج محلية: **632/632 PASS**.
- \`Flutter Analyze\`: أُبلغ سابقًا عن \`No issues found\`، وفحص تنسيق 197 ملف Dart وحارس حجم ملفات Dart نجحا.
- جولات مستقلة مبلّغ عنها: BIL-01 **21/21**؛ BIL-02 **162/162**؛ BIL-03 **34/34**؛ BIL-04 **239/239**؛ BIL-06 **93/93**؛ BIL-08 **12/12**. هذه **جولات أو مجموعات مختلفة** ولا تجمعها حسابيًا لإثبات 632.
- إصلاحات مبلّغ عنها: widget flow للإضافة/إلغاء الطعام بعد تغيّر الحساب، Voice/Drift timers، أولوية Health intent، Activity/moderation، Review pagination، Circles idempotency، BIL Code link validation، وعرض الصور داخل المساحات الصغيرة.
- تم التقاط صور Flutter فعلية وجرى استرداد خطوط Material/Cupertino وملفات Goldens الأصلية لبيئة اختبار محلية. **التقاط screenshot واختبار widget ناجح لا يساوي pixel/reference parity.**

لا تقل «انتهيت» بناءً على هذه الأرقام التاريخية وحدها. اقرأ CI الجديد أولًا وأصلح الإخفاقات المثبتة.

## 4. CI الحالي — المرجع الحي الذي يجب فحصه أولًا

- Run ID: **37766088154**
- الاسم: **BIL next Coach Community QA ONLY**
- الرابط: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37766088154
- SHA تحت الاختبار: \`2985fc5f01a63fa063f123a6ecfc7e27e2a55f3f\`
- عند إعداد الوثيقة بتاريخ **2026-10-08**: \`in_progress\`، في وظيفة \`flutter-checks\` داخل خطوة **Install pinned Flutter**؛ **لا توجد نتيجة نجاح نهائية بعد**.
- كوميت الدمج \`c653fb...\` نفسه لم يظهر عليه تشغيل QA تلقائي؛ جرى إنشاء \`POST_INTEGRATION_CI_SCOPE_20261008.md\` لتحفيز التشغيل على descendant مطابق للتطبيق.
- بعد إضافة وثيقة التسليم الحالية سوف يتحرك HEAD بكوميت توثيق إضافي؛ لذلك **اقرأ HEAD الجديد، والـruns الخاصة به أيضًا، ولا تخلط نتائج run سابق بمصدر معدّل**.

مصفوفة CI القائمة تتضمن: Flutter version 3.44.6؛ locked pub dependencies؛ Dart format؛ Flutter analyze؛ focused tests؛ architecture/performance; أربع \`portable-regression\` shards؛ \`flutter-visual-capture\` للصور الفعلية؛ \`isolated-sql-contracts\` على PostgreSQL تجريبي. أنظر ملف workflow: \`.github/workflows/bil_next_coach_community_qa_only.yml\`. الاختبارات على CI لا تبرهن وحدها اختبارات الهاتف الحقيقي.

## 5. ما بقي — ترتيب التنفيذ الدقيق

1. **HEAD/branch/CI أولًا:** احصل على HEAD الحالي؛ تأكد أنه descendant لكوميت دمج \`c653fb...\`، وأن الكتابة على فرع QA المحدد وحده. اقرأ jobs/logs/artifacts للـRun 37766088154 ولأحدث run إذا ظهر. لا تعتبر \`queued\` أو \`in_progress\` نجاحًا.
2. **إغلاق regression:** حل أي فشل في \`format/analyze/focused/architecture/performance\` ثم تأكيد **4/4 regression shards** على مصدر موحد؛ لا تزيل اختبارات أو تقلل assertions أو تغيّر الحدود لتصبح خضراء.
3. **إغلاق SQL المحلي:** تأكد من jobs والـfixtures المعزولة على PostgreSQL17، لا Supabase Production. راجع notification/publish/privacy والمخططات والدوال الجديدة. أي migration لا يُنفّذ على بيئة حية.
4. **تثبيت الحزمة المصدرية:** إذا ظهرت فروق/إصلاحات إضافية، أنجزها على الفرع المسموح فقط مع تحقق HEAD قبل الكتابة، ثم أعِد CI على الكوميت النهائي. لا تعتمد شجرة محلية قديمة فوق HEAD تحرك.
5. **Visual inventory:** مرّ على كل صفحة خارج Dashboard/AI Coach/Community، واربطها بصور ZIP المرجعي نحو 144–146 صورة MyFitnessPal (الاسم في Library: \`مقترح جديد .zip\`). طابق typography/spacing/row/cards/radius/shadows/search/tab/sheet/buttons/icons/RTL/dynamic type/empty/loading/error/onboarding/coachmarks/micro-interactions. الهوية والشعار BIL، لا MyFitnessPal.
6. **استثناءات المراجع البصرية:** AI Coach وCommunity يتبعان صور BIL المعتمدة **لا** MyFitnessPal:
   - \`AI_COACH_APPROVED.png\` SHA256 \`07f25ba0fffc661e5232a4fba6365ee3ff96cbea69636c2672b97f4fafce63d0\`.
   - \`COMMUNITY_APPROVED.png\` SHA256 \`db67d1c6bb1f4ecd3c539ada3de72a980c610b7c1d2331c4796b7fa27e3bbea4\`.
   - Quick Add يتبع مرجع BIL الأصلي.
7. **Visual evidence:** التقط screenshots **Flutter فعلية** لكل تدفق أساسي والحالات Arabic/English، RTL/LTR، dark/light، أحجام النص، loading/empty/error، ثم مقارنة مرئية/فرق مع المرجع الصحيح. لا تستبدلها بصور مولّدة. لا تعلن أن 144 صورة مرجعية طوبقت إذا لم تُفحص فعليًا.
8. **إغلاق acceptance:** لا تكتب «انتهيت» إلا مع: 01–08 مدموجة على فرع QA، 05/08 مقفلتين، CI/format/analyze/tests/SQL أخضر، Dashboard لم يتغير بصريًا، polish مكتمل، وربط المراجع مع screenshots/diffs مثبت. اتبع أي تعليمات لاحقة صريحة من المستخدم بشأن التسليم.

## 6. ملاحظات أمان مهمة

- أي automation/workflow أو commit QA-only إضافي ليس تصريحًا بتغيير Production. لا ترفع builds؛ لا تفتح deployment job.
- أي تعديل لفحص معماري أو harness يجب أن يحافظ على معنى الاختبار، لا يخفي خللًا.
- لا تستخدم أو تنشر font files للمستخدم؛ الأصول المستردة للاختبار محليًا فقط.
- احترم خصوصية البيانات والبيئات الاصطناعية، ولا تستخدم بيانات مستخدم حقيقية في screenshot.
- إذا توقفت جولة ChatGPT فلن يستمر العمل تلقائيًا؛ لا تدّعِ تشغيلًا بالخلفية أو إنجازًا لم يحصل.

## 7. رسالة جاهزة للصق في المحادثة التالية

> أنت BIL-00 · Integration & Visual. تابع من ملف GitHub:
> \`docs/qa_next/BIL_00_INTEGRATION_HANDOFF_2026-10-08_AR.md\`
> على المستودع \`bilhealth-admin/Body-Intelligence\` والفرع الوحيد \`qa/coach-community-next-20261005\`.
> اقرأ HEAD الحالي أولًا وتحقق من امتداده لكوميت الدمج \`c653fb55485369da62915953ccc0c721dd4cc9ed\`.
> لا تبدأ دمج الحزم الثمانية من الصفر؛ الدمج موجود على GitHub. افحص CI run \`37766088154\` وأحدث run، ثم أغلق regression وSQL وقم بالجرد والمطابقة البصرية مع حفظ Dashboard كما هو.
> ممنوع main/Production/Supabase deploy/app-store builds وتغيير iOS35/Android32 والأسعار والدفع وTrial.
> أرسل نتائج مؤكدة وروابط Evidence، ولا تقل «انتهيت» قبل الإغلاق الكامل.

**الخلاصة:** الدمج على GitHub **موجود ومثبت**. القبول النهائي والـpolish البصري **غير مثبتين بعد**. نقطة الانطلاق هي HEAD الجديد + نتائج CI الفعلية، وليست إعادة العمل من الصفر.
