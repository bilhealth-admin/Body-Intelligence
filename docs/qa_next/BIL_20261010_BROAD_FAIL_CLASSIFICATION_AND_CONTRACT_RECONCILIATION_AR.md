# BIL QA 2026 — فصل إخفاقات التطبيق عن عقود الاختبار القديمة

التاريخ: 10 أكتوبر 2026. النطاق الوحيد: `qa/bil-quality-ux-integration-20261009`، PR #11 Draft. **لا دمج، ولا تعديلات على Home أو Dashboard الإنتاجيين، ولا Supabase/اشتراكات/Trial/Android32/iOS35.**

## 1. مصادر الأدلة
- [مرحلة P0 الخضراء #38050194517](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38050194517): 10/10 suites + source aggregate PASS على `432a0e56`.
- [Progressive focused/broad #38050560391](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38050560391) على `d6029699`: **الخمس focused PASS**، Community Cold Back PASS، والخمس broad الأخرى FAIL، لذلك **لم تُشغّل الثماني الشاملة**. نتائج broad: dashboard-nutrition 5 failures، settings-language-icons 5، weekly-onboarding-goldens 26، dashboard-contract-health 6، wellness-commerce 3؛ الإجمالي **45 إخفاقًا**، أغلبها توقعات صور/عقود قديمة وليست 45 عيبًا مستقلًا.
- [Vision #38052538572](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38052538572) و[Android #38052541464](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38052541464) على `1764848e`: بعد تغيير حفظ وحدات متعددة ظهرت مشكلة `undefined_method addReviewedVisionItemsAtomically` في `food_log_actions.dart` فقط، لأن مكتبة صفحة Food Log لم تستورد `meal_repository.dart` الذي يعرّف امتداد المستودع. وجدت أيضًا `use_null_aware_elements` في بصمة الطلب؛ أصلحتها ببناء Map آمن بدلاً من تجاهل التحذير. تم تنسيق المصادر بالـSDK على `0885ced8`، ولا يعتبر ذلك نجاح Build قبل الفحص الجديد.

## 2. تصنيف الخمس مجموعات الواسعة الحمراء
- **Weekly/Onboarding 26 Golden**: اختلافات Pixel حقيقية كبيرة (بعضها أكثر من 90%) بين Master قديم وتجربة أحدث. لم نحدّث الصور ولا عتبة القبول؛ تحتاج مراجعة صورة بصورة واحتفاظ بالأصول والـRTL ومقاسات الخط.
- **Dashboard 5 failures**: أربعة منها `RenderFlex` overflow **1 px** عند بعض مساحات LTR (مقابل اجتياز RTL ومقاسات 1.6x)، وهي **عيوب لم تُصلح بعد**، لا تُخفى؛ الخامسة كانت عقد اختبار قديم يساوي حجم عنوان Calories بالزر Today رغم أن التصميم الحالي يجعل Calories 15/w700 وToday 18/w800.
- **Dashboard Watch 6 failures**: أربعة عقود نصية كانت تفرض إطار الساعة الداكن القديم أو تمنع Path الرسوم البيانية، وتجاهلت الساعة الفضية الحالية/غلاف First Use. اختبار أيقونات الساعة تغيّر من outline إلى أربعة رموز ممتلئة فعلية، مع بقاء الاختبار يطلب قيم Steps/Heart/Energy/Sleep وسلامة Semantics. **Golden واحد 9.71% لا يزال غير معتمد**.
- **More/RTL/Semantic 5 failures**: العقد القديم افترض وزن خط w500 بدل w400، حجم أيقونات 44/24 بدل 34/20، ومنع حتى `BilNativeSettingsIcon(flat: true)` المتوافق مع اختيار الرموز المسطحة؛ العقود الجديدة تُلزم flat فقط وغياب boxShadow وبقاء route/RTL وسمات الاستخدام.
- **Wellness/Commerce 3 failures**: اثنان Golden لم يُراجعا بعد (recipes/workouts)؛ عقد ثالث/اثنان في اختبارات أخرى افترضا `Start 7-day free trial` في صفحة More بينما المصدر الحالي يعرض `Explore Premium` **كخيار** فقط بعد `EntitlementAuthority.verifiedServer`، و`Active` لخطة فعالة. **لم نغيّر السعر أو Trial أو الدفع أو سلوك الصفحة**؛ العقود المعدلة لا تسمح بـPaywall إجباري.
- **Community cold/warm back**: PASS كامل في الجولة الواسعة. لا إعادة عمل ولا تغيير منطق التنقل.

## 3. المصالحة الاختبارية المحكومة (Test Only)
عدّلنا **11 ملف اختبار فقط** لتفحص الواقع المصرّح به في مصادر الإنتاج، لا لتتجاهل فشل حقيقي. يحتفظ كل اختبار بمنع الزر المعطل أو فحص RTL والسجل والتوثيق الذي سبق، ويستبدل مطالب نصية/بصرية بالمتطلبات الأحدث:
1. title/button typography الصريح؛ weight w700/w800 والأحجام 15/18.
2. More 15.5/w400 بدون leading badges الزائدة؛ أيقونات flat 34/20، بلا `boxShadow`، روابط فعلية وChevron اتجاهي.
3. السماح بـ`canvas.drawPath` لخط اتجاه الوزن المرتبط **فقط بالعينات المسجلة**، والاستمرار بمنعه داخل **رسم أعمدة الخطوات الملوّنة**.
4. `DashboardFirstUseExperience` يغلف hero ولا يحذف hero الحقيقي.
5. Contract الساعة الفضية/الزجاج الداكن، 4 أيقونات فعلية/القيم/السمات دون نقل اختبارات Golden إلى PASS.
6. صفحة More خيار `Explore Premium` موثق بالسلطة، لا `Start 7-day free trial` إجباري؛ `reference_settings_home_page.dart` والاشتراكات لم تُمس.
7. تحقق 5 suites مستقلة على Windows/Flutter 3.44.6 في `.github/workflows/bil_qa_contract_clusters_20261010.yml` بلا full shards ولا تحديث صور.

## 4. ما يبقى أحمر عمدًا حتى دليل إصلاح
- Overflows 1 px في Dashboard LTR: **لا تغيّر Dashboard Home بدون إذن المالك**. يجب اختبار السبب الحقيقي بدل التماس تجاهل/استبدال `tester.takeException()`.
- 29+ Golden مرتبط بتصميم قديم: إثبات اختلافات الصور محفوظ سابقًا في `docs/qa_next/BIL_20261010_VISUAL_GOLDEN_29_INDIVIDUAL_REVIEW_AR.md`؛ راجع كل لقطة على المرجع المعتمد قبل تحديث أي PNG. لا تستخدم `flutter test --update-goldens` على كل المشروع.
- Vision mixed units: أنجز تحويل حصة الغرام/القطعة/الملليلتر والـatomic journal؛ يُعتمد بعد Flutter Analyze وP0 على **SHA بعد إصلاح import**. Android/iOS والـ25 حالة وواقع الأجهزة لم تُعتمد بعد.
- حين تصبح جميع هذه المراحل خضراء، فقط عندها شغّل الثماني shards كاملة لمرة واحدة على HEAD ثابت. لا main ولا Force Push ولا PR Merge.

## 5. تتبّع عدم فقدان إصلاحات المتاجر
يبقى `3f0085e6e6686f2e87e9cf14789e9e578ea64159` أصل Android32/iOS35، والفرع يحتوي أنساب الإصلاحات اللاحقة. مرجع الجرد: `docs/qa_next/BIL_20261010_STORE32_IOS35_TO_QA_COVERAGE_AND_TEST_LADDER_AR.md`.
