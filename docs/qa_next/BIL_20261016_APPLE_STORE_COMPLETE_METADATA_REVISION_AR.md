# BIL — مراجعة وتحديث بيانات متجر Apple كاملة

**الحالة: عُدّلت البيانات المسموح بها في المسودة، وأزال المالك عناصر إرسال المراجعة السابق يدويًا، ثم حُدّثت أوصاف المنتجات الخمسة وقُرئت بعد الحفظ من App Store Connect. لم أضغط Add for Review ولم أعد إرسال العناصر أو التطبيق. هذا ليس اعتمادًا أو شهادة جاهزية للمتجر.**

## المصدر والحالة

- المستودع: `bilhealth-admin/Body-Intelligence`
- مجلد العمل المستخدم: `G:/BIL_Project/worktrees/bil-ios36-audit-snapshot-20261014`
- الفرع: `integration/bil-qa-media-policy-20261011`
- HEAD عند التدقيق: `a6f0a9a15188aabca0dcb739269ab17079ed4504`
- App Store Connect app ID: `6805349703`; الحزمة: `com.bilhealth.bodyintelligencelog`
- النسخة الحية: `1.0.0`, حالة المسودة `PREPARE_FOR_SUBMISSION`, ولا يوجد build مرتبط.
- لم يُرفع أو يُوقّع IPA 36، ولم يُرسل إصدار أو رد إلى Apple، ولم تُغيّر أسعار أو فترات Trial أو التوفر أو بيانات الدخول. أُجري لاحقًا تعديلان موثقان في إجابات App Privacy فقط؛ التفاصيل أدناه.

## ما عُدّل فعليًا

1. **وصف التطبيق باللغة الإنجليزية**: أُضيف إلى إفصاح AI أن الطلب يتضمن السؤال والسياق الذي اختاره المستخدم وما يصل إلى 12 دورًا حديثًا من المحادثة، وأن Gemini يعالج الطلب. وأُوضح أن الإملاء الصوتي قد يُعالج عبر مزوّد التعرف الصوتي المحدد في الجهاز، وأن الصوت الخام لا يُرسل إلى خادم BIL أو Gemini. لم تتغير بقية الفقرة أو بقية حقول اللغة. قرأت Apple القيمة بعد الحفظ حرفيًا؛ طول الوصف الحالي **3135 من 4000 محرف**.
2. **ملاحظات المراجعة**: كانت **4007 بايت** مع أن حد الحقل 4000 بايت. اختُصرت فواصل الفقرات الفارغة فقط؛ لم يتغير أي حرف غير مسافة أو فاصل. أصبحت **3998 بايت**، وأكدت القراءة اللاحقة القيمة والبصمة. لم تُمس بيانات حساب المراجع.

أدلة القراءة بعد الكتابة موجودة في [نتيجة وصف التطبيق](evidence/policy-gate-20261015/apple-full-store-update-20261016/apple-store-description-update-20261016.json) و[نتيجة حد ملاحظات المراجعة](evidence/policy-gate-20261015/apple-full-store-update-20261016/apple-review-notes-limit-repair-20261016.json).

## تدقيق بقية حقول المتجر

| القسم | القراءة الحية والقرار |
|---|---|
| الاسم والعنوان الفرعي | Body Intelligence Log، 21/30؛ Nutrition, Fitness & Progress، 29/30. لم يظهر فرق مثبت عن هوية التطبيق. |
| الكلمات المفتاحية | 95/100 بايت؛ باقية دون تعديل. |
| النص الترويجي | 133/170 محرفًا؛ باقٍ دون تعديل. |
| صفحة الإصدار | الوصف القانوني وروابط الخصوصية والشروط والدعم موجودة. رابط EULA القياسي من Apple موجود مع App Terms وCommunity Guidelines. تقرير الروابط السابق سجّل استجابة 200 للروابط العامة الخمسة. |
| اللغة | en-US فقط في قائمة المتجر. لا أُضيفت ترجمة أو مجموعة صور عربية غير مثبتة. دعم التطبيق للغات لا يثبت جاهزية لقطة متجر مترجمة. |
| What's New | فارغ. النسخة 1.0.0 لا تحمل build بعد؛ لم يُخترع نص تحديث قبل وجود تغيير مبني قابل للنشر. |
| التصنيف العمري | 17+ عمومًا و18+ في البرازيل، مع التصريحات الحالية للمجتمع والرسائل والمحتوى المنشأ والإعلانات والصحة. لم يُغيّر التصنيف تخمينًا. |
| صور المتجر | 8 صور iPhone 6.7 و8 صور iPad 12.9، وكلها `COMPLETE` من ناحية الرفع. لم يثبت فحصها البصري مقابل IPA 36 لأنها غير موجودة ولا يوجد build مرتبط؛ لم تُستبدل الصور. |
| مراجعة Apple | حقول التواصل وحساب المراجعة والملاحظات موجودة. هذا لا يثبت نجاح تسجيل الدخول. الحقل لم يُعرض أو يُنسخ إلى التقرير. |
| المنتجات | أربعة اشتراكات وBoost؛ أسماء العرض والمعرفات باقية كما هي. بعد الحفظ، أظهرت صفحات الاشتراكات ومجموعة الاشتراك وBoost حالة `Developer Rejected`. لا يوجد Build مرتبط، ولم تُرسل أوصاف en-US الجديدة للمراجعة. الأسعار والفترات والعروض والتوفر لم تتغير، ولا يوجد دليل على اعتمادها أو نجاح معاملة Sandbox. |

## أوصاف المنتجات — تم التحديث بعد إزالة الإرسال القديم

يشترط مرجع Apple ألا يتجاوز وصف الشراء داخل التطبيق **45 محرفًا**. كانت القيم التالية ظاهرة قبل تحديث الوصف:

| المنتج | الوصف الحالي | الطول |
|---|---|---:|
| Premium AI Coach Monthly | All Premium features plus multilingual AI Coach. | 48 |
| Premium AI Coach Annual | All Premium features plus multilingual AI Coach. | 48 |
| Premium Monthly | Premium nutrition, fitness, sleep and insights. | 47 |
| Premium Annual | Premium nutrition, fitness, sleep and insights. | 47 |
| AI Boost | Add 2,500 AI Coach tokens to your BIL account. | 46 |

حُفظت القيم التالية في لغة en-US بعد إزالة عناصر الإرسال القديم، ثم أُعيدت قراءة كل قيمة من صفحة منتجها. طول كل قيمة محسوب بالإنجليزية وهي دون حد Apple البالغ 45 محرفًا:

| المنتج | الوصف المحفوظ | الطول |
|---|---|---:|
| Premium الشهري والسنوي | Ad-free nutrition, fitness, sleep and trends | 44 |
| AI Coach الشهري والسنوي | 2,500 AI tokens weekly, max 10,000 monthly | 42 |
| Boost | 2,500 non-expiring AI Coach tokens | 34 |

تدعم الحصة الأسبوعية/الشهرية [نسخة المتجر في الكود](../../lib/features/commerce/presentation/bil_store_copy.dart:130)، ويدعم عدم انتهاء Boost [نص بوابة الشراء](../../lib/features/commerce/presentation/premium_route_glass_gate.dart:313).

العناصر الخمسة كانت ضمن إرسال Apple السابق `d92bf043-3499-4e1f-95e9-f050ed0f66c5` بتاريخ 4 أكتوبر 2026. جرت محاولة API لإزالتها بعد موافقة المالك؛ رفضتها Apple بحالة HTTP 409 `STATE_ERROR.ENTITY_STATE_INVALID` لأن العناصر سبق تقديمها. في قراءة لاحقة قبل الإزالة اليدوية ظلت العناصر موجودة. بعد أن أزالها المالك، قرأت صفحة الإرسال نفسها في App Store Connect: حالتها `Removed`، وتظهر العناصر السبعة كلها `Removed`، **بما فيها عنصر نسخة التطبيق ومجموعة الاشتراك إضافةً إلى المنتجات الخمسة**. لم أغيّر حالة الإرسال أو أحذف أي عنصر. دليل القراءة والقيم بعد التعديل في [سجل إزالة العناصر وتحديث أوصاف المنتجات](evidence/policy-gate-20261015/apple-full-store-update-20261016/app-store-products-after-owner-removal-20261016.json). لم أعد محاولة حذفها ولم أعد إرسال أي عنصر.

**ما بقي للمنتجات:** أوصاف en-US الجديدة محفوظة في صفحات المنتجات، لكن Apple لم تراجعها أو تعتمدها؛ لا يوجد Build مرتبط بالنسخة 1.0.0، وتظهر المنتجات ومجموعة الاشتراك حاليًا بحالة `Developer Rejected`. يلزم تجهيز Build وإجراء المراجعة المناسبة قبل وصف هذه التغييرات بأنها نافذة على المتجر. لم يُضغط `Add for Review` ولم يتغير أي سعر أو فترة أو Trial أو توفر.

## تحديث App Privacy الحي — 16 أكتوبر 2026

بناءً على طلب المالك، عُدلت إجابتان في صفحة App Privacy داخل App Store Connect ثم أُعيدت قراءة الصفحة. **تصحيح بعد مكالمة Apple:** كانت مبررات التعديل تستند جزئيًا إلى Privacy Manifests من حزمة iOS المجمعة (Google Sign-In وGoogle Mobile Ads)، لكنها لم تثبت اكتمال المطابقة السلوكية عبر جميع منصات التطبيق. Apple تصف إجابات App Privacy بأنها على مستوى التطبيق وتشمل بياناته وشركاءه عبر المنصات؛ لذلك لا يُعد هذا التعديل مصدقًا أو كافيًا للامتثال، ويجب اعتباره مؤقتًا إلى أن تُطابق ممارسات Android وiOS ومزوداتهما الفعلية. لم أغيّر الإجابات الحية بعد المكالمة.

| نوع البيانات | قبل | بعد |
|---|---|---|
| User ID | App Functionality؛ Product Personalization؛ Third-Party Advertising؛ مرتبط بالهوية؛ Tracking | App Functionality؛ Analytics؛ مرتبط بالهوية؛ **ليس Tracking** |
| Product Interaction | App Functionality؛ Analytics؛ Product Personalization؛ Third-Party Advertising؛ مرتبط بالهوية؛ Tracking | الأغراض والربط نفسها؛ **ليس Tracking** |
| Device ID | App Functionality؛ Analytics؛ Third-Party Advertising؛ مرتبط بالهوية؛ Tracking | **لم يتغير**؛ ما زال Tracking |

قراءة Preview الحية تعرض فئة **Identifiers** ضمن “Data Used to Track You”، بسبب بقاء Device ID معلنًا للتتبع. هذا يتبع إجابات ASC بعد تعديل User ID وProduct Interaction، لكنه لا يثبت صحة الملصق الكامل عبر المنصات أو السلوك الفعلي للنسخة. جرد SDK من حزمة iOS ليس بديلًا عن مطابقة البيانات التي تجمعها نسختا iOS وAndroid وكل الشركاء. لم تُحذف أنواع البيانات الـ22، ولم تتغير روابط الخصوصية أو أي فئة أخرى. الدليل الزمني: [قراءة App Privacy بعد التعديل](evidence/policy-gate-20261015/apple-full-store-update-20261016/app-privacy-revision-20261016.json) و[تصحيح نطاق المطابقة بعد مكالمة Apple](evidence/policy-gate-20261015/apple-full-store-update-20261016/app-privacy-platform-scope-correction-20261016.json).

## بوابات لم تُغلق

- **App Privacy / P0**: تغيّرت إجابتان حيتان: User ID إلى App Functionality + Analytics وبلا Tracking، وProduct Interaction بلا Tracking. التبرير المحفوظ يستند جزئيًا إلى manifests في حزمة iOS؛ **لم يثبت أن الإجابتين تمثلان سلوك التطبيق وكل شركائه عبر Android وiOS**. Device ID ما زال معلنًا Tracking. اعتراض 5.1.2(i) **غير مغلق**؛ يلزم جرد منفصل للمنصتين، ثم مطابقة الحزمة النهائية وATT قبل اعتماد أي إجابة.
- **الحزمة والمراجع**: لا توجد حزمة 36 مرفقة، ولم تُختبر بيانات المراجع على جهاز أو IPA. صور الرفع أو وجود الحساب لا يعوضان ذلك.
- **ملاءمة الصور**: حالة `COMPLETE` تثبت اكتمال رفع الملفات فقط؛ لا تثبت تطابقها مع نسخة التطبيق المعدة للرفع.
- **حالة الإرسال السابق**: سجل 4 أكتوبر يظهر الآن `Removed` لكل العناصر السبعة؛ الاعتراض التاريخي 5.1.2(i) قائم على سجل الرسالة، ولا يعني أن المشكلة أُغلقت أو أن Apple قبلت إصلاحًا. لم تُرسل رسالة أو إعادة تقديم إلى Apple.

ظل تشغيل GitHub الحالي على SHA أعلاه قائمًا؛ لم أبدأ تشغيلًا موازيًا أو أوقفه. لم تُشغّل اختبارات أو بناء، ولم يحدث commit أو push.

المراجع الرسمية: [حدود بيانات الإصدار](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)، [بيانات الشراء داخل التطبيق وحد 45 محرفًا](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information)، [قيود تعديل بيانات المنتجات المقدمة للمراجعة](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/view-and-edit-in-app-purchase-information)، و[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
