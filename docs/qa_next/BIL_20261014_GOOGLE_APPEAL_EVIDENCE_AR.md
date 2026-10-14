# تحضير استئناف Google Play — مراجعة الأدلة الحالية

**الحالة: مسودة محلية فقط — لم تُكتب أو تُحفظ في Console ولم تُرسل.**

- التاريخ: 14 أكتوبر 2026
- المستودع: `bilhealth-admin/Body-Intelligence`
- الفرع: `integration/bil-qa-media-policy-20261011`
- HEAD الذي فُحص: `e27a58984bff50b4bcf45044ea9893f344307e85`

## الحكم الآن

Play Console يعرض حاليًا **App suspended** لاسم الحزمة `com.bilhealth.bodyintelligencelog`، ويعرض قرار التعليق بتاريخ 8 أكتوبر 2026 وسبب `Violation of Enforcement Process policy` / `Repeated app rejections`. زر الاستئناف ظاهر. لم أرسل طلبًا ولم أغير Console.

لا أوصي بإرسال الاستئناف الآن. إشعار التعليق يطلب مراجعة التطبيق وبقية تطبيقات حساب المطور، ثم تنفيذ التغييرات قبل الاستئناف. لم يظهر دليل إنجاز مراجعة بقية التطبيقات. كما أن سجل Android 33 يصرّح `STAGING_MANIFEST_COMPLETE: NO` و`CANDIDATE_FROZEN_OR_ACCEPTED: NO`، ولا يوجد AAB موقع أو اختبار دخول للمراجع على النسخة الدقيقة. نتائج الكود المحلي لا تثبت ما سيفتحه Play للمراجع. المصدر Android 32 لم يتغير.

قرأت رسائل Google الأصلية في Gmail وقرأت حالة Console الموثقة أعلاه. شاشة الاستئناف بها اختياران؛ اختيار «أفهم سبب المشكلة وسأصلحها» يفتح خانة خطة بحد 1000 حرف، لكنها لا تعرض خيار حفظ. عند فتحها ثم الإغلاق، أكدت Console أن التغييرات غير المحفوظة ستُحذف. أُغلقت واختير الحذف؛ لم أكتب نصًا أو أضغط الإرسال. السجل السابق يؤكد أن المالك قال إنه لم يقدم استئنافًا للتعليق، لكن لم تُعرض في Console صفحة سجل للاستئناف تثبت ذلك مستقلاً.

## مصفوفة الإشعارات والنتيجة الحالية

| التاريخ في رسالة Gmail | البريد الأصلي | النص الرسمي/النسخة | دليل المصدر الحالي وحدوده |
|---|---|---|---|
| 15 سبتمبر 2026، 22:36 PDT | `1a0a8b77579fcd7a` | `Violation of Broken Functionality policy`؛ النص: `Unresponsive UI elements, such as buttons or icons`. لا يذكر نص الرسالة رقم نسخة. | الرسالة تشير إلى المرفق `IN_APP_EXPERIENCE-2101.png`. وصف المرفق في تقرير التحضير السابق يذكر أن شاشة الشراء عرضت تعذر العثور على المنتج؛ هذه ملاحظة للصورة، وليست نص المخالفة الرسمي، ولا تثبت أن كامل المخالفة الحالية أُصلح على جهاز/نسخة متجر. |
| 15 سبتمبر 2026، 22:36 PDT | `1a0a8b76655ed230` | `Excessive data access for declared feature`، version code 13؛ `BodyFat`, `RestingHeartRate`, `SleepSession`. | Manifest المصدر الحالي يطلب `READ_STEPS`, `READ_DISTANCE`, `READ_ACTIVE_CALORIES_BURNED` فقط، ولا يطلب الثلاثة المرفوضة. لا يوجد AAB 33 لقراءة merged manifest، ولم تُطابق تصريحات Health Connect الحالية في Console مع artifact. |
| 2 أكتوبر 2026، 22:04 PDT | `1a1002638f11e217` | `Violation of Play Console Requirements`؛ `App content is restricted by a paywall`. الرسالة لا تذكر version code. | لا يجوز استنتاج النسخة من التاريخ أو الصورة. اختبارات المصدر لا تثبت أن جلسة المراجع تستطيع دخول النسخة المنشورة وتجاوز كل بوابات الدفع/الرصيد. |
| 8 أكتوبر 2026، 03:01 PDT | `1a11af591a4d0cb9` | `Violation of Play Console Requirements`؛ paywall؛ version code 32؛ المرفق `IN_APP_EXPERIENCE-6955.png`. | هذه النسخة الثنائية لا تتغير بإصلاحات المصدر. Android 33 لا يملك AAB موقعًا بعد، ولا يوجد clean-install على حساب مراجع يثبت وصول الوظائف دون شراء أو رصيد مكتسب. |
| 8 أكتوبر 2026، 12:38 PDT | `1a11d06ac8638e5b` | التعليق بسبب `Violation of Enforcement Process policy`، مع العبارة `Repeated app rejections`. | Console ما زال يعرض التطبيق `App suspended`. الإشعار يطلب مراجعة كل تطبيق آخر في حساب المطور قبل تقديم الاستئناف؛ لم تُوثق هذه المراجعة بعد. الاستئناف واحد لكل إزالة/تعليق/إجراء تنفيذي وفق [مساعدة Google Play الرسمية](https://support.google.com/googleplay/android-developer/answer/2477981?hl=en-EN). |

الأزمنة أعلاه كما ظهرت في Gmail (-07:00). تواريخ UTC المقابلة: 16 سبتمبر 05:36، 3 أكتوبر 05:04، 8 أكتوبر 10:01، و8 أكتوبر 19:38. النسخة 13 هي وحدها التي يذكر بريدها صراحةً رقمًا لتقرير Health Connect؛ لا تُنسب إليها أرقام نسخ رسائل أخرى.

## نص عمل داخلي — ليس نص استئناف ولا يُلصق في Console

**لا يوجد الآن نص صالح للإرسال.** النص أدناه، رغم أنه 944 حرفًا، يتضمن وعودًا مستقبلية لم تُثبت بعد. احتُفظ به كقائمة عمل داخلية فقط، ولا يُعد مسودة محفوظة في Console ولا توصية بإرسال الاستئناف. واجهة Console لا توفر حفظًا للمسودة؛ الإجراء المتاح هو الإرسال، لذلك لم يُكتب النص فيها.

> We acknowledge the suspension followed prior review failures; we do not claim those findings were incorrect. September notices cited unresponsive UI and excessive Health Connect scope (BodyFat, RestingHeartRate, SleepSession); later notices found reviewer access blocked by a paywall, including versionCode 32. We will retest the affected UI and Play products on the exact release; limit Health Connect to declared activity features; match its merged manifest to Console declarations; and configure reviewer access to reach the full in-scope experience without purchase, payment details or earned credits. We will also review all other apps in this developer account. The three rejected permissions are absent from current source, but Android33 has no signed AAB, and reviewer access, product availability and final artifact/declaration alignment remain unverified. We will document those checks against the signed artifact before resubmission.

**ممنوع استخدام النص أعلاه للإرسال بصيغته الحالية.** يتطلب أولًا إكمال مراجعة بقية تطبيقات حساب المطور، وإثبات الوظائف وApp Access ومنتجات Play وتطابق Health Connect على AAB موقع ومثبت. بعد ذلك تُكتب صياغة جديدة تصف ما أُنجز فعلًا بصيغة دقيقة، وتُراجع من المالك قبل إرسال الفرصة الوحيدة. ذكر النص أن صلاحيات Health Connect الثلاث غائبة عن المصدر صحيح للمصدر الذي فُحص فقط؛ ليس إثباتًا للـAAB النهائي أو إقرار Console.

## المصدر المحلي وحالة الاختبارات

- سجل [Android 33 التحضيري](../release/BIL_ANDROID_V33_FROZEN_SOURCE_MANIFEST_2026-10-14.md) ليس تجميد إصدار أو Artifact؛ حقلا manifest غير مكتملين، وعدد المراجعات غير المغلقة 5.
- `android/app/src/main/AndroidManifest.xml` يعلن في المصدر خطوات/مسافة/سعرات نشاط فقط. يلزم merged manifest من AAB نهائي قبل الادعاء بالمطابقة.
- `android/app/build.gradle.kts` يستخدم إعدادات SDK 36 ويقرأ رقم البناء من إعداد Flutter؛ لا يثبت هذا إنشاء build 33. `pubspec.yaml` ما زال `1.0.0+8`، والـworkflow هو الذي يمرر رقم البناء عند إنشاء Artifact.
- مصدر بوابات المزايا واختباراتها لا يثبت App Access، استحقاق الحساب أو رصيد AI على نسخة Play. لم أقرأ إعداد App Access أو المنتجات الحية أو إقرار Health Connect في Console ولم أغيّر أيًا منها.
- التحليل والشاملة المرتبطان بـHEAD أعلاه شأنهما منفصل عن هذا القرار، ونتيجتهما لا تحوّل مصدرًا محليًا إلى AAB منشور. لا تنسب نتائج الشاملة المذكورة داخل سجل Android 33 التحضيري إلى تشغيل HEAD الحالي.

## الخطوة التالية المحددة

قبل استخدام فرصة الاستئناف الوحيدة: إكمال مراجعة جميع تطبيقات حساب المطور كما طلب إشعار Google؛ ثم، بعد إذن بناء منفصل، إنشاء AAB 33 موقع ومقيد ببصمة المصدر النهائي؛ فحص merged manifest وبيانات Play المرتبطة به؛ التحقق من منتجات Play؛ وتثبيت artifact نظيف واختبار دخول المراجع وفتح الوظائف المدفوعة دون شراء أو حاجز رصيد. بعد توثيق كل ذلك فقط يُراجع المالك نص Console النهائي ويقرر الإرسال. لا يُدّعى أن build32 تغير، أو أن 33 نُشر، أو أن الخدمة الخلفية تغيرت.

## تحديث تحقق Play Console — 15 أكتوبر 2026

أعاد الوكيل فحص Console وGmail قراءةً فقط على HEAD `e27a58984bff50b4bcf45044ea9893f344307e85` والفرع نفسه. صفحة قائمة التطبيقات في حساب المطوّر `7540824385820504578` تعرض تطبيقًا واحدًا فقط: BIL، بمعرّف التطبيق `4974243137795319021` والحزمة `com.bilhealth.bodyintelligencelog`؛ حالته `App suspended` و`Suspended by Google`. لذلك لا يظهر تطبيق آخر في القائمة الحالية يحتاج مراجعة مستقلة. آخر بريد من Google الذي عُثر عليه هو إشعار التعليق في 8 أكتوبر، ولم يظهر بريد أحدث أو مسودة Appeal. زر Appeal ظاهر، لكن Console لا يعرض سجلًا يثبت هل سبق إرسال استئناف؛ لم يُفتح النموذج ولم يُكتب أو يُرسل شيء.

في مصدر Android الحالي لا تظهر صلاحيات `BodyFat` أو `RestingHeartRate` أو `SleepSession`، لكن ذلك لا يثبت محتوى حزمة Android 33. مسارات إخراج AAB/APK المتوقعة غير موجودة، ولا توجد حزمة 33 موقعة أو نتيجة تثبيت نظيف واختبار وصول المراجع. لذلك أُغلق فقط سؤال وجود تطبيقات أخرى ظاهرة في الحساب؛ ولا تزال أهلية إرسال Appeal غير مثبتة. لا تستخدم النص الداخلي السابق في Console ولا تدّع أن مخالفات النسخ الثنائية عولجت. الخطوة التالية: إنشاء الحزمة المصححة بعد اجتياز بوابات المصدر، ثم فحص merged manifest وإقرارات Play واختبار الوصول على الحزمة نفسها؛ بعدها يُكتب نص Appeal يذكر ما تم إثباته بصيغة الماضي، ويُراجع قبل استهلاك المحاولة الوحيدة.

## نتيجة الشاملة ومسودة عمل دقيقة — 15 أكتوبر 2026

اجتازت الشاملة على HEAD `e27a58984bff50b4bcf45044ea9893f344307e85` وبصمة المصدر `80087ad7b2ef76192e9f22c5be0af34edc53dfc2139eb1b63ad81eaf7416614e`: 9,843 نجاحًا من 1,356 ملف اختبار، بلا فشل أو خطأ أو تخطٍّ. هذه نتيجة مصدر محلي، ولا تثبت AAB أو تجربة مراجعة Play.

مسودة إنجليزية داخلية من 987 محرفًا، لا تُلصق أو تُرسل في Console قبل وجود نسخة Android 33 موقعة واختبار وصول المراجع؛ وهي تطلب مسار إعادة التقديم ولا تدّعي مطابقة binary:

> Google cited Sept unresponsive UI (no version stated), excess Health Connect access on v13 (BodyFat, RestingHeartRate, SleepSession), and paywall-blocked review on v32. Tested source: HEAD e27a58984bff50b4bcf45044ea9893f344307e85; fingerprint 80087ad7b2ef76192e9f22c5be0af34edc53dfc2139eb1b63ad81eaf7416614e; Flutter suite passed 9,843 cases across 1,356 files (0 failed/errors/skips). Store lookup now times out at 12 seconds with retry; empty/malformed catalogs are tested. Android requests Steps, Distance and Active Calories only; tests exclude the cited scopes. Reviewer sign-in uses regular Supabase auth, without hardcoded identity or entitlement bypass; no real account was tested on an AAB. Console lists only BIL; prior appeal status is unconfirmed. No signed AAB33 or clean-install test exists; v32 is unchanged, products/App Access/merged manifest remain unverified. We make no compliance claim. Please advise the official route to submit corrected Android33 while suspended.

هذه ليست مسودة محفوظة في Google؛ لم يُفتح نموذج Appeal ولم يُكتب فيه أو يُرسل شيء. ولا يُؤكد ظهور زر Appeal أن المحاولة السابقة لم تُستخدم. وفق مساعدة Google الرسمية لا تتجاوز محاولة واحدة لكل إجراء تنفيذي؛ لذلك القرار الآن هو عدم الإرسال، ثم تحديث النص بعد فحص AAB 33 وبيانات Play ودخول المراجع على النسخة نفسها.

تحديث 15 أكتوبر بعد الدفع: كوميت المصدر والوثائق `ef4b9f19f491426ba8663ba1a9d76f9af6fe0c67` يحوي المصدر الذي اجتاز الشاملة ذات البصمة أعلاه، واجتاز QA المركز على GitHub [Run 38653187976](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38653187976). لا يوجد AAB33 موقّع أو اختبار وصول مراجع على الحزمة؛ لم يتغير build32 أو Console، ولم يُفتح أو يُرسل Appeal.
