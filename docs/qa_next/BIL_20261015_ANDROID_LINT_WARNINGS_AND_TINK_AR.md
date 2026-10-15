# BIL — مراجعة Android Lint وتبعيات Tink وOkHttp وموارد الإشعارات

تاريخ القراءة: 15 أكتوبر 2026. هذا ملحق تقني لبوابة السياسات، ولا يثبت قبول المتجر أو سلامة حزمة موقعة لم تُبنَ.

## النتائج التي يجب فصلها

تشغيل AGP الحقيقي بعد إصلاحات SDK انتهى خلال1192.508 ثانية دون timeout: Debug احتوى3 أخطاء، أحدها عطل Insights والباقيان PropertyEscape؛ Release احتوى خطأَي PropertyEscape فقط. لا ننسب عطل Debug إلى Release دون سجل. النسختان تعرضان134 تحذيرًا متطابقًا في23 نوعًا، منها40 في Android الخاص بـBIL و94 في SDKs؛ ليست268 مشكلة مستقلة. احتُفظ بالـXML الأصلي والنتائج الفاشلة في [الدليل](evidence/policy-gate-20261015/post-sdk-lint-before-local-path-fix/summary.json).

التشغيل التالي المعتمد على cache أعاد XML القديم نفسه: `:app:lintAnalyzeRelease` و`:app:lintReportRelease` كانا UP-TO-DATE رغم تصحيح local.properties المتجاهل. لم نسمِّ ذلك دليل إعادة فحص. ثم أُجبر تحليل وتقرير app فقط في المتغيرين على التنفيذ الفعلي، مع إبقاء جميع القواعد والمكتبات والمستويات كما هي: انتهى خلال838.588 ثانية، Debug بلا أخطاء وRelease بخطأ Insights واحد، و133 تحذيرًا لكل متغير. أُغلقت PropertyEscape في المتغيرين؛ عطل LoginCredentialsPolicyDetector في Release محفوظ كما حدث، دون تعميم نتيجة Debug عليه. [XML والسجل وتنفيذ المهام الأربعة](evidence/policy-gate-20261015/fresh-app-lint/summary.json) هي المرجع. هذا الفحص يسبق قيد OkHttp اللاحق، فلا يُنسب إلى graph تغيّرت بعده.

الفرق الحقيقي بين134 و133 هو زوال تحذير UnusedResources لأيقونة الإشعار بعد keep المحدد؛ التحذيرات الأخرى متطابقة بعد تجاهل تغير رقم سطر desugar فقط. لا suppression أو baseline أو حذف قاعدة. عطل GLOBAL السابق في GradleDetector على مشروع Kotlin/Groovy مختلط مانع vendor مستقل محفوظ. يصف [Google الرسمي](https://developer.android.com/studio/publish/insights) Insights بأنه إرشاد مبكر لا يغطي كل السياسات ولا يصدر قرار المراجعة؛ الأداة ليست شرط نشر إلزاميًا من Google، لكن اكتمالها شرط داخلي P0 طلبه المالك، لذلك يبقى BLOCKED_VENDOR دون الادعاء بأن عطل الأداة نفسه مخالفة متجر.

## تصنيف التحذيرات

[الجرد التفصيلي](evidence/policy-gate-20261015/android-lint-warning-inventory.json) يحفظ رسالة كل تحذير وموضعه وبصمة XML. عمود SDK يشمل نسخ المكتبات المعدلة والمملوكة داخل build؛ وجودها محليًا لا يجعلها كود التطبيق. درجات الأثر أدناه تخص السلوك المثبت أو التحقق المطلوب، وليست تحويل كل توصية Lint إلى مخالفة متجر.

| النوع | BIL | SDK | الحكم والإجراء الأدنى |
|---|---:|---:|---|
| AndroidGradlePluginVersion |1|8| P2؛ توفر إصدار أحدث ليس شرط نشر. لا ترقية AGP عشوائية. |
| ApplySharedPref |0|7| P2؛ commit المتزامن في ترحيل secure storage قد يكون مقصودًا لضمان الترتيب. لا استبدال جماعي بـapply. |
| BatteryLife |0|1| فرع SDK لتجاهل تحسين البطارية؛ لا استعمال BIL مثبت له. افحص manifest المدمج قبل أي إضافة إذن. |
| ContentDescription |0|2| قوالب NativeAd في Google Mobile Ads؛ لم يُثبت استعمالها في BIL. يلزم فحص وصول إن فُعّلت، لا تعديل SDK غير المستعمل. |
| DiscouragedApi |0|3| getIdentifier في notifications؛ P1 تحقق الاحتفاظ بالأيقونة بعد R8، لا حكم بأن الأيقونة حُذفت دون فحص. |
| GradleDependency |2|14| اقتراح نسخ أحدث؛ افحص graph المحلول والثغرات، لا تعمم حداثة النسخة على سلامتها. |
| HardcodedText |0|2| نص Ad في قالب GMA؛ راجع فقط إن استُخدم القالب فعليًا. |
| HealthConnectPolicy |3|0| P0 أدلة متجر مطلوبة للأذونات المقصودة: steps/distance/active calories. ليست3 أذونات زائدة جديدة؛ تصريح Console ما زال منفصلًا. |
| IconLauncherShape |5|0| توصية تصميم P2؛ لا تغيير لهوية التطبيق المحمية بسبب التوصية وحدها. |
| IconLocation |1|0| PNG أحادي اللون؛ تحقق من كثافة العرض على الجهاز، دون استبدال الهوية افتراضيًا. |
| InlinedApi |0|1| ثابت SCHEDULE_EXACT_ALARM في permission_handler؛ ليس إثبات طلب BIL للإذن. |
| KotlinNullnessAnnotation |0|6| صيانة SDK؛ لا تغيير عقد المكتبة لتجميل التحذير. |
| NewerVersionAvailable |0|7|5 تبعيات اختبارات، وGson/Tink في runtime. Tink يستلزم الإصلاح الأمني أدناه؛ Gson الفعلي2.13.2 وليس النسخة المعلنة في ملف SDK وحده. |
| ObsoleteSdkInt |3|22| P2؛ شروط توافق قديمة، لا إزالة جماعية لفروع المكتبات أو الأصول المحمية. |
| RtlHardcoded |0|3| قالب GMA نفسه؛ تحقق إذا استُخدم. |
| RtlSymmetry |0|2| قالب GMA نفسه؛ لا إعادة تصميم تطبيق بسبب قالب غير مثبت الاستخدام. |
| ScopedStorage |2|0| السطران tools:node=remove في manifest المصدر؛ تحقق من المدمج، ولا تضف READ_MEDIA لمعالجة تحذير على سطر إزالة. |
| SwitchIntDef |0|1| فرع فئة ASSISTANT غير المطلوبة في مسار التطبيق المقروء. |
| UnusedAttribute |3|0| خصائص منصات أحدث مثل neverForLocation وlocaleConfig وback callback؛ حفظ التوافق، لا حذفها لتقليل العدد. |
| UnusedResources |6|12| لا حذف جماعي للسبلاش والأيقونات أو صور محمية. افحص الاستخدام الديناميكي ونتيجة المصغّر أولًا. |
| UnusedTranslation |1|0| alias إندونيسي in/id؛ تحقق locale فعلي قبل حذف ترجمة. |
| UseKtx |13|2| تحسين اختياري P2؛ لا حاجة لإعادة كتابة كود صحيح ضمن اعتماد المتاجر. |
| UseRequiresApi |0|1| فرع API22 تحت minSdk26 الحالي؛ صيانة SDK اختيارية. |

مرجع [Health Connect والنشر](https://developer.android.com/health-and-fitness/health-connect/publish)، [سياسة الصحة](https://support.google.com/googleplay/android-developer/answer/12991134?hl=en)، [متطلبات SDK](https://support.google.com/googleplay/android-developer/answer/13323374?hl=en)، و[تحسينات الخلفية](https://developer.android.com/topic/performance/background-optimization). موقع التحذير لا يحسم وحده انطباق السياسة؛ المصدر والـmanifest والسلوك والـConsole أدلة مختلفة.

## PG22 — Tink: مكوّن متأثر مثبت، واستغلال BIL غير مثبت

كان graph المحلول يحمل `tink-android:1.21.0`. [سجل CVE الصادر عن Google](https://raw.githubusercontent.com/CVEProject/cvelistV5/main/cves/2026/15xxx/CVE-2026-15432.json) و[بلاغ Tink الأصلي](https://github.com/tink-crypto/tink-java/issues/75) يثبتان CVE-2026-15432 في التحقق ChunkedMac، والإصلاح upstream هو [175df91](https://github.com/tink-crypto/tink-java/commit/175df91c54957225a16f5cb4b315d8e022563acf). هذه حالة P1 لمكوّن معروف التأثر، وليست ادعاء حصول تسريب أو إثبات oracle قابل للاستغلال في BIL.

فُحص bytecode الفعلي: النسخة القديمة تستدعي `util.Bytes.equals` المنتهي إلى `Arrays.equals`. يبدأ المسار الثابت الزمن في1.22.0 باستخدام `MessageDigest.isEqual`. تهيئة EncryptedSharedPreferences القديمة قد تسجل ChunkedMac عبر AeadConfig/MacConfig، لذلك لا يكفي الادعاء بأن مسار MAC غير موجود. في المقابل، تشفير مفاتيح وقيم ESP المقروء يستخدم AES256_SIV/AES256_GCM، وتخزين BIL الافتراضي يستعمل RSA-OAEP/AES-GCM عبر Android؛ هذا لا يثبت وحده انطباق ChunkedMacVerification على عملية تسجيل دخول فعلية.

الإصلاح الأدنى: dependency constraint في app يتطلب `tink-android:1.22.0` على الأقل. لا إضافة نسخة Tink ثانية، ولا force يمنع نسخة أعلى، ولا تغيير لخوارزميات التخزين أو مفاتيح مستخدمين أو حسابات حقيقية. يلزم إثبات graph المحلول والـJAR، وتوافق البيانات المصطنعة بين الإصدارين، ثم الاختبار الأصلي Android للـcrypto/secure cache. نجاح JVM لا يساوي نجاح Android Keystore أو ترحيل بيانات المستخدم الحقيقي.

اختبار التوافق عزل ست عمليات JVM واختبر البيانات العربية والإنجليزية والفارغة والثنائية، raw/encrypted keysets، AAD، رفض العبث، والاتجاهين: [936/936 ناجحة على graph الفعلية](evidence/policy-gate-20261015/native-dependency-security/tink-final-runtime-jvm.json)، وبصمة JAR1.22.0 مطابقة لـMaven. فحص bytecode يثبت استعمال الدالة المصححة؛ الاختبارات الوظيفية ليست قياسًا لثبات زمن التنفيذ. اختبار Android الأصلي وCI والحزمة النهائية أدلة منفصلة، ولا يُغلق البند اعتمادًا على declaration وحده.

## PG23 — مورد الإشعارات بعد التصغير

اسم `ic_stat_bil_notification` يُطلب ديناميكيًا من Dart وSDK. `isMinifyEnabled` و`isShrinkResources` مفعلان للإصدار. وفق [دليل Android الرسمي](https://developer.android.com/topic/performance/app-optimization/customize-which-resources-to-keep)، getIdentifier يحتاج مراجعة خاصة وقد يحتاج tools:keep؛ لا نضيف قاعدة keep دون التحقق من النتيجة الفعلية.

الفحص الفعلي كشف الحذف: `resources.txt` يسجل `drawable:ic_stat_bil_notification:2131230905 is not reachable`، وR.txt يثبت ID الأصلي0x7f0800b9، وaapt2 لا يجده داخل الناتج المحسن. هذا عيب P1 مثبت في ناتج المصدر المختبَر، لا حكم افتراضي على binary32 القديمة. [دليل ما قبل الإصلاح](evidence/policy-gate-20261015/notification-resource-retention/before.json) يحفظ بصمات الأرشيف والتقارير ومخرجات الفحص؛ الأرشيف وسيط QA برقم8، وليس حزمة Android33 موقعة.

أضيف `tools:keep` لهذا drawable وحده في `bil_notification_resource_keep.xml`، مع الحفاظ على الصورة والهوية والمحتوى. الفحص الدائم `bil_android_notification_resource.init.gradle` يقرأ الاسمين المطلوبين فعليًا من Dart، ويشغل `:app:optimizeReleaseResources` بعد R8 في AGP9.0.1، ويفحص مخرجات aapt2 الفعلية، ويمنع final APK/AAB packaging والتوقيع والتثبيت والنشر. نتيجة ما بعد الإصلاح تُثبت منفصلة؛ تجربة الإشعار على الحزمة الموقعة تبقى منفصلة عن هذا الفحص وعن4/4 QA runtime السابقة.

التشغيل الأول أنهى R8 وتحويل الموارد وتحسينها، ثم فشل جامع دليل QA الذي أضفناه عند طلب artifacts غير محددة النوع من مشاريع Flutter ذات secondary variants. لم يكن ذلك فشل تصغير أو كود مستخدم. حُفظ exit1 والسجل كاملًا؛ صُحح الجامع باستعمال resolutionResult للجرد وartifactView يحدد نوع JAR/AAR والمكونات الخارجية صراحةً. نجح الجامع الحقيقي، ونجح إثبات وجود المورد بعد keep. أُعيد الفحص المتأثر للموارد بعد تغيير OkHttp؛ نتيجته النهائية تحفظ منفصلة دون تحويل الفشل القديم إلى نجاح.

## PG24 — OkHttp التابعة لـML Kit Translate

مسح OSV القرائي لجميع218 مكوّن Maven محلولًا وجد OkHttp3.0.0 وحدها مطابقة لبلاغي CVE-2021-0341 وCVE-2016-2402. ملف POM الرسمي لـtranslate17.0.3 يطلب3.0.0، ومسار الترجمة المحلي في BIL يستعمل Translation.getClient. هذا إثبات مكوّن قديم، وليس إثبات استغلال بيانات BIL. يؤكد [سجل Square](https://raw.githubusercontent.com/square/okhttp/master/docs/changelogs/changelog_4x.md) إصلاح التحقق المباشر من أسماء مضيفين غير ASCII في4.9.2، مع شروط استغلال أضيق من مجرد وجود SDK.

أضيف minimum constraint4.9.2 دون force أو ترقية ML Kit أو تغيير غرض جمع البيانات. هذا أصغر إصدار إصلاح جرى التحقق منه بين4.9.2 و4.12.0؛ بقي Okio3.4.0 وKotlin stdlib2.3.20 كما حُلّا فعلًا، بينما4.12.0 كان سيرفع Okio إلى3.6.0 بلا حاجة للإصلاح المقصود. Kotlin stdlib ليست إصدار Gradle Kotlin plugin.

[الاختبار على graph النهائية الفعلية](evidence/policy-gate-20261015/native-dependency-security/okhttp-final-runtime-jvm.json) أعاد فشلي Kelvin host/SAN في3.0.0، ثم نجح4.9.2 في75 تحقق ربط لصفوف الرموز32 و21 تحققًا وظيفيًا دون فشل. AAR الترجمة وJAR المرشح وOkio/Kotlin فُحصت ببصماتها الحقيقية. اختبارات CertificatePinner وظيفية، ولا تدّعي إعادة هجوم سلسلة شهادات2016 أو تشغيل طلب ترجمة أو TLS حي أو Android ART.

[إعادة الاستعلام عن graph النهائية](evidence/policy-gate-20261015/native-dependency-security/osv-after-okhttp-fix.json) لم تجد بلاغًا مطابقًا بين218 مكوّنًا في تاريخ الفحص. لا يثبت غياب كل الثغرات أو سلامة المكتبات الأصلية أو سلوك الحزمة الموقعة. النتائج القديمة والبلاغان محفوظة، ولا تُرفع مفاتيح أو JARs أو بيانات مستخدمين مع الأدلة.
