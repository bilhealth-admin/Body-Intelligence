# BIL — استكمال إصلاح CI المركزة واسترداد First Use

التاريخ: 11 أكتوبر 2026. الفرع المصرح: `integration/bil-qa-media-policy-20261011`.

## نقطة الاستلام المثبتة

- قرئت وثيقة التسليم الكاملة في `6ebf1ea22ed20e0172bc026e346835cf12296f19/docs/qa_next/BIL_20261011_COMPLETE_HANDOFF_TO_NEW_CHAT_AR.md`.
- HEAD الفعلي عند الاستلام: `84b24f86eafcaf4e681d0f77782c2a5e79298305`.
- إصلاح تنسيق `lib/shared/widgets/bil_media_review_sheet.dart` موجود بالفعل في هذا HEAD؛ لم يُكرر ولم يُنسب إلى عمل هذه المتابعة.
- تشغيل GitHub Actions `38115162894`، الوظيفة `114398500994`: Format وAnalyze الكامل وPolicy Guard ناجحة، Focused = **77 PASS / 3 FAIL**؛ الإجمالي فشل بحق.
- المرجع: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38115162894

## السبب المحدد والتعديل

الحالات الثلاث الفاشلة في `test/features/community/community_post_image_support_test.dart`:

1. `photo draft previews, shows upload progress, and publishes once`.
2. `failed image publish retains both text and photo for retry`.
3. `cancelled photo review leaves the draft without a new image`.

مساعد الاختبار `_waitForMediaReview` كان يرجع بمجرد وجود الزر وفك الصورة، وقد يحدث ذلك قبل اكتمال حركة دخول `ModalBottomSheetRoute`. استدعاء `ensureVisible` ثم `pump()` بلا مدة لا يكمل حركة المسار. ضغط التأكيد وقع عند y=1023.5 في شاشة 390×844، وعند y=771 في الشاشة الافتراضية 800×600؛ الإلغاء وقع عند y=1100 في 800×600. x=400 في الحالتين الأخيرتين مركز صحيح؛ المشكلة في الإحداثي الرأسي والتوقيت.

لا يصلح انتظار `pumpAndSettle` العام قبل إغلاق المراجعة: Composer يبقي `_selectingImage` فعالًا ومؤشر التقدم متحركًا حتى تنتهي المراجعة.

التعديل المحدود:

- انتظار `AnimationStatus.completed` لمسار المراجعة داخل الانتظار المحدود الموجود، بالإضافة إلى جاهزية فك الصورة عند الحاجة إلى التأكيد.
- الإلغاء ينتظر ظهور المسار فقط؛ لا يُشترط فك الصورة لإلغائه.
- إضافة تحقق `hitTestable` قبل الضغط الحقيقي؛ تحذيرات الضغط وجميع التأكيدات الوظيفية باقية.
- لم يُعدل مصدر التطبيق أو شكل نافذة المراجعة في هذا الإصلاح. ملف المراجعة يحتفظ ببصمة Git blob `247a42695bf03de1ed0d4f20c277b905ad93546d`.

## التنفيذ التدريجي للاختبارات

Workflow `.github/workflows/bil_integration_media_policy_focused.yml` أصبح يمر بهذا الترتيب، ويتوقف التوسع عند الفشل:

1. Format، Analyze، Policy Guard القائمة.
2. تشغيل كل واحدة من الحالات الثلاث السابقة منفردة.
3. تشغيل ملف Community image support كاملًا (12 اختبارًا في نقطة الاستلام).
4. مجموعة Focused القائمة كاملة (11 ملفًا، 80 اختبارًا في نقطة الاستلام).

Aggregate يشترط نجاح المراحل الست جميعها. لم تحذف حالة أو مجموعة ولم يُخف فشل. أعداد المراحل متداخلة ولا تُجمع كاختبارات فريدة. لم يبدأ Full8 أو بناء أو نشر.

### النتيجة الفعلية بعد التنفيذ

كوميت الإصلاح: `aa7f73d8c37331ef56f55e49a92d212f410954b7`، مبني مباشرة على `84b24f86` دون تعديل أي ملف إنتاجي.

تشغيل [38115649502](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38115649502)، الوظيفة `114399901105`، انتهى **SUCCESS** في `2026-10-11T05:46:25Z`:

| المرحلة | النتيجة المثبتة |
|---|---|
| Strict Format | 21 ملفًا، 0 يحتاج تغييرًا |
| Flutter Analyze — كامل المصدر | No issues found |
| Policy fixtures | 3 PASS / 0 FAIL |
| Policy source guard | SUCCESS؛ تدقيق مصدر فقط |
| الحالات الحمراء الثلاث منفردة | 1 PASS لكل تشغيل؛ الثلاث نجحت |
| ملف Community image support كاملًا | 12 PASS / 0 FAIL |
| Focused — 11 ملفًا | 80 PASS / 0 FAIL / 0 SKIP |
| Aggregate | SUCCESS |

سجل التشغيل لا يحتوي تحذير ضغط مفقود `Warning: A call to tap`، ولا `pumpAndSettle timed out`. الأدلة القابلة للقراءة آليًا محفوظة في `docs/qa_next/evidence/20261011-media-focused/ci-result.json`.

**حدود هذه النتيجة:** أعداد 3 و12 متداخلة مع مجموعة 80؛ لا تجمع كحالات فريدة. لم يُشغل Full8 مجددًا. نجاح 8,528 اختبارًا التاريخي يخص `c1f1f47a627169fb692763d3a96dc81afcdc7b17` فقط. هذه النتيجة لا تشمل الكود المحلي غير المسترد، ولا تعادل اختبار الأجهزة أو اعتماد المتاجر.

## استرداد First Use والمرجع

إيصال الحفظ `tools/qa/evidence/20261011-final-closure/records/first-use-preserved.json` يثبت 10 ملفات محلية و`integrated: false`، من قاعدة `944973ed3556ccb9b8cd8a09b451562aea3cf652` في:

`G:/BIL_Project/qa-preserved/first-use-before-final-closure-20261011`.

بصمة SHA256 للـpatch الأصلي: `8364714ef80cd8ef8bc4af710cb339fb6692341d609f4cb232caf98020599205`.

الجهاز الذي يحمل الملفات ظهر Offline عند فحص الاتصال في هذه المتابعة؛ إيصال الحفظ ليس بديلًا عن bytes الملفات. عُثر على أرشيف المرجع الأصلي `الاحتفال والالارشادات.zip` وبدأ استخراجه للفحص البصري. لا يُدّعى استرداد كود First Use أو دمجه أو مطابقته بصريًا قبل وجود المصدر والأدلة الفعلية.

## الحماية

لا تعديل لـHome أو الساعة الفضية أو خمس أيقونات التنقل أو Log Food بصريًا. لا لمس لـmain أو Production أو الأسعار أو Trial أو المتاجر. لا force-push، ولا حذف اختبارات، ولا تحديث Golden جماعي. يبقى قرار الجاهزية معلقًا إلى التحقق النهائي والأجهزة المطلوبة.
