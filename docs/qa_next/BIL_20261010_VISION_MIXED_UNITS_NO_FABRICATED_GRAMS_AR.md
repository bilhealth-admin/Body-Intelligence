# BIL QA 2026 — منع اختلاق الغرامات من قطعة أو ملليلتر في AI Vision

**حالة هذه الوثيقة:** الإصلاحات الشيفرية التالية مجهّزة لفرع `qa/bil-quality-ux-integration-20261009` فقط. لا تعلن PASS على الكوميت الجديد قبل تشغيل الاختبارات المركّزة بالفعل. PR #11 Draft، غير مدموج ولا يمس نسخ المتاجر.

## الخلل المثبت بمراجعة المصدر
قبل هذه الدفعة كان مسارا **Food Log** و**Daily Log** يمرّران الكمية إلى `mealImageAmountInGrams` ثم دائمًا إلى `addReviewedMealItemsAtomically` الافتراضي `quantitiesInGrams=true`. إذا كان سجل الكتالوج يحتوي `servingUnit = piece` و`servingSize = 2`، وأكّد المستخدم `1 piece`، ترجع الدالة القديمة `2` على أنها غرامات! الوضع نفسه عند `100 ml`. هذا قد يرفض الحفظ أو يُظهر تغذية خاطئة. كذلك شاشة الملخص كانت تقسم الغرامات المفترضة على حصة أصلية قد تكون قطعة أو حجمًا.

## الإصلاح (من دون كسر الواجهات القديمة)
1. إضافة `mealImageReviewedQuantity` تُرجع `quantity`, `quantityInGrams`, `servingFactor` وفق سجل الكتالوج الحقيقي:
   - قيمة وزن موثقة (`g/kg/oz/lb/mg`) → الغرامات مع معامل محدد من أساس الوزن الحقيقي.
   - `piece`, `ml` أو وحدة حجم/عد مطابقة لسجل الطعام → **وحدة أصلية، وليس غرامًا مخترعًا**؛ `servingFactor=amount/servingSize`.
   - وحدة غير متوافقة/كتلة من عدد قطع دون وزن/قيمة صفرية/لا نهائية → **رفض**.
2. `addReviewedVisionItemsAtomically` في جزء مستودع الوجبات يستخدم `quantityInGrams` **لكل عنصر منفردًا**؛ أي دفعة مختلطة من وزن وقطعة وحجم تحفظ مرة واحدة أو تتراجع مرة واحدة. `visionRequestId` و`hashedOwner` لا يزالان يحميان من التكرار، وتُضاف أوضاع الوحدات إلى بصمة الطلب. الإيصالات القديمة التي لا تحمل أوضاع عناصر صريحة تُقرأ بالصيغة القديمة من دون تعديل بياناتها، بينما يرفض أي تعارض.
3. استبدال حساب الملخص السريع والكامل إلى `servingFactor` الحقيقي لكل سجل، بما في ذلك `net carbs` والمعادن ذات evidence mask معروف؛ عدم عرض 0 عندما القيمة مجهولة.
4. التحديث في Food Log وDaily Log فقط أثناء مراجعة الصورة؛ **لا تغيير** لوصفات وQuick Macros وAI Coach أو إصدارات Android/iOS أو سياسة الموافقة والاشتراك/الحصة/Production.
5. اختبار `test/features/nutrition/meal_image_unified_review_contract_test.dart` لتثبت تحويل 80 غرامًا و0.5 كغ، و1 قطعة من 2، و250 مل من 100 مل، وإيقاف cup→g أو piece→g بلا دليل.
6. اختبار `test/features/nutrition/meal_vision_verified_commit_test.dart` لحفظ دفعة **80 غ + 1 قطعة + 250 مل** مع القيم الغذائية والكميات والـunits، وإعادة طلب واحدة دون صف إضافي، ورفض تغيير طريقة الكمية لنفس requestId، وrollback لدفعة بها صنف غير موجود.

## بوابة القبول
- Flutter 3.44.6 Format + Analyze عبر `bil_qa_p0_fast_20261010.yml`.
- P0 `vision-durable-idempotency` و`vision-quantity-basis` وباقي P0؛ ثم `meal_image_unified_review_contract_test` و`meal_declared_unit_commit_test` ضمن Vision focused.
- تابع الخمس focused والست broad التي بدأت على الكوميت السابق، ولا تلغِها برفع غير ضروري. **لا تشغيل كامل للثماني** قبل أخضر كل المجموعات وتصنيف الـGoldens القديم.
- اختبارات iOS/Android على الكوميت الجديد + صور من Flutter مع الخط العربي وعرض RTL/25 لغة وأجهزة حقيقية لا تزال شروط اعتماد مستقلة.

## حدود عدم فقدان الإصلاحات
- السلسلة من مصدر Android32/iOS35 ممثلة في `docs/qa_next/BIL_20261010_STORE32_IOS35_TO_QA_COVERAGE_AND_TEST_LADDER_AR.md`.
- إصلاحات الذرّية/عزل المالك/الحفظ الأول لا تُزال، وملفا `meal_repository.dart` و`food_log_page.dart` يظلان دون حد 700 سطر.
