# BIL QA — عقد More المتبقي وتشخيص Overflow في Dashboard

**الفرع:** `qa/bil-quality-ux-integration-20261009`، PR #11 Draft، لا main ولا Production ولا تغييرات المتاجر/Trial/الدفع.

## 1. عقد More
[الاختبارات الخمسة المركزة #38053137165](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38053137165) على `5957a1eb`:
- PASS: `verified-optional-premium`, `watch-real-metrics`, `dashboard-calorie-hierarchy`, `dashboard-bars-first-use`.
- FAIL: `more-flat-icons-and-routing`: 20 tests PASS، اختبار واحد فقط FAIL لأن العقد القديم ما زال يطلب `PremiumCrownEmblem` رغم حذف التاج الزخرفي من تصميم More المعتمد.
- أصلحنا الاختبار الأخير بحيث **يتحقق إيجابيًا** من `Key('more-premium-entry')`، و`ReferenceSettingsCopy.of(context)`، وسهم الاتجاه، وإجراء الانتقال الفعلي إلى `/plans`، ويمنع إعادة `PremiumCrownEmblem`. لا تغيير بسطر واحد من التطبيق.
- تشغيل مستقل `bil_qa_more_flat_contract_20261010.yml` على ملف الاختبار هذا فقط، ثم لا حاجة لإعادة 5 Suites ما دامت الأربعة الأخرى ناجحة وunchanged.

## 2. Overflow الحقيقي — لا تحديث للـDashboard المحمي
[اختبارات broad #38050560391](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38050560391) أظهرت `RenderFlex overflowed by 1.00 pixels on the bottom` في English LTR 320/390/430 عند 1.0x وفي معاينة production dock، بينما RTL وبعض 1.6x اجتازا.
- **هذا لم يُغلق، ولا يُتجاهل خطؤه**، ولم تُغيّر واجهة Home.
- أضفنا إلى اختبار `dashboard_polish_layout_review_test.dart` تعليمات تشخيصية تطبع `debugDumpRenderTree()` **فقط للحالة English 320/1.0 عند اكتشاف الخطأ**، ثم تواصل `expect(layoutException,isNull)` لتبقى النتيجة حمراء.
- workflow `bil_qa_dashboard_overflow_probe_20261010.yml` يشغّل **حالة واحدة** على Windows/Flutter 3.44.6 للحصول على اسم RenderFlex وأصله دون تكاليف suite كاملة أو تعديل التصميم. أي إصلاح مرئي يتطلب احترام قرار المالك بحماية Home.
- لا يُغيّر اختبار Golden أو baseline تلقائيًا؛ صورة watch والـWeekly والـOnboarding والـWorkout/Recipes غير معتمدة حتى تطابق مرجع المستخدم.

## 3. تقدم Vision
- `1764848e`: أضيفت حصة أصلية لكل من `g/kg`، `piece` و`ml` مع batch mixed-unit atomic replay؛ فشل Build أوليًا بسبب import API الجديد في Food Log، ووجد lint في بصمة الطلب.
- `0885ced8` يضم Formatter SDK، و`5957a1eb` يضيف import الضروري ويبني البصمة في Map صريح بدون إخفاء lint.
- [Fast P0 #38053137136](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38053137136) و[Vision #38053137123](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38053137123) على 5957/الحزمة نفسها؛ لا ادعاء نجاح إلا بناء على نتائج GitHub النهائية.
- لا تدخل في تشغيل كامل للثماني قبل نجاح P0 وFocused وBroad وعلى HEAD موحد.

## 4. استمرارية كل الإصلاحات السابقة
مرجع جرد 377 commit بعد Android32/iOS35 مع 49 UX blobs مطابقة و23 اختلافًا موثقًا: `docs/qa_next/BIL_20261010_STORE32_IOS35_TO_QA_COVERAGE_AND_TEST_LADDER_AR.md`.
