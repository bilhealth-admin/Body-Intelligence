# BIL-03 | Settings & Privacy — دليل التنفيذ المحلي

## الهوية والنطاق

- الدور: `BIL-03`
- المستودع: `bilhealth-admin/Body-Intelligence`
- BASE المطلوب للدمج: `1744788e6bfbdffc3a168bbaf36b3abf3e2c698a`
- BASE tree: `8f140791e1c2adcb21122ce64a65cb168bbe90d7`
- البيئة: Flutter `3.44.6` / Dart `3.12.2` / `TZ=Africa/Cairo`
- لا GitHub write، لا push/PR/CI dispatch، لا Production، لا build متجر، لا تغيير 35/32، لا Billing/Paywall/Trial.

استعيدت بيئة المصدر المحلية من snapshot الأب المباشر
`d2fd65f911b6a5f15e6ffc534cbc58d8f4767618`. مقارنة GitHub للوالد مع BASE
أثبتت أن commit `1744788` يغيّر ستة مسارات خاصة بحدود quantityGrams فقط، ولا
يمس أي ملف مملوك أو مشترك في تسليم BIL-03. لذلك bytes السابقة في مسارات
BIL-03 هي نفسها على BASE؛ الرقع تُولّد على هذه bytes وتُراجع بالنسبة إلى
BASE الثابت أعلاه.

## ما أُغلق في الملفات المملوكة

### اللغة والمظهر

- أُضيف readback مستقل من التخزين بعد الحفظ بدل اعتبار القيمة المطلوبة دليل نجاح.
- أُضيف revision وسجل عمليات settings داخل نفس JSON المخزن بواسطة الخدمة القائمة؛ لا مخزن إعدادات موازٍ.
- `set_language` و`set_theme_mode` يدعمان operation ID، replay مطابق، وUndo مشروطًا بالـrevision والقيمة الحالية.
- تعديل أحدث يمنع Undo القديم حتى في حالة ABA (`A → B → A`).
- سحب صلاحية الكتابة أثناء commit/Undo بعد بدء العملية يؤدي إلى rollback تعويضي موثّق بدل إيصال نجاح زائف.
- الواجهة العامة القديمة `save()` بقيت متوافقة مع حقن الاختبارات/subclasses؛ تم اكتشاف regression في هذا الحد أثناء الاختبار وإصلاحه قبل الإقفال.

### الوحدات

- أوامر العرض تستخدم `PreferencesRepository` القائم فقط.
- تغيير الوحدات يغيّر تفضيل العرض ولا يعيد كتابة قياسات الوزن/الطول/المسافة التاريخية.
- Undo يعتمد CAS على snapshot السابق ويُرفض عند تغيير أحدث/مالك مختلف/read-only.

### الإشعارات والتذكيرات

- المسار يستخدم `DailyReminderStore` وخدمة الإشعارات القائمة.
- رفض إذن النظام لا يُسجّل كتفعيل.
- النجاح يتطلب readback من التفضيل ومن `pendingNotificationIds`؛ غياب الجدولة أو فشل جزئي يعيد snapshot السابق best-effort ولا ينتج إيصال نجاح.
- سحب صلاحية Coach أثناء المحاولة يلغيها ويمنع اعتماد تفضيل قديم.
- الاختبارات تستخدم gateway مصطنع؛ لم تُغيّر global notification permission على جهاز حقيقي.

### الذاكرة العامة

- الحذف أصبح انتقائيًا فقط عبر `id + expectedUpdatedAt` من المراجعة التي وافق عليها المستخدم.
- أي تغيير في العنصر بعد المراجعة يرفض الحذف، مع owner guard قبل/أثناء/بعد العملية.
- العناصر غير المختارة لا تُحذف.
- `save_memory` وNative Undo المنشوران لم يُعاد بناؤهما، ولم تُمس قواعد Personal BIL.

### التصدير

- التحضير يمر عبر `LocalDataLifecycleService` القائم مع allowlist لنطاق البيانات المطلوب.
- إنشاء ملفات CSV لا يستدعي share تلقائيًا.
- المشاركة خطوة handoff ثانية وصريحة عبر بوابة المشاركة القائمة.
- النص/النتيجة تفرّق بين «الملفات جاهزة محليًا» وبين عودة واجهة المشاركة؛ لا ادعاء بأن التسليم الخارجي اكتمل.

## التوصيل المشترك المقترح

`integration-proposal.patch` منفصل عن `owned.patch`. يحافظ على
`BilToolRegistry.tools` المنشور بعدد **23** أداة server canonical. أدوات BIL-03
تدخل عبر catalog محلي منفصل وتستفيد من admission/permissions نفسها دون تغيير
عقد الخادم. المقترح يربط:

- units/reminders إلى الأوامر المملوكة.
- memory review إلى شاشة الذاكرة الحالية.
- export إلى route النطاق ثم Create/Share المنفصلين.
- استعادة Undo للغة/المظهر من receipt مخزن + operation journal الحقيقي عند إعادة تحميل المحادثة، دون إعادة تنفيذ أو repair write.

مسارات المساعدة/الاشتراك/حذف الحساب الموجودة تبقى handoff فقط؛ لا تغيير billing أو شراء/restore/delete فعلي.

## التحقق المنفذ

### Focused BIL-03

الأمر:

```text
TZ=Africa/Cairo PUB_CACHE=/mnt/data/pub_cache/pub-cache /mnt/data/flutter_sdk_test/bin/flutter test --no-pub --no-test-assets test/parallel/bil03
```

النتيجة: **34 PASS / 0 FAIL**.

يغطي التخزين والفشل/readback وإعادة إنشاء الخدمة وUndo، التعديل الأحدث وABA،
read-only أثناء commit/Undo، الوحدات، رفض إذن الإشعار وفشل الجدولة الجزئي،
حراسة المالك، حذف ذاكرة محددة، export دون auto-share، وعقد overlay الذي يثبت
بقاء الأدوات canonical = 23.

### Regression قريب

شُغّلت اختبارات الإعدادات القديمة، locale persistence، measurement units،
registry/admission، Native command repository، memory owner sync، reminder
store، notification permission resilience، وsettings functional parity.

النتيجة: **109 PASS / 0 FAIL**. هذه المجموعة متداخلة مع اختبارات أخرى ولا
تُجمع معها باعتبارها عددًا فريدًا.

### Analyze / Format

- `dart analyze --fatal-infos` على الشريحة المملوكة + overlay المشترك + اختبارات BIL-03: **No issues found**.
- `dart format --output=none --set-exit-if-changed` على 29 ملف Dart متغير: **0 changed**.

## اختبار لم يكتمل بسبب البيئة

محاولة تحميل الاختبار الواسع
`test/features/intelligence_center/ai_coach_tool_execution_behavior_test.dart`
توقفت قبل تنفيذ assertions بسبب نقص ملفات مصدر عامة داخل pub-cache المستعاد
(`image 4.9.1` و`pdf 3.13.0` font source files). لا تُحسب هذه المحاولة PASS أو
FAIL؛ تصنيفها `NOT_RUN_ENVIRONMENT`. لم تُضف خطوط أو binaries أو تعدّل
`pubspec.lock` لتجاوز العائق. يجب أن يعيد BIL-00 تشغيل portable/full regression
على checkout كامل بعد تركيب جميع الأدوار.

## حدود الإثبات

- لا device/live-provider notification E2E.
- لا إثبات delivery خارجي للمشاركة؛ فقط handoff إلى واجهة النظام.
- إعادة إنشاء خدمة settings وjournal recovery مثبتة محليًا؛ wiring إعادة فتح Coach موجود في overlay ومحلل، لكن الاختبار الواسع المباشر للـWidget أعلاه `NOT_RUN_ENVIRONMENT`.
- الترجمات الجديدة مكتملة يدويًا لـ EN/AR، وموجودة أيضًا FR/ES/TR في صفحة التصدير؛ بقية لغات التطبيق الحالية تعتمد fallback ولم تُراجع ترجمتها البشرية في هذه الدفعة، لذلك لا يُدعى اكتمال 25 لغة.
- لا تطابق بصري جديد ولا screenshots/goldens؛ لم تُغير هذه المهمة design system.
- لا Production deployment.
