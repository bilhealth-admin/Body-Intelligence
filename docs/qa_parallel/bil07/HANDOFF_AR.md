# BIL-07 | تسليم قنوات المجتمع العامة

**حالة التسليم: READY_FOR_INTEGRATION.** اكتمل نطاق BIL-07 المحلي على
BASE المحدد، بما في ذلك عقد SQL/RLS واختباراته الفعلية. لم يحدث نشر أو
كتابة إلى GitHub أو تشغيل CI جديد أو اتصال بالإنتاج. الدمج النهائي بين
الأدوار والـportable الكامل يبقيان لدى BIL-00 كما ينص TASK.

## الأصل والنطاق

| البند | القيمة |
|---|---|
| المستودع | bilhealth-admin/Body-Intelligence |
| BASE_SHA | `1744788e6bfbdffc3a168bbaf36b3abf3e2c698a` |
| BASE_TREE_SHA | `8f140791e1c2adcb21122ce64a65cb168bbe90d7` |
| المنسق | BIL-00 |
| فرع الدمج المقصود | qa/coach-community-next-20261005 |
| Flutter / Dart | 3.44.6 / 3.12.2 |
| نوع العمل | local-only، owned source + shared integration proposal منفصل |
| نشر خادم جديد | لا؛ `production_connected=false` و`production_deployed=false` |

كل المصدر الجديد تحت prefixes المملوكة في TASK. `owned.patch` يضيف ملفات
دور BIL-07 فقط. `integration-proposal.patch` يحتوي wiring مقترحًا لخمس
ملفات مشتركة ولا يملكها هذا الدور. لا يوجد commit محلي أو remote أنشأه
BIL-07، ولا push/PR/workflow dispatch/rerun.

## ما اكتمل

- **Directory:** إظهار القنوات بحسب الصلاحية، member/nonmember/banned/
  disabled، keyset paging، وعدم auto-join.
- **Messages:** ترتيب ثابت بالـsequence، pagination قديم/حديث دون فقد أو
  duplicate عند وصول رسالة متداخلة، وإرسال explicit فقط.
- **Idempotency/retry:** retry بالمفتاح والنص الأصليين بعد فقد response،
  مع منع duplicate ومطابقة payload، والمفتاح scoped إلى owner+channel.
- **Draft:** مسودة owner/channel منفصلة، لا تُرسل تلقائيًا عند التنقل أو
  policy review، ولا يمحو response قديم نصًا أحدث. التخزين process-memory
  فقط كما هو موثق؛ لا ادعاء persistence بعد قتل العملية.
- **Read/unread:** exact message IDs، dwell + foreground + uncovered route،
  write ثم readback مستقل، وعدم تصفير القراءة بمجرد فتح الدليل؛ private
  unread منفصل ولم يتغير في SQL runtime.
- **Presence:** heartbeat من وقت الخادم، TTL=90s، validity window، انتهاء
  إلى unknown، وعدم احتساب membership كحضور. عند غياب المصدر/contract
  يعرض العميل unavailable بدل success وهمي.
- **Membership/policy/block/text:** إعادة استعمال guards الموجودة في BASE،
  منع nonmember/banned/disabled/suspended/unaccepted policy، حد 2000 Unicode
  code points دون trim/truncation، وسياسة منع بيانات الاتصال من BASE.
- **ABA/lifecycle:** A→B→A، تبديل channel/repository، إغلاق الشاشة، revoke
  ثم restore، وعدم نشر ack/send/presence قديم في زيارة جديدة.
- **Private chat:** routes/badge/messages/unread الخاصة محفوظة، ولا أصدقاء
  أو rewards أو join/policy acceptance/send تلقائي جديد.

## أدلة القبول النهائية

| الفحص | النتيجة | الدليل |
|---|---|---|
| format للنطاق والـshared overlay | PASS، exit0؛ 27 ملفًا، 0 تغيير | `tests/final/format_release.json` |
| analyze للنطاق والـshared overlay | PASS، exit0؛ `No issues found` | `tests/final/analyze_release.json` |
| قنوات + route host + router/navigation | **69/69 PASS**، exit0 | `tests/final/channels_and_routing_release.json` |
| regression قريب في 6 ملفات BASE غير معدلة | **97/97 PASS**، exit0 | `tests/final/regression_release.json` |
| PostgreSQL17.11 SQL/RLS/concurrency | **95/95 assertions PASS**، exit0 | `tests/sql/runtime_pg17_final/sql_results.json` و`runner_results.json` |
| static SQL/Python السابق | PASS؛ parser/AST فقط، وليس بديلًا عن المحرك | `tests/sql/static_final/syntax_results.json` |
| تطبيق patch على BASE | PASS | `tests/patch_application.json` |

الـ69 والـ97 مجموعتان Flutter غير متداخلتين = **166 حالة Flutter ناجحة**.
الـ95 هي assertions محرك SQL مستقلة، فلا تُدمج معها كأنها نفس نوع العد.
الجولات التاريخية المتكررة لا تُضاف للأرقام النهائية.

### SQL/RLS الفعلي

شُغل `loopback_runner.py` على PostgreSQL **17.11** داخل cluster جديد تحت
مستخدم نظام غير مميز `oai`، bind إلى `127.0.0.1` فقط، وقاعدة باسم
`bil07_local_*`. أُغلق cluster وحُذف مساره بعد الجولة. النتيجة95 PASS/0 FAIL.
تشمل: ACL/RLS negative controls، owner spoof، service-role/anon/auth guards،
idempotency، تداخل الصفحات، readback، presence expiry، block/policy، وسباقات
commit/rollback وتعطيل/حظر/تعليق/سياسة. بقي `production_connected=false`.

كشف المحرك فرق PostgreSQL17 في تمثيل `inet`: cast النصي يعطي
`127.0.0.1/32`. عُدل الحارسان إلى `pg_catalog.host(inet_server_addr())`؛
الحماية ما زالت تقبل فقط `127.0.0.1` أو `::1` ولا تسمح بخادم بعيد.
مصدر runtime وبصماته في `tests/sql/runtime_pg17_final/runtime_provenance.json`؛
runtime نفسه غير موجود في ZIP التزامًا بالتسليم.

### Realtime

معيار TASK الخاص بالانقطاع/إعادة الاتصال مغلق على العميل: ضمن الـ69 نجح
`reconnect is explicit and does not reuse a canceled watcher` و
`reconnect creates a new subscription and catches up missed messages`.
عقد الخادم المحلي نفسه يعلن `realtime_available:false` ولا ينشئ publication
أو grants؛ لذلك المسار v1 هو polling، والعميل يفشل بأمان عند غياب capability.
لا أدعي Realtime live لأن هذه القدرة غير موجودة أصلًا في العقد المقترح.

## analyze والـportable النهائي

`analyze` المطلوب لنطاق BIL-07 والـshared overlay **PASS**. توجد محاولة
تاريخية لتحليل repository كامل توقفت بسبب analysis-server -9؛ لا تُسجل PASS.
هذا لا يبقي فجوة BIL-07: TASK ينص صراحة أن **فحص portable الكامل على
التركيب النهائي لدى BIL-00**. وللسياق فقط، evidence مقروء read-only من
run موجود مسبقًا على BASE نفسه يثبت أن BASE المجمد كان `No issues found`؛
لا يُنقل هذا كاختبار لعمل BIL-07 ولا يدخل في عدنا. يوجد في
`tests/base_ci/exact_base_1744788/`.

## ما على BIL-00 فقط

1. تطبيق `owned.patch` ثم دمج hunks `integration-proposal.patch` يدويًا مع
   مقترحات الأدوار الأخرى؛ لا يفترض BIL-07 توافقها التلقائي.
2. تشغيل portable/full composition على التركيب النهائي لكل الأدوار، وإغلاق
   المطابقة البصرية النهائية وفق المراجع التي يملكها BIL-00.
3. إذا تقرر نشر عقد القنوات لاحقًا، صياغة migration إنتاجية منفصلة ومراجعتها؛
   ملف BIL-07 الحالي مقصود أن يرفض remote deployment.

**لا أقول إن المشروع كله جاهز للإنتاج. حالة BIL-07 المحلية فقط هي
READY_FOR_INTEGRATION.**
