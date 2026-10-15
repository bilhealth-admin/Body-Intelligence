# تجهيز بيانات Apple — 16 أكتوبر 2026

## تصحيح لاحق ملزم لتصنيف الحسابات — 16 أكتوبر

صحح المالك التصنيف: عنوانا Gmail المذكوران في القسم التاريخي أدناه **حسابان شخصيان للاختبار، وليسا حسابَي مراجعة متجر**. لذلك المقارنة السابقة بهما وعبارة `MISMATCH_TO_INTENDED_REVIEWERS` **ليستا عيبًا مثبتًا في بيانات Apple، ويُسحب ذلك الاستنتاج**. لا يجوز تعيينهما للمتجر أو إنشاء منح أو تعديل أدوار بسبب تلك المقارنة. لم ينفذ مؤلف هذا التقرير أي تعيين أو منحة أو تعديل أدوار، ولا يعكس هذا التصحيح ترحيل سياسة المالك أو يلغيها.

قراءة ASC عند `2026-10-15T23:02:10Z` ثم `23:03:32Z` أثبتت وجود **حساب متجر مخصص** في demoAccountName وكلمة مرور موجودة. طابق اسم الحساب حقل `$.appReviewInformation.demoAccountName` في ملف إعداد مراجعة Apple بتاريخ29 أغسطس، وكذلك مراجع Google/setup القديمة؛ أُبلغ المعرّف نفسه للوكيل الرئيسي في المحادثة الخاصة بالمهمة، ولم يُنسخ هنا إلى مستند Git. هذه مطابقة هوية إعداد، وليست إثبات نجاح تسجيل دخول. ملف الإعداد التاريخي لا يصلح لاعتماد كلمة المرور الحالية أو استبدالها. لم تُحفظ بصمة username/password في قراءة22:40، لذلك لا يمكن إثبات عدم تغير هذين الحقلين منذ ذلك الوقت من المقارنة القديمة وحدها.

بصمة Notes بقيت دون تغيير عن22:40: `f12d151521d0ca36dde2e6783c525ce393165765978d6ac6b8eb2c513acc5536`. والنص الحالي يوجه فعلًا إلى المسار الصحيح: `3. Tap Sign in > Store reviewer access.`، ولا يوجه إلى OTP. **لا حاجة لإضافة فقرة الحالة التشغيلية المقترحة أدناه لمجرد التحضير؛ تبقى غير منفذة، ولا تُعتمد كتصحيح لوصول المراجع.** يلزم أي تعديل لاحق أن يعالج معلومة نافعة ومثبتة للمراجع، لا أن يملأ الحقل المحدود.

حُضّر helper محلي داخل `.tmp/` المتجاهلة من Git للتحقق العادي بكلمة المرور، ولم يُنفذ اتصال Auth. الوضع الافتراضي خطة بلا شبكة؛ التنفيذ يحتاج موافقة الوكيل الرئيسي المحددة، ويقتصر على قراءة بيانات ASC في الذاكرة ثم password login وقراءة `/auth/v1/user` وخروج `scope=local` للجلسة الجديدة. لا reset أو impersonation أو service-role أو DB/RPC أو منح أو تغيير أدوار. تصحيح الهوية لا يغير موانع artifact/runtime/App Privacy المذكورة أدناه. تبقى الأقسام التالية سجل القراءة والاستنتاج السابق مع أسبقية هذا التصحيح.

## النتيجة والنطاق

**اكتملت إعادة قراءة البيانات العامة والروابط والمنتجات؛ لا تحتاج الحقول الصحيحة إلى إعادة كتابة.** توجد مسودة إضافة دقيقة إلى Notes for Review أدناه، جاهزة لمراجعة الوكيل الرئيسي قبل الحفظ. لم ينفذ مؤلف هذا التقرير أي تعديل في App Store Connect. لم يتغير حساب دخول أو استحقاق أو رصيد أو سعر أو Trial أو build، ولم يُرسل رد مراجعة أو طلب Review.

المصدر المقروء هو worktree `G:/BIL_Project/worktrees/bil-ios36-audit-snapshot-20261014`، الفرع `integration/bil-qa-media-policy-20261011` وHEAD `ed963053c62cc549cbe50757279bd39d73a10e35`، مع الفروق المحلية الموجودة محفوظة. لم تُعدَّل مصادر أو إعدادات أو اختبارات أو Goldens، ولم تُشغَّل اختبارات أو بناء أو commit. يخص هذا التقرير تجهيز Apple؛ نشر Production الذي يتابعه الوكيل الرئيسي نطاق مستقل.

أُجريت **18 قراءة ASC GET ناجحة** بين `2026-10-15T22:40:57Z` و`2026-10-15T22:42:53Z`، أي صباح 16 أكتوبر بتوقيت القاهرة، و**7 قراءات GET عامة** للروابط. استُخدم عميل ASC المحضر وبيانات اعتماده داخليًا؛ لم تُطبع مفاتيح أو JWT أو كلمات مرور أو النص الخام لتعليمات الدخول. لم يُستخدم browser أو Cua. المخرجات العامة أدناه من الاستجابات الحية؛ لا تستبدل اختبار artifact أو رحلة مراجع.

## هوية التطبيق والبناء الحية

| الحقل | القيمة المقروءة |
|---|---|
| التطبيق | `6805349703` — Body Intelligence Log |
| Bundle ID | `com.bilhealth.bodyintelligencelog` |
| الإصدار | iOS `1.0.0`؛ `7a132506-d5a8-4810-a51f-b2dc2bd636cf` |
| الحالة | `REJECTED`؛ releaseType=`MANUAL` |
| build المرتبط فعليًا | `35`؛ ID=`e695f185-2e54-4196-9153-a55653518cc2` |
| رفع 35 | `2026-10-04T13:41:17-07:00`؛ processing=`VALID` |
| usesIdfa | `false`؛ لا يثبت غياب tracking ولا يحل استبيان App Privacy |
| مرشح 36 | لم يضفه هذا العمل ولم يرفعه؛ الأدلة المحلية لا تغير build 35 |

رسالة الرفض وApp Privacy لم تُفتحا مجددًا بهذا الوكيل. أحدث دليل UI موثق من الوكيل الرئيسي هو [دليل 15 أكتوبر](evidence/policy-gate-20261015/live-store-ui-readback-20261015.json): رفض 14 أكتوبر تحت **5.1.2(i)**، على iPad Air 11-inch (M3)، بسبب إعلان tracking لـUser ID وDevice ID وProduct Interaction دون ATT في build 35. لا يزال إغلاق هذا الرفض غير مثبت.

## الحقول العامة: الحالي والقرار

| الحقل/الكيان | الحالي الحي | المقترح |
|---|---|---|
| AppInfo localization | `2ed17031-9665-4f8f-9a75-e4efd2e4e178`؛ `en-US` فقط | إبقاء |
| الاسم | `Body Intelligence Log` | إبقاء |
| Subtitle | `Nutrition, Fitness & Progress` | إبقاء |
| الفئة | `HEALTH_AND_FITNESS` ثم `LIFESTYLE` | إبقاء |
| Version localization | `3866ba6c-b637-4f70-9c53-d6274c37bc62`؛ `en-US` فقط | إبقاء |
| Keywords | `nutrition,food,calories,macros,weight,fitness,habits,progress,wellness,workouts,hydration,sleep` | إبقاء |
| Promotional Text | `Build a clearer picture of your nutrition, activity, and progress—with transparent, evidence-based insights and no medical diagnosis.` | إبقاء |
| Description | يذكر Apple Health بإذن، 1,500 وصفة، 300+ فيديو تمرين، AI باسم Google Gemini وموافقة صريحة، موافقة منفصلة للصورة، مجتمعًا للمسجلين، IAP اختياريًا و25 لغة وحدودًا صحية | إبقاء؛ لا استبدال بالمسودة المحلية الأقدم |
| What's New | `null` في الإصدار الأول `1.0.0` | لا اختراع نص نجاح أو إصلاح build لم يضف |
| Privacy Policy | `https://www.bilhealth.com/privacy` | إبقاء |
| Privacy Choices | `https://www.bilhealth.com/account-deletion` | إبقاء؛ صفحة الحذف خيار خصوصية مفهوم |
| Support | `https://www.bilhealth.com/support` | إبقاء |
| Marketing | `https://www.bilhealth.com/` | إبقاء |
| الشروط في الوصف | Apple standard EULA | إبقاء؛ شروط خدمة BIL غرض مستقل |
| Community Guidelines | `https://www.bilhealth.com/community-guidelines` | إبقاء |

الوصف الحي يطابق نص [لقطة 15 أكتوبر المنقحة](evidence/policy-gate-20261015/asc-public-metadata-text-sanitized.json). بصمة SHA-256 للنص UTF-8 في تلك اللقطة، الذي قورنت به القراءة الحية: `a0fc1131bb50ed0b0419ef987fac458ea38d9df66259001b72de39334247eb8d`، وحجمه `2813` بايت. هذا ليس حارسًا لتعديل مقترح؛ لا يوجد تعديل وصف مطلوب.

المطابقة المصدرية الأحدث محفوظة في [مصفوفة الحقول](evidence/policy-gate-20261015/asc-public-metadata-source-match-20261015.json): `ASC-M02–M07/M09/M11–M16/M18–M20` مثبتة في نطاقها المصدرّي/الثابت. الدليل لا يحول `M08/M10` أو رحلة الحساب أو الشبكة إلى PASS. عدد 300+ يصف مجموع المنزل والنادي، وتدقيق الكتالوج يميز 302 سجلًا عن 301 ملفًا فريدًا. لا سبب لإعادة صياغته أو حذف العدد الصحيح.

الروابط السبعة أعلاه ومعها `https://www.bilhealth.com/terms` وApple EULA أُعيدت قراءتها ضمن المجموعة: **home/privacy/support/account-deletion/terms/community-guidelines/EULA =7/7 HTTP 200**. الصفحات الست التابعة لـBIL أعادت نفس بصمات [قراءة 15 أكتوبر](evidence/policy-gate-20261015/asc-public-links-live-sanitized.json)، مع ظهور Gemini وبريد الدعم في HTML. لم يُختبر المتصفح أو إرسال الدعم أو تنفيذ الحذف. اختلاف نطاق Apple EULA عن شروط خدمة BIL لا يشكل تعارضًا مثبتًا.

العمر الحالي: التمثيل القديم 17+، وoverrideV2=`EIGHTEEN_PLUS`، والبرازيل 18؛ `advertising=true` و`healthOrWellnessTopics=true` و`messagingAndChat=true` و`socialMedia=true` و`userGeneratedContent=true`. لا يُغيَّر advertising اعتمادًا على QA الذي يعطل الإعلانات؛ مطابقة إعداد الإصدار الفعلي مستقلة.

## المنتجات والصور

| SKU / ASC ID | المدة أو النوع | الاسم العام الحالي en-US | الوصف العام الحالي | القرار |
|---|---|---|---|---|
| `bil_premium` / `6806555342` | `ONE_MONTH` | BIL Premium Monthly | Premium nutrition, fitness, sleep and insights. | إبقاء |
| `bil_premium_annual` / `6806555198` | `ONE_YEAR` | BIL Premium Annual | Premium nutrition, fitness, sleep and insights. | إبقاء |
| `bil_premium_ai_coach` / `6806555282` | `ONE_MONTH` | BIL Premium + AI Coach Monthly | All Premium features plus multilingual AI Coach. | إبقاء |
| `bil_premium_ai_coach_annual` / `6806555344` | `ONE_YEAR` | BIL Premium + AI Coach Annual | All Premium features plus multilingual AI Coach. | إبقاء |
| `bil_ai_boost` / `6806561724` | `CONSUMABLE` | BIL AI Boost — 2,500 Tokens | Add 2,500 AI Coach tokens to your BIL account. | إبقاء |

جميع المنتجات الخمسة **READY_TO_SUBMIT**، وlocalizations=`PREPARE_FOR_SUBMISSION`، وملاحظات مراجعة المنتج موجودة. هذه قيم كيانات مختلفة عن Ready for Review في قائمة Submission، وليست موافقة أو معاملة Sandbox. **MISSING_METADATA التاريخية تجاوزتها القراءة الحالية**؛ لا تُخمن خانة مفقودة أو تعاد كتابة الأسعار/التجربة لمعالجتها. مجموعة `22343739` هي BIL Membership؛ localization=`ab15a1b5-4192-4f58-9171-cd89aa5e9674`، الاسم BIL Membership وcustomAppName=BIL Premium. لم يُثبت نقص يبرر تعديلها.

تربط [معرّفات المنتجات بالمصدر](../../lib/features/commerce/domain/store_catalog_configuration.dart)، وتوضح [وراثة الخطة](../../lib/features/commerce/domain/paid_plan_catalog.dart:15) أن AI Coach يضم Premium مع صلاحية AI/حصة يحددها الخادم. [نسخ Boost](../../lib/features/commerce/presentation/bil_store_copy.dart:133) تعرض 2,500 token. لا تُستنتج قيمة سعر أو Trial من هذه القراءة، ولم تُقرأ أو تُغيّر إعداداتها.

صور `APP_IPHONE_67` عددها8 وحالتها COMPLETE، و`APP_IPAD_PRO_3GEN_129` عددها8 وحالتها COMPLETE. لم تُنزَّل أو تُفحص الصور بصريًا هنا؛ اكتمال التسليم لا يثبت مطابقتها لمرشح36. لا تعديل صور مقترح من العد وحده.

## حساب الدخول وNotes: الفجوة الدقيقة

كيان App Review Detail هو `ce559d08-1073-4d88-9887-7f31d1951533`. الحقول الأربعة للتواصل موجودة، وdemoAccountRequired=`true`، واسم الدخول وكلمة مروره موجودان. **الاسم الحالي بعد trim/lowercase لا يطابق أيًا من** `dr.kadem.nana@gmail.com` و`bilhealth.app@gmail.com`. لا تُنشر قيمته هنا ولا يُحكم بأن كلمة مروره خاطئة؛ لم تُختبر جلسة فعلية.

حسابا المراجعة المقصودان منفصلان عن المالك/الإدارة `kademcom@yahoo.com`. لا يُعيَّن أحدهما تلقائيًا لحساب شراء منتهٍ أو صلاحية محتوى دون دليل، ولا يُبدَّل username مع إبقاء password قد لا يطابقه. لا يحتاج هذا النقص إلى تعطيل إغلاق الحقول العامة الصحيحة. تزويد بيانات مطابقة والتحقق من الوصول/الحصة على artifact خطوة منفصلة؛ لم تُنفذ منحة حساب أو رصيد أو تغيير Owner.

النص الحالي لـNotes طوله `2905` محارف و`2917` بايت UTF-8، وبصمته `f12d151521d0ca36dde2e6783c525ce393165765978d6ac6b8eb2c513acc5536`. تحققت فحوص نصية محددة من ذكر Premium وAI وHealth ومن عبارة عن عدم الحاجة للشراء؛ لم يُطبع النص الخام، ولم يثبت ذلك صلاحية الوصول. النص لا يذكر أيًا من عناوين الحسابات الثلاثة المقصودة، ولم تطابقه فحوص المصطلحات لـadmin/UGC/separate-account. لذلك يقترح الملحق تعريف حالة تجهيز36 والأدوار وحدود التحقق، مع حفظ تعليمات الدخول الحالية حتى التوفيق الآمن بينها وبين الحساب الصحيح.

## JSON مقترح دقيق قبل أي كتابة

هذه **خطة تنفيذ للوكيل الرئيسي، وليست عملية PATCH نُفذت**. الحقول العامة والمنتجات الصحيحة لا تحتاج mutation. يُعاد GET للحالة والبناء وNotes مباشرة قبل الحفظ؛ إذا لم تطابق الحراس تتوقف هذه العملية وحدها وتراجع الفروق، دون استبدالها بتخمين. قيمة Notes الجديدة محددة بدقة بأنها `oldNotes + appendText`؛ الحارس والبصمة بعد الإضافة يحددان النتيجة دون نسخ تعليمات دخول حساسة في هذا التقرير.

```json
{
  "publicMetadataPatches": [],
  "subscriptionMetadataPatches": [],
  "privacyQuestionnairePatches": [],
  "reviewCredentialPatches": [],
  "notesProposal": {
    "endpoint": "/v1/appStoreReviewDetails/ce559d08-1073-4d88-9887-7f31d1951533",
    "methodAfterRootReview": "PATCH",
    "type": "appStoreReviewDetails",
    "id": "ce559d08-1073-4d88-9887-7f31d1951533",
    "operation": "APPEND_EXACT_TEXT_IF_SHA256_MATCHES",
    "guards": {
      "appId": "6805349703",
      "versionId": "7a132506-d5a8-4810-a51f-b2dc2bd636cf",
      "versionState": "REJECTED",
      "attachedBuildNumber": "35",
      "expectedBeforeSha256": "f12d151521d0ca36dde2e6783c525ce393165765978d6ac6b8eb2c513acc5536",
      "beforeUtf8Bytes": 2917
    },
    "appendText": "\n\nCandidate 36 preparation (not submitted): build 36 has not been uploaded or added to this App Store Connect version. The currently attached build remains 35; these preparation notes do not establish a fix to its privacy rejection.\n\nIn the candidate source, community reporting and blocking are available in the app. Moderation and administrative support tools require server-authorized roles; an ordinary subscription does not grant an administrative role. Remote AI uses Google Gemini and requires explicit consent. Health/device readings require compatible hardware and system permissions.\n\nReviewer sign-in assignment, feature access and AI balance still require verification on the intended artifact. This note does not assert successful reviewer login or grant any account entitlement or balance.",
    "expectedAfterSha256": "915ee3943c8d979620d7507c57d1e8c9b56d1e953a4f2f1ed613385b8ec0647f",
    "afterUtf8Bytes": 3720,
    "maximumUtf8Bytes": 4000,
    "allowedAttributes": ["notes"],
    "accountFieldsChanged": false,
    "priceOrTrialChanged": false,
    "buildRelationshipChanged": false,
    "executed": false
  }
}
```

لا تشمل الإضافة صياغة أن36 اختُبرت أو أن35 تغيرت، ولا تدعي تحقق حساب/حصة أو إغلاق رفض. بصمة النهاية حُسبت في الذاكرة من Notes الحية دون كتابة النص الحساس إلى ملف. عند التنفيذ المصرح للوكيل الرئيسي يكون body من نوع `appStoreReviewDetails` والـid أعلاه و`attributes.notes` وحدها مساوية للسلسلة الناتجة؛ ثم GET والتحقق من البصمة والحجم والحقول غير المستهدفة. لا يتضمن هذا التقرير موافقة جديدة مطلوبة من المالك؛ الكتابة داخل تفويضه الحالي، بعد مراجعة الوكيل الرئيسي للقيمة المحددة.

تستند فقرة الأدوار إلى [حدود خطة Free](../../lib/features/commerce/domain/free_plan.dart:20)، و[بوابة المجتمع](../../lib/features/community/presentation/community_entry_gate.dart:24)، و[قراءة المحتوى بصلاحية المشرف](../../lib/features/community/activity_rewards/community_moderation_content_loader.dart:7)، و[نسخ إدارة المشرفين](../../lib/features/admin/presentation/community_moderator_admin_panel.dart:76). تشير فقرة AI إلى [منسق الموافقة](../../lib/features/intelligence_center/services/remote_ai_consent_coordinator.dart:16) و[مسودة ملاحظات الأدوار السابقة](BIL_20261011_STORE_REVIEW_TEXTS_AND_TIMING_AR_EN.md:39). هذه أدلة مصدر ونصوص، ولا تدعي نشرًا أو جلسة فعلية.

## الموانع المستقلة التي لا تعالجها إعادة كتابة وصف صحيح

| البوابة | الحالة والمعنى |
|---|---|
| Ordinary description/legal/public links/products | **PASS_READBACK / NO_CHANGE_NEEDED** في النطاق أعلاه |
| الحساب المعيّن في حقل Sign-in | **MISMATCH_TO_INTENDED_REVIEWERS**؛ الاسم الحالي مختلف، والـpassword موجود فقط؛ لا تغيير أحادي للاسم |
| الوصول الفعلي للمراجع وAI | **UNVERIFIED_ON_ARTIFACT**؛ لا منحة ولا شراء ولا رصيد ولا اختبار حساب هنا |
| App Privacy | الدليل الحي السابق22 نوعًا و3 tracking؛ التعديل **BLOCKED_BY_BEHAVIOR_EVIDENCE**؛ لا أعلام false مقترحة |
| مصدر SDK الفعلي | [جرد82fc المجمّع](evidence/policy-gate-20261015/ci-regressions-20261016/compiled-ios-82fc/proof.json): GMA13.11.0 وUMP3.1.0 و31 Manifest، واتحاد22 نوعًا. لا تعتمد13.7.0 التاريخية بدلًا منه |
| tracking وpurposes | [المطابقة الرباعية المحدثة](BIL_20261015_APP_PRIVACY_FOUR_WAY_RECONCILIATION_AR.md) تثبت اختلافات Device ID وUser ID وProduct Interaction، وأغراض DeveloperAdvertising وAnalytics؛ NPA وSameAppKey=false لا يحسمان الإجابات |
| Other Usage Data | مصدر التصريح في هذه الحزمة Google Sign-In؛ التصنيف التاريخي المجهول تجاوزته إضافة16 أكتوبر؛ لا حذف للنوع أو صف Runner عشوائي |
| سلوك مرشح36 النهائي | الـSimulator الموثق ADS=false لا يثبت شبكة الإعلانات لمسار الإصدار؛ اختبار Keychain فشل بـ-34018 قبل بقية المسارات. لا runtime PASS للإصدار الموقع |
| build36/TestFlight/review | لم يُرفع أو يضف هذا العمل build، ولم يختبر توقيع متجر أو Sandbox أو جهاز أو يرسل للمراجعة |

أُعيدت قراءة المراجع الرسمية الآن: تطلب [Apple اكتمال الوصول وبيانات دقيقة](https://developer.apple.com/app-store/review/guidelines/) وشرح الوظائف غير البديهية في Notes؛ وتحدد [مساعدة حقول الإصدار](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/) حد Notes بـ**4000 بايت** وحسابًا لا تنتهي صلاحيته وبيانات الحسابات الإضافية داخل Notes. يطلب [دليل المراجعة الكاملة](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/) حسابًا باشتراك منتهٍ لاختبار مسار الشراء، وتفاصيل الأدوار والخدمات الخارجية والعتاد. توضح [App Privacy الرسمية](https://developer.apple.com/app-store/app-privacy-details/) أن الإجابات تشمل شركاءSDK، وأن collected وlinked وpurpose وtracking قرارات مستقلة؛ تغييرها لا يشترط رفع update، لكنه يشترط دقتها. لذلك غياب build36 لا يمنع تصحيح قيمة ثبتت، بينما نقص دليل السلوك يمنع اختراع قيم tracking.

المخرج الوحيد الذي كتبه مؤلف هذا العمل هو هذا التقرير. انتهى نطاق القراءة والتجهيز؛ لا متابعة تلقائية أو تعديل مصدر أو اختبار أو رفع أو إرسال.
