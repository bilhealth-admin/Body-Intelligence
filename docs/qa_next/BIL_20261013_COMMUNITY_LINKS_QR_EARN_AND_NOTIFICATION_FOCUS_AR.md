# المجتمع: الروابط وQR والدعوة وEarn وفتح الإشعارات — 13 أكتوبر 2026

هذا ملحق تنفيذ للمصدر المحلي في `integration/bil-qa-media-policy-20261011` فوق `e27a58984bff50b4bcf45044ea9893f344307e85`. الشجرة تتضمن إصلاحات أخرى جارية؛ HEAD وحده لا يصف المصدر الجديد. نتائج هذا الملحق **لم تُشغّل بعد عند التسليم للوكيل الرئيسي**. تشغيل الحالات والتنسيق والتحليل من الطرفية المرئية المشتركة فقط، ثم يسجل الوكيل الرئيسي البصمة والنتائج الفعلية.

## التنفيذ

| الطلب | التنفيذ الفعلي | الدليل/الاختبار المكتوب | الحالة عند التسليم |
| --- | --- | --- | --- |
| زر Earn في AI Coach | إجراء ظاهر يفتح `/community/compose?origin=earn`؛ يستهلك شرح سياسة المكافأة الموجود في المحرر، والمحفظة تبقى `/community/rewards` | `community_code_invite_earn_account_test.dart`: ضغط Earn الحقيقي ووجهته؛ صلاحية حفظ آخر رصيد لنفس الحساب | مصدر مكتوب، ينتظر تشغيل الطرفية |
| عدم تسريب A عبر A→B→A | `CommunityAccountVisit` يرقّم كل حدود الحساب المُسلّمة، وتذاكر الزيارة تحرس الطلب والنتيجة والضغط من إطار قديم | جلسات Auth SDK تركيبية حقيقية عبر MockClient؛ QR وGold والدعوة وطلب الصداقة والإشعار | fixture محلي، لا ادعاء Production |
| QR/share | رمز عضو opaque قابل للتدوير؛ مشاركة الرابط العام عبر SharePlus القائم؛ single-flight حتى إغلاق ورقة النظام؛ حراسة الضغط القديم والتدوير | استدعاء قناة SharePlus الفعلية `dev.fluttercommunity.plus/share` مع origin للنظام ورفض/إعادة محاولة؛ رمز QR ثم parser القائم | ليست ورقة مشاركة هاتف أو اختبار كاميرا فعلي |
| الرمز غير المتاح | يعود `null` إلى واجهة لا تكشف الهوية ولا تسمح بطلب صداقة | حالة widget مستقلة؛ لا تحويل null إلى خطأ أو تفصيل يسمح بإحصاء الحسابات | ينتظر التشغيل |
| قبول دعوة صريح | مشاهدة الرابط لا تقبل ولا تنشئ صداقة؛ الضغط محفوظ single-flight؛ حساب قديم لا يستهلك قبولًا جديدًا بعد تسجيل الدخول | نقر متكرر، فشل ثم إعادة محاولة، نتائج A المتأخرة بعد A→B→A | ينتظر التشغيل |
| روابط التنزيل والدعوة | landing scoped جديد بلغة en/ar، يتيح Open in BIL الصريح؛ لا fetch للمستخدم ولا قبول أو منح عند GET؛ لا App Store ID مختلق | `community_links.test.mjs`: URL model وDOM fixture، لغتان، userinfo/port/تكرار/حقول إضافية/رموز فاسدة | DOM fixture، وليس موقعًا منشورًا |
| ارتباط نظامي | Android exact `/download` HTTPS منفصل؛ AASA component يحد member بطول 32؛ parser داخل التطبيق يتحقق hex | worker fixtures، مولد associations، `verified_links_and_analytics_test.dart` | لا نشر AASA/worker ولا ادعاء installed universal link |
| فتح comment/reply المقصود من الإشعار | metadata يوّجه إلى `/community/content/:postId?comment=:commentId`؛ UUID صارم/query واحدة؛ `/community/post/:postId` يظل إيصال المالك الخاص | الضغط من CommunityNotificationsPage ثم تفاصيل المنشور الفعلية، حدّ الرسم وhit-test للتعليق | ينتظر التشغيل |
| الوصول والحذف | lookup جديد بلا feed cache، approved+visible فقط؛ stats يتحقق من عقد social visibility أيضًا؛ إعادة تحقق قبل الرسم، عند التحديث واستئناف التطبيق؛ التعليق/الأصل المزال لا يعاد بناؤه من النسخة القديمة | pending/rejected/hidden، سحب الوصول بين lookup وstats، block، حذف الأصل، resume | RLS production لا يثبت بالfixture |
| التعليق خارج الصفحة الأولى | مسح القراءة المأذونة `bil_social_comments_v2` بصفحات 100 حتى التعليق؛ root/reply من v3 الحالية، fallback إلى v2 عند `PGRST202`/`42883` فقط | root105 وreply110 خارج أول30 root وpreview3، cursor صحيح، عدم التكرار، فقد v3، cursor لا يتقدم | لا RPC جديد أو GRANT جديد |
| عدم حبس المنشور | المنشور يبقى مقروءًا، وتحميل التعليق منفصل مع إلغاء وإعادة محاولة؛ النتيجة المتأخرة لا تكتب بعد الإلغاء | pending scan + Cancel + Retry؛ فشل القراءة؛ A→B→A | ينتظر التشغيل |
| التصميم والوصول | إجراء Earn وQR min48، شاشة320 وخط2×، عربي/إنجليزي وفاتح/داكن؛ focus thread يبنى مستقلاً لتمرير الرد حتى مع أصل طويل | 4 حالات layout في ملف QR/Earn، وتحقق viewport في ملف إشعارات المحتوى | لا تحديث Goldens ولا ادعاء صورة جهاز |

## حدود التكلفة والتوافق

جداول social_v2 تسحب SELECT المباشر من authenticated، وتتحقق migrations من غياب هذا GRANT. لم نوسع RLS أو نفترض أن قراءة anchor مباشرة متاحة. القارئ يستعمل RPCات القراءة القائمة وبمعناها الأصلي. تكلفة تحديد تعليق بعيد خطية في عدد الصفحات المأذونة، وليست O(1). كل صفحة تحرس الحساب والإلغاء، ويلزم أن يتقدم cursor؛ يمكن للمستخدم قراءة المنشور وإيقاف تحميل التعليق والرجوع وإعادة المحاولة. لا spinner يمنع الوصول إلى الصفحة بسبب مسح التعليق.

v2 لا تحمل reply_count الإجمالي في عقدها القديم؛ يظل مجهولًا، ولا نشتق إجماليًا من preview واحدة. pagination تحفظ cursor الحقيقي للصفحة المسطحة في fallback، فلا تسقط صفحات عندما تقل الجذور بسبب الردود. لا قيد مالي، لا AI credit، لا توكنات جديدة ولا تغيير السياسة الاقتصادية.

التحقق الحالي يكرر قراءة الوصول قبل الرسم والتحديث وعند resume. لا نعد بأن إعادة رسم بيانات معروضة سلفًا تحصل فور كل سحب صلاحية في الخلفية دون حدث وارد؛ تفويض كل طلب يبقى في الخادم. اختبار realtime/hardware والـartifact المنشور منفصل عن اختبارات هذا الملحق.

## الملفات

- UI: `community_gold_balance_action.dart`, `community_account_visit.dart`, `community_bil_code_page.dart`, `community_invite_landing_page.dart`.
- إشعارات: `community_notification_destination.dart`, `community_notification_content_loader.dart`, `community_notification_content_page.dart` (جزء من hub), `community_notifications_page.dart`, `community_hub_page.dart`, `community_post_detail_page.dart`, `community_post_detail_rendering.dart`, `community_deep_link.dart`, `app_community_routes.dart`.
- الروابط: `AndroidManifest.xml`, `bil_verified_links_configuration.dart`, `generate_app_link_associations.py`, `bilhealth_site_worker.mjs`, `public_site/community_links.mjs`, `app.js`, `styles.css`.
- الاختبارات: `community_code_invite_earn_account_test.dart`, `community_notification_content_route_test.dart`, `community_bil_code_and_saves_contract_test.dart` (هوية synthetic صريحة دون تغيير التوقعات), `community_notification_auth_session_test.dart` (إضافة مسار الوجهة الجديد دون حذف حراسة الحساب), `verified_links_and_analytics_test.dart`, `community_links.test.mjs`, `bilhealth_site_worker.test.mjs`.

النسخ القبلية محفوظة في `build/stage1-closure/community-before` قبل التعديل. لم يشغّل هذا الوكيل أي test أو format أو analyze، ولم ينشر أو يدخل حسابًا حيًا أو يرسل دعوة/رسالة/منحة. قائمة حالات الاختبار والأوامر ونتيجة التشغيل الفعلية تُضاف من الوكيل الرئيسي بعد الطرفية المرئية.

## ما يحتاج التفعيل/الجهاز لاحقًا

1. نشر الملفات العامة وassociation documents مع worker المعدّل في إصدار واحد بعد موافقة المالك؛ تحميل worker الجديدة مع AASA القديمة يرفض gate عمدًا.
2. تزويد meta `bil-app-store-url` برابط App Store العام الحقيقي بعد توثيقه؛ لا يعرض المصدر الجديد App Store button بلا معرف مؤكد.
3. إعادة اختبار universal/app link بعد تثبيت artifact تتضمن intent filter/parser الحالية، مع حافظة association systems واحتمال تأخير cache المنصة.
4. اختبار ورقة iPad/iPhone/Android المشاركة والكاميرا وفتح الإشعار من OS فعليًا، فوق اختبار قناة SharePlus وSDK fixture.
5. تشغيل الحالات المركزة ثم الملفين ثم المتأثر (notification/comment/social/codes/invites/Earn/launch links)، والتنسيق والتحليل الكامل من الطرفية المرئية. لا تنسب نجاح سابق للشجرة الجديدة.

مصادر النظام الرسمي التي بُني عليها العقد، تاريخ القراءة 2026-10-13: [Android App Links](https://developer.android.com/training/app-links/add-applinks)، [Apple Universal Links: query components](https://developer.apple.com/videos/play/wwdc2019/717/)، [Apple Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains).

## تحديث الوكيل الرئيسي بعد المراجعة المستقلة

كشف تشغيل واجهة الإشعار أن بدء مهمة focus داخل zone لعملية تحميل تنتهي قد يلغي المهمة التابعة فورًا. أصبحت البداية بعد الإطار مع فحص المالك والجيل، وإلغاء typed عند تقاعد الزيارة. اختبار SDK مباشر يثبت قراءة صفحة الردود، واختبار Flutter يضغط الإشعار ويصل إلى التعليق خارج الصفحة الأولى ويعود.

كشفت مراجعة لاحقة علم _rotationSubmitted يبقى بعد A→B أو A→B→A أثناء RPC تدوير الرمز. أعاد الاختبار إنتاج مؤشر دائم واستثناء إلغاء غير معالج. تُصفّر حالة العرض عند حدود الحساب وإعادة الربط، ويُراقب Future المتقاعد دون تغيير خطأ FutureBuilder الحالي أو زر Retry. اجتازت الحالة المركزة وملف QR/Earn الكامل 19 حالة دون فشل أو skip في focused-plan16. لا نشر أو التزام باسم حساب سابق.

ملف المحتوى يتضمن اختبارات SDK ووظيفة وواجهة، فلا يسمى كل عدد فيه widgetcases. ملفات التنفيذ والتوقيت والبصمة ونتيجة المجموعة الأخيرة والتحليل تُحال إلى ملحق الإغلاق في [تقرير الحسابات الأربعة](BIL_20261013_FOUR_ACCOUNT_COMMUNITY_REAL_E2E_AR.md). الغياب عن هاتف وOS camera/share/push يبقى حدًا فعليًا.
