# تدقيق المتاجر والسياسات والدومين — BIL

تاريخ التدقيق: 10 سبتمبر 2026، Africa/Cairo. نُفذت القراءات خلال مساء 9 سبتمبر UTC / فجر 10 سبتمبر القاهرة. هذه لقطة حالة وليست شهادة امتثال أو إذن نشر.

**آخر تحديث DSA — 10 سبتمبر، 03:19 القاهرة:** بعد طلب Kim عند 02:21، وضّح المالك الرقم البديل والشبكتين ووافق صراحة على الإرسال. أُرسل رد واحد بهذه التفاصيل وتحقق ظهوره في السلسلة. قسم 11 يوثق النتيجة؛ المطلوب الآن انتظار تحديث Apple، دون ادعاء اكتمال التحقق.

النطاق: App Store Connect، Google Play، السياسات العامة على `www.bilhealth.com`، مقارنتها بالكود الحالي، metadata خدمة حذف الحساب في Supabase، ثم أحدث مراسلات Apple بخصوص DSA والتحقق من الهاتف بناءً على الطلب الإضافي الصريح.

المصدر المحلي: `G:/BIL_Project/worktrees/bil-unified-release-20260909`، الفرع `codex/bil-unified-release-20260909`، HEAD وقت بدء التدقيق `8d48db48a9b8b5c59b6c10e8a26868bf590de13f` مع تغييرات محلية قائمة. الكود المحلي ليس تلقائيًا نفس binary المرفوع للمتجر.

## إغلاق المهمة وتحديث البريد المصرح به

بعد انتهاء القراءات، أذن المستخدم صراحة بإرسال توضيح إلى Apple ثم إغلاق المهمة. **أُرسل الرد مرة واحدة** عبر Reply لآخر رسالة Kim، إلى المستلم المرئي `eurodev@apple.com`، في سلسلة القضية نفسها، دون Reply all أو مستلم إضافي أو مرفقات. أظهر Gmail **Message sent** ثم ظهرت الرسالة بالنص المعتمد داخل السلسلة بتاريخ **10 سبتمبر 2026، 01:36 بتوقيت القاهرة المعروض في Gmail**. لم يُعد الإرسال.

أفاد الرد، بناءً على كلام المستخدم، بأن شركة الاتصال أكدت عدم وجود مشكلة من جانبها، وأن تجربة تغيير رقم التحقق لم تحل المشكلة، وأن كود البريد يصل بينما كود الهاتف لا يصل. طُلب ضم هذه المعلومات إلى القضية المصعّدة للهندسة وتوضيح أي إجراء إضافي مطلوب. لم يغيّر الوكيل رقمًا ولم يطلب رمز تحقق. **هذا البريد هو التغيير الخارجي الوحيد الذي فُوّض لاحقًا ونُفذ**؛ باقي التدقيق كان للقراءة فقط.

**القرار الآن: انتظار رد Apple على التحديث المرسل.** خطوة فحص شركة الاتصال التي ذكرتها الرسالة السابقة أبلغ المستخدم أنه أنجزها؛ لا يوصي هذا التقرير بإعادتها الآن، أو بتغيير الهاتف مجددًا، أو بإعادة تقديم DSA من الصفر. لم يصل رد جديد من Apple ضمن نافذة إثبات الإرسال، ولم تُنشأ متابعة تلقائية. توقف البحث والعمل الإضافي بناءً على الطلب.

## الخلاصة العربية

- **DSA: انتظر تحديث فريق هندسة Apple بعد الرد المرسل اليوم.** آخر رد بشري من Kim يؤكد استلام المعلومات والتصعيد. أُبلغوا الآن بأن فحص شركة الاتصال وتجربة رقم آخر لم يحلا المشكلة. لا قبول نهائي ولا رفض ولا موعد إنجاز محدد. لا تعِد تقديم الطلب أو تغيّر الهاتف لمجرد ظهور التنبيه.
- **Apple ليس منشورًا للعامة:** الإصدار 1.0.0 والمنتجات الخمسة في حالة `Developer Rejected`، وآخر طلبات المراجعة `Removed`. هذا لا يثبت رفضًا من Apple بسبب سياسة. Build 12 مرفوع ومعالج، لا يعادل الموافقة أو النشر.
- **Google ليس في الإنتاج العام:** الإنتاج `Inactive` وطلب الوصول إلى Production قيد المراجعة. الاختبار المغلق Alpha نشط على build 8. عبارة «نُشر تحديث» في الإشعارات لا تثبت Production.
- **الخصوصية الأساسية مُصرّح بها:** Apple ينشر 17 نوعًا مرتبطًا بالحساب. Google لديه 16 نوعًا محددًا في النموذج، وإفصاح الحذف والتشفير؛ Health Apps مكتمل، وPolicy Status يعرض `No issues found`.
- **الكتالوج متوافق في المعرفات:** أربعة اشتراكات وBoost واحد في المتجرين. فصل Premium الإقليمي عن AI مقصود وموجود فعليًا. تجربتا AI على Apple لمدة أسبوع، وGoogle يعرض عرض `trial-7-day`.
- **الدومين يعمل والسياسات الحالية تطابق ملف الموقع المحلي.** لا دليل في هذا التدقيق على رابط سياسة معطل. الحذف لديه Edge Function وجدولة فعّالة، لكن نجاح حذف حساب وملفاته من البداية للنهاية لم يُختبر.
- **صُحّح جرد الخصوصية المحلي بعد التدقيق** ليتوافق وصف نشر عامل الحذف وحفظ توكنات Apple مع المصدر الحالي وmetadata الحية، مع إبقاء اختبار الحذف الفعلي غير مثبت. تبقى ملاحظة مراجعة Apple بحاجة إلى مواءمة قبل الإصدار التالي: عبارة HealthKit `import-only` لا تصف تصدير الوزن الاختياري الموجود في الكود الحالي.

## طريقة التصنيف وحدود العمل

| التصنيف | المقصود |
| --- | --- |
| مثبت حيًا | قُرئ من واجهة المتجر/البريد/الموقع أو metadata الخدمة أثناء هذا التدقيق |
| تعارض مؤكد | عبارتان/حالتان مفحوستان لا تتطابقان، مع تحديد هل التعارض وثائقي أم في binary |
| خطر/يحتاج تحققًا | احتمال أو فجوة دليل؛ ليس حكمًا بأن الميزة معطلة |
| غير مفحوص | لم تُقرأ التفاصيل أو لم تُنفذ التجربة؛ لا يُسمّى نقصًا في المتجر |

لم تُغيّر إعدادات أو منتجات أو أسعار أو صلاحيات أو هويات أو سياسات أو DNS. لم تُرسل مراجعة أو إصدار، ولم تُنفذ عملية شراء/منح/تعويض/حذف حساب. أُرسل فقط رد DSA المصرح به لاحقًا كما وثق قسم الإغلاق. لم تُقرأ بيانات صحية أو رسائل Community لأشخاص. اكتُفي في البريد بسلسلة DSA ذات الصلة. لم تُفتح روابط تحقق إجرائية ولم يُطلب OTP. لم تُفتح مرفقات البريد المصورة أو تُلتقط صور إضافية بعد إيقاف المستخدم للفحص البصري.

نُقلت صفحات إقرارات Google بين خطوات القراءة دون تغيير إجابات أو حفظ؛ عند تحذير الخروج من معالج الجمهور جرى الخروج وإلغاء حالة المعاينة غير المحفوظة فقط. لم تُنشأ حسابات Sandbox. لا Flutter أو بناء أو اختبارات نفذها هذا الوكيل. فحوص التطبيق التي يجريها الوكيل الرئيسي منفصلة عن جاهزية المتاجر.

## 1. DSA والتحقق من الهاتف: القرار الحالي من البريد

### آخر قرار فعلي

السلسلة: [Developer Support — القضية 20000151571917](https://mail.google.com/mail/u/0/#search/DSA+newer_than%3A30d/FMfcgzQhWLGwSsTGGPNwlCsnpsQXPSNt)، في حساب البريد المفتوح الخاص بـ BIL.

آخر رد **بشري**: Kim، Developer Support، من `eurodev@apple.com`.

- رأس الرسالة الأصلي: **Wed, 09 Sep 2026 07:36:33 +0000 (UTC)**.
- المقابل بالقاهرة: **9 سبتمبر 2026، 10:36:33 صباحًا، UTC+3**.
- Gmail يعرض 10:36؛ فحص الأصل أظهر SPF وDKIM وDMARC ناجحة لـ Apple. هذا تحقق من المصدر وليس حكمًا تقنيًا على سبب فشل الهاتف.
- أكد استلام المعلومات المطلوبة، وأن القضية صُعّدت إلى فريق الهندسة الداخلي للتحقيق، وأنهم سيعودون عند وجود تحديث.
- طلب التواصل مع شركة الاتصال **إذا كانت تحجب الرسائل أو المكالمات من نظام Apple**. لم يقل إن شركة الاتصال ثبت أنها السبب.
- لا طلب وثيقة جديدة في آخر رد، ولا طلب إعادة إرسال DSA، ولا موافقة على تجاوز التحقق أو تحقق يدوي مكتمل، ولا مدة/SLA محددة.

البحث الحي قبل إرسال الرد المصرح به شمل `in:anywhere` منذ 8 سبتمبر، مراسلات Apple الواردة والصادرة، كلمات DSA / Digital Services Act / trader / phone verification ورقم القضية. أعاد سلسلة واحدة من **7 رسائل**؛ لم يظهر رد أحدث من Apple. ثم أُضيف رد المستخدم المصرح به كما وثق قسم الإغلاق. لا يعني ذلك أن كل بريد آخر بالحساب دُقق، وإنما أحدث المطابقات للقضية.

### التسلسل الزمني

الأوقات الأقدم التالية كما عرضها Gmail؛ لم تُفحص رؤوسها الخام منفردة. المنطقة الزمنية ثُبتت من الرأس الخام لآخر رسالة فقط. لا ينبغي الخلط بين أوقات الاقتباسات داخل الرسائل وبين وقت إرسال الرسالة نفسها.

| التاريخ والوقت المعروض | المرسل | مضمون الإجراء/القرار |
| --- | --- | --- |
| 1 سبتمبر، 19:42 | John / Apple | إرشادات عامة لاستكمال DSA وطرق استقبال الكود؛ ليست موافقة على تحقق يدوي |
| 1 سبتمبر، 19:49 | صاحب الحساب | أوضح أن التحقق بالبريد نجح، لكن SMS والمكالمة لا يصلان، وطلب التصعيد/بديل يدوي |
| 2 سبتمبر، 11:00 | صاحب الحساب | كرر طلب معالجة فشل التحقق بالهاتف |
| 5 سبتمبر، 01:52 | صاحب الحساب | متابعة انتظار |
| 9 سبتمبر، 06:26 | Kim / Apple | طلب خطوات التكرار، الوقت والمنطقة الزمنية، صور/فيديو، المستخدم، المتصفحات وإصداراتها، شركة الاتصال، ونوع الهاتف |
| 9 سبتمبر، 06:47 | صاحب الحساب | أرسل خطوات المشكلة والوقت، أسماء Chrome/Edge/Safari، Vodafone Egypt، نوع الهاتف المحمول، وصورًا مرفقة؛ الإصدارات الرقمية للمتصفحات لا تظهر في النص المفحوص |
| **9 سبتمبر، 07:36:33 UTC / 10:36:33 القاهرة** | **Kim / Apple** | **أكد الاستلام والتصعيد للهندسة؛ سيعودون عند التحديث، مع فحص شركة الاتصال إذا كانت تحجب رسائل/مكالمات Apple** |

وجود نقص محتمل في أرقام إصدارات المتصفح في الرد السابق **ليس طلبًا جديدًا واجب الإرسال الآن**: آخر رسالة من Apple أقرت استلام المعلومات وصعّدت القضية، ولم تطلب استكمالًا. لم أفتح المرفقات لإعادة تقييم محتواها.

### ماذا تفعل الآن؟

1. **انتظار فريق هندسة Apple في القضية نفسها.** لا يوجد قرار نهائي حتى الآن.
2. **فحص Vodafone أبلغ المستخدم أنه أُنجز**، وأُرسلت هذه النتيجة إلى Kim في الرد النهائي. لا حاجة لاعتبارها مهمة جديدة غير منفذة؛ الوكيل لم يتواصل مع شركة الاتصال بنفسه.
3. لا تغير الرقم أو عنوان العمل أو تصنيف trader، ولا تعِد الطلب لمجرد استمرار banner. إذا طلب Apple بيانات إضافية، تُرسل في القضية نفسها بعد مراجعتها. لم يُنشأ رصد دوري أو بريد متابعة تلقائي.

### لماذا يبقى تنبيه App Store Connect؟

[Business](https://appstoreconnect.apple.com/business) يعرض `Complete Compliance Requirements`، أي إن اكتمال DSA النهائي **غير مثبت** في المتجر. البريد يفسر الحالة بأنها **مشكلة تحقق هاتف قيد تحقيق الهندسة**، لا دليلًا على وجوب البدء من الصفر. اتفاقيتا Free Apps وPaid Apps كلتاهما `Active`؛ لا دليل على أن عقد البيع هو سبب المشكلة.

تتطلب Apple تحديد صفة trader والتحقق من معلوماته عند انطباقها، ولا تختار Apple هذه الصفة القانونية نيابة عن صاحب الحساب. لم يجرِ هذا التدقيق أي إقرار قانوني. [متطلبات DSA الرسمية لدى Apple](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/).

## 2. حالة التوزيع الحية

| البند | Apple | Google Play |
| --- | --- | --- |
| الهوية الفنية | Apple ID `6805349703`؛ Bundle `com.bilhealth.bodyintelligencelog` | App ID `4974243137795319021`؛ الحزمة نفسها |
| الإصدار العام | 1.0.0 `Developer Rejected`؛ إصدار يدوي محدد | Production `Inactive`؛ طلب الوصول قيد المراجعة، Applied Sunday 10:22 كما تعرض الواجهة |
| المراجعة | آخر طلبات App Review `Removed`، ومنها طلبا أمس 18:56 و07:17 بحسب الواجهة؛ ليست حالة `Waiting for Review` | لا تغييرات غير منشورة في Publishing overview؛ Managed publishing ON |
| البناء | Build **12** رفعه مكتمل، 9 سبتمبر 18:37 بحسب الواجهة، مرتبط بإصدار 1.0.0 | Alpha مغلق، build **8 (1.0.0)** نشط، إصدار 6 سبتمبر، متاح لمختبرين مختارين |
| الاختبار | مجموعة BIL Internal QA، Build 12 `Ready to Submit`؛ مقاييس تثبيته/جلساته ظاهرة بشرطات لا يجوز تحويلها إلى نجاح اختبار | المسار المغلق Active؛ لا يثبت أن المستخدم المجاني العام يستطيع تنزيله من Production |
| البلدان | التطبيق مضبوط **175 Available**؛ لا يعادل تجاوز DSA أو كل تصريح إقليمي | Alpha مضبوط **177 بلدًا/منطقة**؛ ليس إثباتًا لتوافر Production |
| الفئة/العمر | Health & Fitness، Lifestyle؛ 18+ في 173 بلدًا، استثناءات إقليمية، و17+ للأنظمة الأقدم من26 | الجمهور المحدد **18 and over فقط**؛ تقييد Google الإضافي الاختياري لمن يحددهم قاصرين **غير مفعّل** |
| السياسات الحالية | App Privacy منشور؛ ليست كل الموافقات مكتملة | Policy status **No issues found**، App Content **0 Need attention / 10 Actioned** |

الأدلة: [إصدار Apple](https://appstoreconnect.apple.com/apps/6805349703/distribution/ios/version/inflight)، [مراجعات Apple](https://appstoreconnect.apple.com/apps/6805349703/distribution/reviewsubmissions)، [TestFlight](https://appstoreconnect.apple.com/teams/4b4fded6-8542-47ab-955e-25e759c1ef3b/apps/6805349703/testflight/ios)، [توافر Apple](https://appstoreconnect.apple.com/apps/6805349703/distribution/pricing)، [معلومات Apple](https://appstoreconnect.apple.com/apps/6805349703/distribution/info)، [Alpha](https://play.google.com/console/u/0/developers/7540824385820504578/app/4974243137795319021/tracks/4698655612292064176)، [Publishing](https://play.google.com/console/u/0/developers/7540824385820504578/app/4974243137795319021/publishing)، [Policy status](https://play.google.com/console/u/0/developers/7540824385820504578/app/4974243137795319021/policy-center).

Apple App Information يصرح بأن التطبيق ليس جهازًا طبيًا منظمًا. إعلان China ICP غير مضاف على تلك الصفحة؛ لا يُستنتج من ذلك وجوب إضافة تصريح عشوائي. ملاءمة التوزيع/التراخيص القانونية لكل دولة تحتاج قرار المالك عند انطباقها، وليست معطلة عالميًا لمجرد ظهور خيار Set Up.

### تنبيه Android developer verification السابق

الحزمة **Registered**، ولها **4 مفاتيح جميعها Verified**، آخر تحديث 18 أغسطس 2026. لا حاجة لتسجيل نسخة مكررة ولم يُحذف التنبيه. تقرير مستقل: [ANDROID_DEVELOPER_VERIFICATION_2026-09-10.md](ANDROID_DEVELOPER_VERIFICATION_2026-09-10.md). هذه الحالة مستقلة عن انتظار الوصول إلى Production.

## 3. المنتجات والاشتراكات

كل معرفات الكتالوج الخمسة في الكود موجودة في المتجرين. المصدر: [store_catalog_configuration.dart](../../lib/features/commerce/domain/store_catalog_configuration.dart:33).

| Product ID | Apple الحي | Google Play الحي |
| --- | --- | --- |
| `bil_premium` | شهر؛ Developer Rejected؛ 4/175 | base plan `monthly` شهري Auto-renewing، Active، 4بلدان |
| `bil_premium_annual` | سنة؛ Developer Rejected؛ 4/175 | base plan `annual` سنوي Auto-renewing، Active، 4بلدان |
| `bil_premium_ai_coach` | شهر؛ Developer Rejected؛ 168/175؛ أول أسبوع مجانًا | base plan `monthly` Active، 169بلدًا؛ `trial-7-day` Active |
| `bil_premium_ai_coach_annual` | سنة؛ Developer Rejected؛ 168/175؛ أول أسبوع مجانًا | base plan **`yearly`** سنوي Active، 169بلدًا؛ عرض `trial-7-day` Active. الخطة القديمة المسماة `annual` لكنها شهرية **Inactive** |
| `bil_ai_boost` | Consumable، 2,500توكن؛ Developer Rejected؛ 172/175 | 2,500توكن، `standard-2500` Buy Active في173بلدًا؛ عرض `launch-50` Active |

الأدلة: [Apple subscriptions](https://appstoreconnect.apple.com/apps/6805349703/distribution/subscriptions)، [Apple Boost](https://appstoreconnect.apple.com/apps/6805349703/distribution/iaps/6806561724)، [Google subscriptions](https://play.google.com/console/u/0/developers/7540824385820504578/app/4974243137795319021/subscriptions)، [Google Boost](https://play.google.com/console/u/0/developers/7540824385820504578/app/4974243137795319021/one-time-products/sku/bil_ai_boost).

- البلدان الأربعة لـ Premium مفحوصة: **مصر، نيجيريا، باكستان، تركيا**. Apple AI يستثني هذه الأربعة والصين الرئيسية وروسيا وبيلاروسيا. اختلاف أعداد مناطق Apple وGoogle لا يكفي وحده لإثبات خطأ إقليمي.
- أسعار Google Premium المفحوصة: شهري EGP99.99 / NGN1859 / PKR599 / TRY99.99؛ سنوي EGP599.99 / NGN11159 / PKR3599 / TRY599.99. لم تُعدّل. لم تُدقق كل خلية سعر في كل بلد أو كل سعر قديم.
- Apple AI الشهرية والسنوية: عرض أول أسبوع من 30 أغسطس دون تاريخ نهاية، في168بلدًا. Google trial الشهري مفحوص: سبعة أيام، tag `new-customer`، أهلية من لم يملك **أي اشتراك في التطبيق**. تفاصيل أهلية عرض Google السنوي لم تُفتح منفردة؛ ثُبت اسمه وحالته وربطه بـ `yearly`.
- الكود يفحص مدة الاشتراك الفعلية `P1M/P1Y` ولا يعتمد اسم base plan وحده؛ لذلك الخطة الشهرية القديمة غير النشطة ليست دليلًا على شراء سنوي خاطئ حاليًا. [verified_store_purchase_support.dart](../../lib/features/commerce/services/verified_store_purchase_support.dart:213).
- الكود يقبل تجربة AI عند تطابق المنتج وoffer ID وtag وP7D، ويمنع تعميم التجربة على Premium العادي. [إعداد العرض](../../lib/features/commerce/domain/store_catalog_configuration.dart:41)، [تحقق العرض](../../lib/features/commerce/services/verified_store_purchase_support.dart:225).
- مخصصات AI المعلنة 2,500أسبوعيًا وبحد10,000شهريًا تطابق نسخة العرض في الكود؛ هذا ليس تحققًا من رصيد حساب مستخدم أو من كل قواعد الخادم. [bil_store_copy.dart](../../lib/features/commerce/presentation/bil_store_copy.dart:125).
- Apple grace period:16يومًا، All Renewals، Production+Sandbox؛ Google خطتا Premium:7أيام grace و53يومًا account hold تلقائيًا. الاختلاف إعداد منصة، وليس عيبًا بذاته.
- Apple Production وSandbox Server Notification URLs كلاهما يشير إلى `verify-store-purchase` في Supabase. وجود الرابط وFunction ACTIVE لا يثبت وصول/معالجة حدث تجديد حقيقي. إعداد RTDN في Google Cloud/Play وتسليمه من النهاية للنهاية **غير مفحوص** في هذه الجولة.

### رسالة الشراء في الصورة

النافذة البيضاء ذات عبارة عدم السماح بالشراء في Sandbox صادرة من نظام Apple. لا تعني أن الدفع نجح ثم سحب التطبيق الصلاحية، ولا يثبت منها أن `Developer Rejected` هو السبب. القائمة الحالية في [Users and Access > Sandbox](https://appstoreconnect.apple.com/access/users/sandbox) تعرض Create Sandbox Test Accounts ولا تعرض مختبرًا يمكن فحص إعداد Interrupt Purchases له.

لذلك **سبب قيد الحساب على الهاتف غير محسوم حيًا**. من فحوص Apple الرسمية ذات الصلة: `Allow Purchases & Renewals` على جهاز الاختبار، وInterrupt Purchases عند وجود Sandbox tester. إيقاف Allow Purchases يجعل مشتريات الاختبار تفشل؛ هذه إمكانية تشخيص وليست ادعاءً بأن المفتاح مغلق على هاتف المستخدم. [فشل مشتريات Sandbox](https://developer.apple.com/documentation/storekit/testing-failing-subscription-renewals-and-in-app-purchases)، [إعدادات Sandbox](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/manage-sandbox-apple-account-settings/).

المطلوب لاحقًا: مالك جهاز iOS يتحقق من الحساب/المفتاح الفعلي، ثم اختبار Sandbox مصرح به من البداية إلى تحقق الخادم والمنحة/الاستعادة والإلغاء. لا يمكن لهذا التدقيق على Windows أن يعلن نجاح شراء iOS أو يخفي نافذة نظام Apple. رسالة التطبيق المصاحبة وفحوصها المحلية من عمل الوكيل الرئيسي وليست دليل شراء حي.

## 4. App Privacy / Data Safety / Health Apps

### Apple — مثبت حيًا

[App Privacy](https://appstoreconnect.apple.com/apps/6805349703/distribution/privacy) منشور منذ11يومًا وفق الواجهة. Privacy URL=`https://www.bilhealth.com/privacy`، User Privacy Choices=`https://www.bilhealth.com/account-deletion`.

الأنواع الـ17: Name، Email Address، Phone Number، Health، Fitness، Emails or Text Messages، Photos or Videos، Customer Support، Other User Content، Search History، User ID، Device ID، Purchase History، Product Interaction، Performance Data، Other Diagnostic Data، Other Data Types. جميعها معروضة مرتبطة بالهوية. الأغراض المعروضة App Functionality، وتخصيص المنتج للاسم والصحة/اللياقة وبعض المحتوى والبيانات الأخرى. لا يظهر قسم Tracking في المعاينة المفحوصة.

### Google — مثبت حيًا

[Data Safety](https://play.google.com/console/u/0/developers/7540824385820504578/app/4974243137795319021/app-content/data-privacy-security)، آخر تعديل6سبتمبر:

- جمع البيانات:Yes؛ التشفير أثناء النقل:Yes؛ إنشاء حساب باسم/كلمة مرور/مصادقة أخرى، وOAuth.
-16نوعًا محددًا: خمسة أنواع شخصية، الشراء، الموقع التقريبي، رسائل التطبيق، الصور، الصحة واللياقة، Diagnostics، ثلاثة أنواع App activity، ومعرّف الجهاز/غيره.
- البحث داخل التطبيق محدد في النموذج لكنه غير ظاهر في معاينة المتجر، بما يتسق مع تصنيف المعالجة المؤقتة. لم أعدّل الإجابة.
- الصحة/اللياقة/الصور/الرسائل والمعلومات الشخصية والشراء/UGC موصوفة اختيارية. الموقع التقريبي والتشخيصات والتفاعلات والمعرّفات تعرض أغراض analytics/security إضافةً للوظائف حيث يلزم.
- المعاينة تقول No data shared with third parties. **لا يعتبر وجود Supabase/Gemini وحده تناقضًا**: تعريف Google للمشاركة له استثناءات لمعالجي الخدمة والعمليات التي يبدأها المستخدم. لا بد من إثبات انطباقها فعليًا على عقود وإعدادات المعالجين؛ لم تُفحص تلك العقود هنا. [تعريفات Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).
- رابطا حذف الحساب وحذف بعض البيانات محددان، ويعملان. رابط سياسة Google يتضمن slash نهائيًا `/privacy/`، اختُبر HTTP200 دون تحويل خارج الدومين.
- [Ads](https://play.google.com/console/u/0/developers/7540824385820504578/app/4974243137795319021/app-content/ads-declaration)=No، و[Advertising ID](https://play.google.com/console/u/0/developers/7540824385820504578/app/4974243137795319021/app-content/ad-id-declaration)=No، كلاهما محفوظ دون تغييرات.
- [Health Apps](https://play.google.com/console/u/0/developers/7540824385820504578/app/4974243137795319021/app-content/health): Activity/Fitness + Nutrition/Weight + Sleep محددة؛ الخيارات الطبية والبحثية غير محددة.14تبريرًا مكتملًا، ولا متطلب إقليمي إضافي مطلوب حاليًا. تبرير Nutrition ينص على القراءة والكتابة؛ تبرير Weight المفحوص يصف القراءة فقط.
- [الجمهور](https://play.google.com/console/u/0/developers/7540824385820504578/app/4974243137795319021/app-content/target-audience-content):18+ فقط. خيار منع Google للقاصرين إضافيًا اختياري وغير محدد؛ لا يُوصف كفشل إلزامي. الإقرارات المالية والحكومية والتصنيف IARC مدرجة Actioned، لكن إجاباتها الداخلية لم تُفتح منفردة.

## 5. مصفوفة الموقع والسياسات مقابل الكود

| الموضوع | السياسة/المتجر | دليل الكود الحالي | النتيجة |
| --- | --- | --- | --- |
| محلي دون حساب | Privacy/Terms تعرض local-first واختيارية السحابة | adult gate مستقل؛ cloud access/consent/owner gates | متسق في التصميم؛ ليس اختبار رحلة ضيف حيًا |
| العمر | المواقع18+، Apple18+، Play18+ | [adult_eligibility.dart](../../lib/features/onboarding/domain/adult_eligibility.dart:7)، [onboarding_page.dart](../../lib/features/onboarding/onboarding_page.dart:373) | متسق؛ ليس تحقق هوية/عمر خارجيًا |
| HealthKit/Health Connect | استيراد بإذن المستخدم، بقاء المصدر على الجهاز افتراضيًا | [connected_health_provider.dart](../../lib/features/connected_health/providers/connected_health_provider.dart:410) يطلب القراءة منفصلة؛ `synchronize` إجراء صريح عند529، وتحديث الحالة ليس استيرادًا تلقائيًا | متسق؛ لا تخلط مزامنة الصحة المحلية بمزامنة Supabase أو الامتياز المدفوع |
| تصدير الصحة | Apple Review Notes تقول import-only؛ Google وصف وزن للقراءة فقط | [source_card](../../lib/features/connected_health/connected_health_source_card.dart:130) يظهر Allow weight export علىiOS؛ [provider](../../lib/features/connected_health/providers/connected_health_provider.dart:453) يطلب كتابة منفصلة؛ [manifest](../../android/app/src/main/AndroidManifest.xml:76) يعلن WRITE_WEIGHT وWRITE_NUTRITION | **انجراف metadata مقابل الكود الحالي**؛ يُحدّث بعد تثبيت نطاق binary القادم، لا جزم بأنbuild12يحتوي نفس الكود |
| نطاق cloud sync | Profile/body settings + weight + hydration، وليس كل الوجبات | [cloud_manual_sync_service.dart](../../lib/features/cloud_platform/services/cloud_manual_sync_service.dart:129) يحصر الأنواع الثلاثة ويشترط capability/consent/owner | متسق. لا رفع شامل تلقائي للبيانات الصحية من مجرد foreground |
| التشفير | النقل مشفر؛ DMs ليستE2EE | [cipher](../../lib/features/cloud_platform/services/aes_gcm_cloud_payload_cipher.dart:47) يستعمل OS AES-GCM؛ [Android](../../android/app/src/main/AndroidManifest.xml:97) يمنعcleartext | مصدر تصميم جيد، لا شهادة تشفير كل جدول/نسخة احتياطية، ولا حق في الادعاء بأنDMsE2EE |
| AI والموافقة | Gemini/context محدود عند طلب المستخدم، موافقة منفصلة | [privacy boundary](../../lib/features/intelligence_center/services/coach_cloud_privacy_boundary.dart:55) يشترط receipt v2 ويحد السياق؛ [server](../../supabase/functions/ai-coach/server.ts:696) يعيد فحص consent | متسق مصدرًا؛ إعدادات الاحتفاظ/التدريب لدى مزودGemini وعقوده غير مفحوصة |
| سلامة AI وعدم الاحتساب عند الحجب | السياسة الصحية/Privacy9سبتمبر | [server](../../supabase/functions/ai-coach/server.ts:464) يفحص مرشحGemini قبل مسارالنجاح؛ [engine](../../lib/features/intelligence_center/services/intelligence_center_engine.dart:103) حارس أعراض محلي | موجود في الكود؛ لم يُنفذ طلب مدفوع أو اختبار مزود حي في التدقيق |
| الصوت والصور | إرسال النص المتعرف عليه للبوابة؛ صور الوجبة بعد فعل صريح | حدودالموافقة/السياق السابقة، وreceipt خاص بالصوت فيserver | يتسق مع الإفصاح؛ خدمة التعرف المنصية قد تعالج الصوت، لا يجوز قول «لا يعالج أي طرف صوتًا» |
| الإعلانات/التحليلات | سياسة Android مشروطة بالتفعيل؛ PlayAdsNo/ADIDNo | [Android workflow](../../.github/workflows/bil_android_release_candidate.yml:174)، [iOS workflow](../../.github/workflows/bil_ios_signed_release.yml:398) يعطلانAds؛ manifest يزيلAD_IDعند55؛ [gateway](../../lib/features/ads/services/admob_contextual_ad_gateway.dart:137) nonPersonalized؛ بوابةUMP منفصلة | متسق مع التكوين الحالي. لا يُفعّلAdsمستقبلًا قبل إعادةتدقيقSDKوالإفصاح. مصدرworkflowليسإثباتًا مستقلاً لflagsكلbinaryقديم |
| منشورات ورسائل وأمان المجتمع | السياسةنسخةcommunity-policy-v1، قبول، بلاغ/حظر/مراجعة بشرية، DMغيرE2EE | [repository](../../lib/features/community/data/community_repository.dart:245) blockRPC؛ السياسةعند434/484؛ reviewعند119/552؛ reportعند689؛ [comment report](../../lib/features/community/data/community_social_repository_mixin.dart:454) | وظائف الكود موجودة. لم تُقرأ بلاغات/رسائل مستخدمين، ولا يُستنتج SLAالمشرفين من قائمة فارغة |
| الأسعار والمنح | المتجر مصدر السعر؛ تحقق خادم قبل الصلاحية | [catalog adapter](../../lib/features/commerce/services/verified_store_catalog_adapter.dart:292)، [purchase support](../../lib/features/commerce/services/verified_store_purchase_support.dart:225) | مطابق على مستوى المعرفات/مدةالعرض؛ grant/restore/revokeE2Eغيرمفحوص |
| حذف الحساب | مسارداخلالتطبيق، رابطويب، مصدرHealthKitHCوالفواتيرلايحذفان تلقائيًا | [account_deletion_page.dart](../../lib/features/settings/account_deletion_page.dart:90)، [worker](../../supabase/functions/_shared/account_deletion_worker.ts:115) | جدولةونشرحيانمثبتان؛ الاكتمالالفعلينهايةإلىنهايةغيرمفحوص |

متطلبات UGC الرسمية تشمل قبول السياسة، التصفية، الإبلاغ، الحظر والمراجعة الفعالة؛ مجرد وجود الأزرار لا يثبت العمل التشغيلي المستمر. [Apple1.2](https://developer.apple.com/app-store/review/guidelines/)، [GoogleUGC](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en-GB). يجب أن تظل أدوات البلاغ والحظر قابلة للوصول أثناء تبسيط مدخل المجتمع؛ إخفاؤها بالكامل خلف اشتراك أو تسجيل قبول جديد ليس نتيجة معتمدة من هذا التدقيق.

Google يطلب تطابق بيانات Health Connect المطلوبة مع إقرار المتجر وفائدة واضحة للمستخدم. عدم ظهور حقل منفصل لـWRITE في الواجهة المفحوصة ليس دليل مخالفة آلية؛ توصية وزن الكتابة هنا **مواءمة وصف الاستخدام** مع المصدر. [نشر تطبيقات Health Connect](https://developer.android.com/health-and-fitness/health-connect/publish).

## 6. الدومين والروابط الفعلية

الروابط مستخرجة من إعدادات المتجر والكود، لا عناوين مخمنة:

| الرابط | النتيجة أثناء التدقيق |
| --- | --- |
| [Privacy](https://www.bilhealth.com/privacy) و[/privacy/](https://www.bilhealth.com/privacy/) | HTTP200، محتوىسياسةمقروء، تحديث9سبتمبر2026 |
| [Terms](https://www.bilhealth.com/terms) | HTTP200 ومحتوىمقروء، تحديث9سبتمبر |
| [Subscriptions](https://www.bilhealth.com/subscription-terms) | HTTP200 ومحتوىمقروء، تحديث29أغسطس |
| [Account deletion](https://www.bilhealth.com/account-deletion) | HTTP200 ومحتوىمقروء، مسارالتطبيقوبريدطلبالحذف، تحديث29أغسطس |
| [Data deletion](https://www.bilhealth.com/data-deletion) | HTTP200 ومحتوىمقروء، حذفجزئيوموافقةومصادرالصحة، تحديث29أغسطس |
| [Community Guidelines](https://www.bilhealth.com/community-guidelines) | HTTP200 ومحتوىمقروء، community-policy-v1، فعّالة8سبتمبر |
| [Support](https://www.bilhealth.com/support) | HTTP200 ومحتوىمقروء، support/privacy/safetycontacts |
| [Health disclaimer](https://www.bilhealth.com/health-disclaimer) | HTTP200 ومحتوىمقروء، تحديث9سبتمبر |

كلها موقعSPA؛ لذلك لم يُعتبر HTTP200 وحده إثباتًا لوجود السياسة: قُرئ المحتوىالمصيّر نصيًا في المتصفح. صفحة`/contact` مرتبطة بالموقع لكنها لم تُفتح منفردة؛ بياناتالاتصالالقابلةللنقر قرئت فيSupportوالسياسات. رابطAppleEULAالمعياري موجود فيlisting.

ملف `https://www.bilhealth.com/app.js` يطابق [public_site/app.js](../../public_site/app.js) الحالي بالبايت/SHA-256:

`3cf6a9c0fd621628d6b43be5a17da1526893875c3a2b0700d1628549d279332a`

الحجم86324بايت. هذا يثبت نسخةمحتوىالموقع المفحوصة، لا ملكيةالسجل التجاري. عينةHTTPالأخيرة لـ`/privacy/` و`/data-deletion` و`/health-disclaimer` بقيت على`https://www.bilhealth.com` دونتحويلخارجي وأعادتHSTSلسنة وCSPيقيدالمصادر ويجيز اتصالSupabaseالمحدد فقط. الـCSP/HSTS ليسا اختباراختراق.

الخصوصية تشرح Cloudflare كسجلات حافة تشغيلية، وlocalStorage لاختيار اللغة دون منارة تحليلات تسويقية للموقع. لم تُختبر قابلية تسليم support@ أو privacy@ بإرسال بريد، ولم تُدقّق ملكية DNS/registrar أو عقود Cloudflare/Supabase/Gemini. اتساق روابط المتجر والكود والموقع مثبت؛ ملكية الأعمال القانونية ومستندات المعالجين ليست مثبتة به. رسالة Apple الصادرة لا تختبر صندوقي دعم الدومين.

مصادرالنص: [privacy](../../public_site/app.js:77)، [deletion](../../public_site/app.js:111)، [datachoices](../../public_site/app.js:121)، [health](../../public_site/app.js:144)، [community](../../public_site/app.js:169)، [language storage](../../public_site/app.js:287). صياغةالاحتفاظعمومية/مرتبطةبالغرضوالقانون؛ مددالنسخ الاحتياطية وسجلاتالمزودين الفعلية لمتُثبت، ولايصح اعتبارها حذفًا فوريًا شاملًا.

## 7. حذف الحساب: المصدر والنشر والنتيجة

قرأ التدقيق metadata فقط في مشروعSupabase`tgmanzhqulksykhslrzb`؛ المشروعACTIVE_HEALTHY.

| الدليل الحي | النتيجة |
| --- | --- |
| EdgeFunction `account-data-deletion` | ACTIVE، version18، JWTverificationenabled |
| `apple-sign-in-token` | ACTIVE،version7 |
| cron `bil-account-data-deletion-storage-first-15m` | active،`*/15 * * * *`، يستدعيdispatcherالمخصص |
| dispatcher / secret-validator | موجودان؛ لم يُستدعيا بواسطة الوكيل |
| أسرارالتكوينالمطلوبة | تأكد وجودأسمائها فقط دونقراءةالقيم |
| آخر24ساعةمنسجلتشغيلcron | 96تشغيلًاstatus=succeeded؛ آخربدءمفحوص9سبتمبر22:15:00UTC |

نجاحcronهنايثبت تنفيذ **استدعاءdispatcher في قاعدةالبيانات**، وليس نجاحاستجابةHTTPلكلطلب، ولااكتمالحذف مستخدمأوملفStorage. لم تُقرأ قائمةطلباتالحذف، ولم تُنفذوظيفةالحذف أوRPCالمؤثر.

المصدر [account_deletion_worker.ts](../../supabase/functions/_shared/account_deletion_worker.ts:115) يرتب إلغاءمنحةApple قبلضياعتوكنها، ثمحذفStorageوالتحقق، ثمحذفحسابAuth، ولايؤكداكتمالًا عندفشل. الجدولةموصوفةفي [migration](../../supabase/migrations/20260830053817_account_deletion_storage_cleanup_20260830093000.sql:119).

**تعارض وثائقي أُغلق محليًا:** كان [جرد الخصوصية](../APP_STORE_PRIVACY_DATA_INVENTORY.md) يصف عامل الحذف بأنه غير منشور وإلغاء منحة Apple بأنه يدوي فقط، خلاف المصدر الحالي وmetadata الحية. صحح الوكيل الرئيسي الوثيقة في 10 سبتمبر بعد حفظ نسخة احتياطية متحققة، ووضّح الفرق بين نجاح استدعاء الجدولة ونجاح حذف الحساب فعليًا. لم يتغير الخادم أو نص السياسة المنشورة. الجدولة تعمل كل 15 دقيقة؛ لكن نتيجة الحذف من البداية للنهاية، ومدد الاحتفاظ والنسخ الاحتياطية، ما زالت تحتاج تحققًا مصرحًا به.

Appleتطلب مسارحذفداخلتطبيقيدعمالحسابات، بمايشملUGCالمرتبط وفقحدودالقانون، وGoogleتطلب كذلكرابطويب. وجودالمسارينمثبت، ومعنى«اكتمالالحذف»يحتاج الاختبارالفعلي. [Appledeletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/)، [Googledeletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN).

## 8. قائمة الأولويات والجهة المخولة

| الأولوية / التصنيف | البند والأثر | الإجراء المحدد | المنفذ / التفويض |
| --- | --- | --- | --- |
| P1، انتظار خارجي | DSA غير مكتمل والمتجر 175 بلدًا؛ التوزيع الأوروبي غير محسوم | انتظار هندسة Apple في القضية نفسها بعد إرسال إفادة المستخدم بإتمام فحص شركة الاتصال واستمرار المشكلة؛ لا إعادة تقديم من التنبيه فقط | Apple وصاحب الحساب؛ أي تغيير هوية أو هاتف أو إقرار يحتاج توجيه المالك |
| P1، إجراءإصداردونهلعيب | AppleDeveloperRejectedوالطلباتRemoved | عندقرارالإصدار:ثبّتbinaryوmetadataوالاختباراتالمطلوبة، ثمأعدإرسالالمراجعةبإذنصريح؛ ليسفيهذاالتدقيق | مالكالإصدار؛ نشر/إرساليتطلبتفويضًا منفصلًا |
| P1، انتظارخارجي | GoogleProductionaccessقيدالمراجعة | انتظرقرارGoogle؛ لا تفسرAlphaأوالإشعاركنشرعام | Google؛ النشرلاحقًا بتفويضالمالك |
| P1، فجوةدليل | شراءSandbox/restore/renewal/revokeوإشعاراتالخادم | تحققمنإعدادالحساببالجهاز، ثممساراختبارمعتمدونتائجserver؛ تدقيقGoogleRTDNلاحقًا | مهندسالمتجر+مالكهاتف/حساباختبار؛ أيشراء/منح/تغييرخارجالتدقيق يحتاجإذنًا |
| P2، مغلق محليًا | وصف قديم لنشر الحذف وحفظ توكنات Apple في جرد الخصوصية | صُححت الوثيقة وفق المصدر وmetadata الحية، مع فصل الجدولة عن إثبات الحذف الفعلي | أنجزه الوكيل الرئيسي بعد التدقيق؛ لا تغيير خارجي ولا ادعاء نجاح اختبار حذف |
| P2، تعارضmetadataمعالكودالقادم | import-onlyفيApple، وصفWeightقراءةفيGoogle | طابقملخصالصحةمعbinaryالمثبت:استيرادصريح، وزنكتابةاختياريةعلىiOS، تغذية/وزنعلىAndroidإنبقيتنفذ | مهندسالإصدارومالكالمتجر؛ تغييرmetadataبتفويض |
| P2، فجوةدليل | تنفيذالحذفلكلبياناتAuth/Storage/UGCوتوكنApple/النسخ | اختباربحساباختبارمخصصوتحققstorage-firstوحدودالاحتفاظ، دونالمساسبحسابحقيقي | مهندسالخادم/QA؛ حذفمقصودبتفويضمحدد |
| P2، خطرعندتغييرالتكوين | AdsNo/ADIDNoوNoShared مقابلSDKإعلاناتمشروط | قبلتفعيلالإعلانات:إعادةتدقيقالمصادر/SDK/consentوالتصنيفوالإفصاح؛ لاتشغلهامنالخادمدونمواءمة | مهندس+مالكسياسةالمتجر؛ تعديلخارجييتطلبموافقة |
| P2، قانوني/تشغيليغيرمثبت | مددالاحتفاظوعقودالمعالجينوالتحويلاتالدوليةوترخيصبلدانالتوزيع | توثيقالإعداداتالفعليةوالعقودومراجعةقانونيةحسبالبلدان؛ لاإضافةادعاءامتثال/HIPAA/GDPRعامبلاسبب | مالكالبيانات/مستشارقانوني؛ قرااتقانونيةبسلطةالمالك |
| P3، تحقققبلالتسليم | تغيراتUI/ميزاتالحساببعدآخرbinaryوقواعدمجتمعجديدة | اربطنسخةموقعةمحددةمعreviewnotes/الصوروaccountaccess، ولا تعتمدنجاحالاختباراتالمحليةكنشر | مهندسالإصدار؛ لا تصويرإضافي الآن بناءًعلىطلبالمستخدم |

## 9. ما لا يثبته هذا التقرير

- لم تُفحص كل أسعار175/177منطقة ولا كلoffers/legacyprices، ولاكلترجمةوسكرينشوت/تطابقبصري. وجودالصورثُبت؛ حداثتهاالبصريةلمتُحكمبعدإيقافالفحصالبصري.
- لم تُقرأ تفاصيلPlayIARCوالإقرارينالمالي/الحكوميفرديًا، ولمتُستكملجميعمساراتOpen/Internalأودلالاتكلمسودةbundle. لايُستنتجعدموجودهامنالتقرير.
- لم تُراجعRTDNوإيصالإشعاراتApple/Googleفعليًا، ولااتفاقياتGooglePayments/حالةالضرائبأوتفاصيلالبنك. حالةاتفاقياتAppleنشطةمثبتةفقطبالملخص.
- لم تُجرّبأزرارsignin/signoutعلىحساباتالمستخدمينأورحلةfree/paidحقيقية. يوجدتحققمصدرومراجعةمحليةيجريهاالوكيلالرئيسي؛ لايحلانمحلنطاقE2Eللمتاجر.
- لم يُثبتالمحتوىالفعلينفسهفيbuild8/12منالـSHAالحالي. نشرGemini/الحذفACTIVEلايثبتتطابقكلسطرمحليبالمصدرالمنشور.
- لم تُفتح ملفات هوية DSA أو مرفقاتها، ولم يختبر الوكيل الهاتف أو مزود الاتصال، ولم يُطلب OTP أو يُنفذ استدعاء حذف. أُرسل فقط رد البريد المصرح به إلى Apple، متضمنًا إفادة المستخدم عن فحص شركة الاتصال.
- `No issues found`فيGoogleهوحالةالواجهةوقتالفحص، وليسضمانموافقةمستقبليةأوشهادةامتثالشامل.

**الحالة النهائية:** القراءات الأساسية موثقة، مع قرار DSA وفجوات الدليل الصريحة. أُرسل رد Apple المصرح به وتحقق ظهوره في السلسلة؛ لم يُنفذ أي تغيير خارجي آخر. انتهت مهمة الوكيل، ولا مراقبة أو إجراءات إضافية تلقائية.

## 10. متابعة البريد للقراءة فقط — رد Apple الجديد

بناءً على طلب جديد من المستخدم، فُحصت [سلسلة Developer Support نفسها، القضية 20000151571917](https://mail.google.com/mail/u/0/#search/DSA+newer_than%3A30d/FMfcgzQhWLGwSsTGGPNwlCsnpsQXPSNt). ظهر إشعار رسالة جديدة، وفُتح الرد ثم تفاصيل المرسل. وقت إثبات الفحص: 10 سبتمبر 2026، 00:14 UTC / 03:14 القاهرة.

- **المرسل:** Kim، Apple Support. أظهرت تفاصيل Gmail أن From وReply-To هما `eurodev@apple.com`، وأن mailed-by وSigned by هما `apple.com`.
- **التاريخ الظاهر:** 10 سبتمبر 2026، **02:21** بتوقيت عرض Gmail/القاهرة، بعد رد المستخدم المرسل عند 01:36.
- **المطلوب صراحة:** بيانات **الرقم البديل الذي جُرّب**: رقم الهاتف، واسم مزود الشبكة، وهل الرقم خط أرضي أم محمول. قالت Kim إن هذه المعلومات ستُحال إلى فريق الهندسة الداخلي لمواصلة التحقيق.
- **ما لم تقله Apple:** لا قبول أو رفض لـ DSA، ولا تأكيد اكتمال التحقق، ولا طلب وثائق جديدة أو إعادة تقديم الطلب أو طلب OTP، ولا موعد نهائي.
- **القرار المحدّث:** توجد الآن معلومات طلبتها Apple؛ ليس انتظارًا فقط. ينبغي أن يوضح المالك الرقم البديل المقصود قبل أي رد، لأن الرقم المرفق بسياق المهمة يظهر أصلًا في السلسلة بوصفه رقم DSA. لا يُفترض أنه رقم آخر تلقائيًا. اسم الشبكة Vodafone Egypt والمحمول واردان في سياق المالك، لكن لم يُرسل أي منهما في هذه المتابعة ولم يُحفظ رقم الهاتف الكامل في التقرير.

لم يُكتب أو يُرسل رد، ولم تُطلب أكواد تحقق أو تُغيّر أرقام أو إعدادات، ولم تُنشأ مراقبة دورية. انتهت المتابعة عند إثبات الرد وإبلاغ الوكيل الرئيسي؛ لم يُعدّل ملف FINAL_RELEASE_FIX_BATCH أو كود التطبيق.

## 11. إرسال تفاصيل الرقمين بعد موافقة المالك — 10 سبتمبر، 03:19

بعد قراءة الرد الوارد، وضّح المالك البيانات ووافق صراحة بعبارة «نعم، أرسل هذه المعلومات» بعد عرض الوجهة والمحتوى. نُفذ هذا التفويض المحدد فقط، عبر **Reply** لآخر رسالة Kim في القضية **20000151571917** إلى **`eurodev@apple.com`**، دون Reply all أو مستلمين جدد أو مرفقات.

- **قبل الإرسال:** أُعيد التحقق من From وReply-To وأن mailed-by وSigned by هما `apple.com`. أعاد البحث في Sent، مقيدًا بمستلم Apple والرقم البديل، **No messages matched your search**؛ لم يظهر رد مرسل مطابق.
- **المحتوى المرسل:** الرقم البديل المنتهي بـ **7402**، مزوده **Etisalat Egypt (e& Egypt)**، وهو **محمول** ولا يصل إليه SMS التحقق. والرقم الرسمي المنتهي بـ **5552**، مزوده **Vodafone Egypt**، وهو **محمول**؛ تضمن الرد إفادة المالك بأنه موثّق سابقًا لدى Apple، لكن SMS التحقق الحالي لا يصل إليه أيضًا. هذه إفادة المالك، وليست تحققًا مستقلًا من حالة الرقم. طُلب تمرير التفاصيل لفريق الهندسة كما اقترحت Kim، دون تخمين السبب. أُرسلت الأرقام كاملة في البريد المصرح به، ولا تُكرر كاملة في تقرير QA.
- **سلامة النص:** طابق نص حقل الرسالة النص المقصود قبل الإرسال، مع ظهور كل رقم مرة واحدة وإزالة اقتراح التوقيع التلقائي؛ لم يُضف اسم أو معلومات أخرى.
- **الإثبات:** نُقر Send مرة واحدة، ثم ظهر **Message sent** والرد الفعلي داخل السلسلة، بمحتوى الرقمين والشبكتين، ووقت **10 سبتمبر 2026، 03:19** بتوقيت عرض Gmail/القاهرة. لم يُعد الإرسال.

هذا رد ثانٍ منفصل عن توضيح 01:36، وقد فُوّض صراحة بعد طلب Apple لبيانات إضافية؛ لا يغيّر وصف التدقيق الأساسي بأنه للقراءة فقط عدا رسالتي البريد المصرح بهما. **الحالة الآن: انتظار رد فريق Apple على التفاصيل المرسلة**؛ لا قبول أو رفض أو اكتمال تحقق مثبت. لا OTP أو تعديل إعدادات أو إجراء متجر أو تعديل كود أو اختبار أو مراقبة تلقائية. انتهت المهمة بعد إثبات الإرسال وتوثيقه.
