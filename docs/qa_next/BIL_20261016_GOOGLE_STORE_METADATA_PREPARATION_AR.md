> تحديث16أكتوبر2026 لاحق: وجد حسابGoogleالمخصص حيًا فيAuth باسم `google-play-review-20261004@bilhealth.com`، معPremium/AI فعالين. هو الحساب المقصود لتجهيزGoogle، بينماASC يستعمل `play-review@bilhealth.com`. ما زالت قيمةAppAccess الحالية غير مقروءة. وحّد المالك وصولهما معحسابهالشخصيdr.kadem، معبقاءAdminللـkademcom وbilhealth.appفقط؛ [التنفيذوالإثبات](BIL_20261016_REVIEW_AND_OWNER_TEST_ACCOUNTS_ALIGNMENT_AR.md).

# تجهيز بيانات Google Play — 16 أكتوبر 2026

**النتيجة: تجهيز محلي قابل للمراجعة؛ لم تُحفظ إجابات Google Play.** تفويض المالك الحالي يشمل تجهيز وتصحيح بيانات المتاجر وترحيلات Production المطلوبة، مع التوقف قبل إضافة builds. لا يشمل إرسال Appeal أو رفع/إضافة build أو تغيير الأسعار/Trial أو أدوار وأرصدة غير مرتبطة. حظر الكتابة الحالي في Google سببه Console المعلّقة، وليس طلب موافقة إضافية من المالك.

## المصدر والدليل الحالي

- worktree: `G:/BIL_Project/worktrees/bil-ios36-audit-snapshot-20261014`.
- الفرع المقروء: `integration/bil-qa-media-policy-20261011`؛ HEAD: `ed963053c62cc549cbe50757279bd39d73a10e35`.
- worktree غير نظيفة؛ حُفظت التغييرات القائمة. الشاملة التي يديرها الوكيل الرئيسي قيد التشغيل أثناء إعداد هذا الملف. لم يشغّل كاتب هذا الملف اختبارًا أو build أو CI، ولم يغيّر implementation أو tests أو config أو Goldens أو migrations أو workflows.
- [إيصال التفويض والقراءة الحية](evidence/policy-gate-20261015/production-20261016/owner-authorization-and-google-ui.json) يسجل قراءة الوكيل الرئيسي في **15 أكتوبر 2026، 22:39 UTC بدقة الدقيقة**، وتسجيل الإيصال في 22:45 UTC. هذه قراءة الوكيل الرئيسي؛ لم يفتح كاتب الملف متصفحًا أو Console.

| البند | المثبت الآن | الأثر العملي |
|---|---|---|
| التطبيق | `com.bilhealth.bodyintelligencelog`؛ developer `7540824385820504578`؛ app `4974243137795319021` | كل إجراء مستقبلي يجب أن يخص هذا التطبيق نفسه. |
| الحالة | `App suspended`؛ الوقت المعروض `8 Oct 2026, 22:38`؛ إزالة كل النسخ السابقة ظاهرة | لا نحول الوقت المعروض إلى UTC دون منطقة زمنية مثبتة. المصدر الجديد لا يغير binary 32. |
| القضية | `4976804875812644073` | لا يُتبع رابط تذييل بريد يحمل هوية تطبيق أخرى. |
| App content | `disabled_attribute=true`، و`aria_disabled="false"`، والأب يحمل `disabled`؛ الضغط لم يغير الصفحة | الخاصية الفعلية ونتيجة التنقل تثبتان الحجب. لا تعدّ aria وحدها إذنًا للكتابة. |
| App Access / Data Safety / التصريحات | الإجابات الحية الحالية غير مقروءة | لا نخترع before/after ولا نكتب أن القيم الحالية صحيحة أو خاطئة. |
| API | أفاد الوكيل الرئيسي أن الأداة الموجودة تتطلب مسار service account موثقًا غير متاح؛ `GOOGLE_APPLICATION_CREDENTIALS` غير موجود | لا بحث واسع في مجلدات الأسرار، ولا إنشاء مفتاح، ولا التفاف على المسار المعطّل. |
| Appeal | الزر ظاهر؛ لم يُفتح أو يرسل في هذه القراءة؛ السجل المستقل لإرسال سابق غير مؤكد | لا إرسال أو إعادة إرسال ضمن هذا التفويض. |
| Android 33 | لا AAB موقع، ولا clean-install للحساب الحقيقي على حزمة 33 | كل نص عن نجاح الوصول أو توافق release يبقى مشروطًا. |
| Production | الإيصال هو تفويض/readback قبل النشر فقط | ينسب أي نشر لاحق إلى إيصال before/after مستقل يديره الوكيل الرئيسي؛ لا يسجل هذا الملف النشر منجزًا. |

المراجع المحلية المقروءة: [ملف Google الأحدث](BIL_20261014_GOOGLE_APPEAL_EVIDENCE_AR.md)، [نصوص المتاجر التاريخية](BIL_20261011_STORE_REVIEW_TEXTS_AND_TIMING_AR_EN.md)، [ملحق Google والسياسات](BIL_20261015_POLICY_GATE_APPENDIX_GOOGLE_AR.md)، [ملحق الوصول والخصوصية](BIL_20261015_POLICY_GATE_APPENDIX_ACCESS_PRIVACY_AR.md)، [المطابقة الرباعية](BIL_20261015_APP_PRIVACY_FOUR_WAY_RECONCILIATION_AR.md)، و[خريطة فروق 4 أكتوبر](../release/BIL_STORE_METADATA_DELTA_MAP_2026-10-04.md). نتائج iOS وASC في المطابقة الرباعية لا تنقل آليًا إلى إجابات Android.

## App Access: المسار الصحيح والنص الإنجليزي

المسار المثبت من المصدر الحالي:

1. شاشة الحساب → **Sign in**.
2. شاشة Sign in → **Store reviewer access**.
3. إدخال **Email address** و**Password** → **Sign in**.

التسجيل العادي بالبريد في `premium_login_page.dart:52` يرسل OTP؛ رابط `Store reviewer access` في السطر 410 يفتح `/reviewer-login`. شاشة `login_page.dart:14` تستخدم تسجيل Supabase العادي بالبريد وكلمة المرور وتنتقل إلى `/startup`؛ ليست hardcoded identity أو تجاوزًا للاستحقاق. زر الإرسال في السطر 251 يحمل **Sign in**. شاشة الحساب الفعلية مصدرة من `premium_account_gateway_page.dart`، فلا تُنسخ عبارة **Sign in or create account** من الصفحة القديمة غير المستخدمة.

**تصحيح هوية الحساب بناءً على توضيح المالك:** `dr.kadem.nana@gmail.com` و`bilhealth.app@gmail.com` حسابا اختبار شخصيان، وليسا حسابي مراجعة متجر. تُسحب نسبة دور Store Reviewer إليهما وأي مفاضلة سابقة بين Reviewer-R1 وReviewer-R2 لهذا الغرض؛ لا يغيّر هذا التصحيح أدوارًا أو استحقاقات حية.

الحساب المخصص الذي وجده الوكيل الرئيسي في قراءة ASC الحية هو `play-review@bilhealth.com`، وتطابقه وثيقة Apple الأصلية. ملف `docs/release/BIL_EPIC15_PLATFORM_METADATA.json` يشير إليه أيضًا في `google_play.app_access`، لكن ذلك **دليل Play تاريخي محلي فقط، وليس قراءة لإعداد Google الحالي**. لا توجد قراءة حالية لهوية حساب App Access في Google Play؛ التعليق ما زال يحجب الصفحة. قراءة ASC لا تثبت وحدها الهوية المحفوظة في Play أو نجاح تسجيل الدخول والاستحقاق على الحزمة المقدمة.

المسودة الإنجليزية المفصلة في [ملف App Access](BIL_20261016_GOOGLE_APP_ACCESS_DRAFT_EN.md) تستخدم placeholders لحقول الحساب المخصص الآمنة فقط. لا توجد كلمات مرور أو رموز دخول فيه. تُدخل بيانات الحساب المخصص داخل حقول Console الآمنة بعد التحقق الفعلي؛ لا تُستخدم الحسابات الشخصية بدلًا منه، ولا تُنسب البيانات التاريخية إلى Console الحالية.

قبل تحويل المسودة إلى حقائق جاهزة للحفظ:

- تجربة هوية الحساب، الجلسة، استحقاق المزايا، رصيد Coach/Vision، والسطح الظاهر فعليًا بصورة مستقلة، على النسخة المقصودة من تثبيت نظيف ثم إعادة فتح. بيانات دخول قابلة لإعادة الاستخدام من أي بلد وبلا OTP/2FA مانع، وبلا انتهاء أثناء المراجعة.
- فحص **More → Goals → Additional Nutrient Goals** و**Calorie Goals By Meal**، مع الرجوع داخل التطبيق. النصوص الفعلية موجودة في `reference_goals_page.dart:612`؛ تظهر الأبواب الصحيحة للحساب المؤهل، ولا يستبدل تأخر الخادم بحكم Free أو تحويل خاطئ إلى Plans.
- فحص Coach/صورة الوجبة دون شراء أو بطاقة أو دعوة أو نشر بالمجتمع لكسب رصيد. لا يثبت grant في الخادم وحده وصول الواجهة، ولا تضمن اختبارات تركيبية رصيد الحساب الحقيقي.
- تحديد ترتيب آمن ومعلن لفحص الإدارة/الإشراف إن احتاجته المراجعة. وصول المستهلك لا يمنح Financial Admin؛ لا يقال إن كل الوظائف متاحة إن بقي سطح مطلوب غير قابل للفحص. فحص الحذف أو الشراء/الاسترداد يكون بحساب اختبار مخصص يحافظ على الحساب الأساسي القابل لإعادة الاستخدام.
- مطابقة أسماء وخطوات المسودة مع binary المقدمة. هذه المسودة توافق **المصدر الحالي**، ولا تثبت أن build 32 تعرض المسار نفسه أو أن 33 موجودة.

أُعيدت قراءة [متطلبات Google لدخول المراجع](https://support.google.com/googleplay/android-developer/answer/15748846?hl=en) في 16 أكتوبر 2026: بيانات إنجليزية مستمرة وقابلة لإعادة الاستخدام ومن كل المواقع، مع وصول كامل إلى الوظائف المقيدة دون دفع. هذه متطلبات، وليست شهادة بنجاح الحساب.

## الروابط القانونية وصدق الوصف

| الحقل أو الاستخدام | القيمة المعدّة | ما تحقق وما بقي |
|---|---|---|
| Privacy policy في Play | `https://www.bilhealth.com/privacy` | القيمة الافتراضية في `store_catalog_configuration.dart:21`، وهي نفسها في `android/app/src/main/res/values/strings.xml:7` التي يفتحها Health Connect rationale. قرئت علنًا عبر أداة الويب اليوم. |
| Terms of Service | `https://www.bilhealth.com/terms` | القيمة الافتراضية في `store_catalog_configuration.dart:17`. قرئت علنًا اليوم؛ مراجعة build-defines النهائية مستقلة عن default المصدر. |
| Account deletion URL | `https://www.bilhealth.com/account-deletion` | قرئت علنًا اليوم؛ تعرض طلب الحذف داخل التطبيق وطريق مراسلة الخصوصية من عنوان الحساب عند تعذر الدخول، دون اشتراط العودة للتطبيق. لا يثبت ذلك اكتمال حذف حي أو تشغيل العامل. |
| Support / privacy contact | `support@bilhealth.com` / `privacy@bilhealth.com` | ظاهران في الصفحات العامة وفي قانون التطبيق. لا يتغير الاسم القانوني أو عنوان المطور بتخمين. |

أظهرت قراءة الويب للروابط الثلاثة نص fallback قانونيًا واحدًا قابلًا للقراءة دون JavaScript، مؤرخًا **4 October 2026**، باسم BIL. يذكر Google Gemini للطلب الاختياري، والإعلانات السياقية للبالغ Free الموافق عليه عبر UMP، ومسار **More → Help → Delete Account**. هذه قراءة محتوى عام، وليست فحصًا للواجهة التفاعلية أو جميع المناطق أو دليل HTTP status محفوظًا. لم يُكتب أو ينشر شيء في الموقع.

لا يوجد من هذه القراءة فرق يبرر استبدال الروابط الثلاثة. يحتاج الوكيل الرئيسي فقط إلى قراءة القيمة الفعلية حين تعود حقول المتجر متاحة، ثم حفظ الفرق المؤكد وإعادة قراءته. لا نضيف رابط Community مخمنًا أو نخلط رابط subscriptions مع account deletion.

مقطع وصف إنجليزي مقترح عند الحاجة لتصحيح فرق مثبت في listing:

> BIL is an adult wellness logging tool for nutrition, activity and personal trends. It is not a medical device and does not diagnose, treat or replace professional medical advice. Connected readings depend on compatible hardware, supported platform services and permissions. AI features process the information you choose to send after consent; their output is informational and may be inaccurate.

ليس هذا استبدالًا للوصف الحالي غير المقروء. لا تُضاف ادعاءات قياس قلب/سكر أو تشخيص أو دقة سريرية، ولا صور لميزات لا تثبتها النسخة المقدمة. صور build أخرى ونتائج Goldens لا تثبت تطابق listing مع binary 32.

## Health Apps وHealth Connect

Manifest المصدر في `android/app/src/main/AndroidManifest.xml:70` يطلب ثلاثة أذونات قراءة فقط. `BILGlobalHealthBridge.kt:99` يجمع المقاييس المسموح بها؛ السطر 88 يحدد `foreground-refresh-only`، ومسار الكتابة يرفضها. لا نعلن background أو write أو Sleep/BodyFat/RestingHeartRate من Health Connect.

| نوع Health Connect | تبرير إنجليزي معدّ من الاستخدام الحالي |
|---|---|
| Steps — `READ_STEPS` | BIL reads step totals from Health Connect to display the user's activity summary and step history. Access is read-only and refreshes while BIL is in use. Users can grant, deny or revoke this permission in Health Connect settings. |
| Distance — `READ_DISTANCE` | BIL reads activity distance from Health Connect to display distance alongside the user's activity summary. Access is read-only and refreshes while BIL is in use. Users can grant, deny or revoke this permission in Health Connect settings. |
| Active calories — `READ_ACTIVE_CALORIES_BURNED` | BIL reads active calories from Health Connect to display active energy in the user's activity summary. Access is read-only and refreshes while BIL is in use. Users can grant, deny or revoke this permission in Health Connect settings. |

هذه مسودات تبرير، وليست إجابات محفوظة. تظل مطابقة merged release manifest وواجهة الإذن والحزمة النهائية خطوة منفصلة عند توفر build. الأنواع الثلاثة المرفوضة تاريخيًا **BodyFat / RestingHeartRate / SleepSession** غائبة عن Manifest المصدر المقروء؛ ذلك لا يغير binary 13 أو 32.

Health Apps declaration أوسع من أذونات Health Connect: المنتج يحتوي Activity/Fitness وNutrition/Weight، وشاشة Sleep المحلية موجودة في More. تُراجع الفئات الفعلية المعروضة في النموذج والمنتج؛ لا يعني Sleep في المنتج طلب SleepSession من Health Connect، ولا تختار Medical/Research دون وظيفة تنطبق عليها. لا نخترع اختيارًا حاليًا للنموذج غير المقروء.

أُعيدت قراءة [دليل نشر تطبيق Health Connect](https://developer.android.com/health-and-fitness/health-connect/publish) في 16 أكتوبر 2026: Data Safety وHealth Apps وتبرير كل نوع مستخدم، مع أقل صلاحيات والسياسة نفسها في Play وفي شاشة Health Connect. المصدر يحدد المطلوب؛ الحزمة والمتجر يثبتان المطابقة.

## Data Safety والإعلانات: خريطة تعديلات جاهزة للمقارنة

### نسخ SDK وإعداد المصدر الحالي

| الطبقة | القراءة الحالية | حد الدليل |
|---|---|---|
| Flutter Ads | `google_mobile_ads 9.1.0` في `pubspec.lock:695` | ليس جرد AAB. |
| Android Ads / UMP | override المثبت في `.dart_tool/bil-android-policy-overrides/google_mobile_ads-9.1.0/android/build.gradle:71`: GMA `25.4.0`؛ UMP `4.0.0` في السطر 73 | لا يُستبدل بإصدار iOS؛ graph release النهائي غير متاح. |
| الشراء | `in_app_purchase_android 0.5.2`؛ المكتبة المثبتة تعتمد Billing `8.0.0` | لا تثبت توفر SKU أو base plan أو شراء Play ناجحًا. |
| إعلانات الإصدار | `.github/workflows/bil_android_release_candidate.yml:135` و`:230` تضبط `BIL_ADS_ENABLED=true` | لا تستخدم QA ذات الإعلانات المعطّلة لإجابة release. |
| المعرّفات | المصدر يزيل AD_ID وAdServices ID/Topics/Attribution/Custom Audience من manifest merge | لا يعني ذلك غياب app set ID أو كل بيانات SDK، ولا يغني عن merged manifest. |

دليل [Google Mobile Ads Android Data Disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure) المقروء اليوم يصف **Legacy SDK 25.5.0**، وتاريخ تحديث الصفحة **2026-10-15 UTC**. يذكر نقل IP والتفاعل والتشخيص والمعرّفات للإعلانات والتحليل ومنع الاحتيال. BIL يحل حاليًا 25.4.0؛ لذلك يستخدم الجدول baseline مزود للمقارنة، لا شهادة تطابق للحزمة أو كل الخيارات. NPA وإزالة AD_ID لا تعنيان عدم جمع البيانات أو مشاركتها.

### فروق 4 أكتوبر التاريخية التي يعاد فحصها عندما تسمح Console

خريطة 4 أكتوبر سجلت آنذاك Approximate location غير محددة، وغياب أغراض إعلانية عن App interactions/Diagnostics/IDs، وعبارة No data shared. لا نعرف هل بقيت هذه القيم اليوم؛ توثيقها هنا لا يحولها إلى قراءة حالية.

| الحقل | القيمة المعدّة للمقارنة مع تشغيل Ads الفعلي | قبل الحفظ |
|---|---|---|
| Approximate location | معالجة IP-derived approximate location الخاصة بـAdMob: collected + shared، وأغراض Advertising or marketing / Analytics / Fraud prevention, security, and compliance حيث يثبت انطباقها | لا تضف Precise location من دليل IP وحده. Optional/Required غير محسوم. |
| App interactions | تغطية جمع ومشاركة تفاعل SDK للأغراض الثلاثة السابقة مع حفظ أغراض BIL الصحيحة | مطابقة التشغيل وgraph، وعدم نسب Health/UGC إلى الإعلان. |
| Diagnostics | تغطية تشخيص SDK والأغراض الثلاثة السابقة | لا تضف Crash logs أو Other app performance لمجرد manifest iOS؛ subtype Android يحتاج منتجه. |
| Device or other IDs | تغطية معرّفات SDK الفعلية وجمعها ومشاركتها وأغراضها، ولو غاب AD_ID | لا تعدّ إزالة إذن AD_ID نفيًا لكل IDs، ولا تغير حقول Advertising ID الحية غير المقروءة بتخمين. |
| Overall sharing / Contains ads | مسار release المفعّل للإعلانات يحتاج إقرار Ads وإجابات sharing متسقة مع ما يعمل | لا تنسخ No data shared اعتمادًا على RLS أو NPA. لا يثبت هذا الملف الإجابة الحالية. |
| Ephemeral / Optional / Required | تبقى غير محسومة دون lifecycle/retention/اختيار فعلي لجميع المستخدمين المعنيين | لا CSV import كامل ولا اختيار radio افتراضي لسد الفراغ. |

### بيانات BIL التي لا تختزل في إعلان SDK

| التدفق الفعلي المقروء في الوثائق/المصدر | المراجعة المطلوبة في Data Safety |
|---|---|
| Auth وربط الحساب/السجلات/الاستحقاق | معرفات الحساب والبريد والحقول المرسلة فعلًا؛ App functionality/Account management والأمن حيث ينطبق. لا تضف رقم هاتف بلا producer فعلي. |
| selected cloud sync وHealth/Fitness context | تمييز البيانات المحلية التي لا تغادر عن البيانات المرسلة للمزامنة أو سياق AI المأذون؛ لا تنسب الإعلان للصحة. |
| AI Coach وMeal Photo | النص/السياق والصورة المختارة عبر backend إلى Google Gemini بعد الموافقة؛ لا تدع zero retention أو exemption من sharing دون الشروط الفعلية. |
| Voice | BIL/Gemini يستقبل transcript في المسار المراجع؛ system SpeechRecognizer قد يعالج الصوت خارجيًا. سلوك خدمة Android الفعلية غير محسوم، فلا تدع local-only أو جمع صوت خام بواسطة BIL بلا دليل. |
| Community ومراسلة ودعم وصور/علاقات | تصنيف المحتوى والملكية والمشاركة حسب التدفق الفعلي؛ Contacts إن انطبق يكون social graph لا إذن دفتر عناوين مخترعًا. لا تنسخ اسم نوع Apple حرفيًا إلى نوع Play مختلف. |
| food remote search | طلب بحث مصادق عليه إلى gateway/USDA عند الحاجة؛ checkbox ephemeral القديم لا يثبت حذف logs. |
| شراء/تحقق/Integrity/notifications | purchase history ومعرّفات تقنية/أمنية حسب المنتج؛ وجود FCM لا يثبت Firebase Analytics أو Crashlytics. |
| الحذف والتشفير | ربط النموذج بمسار طلب/إتمام الحذف واستثناءات الاحتفاظ الفعلية؛ التشغيل المحلي أو تصريح HTTPS وحده ليس إثباتًا لكل خدمة. |

لا يوجد في هذه القراءة نموذج Data Safety حالي كامل أو CSV جديد، ولذلك لا ننتج ملف import يدعي الاكتمال. عند فتح Console، يقرأ الوكيل الرئيسي الحقول الفعلية مرة واحدة، ويطبق الفروق المؤكدة فقط، ويحفظ readback يميز القيم التي ثبتت عن الباقي المجهول.

## ما ينفذ الآن وما يتوقف عند build

| التوقيت | الإجراء والحالة |
|---|---|
| الآن — منجز هنا | قراءة المصدر/الوثائق والروابط الرسمية والعامة، وتجهيز App Access والروابط والتبريرات وخريطة Data Safety. لم تتغير حقول متجر أو production بهذا العمل. |
| الآن — الوكيل الرئيسي | إكمال ترحيلات Production المطلوبة وفق فحص التوافق وإيصال before/after مستقل. لا تعتبر ترحيلًا معتمدًا لمجرد وجوده محليًا، ولا تجاوز HOLD موثق لفروق الإنتاج. |
| الآن — Google UI | التعديلات مأذونة لكن App content والتصريحات محجوبة فعليًا بالتعليق؛ لا تكرار نقر أو محاولة API بمفاتيح مخمنة. تسجيل هذا القيد يغلق محاولة الإعداد الحالية بوضوح. |
| عند عودة الحقول أو فتح مسار رسمي | قراءة القيم الفعلية، مقارنة هذه المسودات، حفظ الفروق القابلة للإثبات، ثم إعادة قراءة ما حُفظ. إذا بقيت optionality أو بيانات SDK مجهولة فلا تحوّلها إلى إجابة قطعية. |
| بعد إذن بناء مستقل | ربط AAB33 وتوقيعه/binary hash وmerged manifest وSDK graph بالنسخة نفسها، وتجربة الحساب الحقيقي باردًا ودافئًا، ورحلة المراجع والأذونات والخدمات وPlay products حيث يسمح التعليق. |
| حد التوقف الحالي | لا إضافة/رفع build، ولا إرسال للمراجعة أو نشر أو Appeal. لا يغير تجهيز المتجر binary 32، ولا يثبت عودة التطبيق للمتجر. |

الحد العملي ليس انتظار Polish أو إعادة اختبارات لا تغير الإجابة. المتبقي محدد: Console محجوبة، وإجاباتها الحالية غير مقروءة، وحساب/حزمة المراجعة الدقيقة غير مجرّبين، وإيصالات Production اللاحقة منفصلة. تُحدّث الحالة بهذه الأدلة عند وجودها بدل ادعاء اكتمالها الآن.
