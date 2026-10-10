# BIL 2026 — تدقيق عدم فقدان الإصلاحات منذ Android 32 / iOS 35، وتسلسل QA الاقتصادي
**10 أكتوبر 2026 — وثيقة تدقيق هندسي، وليست شهادة جاهزية للمتاجر.**

## 1. المصدر والسجل الزمني
- **مصدر نسختَي المتجر كما ورد في تقارير الإصدار:** `3f0085e6e6686f2e87e9cf14789e9e578ea64159`، Android version code 32 وiOS build 35. كلاهما كان يشتق من مصدر Flutter هذا وفق تقارير الإصدار؛ رقم `pubspec.yaml` في المصدر هو `1.0.0+8` لأن بناء النسخة المرفوعة يستخدم override. لا تغيّر أي رقم إصدار.
- **فرع QA المشترك عند بداية الجرد:** `20c9fe144a0b14984c02826593bdc41196131473`، فقط `qa/bil-quality-ux-integration-20261009`، PR #11 Draft.
- تحقق GitHub `compare 3f0085e6...20c9fe14`: `ahead_by=377`, `behind_by=0`. **كل تاريخ الكوميتات الممتد من مصدر نسختَي المتجر جزء من ancestry فرع QA؛ هذا لا يثبت تلقائيًا أن كل تعديل واجهة بقي بدون تعارض لاحق.**
- `compare 386d00a6 (PR #10 QUALITY)...20c9fe14`: `ahead_by=134`, `behind_by=0`. تاريخ QUALITY محفوظ كذلك. **لا تعِد دمج PR #10 أو #9 من الصفر.**
- `pubspec.yaml` في مصدر المتاجر وفي QA بقي `1.0.0+8`. لم نغيّر build numbers أو Supabase/Production/الدفع/Trial.

## 2. تدقيق فرع UX الأصلي ضد QA — من GitHub trees الكاملة
ثلاث شجرات Git فعلية (`bfe71232` أساس UX، `bccce73c` آخر UX، `20c9fe14` QA)، `recursive=1`, `truncated=false`:
- **72 ملفًا تغيّرت في UX منذ أساسه.**
- **49 ملفًا:** Blob SHA مطابق تمامًا بين UX وQA؛ محفوظة دون إعادة دمج.
- **23 ملفًا:** Blob SHA مختلف بين UX وQA، لأنها عُدّلت لاحقًا عبر QUALITY/تكامل QA والـGoldens؛ **يلزم تدقيق الفروق ولا يصح نسخ UX عليها**.
- لا يوجد ملف UX تغير ثم بقي في QA مطابقًا للأساس القديم أو حذف دون بديل (`MISSING_UX_UNCHANGED=0`, `MISSING_UX_DELETED=0`). ومع ذلك فالاختلافات الـ23 لا تعني تحقق كل مطالب UX.

**ملفات الاختلاف الـ23:** `.github/workflows/verify.yml`, `docs/visual_2026/design_research_and_qa.md`, `docs/visual_2026/reference_146_inventory.csv`, `lib/features/analytics/analytics_page.dart`, `lib/features/connected_health/connected_health_page.dart`, `lib/features/notifications/presentation/notification_settings_page.dart`, `lib/features/settings/help_center_page.dart`, `lib/features/settings/legal_document_page.dart`, `lib/features/settings/reference_settings_home_page.dart`, `lib/features/settings/settings_page.dart`, `lib/features/settings/settings_page_polish.dart`, `lib/features/settings/trust_support_page.dart`, `lib/features/wellness/presentation/sleep_tracker_experience.dart`, `lib/features/wellness/presentation/wellness_library_page.dart`, `lib/features/wellness/presentation/wellness_tools_pages.dart`, `test/bil_semantic_icons_test.dart`, `test/epic15_store_screenshot_golden_test.dart`, `test/features/commerce/store_transaction_queue_test.dart`, `test/features/settings/more_premium_polish_contract_test.dart`, `test/launch_readiness/webcam_vision_barcode_preparation_contract_test.dart`, `test/premium_splash_experience_test.dart`, `test/visual_closure/actual_data_pages_golden_test.dart`, `test/visual_closure/actual_production_pages_golden_test.dart`.

**اختبار أولي للسطر الدلالي** على 12 ملف واجهة متداخلة: أغلب الأسطر UX الخاصة الجديدة باقية؛ الاستثناء الأكبر هو `reference_settings_home_page.dart`, `settings_page.dart`, `settings_page_polish.dart`: تم استبدال أسلوبها لاحقًا بقرارات صاحب التطبيق الخاصة بتبسيط More والأيقونات (لا تعُد تلقائيًا إلى واجهة UX القديمة). يوجد اختلاف صياغة ثانوي في notification settings. هذا فحص أسطر وليس اختبارًا بصريًا/وظيفيًا.

## 3. عمل QA الذي يجب عدم إسقاطه
- QUALITY: ثبات Streaming AI Coach reactions/sources، Customize Today optimistic controls، Community Publish/Back والإشعارات cold/warm، Connected Health source labels، 25 لغة وHome.
- UX: المعالجة المقيدة لـ49 ملفًا + مراجعة حالات الـ23 أعلاه، مع حماية Dashboard/Bottom 5/كابتن AI Coach/Log Food.
- First Use: الزجاج المتحرك والـSkip أسفل البطاقة والاحتفال الذري لأول وجبة مرة واحدة، وحالة تقليل الحركة.
- Vision: المراجعة الأصلية والصورة الحقيقية والثقة المنفصلة عن التغذية، تأكيد المأكول، سجل الغذاء الموثوق، الحفظ الذري، الأدلة الدقيقة للمغذيات وقيم unavailable. لا تعكس أعمال المحادثة الأخرى.
- مجموعة Golden المقبولة للرجوع بالعربية والإنجليزية بعد مراجعة محدودة ذات manifest SHA-256؛ لا تحدث الصور آليًا، ولا تعتبر CI مطابقًا للـ146 صورة/أجهزة فعلية.
- فحوص ثماني Shards التاريخية أحصت 90 ثم 91 FAIL على SHAs أقدم؛ يجب تفسير نتائج أي تشغيل جديد على SHA نفسه، لا نقل النتائج.

## 4. سلّم التحقق المعدّل — اختبارات أضيق قبل الأوسع
1. `source-checks`: Dart Format، Flutter Analyze، First Use/الحفظ الأول/Skip/Reviewer والرجوع من الإشعارات.
2. **`p0-regressions` الجديدة:** خمس Suites محددة (حفظ الطعام الذري/عزل المستخدم، Journal Coach، مراجعة AI Vision، Flutter capture حقيقي، وحارس 700 سطر). لا تغيير إلى حدود الاختبارات ولا snapshots لتخضيرها.
3. **خمس `focused-regressions` الأصلية**: صورة الإنتاج والبيانات والمتجر والـSplash وطابور المعاملات.
4. **6 مجموعات `broad-regressions`** تسبق full: تغطي 22 ملف اختبار تُعرف منها إخفاقات الـ90/91 التاريخية (Dashboard, Nutrition, Weekly/Onboarding Golden, Settings/RTL, Wellness/Commerce, Community cold-back). تشمل مجالات كانت خارج الخمس focused، وتعمل بالتوازي بلا خفض المقارنات.
5. فقط بعد نجاح 1–4: **8 شظايا `flutter-tests` كاملة** بالتوازي على SHA واحد، وبوابة `flutter` النهائية ترفض أي فشل من المراحل الخمس.
6. Android Debug وiOS Simulator على **نفس SHA** ثم مراجعة Android/iOS فعلية لصور RTL/LTR وحجم الخط والأزرار والرجوع؛ ليست Release Stores.

عدم جاهزية أي مرحلة لا يساوي حذف الاختبار، بل يمنع التشغيل الشامل المكرر المكلف.

## 5. AI Vision — مصفوفة 25 حالة، تُغلق بالأدلة لا بالتخمين
الحالة `قيد الاعتماد` لكل بند حتى نتيجة اختبار واضح على SHA نهائي + المقارنة على جهاز عند الحاجة.

| # | الحالة | أقرب تحقق برمجي / دليل إضافي لازم |
|---|---|---|
| 01 | صورة واضحة وصنف واحد | Premium review + Verified commit؛ E2E صورة فعلية |
| 02 | عدة أصناف في صورة | atomic batch + multi-select؛ E2E متعددة |
| 03 | بقايا مأكولة جزئيًا | Premium leftover widget، لا يساوي المتبقي بالمأكول |
| 04 | كمية مجهولة | Continue disabled حتى تأكيد الكمية |
| 05 | صنف غير معروف | Add missing + verified match/cancel |
| 06 | اختيار بديل مختلف | Verified record ID لا يُنقل من الطعام القديم |
| 07 | ثقة تعرف منخفضة | Recognition-only warning لا تمثل ثقة السعرات |
| 08 | لا يوجد سجل غذائي موثوق | Search/add/cancel دون قيم وهمية |
| 09 | مغذيات/معادن ناقصة | nutrientEvidenceMask، يظهر غير متوفر |
| 10 | استجابة تحليل فارغة | Gateway+UI empty-state |
| 11 | فشل الاتصال | gateway error + retry idempotence |
| 12 | انتهاء timeout | no partial write and truthful error |
| 13 | فشل الكاميرا | camera recovery + manual fallback |
| 14 | رفض صلاحية الصور | picker permission + manual flow |
| 15 | رفض الموافقة على AI | consent gate يمنع إرسال الصورة |
| 16 | نفاد quota | Vision quota contract (دون تغيير الاشتراكات) |
| 17 | Offline | offline fallback ولا تعليق دائم |
| 18 | نقر الإضافة مرتين | عدم تكرار persistent entry عند إعادة الطلب |
| 19 | إلغاء قبل الحفظ | سجل بلا تغيير وعودة صحيحة |
| 20 | فشل الحفظ | rollback كامل وJournal صحيح |
| 21 | الرجوع/لوحة المفاتيح | حفظ تعديلات الكمية وعدم فقد مسودة |
| 22 | 320px وغيرها وجهاز لوحي | tests responsive/UI screenshots |
| 23 | تكبير النص 1.8× أو 2× | no overflow/accessible controls |
| 24 | RTL العربية وبقية اللغات | localization/semantics/25 locale smoke |
| 25 | حفظ حقيقي واحد | SQLite readback وDaily totals/Dashboard تحديث فعلي |

**المصدر التفصيلي:** `BIL_20261010_AI_VISION_QA_FORMAL_HANDOFF_AR.md`. لا يُكتب PASS في هذه المصفوفة حتى يثبت الاختبار على الكوميت النهائي.

## 6. قيود ثابتة
- ممنوع `main`، PR merge، Force Push، Supabase Production، الدفع والأسعار وTrial، إصدار Apple/Google، نقل البوابة إلى أداة تُخفي Failure.
- لا تقبل بمجرد إنشاء APK أو صور Flutter كدليل على موافقة Apple/Google أو تطابق مرجع BIL.
- احتفظ بعناوين commits وملفات إصلاح كل مجموعة وروابط Actions وسبب فشلها/نجاحها داخل PR #11.
