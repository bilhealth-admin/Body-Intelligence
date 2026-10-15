# BIL — مطابقة App Privacy الرباعية وخطة القرار المشروط

تاريخ التوثيق: 15 أكتوبر 2026. HEAD المصدر: `769169f2dd00f7e3dbcbce763285d2b81c2e9d60`، الفرع `integration/bil-qa-media-policy-20261011`، مع تعديلات محلية محفوظة. وقت تجميع هذا الملحق: `2026-10-15T17:51:21.394820+00:00`.

## القرار المباشر

**قراءة App Privacy ورسالة الرفض أصبحتا READ_VERIFIED، وليستا READ_BLOCKED. ما زال تصحيح الإجابات وإغلاق مطابقتها مع IPA وسلوك التشغيل BLOCKED/P0.** لا أوصي بإلغاء علامات tracking الثلاث اعتمادًا على NPA أو على نجاح QA بلا إعلانات. لا أوصي بإضافة ATT لمجرد مطابقة إعلان غير محقق. يلزم أولًا إثبات سلوك الإصدار الفعلي ثم تنفيذ القرار الموافق له بموافقة المالك.

الدليل الحي الذي قرأه الوكيل الرئيسي من DOM الفعلي وموصل Gmail الرسمي هو [live-store-ui-readback-20261015.json](evidence/policy-gate-20261015/live-store-ui-readback-20261015.json). لم ينفذ مؤلف هذا الملحق UI أو شبكة أو اختبارات أو بناء أو تعديل متجر جديدًا. لم تتغير حسابات أو أسعار أو Trial أو أدوار أو بيانات Production.

التصنيف المعروف في [A084 داخل policy-requirements.json](evidence/policy-gate-20261015/policy-requirements.json) هو **FAIL/P0 للحزمة المرفوضة build 35 والبيانات الحالية في ASC**؛ سببه مثبت، وليس تعذر قراءة أو نقص دليل افتراضيًا. **مطابقة candidate 36 مع IPA/runtime تبقى BLOCKED/P0** ولا تسمى FAIL مثبتًا على حزمة لم تختبر، ولا PASS بسبب نجاح QA.

## ما أثبته الدليل الحي الآن

| الواقعة | النتيجة ونطاقها |
|---|---|
| حالة Apple | iOS 1.0.0، REJECTED، مرتبطة بـ build 35. المراجعة بتاريخ 14 أكتوبر 2026 على iPad Air 11-inch (M3). لا تعني هذه الواقعة اختبار build 36. |
| سبب الرفض الأخير | Guideline 5.1.2(i): ASC يعلن tracking لـ User ID وDevice ID وProduct Interaction، بينما النسخة المقدمة لم تطلب ATT. هذا هو السبب المقروء، وليس استنتاجًا من Manifest. |
| App Privacy الحالي | 22 نوعًا مجموعًا، منها الأنواع الثلاثة نفسها معلنة للتتبع. نص النشر النسبي «2 days ago» لا يعين وقت نشر UTC دقيقًا. |
| تفصيل linked/purposes في ASC | القراءة الحية الإضافية تثبت الأغراض المعروضة لكل الأنواع الـ22. ظهر linked-identity bullet لـ21 نوعًا؛ Crash Data محفوظة null لأن bullet لم يظهر ولم يفتح radio. لا نستبدل null بـfalse أو نستنتج القيم من Runner. |
| عناصر Submission | **7 = تطبيق واحد + مجموعة اشتراك واحدة +4 اشتراكات +Boost واحد؛ أي 6 عناصر غير التطبيق.** مجموعة الاشتراك ليست منتج IAP سادسًا. |
| حالة العناصر الأخرى | Ready for Review، وليست approved. حالة API للمنتجات READY_TO_SUBMIT تخص كيانًا مختلفًا ولا تغني عن حالة Submission. |
| إغلاق الاعتراض | لم يثبت إغلاق رسمي من Apple. القراءة الحية لا تغير binary 35 ولا تمنح اعتمادًا لـ36. |

## الفصل بين إعداد QA والإصدار الفعلي

| المصدر الحالي | إعداد الإعلان المثبت | ما يجوز استنتاجه |
|---|---|---|
| `.github/workflows/bil_ios_signed_release.yml:251–252` | ADS_ENABLED=true وAD_PROVIDER_READY=true في تحقق المصدر | الإصدار الموقع المقصود يسمح بمسار إعلان؛ لا يمكن وصفه بأنه no-ads من نتائج QA. |
| الملف نفسه `:453–454` | القيمتان true في dart-defines لأمر البناء الموقع | هذه بصمة إعداد مصدرية، وليست IPA مبنية في هذا الملحق. |
| `.github/workflows/bil_android_release_candidate.yml:135–136` و`:230–231` | القيمتان true | يلزم تدقيق Android مستقل؛ لا تثبت إعدادات iOS وحدها إفصاح Google. |
| `.github/workflows/bil_rc_mobile_test_build.yml:79,162,242,249,370` | الإعلانات false في مسارات QA المذكورة؛ provider=false في حزمتَي release QA | نجاح هذه المسارات لا يختبر جمع SDK لإعلانات الإصدار الموقع حين تكون القيم true. |
| `admob_contextual_ad_gateway.dart:86–94` | `setSameAppKeyEnabled(false)` قبل initialization | يقلل نطاق معرّف Google first-party، ولا ينفي جميع المعرفات أو القياس أو جمع SDK. |
| الملف نفسه `:119–137` | شرط حساب بالغ مؤهل وUMP، ثم `nonPersonalizedAds: true` | مصدر NPA والموافقة موجود؛ NPA ليست إثباتًا مستقلًا لعدم tracking بحسب تعريف Apple. |
| `ad_policy.dart:49–99` | مواضع عامة فقط، Free باستحقاق خادمي، ولا مدخلات صحة/تغذية/بحث خاصة للإعلان | حدود مصدرية مهمة، ويجب إثبات عدم تجاوزها في runtime. لا تعني تعطيل SDK لكل المستخدمين. |

## معنى المطابقة الرباعية

1. **ما يفعله التطبيق:** المنتج الذي ينشئ البيانات ووجهتها وغرضها، مع اختلاف المحلي عن المزامنة وطلبات AI والرسائل والإعلان. هنا نعتمد على المصدر والجرد القائم I1، ولا ندعي التقاط شبكة جديدًا.
2. **ما تفعله SDKs:** قدرات وإعلانات المكتبة مقابل ما تفعله فعليًا في الحزمة المحددة وتحت الموافقة الفعلية. Supabase/Gemini/Meta OAuth معالجات ومسارات خدمة ينبغي تغطيتها، ولا يصبح كل منها SDK أصليًا مدمجًا في IPA لمجرد وجود اسمه.
3. **Privacy Manifests:** Runner يعلن 18 نوعًا app-owned، جميعها linked=true وtracking=false، وNSPrivacyTracking=false. تقرير Xcode المجمع يضيف manifests المكتبات ولا يلزم نسخ صفوفها تلقائيًا إلى Runner. Manifest مصدر مكتبة لا يقيس runtime ولا تعدله إجابات ASC.
4. **App Privacy في ASC:** الدليل الحي يثبت 22 نوعًا وثلاثة tracking، والقراءة الإضافية تثبت أغراض الأنواع الـ22 وظهور linked-identity bullet لـ21 نوعًا، مع Crash Data=null. الإجابة النهائية يجب أن تغطي التطبيق والمعالجات وSDKs جميعًا، مع فصل collected وlinked وpurpose وtracking. جمع البيانات وربطها بالحساب لا يعنيان tracking تلقائيًا.

الإحالات: **I1** [جرد التطبيق وSDK القائم](../APP_STORE_PRIVACY_DATA_INVENTORY.md)، خصوصًا أقسام Optional cloud data وCurrent app-owned data-type map وSDK-owned declarations. **I2** `community_repository_connections_messaging_mixin.dart` و`community_social_repository_mixin.dart` ومراجع علاقات UUID داخل I1. **I3** gateway وAdPolicy أعلاه. **I4** فحص GMA 13.7.0 الموثق في I1. هذه إحالات إلى أدلة محفوظة، لا إعادة تدقيق سحابة أو حساب حي.

المكتبة Flutter المقفلة `google_mobile_ads=9.1.0` تطلب GMA native ضمن مجال إصدار، وليس تعيينًا ثابتًا لكل IPA. لا يوجد `ios/Podfile.lock` في هذه اللقطة؛ ولم يقدم هذا الملحق graph حل الحزم النهائي أو IPA. فحص vendor السابق يخص **GoogleMobileAds 13.7.0** فقط، من أرشيف رسمي ببصمة `E89BA382A6244F5C8D92941015B12D98678689EBE14960EAA4C1D5951784A9C2`. لا ننسبه تلقائيًا إلى build 35 أو36.

## الأنواع الـ22: مصدر التطبيق، SDK، Manifest، وإجابة ASC

عمود SDK التالي يصف **إعلان vendor 13.7.0 المحفوظ**، ولا يثبت جمعًا حيًا أو انعدام تتبع. «لا صف في جدول GMA» لا ينفي معالجة ذلك النوع من التطبيق أو خادمه أو مكتبة أخرى. كل صف يحتاج مطابقة artifact/runtime عند الإغلاق؛ الحالات P0 المبينة تخص التناقض المؤثر في سبب الرفض. أغراض الأنواع الـ22 وحالة linked-bullet المقروءة مدونة في جدول DOM الإضافي أدناه؛ وحدها إجابة linked الخاصة بـCrash Data غير محسومة من هذه القراءة. ذلك لا يثبت سلوك IPA/runtime.

| # | نوع ASC | مصدر البيانات/وظيفة التطبيق | SDK المعروف وحدود إثباته | Manifest app-owned | ASC الحالي | ما يبقى للحسم |
|---|---|---|---|---|---|---|
| 1 | Search History | طلب بحث USDA الموثق بعد فقد المطابقة المحلية، مع جلسة مصادق عليها؛ لا سجل بحث إعلاني مقصود. جرد I1. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 2 | Other User Content | محتوى المجتمع وسياق المحادثة المدخل من المستخدم عند اختيار الوظيفة؛ I1 وI2. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 3 | Emails or Text Messages | رسائل المجتمع الخاصة؛ لا تعني قراءة صندوق بريد الهاتف. I1 وI2. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 4 | User ID | هوية Auth وربط ملكية السجلات والاستحقاق والطلبات؛ UUID فحص أهلية الإعلان لا يمرر إلى AdRequest في gateway المفحوص. I1 وI3. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking **نعم** | **P0:** ASC tracking نعم؛ Runner app-owned لا. لا يجوز حسم tracking من صف Runner أو SDK وحده. |
| 5 | Name | ملف المستخدم وبيانات دخول اختيارية وملف المجتمع؛ I1. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 6 | Other Data Types | العمر/تاريخ الميلاد والجنس وحقول الملف للحسابات المطلوبة، مع مزامنة اختيارية؛ I1. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 7 | Health | الوزن والقياسات والصحة المتصلة بحسب الأذونات، ومزامنة/سياق AI بحسب الاختيار؛ I1. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 8 | Photos or Videos | صور مختارة للملف والمجتمع وVision؛ لا تستخدم للتوجيه الإعلاني؛ I1 وI3. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 9 | Customer Support | طلبات الدعم المرتبطة بالحساب ومحتواها وسياق تقني محدود؛ I1. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 10 | Purchase History | معرّفات المعاملة والتحقق والاستحقاق؛ معالجة بطاقة الدفع عند المتجر، لا يجمعها BIL؛ I1. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 11 | Device ID | معرّفات التشغيل/التسجيل/الأمان app-owned وفق الجرد، مع احتمال معرّفات SDK مستقلة؛ I1 وI3. | GMA 13.7.0: linked نعم، tracking نعم؛ إعلان طرف ثالث/إعلان المطور/Analytics. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking **نعم** | **P0:** إعلان SDK tracking نعم يفرض تحققًا خاصًا. NPA وSameAppKey=false لا يحسمان إزالته. |
| 12 | Phone Number | مسار تسجيل/تواصل يطلب الرقم عند توفره؛ ليس شرطًا لكل دخول؛ I1. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 13 | Fitness | النشاط والتدريب والصحة المتصلة المختارة؛ لا تصبح مدخلًا للإعلان؛ I1 وI3. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 14 | Product Interaction | استعمال الوظائف وسجل طلبات AI الضروري للاستخدام/الحدود، وتفاعلات إعلان SDK عند تشغيله؛ I1 وI3. | GMA 13.7.0: linked نعم، tracking لا؛ إعلان طرف ثالث/إعلان المطور/Analytics. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking **نعم** | **P0:** ASC tracking نعم؛ Runner app-owned لا. لا يجوز حسم tracking من صف Runner أو SDK وحده. |
| 15 | Performance Data | زمن طلبات AI المرتبط بالحساب، وأداء SDK مستقل؛ I1. | GMA 13.7.0: linked لا، tracking لا؛ إعلان طرف ثالث/إعلان المطور/Analytics. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 16 | Email Address | Auth والملف والدعم وOAuth عند توفير البريد بالإذن؛ لا يمرر إلى طلب الإعلان؛ I1 وI3. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 17 | Crash Data | crash reporter الخاص بالتطبيق محلي وفق الجرد؛ SDK الإعلان يعلن تشخيص الأعطال بصورة مستقلة؛ I1 وI4. | GMA 13.7.0: linked لا، tracking لا؛ Analytics. | لا صف app-owned مستقل في Runner الحالي؛ لا يعني عدم وجود جمع SDK/خادم. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 18 | Other Diagnostic Data | سجلات المصادقة/الأمان/موثوقية الخدمة وتشخيص SDK؛ I1. | GMA 13.7.0: linked لا، tracking لا؛ إعلان طرف ثالث/إعلان المطور/Analytics. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 19 | Other Usage Data | ASC يعلن هذا النوع؛ سجل استعمال/تكلفة/حصة AI قد يفسر التصنيف. يحتاج تعيينًا صريحًا إلى منتج البيانات وتصنيفه النهائي؛ I1. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | لا صف app-owned مستقل في Runner الحالي؛ لا يعني عدم وجود جمع SDK/خادم. | collected نعم؛ tracking لا | فرق تصنيفي غير مغلق: لا صف مستقل في Runner 18 ولا GMA 7 الموثق. راجع المنتج الفعلي والغرض والتقرير المجمع؛ لا حذف أو إضافة آلية لمساواة الأعداد. |
| 20 | Coarse Location | استدلال IP لدى مزود الشبكة/الإعلان؛ ليس دليل إذن GPS أو قراءة موقع دقيق من BIL؛ I1 وI4. | GMA 13.7.0: linked نعم، tracking لا؛ إعلان طرف ثالث/إعلان المطور/Analytics. | لا صف app-owned مستقل في Runner الحالي؛ لا يعني عدم وجود جمع SDK/خادم. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 21 | Contacts | علاقات متابعة وصداقة UUID في المجتمع وتخصيص الخلاصة؛ social graph لا دفتر عناوين الهاتف؛ I1 وI2. | لا صف مقابل في جدول GMA 13.7.0 المفحوص؛ لا ينفي ذلك معالجة App/Auth/AI أو SDK آخر في الحزمة. | Runner: collected نعم؛ linked نعم؛ tracking لا. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |
| 22 | Advertising Data | بيانات الإعلان المعروض/التفاعل عند تشغيل SDK للمستخدم المؤهل؛ I3 وI4. | GMA 13.7.0: linked نعم، tracking لا؛ إعلان طرف ثالث/إعلان المطور/Analytics. | لا صف app-owned مستقل في Runner الحالي؛ لا يعني عدم وجود جمع SDK/خادم. | collected نعم؛ tracking لا | مطابقة IPA وruntime/GMA الفعلي قبل اعتماد الإجابة. |

## أغراض وربط App Privacy — قراءة DOM الإضافية للأنواع الـ22

المصدر هو [live-app-privacy-purposes-20261015.json](evidence/policy-gate-20261015/live-app-privacy-purposes-20261015.json)، بتاريخ 15 أكتوبر 2026، من الصفحة الحية نفسها دون استخدام Edit أو فتح radio. كل الأنواع أدناه collected=true في الدليل. أسماء الأغراض محفوظة كما عرضتها ASC؛ ليست أغراضًا مفترضة من Manifest أو أسماء SDK.

| # | النوع | الأغراض المعروضة في ASC | linked-identity bullet المشاهد | tracking bullet المشاهد |
|---|---|---|---|---|
| 1 | Name | Product Personalization؛ App Functionality | ظهر (true) | لم يظهر (false في دليل DOM) |
| 2 | Email Address | App Functionality | ظهر (true) | لم يظهر (false في دليل DOM) |
| 3 | Phone Number | App Functionality | ظهر (true) | لم يظهر (false في دليل DOM) |
| 4 | Health | Product Personalization؛ App Functionality | ظهر (true) | لم يظهر (false في دليل DOM) |
| 5 | Fitness | App Functionality؛ Product Personalization | ظهر (true) | لم يظهر (false في دليل DOM) |
| 6 | Coarse Location | App Functionality؛ Third-Party Advertising؛ Analytics | ظهر (true) | لم يظهر (false في دليل DOM) |
| 7 | Contacts | Product Personalization؛ App Functionality | ظهر (true) | لم يظهر (false في دليل DOM) |
| 8 | Emails or Text Messages | App Functionality | ظهر (true) | لم يظهر (false في دليل DOM) |
| 9 | Photos or Videos | App Functionality | ظهر (true) | لم يظهر (false في دليل DOM) |
| 10 | Customer Support | App Functionality | ظهر (true) | لم يظهر (false في دليل DOM) |
| 11 | Other User Content | App Functionality؛ Product Personalization | ظهر (true) | لم يظهر (false في دليل DOM) |
| 12 | Search History | App Functionality | ظهر (true) | لم يظهر (false في دليل DOM) |
| 13 | User ID | App Functionality؛ Product Personalization؛ Third-Party Advertising | ظهر (true) | ظهر (true) |
| 14 | Device ID | App Functionality؛ Analytics؛ Third-Party Advertising | ظهر (true) | ظهر (true) |
| 15 | Purchase History | App Functionality | ظهر (true) | لم يظهر (false في دليل DOM) |
| 16 | Product Interaction | App Functionality؛ Analytics؛ Product Personalization؛ Third-Party Advertising | ظهر (true) | ظهر (true) |
| 17 | Advertising Data | Analytics؛ Third-Party Advertising | ظهر (true) | لم يظهر (false في دليل DOM) |
| 18 | Other Usage Data | Analytics | ظهر (true) | لم يظهر (false في دليل DOM) |
| 19 | Crash Data | App Functionality؛ Analytics | **null — لم يظهر bullet؛ لم يفتح radio** | لم يظهر (false في دليل DOM) |
| 20 | Performance Data | App Functionality؛ Third-Party Advertising؛ Analytics | ظهر (true) | لم يظهر (false في دليل DOM) |
| 21 | Other Diagnostic Data | App Functionality؛ Analytics؛ Third-Party Advertising | ظهر (true) | لم يظهر (false في دليل DOM) |
| 22 | Other Data Types | App Functionality؛ Product Personalization؛ Analytics | ظهر (true) | لم يظهر (false في دليل DOM) |

**حدود الربط:** ظهر linked-identity bullet لـ21 نوعًا. لم يظهر هذا bullet عند Crash Data؛ لذلك تبقى القيمة المحفوظة **null**، ولا نستنتج linked=false دون قراءة الإعداد الفعلي. كون GMA يعلن Crash Data غير مرتبطة لا يحل محل هذا الدليل الحي. كذلك tracking-bullet هو وصف لما ظهر في ASC، وليس قياسًا لتتبع SDK على الجهاز.

أصبحت الأغراض الحالية معلومة: User ID يتضمن Third-Party Advertising وProduct Personalization، وProduct Interaction يتضمنهما مع Analytics؛ وOther Usage Data تعرض Analytics وlinked-bullet ظاهرًا. يبقى ربط هذه الأغراض بالمنتج الفعلي للحزمة مطلوبًا. لا يعني إلغاء tracking لاحقًا حذف كل أغراض الإعلان تلقائيًا، ولا يعني ظهور غرض إعلان أن tracking مباح دون شروط Apple. لم يجر أي تعديل App Privacy أو فحص runtime جديد هنا.

اتحاد Runner 18 مع أنواع GMA 7 الموثقة يعطي 21 نوعًا مختلفًا، لأن Device ID وProduct Interaction وPerformance Data وOther Diagnostic Data مشتركة. النوع الإضافي في قائمة ASC هو **Other Usage Data**. هذا فرق تصنيف يجب تعيينه، وليس دليلًا تلقائيًا أن ASC يجمع أكثر من التطبيق أو أن Runner خاطئ. بيانات استعمال/حصة AI أو مكتبة أخرى في graph النهائي قد تبرره. لا نحذف النوع لمجرد مساواة الأعداد، ولا نضيف صف Manifest عشوائيًا قبل تحديد المنتج والغرض المناسبين. درجته الحالية **P1/BLOCKED_CLASSIFICATION**.

## قبل/بعد مشروط للقيم الثلاث

| النوع | قبل: ما نعرفه الآن | إذا أثبت الإصدار النهائي عدم tracking | إذا أثبت tracking فعليًا أو بقي مجهولًا |
|---|---|---|---|
| User ID | ASC tracking=true وlinked-bullet ظاهر؛ الأغراض: App Functionality؛ Product Personalization؛ Third-Party Advertising. Runner linked=true وtracking=false. لا صف User ID في GMA 13.7.0 المفحوص؛ UUID الأهليّة محلي في gateway ولا يدخل AdRequest المفحوص. | يجوز اقتراح tracking=false لهذا النوع بعد التحقق من كل الجهات والإعداد النهائي. يبقى collected نعم حيث يستعمل Auth/ملكية السجلات؛ لا يحذف linked أو App Functionality لمجرد إلغاء tracking. | إن كان tracking فعليًا، يلزم تصميم ATT قبل هذا السلوك ومنع التتبع عند الرفض، بعد قرار المالك. إذا كان مجهولًا، يبقى تعديل ASC BLOCKED ولا نستبدل unknown بـfalse. |
| Device ID | ASC tracking=true وlinked-bullet ظاهر؛ الأغراض: App Functionality؛ Analytics؛ Third-Party Advertising. Runner app-owned tracking=false، بينما vendor GMA 13.7.0 tracking=true. NPA وSameAppKey=false موجودان فعلًا. | tracking=false ممكن فقط بدليل يفسر معرّفات SDK الفعلية وتهيئته وكل مساراته. يبقى collected/linked/purposes بحسب معرّفات التطبيق وSDK؛ عدم IDFA وحده غير كافٍ. | إن وقع tracking، يلزم ATT قبل حدوثه وإثبات عدم استعمال معرّف بديل/بصمة عند الرفض. إن تعذر الإثبات، يظل P0/BLOCKED ولا تغير العلامة. |
| Product Interaction | ASC tracking=true وlinked-bullet ظاهر؛ الأغراض: App Functionality؛ Analytics؛ Product Personalization؛ Third-Party Advertising. Runner وvendor GMA المفحوص كلاهما يعلن tracking=false؛ SDK يعلن أغراض إعلانات وAnalytics. | يجوز اقتراح tracking=false عند إثبات أن تفاعلات التطبيق والإعلان لا تربط ببيانات أطراف أخرى للإعلانات/القياس ولا تشارك مع data broker. تبقى أغراض/جمع SDK الصحيحة معلنة. | تشغيل analytics الخاص بـSDK قد يختلف عن product analytics المعطل داخل BIL. إن وقع tracking طبّق شرط ATT؛ إذا بقي مجهولًا لا تصنفه PASS. |

هذه **خطة تغييرات مقترحة وليست إذن تعديل**. لا نفترض تغيير الثلاث معًا؛ لكل قيمة قرار ودليل مستقل. لا يجوز استبدال رفض Apple بتعديل تجميلي في Manifest أو حذف فئات صحيحة من App Privacy.

## أصغر سلسلة أدلة قبل تنفيذ القرار

1. إثبات SHA وبصمة IPA/Archive المقصود لـ36 وdart-defines الفعلية في مسار الإصدار الموقع، ثم graph الحزم المحلول ونسخ SDK المدمجة وتوقيعاتها وPrivacy Manifests والتقرير المجمع. يجب أن يعكس الدليل مسار release ذي الإعلانات المفعلة، لا مسار QA الذي يعطلها. البناء/التوقيع/الرفع يحتاج الإذن المنفصل المعتاد؛ لم ينفذ هنا.
2. ربط كل معرّف/حدث بشركته المستقبلة وغرضه. فحص المسار قبل CMP ثم قبول/رفض/سحب الموافقة حيث ينطبق، والتثبيت البارد وإعادة الفتح وتبديل الحساب والمنطقة وFree/Premium. طلب CMP الضروري لا يسمى tracking تلقائيًا؛ يصنف ما يحدث فعلًا. لا يكفي فحص غياب IDFA أو حركة شبكة واحدة لنفي جميع الروابط بين الأطراف.
3. التحقق من تهيئة UMP/AdMob الفعلية، وسلوك SDK عند عدم إذن ATT، وpublisher first-party ID والمعرّفات الأخرى، ومطابقة وثائق vendor للإصدار المحلول. تظل صحة/لياقة/بحث المستخدم ومحتواه الخاص خارج مدخلات الإعلان كما يفرض المصدر. فحص حساب Premium الخالي من الإعلانات وحده لا يغطي Free.
4. حفظ نتيجة لكل نوع: collected وlinked وكل purpose وtracking، مع مصدر الاستنتاج وحدوده. احتفظ بجمع User ID وDevice ID وProduct Interaction المشروع وغرضه الصحيح حين يوجد، ولو كانت إجابة tracking النهائية false. افحص Other Usage Data صراحةً بدل حذفها أو نسبتها افتراضًا إلى Firebase؛ لا Firebase analytics أصلي مثبت في هذه اللقطة بمجرد وجود خدمات إشعار خلفية.
5. إذا أثبتنا no-tracking في المسار النهائي، يراجع المالك مسودة قبل/بعد وتعدل ASC للقيم المبررة فقط ثم تعاد قراءة الصفحة الحية. إذا ثبت tracking، يختار المالك إزالته/تهيئته دون tracking أو تنفيذ ATT الصحيح قبل أي tracking مع مسار رفض آمن؛ هذا قرار وتنفيذ منفصلان، لا تغيير في هذا الملحق. تعطيل الإعلان/إزالة SDK خيار منتج مستقل إن اختير؛ يجب أن يصل إلى مسار الإصدار الفعلي ثم تعاد مطابقة الميزات والإفصاحات والحزمة.
6. عند اكتمال الأدلة، تكتب ملاحظات المراجعة للحزمة المقصودة بما ثبت فعليًا، وتشرح معالجة سبب 5.1.2(i) دون ادعاء أن binary 35 تغيرت. إرسال الرد أو إعادة التقديم وتعديل ASC بحاجة لموافقة المالك، ولا تنفذها هذه الخطة.

## حالة الإغلاق بعد هذه الإضافة

| البند | الحالة |
|---|---|
| قراءة App Privacy الحالي والأغراض والربط المعروض | **PASS_READ_VERIFIED**: 22 نوعًا بأغراضها و3 tracking؛ linked-bullet لـ21 نوعًا، وCrash Data=null دون حسم radio. |
| قراءة سبب رفض 35 الأخير وعدد عناصر Submission | **PASS_READ_VERIFIED**؛ 7 إجمالًا و6 غير التطبيق. |
| حالة build 35 وASC الحالية — A084 | **FAIL/P0 مثبت** بسبب tracking المعلن دون ATT؛ مطابقة candidate 36 تبقى **BLOCKED/P0** بصورة مستقلة. |
| وجود NPA وSameAppKey=false وحدود المصدر | **PASS_SOURCE_SCOPE** فقط، وليست شهادة runtime. |
| مطابقة App/SDK/Manifest/ASC للإصدار36 | **BLOCKED/P0**؛ IPA/graph/runtime الصحيح غير مثبت هنا. |
| تصحيح tracking في ASC | **BLOCKED/P0** حتى دليل النوع وقرار المالك؛ لم يتغير المتجر. |
| Other Usage Data | **BLOCKED/P1_CLASSIFICATION** حتى ربط المنتج الفعلي والغرض/التصنيف. |
| إغلاق رفض Apple رسميًا | **BLOCKED**؛ لم يحدث إرسال أو قبول جديد. |

الموانع الباقية محددة في الدليل والتنفيذ؛ عائق قراءة App Privacy ورسالة الرفض أزيل. لا تمنح هذه الإضافة شهادة قبول Apple أو Google، ولا تستخدم اختبار Goldens أو نسخة QA لتعويض فحص IPA/runtime الذي يخص سبب الرفض.

## المراجع الرسمية وحدود القراءة

قراءات السياسات المحفوظة مؤرخة 15 أكتوبر 2026، وأعيد استخدامها دون شبكة جديدة في هذا التحديث: [Guideline 5.1.2(i)](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing)، [تعريفات App Privacy وtracking](https://developer.apple.com/app-store/app-privacy-details/)، [مسؤولية البيانات وATT](https://developer.apple.com/app-store/user-privacy-and-data-use/)، [تجميع Privacy Manifests](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)، [إفصاح Google Mobile Ads](https://developers.google.com/admob/ios/privacy/data-disclosure). المصدر الرسمي يحدد الشرط؛ سلوك BIL النهائي يثبت انطباقه. لم تنقل فقرات طويلة حرفيًا.

## بصمات مدخلات هذا الملحق

| المدخل | SHA-256 |
|---|---|
| docs/qa_next/evidence/policy-gate-20261015/live-app-privacy-purposes-20261015.json | `67afa93e3e75b0ef2a2f569dfaf3e911853bb420a047b58e0335f0ffb62c67b6` |
| docs/qa_next/evidence/policy-gate-20261015/live-store-ui-readback-20261015.json | `f409180e4692f7aae63a792120d9191127963d1ba5f8924afb94804e440cec2a` |
| docs/APP_STORE_PRIVACY_DATA_INVENTORY.md | `3bd83b6e6ec7ba40e6c160aa91dc6e49af458f3acf76f26d0fdc9117372478b4` |
| ios/Runner/PrivacyInfo.xcprivacy | `5d8f8a40a8976f928a7e890aabde8d02e74e0487769b8794c1a4566270775249` |
| ios/Runner/Info.plist | `ffcff20d35899231661441084efdf4a5da0bfcfc1facb614462f5bea17921e3e` |
| pubspec.lock | `bb70bc2d38114dc61a0d28fd6feb21f2b91957ac1f82c54b14573898cfde2c54` |
| .github/workflows/bil_ios_signed_release.yml | `ada0bd63df351f76a7d99d569a5ca218a9cfbb4e25d93a734c6fc6730acf4c9a` |
| .github/workflows/bil_android_release_candidate.yml | `dc7058e1e64184258385b254913967809a375546c7c53b0b03b30b32f383aae4` |
| .github/workflows/bil_rc_mobile_test_build.yml | `1ccc8365f08486cb8aad90848a6afad9e110f43f11daa10242e70926917630ac` |
| lib/features/ads/services/admob_contextual_ad_gateway.dart | `9f9e383bbd658ccdd9fccf6fea855658a0789c7a4cef34642d500661870dc2d0` |
| lib/features/ads/domain/ad_policy.dart | `8614954ccab3d89c6dedd8673362a1c90c255df8d506c054862eb985bf15c399` |
| build/qa/policy-gate-20261015/sources/apple-guidelines.html | `247ed6016623131cab3e94bf4c92b1fd8f61f37c2e24af59c0c88c27b729e137` |
| build/qa/policy-gate-20261015/sources/apple-privacy-labels.html | `7d3e3539a0f7905f28871eab8a06c153db8b91cd8963dcde85fd043575cee9af` |
