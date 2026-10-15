# BIL — أذونات الصحة وتجدد القراءات: مقارنة رسمية وإصلاح مثبت

تاريخ البحث: 15 أكتوبر 2026. تكليف المالك: اختيار السلوك الصحيح بعد سؤال الساعة الفارغة في iOS35، بالرجوع إلى Apple وGoogle وMyFitnessPal. هذه إضافة إلى مطابقة الملفات7–18، وليست إعادة اختبار157 حالة منجزة.

## النتيجة التنفيذية

الربط يكون باختيار المستخدم. تعرض الواجهة البيانات المسموح بها فقط، وتحفظ آخر قراءة موثقة مع تاريخها عند تعطل تحديث عابر. توجد إعادة محاولة يدوية وتحديث أثناء الوجود في التطبيق؛ لا تُطلب أذونات إضافية عند كل دخول، ولا تُضاف كتابة أو قراءة خلفية خفية.

معظم هذا منفذ بالفعل في BIL. كُشف نقص واحد إضافي وأُصلح: مؤقت التحديث كل دقيقة كان يضيف callback بعد الرسم دون طلب إطار. عند سكون الشاشة بعد فشل قراءة أولى، يظل callback منتظرًا حتى لمسة أو رسم آخر. اختباران فشلا قبل الإصلاح بالنتيجة الفعلية1 قراءة بدل2 على إعدادَي iOS وAndroid. أضيف `ensureVisualUpdate()`؛ نجحت25/25 من الحالات المتأثرة بعده، دون تغيير شكل الساعة أو Home أو وتيرة المؤقت أو الأذونات.

هذا يثبت عيب المسار وإصلاحه محليًا؛ لا يثبت أن هذا هو وحده سبب حادثة المالك على الحزمة35. لم تتغير الحزمة المثبتة35 بهذا الإصلاح، ولم يختبر HealthKit على هاتف فعلي ضمن هذه الإضافة.

## المصادر وقرار التطبيق

| المصدر الرسمي | ما نأخذه منه | المطابقة في BIL |
|---|---|---|
| [Apple — Authorizing access](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data) | طلب حسب الأنواع والاستخدام، وقرار المستخدم قابل للتغيير في النظام | زر منح الإذن صريح؛ startup seam يعيد null؛ كتابة الوزن منفصلة عن القراءة |
| [Apple — HKAuthorizationStatus](https://developer.apple.com/documentation/healthkit/hkauthorizationstatus) | حالة الكتابة لا تثبت إذن القراءة؛ iOS يخفي رفض القراءة | native `permissions` يعني قابلية الاستعلام فقط، والموافقة المحلية مطلوبة؛ لا استنتاج من خلو البيانات |
| [Google — Sync data](https://developer.android.com/health-and-fitness/health-connect/sync-data) | القراءة عند العودة والمراجعة الدورية أثناء الوجود، واستكمال الدفعات بعد انقطاعها | lifecycle + مؤقت foreground + pagination/anchors وsingle-flight؛ لا استئناف متنافس |
| [Google — Permissions UI](https://developer.android.com/health-and-fitness/health-connect/ui/permissions) | إدارة الربط والوصول من الإعدادات وشرح نقص الإذن | Apps & Devices وفتح إعدادات النظام؛ لا ربط مدفوع أو إعادة فرض للموافقة |
| [Google — Read data](https://developer.android.com/health-and-fitness/health-connect/read-data) | تجميع النشاط لتجنب الازدواج؛ historical/background أذونات مستقلة؛ pageToken الفارغ منتهي | aggregateGroupByDuration للنشاط؛ bootstrap30يومًا لـAndroid، token فارغ يُطبع null؛ لا أذونات خلفية/تاريخية إضافية |
| [MyFitnessPal — Apple Health](https://support.myfitnesspal.com/hc/en-us/articles/360032271092-Apple-Health-connection-and-syncing) | ربط صريح وإدارة لاحقة للأذونات في النظام واتجاه معروف لكل بيانات | نفس وضوح الاختيار؛ لا ننقل اقتراح تشغيل كل الأذونات أو قيود تاريخ MFP إلى BIL بلا ضرورة |
| [MyFitnessPal — Health Connect](https://support.myfitnesspal.com/hc/en-us/articles/10553948248973-Health-Connect-FAQ-and-Troubleshooting) | اختيار Connect ثم مراجعة الإذن واختيار مصدر الخطوات | مصدر ظاهر وإجراء صريح؛ لا خلط BLE مع مصدر HealthKit/Health Connect |

لا يعني استعمال طريقة تطبيق منافس ضمان قبول المتجر. تعليمات المنصتين والبيانات الفعلية في BIL هي أساس القرار. لم تُضف SDK أو صلاحية أو entitlement جديدة.

## مسارات المصدر التي فُحصت

- `dashboard_health_activity_refresh.dart`: استعادة cache محليًا أولًا، تحديث بعد الرسم، مؤقت دقيقة عند foreground، إيقافه في paused/hidden، وطلب إطار بعد الإصلاح.
- `connected_health_native_gateway.dart`: موافقة owner scoped، عدم طلب startup، مراجعة أذونات Apple المعروفة عبر إرشاد النظام، مسح anchor فارغ سابق للموافقة الأولى فقط، وفصل إذن كتابة الوزن.
- `connected_health_provider.dart`: مهلة تبدأ عند ضغط المزامنة، تجاوز انتظار القراءة الساكنة العالقة، منع النقرات المكررة، generation/lifecycle fencing وإلغاء قراءة iOS.
- `connected_health_native_daily_activity.dart`: حفظ آخر metric عندما تعيد المنصة نتيجة جزئية/فارغة؛ لا تحويل الغياب إلى صفر. تاريخ كل قراءة يبقى من بياناتها.
- `BILGlobalHealthBridge.swift`: عدم استعمال إذن الكتابة لاستنتاج القراءة؛ الطلب الفعلي من النظام؛ إلغاء قراءة الخلفية، صفحات100 وتاريخ أولي محدود، ولا ادعاء background delivery.
- `BILGlobalHealthBridge.kt`: تجميع النشاط عبر API، صفحات قابلة للاستكمال وtoken فارغ/مسافات منتهٍ، حدود القراءة الموافقة للعقد الحالي.

## الاختبارات والحدود

الأمر: `flutter test --no-pub --reporter expanded` لهذه الملفات فقط:

1. `test/connected_health/apple_health_permission_flow_test.dart`
2. `test/features/connected_health/health_cache_first_regression_test.dart`
3. `test/features/connected_health/health_controller_disposal_test.dart`
4. `test/features/connected_health/explicit_sync_deadline_test.dart`
5. `test/features/connected_health/health_sync_responsiveness_test.dart`
6. `test/connected_health/dashboard_health_cache_startup_contract_test.dart`

النتيجة25/25. تشمل native boundary محاكى وSQLite فعلية، لا شاشة إذن HealthKit فعلية. الفشل قبل الإصلاح محفوظ في `build/qa/text7-18-reconciliation-20261015/health-idle-before.log`، والنجاح في `health-permissions-affected-final.log`. بصمات المصدر وحدود الاختبار في `evidence/text7-18-reconciliation-20261015/health-permission-research-20261015.json`.

قبل اعتماد iOS36/Android33 يلزم على الحزمة نفسها: منح جزئي ورفض، العودة من إعدادات النظام، إغلاق/فتح وقفل الهاتف، غياب بيانات/بيانات قديمة، مزامنة متكررة وقراءة عالقة، ثم A→B→A وسحب الموافقة. لا حذف لبيانات المالك ولا منح لحساب حي.

## توضيح سؤال Today وصحة القلب

شريط7 أيام الحالي يوسّط التاريخ المحدد: الدخول الجديد يبدأ باليوم الحالي؛ اختيار يوم آخر يوسّطه بدل تثبيت تاريخ اليوم دائمًا. لم يتغير سلوكه أو تصميمه في هذه الإضافة. بطاقة صحة القلب تجمع مغذيات الوجبات المدخلة؛ لا قياس طبي ولا إثبات دقة مخبرية. القيمة المجهولة شرطة، والمرجع/الهدف منفصل عن الكمية المسجلة.
