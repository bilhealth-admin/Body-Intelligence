# BIL Smart Plan — حزمة كود وتسليم إلى Codex — 22 أكتوبر 2026

## 0. الحالة القانونية والتنفيذية لهذه الحزمة

- الأساس المحمي: bilhealth-admin/Body-Intelligence، SHA = 31554b3e078667a38bd3c53aa105f5f1d2a4dc96.
- الفرع الأصلي integration/bil-qa-media-policy-20261011 والكوميت المحمي لا يُعدّلان مطلقًا بسبب هذه الحزمة.
- فرع التطوير المنفصل لهذه الحزمة هو feature/bil-smart-plan-handoff-20261022.
- المرحلة المنفذة = نواة تطبيق محلية مرتبطة فعليًا بالراوتر، شاشة BIL Smart Plan، نماذج بيانات، جدولة، كتالوجات رياضة وغذاء موثوقة، حفظ محلي، اختبارات وحدات مكتوبة، ووثائق امتثال ومقترح قاعدة سحابية.
- غير مثبت النجاح: flutter analyze أو الاختبارات المحلية أو Golden أو بناء وتوقيع iOS/Android. جهاز المطور البعيد غير متصل وبيئة هذه الجلسة لا تتضمن Flutter/Dart.
- غير منفذ: نشر Supabase، ترحيل قاعدة البيانات، الربط السحابي متعدد الأجهزة، أدوات chatbot الجديدة، مزامنة التدريب مع دفتر الأنشطة، التكامل الكامل مع HealthKit/Health Connect، تمارين المنزل الكاملة، الإشعارات، مساعد تدريب آلي معتمد من الطبيب. كلها موصوفة في مراحل التسليم التالية.
- لا تعلن أن هذه الحزمة جاهزة للمتجر أو أن جميع الوظائف أصبحت مكتملة إلى أن تُنجز البنود المتبقية ببرهان اختبارات وتشغيل فعلي.

## 1. مقصد المالك

تحويل AI Coach إلى مدير رحلة متكامل:
- إنشاء برنامج تغذية، تمارين، أو برنامج مشترك.
- أربعة آفاق: 7 أيام، شهر تقويمي، 3 أشهر، 6 أشهر تقويمية.
- تمرين اليوم بضغطة؛ عند البدء تعرض تمارين معتمدة من المكتبة وتُسجّل النتيجة بعد تأكيد المستخدم.
- غذاء اليوم مع اقتراحات من وصفات حقيقية ومراعاة نمط الأكل والحساسية والقيود.
- خطة محفوظة منفصلة عن نص الشات، مرتبة يوميًا وأسبوعيًا؛ تتكيف مع تقدم المستخدم وملاحظاته.
- لا نسيان للخطة عندما يفشل مزود الذكاء الاصطناعي، ولا تغييرات بيانات خفية، ولا ادعاء تنفيذ دون إيصال.
- أيقونة My Plan / خطتي بجانب Tools / الأدوات في واجهة Coach Overview، ومدخل إضافي في قائمة المدرب؛ لا تبويب سادس في شريط التطبيق الخماسي.

## 2. الجرد المؤكد من الكود المرجعي

المكونات المستخدمة:
- lib/features/wellness/repositories/gym_six_month_plan_repository.dart
- lib/features/wellness/repositories/workout_release_catalog_repository.dart
- lib/features/wellness/domain/gym_six_month_plan.dart
- lib/features/nutrition/domain/dietary_preferences.dart
- lib/features/meal_planner/services/meal_plan_engine.dart
- lib/features/meal_planner/domain/meal_plan.dart
- lib/data/repositories/preferences_repository.dart
- lib/features/profile/providers/user_profile_provider.dart
- lib/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart
- lib/app/router/app_router.dart
- lib/app/router/app_wellness_routes.dart
- lib/features/commerce/presentation/premium_route_glass_gate.dart

معايير الواجهة: BilPearlBackdrop وBilPearlMaterialCard والـ Theme الحالي، دعم RTL والإنجليزية، وحدود عرض 760، عدم تغيير الاشتراك أو الشريط الخماسي.

## 3. ملفات التنفيذ التي يجب أن يقرأها Codex

- lib/features/smart_plan/domain/bil_smart_plan.dart
  نماذج مخطط مركّب، serialization، الترقيم، التحقق من يوم مدني محلي، حالة الخطة، تأكيد فعل التمرين.
- lib/features/smart_plan/domain/bil_smart_plan_engine.dart
  مولد حتمي مقيد بمرجع كتالوج، جدول طويل، رفض النواقص، إشارات مراجعة طبية، منع اعتباره علاجًا.
- lib/features/smart_plan/services/bil_smart_plan_catalog.dart
  الربط بكتالوج التمارين الصادر والمراجَع والوجبات المفلترة باستخدام DietaryCompatibility.
- lib/features/smart_plan/data/bil_smart_plan_repository.dart
  تخزين محلي عبر Drift Preferences، مطابقة المستخدم قبل وبعد await وcompare-and-swap revision.
- lib/features/smart_plan/presentation/bil_smart_plan_page.dart
  صفحة قابلة للاستخدام محليًا: إنشاء مسودة، تأكيد، اليوم، الجدول، التقدم، حفظ/استرجاع.
- lib/app/router/app_router.dart + app_wellness_routes.dart
  المسار /smart-plan وراء PremiumGateFeature.personalPlan القائم؛ لا تغيير للشراء.
- lib/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart
  رابط خطتي بجانب الأدوات.
- lib/features/intelligence_center/presentation/intelligence_coach_menu.dart
  رابط في القائمة.
- lib/features/intelligence_center/presentation/intelligence_reference_workspace_flow.dart
  رجوع لمسار المدرب الأصلي بعد فتح الخطة عبر push.
- test/features/smart_plan/bil_smart_plan_engine_test.dart
  فحوص وحدات حتمية.
- docs/qa_next/BIL_20261022_SMART_PLAN_POLICY_GATES.md
  تفسير سياسات Apple وGoogle وقائمة الإقرارات والشروط.
- docs/qa_next/BIL_20261022_SMART_PLAN_RELEASE_QA.md
  مصفوفة اختبارات وإصلاحات القبول.
- docs/qa_next/BIL_20261022_SMART_PLAN_CLOUD_PROPOSAL.sql
  تصميم قاعدة مستقبلية فقط، لا تشغيل أو نشر الآن.

## 4. الحالة الفعلية والحدود

النواة تنشئ مسودة فقط؛ لا تُفعّل إلا بعد ضغط واعتماد المستخدم.
المستخدم يحدد أربع مدد والتدريب/الغذاء/المشترك، وتيرة تدريب 2–6 أسبوعياً.
جلسات الرياضة مشتقة من GymSixMonthPlanRepository وتُقبل فقط إذا كل تمرين في فهرس الإصدارات المعتمد؛ ملف الوسائط وتشغيل الفيديو يظلان بيد مكتبة التمارين الموثقة ولا يُقدّم رابط خام على أنه فيديو قابل للتشغيل.
الوجبات تعرض ثلاثة اقتراحات يومية عند توافر قائمة ملائمة لكل الوجبات. لا يُنشئ النظام عجز سعرات أو جرعات علاجية، ولا يدخل تلك المقترحات سجل الطعام.
التغذية التي لا تتوافق مع القيود المحفوظة تتوقف بوضوح؛ لا يتخطى Allergy أو Religious pattern ليصنع جدولًا.
الأعراض الخطرة أو القيود الطبية ترجع إلى مراجعة مختص بدل إصدار توصية مؤتمتة.
الإكمال يُثبت داخل سجل الخطة المحلي فقط بإقرار المستخدم، ولا يدّعي تسجيل تمرين في DailyLog أو HealthKit.

قيود مهمة:
- هذا النموذج لا يدعم في المرحلة الحالية إعداد تمارين منزلية يومية موثقة؛ لا تملأها بتمارين مختلقة.
- توجد وصفات قليلة؛ نظام الوجبات يحتاج تنوعًا وتخطيط سعرات ومغذيات من مصدر معتمد مع مراجعة شخصية قبل وصفه نظامًا غذائيًا كاملًا.
- تخزين Preferences المحلي وحده لا يكفي للمزامنة متعددة الأجهزة والتصدير والحذف المتكامل. يجب تنفيذ عقد المزامنة السحابية أدناه.
- لم يتم تغيير Edge Function ai-coach ولا إعادة تهيئة مخصصات الرصيد. لا تعرض أمر خطة جديدًا في Gemini schema قبل إنشاء registry وclient validation وreceipts واختبارات.

## 5. التكامل الكامل التالي — مهمات Codex إلزامية قبل الدمج

أ. أدوات Coach:
- إضافة read_active_smart_plan, create_smart_plan_draft, preview_smart_plan_day, request_smart_plan_revision, record_smart_plan_workout إلى BilToolRegistry مع أسماء ثابتة ووثائق arguments.
- القراءة دون كتابة؛ المسودات مع موافقة؛ الحفظ والتعديلات وحالة الإتمام مع تأكيد وإيصال client receipt، وعقود UNDO محدودة.
- لا نص من نموذج LLM يثبت حصول تسجيل. أي عبارة مثل I logged your weight أو أتممت التمرين محظورة إلا بعد receipt متحقق.
- فهم نية خطة vs هدف وزني vs تسجيل فعل vs سؤال، مع اختبارات عبارة please i need to plan وهدف 60kg خلال أسبوع وأريد تمرين اليوم.
- رفض AI output إذا خلط الرسائل أو ادعى إجراء غير مثبت؛ لا تتعامل مع عبارة حرة كـ JSON action صالح.
- استخدام user-approved privacy disclosure قبل إرسال صورة أو ملف أو بيانات صحية إلى Gemini.

ب. ذاكرة وجدولة:
- مخطط مخزن منفصل عن 12 آخر رسالة شات وعن 50 حقيقة صغيرة.
- ربط plan_id + plan_revision + horizon + today_date + planned vs actual + adherence بحزمة سياق قصيرة ذات provenance حقيقي.
- تحديثات أسبوعية: للمستخدم قبول أو رفض التعديل، لا كتابة صامتة لخطة الأشهر القادمة.
- تحفظ الحصص المنجزة بأصلها الفعلي مع عدم المبالغة أو عبارات ضغط.
- تباين التمرينات ضمن حدود المحتوى الموثق وبالرجوع للاصابة والقدرة والتقدم؛ الراحة والتعافي جزء من الجدول.

ج. مزامنة:
- المرفق SQL اقتراح لا ترحيل جاهز؛ يُراجع الأسماء الموجودة أولاً.
- نسق cache محلي + cloud canonical، اختبارات multi-device CAS، تعارض حقيقي، reconnect، sign-out/auth switch، restore، deletion، RLS وسباق الكتابة.
- لا تسرب بين الحسابات؛ owner_id من التوكن لا من قيمة غير موثوقة بالعميل.
- أدرج خطط Smart Plan في التصدير والحذف الإجباريين بعد التحقق من سياسة الاحتفاظ.
- لا تصدر Data Safety / App Privacy قبل تدقيق حقيقي لما خرج من الجهاز.

د. تتمة الواجهات:
- تكملة تصميم تفاصيل التمرين: فيديو مرخص إن توفر، إرشادات، مجموعات وتكرارات موثقة، راحة، شدة محسوسة، تعديلات وتأجيلات.
- دعم المنزل/الجيم/السفر والمعدات والأهداف مع catalog validators، تقارير أسبوعية، progress وadherence.
- اليوم الغائب من الخطة يظهر بوضوح؛ لا تفتح جلسة أخرى بوصفها اليوم.
- Dynamic Type وVoiceOver وTalkBack وأسماء صحيحة وRTL ومناطق لمس 44pt، اختبارات الأجهزة الصغيرة ولوحة المفاتيح.
- النسخة الرسمية لا تضيف شريط تنقل جديد ولا تغيّر طريقة شراء Premium ولا Entitlements.

هـ. الاعتماد الصحي:
- استكمال استبيان العمر والقدرة والإصابة والحمل/القيود المعروفة عندما تنطبق على المستخدم، وعدم التشخيص.
- تنبيه غير وصمي للطاقة المنخفضة والتغيرات السريعة، وطلب مراجعة المختص، ولا تصنع خططًا طبية أو حميات قاسية.
- لا أرقام علاجية أو غذائية مخترعة. الغذاء المستهدف يتبع حسابات NutritionGoals الموثقة وليس طلبًا لغويًا.
- لا تشجيع على التعويض القهري عن الطعام بالتمارين، ولا أحكام أخلاقية على الوزن أو الوجبات.
- منطق السلامة الحالي حد أدنى؛ يجب توسيعه والتحقق السريري قبل فتح التوليد الشخصي على الإنتاج.

## 6. تشخيص 503 المؤكد في 22/10

خلال 17:20–17:35 بالتوقيت المحلي في سجلات Supabase لوظيفة ai-coach:
- ثلاث استجابات 200 واثنتان 503.
- سطران لحدث ai_coach_failure: stage gemini_provider، elapsed_ms قرابة 20772 و20544، مع compensation_succeeded=true.
- وظيفة production ai-coach ذات version 112، وserver.ts مطابق للكوميت المرجعي.
- محاولة كل Gemini 10000ms وfallback محتمل. لا دليل قطعي على سبب الخطأ أكثر من انتهاء استدعاء الخادم عند Gemini.
- مطلوب تمييز provider_timeout عن provider_http_429 وinvalid_schema ومشاكل الفواتير دون تسريب أي مدخل شخصي، ومع telemetry لا تحتوي نصوص الوجبات أو الأعراض.

## 7. أمر التنفيذ المقترح لـ Codex

اقرأ هذه الوثيقة كاملة، ثم افتح فرع feature/bil-smart-plan-handoff-20261022 في worktree مستقل دون لمس integration/bil-qa-media-policy-20261011 أو SHA 31554b3e. احصر ملفات الحزمة والاختبارات. تحقق من المخطط الحالي؛ أصلح أي أخطاء compile/format أو runtime من الكود المضاف، ولا تنقل غير المراجع إلى الكوميت المحمي. شغل مركّزات smart_plan أولًا ثم targeted coach/navigation/nutrition/workout. بعد اعتماد التصميم، أنجز التكامل الناقص مع أوامر Coach والمزامنة والترقية الآمنة للمخطط، واختبر unit/widget/integration/RLS/offline/auth-boundary/RTL/Golden/Store-receipt. اعمل flutter analyze كامل ثم full tests على مصدر مجمّد وبراهين SHA بدون إعادة غير الضروري؛ لا توقف CI العام ولا تعيد رفع TestFlight إلا بأمر منفصل. لا تدمج إلى الفرع المحمي تلقائيًا.

## 8. معايير قبول نهائية غير قابلة للاختصار

[ ] فحص flutter analyze صفر أخطاء وتحذيرات جديدة ذات صلة.
[ ] جميع الاختبارات المضافة تمر فعليًا، لا مجرد وجود ملفات.
[ ] لا خرق في subscription/StoreKit/Play Billing ولا تجاوز gate.
[ ] Snapshot بصري للمسارات الموجودة وCoach لا يتغير إلا المعتمد.
[ ] كل يوم له تاريخ مدني مستقر عبر DST ومناطق التوقيت.
[ ] إنشاء/حفظ/استرجاع/تفعيل/توقيف/تمرين منجز بموافقة صريحة.
[ ] AI actions validated؛ لا كذب تنفيذ ولا كتابة بالخطأ.
[ ] لا تغييرات بيانات عبر حسابات، ولا تسرب بعد logout.
[ ] اختلاف الأجهزة ومصادر البيانات لا يسبب conflict أو overwrites.
[ ] تفضيلات الحساسيات المحفوظة تسبق اقتراحات النظام.
[ ] لا إرسال health data لطرف ثالث بغير الموافقة المحددة.
[ ] Data Safety / App Privacy / Health declaration / review notes محدّثة بناء على السلوك الحقيقي فقط.
[ ] فيديوهات وروابط التمارين من المصدر المعتمد والترخيص.
[ ] تقرير فحوص مركزية وشاملة وGolden/محاكاة Native فعلي.
[ ] لا نشر cloud أو migration أو اختبار مستخدمين حقيقيين قبل موافقة منفصلة.

## 9. فلسفة الإطلاق

الشيفرة الحالية تثبت اتجاه المنتج وتقدم مسارًا محليًا ملموسًا لكنها ليست إعلان اكتمال النسخة. لا يُسمح اختصار هذا الوصف إلى تم الإصلاح أو جاهز للمتجر. أي gap يكتشفه Codex يدوّنه ويعالج بأثر اختباري أو يبقي release blocked.
