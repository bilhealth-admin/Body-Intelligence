# BIL — ملحق المراجع المستقل لبوابة سياسات Apple

تاريخ القراءة: **15 أكتوبر 2026**. المصدر المقروء: `769169f2dd00f7e3dbcbce763285d2b81c2e9d60` في `G:/BIL_Project/worktrees/bil-ios36-audit-snapshot-20261014`، على الفرع `integration/bil-qa-media-policy-20261011`. آخر تحديث معلن للنص الرسمي الكامل لـ App Review Guidelines: **8 يونيو 2026**.

هذه مراجعة مستقلة للمصدر والأدلة القائمة. لم يشغّل المراجع اختبارات أو CI أو حسابًا أو متجرًا، ولم يعدّل التطبيق. حُفظ هذا الملحق وحده بإذن الوكيل الرئيسي بعد تسليم المراجعة. لم تتغير Production أو ASC أو الأسعار أو Trial أو أدوار المستخدمين. تسجل النتائج حالة اللقطة المقروءة؛ أي إصلاح لاحق يعتمد بدليله و SHA الخاص به في سجل البوابة الرئيسي، ولا يمحو النتيجة السابقة.

`source checked` يعني أن التنفيذ أو الدليل فُحص قراءة. لا يعني `certification PASS`. معظم البنود المنطبقة أدناه **BLOCKED** على مستوى اعتماد المتجر حتى يكتمل دليل الحزمة أو الجهاز أو الخدمة أو Console المحدد. `FAIL` المصدرية تميز العيب المثبت من مجرد غياب دليل. لا توجد شهادة بأن Apple ستقبل التطبيق.

مرجع المطابقة السابق: [تكليفات 7–18](BIL_TEXT7_18_RECONCILIATION_20261015_AR.md)، [تدقيق خصوصية Apple وبياناته](BIL_20261014_APPLE_STORE_PRIVACY_METADATA_AUDIT_AR.md)، [جاهزية iOS36](BIL_IOS_36_RELEASE_CANDIDATE_READINESS_20261015_AR.md)، وملاحق Apple بتاريخ 12 و 13 أكتوبر. قرأ المراجع النص الرسمي الكامل، ولم يعد الاختبارات الشاملة 9843 أو ينسبها إلى مصدر أحدث.

## النتائج التي يجب إبقاؤها ظاهرة في البوابة

| البند | النتيجة المثبتة في اللقطة | المصدر فُحص؟ | الحكم والإجراء الأدنى |
|---|---|---|---|
| رفض 35 تحت 5.1.2(i) | تقرير 14 أكتوبر يوثق إعلان ASC عن Tracking لـ User ID و Device ID و Product Interaction بينما المصدر لا يطلب ATT. لا قراءة ASC حية جديدة في هذا التدقيق، ولا IPA36 مطابق. | نعم؛ تقرير حي مؤرخ ومصدر، وليس اتصالًا جديدًا بالمتجر | **P0/BLOCKED** لإغلاق الرفض. لا تغيّر أعلام ASC أو تضف ATT اعتمادًا على Runner أو NPA وحدهما. |
| اختلاف QA والتوقيع في الإعلان | `bil_rc_mobile_test_build.yml` يعطل الإعلان ومزوده على المنصتين؛ `bil_ios_signed_release.yml:251,453` و`bil_android_release_candidate.yml:128,223` يفرضان true. | نعم | **P1/FAIL لمطابقة إعدادات المرشح**؛ وحكم السياسة **BLOCKED**. طابق قرار الإعلانات الموثق واختبر الإعداد المقصود؛ لا توريث لدليل QA المعطل فيه الإعلان. لا يثبت ذلك مخالفة إعلان في Production. |
| جهة استقبال Coach | `supabase/functions/ai-coach/server.ts:871` يأخذ `BIL_GEMINI_VISION_ENDPOINT` أو `BIL_GEMINI_TEXT_ENDPOINT` مباشرة، و fetch يتبع redirects افتراضيًا. Vision يتحقق من HTTPS والمضيف. | نعم؛ أحيل التثبيت واختبار before/after إلى مراجع الخصوصية منعًا للتكرار | **P1/FAIL في حاجز الإعداد** وخطر بيانات **P0** إن أسيء الضبط؛ لا دليل أن Production مضبوطة خطأ. يلزم حاجز endpoint واختبار منع الإرسال لوجهة غير معلنة. |
| شروط مشروع Gemini | ترسل الوظيفة نصوصًا وسياقًا صحيًا وصورًا شخصية. نوع المشروع و Billing و DPA ومناطق المعالجة غير مثبتة هنا. | نعم للمصدر؛ لا لحساب المزود | **P0/BLOCKED للخدمة الحقيقية** حتى يثبت إعداد المعالجة. لا تفعيل لخدمة مدفوعة أو تغيير فوترة. |
| بلاغ الإعلان | `SafeContextualBannerSlot` يعرض handle.widget فقط؛ لا مسار بلاغ إعلان صريح في lib/features/ads. قد توفر Google واجهة أصلية مناسبة، دون دليل تفاعل يثبتها. | نعم للمصدر فقط | **P1/BLOCKED عند تفعيل الإعلانات** تحت 2.5.18، وليس FAIL مؤكدًا بسبب غياب زر BIL وحده. تحقق من AdChoices أو مسار دعم فعلي مختبر؛ UMP ليس بلاغ إعلان. |
| نوع حساب المطور | لا دليل حي على نوع عضوية Apple أو الكيان القانوني. BIL يصف نفسه بلياقة غير سريرية ويتعامل مع بيانات صحية اختيارية. | نعم للمصدر؛ لا للعضوية | **P1/BLOCKED للتحقق من 5.1.1(ix)**. تصنيف Health & Fitness وحده لا يثبت وجوب Organization ولا ينفيه. لا تغيير تلقائي للحساب. |

تفرق [شروط Gemini الحالية](https://ai.google.dev/gemini-api/terms) بين Paid و Unpaid، وتحظر إرسال معلومات حساسة أو شخصية إلى Unpaid؛ وتنص على أحكام مختلفة للمعالجة في Paid، وقيود مناطق واستخدام طبي. موافقة المستخدم علىالإرسال لا تحسم وحدها صلاحية إعداد المزود أو أغراض احتفاظه. هذا شرط يجب إثباته، وليس ادعاءً بأن المشروع الحي مخالف.

## المطابقة الرباعية للبيانات

| المجال | المنتج الفعلي في المصدر | Runner أو SDK | App Privacy والدليل الناقص |
|---|---|---|---|
| User ID | Supabase Auth وعلاقات المجتمع والدعم والاستخدام والاستحقاق مرتبطة بالحساب | Runner يعلن linked ووظيفةالتطبيق | Tracking القديم موثق؛ الحالة الحية الحالية **BLOCKED** |
| Device ID | رموز push و AppAttest وبيانات تشغيل بحسب المسار؛ لم يظهر وصول مباشر إلى IDFA | Runner يعلن nontracking؛ SDK الإعلان له إعلان مستقل | لا يجوز تعميم Runner على SDK؛ مطابقة artifact و ASC **BLOCKED** |
| Product Interaction | استعمال AI والدعم والتشغيل؛ DisabledProductAnalytics لا ينفي telemetry لكل SDK | Runner functionality وأغراض SDK مختلفة | المطابقة الحية **BLOCKED** |
| Health/Fitness | محلي افتراضيًا؛ اختيار HealthKit ومشاركة سياق AI بموافقة محددة | معلن بالـ Runner، مع حفظ unknown مقابل 0 | artifact والخادم و ASC **BLOCKED** |
| الصور | صورة مختارة لـ Vision بموافقة منفصلة؛ مجتمع/ملف حسب الوظيفة | Photos/Videos معلنة؛ Vision يرفض مزودًا غير Gemini | إعداد المعالجة الفعلي لم يثبت؛ لا يفترض تدريب أو Tracking تلقائيًا |
| الصوت | BILSpeechBridge.swift:110,118 يتطلب on-device recognition؛ لا raw audio إلى Gemini | لا speech_to_text في lock؛ النص يعبر موافقة Coach | جهاز/لغات ومراقبة شبكة **BLOCKED** |
| Facebook | OAuth اختياري عبر Supabase؛ لا flutter_facebook_auth أو FBSDK ظهر في lock | لا تنسب جمع FBSDK لمجرد وجود OAuth | إفصاح Meta/Auth و graph النهائي مطلوبان |
| Firebase | لا firebase_core أو firebase_messaging أو firebase_analytics في lock/iOSregistrant | APNs الأصلي موجود | حكم عميل iOS فقط؛ لا ينفي استعمال FCM فيالخلفية |
| Advertising | UMP وبالغ Free و NPA و SameAppKey=false وفصل الصحة عنالطلب | google_mobile_ads9.1.0 موجود؛ graph النهائي يحدد النسخة المحلولة | NPA لا يعني عدم جمع ID/IP/performance؛ المطابقة **BLOCKED** |

[جرد بيانات الخصوصية](../APP_STORE_PRIVACY_DATA_INVENTORY.md):189–242 يتضمن بالفعل فحص vendorZIP أصلي لـ GoogleMobileAds13.7.0 ببصمة مطابقة، دون بناء BIL. للـ SDK سبعة أنواع معلنة، منها DeviceID مع tracking=true. يميز الجرد قدرة SDK المعلنة من السلوك الفعلي؛ لا حاجة لتكرار التنزيل، ولا يصح تسميته فحص IPA36. Runner لا يحتاج نسخ صفوف SDK المستقلة لمجرد تجميعها في تقرير Xcode.

لم يظهر موصل ASC قابل للاستعمال ضمن أدوات المراجع. تظل قراءة 14 أكتوبر قراءة تاريخية معلنة، ولا يُعامل JSON محفوظ كدليل حي جديد. غياب ATT أووجود NSPrivacyTracking=false لا يثبتان وحدهما غيابالتتبع. [مسؤوليةالمطور و ATT](https://developer.apple.com/app-store/user-privacy-and-data-use/)، [إدارة AppPrivacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)، [إفصاح GoogleSDK](https://developers.google.com/admob/ios/privacy/data-disclosure).

## مفاتيح الأدلة المصدرية والاختبارات الموجودة

هذه إحالات إلى تنفيذ واختبارات موجودة، لا ادعاء بتشغيل جديد في هذا الملحق.

| المفتاح | التنفيذ | الاختبارات وحدودها |
|---|---|---|
| E1 | `lib/features/community/`، `ai_coach_feedback_service.dart`، `ai_coach_report_confirmation_sheet.dart`، `supabase/functions/ai-coach/` | moderation/reports/roles و SQL/API القائمة. Run38734170433 معزول، ولا يثبت زمن استجابة Production. |
| E2 | `lib/features/connected_health/`، `lib/features/ai_platform/services/body_twin_*`، قراء evidence والأهداف | `test/connected_health/apple_health_permission_flow_test.dart`، `test/platform_readiness/ios_healthkit_ai_privacy_disclosure_contract_test.dart`، مجموعةالصحة 25 الحالية. لا اختبارقياساتالهاتف المقصود. |
| E3 | `lib/features/commerce/`، `server_entitlement_repository.dart`، nativepurchasequeue والتحقق الخادمي | اختباراتالشراء 97 المحفوظة. لا تمثل Sandbox معاملة أوحساب مراجع على signedartifact. |
| E4 | `remote_ai_consent_coordinator.dart`، `coach_cloud_privacy_boundary.dart`، `meal_vision_consent_gate.dart`، `analyze-meal/consent.ts` و`providers/config.ts` | `remote_ai_consent_*`، `coach_remote_consent_preflight_test.dart`، `cloud_voice_privacy_contract_test.dart`. مصدرالحاجز لا يثبتنشرالخادم. |
| E5 | `account_deletion_page.dart`، `apple_credential_lifecycle.dart`، `BILAppleSignInLifecycleBridge.swift`، عاملالحذف و Apple token custody | `apple_account_deletion_contract_test.dart`، `account_deletion_apple_fallback_test.dart`، `account_deletion_cache_cleanup_test.dart`؛ إكمالالخدمةالحقيقية منفصل. |
| E6 | `pubspec.lock`، `ios/Runner/Info.plist`، `PrivacyInfo.xcprivacy`، entitlements، AdMob/UMP/AdPolicy | `apple_privacy_closure_contract_test.dart`، `apple_release_boundary_contract_test.dart`، اختبارات Ads/UMP؛ graph و runtime النهائيان منفصلان. |
| E7 | `ios/Runner/AppDelegate.swift`، `BILSpeechBridge.swift`، `BILGlobalHealthBridge.swift`، `health_storage_privacy.dart`، `project.pbxproj` | `health_storage_privacy_test.dart`، `bootstrap_health_storage_retry_test.dart`، `ios_native_runtime_safety_contract_test.dart`؛ خصائصجهازواستعادةمنفصلة. |
| E8 | تقاريرالمتاجر، `legal_document_page.dart`، `help_center_page.dart`، `/plans` الحالي و`BilDynamicStoreOffers`، `public_site/`، جردالوسائطوالتراخيص | legal/plans/privacy والصورالقائمة. Console والحقوقالخارجية لا تثبتهاالملفات وحدها. |

## سجل الانطباق الكامل

لكل صف `source checked: yes` بمعنى فحص التطبيق أو نفي الوظيفة المذكورة في اللقطة. الحالة أدناه هي **حكم اعتماد السياسة**؛ تبقى BLOCKED عند غياب دليل الحزمة/الجهاز/الخدمة/المتجر. PASS المصدرّي أدناه مصدرّي وصريح الحدود. يغطي التجميع المبرر فروع NA مع أرقامها، وليس إغفالًا لها. مرجع الأرقام: [النص الرسمي الكامل](https://developer.apple.com/app-store/review/guidelines/).

| البند والفروع | انطباق BIL ومفتاح الدليل | الحالة والخطر والدليل المتبقي |
|---|---|---|
| 1.1.1–1.1.5، 1.1.7 | المجتمع ومخرجات Coach؛ E1 | BLOCKED/P0؛ moderation والإبلاغ الفعليان |
| 1.1.6 | صدق القياسات والمراجع و unknown؛ E2 | BLOCKED/P0 للحزمة؛ لا يثبت المصدر دقة كل طعام |
| 1.2 وقائمته الكاملة | منشورات وتعليقات وردود ورسائل؛ E1 | BLOCKED/P0 للخدمة الحية والمراجع |
| 1.2.1 و(a) | الناشر مع المكافآت قد يقع ضمن CreatorContent؛ E1 والعمر 18+ | BLOCKED/P1؛ لا يوجب حذف المجتمع أو جعله مدفوعًا |
| 1.3 | BIL18+ وليس Kids؛ BilAdultEligibility | NOT APPLICABLE مشروط بتطابق ASC والتسويق |
| 1.4.1 | الصحة والغذاء و BodyTwin؛ E2 | BLOCKED/P0 لدقة الادعاءات النهائية |
| 1.4.2 | لا حاسبة جرعات دوائية؛ حاجز الأسئلة الطبية E1 | NOT APPLICABLE للوظيفة؛ منع التوصية الخطرة يبقى منطبقًا |
| 1.4.3 | لا تجارة مواد؛ UGC/AI قد يتطلب فلترة؛ E1 | BLOCKED/P1 لحماية المحتوى |
| 1.4.4 | لا DUI أو ملاحة | NOT APPLICABLE |
| 1.4.5 | تمارين وصيام وتحديات؛ E2 | BLOCKED/P1 للتعليمات الآمنة |
| 1.5 | الدعم وروابطه؛ E8 | BLOCKED/P1 للتحقق الحي |
| 1.6 | صحة ورسائل خاصة و Auth/RLS؛ E1/E4/E5 | BLOCKED/P0 للحزمة والخادم الفعليين |
| 1.7 | لا خدمة إبلاغ جرائم | NOT APPLICABLE |
| 2.1(a),(b) | المراجع والخدمات والمنتجات؛ E3/E5/E8 | BLOCKED/P0؛ لا signedreviewerjourney |
| 2.2 | TestFlight أو إصدار؛ E8 | BLOCKED/P1 عند التوزيع |
| 2.3.1(a),(b) | الإدارة و AI والمجتمع موثقة وليست مخفية؛ E1/E8 | BLOCKED/P0 لمطابقة Notes والخدمات |
| 2.3.2 | ميزات مدفوعة ومنتجات؛ E3/E8 | BLOCKED/P0 |
| 2.3.3، 2.3.4 | صور وفيديو Store من النسخة الفعلية؛ E8 | BLOCKED/P1؛ WidgetPNG ليست signedartifact |
| 2.3.5، 2.3.6 | تصنيف Health&Fitness والعمر؛ E8 | BLOCKED/P1 للـ ASC الحي |
| 2.3.7، 2.3.8 | اسم وكلمات وصور وادعاءات؛ E8 | BLOCKED/P1 |
| 2.3.9 | الحقوق وبيانات صور تركيبية؛ E8 | BLOCKED/P1 لحقوق المالك |
| 2.3.10 | مواد Apple مقابل المنصة؛ E8 | BLOCKED/P1 للمواد الحية |
| 2.3.11 | لا preorder معلوم | NOT APPLICABLE حاليًا |
| 2.3.12 | What'sNew والوظائف الحقيقية؛ E8 | BLOCKED/P1 |
| 2.3.13 | لا ASC In-AppEvent معلوم | NOT APPLICABLE حاليًا |
| 2.4.1 | TARGETED_DEVICE_FAMILY=1,2؛ E7 | BLOCKED/P1 لمصفوفة iPhone/iPad النهائية |
| 2.4.2 | طاقة وذاكرة وخلفية؛ E7 | BLOCKED/P1 لجهاز؛ لا P95 هاتف من debug |
| 2.4.3 | لا tvOS | NOT APPLICABLE |
| 2.4.4 | إرشادات الصلاحيات والعودة؛ E2/E7 | BLOCKED/P1 للمسارات الأصلية |
| 2.4.5(i)–(ix) | ليس MacAppStore target | NOT APPLICABLE |
| 2.5.1 | publicAPIs و HealthKit المقيد؛ E7 | BLOCKED/P0 للحزمة و SDK |
| 2.5.2 | native وكتالوجات بيانات، لا كود عن بعد executable ظهر | BLOCKED/P1 لفحص الحزمة؛ الصور ليست كودًا |
| 2.5.3 | أمن الحزمة والمدخلات؛ E1/E7 | BLOCKED/P0؛ الفحوص ليست شهادة خلو |
| 2.5.4 | Health/voice/push/lifecycle؛ E7 | BLOCKED/P1 للجهاز |
| 2.5.5 | HTTPS بالاسم لا يثبت IPv6-only | BLOCKED/P1 لاختبار NAT64/DNS64 |
| 2.5.6 | روابط قانونية و webview_flutter؛ E7/E8 | BLOCKED/P1 للتحقق الفعلي؛ ليس browser بديلًا معلنًا |
| 2.5.7، 2.5.10 | intentionallyomitted | NOT APPLICABLE |
| 2.5.8 | لا تغيير homeOS | NOT APPLICABLE |
| 2.5.9 | صوت وميكروفون وعودة؛ E7 | BLOCKED/P1 لنظام الجهاز |
| 2.5.11(a),(b) | لا SiriKit/Shortcuts معلن | NOT APPLICABLE |
| 2.5.12 | لا CallKit/SMSspamblocking | NOT APPLICABLE |
| 2.5.13 | لا facialauthentication خاص؛ SIWA نظامي | NOT APPLICABLE |
| 2.5.14 | صوت وكاميرا بإجراء المستخدم؛ E4/E7 | BLOCKED/P0 للجهاز؛ on-device محدد بالمصدر |
| 2.5.15 | استيراد وتصدير واختيار ملفات؛ E7 | BLOCKED/P1 لمنتقي Files/iCloud |
| 2.5.16 | إشعارات BIL وروابطها؛ E1/E7 | BLOCKED/P1 لجهاز وخدمة push |
| 2.5.17 | لا Matter | NOT APPLICABLE |
| 2.5.18 | AdMob عند التفعيل؛ E6 | BLOCKED/P0 للخصوصية و P1 للإبلاغ؛ إعداد QA مختلف |
| 3.1.1 | اشتراكات و Boost؛ E3 | BLOCKED/P0؛ credits المشتراة لا يفترض أنها تنتهي |
| 3.1.1(a) | لا رابط شراء خارجي جديد ثبت؛ Terms/Privacy/Manage مختلفة | NOT APPLICABLE للاستثناء الإقليمي دون شراء خارجي |
| 3.1.2(a),(b),(c) | اشتراك وقيمة وتغيير وعرض؛ E3/E8 | BLOCKED/P0 للمنتج والحزمة و Sandbox |
| 3.1.3(a) | BIL ليست ReaderApp لمجرد وصفات وفيديو | NOT APPLICABLE |
| 3.1.3(b) | استحقاق حساب متعدد المنصات؛ E3 | BLOCKED/P0 للملكية والعرض |
| 3.1.3(c)–(g) | لا Enterprise أو جلسات مدرب بشري مدفوعة أو سلع أو Admanagement | NOT APPLICABLE للوظائف الحالية |
| 3.1.4 | الأجهزة اختيارية؛ لا تبرر QR لفتح Premium عام | NOT APPLICABLE كاستثناء دفع المنتج الحالي |
| 3.1.5(i)–(v) | AITokens ليست cryptocurrency | NOT APPLICABLE |
| 3.2.1(i)–(viii) | لا appcatalog/rentals/Wallet/insurance/donation/gifts/financialservice | NOT APPLICABLE |
| 3.2.2(i),(iv),(vii)–(ix) | لا appmarketplace/fundraising/rankmanipulation/options/loans | NOT APPLICABLE |
| 3.2.2(ii),(vi) | omitted | NOT APPLICABLE |
| 3.2.2(iii),(v),(x) | إعلان وبلدان ومكافأة نشر؛ E1/E3/E6 | BLOCKED/P0 للتحقق؛ النشر داخل BIL ليس تقييم Store |
| 4.1(a),(b) | هوية BIL والحقوق؛ E8 | BLOCKED/P1؛ لا تدّع تزكية Apple |
| 4.2، 4.2.2، 4.2.3(i),(ii) | native بمنفعة ومحتوى تنزيل؛ E2/E7/E8 | BLOCKED/P1 لـ coldlaunch والمحتوى |
| 4.2.1 | لا ARKit | NOT APPLICABLE |
| 4.2.4، 4.2.5 | omitted | NOT APPLICABLE |
| 4.2.6، 4.2.7(a)–(e) | ليس templatefleet ولا remoteDesktopclient | NOT APPLICABLE |
| 4.3(a),(b) | تطبيق مستقل لا flavors للتلاعب | BLOCKED/P1 لبيانات المطور والتوزيع |
| 4.4، 4.4.1، 4.4.2 | لا keyboard/Safariextensiontarget | NOT APPLICABLE |
| 4.4.3، 4.6 | omitted | NOT APPLICABLE |
| 4.5.1 | لا AppleRSS/Storedataaggregation في المنتج | NOT APPLICABLE |
| 4.5.2(i)–(iii) | لا MusicKit | NOT APPLICABLE |
| 4.5.3، 4.5.4 | APNs والمجتمع والتفضيلات؛ E1/E7 | BLOCKED/P0 لخصوصية push و P1 للتسليم/الانسحاب |
| 4.5.5 | لا GameCenter | NOT APPLICABLE |
| 4.5.6 | Helpful/NotHelpful تستخدم Unicode👍👎 بخط النظام؛ لا Apple emoji asset ظهرت | PASS مصدرّيًا فقط؛ تحقق الخطوط المضمنة في الحزمة مستقل |
| 4.7، 4.7.1–4.7.5 | Coachnative مضمن؛ لا كتالوج miniapps أو بوتات قابلة للتثبيت أو remoteplugins | NOT APPLICABLE للمصدر المفحوص؛ اسم chatbot وحده لا يكفي |
| 4.8 | Google/FacebookOAuth مع SIWA مكافئ؛ E5/E7 | BLOCKED/P0 للجلسة الأصلية والاعتمادات |
| 4.9 | لا ApplePay | NOT APPLICABLE |
| 4.10 | مدفوع للتحليل أو الخدمة، لا قدرة كاميرا OS وحدها؛ E3 | BLOCKED/P1 لرحلات Free/paid |
| 5.1.1(i) | سياسات وشركاء واحتفاظ؛ E4/E6/E8 | BLOCKED/P0 للمطابقة الرباعية وشروط المزود |
| 5.1.1(ii)–(iv) | اختيار وسحب وتقليل بيانات؛ E4/E7 | BLOCKED/P0 للجهاز والخادم المنشور |
| 5.1.1(v) | local بدون دخول وحذف حساب و credentialrevocation؛ E5 | BLOCKED/P0 لحذف حساب اختبار فعلي دون تدمير reviewer |
| 5.1.1(vi),(viii) | لا passworddiscovery/publicPIIaggregation في المصدر المفحوص | PASS مصدرّيًا؛ ليس فحصًا كاملاً لشبكة SDK |
| 5.1.1(vii) | OAuth والروابط ظاهرة؛ E5/E8 | BLOCKED/P1 للتجربة الأصلية |
| 5.1.1(ix) | نوع الخدمة والكيان والمعلومات المطلوبة | BLOCKED/P1 وقرار مالك؛ لا حكم تلقائي |
| 5.1.1(x) | الهاتف لمساره؛ الخيارات الأخرى لا تفرضه؛ E5/E8 | BLOCKED/P1 للجلسات الحقيقية |
| 5.1.2(i) | AI و SDK و ATT؛ E4/E6 | BLOCKED/P0؛ رفض 35 لم يغلق رسميًا |
| 5.1.2(ii),(iii),(iv),(vi) | فصل الغرض والصحة عن الإعلان؛ E4/E6 | BLOCKED/P0 للشبكة والإعداد الحقيقي |
| 5.1.2(v) | دعوات ومشاركة اختيارية؛ E1/E7 | BLOCKED/P1 للمنتقي والمعاينة والمشاركة |
| 5.1.2(vii) | لا ApplePay | NOT APPLICABLE |
| 5.1.3(i) | HealthKit/fitness وسياق اختياري؛ E2/E4 | BLOCKED/P0 للمزود وشروط الصحة |
| 5.1.3(ii) | كتابة weight بإذن منفصل؛ استثناء backup أصلي؛ E2/E7 | BLOCKED/P0 لخصائص جهاز و restore؛ لا يتغير 35 المثبت |
| 5.1.3(iii),(iv) | لا human-subjectresearch/ResearchKit | NOT APPLICABLE |
| 5.1.4(a),(b) | 18+ وغير موجه للأطفال؛ E2/E8 | NOT APPLICABLE للمسار البالغ المتحقق؛ راقب agegate والتسويق |
| 5.1.5 | لا GPS permission في Info الحالي؛ موقع IP تقريبي من SDK مختلف | NOT APPLICABLE لـ LocationServices الحالية؛ coarseIP ضمن E6 |
| 5.2.1، 5.2.2، 5.2.3 | صور ووصفات وفيديو ومزود AI؛ E8 | BLOCKED/P1 لحقوق المواد والخدمات |
| 5.2.4، 5.2.5 | أيقونات منصة و emoji نظامي؛ E7/E8 | BLOCKED/P1 للحزمة والمتجر؛ glass ليس حكم تقليد تلقائيًا |
| 5.3.1–5.3.4 | مكافأة نشر محددة ليست رهنًا أو مسابقة عشوائية مشتراة | NOT APPLICABLE حاليًا |
| 5.4، 5.5 | لا VPN/MDM | NOT APPLICABLE |
| 5.6، 5.6.1–5.6.4 | هوية وردود وتقييمات وجودة؛ E8 | BLOCKED/P1 للعمليات و Console؛ لا Tokens مقابل StoreReview |

لا تعني NA إعفاءً دائمًا؛ تغير الوظيفة أو التسويق يعيد الانطباق. لا توجد مشكلة P2 جديدة مثبتة في هذا التدقيق؛ تفضيلات HIG والزجاج والخط لا تُرفع إلى P0 دون عيب وظيفة أو نص سياسة منطبق.

## متطلبات تقنية مستقلة وحدود الإثبات

- تطلب Apple منذ 28 أبريل 2026 **Xcode26+ و iOS/iPadOS SDK26+**؛ ومنذ 9 سبتمبر 2026 targetiOS/iPadOS13+. يحدد المصدر deployment15 و iPhone+iPad. إثبات toolchain والحزمة مستقل. [المتطلبات الحالية](https://developer.apple.com/news/upcoming-requirements/).
- Manifest التطبيق موجود في Resources، ويعلن 18 نوعًا app-owned و RequiredReason `UserDefaults/CA92.1`. لا تُضاف FileTimestamp/DiskSpace عشوائيًا؛ افحص الاستخدام والتقرير المجمّع. قائمة Apple تشمل Flutter و GoogleSignIn وعدة plugins مثبتة؛ شروط توقيع binarydependencies تطبق حيث تنطبق. [متطلبات SDK](https://developer.apple.com/support/third-party-SDK-requirements/).
- لا ATS استثناء عام ظهر في Info.plist؛ لا يغلق ذلك IPv6 أو redirects أو TLS للـ SDK.
- SIWA و HealthKit و APNs/AppAttestentitlements موجودة مع فصل debug/production. يلزم فحص signedentitlements وملف التزويد.
- HIG وتفضيل glass ليسا مخالفة مستقلة. قص نص أو زر معطل أو تسريب قيمة مدفوعة عبر semantics قد يصبح عيبًا وظيفيًا. إعلان Accessibility في ASC يحتاج دليلًا على مساراته.
- backup الأصلي يغطي ApplicationSupport/Documents/Preferences قبل الكتابة ويقرأ الصفة للتحقق. لم يثبت iCloudrestore على جهاز. لا يتغير build35 بإصلاح المصدر.
- حذف الحساب يميز pending/completed ويذكر أن فوترة المتجر مستقلة ويحمي owner عند التبديل. إكمال Storage/Auth و Apple revoke بحساب اختبار على الخادم المعني بوابة حقيقية. [مرجع الحذف](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion).

## القرار

لا أساس لإعلان إغلاق رفض Apple أو المطابقة النهائية لـ iOS36. العمل الممكن قبل التوقيع: إغلاق حاجز endpoint، وتوحيد إعداد الإعلان للمرشح المقصود وفق قرار المالك الموجود، واختبار الانحدار المتأثر، وربط جرد SDK والخصوصية بحزمة غير موقعة متاحة إن وجدت. تبقى AppPrivacy الحية، وشروط المزود، ورحلة reviewer على حزمة مطابقة، و Sandbox، والجهاز، و signedentitlements بوابات **BLOCKED** ظاهرة. ليس إذنًا لبناء موقّع أو رفع أو رد على Apple.

المصادر الأخرى التي قُرئت: [إفصاح SDK الإعلانات](https://developers.google.com/admob/ios/privacy/data-disclosure)، [استراتيجيات AdMob](https://developers.google.com/admob/ios/privacy/strategies)، [طلب HealthKit](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)، [تجميع manifests](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests). لم تُنسخ مقاطع طويلة من Apple؛ المصفوفة تحيل للأرقام وتطابقها بوظائف BIL.


## تحديث القراءة الحية ونتيجة وصف الفيديوهات — 15 أكتوبر 2026

هذا تحديث لاحق للتدقيق أعلاه، ولا يحذف القراءة الأصلية أو يعيد نسب نتائجها إلى مصدر مختلف. العبارة السابقة عن عدم توفر قراءة ASC حية تصف وقت التدقيق الأول؛ أصبح لدينا الآن دليل API حي باستخدام العميل المحضر، دون تغيير المتجر أو حساباته.

- اكتملت **27 قراءة GET** أولية لهوية التطبيق والنسخة والحقول والمنتجات، ثم **4 قراءات GET عامة محددة** للنصوص والتصنيفات والعمر ووصف الاشتراكات؛ المجموع **31 استجابة HTTP 200**. لم تنسخ بيانات دخول المراجع أو JWT أو إيصالات، ولا نزلت صور من المتجر.
- النسخة الحالية في ASC هي **1.0.0، حالتها REJECTED، ومرتبطة فعليًا بـ build 35**، المرفوع في 4 أكتوبر 2026. لا تعني هذه القراءة اختبار iOS 36 أو تغيير النسخة المثبتة 35. المنتجات الخمسة موجودة بحالة READY_TO_SUBMIT؛ لا تساوي هذه الحالة موافقة Apple أو معاملة Sandbox ناجحة.
- نصوص الوصف والاسم والعنوان الفرعي والكلمات والتصنيفات والروابط وحقول العمر وأسماء الاشتراكات ومددها محفوظة في [الدليل العام المنقح](evidence/policy-gate-20261015/asc-public-metadata-text-sanitized.json). مقياس العمر القديم 17+ والتمثيل الجديد 18+ لا يشكلان تناقضًا بذاتهما؛ [Apple تميز التقييمات بحسب إصدار النظام](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/). يلزم مطابقة إعلان الإعلانات مع إعداد حزمة 36 النهائية بصورة مستقلة.
- استجابت روابط الموقع والخصوصية والدعم والحذف والشروط والمجتمع جميعها بـ HTTP 200، ووجد محتوى قانوني مقروء ومسارات فعلية بالإنجليزية والعربية. رابط Apple EULA في وصف المتجر ورابط شروط خدمة BIL داخل الخطط لهما غرضان مختلفان، ولم يظهر تعارض مثبت بينهما. هذا فحص روابط ومحتوى، وليس إثبات استخدام متصفح أو استجابة دعم أو تنفيذ حذف حي.
- كشف الفحص أن وصف Plans كان يقصر «300+ فيديو» على التمارين المنزلية، بينما الكتالوج المعتمد **200 منزلي +102 للنادي =302 سجلًا، و301 ملفًا فريدًا**. وصف ASC العام «300+ workout videos» كان صحيحًا. صححت قيم عرض الخطط في اللغات الـ25 إلى الوصف العام مع حفظ مفاتيح الترجمة القديمة للتوافق، ودون تغيير منتج أو سعر أو Trial أو صلاحية.
- أصبح بند **ASC-M06 = PASS_SOURCE_SCOPE** بعد تشغيل الوكيل الرئيسي: **13 اختبار نسخ +2 Golden للخطط +5 Goldens لصور منتجات مراجعة Apple =20/20 PASS**، بالتشغيل العادي دون update. السجل نفسه ينتهي بـ **36/36 PASS** بعد 14 اختبار إفصاح صوتي ومسارين للتنقل. [السجل الخام](evidence/policy-gate-20261015/copy-and-pearl-visual-focused.log) وبصمته أدناه يثبتان النتيجة المحلية؛ لا تثبت Goldens حزمة موقعة أو قبول متجر. عدل هذا البند وحده في مصفوفة المطابقة، وبقيت البنود الأخرى وحدودها كما هي.

بصمة SHA-256 للسجل الخام: `984c8cb444452c5b8e9d775349ebe11eca2fcc4be542d5ac8bdce014c178ef07`.

تبقى **إجابات App Privacy الحية، ونص رسالة رفض Apple الأحدث، ومطابقة جرد التطبيق وSDK والحزمة والشبكة، ونشر قيود مزود Gemini، ورحلة حساب المراجع وSandbox على الحزمة المعنية** بوابات مستقلة لم تغلق بهذه القراءة. لا يثبت وجود رابط Privacy أو NSPrivacyTracking=false إغلاق 5.1.2(i)، ولا يصح اعتبار مصدر 36 أو اختبار محلي تعديلًا للـ binary 35 الموجودة في المتجر.

المخرجات المحفوظة: [مصفوفة المطابقة العامة](evidence/policy-gate-20261015/asc-public-metadata-source-match-20261015.json)، [حالة القراءة الحية](evidence/policy-gate-20261015/live-store-api-readback-status-20261015.json)، [إيصال إصلاح النسخ](evidence/policy-gate-20261015/workout-count-copy-fix-receipt.json)، و[قائمة الملفات والبصمات وفحص عدم الأسرار](evidence/policy-gate-20261015/asc-public-evidence-copy-manifest-20261015.json). لم ينفذ هذا التحديث أي تشغيل أو تعديل مصدر أو إعداد متجر.


## تحديث لاحق: App Privacy ورسالة الرفض مقروءتان حيًا — 15 أكتوبر 2026

ثبتت القراءة الحية من DOM الفعلي عبر Browser.tabs.get وموصل Gmail الرسمي، كما حفظ الوكيل الرئيسي في [دليل المتجر الحي](evidence/policy-gate-20261015/live-store-ui-readback-20261015.json). **App Privacy ورسالة رفض Apple لم تعودا READ_BLOCKED.** العبارات السابقة التي تفيد تعذر قراءتهما تحكي زمنها، ويحدثها هذا الملحق دون حذف الدليل التاريخي.

رفض 14 أكتوبر يخص **iOS 1.0.0/build 35** على iPad Air 11-inch (M3)، وسببه المحدد **5.1.2(i): إعلان tracking لـUser ID وDevice ID وProduct Interaction دون طلب ATT في النسخة المقدمة**. App Privacy الحالي يعلن **22 نوعًا و3 tracking**. Submission يضم **7 عناصر = تطبيق +مجموعة اشتراك +4 اشتراكات +Boost؛ أي 6 عناصر غير التطبيق**. العناصر الأخرى Ready for Review وليست approved، وحالة API للمنتجات READY_TO_SUBMIT ليست بديلًا عن حالة كيان Submission.

إعداد `.github/workflows/bil_ios_signed_release.yml:251–252,453–454` يفعل ADS_ENABLED وAD_PROVIDER_READY، وAndroid release candidate يفعلهما أيضًا، بينما مسار RC mobile QA يعطلهما. **نجاح QA بلا إعلانات لا يثبت غياب tracking في الإصدار الموقع.** gateway يضبط فعلًا `setSameAppKeyEnabled(false)` وNPA؛ هذان الشرطان لا يثبتان وحدهما غياب تتبع Apple. إعلان Runner app-owned tracking=false لا يلغي إعلان Device ID tracking=true في vendor GMA 13.7.0 المفحوص، ولا يحدد النسخة المدمجة في IPA36.

أضيفت [مطابقة رباعية تفصيلية للأنواع الـ22 وخطة قبل/بعد مشروطة للقيم الثلاث](BIL_20261015_APP_PRIVACY_FOUR_WAY_RECONCILIATION_AR.md). لا توصي بمسح علامات tracking أو إضافة ATT افتراضيًا. تثبت أولًا بيانات التطبيق وSDK وManifest وسلوك الحزمة النهائية، ثم تعرض تغييرات ASC المبررة على المالك. يبقى collected/linked/purpose قرارًا مستقلًا عن tracking؛ لا تحذف أنواعًا صحيحة لمجرد تغيير الأخير. الفرق التصنيفي Other Usage Data موثق دون الحكم بأنه عيب كود مؤكد أو حذفه لمساواة الأعداد.

**مطابقة IPA/runtime للإصدار36 وتصحيح ASC وإغلاق الرفض رسميًا ما زالت BLOCKED/P0.** أزيل عائق القراءة فقط. لم ينفذ هذا التحديث أي شبكة أو UI أو تشغيل أو بناء أو تعديل مصدر أو إعداد متجر، ولم يغير حقوق الشراء أو الحسابات أو Production.
