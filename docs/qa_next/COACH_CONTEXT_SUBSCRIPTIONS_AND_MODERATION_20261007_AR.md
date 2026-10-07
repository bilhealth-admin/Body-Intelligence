# إصلاح انتظار Coach وتحديث الإشراف — QA، 2026-10-07

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
