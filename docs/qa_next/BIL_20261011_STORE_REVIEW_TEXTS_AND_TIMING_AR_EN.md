> تحديث13أكتوبر2026: هذا سجل تاريخي لنسخته ونتائجه. الحالة الحالية والإصلاحات بعد2c518ee4 وقرار المراجعين في [التقرير الجامع](BIL_20261013_PRE_FULL_STORE_REVIEW_CLOSURE_AR.md). نتائج1292 القديمة لا تنسب للمصدر الجديد. nutrition/goalsV2 أصبحت منفذة واختُبرت محليًا، دون نشر. الشاملة مأذونة مرة واحدة بعد الإغلاق، ولم تبدأ أثناء الإصلاحات. حالة الحسابات/artifact/Console تبقى غير مثبتة؛ السماح برفع Play ليس شرطًا لإعداد Appeal أثناء التعليق.

# نصوص المتاجر المقترحة وتوقيت استخدامها — غير مطبقة

فحص المصادر الرسمية: 2026-10-11. المالك أكد عدم تقديم Appeal لتعليق8 أكتوبر. قراءة Console الحالية تعذرت بسبب اتصال المتصفح؛ لا استنتاج بإنهاء حساب المطور أو حذف بياناته. Apple35 تحت المراجعة بحسب المالك، دون تأكيد حي من App Store Connect. لم نرسل Appeal أو بريدًا أو نغير metadata أو حساب مراجع أو build.

## قرار الإرسال

مسودة الاستئناف جاهزة للتحرير النهائي، **وليست جاهزة لادعاء معالجة جميع المخالفات**. يمنع الإرسال المثبت الآن: غياب تجربة نظيفة على artifact Play32/نسخة مصححة متاحة، وعدم إثبات منتجات IAP الحية وتعليمات دخول المراجع وصلاحيته ورصيد AI، وتعذر تأكيد Console والمسار المتاح لرفع نسخة أثناء التعليق. ليست جودة الـPolish شرط الانتظار. المرجع والتسلسل ومسودة الإنجليزية في [ملف الاستئناف](BIL_20261011_GOOGLE_APPEAL_PREPARATION_AR_EN.md).

Google قد ترفض تحديثًا أو تعلق التطبيق بسبب تكرار الرفض؛ استئناف قرار التعليق يعالج سجل المخالفات المثبت كله. لا ضمان إعادة التفعيل، ولا package بديلة للالتفاف. تجهيز المصدر لا يغير Android32 المرفوعة. مصدر [إجراءات الرفض والتعليق والاستئناف](https://support.google.com/googleplay/android-developer/answer/2477981).

## Google — الحقول والتغيير المقترح

| الحقل/الوضع الحالي | السبب | النص أو الإجراء المقترح | النسخة والتوقيت/المراجعة |
|---|---|---|---|
| App Access: لم تُقرأ قيم Console الحالية | رفض paywall32 مثبت | بيانات آمنة قابلة لإعادة الاستخدام، بلا OTP/شراء/بطاقة دفع؛ English steps أدناه بعد تحقق entitlement/AI | النسخة المتاحة للمراجع فعليًا؛ أثناء التعليق بحسب أدوات Console المسموحة |
| App Status: رسالة8Oct Suspended؛ الحالة الحية غير مقروءة | repeated rejections | استئناف واحد على القرار نفسه بعد موافقة المالك وإغلاق أدلة العيوب؛ لا تحديثAndroid33 مفترض | يتطلب رد/إعادة تفعيل أو سماح رسمي عند تعذر رفع التصحيح |
| IAP catalogue الحي غير مقروء | 15Sep صورة item could not be found للشراء | فحص product IDs والبلدان والتفعيل والشراء sandbox/Play artifact ثم تصحيح الفرق إن ثبت | لا ادعاء أن preflight مصدر32 يعالج كتالوج المتجر الحي |
| Health declaration/Data Safety غير مقروءين حاليًا | 15Sep Android13 طلب ثلاثة أذونات مفرطة | مطابقة الاستخدام الفعلي مع Manifest الحالية والخدمات، إزالة التصريح غير المستخدم بعد تحقق artifact | source32/current لا يطلب BodyFat/RestingHeartRate/SleepSession؛ يلزم artifact/device قبل تعديل Console |
| الوصف المجاني/المدفوع الحالي غير مقروء | وضوح سياسة الوصول | وصف الميزات المجانية والمدفوعة والرصد المجاني والمنح الاختيارية بصدق | تصحيح إلزامي فقط عند تناقض؛ ليس تحديث وصف بسبب الألوان |
| UGC/تصنيف عمري/AI consent/privacy الحالي غير مقروء | وظائف المجتمع ومشاركة AI | مطابقة البلاغ/الحظر والمراجعة ومصادر AI والموافقة الصريحة مع النسخة المقدمة | لا إخفاء إدارة أو تحويل consent إلى default |

تعليمات مقترحة، تُستكمل عبر قناة المتجر الآمنة لا GitHub:

> Sign in using the reusable review credentials provided in App Access. This review account has the documented feature access and AI balance required for review; no purchase, payment card, invitation, or community posting is required. Open Goals, Nutrition, Recipes, Exercises, Connected Health, AI Coach, Vision, and Barcode. Return using the in-app back control. Subscription upgrades remain optional. If an access check is temporarily unavailable, use Retry; the app should not automatically redirect this authorized account to Plans.

هذا **نص مشروط بالتحقق وليس تأكيدًا بوجود تلك الصلاحية الآن**. تُذكر متطلبات عتاد Bluetooth/Health الحقيقية والخطوات البديلة بوضوح، ولا بيانات دخول أو مفاتيح في هذا الملف. فصل الهوية/الجلسة/الاشتراك/رصيدAI/الدور الإداري أساس التحقق. [متطلبات دخول المراجع](https://support.google.com/googleplay/android-developer/answer/15748846).

## Apple — الحقول والتغيير المقترح

| الحقل الحالي | سبب التعديل | النص/الإجراء المقترح | النسخة والتوقيت/المراجعة |
|---|---|---|---|
| Notes for Review الحالية لم تُقرأ حيًا؛35 تحت المراجعة وفق المالك | شرح الوصول والإدارة غير البديهية | نص Notes أدناه بعد مطابقة35، وتخصيص وصول إدارة في بيئة بيانات معزولة إن احتاج المراجع | لا استبدال تعليمات35 بوعد نسخة محلية مختلفة؛ موافقة المالك مطلوبة |
| IAP/subscriptions/restore الحالية غير مقروءة | اكتمال شراء ومطابقة الاستحقاق | إثبات sandbox للمنتجات والشراء والاستعادة والتجديد وحقوق المتجر | لا تعديل سعر أو Trial أو منتج أو metadata الآن |
| App Privacy/AI disclosure/Health descriptions | بيانات فعلية وأذونات وموافقة واضحة | ربط كل نوع بيانات وجهة إرسال واستخدام صحي بالمصدر الفعلي؛ لا ادعاء دقة أو اعتماد جهاز طبي | تصحيح إلزامي عند فرق مثبت، لا تغيير شكلي لمجردPolish |
| UGC/age rating/screenshots | المحتوى والإبلاغ والحظر وصور النسخة المقدمة | صور artifact المقدمة نفسها؛ لا صور المصدر الجديد دليلًا على35 | عند نسخة مناسبة وموافقة مستقلة؛ لا سحب مراجعة35 |

Notes draft:

> BIL includes role-authorized community moderation and administrative support tools. Ordinary users and subscription purchases do not obtain these roles. Financial actions require server authorization and are separate from community moderation. Community reporting and blocking remain available inside the app. Review access and any isolated administrative demonstration are documented in the supplied review instructions. AI features require explicit third-party data consent. Health/device readings are informational; supported hardware and system permissions are required for native device tests.

لا نعطي مراجعًا سلطة منح مالية حقيقية على المستخدمين. لا إخفاء وظيفة أو سلوك خاص بهوية مراجعة مخزنة في الهاتف. Apple تطلب تطبيقًا مكتملًا وتعليمات ووصولًا للوظائف، وUGC بضوابطه وmetadata دقيقة. راجع [Guidelines: 1.2, 1.4, 2.1, 2.2, 2.3, 3.1](https://developer.apple.com/app-store/review/guidelines/).

## Tokens والعروض — فصل المنصتين

Google تميز نقاطًا مكتسبة/ممنوحة عن نقاط مباعة؛ المباعة تخضع لسياسة الدفع المناسبة. لا نجعل النشر بالمجتمع شرط استعمال خدمة مشتراة. [Payments/FAQ](https://support.google.com/googleplay/android-developer/answer/10281818).

Apple تُفحص بصورة مستقلة: حقوق شراء IAP والاشتراك والمنح ليست تفسير Google نفسه. لا تنتهي credits مشتراة بسبب منحة إدارية، ولا يُعوَّض مختبر TestFlight لقاء الاختبار. منح الوصول الحالية لا تثبت بذاتها أنها مكافأة مشروطة باختبار؛ يلزم فحص شروطها الفعلية. لم نضف دفعًا خارجيًا أو روابط شراء بريدية. لا مكافآت مقابل تقييم إيجابي أو إزالة سلبي.

Offer Codes الرسمية قد تناسب عرض اشتراك محدد حسب نوع العرض والمنطقة والأهلية وإعداد تجديده، ولا نستبدل كل منحة بها تلقائيًا: [وثيقة Apple Offer Codes](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-subscription-offer-codes/).

المجتمع يحافظ على آلية الإبلاغ والحظر والمراجعة، منفصلة عن مكافأة اعتماد منشور: [Google UGC](https://support.google.com/googleplay/android-developer/answer/12923286). البريد لا يحل محل الإبلاغ داخل التطبيق.
