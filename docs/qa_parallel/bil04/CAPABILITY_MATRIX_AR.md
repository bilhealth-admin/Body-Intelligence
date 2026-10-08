# BIL‑04 — جرد BASE ومصفوفة القدرات والقبول

## المرجع وطريقة قراءة الحالة

BASE_SHA: `1744788e6bfbdffc3a168bbaf36b3abf3e2c698a`.
BASE_TREE_SHA: `8f140791e1c2adcb21122ce64a65cb168bbe90d7`.
الدور: BIL‑04 Health Commands؛ التنفيذ والتجارب محليان فقط.

هذا الجرد مشتق من المصدر الفعلي لهذه القاعدة ومن ملفات BIL‑04 الجديدة
ومقترح الدمج في نسخة `validation`. جرى حساب Git blob SHA‑1 محليًا لـ 79 ملف
مصدر واختبار قائم، ومقارنته بشجرة BASE المحفوظة: جميعها مطابقة، ولا ملف
مفقود. القائمة وبصمات SHA‑256 في
[capability_source_inventory.json](query_validation/capability_source_inventory.json).
لم يُستعمل وصف «missing» في جرد تاريخي عند SHA أقدم دليلاً على وجود فجوة.

معاني الحالات في الجداول:

- **موجود في BASE ومحفوظ**: له تنفيذ قائم؛ ليس إنجازًا جديدًا لهذا الدور.
- **منفذ محليًا / انتظار الدمج**: له adapter وتوصيل فعلي في overlay واختبارات
  محددة أدناه. يحتاج تطبيق `owned.patch` و`integration-proposal.patch` معًا
  بواسطة BIL‑00؛ وجود الملفات الجديدة وحدها لا يوصّل الواجهة.
- **PASS مسجل**: نتيجة تشغيل عند بصمات المصدر المسجلة في ملف ذلك التشغيل.
  لا تنتقل تلقائيًا إلى تعديل مصدر لاحق، ولا تعني جهازًا حيًا أو تركيب جميع الأدوار.
- **PASS البوابات المحلية النهائية**: اختبارات الدور الـ13 والتراجع الـ9
  ومعاملات الطعام الـ4 وDST والتحليل والتنسيق اجتازت عند البصمة النهائية
  أدناه. هذا الوصف يخص الملفات والحالات المسماة؛ لا يحوّل اختبارًا غير مشغّل
  أو تكامل جميع الأدوار إلى PASS.
- **محدود / غير موصول**: يحدد الحد الفعلي ولا يختفي من المصفوفة.

**حالة هذه النسخة من المصفوفة:** نجحت 239 حالة جديدة عبر 13 ملفًا منفصلًا،
و300 حالة تراجع عبر 9 ملفات و50 حالة معاملات طعام عبر 4 ملفات، وإعادة DST
ذات 27 حالة، والتحليل الكامل والتنسيق
عند البصمة الثابتة
`48f4e77f93293f0a51bcc21728b8d5db7f376c33cf61bf28eabc9255b0333e87`.
المجموع 589 حالة غير متداخلة عبر 26 ملف اختبار. حالات DST الـ27 إعادة
تحقق من اختبارات الدور نفسها ولا تضاف إلى هذا المجموع. أُغلقت البوابات
المحلية المسماة؛ يبقى تطبيق الحزمة ومراجعة تكامل جميع الأدوار لدى BIL‑00.
حُفظ فشل اختبار registry السابق ونتائجه السابقة في أرشيف مستقل؛ توسعة
التوقع من 23 إلى مجموعة الأسماء الـ38 الصريحة اجتازت التحقق الحالي.
الحدود الأخرى تشمل دمج جميع الأدوار، و23 لغة، والتجربة البصرية والأجهزة؛
لا يُعلن release من هذه الوثيقة.

## 1. الجرد الحديث: القدرات القائمة التي يجب حفظها

العقد العام في BASE هو `BilToolRegistry` ثم `CoachActionAdmission` ثم
`_IntelligenceActionFlow._executeAction`. لا يستنتج هوية الأداة من تسمية
عنصر الواجهة. المصدر:
[bil_tool_registry.dart](../../../lib/features/intelligence_center/domain/bil_tool_registry.dart)،
[coach_action_admission.dart](../../../lib/features/intelligence_center/domain/coach_action_admission.dart)،
[intelligence_action_flow.dart](../../../lib/features/intelligence_center/presentation/intelligence_action_flow.dart).

تأكيد BASE للكتابات القابلة للتراجع يتبع `CoachActionPermissionGate`:
`readOnly` يمنعها، و`askBeforeWrite` يطلب المراجعة، و`writeAllowed` قد يسمح
بها دون حوار إضافي ما لم يفرض الفعل تأكيدًا جديدًا. الأفعال الحساسة تطلب
التأكيد دائمًا. مسار BASE يقبل التأكيد النصي المسموح. هذه الدلالة محفوظة؛
الإلزام بحوار جديد لكل كتابة صحية ينطبق على أدوات BIL‑04 الجديدة.
المصدر: [coach_action_permission.dart](../../../lib/features/intelligence_center/domain/coach_action_permission.dart).

| القدرة في BASE | canonical action والنوع | handler → repository الحقيقي | التأكيد | readback الفعلي | Undo / إعادة المحاولة | الاختبار الموجود والدليل | الحالة |
|---|---|---|---|---|---|---|---|
| الماء | `log_water` / `addWater`؛ write | `_commitPreparedCoachNativeAction` → `CoachNativeCommandRepository.commit` → `WaterRepository.add` | سياسة BASE أعلاه؛ قيمة 1–5000 ml | الصف المحفوظ، UUID/revision، الكمية واليوم | journal نفسه؛ تعويض الصف المحدد مع منع Undo بعد تعديله | N1: `log_water commits a durable readback and compensates its exact snapshot`؛ N2: `water confirmation rejects delivered owner A B A` | موجود ومحفوظ؛ N1 PASS43 وN2 PASS48 ضمن التراجع النهائي |
| الوزن | `log_weight` / `addWeight`؛ write | Native commit → `WeightRepository.addWeight` | BASE؛ 20–500 kg، تاريخ قانوني | الوزن واليوم والهوية والإصدار؛ حفظ الملاحظة والصورة الموجودة في التخزين | استعادة السجل السابق أو تعويض الإضافة؛ لا يمحو تسجيلًا أحدث | N1: `log_weight commits a durable readback and compensates its exact snapshot`؛ N2: `weight changed during confirmation is preserved` | موجود ومحفوظ؛ ليست إعادة بناء للوزن |
| الهدف | `update_goal` / `updateGoal`؛ write | Native commit → `UserProfileRepository.save` و`GoalRepository.save` في معاملة واحدة | BASE؛ هدف 20–500 kg وتاريخ اختياري | الملف والهدف الفعليان والربط والنسخ | تعويض الاثنين معًا؛ رفض النسخة الأقدم | N1: `update_goal commits a durable readback and compensates its exact snapshot`؛ N2: `goal Undo preserves later profile changes atomically` | موجود ومحفوظ؛ هذه هي كتابة هدف الوزن القائمة |
| القياسات | `save_measurements` / `saveMeasurements`؛ write | Native commit → `BodyMeasurementRepository.saveForDay(preserveExistingValues: true)` | BASE؛ حقل واحد على الأقل ضمن 20–300 cm | الحقول المقدمة والحقول السابقة المحفوظة، اليوم والإصدار | تعويض مطابق؛ لا يكتب فوق تعديل جزئي أحدث | N1: `save_measurements commits a durable readback and compensates its exact snapshot`؛ N2: `measurement receipt includes the committed preserved fields` | موجود ومحفوظ |
| الذاكرة العامة | `save_memory` / `saveMemory`؛ write | Native commit → `PreferencesRepository.setManyInCurrentTransaction` عند `CoachMemoryRepository.storageKey`، ثم مزامنة الذاكرة القائمة | BASE؛ نص صريح حتى 500 ونوع مسموح | المجموعة المحفوظة، هوية الإدخال، النص والنوع و`confirmed` | استعادة الذاكرة السابقة حتى عند deduplication؛ لا يستبدل مجموعة عُدلت لاحقًا | N1: `save_memory commits a durable readback and compensates its exact snapshot`؛ N2: `memory Undo restores a deduplicated pre-existing memory` | موجود ومحفوظ؛ مختلف عن سياق الحياة الجديد |
| ماكروز سريعة | `quick_add_macros` / `quickAddMacros`؛ write | `_prepareCoachMealAction` / `_commitPreparedCoachMealAction` → `MealRepository.commitCoachMeal` | مراجعة الطعام القائمة + owner/permission؛ دليل المغذيات محدد | item وbucket وnutrient evidence mask وreceipt ثم ledger | `undoCoachMeal` و`readCoachMealOperation`؛ نفس operation لا يكرر الطعام | F1: `1905 calorie-only command has unknown macros in stored item, receipt and totals`؛ `same operation after repository restart reads committed rows and a changed command conflicts` | موجود في BASE؛ إغلاق الثغرات العادية إضافة BIL‑04 منفصلة |
| تصحيح كمية الطعام | `update_meal_item` / `updateMealItem`؛ write | meal handler → `CoachMealCommand.updateQuantity` → `commitCoachMeal` | `itemId` و`quantityGrams` موجبان وحدود قائمة؛ تحقق معنى الوحدة | تغذية السجل المجمّدة، لا تحويل حديث من الكتالوج | استعادة snapshot الأصلي مع فحص النسخة | F2: `gram command rejects ml without changing item or journal`؛ `gram edit never reads a newer catalog conversion` | موجود ومحفوظ؛ لا تغيير لدلالة grams |
| حذف / نقل صنف | `delete_meal_item` / `deleteMealItem`؛ `move_meal_item` / `moveMealItem`؛ write | meal handler → command/remove أو move → `MealRepository.commitCoachMeal` | الحذف sensitive؛ النقل reversible وفق BASE؛ item/version والوجهة | هوية الصنف وحالة الحذف أو bucket/position الفعلي | `undoCoachMeal` يعيد snapshot والموقع؛ لا يمحو تحريرًا أحدث | F1: `update delete and move restore immutable snapshots and original positions`؛ `a later quantity edit rejects stale Undo and retry discloses modified state` | موجود ومحفوظ؛ لا تعديل في ملفات BIL‑01 |
| إضافة طعام / استبداله والوصفات | canonical داخل repository: `log_foods` و`replace_meal_item`؛ Food V2 write | `CoachMealCommand.foods/replaceFood` → `MealRepository.commitCoachMeal`؛ BASE `_prepareCoachMealAction` ينتج الأنواع الأربعة في الصفوف السابقة فقط | عقد source/quantity/owner قائم؛ لا يُستدل من factory أو card على اكتمال التأكيد من المحادثة الرئيسية | الصفوف الغذائية والمغذيات والإيصال حقيقيون في repository | journal الطعام وتعويض snapshot القائم | F3: `four foods commit complete immutable evidence and replay after repository recreation`؛ `replacement changes the existing entry and Undo restores full prior evidence` | domain/cards/repository موجودة؛ producer شامل من المحادثة لهذه الصيغ غير مثبت هنا؛ استكماله في BIL‑01 |
| المتبقي الغذائي / الاسم | `read_nutrition_remaining` / `readNutritionRemaining`؛ `read_profile_identity` / `readProfileIdentity`؛ read | `_executeAction` → `coachContextSnapshotProvider` → حساب المتبقي/الهوية القائم | قراءة وفق السياق القائم؛ لا مراجعة كتابة | قيمة من snapshot أو عدم توفر؛ لا journal جديد | لا Undo لقراءة | الاختبارات الموجودة في BASE للـcontext/registry؛ لم يُعَد بناء هذين المسارين | موجودان؛ مسار القراءة الصحية المحدود الجديد مستقل |
| فتح سجل الوزن أو الطعام | `open_weight_log`؛ `open_meals`؛ `open_meals_yesterday`؛ handoff | route → `/weight-history` أو `/daily-log?focus=meal` | navigation lowRisk | فتح المسار فقط؛ لا إيصال تسجيل وزن/طعام | لا تعويض بيانات | N3: `open weight log is read-only navigation to weight history` | موجود؛ لا يُحتسب كتابة |
| فتح التمرين | `open_workouts` / `reviewWorkout`؛ handoff | route → `/wellness/workouts/log` | navigation lowRisk | لا completed workout من مجرد الفتح | لا Undo بيانات | binding/route القائمان؛ إضافة التسجيل الفعلي أدناه | route-only محفوظ، وليس التسجيل الجديد |
| فتح الخطة / التقرير | `open_plan` / `openPlan`؛ `open_report` / `openReport`؛ handoff | route → `/plan?origin=dashboard` أو `/analytics` | navigation lowRisk | لا activation ولا تنفيذ تقرير bounded | لا Undo بيانات | N3: `navigation is low risk and deletion is destructive`، وفحص handler الحالي | route-only محفوظ؛ المعاينة والتفعيل والقراءة المحددة أدناه |

N1 هو suite المستودع وN2 suite الواجهة والاستعادة القائمة؛ الأسماء الكاملة
ومواضع تشغيلهما في القسم 5. آلية BASE تحفظ `operationId` وdigest وbefore/after
في `coachNativeOperationV1.*`، وتقرأ السجل الفعلي بعد commit، وتستعيد Undo
بعد إعادة فتح المحادثة إذا كان إيصالها محفوظًا وصالحًا. لا تُنسب آلية Native
Undo الأصلية إلى هذا الدور. إضافة health تستعملها عبر فرع متوافق؛ الإصلاح
الجديد لإيصال الصحة المفقود له locator ذري واختبارات R/UI مستقلة أدناه.

### الفجوة المثبتة عند بداية BIL‑04

| عائلة BIL‑04 | الموجود فعلًا في BASE خارج أوامر Coach | ما لم يكن canonical Coach write/read في registry الأساسي |
|---|---|---|
| اليوم | `DailyLogRepository.closeDay/reopenDay/readLedger` وحالة اليوم | `close_day` و`reopen_day` |
| النوم والملاحظات | `updateSleepHours` و`saveBodyContext` وواجهة النوم | `log_sleep` و`save_day_note` وقراءة نوم محدودة |
| سياق الحياة | `LifeContextRepository.add` وإذن الرؤى المخزّن | `save_life_context` بهوية ثابتة وUndo ذري |
| الصيام | `fasting_timer_actions.dart` وsession/history codecs وتفضيلات الإشعار | start/stop/adjust canonical command له journal/readback واستعادة |
| التمرين | مكتبة التمرين و`appendExerciseNotes` | `log_exercise`؛ فتح workout قائم لكنه لا يسجل أداءً |
| الخطط | `DietPlanCommand.activate` و`DietPlanRepository` وبوابات الوصول والسلامة | `preview_plan` و`activate_plan` من Coach |
| التحليلات والسجل والمحتوى | `ProgressAnalysis` وrepositories و`CoachCatalogGrounding` | نافذة محددة للموضوع تحترم حد الأيام والصفوف دون تحميل التاريخ كله |

مصدر هذا الفرق هو registry الحالي مقارنةً بالخدمات المذكورة، وكلها ضمن
قائمة blob المتحقق منها؛ لا استدلال من تاريخ اسم ملف توثيق.

## 2. مصفوفة الكتابات الصحية الجديدة

**الحد المشترك H:** `CoachHealthToolDescriptor` يتحقق من canonical tool
وschema، ثم `CoachActionAdmission` يمنح هوية operation من التطبيق، ثم
`_confirmCoachHealthAction` يعرض مراجعة جديدة حتى في `writeAllowed` وحتى مع
تأكيد نصي سابق. يتم التقاط owner/epoch وإذن محاولة الكتابة، والتحقق قبل
وبعد awaits. `CoachNativeCommandRepository` ينفذ adapter وjournal داخل
المعاملة القائمة؛ readback داخلها يثبت أثر repository، ثم readback العملية
بعد commit يحدد حالتها. refresh والإيصال وUndo يتبعان المسار القائم مع فرع
health. هذه الكتابات لا تنشئ قاعدة بيانات صحية موازية.

مصادر التنفيذ:
[coach_health_tools.dart](../../../lib/features/intelligence_center/app_commands/coach_health_tools.dart)،
[coach_health_flow.dart](../../../lib/features/intelligence_center/app_commands/coach_health_flow.dart)،
[coach_health_adapter.dart](../../../lib/features/intelligence_center/app_commands/coach_health_adapter.dart).

| القدرة / canonical action | handler → repository | نوع الأثر والتأكيد | readback / refresh | Undo وإعادة المحاولة | اختبار محدد | حالة التنفيذ وحده |
|---|---|---|---|---|---|---|
| إغلاق اليوم `close_day` | `CoachDailyCommandAdapter` → `DailyLogRepository.closeDay` و`readLedger` | write؛ H؛ اليوم مجمد وغير مستقبلي | حالة الإغلاق/timestamp وledger الحقيقي؛ اليوم الفارغ يبقى بلا طعام وبقيم مجهولة | restore اليوم السابق أو غيابه؛ نفس operation يعيد الحالة ولا يكرر | D: `empty day closes with unknown totals and Undo restores absence`؛ `close freezes real meal totals; reopen exposes current source totals` | منفذ محليًا؛ PASS28 في D؛ انتظار تطبيق مقترح الدمج |
| إعادة فتح اليوم `reopen_day` | daily adapter → `DailyLogRepository.reopenDay` | write؛ H؛ لا إنشاء يوم مفقود | `open` و`closedAt=null`، ثم ledger من المصدر الحالي | restore snapshot المغلق؛ فحص تغييرات لاحقة | D: `timestamp-only closure is reported closed and explicit reopen clears it`؛ `reopening a missing day creates no data or operation journal` | منفذ محليًا؛ PASS مسجل |
| مدة نوم يدوية `log_sleep` | daily adapter → `updateSleepHours` | write؛ H؛ قيمة واحدة 0–14 ساعة واليوم صريح | ساعات محفوظة و`source=manual`؛ لا اختراع start/end؛ حفظ حقول اليوم الأخرى | restore صف اليوم أو غيابه؛ منع النسخة الأقدم | D: `manual zero sleep is distinct from absent sleep and Undo restores absence`؛ `sleep write preserves notes, steps, activity and record identity` | منفذ محليًا؛ PASS مسجل؛ ليس قياس جهاز |
| ملاحظة اليوم `save_day_note` | daily adapter → `saveBodyContext` | write؛ H؛ نص غير فارغ حتى 1000 | نص الملاحظة فقط مع اليوم؛ بقية الحقول محفوظة | snapshot اليوم؛ منع التعويض فوق تحرير أحدث | D: `day-note replacement and Undo preserve every unrelated daily field` | منفذ محليًا؛ PASS مسجل |
| سياق الحياة `save_life_context` | `CoachLifeContextCommandAdapter` → `LifeContextRepository.add/getByUuid/delete` | write؛ H وsensitive؛ UUID مشتق من operation؛ `useInInsights=false` افتراضيًا | UUID واليوم والنوع والنص وإذن الرؤى الفعلي؛ تخزين manual | delete كتومبستون لنفس UUID؛ لا إدخال جديد عند replay ولا إحياء بعد Undo | D: `life context missing consent defaults to false in the real repository`؛ `life-context Undo uses the same UUID tombstone without losing other fields` | منفذ محليًا؛ PASS مسجل؛ ليس save_memory |
| بدء الصيام `start_fasting` | `CoachFastingCommandAdapter` → `PreferencesRepository` + codecs القائمة | write؛ H؛ هدف integer 1–23؛ رفض جلسة ثانية | v2 session وlegacy started/target متطابقان؛ نفس الإيصال الثابت | استعادة البيانات السابقة بالضبط؛ إعداد notify مستقل | FA: `start persists both session formats and preserves unrelated state`؛ `a second start cannot replace an active session` | منفذ محليًا؛ PASS مسجل؛ إشعار الجهاز نتيجة مستقلة |
| إنهاء الصيام `stop_fasting` | fasting adapter → تفضيلات الجلسة والتاريخ القائمة | write؛ H؛ جلسة نشطة ومدة موجبة | التاريخ والمدة من end instant مجمد؛ سياسة التاريخ القائمة 100 إدخال | استعادة active session والتاريخ الخام، بما فيه legacy-only | FA: `stop derives history and duration from its immutable end instant`؛ `Undo stop restores legacy-only session and exact raw history` | منفذ محليًا؛ PASS مسجل |
| تصحيح الصيام `adjust_fasting` | fasting adapter → session codec + Preferences | write؛ H؛ هدف أو startedAt صريح بـZ/offset؛ لا wall time ملتبس | الهدف/البداية المطلوبة فقط؛ التاريخ لا يتغير | استعادة snapshot السابق؛ رفض تعديل أحدث | FA: `adjust rejects ambiguous DST, rollover, future and empty corrections`؛ `DST repeated wall hour remains distinct through explicit offsets` | منفذ محليًا؛ PASS مسجل؛ parser النصي يدعم تعديل الهدف، لا يستنتج timestamp حرًا |
| تمرين أدّاه المستخدم `log_exercise` | `CoachActivityCommandAdapter` → `DailyLogRepository.appendExerciseNotes` | write؛ H؛ واحد من 18 معرفًا حقيقيًا؛ 5–120 دقيقة integer | أربعة حقول قائمة `id/name/minutes/recordedAt`؛ حفظ بقية اليوم؛ تقدير الطاقة إن توافر دليل اليوم | restore كامل صف اليوم/غيابه؛ journal واحد؛ لا يعيد replay التمرين | A: `appends accepted schema and preserves unrelated day fields`؛ AN: `activity native replay, repository restart and Undo use one journal` | منفذ محليًا؛ PASS مسجل؛ لا يزيد targets ولا يحول اقتراح تمرين إلى أداء |
| تفعيل خطة `activate_plan` | `CoachPlanCommandAdapter` → `DietPlanCommand.activate` → `DietPlanRepository.activate` وجدول الأهداف القائم | write؛ H؛ exact pathwayId؛ verified entitlement لمسارات Premium، والمسار المجاني لا يستدعي subscription loader؛ checkbox جديد إذا تطلبت clinicianReview؛ medicalSupervision غير مفعل هنا | activePathway والمسودة نفسها وأهداف الأسبوع مع حفظ meal targets؛ رفض تغير المسودة أثناء الحوار | restore المفاتيح/المسودة/الجدول السابقة؛ فحص نسخة + fence للعمليات المتداخلة؛ إعادة المحاولة تقرأ العملية نفسها دون إعادة التفعيل | P: `free activation uses exact command and updates the live weekly goal`؛ `verified Premium activates the exact saved personalized draft`؛ `Undo restores previous plan, exact saved draft, and meal schedule`؛ UI: `checking clinical review cannot adopt a draft edited during the dialog` | منفذ محليًا؛ PASS مسجل؛ لا شراء ولا منح entitlement |

السياق النصي لا يعيّن `useInInsights=true` أو clinician approval ضمنيًا.
النموذج لا يضع علامة checkbox بدل المستخدم. الحد السريري يأتي من كتالوج
التطبيق والسياسة القائمة، ولا يقدم هذا العمل توصية علاجية جديدة.

### ثغرة قفل اليوم خارج Coach وحد الإشعار

| مطلب القبول | التنفيذ الحقيقي | الدليل | الحالة |
|---|---|---|---|
| ألا يتجاوز أي مسار غذائي عادي إغلاق يوم فارغ أو ممتلئ | private helper في `MealRepository` يفحص `lifecycleState==closed` **أو** `closedAt!=null` داخل نفس معاملة mutation؛ يغطي createMeal حتى bucket الموجود، add/update/delete/restore/cascade/reorder/move/no-op/duplicate، ومسارات recipe/quick قبل كتابة snapshot food | C: `empty closed day blocks every ordinary destination writer` و`closed source remains readable and copyable into open destinations` | منفذ واختبارات repository فعلية؛ المقترح المشترك فقط |
| copy/repeat لا يكتب وجهة مغلقة | guard لمسار `copyDay` الذي يدرج مباشرةً، وجميع وجهات `copyDayToDates` قبل أول كتابة؛ بقية المسارات تدخل createMeal المحمي | C: `multiple destination copy rejects one closed day before any insert` و`pending closure and ordinary insertion serialize in one database` | PASS مسجل؛ النسخ **من** مصدر مغلق **إلى** وجهة مفتوحة مسموح |
| closeDay والكتابة الغذائية يتسلسلان ذريًا | مقترح `DailyLogRepository.closeDay` يقرأ ledger ويكتب الإغلاق داخل transaction | C + D؛ لا triggers/schema جديدة في المنتج | منفذ محليًا؛ يحتاج مقترحات shared الثلاثة معًا |
| reopening يعيد الكتابة الطبيعية دون تغيير semantics الغذاء | إعادة فتح صريحة ثم repository العادي | C: `explicit reopen allows ordinary edits without changing food semantics` | PASS مسجل؛ لا تغيير للوحدات/الطاقة |
| حفظ الصيام مستقل عن نجاح الإشعار | `CoachFastingNotificationSync.syncLatest` بعد durable commit/recovery/resume، طابور محلي متسلسل، إعادة قراءة الجلسة وpending IDs، حفظ notify opt-in القائم | FN: `target scheduling failure leaves durable session saved and readback unknown`؛ `silent scheduling loss is detected by pending-ID readback` | حفظ البيانات ونتيجة الجهاز منفصلان؛ اختبارات host بمنافذ جهاز مصطنعة |
| تغيير الجلسة أو الحساب أثناء جهاز await | إعادة reconciliation من أحدث saved state، epoch لا يعود صالحًا بعد A→B→A؛ محاولات محدودة | FN: `latest stop during device await prevents an obsolete target reschedule`؛ `owner A to B to A during async device work is a rejected attempt` | PASS مسجل؛ نجاح scheduled IDs ليس إثبات وصول إشعار فعلي |

المفاتيح الصحية الخمسة للصيام هي `wellness_fasting_session_v2`،
`wellness_fasting_started_at`، `wellness_fasting_target_hours`،
`wellness_fasting_history_v1`، `wellness_fasting_last_minutes`.
إعداد notify ليس جزءًا من تعويض هذه البيانات؛ تغيير المستخدم له لاحقًا
يبقى محفوظًا. لا يوجد متجر جلسات موازٍ.

## 3. مصفوفة القراءات المحدودة والتحليلات والمحتوى

`_executeCoachHealthRead` يلتقط `CoachHealthReadGuard` وفئة السياق اللازمة،
ثم يستدعي adapter محليًا قبل بناء السياق الشخصي الكامل أو استدعاء نموذج.
`checkAccess` يحيط بكل await ويُبطل نتيجة A→B→A أو revoke/re-enable. القراءة
لا تحتاج تأكيد كتابة ولا تنشئ journal، لذلك **Undo لا ينطبق** في كل صف هنا.
إيصال القراءة يعرض نتيجة repository؛ لا ينشئ سجلًا يعوض غياب البيانات.

| canonical action / الموضوع | handler → المصدر والحساب | الحد وreadback | التأكيد / Undo | اختبار محدد | الحالة والحدود |
|---|---|---|---|---|---|
| `read_health_history(topic: daily)` | `CoachHealthQueries.execute` → `DailyLogRepository.readLedger(day)` | ≤31 يومًا مدنيًا شاملًا و≤31 صفًا؛ حالات اليوم + الماكروز/الألياف/net carbs الفعلية | read؛ لا تأكيد كتابة ولا Undo | Q: `empty closed day returns persisted state with unknown nutrition`؛ `daily projection retains known zero separately from unknown macro` | منفذ محليًا؛ PASS مسجل؛ ليس كل تقارير analytics |
| `read_health_history(topic: sleep)` | execute → `DailyLogRepository.getForDay` | مدة manual منفصلة؛ الغياب null والصفر محفوظ؛ لا start/end يدويين مختلقين | read؛ habits focus؛ لا Undo | Q: `no sleep is absent while explicit zero sleep is a recorded value`؛ UI: `sleep read uses only requested days and never builds full context or calls model` | موصول بالسجل اليدوي فقط حاليًا |
| `read_health_history(topic: activity)` | execute → `DailyLogRepository.getForDay` وإسقاط schema التمرين القائم | manual steps منفصلة؛ ≤31 سجل تمرين متداخل إجمالًا؛ لا نصوص exercise notes الحرة أو مفاتيح غير مسموحة | read؛ training focus؛ لا Undo | QC: `exercise payload has a global bound and keeps actual log fields only`؛ RG: `training-only brief preserves zero steps and excludes sleep` | منفذ محليًا؛ لا اختراع calories أو completed workout |
| `read_health_history(topic: weight)` | execute → `WeightRepository.getForDay` | ≤31 يومًا/صفًا؛ اليوم والسياق والإصدار والوقت؛ حذف note/photo من projection | read؛ analytics focus؛ لا Undo | Q: `weight query excludes private photo paths and free-text notes`؛ `31 civil days use only per-day reads, preserve gaps, limit newest rows` | منفذ محليًا؛ PASS مسجل |
| `read_health_history(topic: measurements)` | execute → `BodyMeasurementRepository.getForDay` | الحقول الجزئية تبقى null؛ السجلات المحذوفة لا تعرض | read؛ analytics focus؛ لا Undo | Q: `partial measurements keep null fields and omit deleted records` | منفذ محليًا؛ PASS مسجل |
| `read_health_progress` | execute(topic: progress) → per-day WeightRepository + `ProgressAnalysis.evaluate` القائم | نافذة ≤31؛ الاتجاه/confidence/sample count من الحساب الحالي؛ لا fat/muscle أو ETA مخترع | read؛ analytics focus؛ لا Undo | Q: `progress uses established confidence and does not infer from one reading` | منفذ محليًا؛ تقدم وزن فقط، لا تحليل صحي مفتوح |
| `read_fasting` | `CoachFastingCommandAdapter.read` → المفاتيح الخمسة القائمة | active session/target، عدد التاريخ والمدة الأخيرة؛ لا تصدير كامل التاريخ؛ no session لا ينشئ preferences | read؛ habits focus؛ لا Undo | FA: `read-only absent fasting status creates no preferences or command`؛ `unknown history and missing last duration are not reported as zeros` | منفذ محليًا؛ جلسة الصيام والتاريخ الملخص |
| `preview_plan` | `CoachPlanCommandAdapter.preview` → `DietPlanRepository.read` والكتالوج والجدول القائم | exact pathway، saved draft ومتطلبات الوصول؛ لا save draft ولا activation ولا entitlement request | read؛ nutrition focus؛ لا Undo؛ يظهر أن التفعيل يحتاج مراجعة مستقلة | P: `preview reads saved drafts and requirements without any mutation`؛ UI: `local plan preview reads saved draft without activation or entitlement calls` | منفذ محليًا؛ PASS مسجل |
| `search_health_content` | `CoachHealthQueries.searchContent` → `CoachCatalogGrounding.answer` القائم | سؤال canonical ≤160، ≤3 نتائج/مسارات محلية موثقة، answer ≤1600 Unicode scalars؛ لا تاريخ صحي | read؛ owner فقط دون قراءة context preferences؛ لا Undo | Q: `catalog lookup bounds text and routes without reading health history`؛ `catalog routes are validated and account changes reject its result` | منفذ محليًا؛ الوصفات والتمارين في lookup الحالي فقط؛ ليس بحثًا عامًا في كل محتوى wellness أو الويب |
| موجز السياق الصحي القصير؛ ليس tool جديدًا | `coachHealthBriefProvider` → ledger اليوم + per-day habits/training/weight + الأهداف القائمة | nutrition الحالي، ونافذة وزن ≤7 أيام؛ احترام focus؛ watchers للجداول تبطل cache بعد تعديل اليوم/الهدف | read للسياق المختار؛ لا Undo | RG: `analytics reads exactly seven civil days and excludes older, future, deleted and invalid weights`؛ `a same-day meal write refreshes the brief using only the current ledger` | منفذ؛ لا تحويل سؤال صغير إلى قراءة كل التاريخ |
| إسقاط بيانات connected health الاختياري داخل adapter | existing `connectedHealthDailyStepTotals` و`compactConnectedHistoryViews`؛ لا provider fetch | provenance يميز manual/device، observedAt/local day/endedAt، permission/degraded؛ لا جمع يدوي وجهاز | read فقط إذا منح caller snapshot موثوق الملكية؛ لا Undo | QC: `sleep keeps manual duration and connected provenance separately`؛ `manual steps and native steps are not silently summed`؛ `existing energy projection avoids counting daily and latest twice` | **غير موصول إلى Coach فعليًا**: snapshot الحالي لا يثبت owner/epoch؛ لا claim live health E2E |

حد 31 يومًا يحسب باليوم المدني، لا بفترات 24 ساعة. ترتيب النتائج من الأحدث،
مع `matched/truncated/missingDays` صريحة. الواجهة النصية تختار 7 أيام عند
غياب المدى؛ يوم واحد إذا ورد تاريخ واحد بلا عدد. نافذة غير قانونية أو
failure من repository تُرفض ولا تتحول إلى «لا توجد بيانات» أو صفر.

هذه القراءات الجديدة لا تستعمل `getAll/watchAll` لسؤال صغير. هذا ليس وعدًا
بتحويل جميع reads القديمة في التطبيق: مثلًا `update_goal` في BASE يستعمل
`weights.getAll` لتعيين current weight ضمن الكتابة القديمة. تغيير ذلك خارج
هذه القراءة الجديدة ولم يُنسب إصلاحه إلى BIL‑04.

## 4. مصفوفة معايير القبول العابرة للقدرات

| المتطلب | التنفيذ / الإثبات | الحالة الدقيقة |
|---|---|---|
| intent واحد واضح قبل أي write | `LocalCoachHealthCommandParser.parse/recognizesHealthIntent`؛ grammar EN/AR صارم؛ local clarification قبل catalog/model/context | parser منفذ واختبارات مسجلة؛ صيغ غير مدعومة في `query_parser_notes_AR.md` |
| النفي/المستقبل/الشرط/طلبان/كميتان لا يتحولون إلى write | HP: `future, negated, questioned or multiple writes do not become actions` | PASS مسجل؛ لا اختيار رقم أو فعل أول بصمت |
| حفظ النص الحرفي للملاحظة | تقسيم header عن body؛ تفسير التاريخ من الرأس فقط | HP: `note body is literal and cannot change header date or execute a command`؛ PASS مسجل |
| عدم كسر صيغ BASE | recognizer يترك الطعام/الماء/كتابة الوزن/الملاحة؛ أسماء الأدوات الأصلية محفوظة مع 15 اسمًا إضافيًا صريحًا للصحة | HP: `routing leaves existing food, water, weight-write and navigation alone`؛ parser regression القائم PASS80، وregistry PASS7 عند بصمة التحقق النهائية |
| التأكيد الصحي الجديد | كل health write في AlertDialog جديد؛ cancel لا يكتب | UI: `log_sleep requires fresh confirmation in writeAllowed` و`log_exercise requires fresh confirmation in writeAllowed`؛ `cancelling model sleep and exercise proposals changes no health data`؛ **PASS25** |
| owner/permission لكل محاولة | epoch ثابت وفحص حول awaits والكتابة وUndo؛ read guard يلاحظ سحب فئة السياق | D/AN/FN/RG/UI اختبارات A→B→A والسحب بعد await وبعد journal؛ PASS مسجل |
| rollback قبل durable commit | فشل write readback أو journal داخل transaction يعيد الأثر والعملية معًا | D: `daily write readback exception rolls back actual data and native journal`؛ AN: `log_exercise rolls back its health mutation when the native journal fails`؛ PASS مسجل |
| فشل readback بعد durable commit | Native journal يحفظ `healthReceiptRecovery` ذريًا مع أثر الصحة؛ UI يعيد اكتشاف operation للمحادثة نفسها ويقرأه ولا يعيد commit | R: `lost postcommit readback is rediscovered after closing and reopening SQLite`؛ UI: `failed postcommit readback recovers exact receipt and Undo after reopening Coach` يشمل paused receipt save/no early ack، وإعادة الفتح دون تكرار وUndo؛ **PASS** في سجلي 63 و 25 |
| الاستعادة وإعادة المحاولة بعد إعادة فتح route | التحقق من هوية المحادثة المحفوظة قبل health commit؛ pending lookup ثم readOperation، append مطابق، ack بعد التحقق من receipt المحفوظ؛ Undo الحالي | UI: `approved health commit finishing after route close recovers one receipt and Undo`؛ يشمل إعادة فتح مرتين دون تكرار وUndo؛ **PASS25** |
| Undo يحترم تعديلات لاحقة | snapshot/version/digest وoverlap fence للخطة؛ فشل compensation readback يعيد Undo transaction | D: `failed compensation readback rolls Undo back with its journal untouched`؛ AN: `later identical plan activation fences Undo even when row timestamps share a second`؛ PASS مسجل |
| يوم مغلق + غياب بيانات | guard للعلامتين `closed` و`closedAt`؛ لا صفر وهمي أو أطعمة مولدة عند إغلاق يوم فارغ | C/D/Q؛ PASS مسجل |
| DST والمنطقة الزمنية | ترتيب أيام مدني؛ timestamp صيام له offset صريح؛ source metadata لا يختلط بوقت القراءة | HP: `date arithmetic remains calendar based across spring and autumn DST`؛ FA: `DST repeated wall hour remains distinct through explicit offsets`؛ `final_validation/new_york_dst_final.json/.txt`: PASS27 عند TZ=America/New_York وبصمة التحقق النهائية |
| لا نجاح إشعار زائف ولا rollback زائف للحفظ | readback pending IDs/permission مستقلة، failure أو unknown لا يمحو session | FN/UI؛ PASS مسجل ببوابة جهاز مصطنعة |
| إغلاق route مع عمل notification معلق | deadline مملوك للزيارة ويُلغى عند disposal؛ لا timer متروك في fake clock | UI: `closing route cancels a hung fasting device deadline after durable save`؛ **PASS25** مع اختبارات recovery الجديدة |
| عدم خلط manual وconnected | واجهة القراءة الحالية manual-only عمدًا لأن cache لا تحمل owner؛ projection الاختياري يفصل المصادر | QC unit PASS؛ ربط الجهاز صاحب الهوية والتحقق الميداني **غير منفذين** |
| minimization وحدود السياق | ≤31 يومًا/صفًا، ≤31 exercise متداخل، no note/photo history، category guard | Q/QC/RG/UI؛ PASS مسجل؛ لا model/provider حي |
| الخطة preview لا تغير المستخدم | لا save/activate/subscription loader في preview | P/UI؛ PASS مسجل |
| accessibility/localization | EN/AR حقيقيان، RTL semantics، Cancel/Continue، 320 logical px + text scale 2 | UI **PASS25**؛ مراجعة بشرية بصرية شاملة و 23 لغة أخرى **معلقة** |
| ownership | 0 تغيير في ملفات الأدوار الأخرى؛ 26 ملفًا مشتركًا مقترحًا بملكية BIL‑00، منها اختبار registry | `query_validation/shared_ownership_audit_final.json`: PASS؛ جميع الملفات القائمة المملوكة للأدوار الأخرى مطابقة BASE، وإزالة إدخال ملف BIL‑01 المستعاد من manifest مؤكدة؛ التدقيق التاريخي محفوظ |
| التوافق العام | لا schema migration ولا pubspec/lock upgrade ولا تغيير build35/32 | بصمات BASE وmanifest النهائي؛ portable جميع الأدوار لدى BIL‑00، **غير منفذ هنا** |

## 5. فهرس الاختبارات والسجلات — لا جمع للأعداد المتداخلة

مسار الاختبارات الجديدة المختصر في الجداول هو `test/parallel/bil04/`.
الأسماء المعلمة مثل `$tool` في المصدر توسّع فعليًا إلى canonical ID المبين
في صف القدرة؛ ليست اختبارات افتراضية. جميع fixtures صحية مصطنعة، والتخزين
الفعلـي Drift/SQLite داخل الذاكرة في أغلب الاختبارات، مع ملف SQLite مؤقت
حقيقي يُغلق ويُعاد فتحه في اختبار R الخاص بفقدان readback. اختبارات الواجهة تركّب
صفحة Flutter الفعلية مع مزود نموذج/اشتراك/جهاز مصطنع؛ ليست live E2E.

| الرمز | suite / مصدر الحالات الدقيقة | سجل النتيجة المتاح |
|---|---|---|
| N1 | `test/features/intelligence_center/coach_native_command_repository_test.dart`؛ cases وoperation_readback وundo_permission_repository parts القائمة؛ الخمس أدوات الأصلية | `final_validation/nearby_files/coach_native_command_repository_test.json/.txt`: **PASS43**؛ التشغيل المركّز السابق PASS63 = N1+R ولا يضاف إلى العدد |
| N2 | `test/features/intelligence_center/coach_native_command_behavior_test.dart`؛ `coach_native_command_behavior_cases.dart` و`coach_native_command_recovery_cases.dart` وundo/recovery lifecycle parts | `final_validation/nearby_files/coach_native_command_behavior_test.json/.txt`: **PASS48**؛ owner/confirmation/recovery/Undo للقدرات الأصلية |
| N3 | `test/features/intelligence_center/bil_tool_registry_test.dart` | `final_validation/nearby_files/bil_tool_registry_test.json/.txt`: **PASS7** بعد تثبيت 38 اسمًا صريحًا؛ FAIL السابق محفوظ في `before_registry_contract_update/nearby_files/` كما في شرح تطور العقد |
| F1 | `test/features/nutrition/coach_meal_commit_boundary_test.dart` يستورد `coach_meal_journal_cases.dart` وowner atomicity cases؛ `coach_meal_compensation_readback_test.dart` و`coach_meal_undo_permission_test.dart` | `final_validation/food_journal_regressions.json/.txt`: **PASS16 commit +6 compensation +16 Undo permission**؛ ملفات BASE غير معدلة، عند digest 48f4 النهائي |
| F2 | `test/features/nutrition/coach_meal_quantity_unit_test.dart` و`test/features/intelligence_center/coach_meal_gram_boundary_behavior_test.dart` | quantity **PASS12** ضمن `food_journal_regressions`؛ gram **PASS4** ضمن `nearby_regressions`؛ كلاهما عند digest 48f4، ولا عدّ مكرر لgram |
| F3 | `test/features/nutrition/coach_food_commit_test.dart` و`coach_food_journal_cases.dart`؛ `test/features/intelligence_center/coach_food_cards_test.dart` | جرد BASE مثبت فقط لهذين الملفين، **NOT_RUN ضمن البوابة المحلية المختارة**؛ لا PASS overlay مفترض من وجود factory/card، ولا ادعاء إكمال producer الطعام الذي يملكه BIL‑01 |
| D | `daily_life_commands_test.dart`، 28 حالة | `final_validation/owned_files/daily_life_commands_test.json/.txt`: **PASS28** |
| C | `closed_day_food_test.dart`، 19 حالة | `final_validation/owned_files/closed_day_food_test.json/.txt`: **PASS19** |
| Q | `health_query_adapter_test.dart`، 14 حالة | `final_validation/owned_files/health_query_adapter_test.json/.txt`: **PASS14** |
| QC | `health_query_connected_test.dart`، 8 حالة | `final_validation/owned_files/health_query_connected_test.json/.txt`: **PASS8**؛ synthetic connected snapshot، لا صلاحية أو مصدر جهاز حي |
| HP | `health_parser_test.dart`، 13 حالة | `final_validation/owned_files/health_parser_test.json/.txt`: **PASS13**؛ يتضمن إصلاح اسم read topic الثنائي اللغة |
| FA | `fasting_command_adapter_test.dart`، 23 حالة | `final_validation/owned_files/fasting_command_adapter_test.json/.txt`: **PASS23** |
| FN | `fasting_notification_sync_test.dart`، 21 حالة | `final_validation/owned_files/fasting_notification_sync_test.json/.txt`: **PASS21**؛ بعد إصلاح queue، مع حفظ السجلات السابقة الفاشلة |
| RG | `health_read_guard_brief_test.dart`، 23 حالة | `final_validation/owned_files/health_read_guard_brief_test.json/.txt`: **PASS23** |
| A | `activity_command_adapter_test.dart`، 14 حالة | `final_validation/owned_files/activity_command_adapter_test.json/.txt`: **PASS14** |
| P | `plan_command_adapter_test.dart`، 15 حالة | `final_validation/owned_files/plan_command_adapter_test.json/.txt`: **PASS15** |
| AN | `activity_plan_native_test.dart`، 16 حالة | `final_validation/owned_files/activity_plan_native_test.json/.txt`: **PASS16**؛ يستورد `activity_plan_native_failure_cases.dart` |
| UI | `health_coach_ui_test.dart`، 25 حالة | `final_validation/owned_files/health_coach_ui_test.json/.txt`: **PASS25**؛ يشمل recovery وRTL/semantics؛ سجل UI25 المركّز السابق محفوظ |
| R | `health_receipt_recovery_test.dart`، 20 حالة | `final_validation/owned_files/health_receipt_recovery_test.json/.txt`: **PASS20**؛ التشغيل المركّز السابق PASS63 يضم N1 نفسه ولا يضاف مرة أخرى |

سجلات D/C/Q/QC/HP/FA/FN/RG/A/P/AN/UI/R وN1/N2/N3 أعلاه كلها عند البصمة
الثابتة `48f4e77f93293f0a51bcc21728b8d5db7f376c33cf61bf28eabc9255b0333e87`.
يجمع [all_owned_files_final.json](final_validation/all_owned_files_final.json)
**239 حالة في 13 ملفًا غير متداخل، كل ملف في عملية Flutter منفصلة**.
أُعيدت جميع الملفات من الصفر بعد تغيير عقد registry، دون إعادة استعمال
تقارير البصمة السابقة. ثبُتت بصمات 2979 ملف مصدر/مدخل قبل كل تشغيل وبعده.
لا تُجمع إعادة تشغيل الحالة ذاتها أو السجلات المركّزة القديمة مع هذه الحالات.

[nearby_regressions.json](final_validation/nearby_regressions.json) يجمع
**300 حالة في 9 ملفات غير متداخلة** عند البصمة نفسها. هذه هي القائمة الفعلية؛
لا تُنسب النتيجة إلى جميع اختبارات الطعام أو التطبيق لمجرد وجودها في BASE:

| ملف التراجع القائم داخل `test/features/intelligence_center/` | الحالات الناجحة | الدليل الفردي داخل `final_validation/nearby_files/` |
|---|---|---|
| `coach_native_command_behavior_test.dart` | 48 | `coach_native_command_behavior_test.json/.txt` |
| `coach_native_command_repository_test.dart` | 43 | `coach_native_command_repository_test.json/.txt` |
| `coach_meal_gram_boundary_behavior_test.dart` | 4 | `coach_meal_gram_boundary_behavior_test.json/.txt` |
| `coach_food_receipt_binding_test.dart` | 13 | `coach_food_receipt_binding_test.json/.txt` |
| `coach_nutrition_remaining_evidence_test.dart` | 74 | `coach_nutrition_remaining_evidence_test.json/.txt` |
| `coach_action_admission_contract_test.dart` | 29 | `coach_action_admission_contract_test.json/.txt` |
| `coach_parser_numeric_intent_regression_test.dart` | 80 | `coach_parser_numeric_intent_regression_test.json/.txt` |
| `coach_action_permission_test.dart` | 2 | `coach_action_permission_test.json/.txt` |
| `bil_tool_registry_test.dart` | 7 | `bil_tool_registry_test.json/.txt` |


[food_journal_regressions.json](final_validation/food_journal_regressions.json)
يثبت **50 حالة في أربعة ملفات BASE غير معدلة** عند digest 48f4 نفسه:

| الملف داخل `test/features/nutrition/` | الحالات الناجحة |
|---|---|
| `coach_meal_commit_boundary_test.dart` | 16 |
| `coach_meal_compensation_readback_test.dart` | 6 |
| `coach_meal_undo_permission_test.dart` | 16 |
| `coach_meal_quantity_unit_test.dart` | 12 |

اختيرت هذه الإعادة التكميلية لأن guards اليوم المغلق تعدل حدود
`MealRepository` المشتركة، ولإثبات حفظ journal الطعام وrollback وUndo
ودلالة الكمية. الملفات الأربع منفصلة عن التسعة أعلاه؛ gram ليس مضافًا
مرة ثانية. المجموع النهائي **239 +300 +50 =589 حالة غير متداخلة**.

أدلة أخرى قريبة، منفصلة عن القائمة:

- `daily_life_validation/baseline_regression_01.json`: PASS لاختبارات
  `test/authoritative_daily_ledger_test.dart`، `test/repository_test.dart`،
  `test/features/wellness/fasting_session_test.dart`،
  `test/features/wellness/fasting_preferences_transaction_test.dart`.
- `query_validation/query_parser_new_york_final.json`: PASS27 عند
  `TZ=America/New_York` لquery adapter/parser. تتحقق fixture أن يوم الربيع
  23 ساعة ويوم الخريف 25 ساعة قبل اختبار المنطق المدني. هذه إعادة تحقق، لا
  27 اختبارًا فريدًا إضافيًا فوق PASS54. أعيد الملفان على المصدر
  النهائي في `final_validation/new_york_dst_final.json/.txt`: PASS27 عند
  digest 48f4؛ لا تُضاف إلى 239 بوصفها اختبارات فريدة جديدة.
- `query_validation/analyze_queries_parser_meals_final.json`: exit0،
  `No issues found` للملفات التسعة المحددة فيه؛ ليس full analyzer.
- `query_validation/health_string_tool_analyze_final.json`: exit0،
  `No issues found` لأداة AST؛ لا اختبار منتج إضافي.
- `activity_plan_ui_validation/evidence.json` يحفظ أسماء التشغيلات الأولية
  الفاشلة والمتوقفة، أعدادها وسبب تعديل fixture أو إصلاح lifecycle.

### سجل البوابة النهائية

| البوابة | الحالة في هذه النسخة | شرط إغلاقها |
|---|---|---|
| إصلاح locator صحي ذري + discovery/ack + lost-readback/reopen | **PASS محلي** | R وUI أعلاه؛ owner/conversation filtering قبل LIMIT؛ CASE يحمي JSON؛ ack يستعمل CAS UPDATE داخل transaction ويحفظ SQLite rowid |
| جميع ملفات اختبارات BIL‑04 على source ثابت | **PASS239 / 13 ملفًا عند digest 48f4** | `final_validation/all_owned_files_final.json`؛ كل الملفات الأصلية أُعيدت في عمليات مستقلة؛ لا exclusions ولا ادعاء تشغيل واحد |
| regressions Native/food/parser/registry القريبة | **PASS300 / 9 ملفات عند digest 48f4** | `final_validation/nearby_regressions.json` و`nearby_files/`؛ القائمتان والأعداد مفصلتان أعلاه |
| معاملات الطعام وcompensation وUndo والوحدات | **PASS50 / 4 ملفات عند digest 48f4** | `final_validation/food_journal_regressions.json/.txt`؛ commit16 +compensation6 +Undo permission16 +quantity12؛ لا إعادة عدّ gram القائم في مجموعة الـ9 |
| إعادة DST على المصدر النهائي | **PASS27 / ملفين عند digest 48f4** | `final_validation/new_york_dst_final.json/.txt`، TZ=America/New_York؛ تحقق 23/25 ساعة ثم عمليات الأيام المدنية؛ 27 إعادة تحقق متداخلة مع 239 |
| full analyzer | **PASS عند digest 48f4 النهائي** | `final_validation/full_analyze_final.json/.txt`؛ `flutter analyze --no-pub --fatal-infos`، exit0 وNo issues؛ 2979 مدخلًا ببصمات ثابتة أثناء التشغيل |
| final format | **PASS عند digest 48f4 النهائي** | `final_validation/format_final.json/.txt`؛ 60 ملفًا، 0 تغييرات، exit0؛ أول فحص قبل التنسيق محفوظ ضمن أرشيف النتائج السابقة |
| final localization rescan | **PASS مع تصنيف SQL موثق** | 147 زوج EN/AR، 0 placeholder mismatches، 39 مصدرًا ببصمات حالية؛ AST الخام احتفظ بـREVIEW_REQUIRED لliteral SQL داخلي واحد؛ `health_strings_manual_review.json` يثبت استبعاده، و`health_strings_catalog_checks.json` PASS |
| portable على تركيب كل الأدوار | **NOT_RUN لدى BIL‑04** | مسؤولية BIL‑00 بعد الدمج اليدوي |

محاولتا تشغيل كل ملفات الدور في عملية Flutter واحدة ليستا دليلاً ناجحًا:
خرج frontend/compiler وعلق الانتقال إلى ملف لاحق، فأوقفهما العامل الرئيسي
بـCtrl‑C/130. أكملت الأولى 23 حالة والثانية 48 حالة دون فشل assertion مسجل
في هذه الحالات، لكن التشغيلين لم يكتملَا، ولم ينتج recorder فيهما snapshots
نهائية مكتملة. السجلات وinterruption JSON محفوظة باسمَي `all_owned` و
`all_owned_final`. لا تدخل هذه الأعداد الجزئية في مجموع النجاح النهائي.
التحقق البديل يشغّل كل الملفات الأصلية على حدة بالتتابع؛ لا تعديل assertions
أو timeouts أو skips أو exclusions أو شيفرة المصدر للحصول على النتيجة.

في التشغيل السابق عند digest 5097 نجحت ستة ملفات تضم 121 حالة؛ استُكملت
الملفات السبعة بإعداد compiler أقل استهلاكًا للذاكرة، وأثبت التقرير السابق
239 حالة في 13 ملفًا. هذه الأدلة، بما فيها إعدادها، مؤرشفة في
`final_validation/before_registry_contract_update/` ولا تُخلط مع البوابة الحالية.

إعادة التحقق النهائية من الصفر عند digest 48f4 استعملت خيار Flutter القائم
`--frontend-server-starter-path` لتشغيل **AOT snapshot نفسه** من SDK المثبت
بـ`--old_gen_heap_size=1024` و`--new_gen_semi_max_size=16` لكل الملفات.
هذا إعداد runtime فقط؛ لا يعدل SDK أو شيفرة التطبيق أو timeouts أو skips.
تعديل اختبار registry مستقل وصريح كما في الفقرة التالية. إعداد 512MB السابق
واجه نفاد ذاكرة compiler قبل بدء بعض الاختبارات؛ سجله
`ui_compiler_512mb_failure.txt` محفوظ، ولا تُعد هذه المحاولة اختبارًا ناجحًا.
المصدر النصي للlauncher وبصمته وبصمة snapshot وruntime موثقة في
[compiler_launch_configuration.json](final_validation/compiler_launch_configuration.json)
و`compiler_heap_starter.dart.txt`. فحص `--print_flags` فيه probe إعدادات،
وليس اختبارًا ناجحًا؛ لا يدخل في عدد الحالات. launcher خارج بصمة مصدر
التطبيق، وله SHA‑256 منفصلة معلنة في التقرير.

### الانتقال التاريخي لعقد registry: 5097 → 93005

السجل `final_validation/before_registry_contract_update/nearby_files/bil_tool_registry_test.txt`
يحفظ فشل اختبار BASE عند توقع طول ثابت 23، بينما الإضافة المطلوبة ترفع
المجموعة إلى 38: الأدوات الأصلية الـ23 والأدوات الصحية الـ15. المقترح ضمن
`integration-proposal.patch` يقارن مجموعة الأسماء الـ38 صراحةً؛ كل سطور
الاختبار الأخرى محفوظة، بما فيها assertions اللاحقة. هذا تطور صريح للعقد
لدى BIL‑00، دون حذف حالات أو تعطيل assertions أو قبول عدد غير محدد.

[registry_contract_source_transition.json](query_validation/registry_contract_source_transition.json)
يوثق المرحلة التاريخية من digest 5097 إلى
`93005f00fe40bb77bedfbea5ad43752de23ef6f526d6490ad9a82a49f978ad65`،
بمقارنة 2978 مدخلًا: الفرق الوحيد هو اختبار registry، في كتلة واحدة تستبدل
`hasLength(23)` بـ`unorderedEquals(expectedToolNames)`. أصل manifest
المرحلة الثانية أصبح محفوظًا في `before_localization_builder_sync`؛ لا
يشير التقرير التاريخي إلى manifest المصدر النهائي الأحدث. لا تغيير تطبيق
بين هاتين المرحلتين. الاختبار ضمن ملكية BIL‑00 الافتراضية؛ عدد الملفات
المشتركة المقترحة 26، ولا ملف مملوك لدور آخر ضمنها. اجتاز الاختبار الحالي
7 حالات، وتحفظ سجلات المراحل نتائجها دون نقل نجاح إحداها إلى الأخرى.

### مزامنة أداة الترجمة: 93005 → 48f4

كشف فحص اتساق الحزمة أن `tool/qa_parallel/bil04/build_health_strings.py`
موجود أصلًا في ملفات الدور المسلّمة، لكنه لم يكن منسوخًا إلى نسخة validation.
نُسخت بايتاته نفسها: 8271 بايت، SHA‑256
`98f2cb42bca07861b9e922a402a6135bbba21971d846387b3f50b2fcaf7e48f7`.
لا تعديل لهذه الأداة أو لمصدر التطبيق أو الاختبارات في هذه الخطوة.

[localization_builder_source_transition.json](query_validation/localization_builder_source_transition.json)
يثبت أن بصمات المدخلات السابقة الـ2978 جميعها محفوظة، وأن الإضافة الوحيدة
هي الأداة المذكورة. أصبح النطاق 2979 مدخلًا والبصمة النهائية
`48f4e77f93293f0a51bcc21728b8d5db7f376c33cf61bf28eabc9255b0333e87`.
أُرشفت بوابات digest 93005 المكتملة تحت
`final_validation/before_localization_builder_sync/`، ثم أُعيدت البوابات الست
من الصفر على المصدر الكامل النهائي: 239 +300 +50 =589 حالة غير متداخلة،
وDST27 إعادة تحقق، والتحليل الكامل والتنسيق. لا تُجمع إعادة التشغيل هذه
مع نتائج المراحل السابقة بوصفها حالات إضافية.

نجحت إعادة بناء ملفات الترجمة في مجلد معزول بالقوالب الـ147 وبصمات المصادر
الـ39 نفسها، وبقي تحذير SQL الداخلي الواحد في التقرير الخام كما هو؛ الدليل: `final_validation/localization_builder_reproduction.json`.
الاستبعاد اليدوي الموثق للنص الداخلي ما زال قائمًا، ولم يتحول إلى ادعاء
مراجعة بشرية للغات المتبقية.

## 6. ما يبقى محدودًا أو غير منفذ عند التسليم

1. **الدمج المشترك إلزامي.** adapters/new tests مملوكة لـBIL‑04؛ registry،
   enum/journal، action/query/UI/recovery وrepository roots مقترحات منفصلة.
   لا توجد وعود بتطبيق hunks تلقائيًا على اقتراحات الأدوار الأخرى.
2. **المحلل محدود بصيغ مثبتة.** الأرقام بالكلمات، ranges الحرة، عدة أفعال أو
   قيم، timestamps غير الصريحة، أسماء تمارين أو pathway IDs غير موثقة،
   والموافقة السريرية/إذن الرؤى الضمنيان لا ينفذون كتابة. التفاصيل والأمثلة
   في `query_parser_notes_AR.md` و`FIRST_USE_NOTES_AR.md`.
3. **التحليلات محددة.** progress هو اتجاه وزن بالحساب الحالي، وdaily هو
   ledger/مغذيات اليوم؛ لا تحليل طبي شامل أو مقارنة أجهزة أو ETA جديد.
4. **connected health ليس موصولًا إلى جواب Coach.** وجود adapter واختبارات
   provenance المصطنعة لا يثبت ownership لمخزن الجهاز القائم. يلزم عقد
   owner/epoch موثوق ومراجعة تكامل لاحقة قبل حقنه.
5. **الإشعارات لها حد تحقق.** فحص IDs المعلقة والخيارات لا يثبت تسليم نظام
   التشغيل للإشعار على هاتف فعلي. لا اختبار حي أو device build هنا.
6. **التعريب والترجمة.** `strings.en.json` و`strings.ar.json` يجمعان النصوص
   الفعلية مع mapping وplaceholders. التطبيق يدعم 25 لغة إجمالًا؛ **23 لغة
   أخرى PENDING_HUMAN_TRANSLATION_AND_REVIEW** وليست نسخًا إنجليزية محسوبة
   ترجمة. المراجعة اللغوية البشرية الشاملة ولقطات المرجع/RTL على الأجهزة
   ما زالت pending؛ PASS semantics/widget لا يغلق المطابقة البصرية كلها.
7. **الاستخدام الأول مقترح موثق.** FIRST_USE يبين triggers والنص وskip/reopen
   وowner-local-state المقترح؛ لم يُبنَ onboarding بديل ولم يُحفظ consent
   أو opt-in تلقائيًا.
8. **حدود الأدوار.** الوصفات والحصص وكل صيغ الطعام في BIL‑01؛ الإعدادات
   العامة واللغة والذاكرة العامة في BIL‑03؛ لم تُعدَّل ملفاتهم. لا شبكات
   اجتماعية أو شراء أو حذف حساب أو كتابة إنتاج أو تعديل build35/32.
9. **اكتشاف الإيصالات محدود.** يعيد أحدث 16 مرشحًا للمحادثة والمالك افتراضيًا،
   حتى 32 إذا طلب caller، دون pagination شاملة. السجل المتضرر الذي يمر من
   SQL prefilter قد يستهلك موضعًا ثم يُرفض في decode؛ لا ادعاء استعادة كل
   سجل قديم دفعة واحدة. ack يغيّر metadata فقط؛ لا يعيد ترتيب journal أو
   يمنح إذن كتابة/Undo. عمليات لاحقة لا يستطيع فحص 128 استبعاد تعارضها تمنع
   Undo احترازيًا.

أُغلقت البوابات المحلية أعلاه عند مصدر ثابت، وتدعم حالة
`READY_FOR_INTEGRATION` للحزمة المحددة مع `owned.patch` ومقترح الدمج
والتبعيات المعلنة. يبقى دمج BIL‑00 والتحقق portable على تركيب جميع الأدوار
منفصلين. هذه الحالة لا تعني اكتمال 25 لغة أو device/live-provider E2E أو
صلاحية إصدار production. `production_deployed=false` في جميع الحالات.
