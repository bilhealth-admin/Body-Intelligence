# سياق الطعام في AI Coach — P0، QA فقط

## نطاق هذه الدفعة

الفرع الوحيد لهذه الدفعة هو `qa/coach-community-next-20261005`.
تأتي الدفعة بعد checkpoint مثبت على
`7046710f8625aa1b2b9915cc6beff4011c37fefa`، وكان مصدر التطبيق عنده
مطابقًا لـ`6f4ccc1374d643678bee02db39951cab14c573a4`.
لا تمس هذه الدفعة main أو أرقام iOS 35 / Android 32 أو الإنتاج أو سياسة الدفع وTrial.

## المشكلة والتغيير

كان تجميع سياق Coach يقرأ أعمدة projection وmask مباشرة، ويأخذ اسم الطعام من
الكتالوج الحالي، ويجمع الأيام من timestamp. هذا لا يتحقق من سلامة immutable
snapshot الحديث، وقد يجعل ملفًا حديثًا تالفًا يبدو معروف التغذية. وكانت حسابات
Today تستخدم قيمة calories الداخلية حتى عندما لا يكون هذا الإجمالي معلومًا.

التجميع الآن يقرأ `MealFoodEvidence` مع مفتاح المالك الذي أعاده المستودع،
ويشترط وجوده للدليل الحديث. يُتحقق من مصدر الطعام ومصدر تحويل الكمية ومن تطابق
projection. اسم الطعام الحديث يأتي من snapshot المحفوظ، والتاريخ من
`meal.dayKey`. يبقى مسار الأسماء القديم خاصًا بالمدخلات legacy.

| حالة الدليل | خرج السياق المقصود |
|---|---|
| عنصر ذو مغذٍ مجهول | يبقى إجمالي هذا المغذي مجهولًا مهما كان ترتيب العناصر؛ تستمر المجاميع الأخرى المعروفة |
| قيمة صفر موثقة | تبقى صفرًا معلومًا |
| modern snapshot تالف أو owner غائب/مختلف | لا يُستعار اسم أو تغذية من الكتالوج الحالي |
| سعرات فقط بقيمة 1905 | `entryType: quick_add` والسعرات؛ دون اسم طعام أو كمية طعام أو macros مختلقة |
| يوم غائب أو وجبة فارغة أو استهلاك مجهول | consumed/net/remaining في Today تبقى null |
| إضافة قيم تؤدي إلى overflow | لا يُرسل إجمالي غير finite |

لا يتغير عقد `CoachNutritionDay` القائم أو أسماء حقول السياق الخمسة.
أضيف `knownCalories` ويستخدمه provider في الحسابات المشتقة.
تبقى privacy category gates والأهداف و`ExerciseCaloriePolicy` كما هي.

## الاختبارات الجديدة وطريقة الإثبات

هذه الدفعة تضيف **34 حالة جديدة**. وقت حفظ هذه الوثيقة، هي مراجعة مصدر تنتظر
التنفيذ على SHA الدفعة؛ لا يجوز استخدام نجاح checkpoint السابق لإعلان نجاح P0.

- **23 حالة تجميع:** المغذيات الخمسة، ترتيب known/unknown في الاتجاهين،
  المجاميع الدقيقة، الدليل الفاسد، owner المصدر والتحويل، اسم snapshot،
  dayKey، الصفر الموثق وoverflow.
- **4 حالات Drift:** `MealRepository.watchAll` الحقيقي بعد تعديل الكتالوج
  وتلف snapshot، وحالة calories-only وdayKey.
- **7 حالات provider:** قاعدة Drift وتفضيلات فعلية و
  `coachContextSnapshotProvider.future` نفسه؛ no-day، empty، unknown،
  known-zero، calories-only، partial-calories وmalformed-modern.

اختبار provider يتجاوز حدود health native والـcanonical engine الاختيارية
بـfixtures معلنة فقط. لا يتجاوز Meals أو Preferences أو Coach provider.
يؤكد owner المقروء وصلاحية الدليل قبل التحقق من الأرقام. هدف 2000 وقراءة تمرين
300 ينتجان هدفًا فعالًا 2300؛ بذلك لا تمر اختبارات null بسبب هدف مفقود أو صفر.
تفكك الحاوية قبل إغلاق قاعدة البيانات، وتعمل دورة الحياة بالوقت الحقيقي.

أضيفت ثلاثة ملفات الاختبار الجديدة وخمسة اختبارات توافق إلى focused CI.
جميع البوابات والاختبارات السابقة والـpartitions والـexclusions بقيت قائمة.

## checkpoint السابق: دليل إغلاق الإخفاقات الستة

[Run 37545878945](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37545878945)
انتهى SUCCESS على SHA `7046710f8625aa1b2b9915cc6beff4011c37fefa`.

| البوابة | النتيجة |
|---|---:|
| Dart format | 382 ملفًا / 0 تغيير |
| Flutter analyze | 0 issues |
| Focused | 89 PASS |
| Architecture | 1 PASS |
| Performance prerequisite | 2 PASS |
| Regression 0 | 1734 PASS / 284 ملفًا |
| Regression 1 | 1709 PASS / 284 ملفًا |
| Regression 2 | 1699 PASS / 284 ملفًا |
| Regression 3 | 1843 PASS / 284 ملفًا |
| Regression مجتمعة | **6985 PASS / 0 FAIL / 1136 ملفًا** |
| SQL المعزول | SUCCESS |
| Flutter capture | 8 PASS |

راجعت السجلات أسماء حالات read receipts وrecipient layout وEpic9
وaccessibility/localization source contracts نفسها. لم تُحذف assertions.
كانت آخر مشكلة تنسيق هي أربع مسافات أخرجها Dart حرفيًا داخل Epic9.

حالات SQL ذات `EXPECTED_PRODUCT_FAILURE` هي إثبات فشل baseline القديم أولًا،
ثم نجاح الاختبارات نفسها بعد migration داخل PostgreSQL معزول. لا تعني هذه
النتيجة تطبيق migration أو إجراء كتابة على Production.

معرفات artifacts وبصماتها محفوظة في
[evidence/coach_context_food_evidence_20261006.json](evidence/coach_context_food_evidence_20261006.json).
الـcaptures هي Flutter host renders ببيانات اصطناعية. نجاح التقاطها ليس
إثبات مطابقة بصرية للمرجع أو تصوير جهاز حقيقي.

## العمل التالي وحدود هذه الدفعة

يبقى دمج native food host وPersonal BIL وصورهما من العمل المحلي متوقفًا على
استعادة البيئة؛ آخر host-r9 أثبت 99 حالة، لكنه ليس جزءًا من هذا SHA.
تفاصيله محفوظة في
[checkpoint الاستعادة](CHAT_HARNESS_AND_NATIVE_FOOD_RECOVERY_20261006_AR.md).

`nutritionRemainingFor` يحتفظ مؤقتًا بعقده السابق all-or-null. fallback الهدف
الناقص إلى صفر وعودة الأهداف عند غياب يوم كامل مسألتان منفصلتان لم تُغيّرا هنا.
كذلك تظل هذه الدفعة عرض السياق الحالي ذي خمسة مغذيات؛ لا تمثل جرد القدرات الكامل
أو دمج مصادر الصور/barcode أو إثبات exact visual fidelity.
