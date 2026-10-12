# ملحق 3 — Apple والخصوصية والصحة والواجهة

تاريخ القراءة 12 أكتوبر 2026 ؛المراجع `/root/store_review_apple` مستقل قراءة فقط. اللقطةالكاملة 9656 ملفًا فوق 2c518ee4 تشملالتعديلات؛بصمة v4`d47f536bf052cd139f94aa6da0295f1a74dcd70e82ef29fd2029370773c75b36`. لا كتابة أو اختبار أو بناء أو حساب حي أو متجر. أصلحهاالوكيلالرئيسيلاحقًا بعدإذنالمالكوقبل Full ؛الإصلاحاتليستنتائجلهذاالتدقيق.

المراجع قرأ AppReviewGuidelines كاملة؛آخر تحديثمعلن 8 يونيو 2026 ،واسترجاعها 12 أكتوبر 2026.

**P1 بالمصدر:** SQLite الصحيةفي ApplicationSupport بلااستثناء backup صريح. القاعدةتحتويالوزن/الماء/الوجبات/القياسات/السياق. يشملالنطاق legacy/scopedDB و WAL/SHM ، bil_global_platform.sqlite3 ، bil_cloud_ledger_v1.sqlite ،نسخال recovery والصورالخاصة وكاشالمجتمع. افحص Library/Preferences لحفظالأرشيفوالتفضيلاتالحساسة. لا دليلنسخ iCloud فعليأوتسربقديم؛الفجوةفيتحكمالمصدر. إصلاحهابتعيين nativeisExcludedFromBackup علىالآباءقبلالكتابةوالإعادةعند startup/restore ،بلا deletion أونقلفقديإلى Caches. العلمتوجيهللنظام،وليسضمانًامطلقًا؛تحتاجخصائصملفاتعلى iPhone/iPad واستعادة.

[Apple5.1.3(ii)](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research)،[نسخ iCloud](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup).

| بند Guidelines | الانطباق / نوعه | الدليل والإجراء الأدنى |
|---|---|---|
|1.1/1.2|UGC إلزامي|بلاغوحظرومراجعة،لا يكفيفصل UI ؛يثبت response تشغيلي/contact والعمر|
|1.4.1/1.4.5|health/safety إلزامي|المراجعوالمجهولمصونةبالمصدر؛لاادعاءتشخيصودقةجهازبلاطبي/documentation|
|1.5/1.6|دعم/أمنإلزامي|تفويضخادمي/session والعزل؛الدعم metadata والخادم بحاجةدليل فعلي|
|2.1/2.3|اكتمال/vocabulary/حساب/metadata إلزامي|كافةحساباتالأدواروهاردويرو Notes ،لا falseStory أورصيد fake ؛ artifact غيرموجود|
|2.2/2.4/2.5|beta/compat/native/permissions|iPadgoldens لاتثبت native الجهاز؛ UIKit/HealthKit/ميكروفون permissions لحظةالاستعمال|
|3.1.1/3.1.2/3.1.3(b)|IAP والاشتراكوالاستعادة/تعددمنصات|تمييزالاشتراك/Boost/Pending ؛ expiredpurchaseaccount ؛ nativeStoreKitSandbox وليس Fakepass|
|4.1–4.3/4.8/4.10|هوية/منفعة/Login/بيعقدرة OS|Applelogin موجود؛لااشتراكمقابل camera قدرةالنظاموحدها؛حساب فعليو metadata|
|5.1.1/5.1.2(i)|خصوصيةو thirdpartyAI إلزامي|Coach يعلن Gemini والسياقو consentversion3 ؛ Visionconsent مستقل؛يلزممطابقة publishedbackend وال DataPrivacy|
|5.1.3(ii)|health/iCloud إلزامي|الفجوةالمحددةفي backup تُصلحقبل 36 ؛لاادعاءحدثت 35 تلقائيًا|
|5.2/5.6|IP/Developerconduct إلزامي|راجع licenses والوسائط/metadata ،لاحوافز TestFlight/review ولاالتفافبالإخفاء|
|1.2.1/4.4–4.7/5.1.4/5.1.5|مشروط|creator/extensions/remoteprogram/kids/location بحسبالفعل؛ nativeCoach ليس miniapp تلقائيًا|
|جرعات/crypto/gambling/VPN/MDM بقيةالفئات|غيرمنطبقعلىالوظائف الموصوفة|يعادالحكمإنأضيفتوظيفة؛ليسضمانمطابقةجميعمحتويات UGC|

مكتمل بالمصدر:AI إفصاحوموافقةإيجابيةمتبوعبقراءةإيصال policy3 ،الخادميفحصها قبل provider ؛ Vision منفصلة. HealthKit أوصافالأذونات؛ authorizationindeterminate لايتحولإلىرفضأوصفر. حذفالحسابيميز pending عن completed ولايدعيإلغاءمتجر؛عامل Storage قبل Auth ومسار Applecredentialrevoke. لا يثبت worker منشورًاأو deadline الحذف/UGC/احتفاظحسابقديم. UMP+Freeadult/nonpersonalizedads+publisherfirstpartyoff بالمصدر؛الـ SDKgraph و AppPrivacy يحتاجانفحص artifact والممارسةالفعلية.

ملاحظة اشتراك إضافية:actual`/plans`→BilDynamicStoreOffers يعرض Restore/Manage ؛لا Terms/Privacy في footer. الروابطفي CommercePaywall قديم،واختبارالمصدريفحصه. ليستحكمرفضمؤكد(قدتوجدفي settings)؛التحسينالأدنىروابط واضحةفعالةفيالرحلةالحقيقيةواختبارضغط. [عرضالاشتراك](https://developer.apple.com/app-store/subscriptions/).

المتطلبات التقنية الحالية:sourceiOS15 ،بوابة Xcode26+/SDK26+؛لم يُبنَ archive موقع/SDKgraph/PrivacyManifests/signatures لـ 36. [مواعيدالنشر](https://developer.apple.com/news/upcoming-requirements/)،[SDKmanifests](https://developer.apple.com/support/third-party-SDK-requirements/). Manifest التطبيقالحالي tracking=false ويعلن health/fitness و CA92.1UserDefaults ؛لايحل محل composedmanifest لكل SDK.

Golden:ثبت 258 قرارمرجعو 260promotion فردي؛ 180/200 أعيدافردهـمابعدتصحيحالتداخل،وصورةالساعةالمرفوضةلميُعتمدبديلها. المراجع فحصصورمختارة Home/Today/watch/dock/AIipad258/recipe/320Arabic2x/firstmealreducedmotion ،ولميدعِفحصكل 258 بصريًامرةثانية. القيمتحت mask محميةمن semantics/focus/tooltip/selection ؛الحدود/التفاعلالفعليبالاختباراتالمحددة. نتائج 420/8/70 متداخلة،و 1292 أقدم؛ Widget ليسجهازًاأو build35. HIG وتفضيل Glass ليساحكمرفضتلقائيًا. Accessibilitylabels طوعية؛إنادعيتدعمًافأثبتجميع commonworkflows علىكلمعلنجهازومكبرخط. [Accessibility](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels).

الحسابات الفعليةغير مختبرة. جهز content/purchaseexpired/adminisolated ؛ PaidAppsAgreement نشطو StoreKitSandbox ،وأي BLE/AppleWatch يتطلبفيديوجهاز Apple متفاعلفعلي.[CompleteReview](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/)،[IAPconfigure](https://developer.apple.com/help/app-review/before-submitting-for-review/configure-in-app-purchases/).

انتهى التدقيقعلى d47 ؛لا ضمانقبول Apple. الآثارالمثبتةوالإصلاحاتالمحليةاللاحقةوالفحصالفعليللجهازتبقىمستوياتدليلمختلفة.
