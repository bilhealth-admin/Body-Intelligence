# BIL 2026 — تدقيق Apple App Store وGoogle Play وAndroid الصارم
**11 أكتوبر 2026 — فحص مصدر وسياسات، وليس شهادة اعتماد متجر**

المستودع: bilhealth-admin/Body-Intelligence
فرع التدقيق المعزول: audit/bil-apple-google-review-compliance-20261011
SHA أساس الاستلام: 06c365022f20e0f0c5d6e901b19a8efb1419b81f
QA/ Codex: qa/bil-quality-ux-integration-20261009 — PR #11 مسودة غير مدموجة
تطوير الوسائط: feat/bil-native-media-review-20261011 — مستقل وغير مدموج

**حدود الإثبات:** تم تعداد 7,129 ملف blob ضمن شجرة Git بها 7,870 مدخلاً، وفحص ملفات/اختبارات/مستندات عالية المخاطر بصورة مباشرة. هذا لا يعني قراءة دلالية بشرية لكل سطر في 7,129 ملفًا. لم يتوفر Flutter SDK أو Xcode أو Android Gradle أو جهاز فعلي في جلسة التدقيق. كل حالة خضراء في التقرير هي تحقق مصدر جزئي، وليست اعتماد متجر أو بناء أو تجربة جهاز.

## 1 — صورة Flightradar24 ونموذج التقييم المطلوب

الصورة تشبه نافذة التقييم الأصلية التي يقدمها نظام Apple بواسطة StoreKit (أيقونة التطبيق، سؤال عن التجربة، 5 نجوم، Not Now). التطبيق يطلب العرض في وقت ملائم؛ Apple تقرر إن كانت ستعرض النموذج وما شكله بحسب iOS وإعدادات المستخدم. لا توجد وسيلة شرعية تضمن نسخ نفس البكسلات أو فرض ظهور النافذة. يحد Apple عرض المطالبة عادة بحد أقصى 3 مرات خلال 365 يوماً؛ طلب التقييم من داخل نسخة TestFlight لا يعرض النافذة.

في Android الصحيح هو Google Play In-App Review API: نافذة Google Play أصلية ومختلفة عن Apple. ممنوع تصميم بطاقة تشبهها أو إضافة طبقة فوقها أو سؤال «هل تحب BIL؟» لتوجيه التقييمات أو مكافأة النجوم. Google تفرض حصصاً غير معلنة؛ زر مباشر يعد بعرض popup يمكن أن يخيب توقع المستخدم عند بلوغ الحصة.

**الوضع المثبت من كود BIL:** حزمة in_app_review v2.0.12 مثبتة في pubspec، والخدمة lib/app/services/store_review_prompt_service.dart تستدعي requestReview الأصلي. توجد 3 لحظات نجاح فقط: حفظ قياس اليوم، إنهاء اليوميات، حفظ خطة. سياسة محلية محافظة: 7 أيام من أول نشاط ناجح، 5 أيام نجاح مميزة، تهدئة 180 يوم، وتأخير ثانيتين. لم أضف واجهة نجوم مقلدة. على فرع التدقيق أُضيف شرط عدم طلب العرض عند ترك التطبيق أو انتقاله للخلفية خلال التأخير، مع اختبارات وحدة جديدة؛ لم تُشغّل على Flutter بعد.

مراجع:
- https://developer.apple.com/documentation/storekit/requesting-app-store-reviews
- https://developer.apple.com/documentation/StoreKit/RequestReviewAction
- https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews
- https://developer.android.com/guide/playcore/in-app-review
- https://developer.android.com/guide/playcore/in-app-review/test
- https://pub.dev/packages/in_app_review/changelog

## 2 — مصفوفة المتطلبات، الأدلة، والباقي

| المجال والسياسة | دليل من المصدر | الحالة الفعلية |
|---|---|---|
| Apple التقييم / Google تقييم Play | native in_app_review، اختبارات StoreReview | موجود؛ تعديل foreground غير مختبر محليًا؛ سلوك متجر حقيقي معلق |
| Apple 1.2 / Google UGC | community_post_card، community_safety_page، إجراءات التقرير والحظر | موجود مصدرًا؛ اختبار تنفيذ الحظر وتصفية المحتوى ومراقبته على Backend مطلوب |
| Apple 1.4.1 ادعاءات صحية | health disclaimer، AI evidence policies | يحتاج تدقيق كل ادعاء طبي، أرقام القياس، واللقطات |
| Apple 2.1 App Completeness | reviewer notes + account gateway + QA | يتطلب تطبيقًا مثبتًا وحساب مراجع مخولًا وخدمات حيّة؛ غير معتمد |
| Google App Access/Paywall | server_entitlement_repository وملف رفض Google | **عائق P0**: آخر إخطار Google موثق بتاريخ 8 أكتوبر 2026 يشير إلى Suspended بسبب الرفض المتكرر؛ حالة Play Console الحالية غير مفحوصة |
| Apple/Google الدفع والاشتراكات | paywall terms/privacy/restore، store-managed IAP | ظاهر في المصدر؛ الأسعار/التجديد/التجربة/الاستعادة/الإلغاء الحقيقي يحتاج sandbox/store |
| Apple 5.1 الخصوصية | ios Info.plist وPrivacyInfo.xcprivacy وواجهة الخصوصية | موجود مصدرًا؛ مقارنة SDKs وApp Store Connect App Privacy مطلوبة |
| Google User Data/Data Safety | Android manifest، privacy policy وAI/ads/backend | يلزم مطابقة الإفصاح المنشور الفعلي ونقل البيانات والحذف |
| Android Health Connect | ثلاث صلاحيات READ_STEPS/READ_DISTANCE/READ_ACTIVE_CALORIES_BURNED، rationale Activity | النطاق ضيق في المصدر؛ merged manifest ونموذج Health Apps وأجهزة فعلية لم تُفحص |
| Apple HealthKit | NSHealthShare/UpdateUsageDescription وHealth screens | موجود مصدرًا؛ إلغاء الصلاحيات وإعادة منحها يحتاج أجهزة حقيقية |
| الكاميرا/المعرض/الميكروفون/BLE | iOS usage descriptions، Android optional hardware وstorage-permission removal | موجود في المصدر؛ راجع manifest المدموج والرفض/التخطي على الأجهزة |
| صور المجتمع وخصوصيتها | Storage خاص وروابط signed وإجراءات المراجعة | إثبات فعلي لحماية الروابط/عزل A→B→A والحذف مطلوب |
| الحساب والحذف | account_deletion_page وbil_request_account_deletion | الكود موجود؛ وصول العامل وحذف البيانات الفعلي ومتطلبات منصة الاشتراك غير مثبتة |
| الإعلانات والتتبع | UMP + nonPersonalizedAds + manifest بدون AD_ID/Topics | مصدر محافظ؛ مراجعة SDK runtime وملصقات الخصوصية الفعلية مطلوبة |
| Android 16KB / ABI / SDK | targetSdk 36، minSdk 26، arm64/x86_64 وrelease signing guard | مصدر موجود؛ APK/AAB/ELF فعلي غير مبني/مقاس |
| iPad/Android UX والتوطين | RTL و25 locales وHome بخمس وجهات | اختبار 320/390/430/iPad/tablet، VoiceOver/TalkBack و2× مطلوب |
| First Use + أول وجبة | عمل محلي منفصل نجحت له 175 حالة وفق تقرير سابق | غير مثبت بعد ضمن SHA النهائي، لا ينسب لـQA |
| الوسائط الأصلية متعددة الصور | فرع feat/bil-native-media-review-20261011 | غير مدموج؛ يحتاج اختبارات Native picker والكاميرا والتأكيد |
| Golden وFull8 | QA PR#11، فروق 29 مرجع | لا اعتماد جماعي ولا شهادة نجاح Full على الكود النهائي |
| البيانات المنشورة للمتاجر | Privacy/Terms/Support/Deletion URLs والمشاهد | يجب فتح URLs وفحص App Store Connect وPlay Console وسجل الأذونات |

## 3 — العوائق ذات الأولوية القصوى

**P0A: Google Play** — أحدث وثيقة محفوظة هي docs/google_play_preparation/BIL_GOOGLE_SUSPENSION_20261008_APPEAL_READINESS_AR.md وتذكر تعليق التطبيق بتاريخ 8 أكتوبر. هذا وضع تاريخي موثق وليس تأكيدًا للحالة الآن. يجب فحص Play Console بنفس صلاحية المالك. حتى إذا اجتازت كل الاختبارات فنجاح الكود لا يفك تعليق Google تلقائيًا. لا تلجأ إلى تجاوز خفي للاشتراكات أو مزايا وهمية، ولا تضع كلمات مرور المراجع على GitHub.

**P0B: الوصول للمراجعين** — حسابات المراجعة في App Store Connect وPlay Console تحتاج دخولًا متاحًا وحصصًا/استحقاقات حقيقية ومفعلة، أو تعليمات قانونية بديلة حسب المنصة. اختبر حسابًا مجانيًا ومشتركًا حقيقيًا من التثبيت حتى AI Coach وخطط الغذاء/التحليل. أصلح أي Paywall كاذب من المصدر الفعلي، لا من مظهر البطاقة فقط.

**P0C: الخصوصية والدفع** — أكمل مطابقة كل SDK/خادم مع App Privacy وData Safety وHealth Apps Declaration؛ اختبر شراء واستعادة وإلغاء التجارب بصناديق اختبار صحيحة. لا تخف أسعارًا أو تضع اشتراكًا صوريًا.

**P0D: سلامة التطبيق** — أغلِق الاختبارات المركزية والـ29 Golden واحدًا واحدًا والعمل المنفصل ثم Full8 على SHA نهائي، واختبر Apple/Android/iPad على أجهزة فعلية قبل أي إصدار.

## 4 — الحارس الآلي المحلي الجديد

المسار: tool/prebuild/store_policy_source_guard.py
الاختبارات: tool/prebuild/test_store_policy_source_guard.py

من جذر Checkout محلي: 
- python tool/prebuild/store_policy_source_guard.py --json-out build/store-policy/guard.json
- python -m unittest discover -s tool/prebuild -p test_store_policy_source_guard.py

يمسح كل ملفات Dart تحت lib بحثًا عن استدعاءات التقييم والتوجيه نحو النجوم، ويحلّل Info.plist وPrivacyInfo.xcprivacy وAndroidManifest.xml وGradle، ويفحص Health permissions وrationale وexported components، وشاشة Paywall واتفاقية المجتمع. يرفض أخطاء مصدر مؤكدة ويصدر تحذيرات للجوانب التي تحتاج أجهزة/Console. **هذا فحص استاتيكي مساعد لا يكفي لاعتماد التطبيق أو تأكيد امتثاله.**

اختبارات لاحقة عند توفر Flutter 3.44.6:
- dart format --output=none --set-exit-if-changed lib/app/services/store_review_prompt_service.dart test/app/services/store_review_prompt_service_test.dart
- flutter analyze --no-pub
- flutter test --no-pub --concurrency=1 test/app/services/store_review_prompt_service_test.dart
- iPhone/iPad development StoreKit test (لا يظهر في TestFlight) + Android Play internal track native Review API.
- اختبارات الحسابات/الدفع/الخصوصية/UGC/Health/الأذونات والتوطين، ثم المجموعات الموسعة بعد إغلاق العوائق على Revision ثابت.
- Android Gradle merged manifest، ملف AAB حقيقي وتوافق 16KB، iOS Xcode signing/PrivacyInfo على macOS.

## 5 — قواعد عدم التخريب

لا تحذف وظيفة أو صلاحية فقط ظنًا أنها مخالفة؛ اربطها بالمبدأ الرسمي وباستخدام فعلي واختبار الانحدار قبل الإزالة. لا تغيّر Home المحمي/الساعة الفضية/Log Food/5 tabs أو أسعار Trial أو حسابات المراجعين دون دليل. لا تدمج أو تنشر أو ترسل استئنافًا. كل هذا التدقيق على فرع منفصل عن Codex وعن تطوير الوسائط.

المراجع الرئيسية:
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/design/human-interface-guidelines/privacy/
- https://developer.apple.com/design/human-interface-guidelines/healthkit/
- https://support.google.com/googleplay/android-developer/answer/9876937
- https://support.google.com/googleplay/android-developer/answer/9900533
- https://support.google.com/googleplay/android-developer/answer/16679511
- https://developer.android.com/health-and-fitness/health-connect/get-started
- https://developer.android.com/about/versions/16/behavior-changes-16
