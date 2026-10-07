# إصلاح انتظار Coach وتحديث الإشراف — QA، 2026-10-07

## نتيجة 4669368 وتصحيح نطاق provider

[run37550211630](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37550211630)
على `4669368702751054f502fd9be321b29c59732b92` انتهى خلال25ثانية اختبار:
**144PASS /7FAIL**. انتهى انتظار أول نتائج Drift؛ assertions `null` و`empty`
اجتازت، ووصلت الحالات السبعة إلى provider الحقيقي. السبب المتبقي هو عدم تصريح
`coachContextSnapshotProvider` باعتماده ذي النطاق `connectedHealthProvider`؛
أبلغ Riverpod عن ذلك عند `ref.watch` في السطر48 قبل assertions التغذية.

يضيف تصحيح المصدر `dependencies: [connectedHealthProvider]` إلى تعريف
Coach provider نفسه. راجعت مصادر الاعتمادات المباشرة السبعة عشر؛ هذا هو الاعتماد
الوحيد الذي يعلن scope metadata. وراجعت قراءات Coach المنشورة: المستهلكون
WidgetRef داخل ConsumerState، ولا core provider downstream يحتاج تصريحًا إضافيًا
ضمن الملفات المقروءة. لا تتغير overrides أو assertions أو خوارزمية التغذية.
[عقد Riverpod3.3.2](https://github.com/rrousselGit/riverpod/blob/riverpod-v3.3.2/packages/riverpod/lib/src/core/ref.dart#L134)
هو مرجع التصريح، ونتيجة التصحيح التنفيذي التالية ما زالت pending.

**Moderation8/8PASS** على466: الخمس الأصلية والثلاث الجديدة. الخطأ الذي تصححه
callbacks هو مخالفة عقد Flutter setState، والتي يكتشفها فحص Flutter في debug؛
اختبارات remove/hide تؤكد غياب رسالة الفشل الكاذبة في هذا المسار.
بقي اقتراح Dart من hunkين في ملف الاختبار فقط، ويُطبّق حرفيًا دون تغيير assertions.

[R5 run37550211417](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37550211417):
276focusedPASS و4capturePASS وanalyze0، مع failure بسبب تنسيق ملف moderation
وحده؛ regression التابعة skipped. أضيف ملف الاختبار إلى trigger وfocused R5
حتى يُفحص تغيير الاختبار نفسه في هذا المسار، مع بقاء كل الملفات والمهل الأصلية.

[Native run37550211316](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37550211316)
انتهىSUCCESS:199PASS وanalyze0 والمصدر دون تغيير. هذه Flutter host captures،
ولم تُفحص PNG بصريًا أثناء الانقطاع؛ لا يُستنتج منها تطابق المرجع أو صلاحية إصدار متجر.

## الحالة التي أدت إلى هذه الدفعة

المصدر السابق هو `dde861ba2a266b79f9c04a5ebcc86ca3c7958820`.
انتهى [run37547980744](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37547980744)
بـFAILURE: **136 PASS / 7 FAIL** في focused، و0 issues في analyze،
وarchitecture1PASS وperformance2PASS. طلب Dart تنسيق أربعة ملفات.

الحالات السبعة التي انتهت بالمهلة هي اختبارات provider الفعلي الجديدة:
noDay، emptyMeal، unknownModern، knownZero، calorieOnly، partialCalories،
malformedModern. ظل `latestDailyLogProvider` في loading حتى teardown.
حالات تجميع الدليل23 وحالات Drift4 نجحت؛ لم تصل الحالات السبعة إلى assertions
التغذية، فلا تُنسب إليها نتيجة تغذية ناجحة.

آخر regression كامل مثبت ما زال `7046710f8625aa1b2b9915cc6beff4011c37fefa`:
6985PASS / 0FAIL في [run37545878945](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37545878945).
لا تنقل هذه النتيجة تلقائيًا إلى مصدر أحدث.

## سبب الانتظار وتصحيحه

`pubspec.lock` يثبت Riverpod3.3.2. في المصدر المطابق لهذه النسخة:

- [ProviderContainer.read](https://github.com/rrousselGit/riverpod/blob/riverpod-v3.3.2/packages/riverpod/lib/src/core/provider_container.dart#L1027)
  يفتح listener مؤقتًا ويغلقه داخل finally قبل اكتمال Future.
- [تغير آخر اشتراك](https://github.com/rrousselGit/riverpod/blob/riverpod-v3.3.2/packages/riverpod/lib/src/core/element.dart#L1163)
  يستدعي onCancel عند انعدام المستمعين.
- [handleStream/onCancel](https://github.com/rrousselGit/riverpod/blob/riverpod-v3.3.2/packages/riverpod/lib/src/core/element.dart#L164)
  يوقف اشتراك Stream نفسه مؤقتًا.

كان harness ينتظر أول نتيجة من stream قبل إنشاء Coach context الذي يراقبه.
تحافظ هذه الدفعة على listener حقيقي لكل من latestDailyLog وinsightLifeContext
أثناء الانتظار، وتغلقهما في teardown قبل container ثم قاعدة البيانات.
وتضيف assertion بأن النتيجة الأولى هي null/empty الفعليتان لقاعدة fixture.
لا تُضاف DailyLog وهمية، ولا snapshot override، ولا WidgetsBinding لتغطية السبب.

بقيت assertions provider الـ32، وأضيفت اثنتان. بقيت بيانات Drift الفعلية
والحالات السبع وhealth fixture المعلن والـcanonical unavailable override كما هي.
التنسيق لأربعة ملفات مأخوذ حرفيًا من formatter proposal في سجل CI،
بتحقق كل hunk مقابل المصدر وعدد assertions قبل التطبيق وبعده.

## ثلاثة callbacks في Community

في Feed، كان مسارا moderator remove وhide يعيدان Future من assignment expression
داخل setState. كان الخطأ يصل إلى catch فيظهر للمستخدم فشل رغم نجاح mutation.
وفي صفحة الإشراف، كانت Refresh تعيد Future من callback بالطريقة نفسها.

حُولت callbacks الثلاثة إلى blocks لا تعيد قيمة. يظل كل Future يُنشأ مرة واحدة،
ويظل عرض القائمة تابعًا للقراءة الجديدة نفسها. لم تتغير RPCs أو صلاحياتها
أو سياسة المكافآت أو حماية الحسابات في هذه الدفعة.

أضيفت ثلاث حالات widget إلى ملف moderation الحالي:

| الحالة | assertions السلوكية |
|---|---|
| Feed remove | فعل واحد مع id/سبب صحيحين، تحميل ثانٍ واحد، ظهور قراءة الخادم الجديدة واختفاء القديمة، نجاح صريح وغياب الفشل الكاذب |
| Feed hide | التحقق المستقل نفسه لمسار hide ورسالة نجاحه |
| AppBar Refresh | Future مؤجل جديد يُستكمل إلى queue فارغة، بلا mutation أو تحميل ثالث أو exception |

اختبار approve الأصلي وجميع assertions القديمة محفوظة. إنشاء عميل Supabase
وإغلاقه للمجموعة الجديدة خارج fake clock، والـCompleters داخل widget test.
الـfixture يغطي preload دون شبكة. لم يُنفذ red/green المحلي خلال انقطاع البيئة؛
أول تحقق تنفيذي لهذه الإضافة هو CI على SHA الدفعة.

## التحقق التالي والحدود

أضيف ملف moderation إلى focused CI دون إزالة أي ملف أو تغيير timeout أو shard
أو exclusion. يجب إغلاق format/analyze/focused ثم الأربع shards وSQL المعزول
وFlutter capture على المصدر الحالي. وقت حفظ هذه الوثيقة، نتيجة الإصلاح **pending**.

[جرد أسطح Community](COMMUNITY_EIGHT_SURFACE_INVENTORY_20261007_AR.md)
يفصل الوظائف الموصولة عن الفجوات الباقية. هذا الجرد مبني على7046710؛ callbacks
الثلاثة فيه سجل اكتشاف سابق لهذه الدفعة، لا إعلانًا بأن الفجوات كلها أُغلقت.

تبقى تعديلات Home/Activity وModeration/Earn المحلية المتأخرة وnative food وPersonal
BIL خارج هذه الدفعة حتى يمكن قراءة حالتها واختبارها. لا يتغير main أو35/32،
ولا Production أو الدفع/Trial، ولا تُبنى حزم متاجر. لا توجد دعوى مطابقة بصرية.
