> تحديث16أكتوبر2026 لاحق: وجد حسابGoogleالمخصص حيًا فيAuth باسم `google-play-review-20261004@bilhealth.com`، معPremium/AI فعالين. هو الحساب المقصود لتجهيزGoogle، بينماASC يستعمل `play-review@bilhealth.com`. ما زالت قيمةAppAccess الحالية غير مقروءة. وحّد المالك وصولهما معحسابهالشخصيdr.kadem، معبقاءAdminللـkademcom وbilhealth.appفقط؛ [التنفيذوالإثبات](BIL_20261016_REVIEW_AND_OWNER_TEST_ACCOUNTS_ALIGNMENT_AR.md).

# ملف تجهيز رفع تعليق Google Play — 16 أكتوبر 2026

**محضّر محليًا، غير مرسل.** توجيه المالك الأخير هو «يلا جهز لفك الحظر في كنسول». يُجهّز هذا الملف القضية والنص والخطوات الآن؛ لا يتضمن التوجيه إذن إرسال Appeal أو إضافة/رفع build أو تنفيذ شراء. لم يفتح كاتب هذا الملف UI أو يغيّر متجرًا أو مصدرًا أو حسابًا أو Production؛ كتب هذا الملف الجديد فقط. يراجع الوكيل الرئيسي Console والبريد الحيين بصورة مستقلة.

## القرار العملي الآن

**خطة الاستئناف جاهزة الآن للمراجعة وموافقة المالك؛ الإرسال غير منفذ.** أثبتت قراءة الوكيل الرئيسي الحية أن النموذج الرسمي يتيح اختيار **I understand what led to this issue and will fix it**، ثم وصف خطة الإصلاح حتى1000حرف. لا تشترط هذه الطريق اكتمال الحزمة أو اختبارات الجهاز قبل تقديم **الخطة**. النص الإنجليزي النهائي أدناه949حرفًا، يفصل ما هو موجود في المصدر/الخادم عن ما سيختبر قبل إعادة التقديم، ولا يدعي خطأ قرار Google أو اكتمال المعالجة. لا يحتاج تجهيز الخطة أو موافقة المالك عليها إلى انتظار Polish أو build جديدة.

**إعادة إرسال التطبيق للمراجعة ليست جاهزة بعد.** الحزمة المصححة وبصمتها، وتجربة الحساب المخصص عليها، وتوفر منتجات Play، ومطابقة الأذونات والتصريحات هي بوابات **قبل app resubmission**، وليست شروطًا مخترعة لقبول إدخال خطة الاستئناف في هذا النموذج. تنفيذ تلك الخطوات ينتظر التفويض اللازم للبناء/الإجراءات، وقبول Appeal إن اشترطه المسار الرسمي. لا نغيّر package أو حساب المطور للالتفاف على التعليق. يراجع المالك الخطة والقضية وحدود الأدلة المتاحة وسجل الإرسال المتاح قبل الإذن بإرسال الاستئناف الواحد.

## هوية القضية والمسار الآمن

| الحقل | القيمة المثبتة وحدودها |
|---|---|
| اسم التطبيق | Body Intelligence Log / BIL |
| package | `com.bilhealth.bodyintelligencelog` |
| developer / app داخل Console | `7540824385820504578` / `4974243137795319021` |
| Suspension case | **`4976804875812644073`** |
| قرار التعليق | **8 أكتوبر 2026**؛ `Violation of Enforcement Process policy` / `Repeated app rejections` |
| Console | ما زالت `App suspended`؛ تعرض `8 Oct 2026, 22:38` وإزالة كل النسخ السابقة. المنطقة الزمنية للوقت المعروض غير مفترضة. |
| أصل البريد | `1a11d06ac8638e5b`؛ التوقيت الفعلي من قراءة Gmail الحية للوكيل الرئيسي: **2026-10-08T19:38:58Z** |
| App content | معطلة فعليًا: `disabled=true` وأب يحمل `disabled`، رغم `aria-disabled=false`. لم تؤد محاولة التنقل إلى فتح App Access أو Data Safety. |
| Appeal UI | الزر المباشر لم يفتح نموذجًا أولًا؛ بعدها فتح الوكيل الرئيسي المسار الرسمي العام، واختار BIL Health ثم تطبيق BIL ثم Appeal، فظهر الحوار الصحيح. اختار سبب الخطة الصادق وملأ النص949حرفًا مؤقتًا؛ لم يضغط Submit. |
| السجل السابق | بحث Gmail المحدود الحي بعد 8 أكتوبر بالـpackage/name/case وكلمات appeal/suspension/suspended لم يعثر على thread استئناف مستقل؛ أعاد رسالتي 8 أكتوبر. هذا **ليس إثباتًا لعدم إرسال Appeal سابق عالميًا أو عبر نموذج Console**. |

المرجع المحفوظ للقراءة السابقة والتفويض هو [إيصال Console](evidence/policy-gate-20261015/production-20261016/owner-authorization-and-google-ui.json). تحديث حالة البريد/زر Appeal والروابط أعلاه وصل مباشرةً من قراءة الوكيل الرئيسي الحية أثناء إعداد هذا الملف؛ لا ينسب كاتب الملف هذه القراءة إلى اتصال جديد أجراه بنفسه. أي إيصال أحدث يحفظه الوكيل الرئيسي له أسبقية زمنية على snapshot السابقة.

**خطأ رابط مثبت يجب تجنبه:** بريد التعليق المعروض في Console يخص BIL في subject/body/case، لكن رابط التذييل المحدد **Submit an appeal** يحتوي `aid=com.dima.marlo`، وهي حزمة أخرى. لم يستخدمه الوكيل الرئيسي. المسار العام المرصود هو `https://play.google.com/console/appealsForm?ts=SR`؛ فتحه واختار BIL صراحةً حتى ظهر الحوار الصحيح. هذا يزيل عائق فتح النموذج، ولا يزيل تعليق التطبيق أو يغير App content المعطلة.

يحافظ أي إرسال لاحق على اختيار BIL والـpackage والقضية الصحيحين. لا يُنقل إلى رابط الحزمة الأخرى. جهة اتصال مالك الحساب تتلقى نتيجة النموذج؛ **Additional contacts اختيارية** حسب الواجهة الحية. لا يوضع بريد `play-review@bilhealth.com` في حقل جهة اتصال المطور لمجرد أنه حساب دخول التطبيق؛ بريد الشركة/المالك وجهة الاتصال في Console مستقل عن حساب مراجعة التطبيق.

### ما أكدته الواجهة الرسمية عن خطة الاستئناف

- السبب المختار: **I understand what led to this issue and will fix it**.
- نص الواجهة: **If you understand what led to this issue and have a plan for how you will fix it, submit an appeal. If your appeal is approved, you must fix this issue before you send your app for review.**
- اسم الحقل الفعلي: **Describe the changes that you’ll make to fix this issue if your appeal is granted**.
- الحد الفعلي: **1000 characters**؛ العداد المقروء بعد إدخال الوكيل الرئيسي **949/1000**. السبب الثاني مختار، وSubmit مفعّل لكنه **لم يُضغط**، وAdditional contacts فارغة. النص الحالي داخل الحوار **إدخال مؤقت غير مرسل وغير مثبت كحفظ على الخادم**.
- [صورة النموذج غير المرسل](evidence/policy-gate-20261015/google-appeal-20261016/official-plan-appeal-unsent.jpg) تحفظ الحالة التي أعدها الوكيل الرئيسي. Tab `2003098994` معلّمة handoff؛ كاتب هذا الملف لم يفتحها أو يتفاعل معها. هوية تطبيق BIL الصحيحة مؤكدة في اختيار الوكيل الرئيسي.
- لا نختار مسار «القرار خطأ» ولا نحول خطة مستقبلية إلى ادعاء إنجاز.

أُعيدت قراءة [إجراءات الرفض والتعليق والاستئناف الرسمية](https://support.google.com/googleplay/android-developer/answer/2477981?hl=en) في 16 أكتوبر 2026. توضح Google أن التعليق قد ينتج عن تكرار الرفض، وتسمح **باستئناف واحد لكل إجراء تنفيذي**. إجراءات رفع حزمة عبر tracks المنشورة في الصفحة ليست دليلًا على أن Console المعلّقة الحالية تسمح لنا بالرفع؛ يُطلب المسار الرسمي عند تعذره، دون تطبيق خطوات rollout أو نشر في هذه المهمة.

## سجل المخالفات: فصل النسخ والأسباب

الأوقات التالية UTC حيث ذُكرت. قُرئت الرسائل الأصلية في المراجعات السابقة، وأكد الوكيل الرئيسي هوياتها وأوقاتها في بحث Gmail الحي أثناء هذه المهمة. لا تُنسب كل الإشعارات إلى version32.

| الإشعار الأصلي | النسخة والسبب الدقيق | ما لدينا الآن | ما لا يزال غير مثبت |
|---|---|---|---|
| 16 سبتمبر، 05:36:26؛ Gmail `1a0a8b76655ed230` | **version13**؛ `Excessive data access for declared feature`: BodyFat / RestingHeartRate / SleepSession | Manifest المصدر الحالي يطلب Steps / Distance / Active Calories قراءة فقط. النطاق الضيق موجود أيضًا في مصدر32 المقروء سابقًا؛ لا نزعم أن كل ذلك أُصلح اليوم. | merged manifest لحزمة33، أذونات النظام، وتطابق Health Apps / Health Connect الحاليين في Play. |
| 16 سبتمبر، 05:36:28؛ Gmail `1a0a8b77579fcd7a` | `Broken Functionality`: `Unresponsive UI elements, such as buttons or icons`؛ **لا رقم نسخة في نص الإشعار** | المرفق `IN_APP_EXPERIENCE-2101.png` يعرض تعذر العثور على عنصر شراء. المصدر يتضمن preflight للشراء وtimeout/retry/حالات catalog؛ لا نستنتج أن كل الأزرار معطلة أو أن عيب سبتمبر هو نفسه عيب32. | توفر منتجات Play على الحزمة/الحساب/بلد المراجع، واستجابة المسار الفعلي. تعليق المتجر قد يعطل منتجًا؛ لا يثبت ذلك وحده عيب كود جديدًا. |
| 3 أكتوبر؛ Gmail `1a1002638f11e217` | `App content is restricted by a paywall`؛ **لا رقم نسخة مثبت في النص** | فصل authentication عن entitlement والرصيد وloading/error في المصدر | هوية وجلسة وصلاحية المراجع على النسخة المقصودة. |
| 8 أكتوبر، 10:01:02؛ Gmail `1a11af591a4d0cb9` | **versionCode32**؛ paywall؛ المرفق `IN_APP_EXPERIENCE-6955.png` يظهر Goals → nutrient goals → Plans | مصدر محلي يعالج التحقق/الاستمرارية وحدود المزايا؛ اختبارات مصدر لا تجربة حساب | build32 لم تتغير، ولا clean-install لحساب المراجعة على حزمة33. الصورة لا تثبت وحدها هوية الحساب أو نتيجة entitlement. |
| 8 أكتوبر، 19:38:58؛ Gmail `1a11d06ac8638e5b` | تعليق للقضية `4976804875812644073` بسبب **Repeated app rejections** | القضية والحالة الحيتان محددتان؛ هذه الحزمة توحد الأدلة بدل نسب كل شيء إلى سبب واحد | لا قرار إعادة تفعيل، ولا استئناف مرسل في هذه المهمة، ولا سجل مستقل يحسم إرسالًا سابقًا. |

تفاصيل الصور وبصماتها محفوظة في [ملف 11 أكتوبر](BIL_20261011_GOOGLE_APPEAL_PREPARATION_AR_EN.md) و[مصفوفة Google](BIL_20261015_POLICY_GATE_APPENDIX_GOOGLE_AR.md). لا ترفق Gmail raw أو روابط تنزيل موقعة أو credentials أو صورًا تكشف سجلات مستخدم حقيقي؛ تحفظ النسخة العامة من الأدلة المنقحة مع بصماتها عند الإرسال المأذون.

## سجل ما أُنجز فعلًا وما لم ينجز

| الطبقة | النتيجة الحالية القابلة للقول | حدودها التي تبقى مع أي نص مرسل |
|---|---|---|
| المصدر | worktree `G:/BIL_Project/worktrees/bil-ios36-audit-snapshot-20261014`؛ الفرع `integration/bil-qa-media-policy-20261011`؛ HEAD **`ed963053c62cc549cbe50757279bd39d73a10e35` مع تغييرات محلية غير ملتزمة** | HEAD وحده لا يمثل كل البايتات المختبرة ولا مصدر إصدار مجمد؛ لا artifact33 أو hash نهائية متاحة. |
| آخر شاملة اكتملت | **9,888 حالة: 9,884 PASS، 4 FAIL/ERROR، 0 skipped؛ 1,358 ملفًا**. [الدليل](evidence/policy-gate-20261015/ci-regressions-20261016/corrected-root-full-first/proof.json) | لا تسمى PASS. الثلاثة توقعات copy القديمة وحالة شرط workflow محفوظة في سجل الفشل. |
| الإصلاح وإعادة المتأثر | **33 PASS، 0 failed/skipped**، تغطي الملفات الأربعة كاملة بما فيها الحالات الأربع، دون تحديث Goldens. [الدليل](evidence/policy-gate-20261015/ci-regressions-20261016/four-failures-focused/proof.json) | نجاح focused لا يتحول إلى نجاح comprehensive. الشاملة المصححة التالية pending وقت هذا التحضير؛ لا يُكتب لها رقم نجاح متوقع. |
| Production | **11 migration نُشرت فعلًا** في 15 أكتوبر 22:49–22:51 UTC، مع catalog/ACL ومقارنة العقود ورفض anonymous المحدود. [إيصال التنفيذ](evidence/policy-gate-20261015/production-20261016/deployment-result.json) | ليست تجربة دخول حساب أو شراء أو رحلة تطبيق حية. حافظت مقارنة ست مجموعات جداول مالية على صفوفها؛ لا تدعي أنها منحت حساب المراجعة حقًا أو رصيدًا. |
| الاستثناءات من النشر | `community_post_review_receipts_v2` **لم تُنشر** بسبب تعارض fan-out مع V1 الحية؛ **0 Edge Function deployments** في الإيصال | لا تدع نشر receiptV2 أو recipient/memo/verifier المحلي. ليست نتيجة المصدر خدمة متاحة تلقائيًا للمراجع. |
| الأدوار | نُشر ترحيل المدير الوحيد ضمن11 أولًا؛ ثم صحح الوكيل الرئيسي أثر التصنيف الشخصي بترحيل حي لاحق **`20261015231142`** أعاد صفّي Admin السابقين بالضبط، مع33حالة معزولة PASS، بحسب تحديثه المباشر | هذا التصحيح اللاحق مستقل عن receipt11 السابقة، ولا يجعل الحسابين الشخصيين مراجعي متجر. الحساب المخصص بقي Admin=false/Moderator=false. لا تنسب تصحيح الأدوار إلى نجاح Auth أو اختبار حزمة. |
| الحساب المخصص على الخادم | قراءة الوكيل الرئيسي الحية أثبتت هوية واحدة للبريد المخصص، confirmed وغير banned، وكلمة مرور موجودة؛ grant وsubscription mirror نشطان، `premium_ai_coach` حتى2027-10-05؛ الرصيد granted2500/used0/reserved0/refundDebt0؛ Admin=false وModerator=false | **تهيئة خادم مثبتة فقط**: لا password login ناجح أو RLS/UI أو وصول على artifact. لا تحفظ كلمة المرور في الوثيقة، ولا تخلط ذلك بالحسابين الشخصيين. |
| بيانات المتجر | إعداد الروابط والتبريرات ومسودة App Access منجز محليًا | **0 Google store fields written**؛ إجابات App Access / Data Safety / Health الحالية غير مقروءة. لا تعدل unknown إلى compliant. |
| الحزمة | Android32 المنشورة سابقًا **لم تتغير**؛ Android33 **لم تُبنَ كـAAB موقعة** | لا clean-install ولا merged release manifest أو اختبار SKU أو reviewer journey على33. لا رفع/إضافة build مأذون بهذه المهمة. |

ينسخ هذا الجدول آخر receipts المتاحة وقت الإعداد. إذا انتهت الشاملة التالية أو تغيّر نشر الخادم، يحدّث الوكيل الرئيسي النص من الإيصال الجديد قبل أي إرسال؛ لا تنسب الأرقام السابقة إلى SHA/بايتات أحدث تلقائيًا.

## الحساب الصحيح: إعداد الهوية ليس نجاح وصول

- `dr.kadem.nana@gmail.com` و`bilhealth.app@gmail.com` **حسابا اختبار شخصيان** بتوضيح المالك، وليسا حسابي مراجعة متجر. لا تستخدمهما في حقول App Access ولا تمنحهما دورًا بسبب alias تاريخي.
- الحساب المخصص هو **`play-review@bilhealth.com`**. وجده الوكيل الرئيسي حيًا في ASC، وطابق ملف Apple الأصلي. `docs/release/BIL_EPIC15_PLATFORM_METADATA.json`، الحقل `google_play.app_access`، يشير إليه تاريخيًا فقط. **لم تُقرأ هوية App Access الحالية في Google Play** بسبب التعليق.
- قراءة Production الحية اللاحقة للوكيل الرئيسي أثبتت `identity_count=1`، وemail confirmed، وpassword present، وعدم الحظر؛ grant من cohort `apple-app-review-20261005` نشط حتى2027-10-05، وmirror provider `closed_test`/plan `premium_ai_coach`/lifecycle `active` بالانتهاء نفسه. AI balance: granted2500/used0/reserved0/refundDebt0؛ Admin=false/Moderator=false. هذه قراءات بلا تعديل، وتدعم عبارة **configured server-side** فقط؛ لا تدعم **login tested** أو **all UI unlocked**. لا تثبت هوية Play الحالية غير المقروءة.
- محاولة التحقق العادي للحساب المخصص اليوم **رفضتها automatic approval review قبل بدء العملية**، بحسب الوكيل الرئيسي. لم يُنفذ اتصال Auth؛ ليست النتيجة invalid credentials أو رفض Supabase أو دليل نجاح/فشل الحساب. لا تُستبدل كلمة مروره ولا reset ولا impersonation لاستنتاج سبب لم يقع.
- لا كلمة مرور أو JWT أو code أو session أو raw receipt في هذا الملف. تبقى القيم داخل حقول المتجر الآمنة، وتفصل جهة اتصال المطور عن حساب دخول التطبيق.
- مسار المصدر الصحيح: **Sign in → Store reviewer access → Email address / Password → Sign in**. التسجيل العادي بالبريد يرسل OTP. [مسودة الخطوات](BIL_20261016_GOOGLE_APP_ACCESS_DRAFT_EN.md) مشروطة بتجربتها على النسخة المقصودة؛ وجودها ليس إثباتًا لنجاح الدخول أو entitlement أو رصيد AI.

## أصغر حزمة أدلة لازمة قبل إعادة إرسال التطبيق للمراجعة

هذه خطوات تنفيذية محددة، لا قائمة انتظار لـPolish أو تكرار اختبارات بلا سبب. ما يحتاج build أو إرسالًا لا ينفذ تحت تفويض التحضير الحالي.

1. **خطة Appeal الآن:** المسار الرسمي وحوار خطة الإصلاح والحد1000 أصبحت مثبتة، والنص949حرفًا داخل الحوار مؤقتًا وغير مرسل. يراجع المالك النص والقضية الصحيحة وسجل الإرسال المتاح، ثم يقرر إرسال Appeal أو إبقاءها مسودة. غياب signed33 أو نهاية الشاملة لا يمنع **عرض خطة مستقبلية صادقة لموافقته الآن**؛ لا تُضغط Submit دون إذنه. قيد App content/الرفع إن وجد يذكر في الخطة لطلب المسار الصحيح، ولا يعالج بفتح حزمة أخرى أو Appeal مكررة.
2. **المصدر والخادم المرتبطان بالمخالفات:** تُقرأ نتيجة الشاملة المصححة عند اكتمالها وتوثق دون تحويل focused إلى full. تُحسم الخدمات التي تستدعيها رحلة المراجع فعلًا؛ إن احتاجت Edge محلية غير منشورة أو مسار receiptV2 غير المتوافق، يعالج السبب المتأثر ويثبت نشره/توافقه قبل وصفه حيًا. نشر11 لا يعني أن كل backend اكتمل. لا يلزم انتظار تحسين مرئي غير متعلق بالمخالفة لطلب المسار الرسمي.
3. **حزمة مصححة بعد إذن بناء منفصل:** مصدر وبصمة مدخلات نهائيان، versionCode33، AAB موقعة وSHA-256، وAPK تثبيت مشتقة من البايتات نفسها عند الحاجة. تحفظ merged manifest ونسخ SDK الفعلية؛ تظهر أذونات Health الثلاث فقط دون الأنواع المرفوضة أو write/background غير مستخدم. تختبر Health Connect على نظام مدعوم وتطابق Health declaration حين يتاح؛ لا تستبدل ذلك بإقلاع debug offline.
4. **حساب مخصص على الحزمة نفسها:** دخول عادي ببريد/كلمة مرور قابلة لإعادة الاستخدام دون OTP/2FA مانع، ثم فتح بارد/دافئ وإعادة فتح. يثبت Auth والجلسة وfeature entitlement ورصيد Coach/Vision كل على حدة، دون شراء/بطاقة/نشر لكسب رصيد ودون hardcoded reviewer bypass. يتم الرجوع من **More → Goals → Additional Nutrient Goals / Calorie Goals By Meal**، وCoach وVision، دون Plans خاطئة أو تحميل عالق. تبقى حالة Free العادية سليمة. الحذف/الاستهلاك أو معاملات sandbox تستخدم حساب اختبار مخصصًا عند الإذن، للحفاظ على حساب المراجعة.
5. **SKU والرفض القديم:** تقارن `bil_premium`، `bil_premium_annual`، `bil_premium_ai_coach`، `bil_premium_ai_coach_annual` و`bil_ai_boost` مع products/base plans والبلد والحساب الفعلي. يثبت lookup/preflight وresponse/Retry في المسار الذي أظهر تعذر العنصر، دون شراء حقيقي غير مأذون. إذا عطل التعليق متجر الاختبار، يسجل أنه قيد Play ويطلب المسار الرسمي؛ لا يعلن PASS أو يعيد كتابة الفوترة بلا عيب مثبت.
6. **الحقول قبل الإرسال النهائي:** عندما يسمح المسار، تطابق App Access الإنجليزية وحسابها الفعلي وHealth Apps/Health Connect وData Safety/Ads والروابط مع الحزمة والخدمات. تحفظ قراءة ما قبل/بعد لأي تعديل. يراجع المالك النص النهائي المبني على receipts ويأذن بإرساله المحدد؛ يرفق أقل دليل منقح لكل مخالفة، لا كلمات مرور. تراجع قائمة تطبيقات المطور الحالية حيث تتاح قبل ادعاء إكمال مراجعة باقي التطبيقات؛ القراءة السابقة التي أظهرت BIL وحدها ليست قائمة حية جديدة تلقائيًا.

يبقى حد العمل الحالي: **لا build جديدة، ولا upload/addition، ولا إرسال Appeal/رد سياسة/نشر**. لا تعني هذه الحدود أن إعداد طلب المسار الرسمي مؤجل؛ النص أدناه جاهز للمراجعة الآن بوقائعه الحالية.

## English official-form plan — 949 characters, NOT SENT

**جاهز لمراجعة المالك الآن، وليس طلب إعادة إرسال التطبيق جاهزًا.** هذه خطة المستقبل ضمن سبب النموذج الثاني المثبت، لا ادعاء إغلاق المخالفات أو إنجاز اختبار لم يحدث. لا توجد placeholders أو كلمة مرور. النص التالي **949 حرفًا شاملًا المسافات** دون Markdown أو فاصل السطر، وهو النص الحالي الذي أدخله الوكيل الرئيسي في الحقل، وعداده949/1000. لا يضاف Subject أو package/case إلى النص على حساب الحد؛ التطبيق والقضية مربوطان بالنموذج الصحيح.

**عنوان ملف/رسالة مرافقة إن احتاجته قناة رسمية منفصلة، وليس حقلًا مثبتًا في الحوار:** Case 4976804875812644073 — Body Intelligence Log: remediation plan after suspension

**Body for “Describe the changes that you’ll make to fix this issue if your appeal is granted”:**

> We understand the suspension followed Health Connect overreach on v13, an earlier unresponsive purchase screen/item error, and paywall-blocked reviews on 3 October and 8 October (v32). We do not dispute these findings. Version 32 is unchanged. Current source limits Health Connect to Steps, Distance and Active Calories and improves entitlement loading/retry and product lookup; it is not a tested Play release. Dedicated reviewer access and AI balance are configured server-side; normal sign-in and app access remain unverified. Before resubmission we will test a corrected signed build, reviewer access without payment/OTP, AI balance, all cited UI and Play SKUs; verify merged permissions; and match App Access, Data Safety and Health declarations to the build and backend. We will review our portfolio and all tracks and replace noncompliant bundles as permitted. Please confirm the official route to provide the corrected build while suspended.

النص يفصل Health13، وUI/شراء أقدم، ورفضpaywall3أكتوبر، ورفضpaywall8أكتوبر/version32. عبارة server-side تشير إلى grant/mirror/balance المقروءة، ولا تدعي نجاح ordinary login أو RLS/UI. أفعال **will test / verify / match / review / replace** هي خطة قبل إعادة التقديم بعد السماح، وليست أفعالًا منجزة. لا ضمان لقبول Appeal أو فك التعليق.

## أدلة إعادة تقديم التطبيق لاحقًا، دون جعلها شرطًا لخطة Appeal الآن

| المستند/المرفق | متاح الآن | ما يضاف فقط عندما يثبت |
|---|---|---|
| القضية وتسلسل الإشعارات | الجدول أعلاه، وروابط الإيصالات المحلية | screenshot/readback حديثة للتطبيق الصحيح والنموذج الصحيح، منقحة دون بيانات دخول. |
| المصدر والاختبارات | SHA الأساس مع dirty scope؛ full FAIL وfocused PASS بإيصالاتهما | SHA/بصمة نهائية ونتيجة الشاملة المصححة الفعلية؛ لا تستبدل النتائج التاريخية. |
| Backend | إيصال11 migrations والاستثناءات | before/after لأي نشر لاحق يخص رحلة المراجع، مع نجاحها الفعلي؛ لا سجل أسرار أو صفوف خاصة. |
| Artifact33 | **غير متاح** | versionCode / source fingerprint / AAB hash / signature identity / merged manifest / SDK inventory. |
| Account access | إعداد ASC وgrant/mirror/balance وأدوار الخادم المخصصة مثبتة؛ هوية Play الحالية غير مقروءة ودليلها المحلي تاريخي | إيصال دخول عادي بارد ودافئ وGoals/Coach/Vision وbalance على artifact نفسها؛ القيم السرية في قناة Google الآمنة فقط. |
| SKU وHealth/metadata | source catalog والتبريرات والنصوص محضرة | نتيجة Play/الجهاز والتصريحات الحية الحالية وأي حفظ/readback فعلي. |

## المراجع وحدود الملف

- [مسودة 11 أكتوبر وسجل الصور](BIL_20261011_GOOGLE_APPEAL_PREPARATION_AR_EN.md)؛ تقرأ كسجل تاريخي، لا كحالة الخادم الحالية.
- [ملف Google الأحدث وتسلسل الرفض](BIL_20261014_GOOGLE_APPEAL_EVIDENCE_AR.md) و[ملحق السياسات](BIL_20261015_POLICY_GATE_APPENDIX_GOOGLE_AR.md).
- [تجهيز Google المصحح](BIL_20261016_GOOGLE_STORE_METADATA_PREPARATION_AR.md)، [App Access المصحح](BIL_20261016_GOOGLE_APP_ACCESS_DRAFT_EN.md)، و[تصحيح حساب ASC](BIL_20261016_APPLE_STORE_METADATA_PREPARATION_AR.md).
- [تقرير نشر Production](BIL_20261016_PRODUCTION_AND_STORE_PREPARATION_AR.md) و[إيصال التنفيذ](evidence/policy-gate-20261015/production-20261016/deployment-result.json). أسماء reviewer_a/reviewer_b التاريخية لا تتجاوز توضيح المالك لهوية الحسابين الشخصيين.
- [متطلبات App Access الرسمية](https://support.google.com/googleplay/android-developer/answer/15748846?hl=en) و[نشر تطبيق Health Connect](https://developer.android.com/health-and-fitness/health-connect/publish)، قرئا في16 أكتوبر في هذه المهمة الأوسع؛ [الاستئناف وإعادة التقديم](https://support.google.com/googleplay/android-developer/answer/2477981?hl=en) أعيد فتحه عند إعداد هذا الملف.

هذا الملف يجهز قرارًا ونصًا قابلين للمراجعة؛ لا يمثل حفظ نموذج أو رفع حزمة أو محاولة Auth أو إزالة تعليق أو موافقة متجر. تعديل هذا الملف فقط لا ينفذ أي خطوة من الخطوات الخارجية المذكورة.
