# BIL‑04 — مقترح منع تجاوز اليوم المغلق من الطعام العادي

الحالة: مقترح مشترك محلي داخل validation؛ ليس تغييرًا ضمن owned.patch.
القاعدة: 1744788e6bfbdffc3a168bbaf36b3abf3e2c698a.

## الفجوة المثبتة

مسار Coach في BASE يستعمل _requireCoachOpenDay، لكن مسارات MealRepository
العادية كانت تضيف وتصحّح وتحذف وتستعيد وتنسخ دون فحص إغلاق اليوم. وجود الحماية
في Coach وحده لا يمنع تسجيل الطعام من صفحة اليومية أو الوصفات أو Quick Add.

## الملفات المشتركة المقترحة

| الملف | التغيير |
|---|---|
| lib/data/repositories/meal_repository.dart | حارس خاص لحالة اليوم؛ إضافة فحوص داخل معاملات كل mutation، وجعل createMeal / deleteMealItem / restoreMealItem معاملات تحوي الفحص والكتابة معًا. |
| lib/data/repositories/meal_repository_copying.dart | فحص اليوم الوجهة داخل copyDay، وفحص جميع وجهات copyDayToDates قبل أول كتابة. |
| lib/data/repositories/meal_repository_queries.dart | بلا تغيير: draft/template يمران بالفعل عبر createMeal داخل معاملتهما؛ الحارس المركزي الجديد يغطيهما. |

تحقق العامل من تطابق الملفات الثلاثة حرفيًا مع BASE قبل التعديل؛ البصمات
موجودة في query_validation/closed_day_food_preimages.json.

الحارس _requireOpenDayForMeals يرفض حالة lifecycleState=closed أو وجود closedAt
حتى إن كانت الحالة القديمة غير متسقة. يستعمل استثناء CoachMealConflict.closedDay
القائم دون enum جديد أو signature جديدة. لا يغيّر مقادير الطعام أو أساسه
الغذائي أو ترتيب المخازن أو حماية quantityGrams.

## تغطية المسارات

- createMeal يفحص قبل إرجاع bucket قائم وقبل إنشاء bucket جديد.
- addMealItem وupdateMealItem وdeleteMealItem وrestoreMealItem تفحص اليوم
  الحقيقي المرتبط بـmealId داخل المعاملة نفسها.
- deleteMealCascade وmoveMealItem وmoveMealItemToType وduplicateMealItem
  تفحص اليوم قبل الكتابة أو قبول مسار no-op. الحذف والاستعادة يزيدان النسخة
  بالطريقة القائمة دون تعديل معناها.
- addReviewedMealItemsAtomically وrepeatHistoricalMeal وrepeatMeal
  وcreateMealFromDraft وinstantiateTemplate محمية باستدعاء createMeal ضمن
  معاملتها المحيطة.
- addCalculatedRecipeServingAtomically وaddQuickMacroEntry تفحصان اليوم
  قبل إنشاء أي food snapshot، إضافة إلى الحارس عند createMeal.
- copyDay كان يدرج Meals مباشرة؛ أصبح يفحص الوجهة قبل القراءة/الإدراج.
  copyDayToDates يرفض أي وجهة مغلقة قبل كتابة الوجهات الأخرى.
- قراءة/نسخ المصدر المغلق إلى وجهة مفتوحة تظل مسموحة. لا نغيّر read APIs
  لتمنع مشاهدة الطعام أو تاريخه.

## الاعتماد اللازم عند الدمج

يجب ضم تحويل DailyLogRepository.closeDay إلى transaction تشمل قراءة ledger
وحفظ الإغلاق؛ هذا التغيير يملكه العامل الرئيسي BIL‑04. الحماية من سباق
الإغلاق والكتابة تتطلب أن يشترك الطرفان في معاملات قاعدة البيانات نفسها.
لا قاعدة schema جديدة ولا triggers ولا مخزن موازٍ.

جميع ملفات BIL‑01 المملوكة، بما فيها Coach commands/journal/Undo/food/portions،
بقيت دون تعديل. تراجع تقاطعاتها بعد الدمج مع عامل BIL‑01؛ لا يعتبر نجاح هذه
الاختبارات ضمان توافق دفعات جميع الأدوار.

## الاختبارات الجديدة

test/parallel/bil04/closed_day_food_test.dart يعرّف 19 اختبارًا على Drift حقيقي
مؤقت ببيانات مصطنعة:

- عشرة أنواع mutation على طعام يوم مغلق، مع مقارنة كل الجداول قبل/بعد.
- يوم مغلق فارغ يرفض تسعة مسارات وجهة، منها Quick Add والوصفة والقالب
  والمسودة والنسخ والتكرار؛ يبقى بلا أطعمة أو أرقام مختلقة.
- مصدر فارغ لا يحول النسخ إلى وجهة مغلقة إلى نجاح صامت.
- النسخ إلى عدة أيام يرفض دفعة تحوي يومًا مغلقًا دون أثر في اليوم المفتوح.
- النسخ من مصدر مغلق إلى وجهة مفتوحة يعمل ويحافظ على المصدر.
- كل من lifecycleState=closed وclosedAt وحده يكفي للمنع.
- الاستعادة ممنوعة أثناء الإغلاق وتعمل بعد إعادة الفتح.
- إعادة الفتح تسمح بالتعديل مع بقاء نفس حساب الكمية/التغذية.
- إغلاق داخل معاملة معلّقة يجعل الإضافة المنافسة تنتظر ثم ترفض بعد commit.

نجحت الاختبارات الـ19 فعليًا على integration overlay الذي يتضمن حراس
MealRepository ومعاملة DailyLogRepository.closeDay. السجل الكامل المثبت:
query_validation/query_closed_day_parser_stable، والاختبارات الكلية فيه 54.
تحليل الملفين المشتركين ضمن تسعة ملفات انتهى بخروج 0 ودون ملاحظات.

هذه الاختبارات تعتمد على integration overlay؛ يُتوقع أن تكشف الفجوة على
BASE. لا يصح عدّها اختبارات ناجحة على owned.patch وحده. بقيت المحاولة الأولى
في السجل؛ فشلت حالة واحدة بسبب position=0 في مسودة الاختبار، وصُححت إلى 1
وفق عقد MealBuilderEngine قبل التشغيل الناجح. لم يتغير الإنتاج لإخفاء ذلك.
