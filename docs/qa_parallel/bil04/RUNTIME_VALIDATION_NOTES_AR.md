# BIL-04 — بيئة التنفيذ وأدلة التحقق

## الحالة النهائية

بيئة Linux المحلية المعزولة تشغّل Flutter test وanalyze فعليًا. الإصدار مثبت على Flutter **3.44.6** وDart **3.12.2**، ولم تُرقّ dependencies الخاصة بالمشروع.

| البند | القيمة |
| --- | --- |
| Flutter framework | `ee80f08bbf97172ec030b8751ceab557177a34a6` |
| Engine | `83675ed27633283e7fc296c8bca22e841224c096` |
| الأرشيف الرسمي | `stable/linux/flutter_linux_3.44.6-stable.tar.xz` |
| حجم التنزيل المتحقق | 1,544,352,104 بايت |
| SHA-256 المتحقق | `a6320fd72e9a2690c08e2a6a70874a30cb120dee7c78f49d2c628bd7c9e20525` |
| SHA-256 لقفل المشروع | `359caf1c42418012a7d9943c0413e7c243afd7dd21f605f5b3754d4d587c5a46` |
| SHA-256 لقفل Flutter tooling | `1aa193fc5df798338a2ca97d1737450f9c2cc1984ec0095b2efbaa0f4dcad340` |

مصدر الإصدار المثبت هو manifest الرسمي: https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json . احتُفظ ببصمة الأرشيف وتفاصيل الإصدار ثم حُذف تنزيلنا الكبير لتوفير المساحة. استُخدمت نسخة عامة مطابقة ومتحقق من Git commit الخاص بها للقراءة فقط، مع إنشاء runtime خاص بهذه المهمة.

## العزل والمسارات

- Flutter: `/workspace/scratch/ada7a97de764/runtime/flutter-bil04`
- مشغّل الأوامر: `/workspace/scratch/ada7a97de764/runtime/with-flutter`
- Dart: `/workspace/scratch/ada7a97de764/runtime/flutter-bil04/bin/cache/dart-sdk/bin/dart`
- PUB_CACHE: `/workspace/scratch/ada7a97de764/runtime/pub-cache`
- الإعدادات: `/workspace/scratch/ada7a97de764/runtime/config`
- نسخة التحقق: `/workspace/scratch/ada7a97de764/validation`

نُسخت metadata وFlutter tooling القابلة للكتابة إلى نطاق خاص. الروابط الصلبة مخصصة لثنائيات/artifacts العامة الثابتة فقط. جرى التحقق من وجود **103** جذور حزم تخص Flutter tooling، وجميعها داخل نطاق المهمة الخاص. لا يُشغّل هذا العمل SDK أو PUB_CACHE مشتركًا للكتابة.

المشغّل يستدعي snapshot الرسمي للأداة عبر Dart الخاص مباشرة؛ هذا يمنع bootstrap مبنيًا على اختلاف timestamps من طلب pub upgrade. لم يُعدّل كود SDK لتجاوز التحقق. نجح `dart pub get --offline --enforce-lockfile` لأدوات Flutter مع بقاء القفل نفسه. تضبط البيئة CI/BOT وتعطيل analytics، ويستخدم التشغيل `TAR_OPTIONS=--no-same-owner` لمعالجة هوية مالك الأرشيف في الحاوية.

## مثال إعادة التشغيل في هذه البيئة

من مجلد `/workspace/scratch/ada7a97de764/validation`:

```bash
TAR_OPTIONS=--no-same-owner /workspace/scratch/ada7a97de764/runtime/with-flutter test --no-pub --reporter expanded test/parallel/bil04/fasting_command_adapter_test.dart test/parallel/bil04/fasting_notification_sync_test.dart test/parallel/bil04/daily_life_commands_test.dart test/parallel/bil04/health_read_guard_brief_test.dart
```

الأوامر التفصيلية للـanalyze وformat موجودة كما نُفذت في تقارير JSON. لا تتطلب إعادة التشغيل ترقية dependency أو خدمة إنتاج أو CI. ملفات runtime الثنائية والحزم ليست جزءًا من تسليم كود BIL-04.

## النتائج الحالية

| النطاق | النتيجة | الدليل |
| --- | --- | --- |
| بيانات الصيام | 23 PASS | `focused_tests_after_queue_fix` |
| مزامنة الإشعارات | 21 PASS | `focused_tests_after_queue_fix` |
| اليوم وسياق الحياة مع Native journal | 28 PASS | `focused_tests_after_queue_fix` |
| الحارس والملخص المحدود | 23 PASS | `focused_tests_after_queue_fix` |
| المجموع الجديد | **95/95 PASS**، exit 0 | `health_read_brief_validation/focused_tests_after_queue_fix.{json,txt}` |
| اختبارات قائمة مجاورة | **40/40 PASS**، exit 0 | `daily_life_validation/baseline_regression_01.{json,txt}` |
| analyze | **10 ملفات، بلا ملاحظات**، exit 0 | `health_read_brief_validation/focused_analyze_after_queue_fix.{json,txt}` |
| format | **10 ملفات، 0 تغيير**، exit 0 | `health_read_brief_validation/focused_format_after_queue_fix.{json,txt}` |

كل بصمات المصادر وقفل المشروع في التشغيل النهائي متطابقة قبل الأمر وبعده. لا تشمل الأعداد إعادة تشغيل الحالات نفسها. الاختبارات القائمة الأربع هي `authoritative_daily_ledger_test.dart` و`repository_test.dart` و`features/wellness/fasting_session_test.dart` و`features/wellness/fasting_preferences_transaction_test.dart`.

## الإخفاقات التي بقيت في سجل الأدلة

- مسار manifest أولي غير صحيح أعاد 404؛ نجح المسار الرسمي أعلاه.
- الاستخراج الكامل تعثر بملكية UID ثم امتلاء مساحة العمل؛ أُزيلت الملفات الجزئية الخاصة بالمهمة والأرشيف المتحقق بعد حفظ بصمته.
- احتاج analyzer مجلد SDK `dev` الذي لم يكن ضمن الاستخراج المختصر؛ استُعيد `dev` و`examples` من Git commit المثبت نفسه.
- كشفت اختبارات adapters خمس حالات حقيقية في علامات إغلاق اليوم والتحقق من UUID/تاريخ سياق الحياة، وأُصلحت قبل نجاح التشغيل.
- كشف اختبار نطاق الزيارة الاحتفاظ بـFuture مكتمل في قائمة إشعارات ساكنة. يُحتفظ باختبار FAIL قبل الإصلاح؛ تم تفريغ الطرف عند الخمول فقط مع استمرار تسلسل الطلبات الجارية، وأضيف اختبارا إعادة استخدام الزيارة وتسلسل المثيلات.
- يحفظ أحد التشغيلات الانتقالية `source_stable_during_execution: false` لأن الحارس تغيّر أثناء التشغيل؛ لا يُستعمل للاعتماد النهائي. تقارير `after_queue_fix` النهائية مستقرة.

## الحدود العملية

الإشعارات تُفحص ببديل منصة مصطنع مع preferences فعلية؛ لم يُختبر التسليم على iOS/Android فعليين. قد يتم أثر جهاز قبل اكتشاف تبدل المالك بعد await، ولذلك توجد تسوية لاحقة بالحالة الحالية ونتيجة منفصلة عن حفظ البيانات. اختبار مالكين منفصلين يفتح قاعدتي ذاكرة مستقلتين ويطبع تحذير Drift العام بشأن تعدد مثيلات قاعدة البيانات؛ لا يتشاركان QueryExecutor ولم يُخفَ التحذير.

اختبارات الشاشة والتأكيد وإمكانية الوصول تُسجل في حزمة قائد BIL-04/وكيل الواجهة المستقلة؛ لا يُدّعى اجتياز كل اختبارات المشروع بناءً على هذه المجموعة المحددة.
