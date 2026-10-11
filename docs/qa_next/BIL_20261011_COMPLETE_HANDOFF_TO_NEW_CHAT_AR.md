# BIL 2026 — التسليم الرسمي الشامل إلى المحادثة الجديدة
**التاريخ: 11 أكتوبر 2026. وثيقة حفظ حقيقية في GitHub، ليست شهادة جاهزية.**

## 1) خريطة الفروع — اقرأ HEAD الحالي قبل أي تعديل
المستودع: bilhealth-admin/Body-Intelligence

| المرجع | SHA المثبت وقت التسليم | الحالة |
|---|---|---|
| QA الرئيسي — PR #11 | d073dcb39c4d4ba5cef856a5d39935ca1f7de1ca | qa/bil-quality-ux-integration-20261009، Draft، غير مدموج |
| مصدر نجاح Full التاريخي | c1f1f47a627169fb692763d3a96dc81afcdc7b17 | لم يشمل إضافات الوسائط الجديدة |
| Feature الوسائط | 57526fedbbf272801620ab6af0a9f4f426553a27 | feat/bil-native-media-review-20261011 |
| تدقيق Apple/Google | 6e63fe5e0315e88ace9c748281d3607e4334d146 | audit/bil-apple-google-review-compliance-20261011 |
| فرع التجميع الأساسي | a993f1723fb0a714f0d07fe33efb057bfa1f5284 | integration/bil-qa-media-policy-20261011، كان يتحرك أثناء إنشاء التسليم؛ تحقق من SHA الجديد |
| نسخة التوثيق الآمنة | مبنية على a993f172 | handoff/bil-20261011-unified، لا تحل مكان integration |
| المصدر القديم Android code32 / iOS build35 | 3f0085e6e6686f2e87e9cf14789e9e578ea64159 | مرجع تاريخي، ممنوع rollback |

الـintegration فعلاً يجمع QA/Media/Policy، مع حفظ تاريخ الدمج، ولا توجد تعارضات ملفات مؤكدة عند التجميع. هذا لا يعني عدم وجود أخطاء runtime. فرع التسليم معزول حتى لا يغطي عملًا متزامنًا على integration أو QA أو main.

## 2) نجاح Codex الحقيقي وحدوده
Codex على Flutter 3.44.6 / Dart 3.12.2: Format 195 ملف، Analyze نظيف، Arabic 84 PASS، P0=203 PASS، Focused=272 PASS، Broad=255 PASS، جميعها بلا إخفاقات في التقرير النهائي.

Full الحقيقي على c1f1f47a: **8,528 PASS / 0 FAIL / 3 SKIP**، بثمانية shards (0–7)، بحد عمليتين بالتوازي وconcurrency=1 لحماية ذاكرة Windows نحو 16GB. اثنتان من حالات SKIP شُغّلتا منفردتين لاحقاً ونجحتا؛ **بقي فحص حزمة الاعتماد البصري المستقلة غير منفذ/غير معتمد**. لا تصف الثلاث SKIP كأنها لم تكن، ولا تضف أعداد المراحل المتداخلة كأنها اختبارات مختلفة.

29 Golden روجعت فردياً وتغيرت مراجعها بدليل Master/Actual/Diff واجتازت الاختبارات على المصدر القديم؛ لا تحديث جماعي ولا تغيير تصميم الساعة المعدنية الفضية أو Home أو iPad أو شريط أسفل التطبيق ذي 5 أيقونات.

إصلاحات QA الموثقة: AI Vision (فك الصورة ثم إغلاق التكبير، 80g=76kcal من مصدر 95kcal/100g، حبس التكرار والحفظ الذري ووحدات الكميات)، Body Twin بالعربية مع الوزن المتغير، RTL clock. نتائج Headless test لا تساوي اختبار جهاز حقيقي.

الدليل:
https://github.com/bilhealth-admin/Body-Intelligence/pull/11#issuecomment-6104718450
https://github.com/bilhealth-admin/Body-Intelligence/blob/d073dcb39c4d4ba5cef856a5d39935ca1f7de1ca/tools/qa/evidence/20261011-final-closure/README.md

**حاسم:** نجاح Full السابق لا يشمل ملفات integration الجديدة؛ لا تقل 8,528 PASS على فرع التكامل.

## 3) التعديلات المرفوعة فعلاً في integration
**Camera/Gallery/Community:** بعد التصوير تظهر المعاينة الأصلية وزرا Retake/Use Photo، ولا يستعمل الملف تلقائياً. صورة المعرض تمر بمراجعة وتأكيد قبل AI أو تغيير Avatar أو Cover. Community يدعم اختيار أربع صور دفعة واحدة أو العدد المتبقي، حذف عنصر قبل إضافته إلى المسودة، ثم Publish منفصل؛ مراجعة FileImage والتأكد من عدم استخدام صورة تالفة، وعدّ الصور والتحكم في المالك، واختبارات RTL/2x. أدوات اختيار Apple Photos/Android Photo Picker ونمط Cupertino/Material بحسب النظام. حماية المالك عند Android lost-data؛ تحتاج اختبار جهاز/عملية Android حقيقية.

**Store Review/Compliance:** استخدم BIL أصلاً in_app_review Native StoreKit/Google Play، لا نافذة نجوم Flutter مقلدة. 7 أيام/5 أيام نجاح/cooldown 180 يوماً و3 مسارات نجاح. أضيف كبح طلب التقييم في الخلفية وTests. توجد أداة Python تدقيق مصدر للأذونات وPlists وHealth وReview وUGC والدفع؛ نجحت 3 اختبارات fixture الخاصة بها فقط، وهي ليست ضمان امتثال رسمي.

وثائق:
docs/qa_next/BIL_20261011_MEDIA_PICKER_GLOBAL_GUIDELINES_AR.md
docs/qa_next/BIL_20261011_APPLE_GOOGLE_ANDROID_STRICT_AUDIT_AR.md
docs/qa_next/BIL_20261011_POSTFULL_INTEGRATION_QA_PLAN_AR.md
docs/qa_next/BIL_20261011_INTEGRATION_FOLLOWTHROUGH_AR.md

## 4) الأهم الآن: اختبارات GitHub Integration ليست خضراء
Workflow: .github/workflows/bil_integration_media_policy_focused.yml

أربع جولات فشلت: 38113700276، 38114007238، 38114369411، 38114650117.
في Run 38114650117 على 56d1f803:
- Format SUCCESS، Flutter Analyze SUCCESS، Policy Guard SUCCESS.
- Focused Flutter regression FAIL، ومن ثم Aggregate FAIL.
- ثلاث حالات حمراء في test/features/community/community_post_image_support_test.dart:
  1. photo draft previews, shows upload progress, and publishes once
  2. failed image publish retains both text and photo for retry
  3. cancelled photo review leaves the draft without a new image
- السجلات تظهر Confirm/Cancel tap خارج حدود HitTest، وأحياناً y=1015 في viewport height=844 أو x=400 خارج العرض، ثم pumpAndSettle timeout. لا تعطل hit-test warnings أو تخفي الاختبار؛ افحص موضع الـSheet وscroll الفعلي وتوقيت فك الصورة/الرسوم، ثم أعد الحالات مفردة والملف فقط.
- الحالة one native selection stages several photos only after review نجحت في نفس التشغيل.
رابط آخر FAIL مثبت:
https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38114650117

**ملاحظة زمنية:** بعده تحرك integration إلى a993f172، وانطلق Workflow جديد رقم 38114955005 وكان In Progress عند آخر فحص. يجب فتح النتيجة الجديدة قبل إعادة أي تعديل، وقد تكون تغيّرت:
https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38114955005

لا تكرر Full8 ما لم تصبح الإضافات المركزة خضراء ويثبت تجميد الكود.

## 5) First Use والاحتفال — محلي فقط، لم يُرفع مع ملفات عمله
عمل First Use/Glassy coachmarks/Skip/احتفال أول وجبة موجود بحسب إيصال Codex في عشرة ملفات وPatch محلي في:
G:/BIL_Project/qa-preserved/first-use-before-final-closure-20261011

هناك تقرير نجاح محلي سابق بنحو 175 حالة، لكنه يخص Worktree آخر ولم يدخل الـintegration ولا Full التاريخي. توثيق الإيصال:
tools/qa/evidence/20261011-final-closure/records/first-use-preserved.json

**هذه الوثيقة لا تحفظ bytes تلك الملفات نفسها.** Desktop Commander كان Offline؛ فلا تدعِ أنها نُقلت إلى GitHub. استعد المصدر الأصلي من الجهاز المصرح أو Patch مرفق ثم نفّذ 3-way merge بلا إسقاط إصلاحات QA. اختبر Skip بكل خطوة، الاحتفال بعد أول حفظ حقيقي مرة واحدة لكل مالك، reduced motion، حسابات A→B→A، RTL والنص 2x.

## 6) متطلبات لم تُنجز ولا ينبغي التظاهر بإنجازها
- الصور الفورية في المجتمع والصورة الشخصية: Disk cache آمن لكل مالك، stable IDs لا روابط signed المتغيرة، thumbnails، foreground stale-while-revalidate، purge عند تغيير الحساب أو حذف الوسائط.
- بحث الطعام الفوري مثل MyFitnessPal: local SQLite FTS first while typing، cloud async لاحقاً، منع stale query/flicker/انتظار 180ms قبل أول نتائج محلية.
- مطابقة المرئيات المرجعية المستقلة بما فيها حزمة visual evidence الأخيرة؛ حماية Home والساعة و5 tabs.
- iPhone/Android/iPad Native E2E: camera/gallery/permissions, multi-image, offline, lifecycle, notifications back, real AI, Health Connect, VoiceOver/TalkBack, RTL/text 2x وStore subscriptions.
- Google Play: أحدث إخطار محفوظ بتاريخ 8 أكتوبر يقول Suspended بعد رفض متكرر بسبب App Access/Paywall. الحالة الحالية **غير مفحوصة في Play Console**. لا توجد صلاحية لاستئناف أو نشر أو تجاوز اشتراك مزيف.

## 7) ترتيب العمل لتوفير الوقت والرصيد
1. تحقق من آخر HEAD ومن Workflow 38114955005؛ حدّد الأحمر المتبقي.
2. أصلح السبب الحقيقي للحالات المركزة الفاشلة، واختبر حالة ثم ملفاً ثم CI Focused. لا تعِد 8,528 من الصفر.
3. استرد First Use/الاحتفال الحقيقي بعد وصول الجهاز؛ حافظ على النسخ المتسخة والـPatch واجمعه بدمج ثلاثي موثق.
4. عند استقرار كل المصدر: Format/Analyze ثم P0/Focused/Broad المتأثرة، وبعدها Full8 نهائية على SHA واحد بمجموعتين متزامنتين وبأدلة PASS/FAIL/SKIP.
5. اختبر الأجهزة والمتاجر الفعلية والخصوصية/المراجع، وقم بمراجعة Golden مستقلة للحالات الجديدة، ثم قرار بناء تجريبي فقط بعد توفر الأدلة.
6. عالج Instant Experience كعمل جديد منفصل عند ترتيب الأولويات؛ لا تحسبه ضمن media picker.

## 8) حظر صارم
ممنوع تغيير main أو Production Supabase أو Trial/أسعار/دفع أو الدمج أو نشر Builds للمتاجر دون إذن مستقل، وممنوع Force Push/حذف الاختبارات/إخفاء فشل/تحديث Golden جماعي/إعادة Home والساعة للشكل القديم. حماية Home وLog Food بصرياً، 5 bottom icons، ومسارات حفظ الطعام ومصداقية المعادن والقيم. أي إصلاح يرفع SHA ونتائج focused حقيقية ويوثق بدقة.

المصادر التي تقرأها المحادثة التالية أولاً:
- PR11: https://github.com/bilhealth-admin/Body-Intelligence/pull/11
- تقرير Codex: https://github.com/bilhealth-admin/Body-Intelligence/pull/11#issuecomment-6104718450
- فرع التكامل: https://github.com/bilhealth-admin/Body-Intelligence/tree/integration/bil-qa-media-policy-20261011
- تسليم Codex: https://github.com/bilhealth-admin/Body-Intelligence/blob/d073dcb39c4d4ba5cef856a5d39935ca1f7de1ca/tools/qa/evidence/20261011-final-closure/README.md
- آخر CI فاشل مثبت: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38114650117
- أحدث CI قيد الفحص: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38114955005

**نقطة النهاية للتسليم:** كل ما ظهر من كود/أدلة في GitHub محفوظ على الفروع، لكن First Use المحلي غير مرفوع، والتكامل لم يثبت نجاحه نهائياً، والأجهزة والمتجر لم تُعتمد. لا تقل Release Ready.
