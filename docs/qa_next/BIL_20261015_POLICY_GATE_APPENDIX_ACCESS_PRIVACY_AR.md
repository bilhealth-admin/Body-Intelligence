# ملحق بوابة السياسات: الوصول والموافقات وخصوصية AI

تاريخ القراءة: 15 أكتوبر 2026. المراجع المستقل: `/root/reviewer_privacy_gate`.

- المستودع: `bilhealth-admin/Body-Intelligence`.
- الفرع: `integration/bil-qa-media-policy-20261011`.
- المصدر الذي تمت مراجعته: `769169f2dd00f7e3dbcbce763285d2b81c2e9d60`.
- نسخة العمل: `G:/BIL_Project/worktrees/bil-ios36-audit-snapshot-20261014`.
- النطاق: الوصول المدفوع والمجاني، حسابات المراجعين، حدود موافقات النص والصوت والصور والبيانات الصحية، وطابور بلاغات Coach.

المراجعة قرائية؛ لم يشغّل المراجع اختبارًا أو CI، ولم يستعمل حسابًا حيًا أو يغيّر Supabase أو متجرًا. أُذن لاحقًا بحفظ هذا الملحق فقط. أرقام الأسطر أدناه تخص المصدر المقروء، وقد تتحرك بعد الإصلاح اللاحق. الأدلة السابقة تُنسب إلى مصادرها، ولا تتحول إلى إثبات هاتف أو حزمة موقعة.

## القرار المباشر

لم يثبت عيب Paywall جديد من هذه القراءة. اكتُشف عيب حقيقي في تقييد متلقي بيانات Coach، وسلّمه المراجع للوكيل الرئيسي. أصلحه الوكيل الرئيسي محليًا بعد القراءة، وأبلغ بنتيجة 10 حالات تفشل قبل الإصلاح و10 تنجح بعده. لا يمثل ذلك اجتياز كل الاختبارات المتأثرة أو نشر الإصلاح أو اختبار الحزمة النهائية.

الحسابات الحقيقية وأدوارها والخادم المستهدف وحركة البيانات في الحزمة الموقعة ما زالت **BLOCKED** في نطاق هذا الملحق. لا يصح وصف رفض Google أو Apple بأنه مغلق رسميًا بناءً على هذه القراءة.

## 1. عيب متلقي بيانات AI وتصحيحه المحلي اللاحق

### ما اكتُشف على 769169f2

في `supabase/functions/ai-coach/server.ts:870` تؤخذ `BIL_GEMINI_VISION_ENDPOINT` ثم `BIL_GEMINI_TEXT_ENDPOINT` وتستعمل مباشرة. استدعاء `fetcher` عند السطر 881 لا يقيّد HTTPS أو المضيف ولا يمنع التحويلات الافتراضية.

واجهة الموافقة تسمي Google Gemini صراحة في `lib/features/intelligence_center/presentation/intelligence_query_flow.dart:657`، وتعدد البيانات عند السطر 672. يسمح إعداد خادم خاطئ بإرسال السؤال والسياق الصحي ومفتاح Gemini إلى متلقٍ غير مشمول بالموافقة. لم يثبت المراجع أن Production يستعمل عنوانًا خاطئًا أو يسرّب بيانات.

صور الوجبات لديها تحقق من المضيف الأول في `supabase/functions/analyze-meal/providers/config.ts:50`، لكن `supabase/functions/analyze-meal/index.ts:279` كان يسمح بتحويلات HTTP الافتراضية. هذه فجوة في حد المتلقي؛ لم يثبت تحويل فعلي لدى Google.

### الإصلاح الذي نفذه الوكيل الرئيسي محليًا

أضاف الوكيل الرئيسي حدًا مشتركًا في `supabase/functions/_shared/ai_provider_recipient.ts`، مع رفض المتلقي غير المسموح، واستعمال `redirect: "error"` في Coach وMeal Vision. أبلغ بنتيجة إعادة إنتاج محلية: **10 حالات فشلت قبل الإصلاح، و10 نجحت بعده**.

هذا إثبات اختبار مركز محلي كما سلّمه الوكيل الرئيسي، وليس اختبارًا شغّله هذا المراجع. مراجعة النتيجة النهائية على SHA المحفوظ، ونتيجة المسارات المتأثرة وGitHub والنشر، مسؤولية التقرير الجامع. لا تُنسب نتيجة ما بعد الإصلاح إلى 769169f2 الذي كشف العيب.

الحالات المطلوبة لهذا الحد تشمل: عنوان HTTP، ومضيفًا آخر، وuserinfo، وport/query/hash غير متوقعة، وصفر fetch للعناوين المرفوضة، ونجاح عنوان Google الطبيعي، ورفض redirect، وبقاء fallback لدى Google، ومنع تحويل صورة الوجبة إلى جهة أخرى.

التصنيف: **P0 عند الاكتشاف؛ إصلاح محلي مركز مُبلّغ، واعتماد المصدر النهائي والخدمة والحزمة يحتاج أدلته الخاصة**. ينطبق متطلب الإذن قبل مشاركة البيانات مع AI خارجي في [Apple 5.1.2(i)](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing)، قرئ في 15 أكتوبر 2026.

## 2. حسابات المراجعة والأدوار التاريخية

المصدر الحالي يوثق حسابي مراجعة هما `dr.kadem.nana@gmail.com` و`bilhealth.app@gmail.com`، ومالك الإدارة `kademcom@yahoo.com`. هذه هويات غير سرية؛ لا كلمات مرور أو JWT أو إيصالات في هذا الملف.

- `supabase/migrations/20260906120000_owner_approved_second_administrator.sql:21` يحدد الحساب الثاني، ثم يضيفه إلى `private.bil_ai_coach_admins` وإلى `public.bil_community_moderators` عند السطر 61.
- `supabase/migrations/20260906100000_community_moderation_reviewer_and_message_privacy.sql:13` أضاف الحساب التاريخي `play-review@bilhealth.com` إلى المشرفين.
- `supabase/migrations/20261015090000_restore_single_owner_administrator.sql:30` يعطّل Admin لكل من عدا المالك، لكنه لا يزيل صفوف Moderator.

الاستنتاج يخص سلسلة المصدر: تصحيح Admin لا يثبت أن حساب المراجع أصبح بلا دور إشراف. ولا يثبت الحالة الحية أو يمنح تلقائيًا Financial Admin. Premium وStore Reviewer وCommunity Moderator وApplication Administrator وFinancial Administrator تبقى مفاهيم مستقلة.

الحالة: **P0 BLOCKED لتهيئة الحسابات بأقل الصلاحيات**. الخطة هي readback حي مأذون، للمعرّفات والأدوار والمنح ومددها فقط، ثم عرض إجراء محدد للمالك إذا وجد دور زائد. لا يتضمن هذا الملحق SQL mutation، أو حذف كل المشرفين، أو تعديل صلاحيات حقيقية. موافقة التطوير ليست تفويضًا بتغيير هذه الحسابات في هذه المرحلة.

الاختبار `test/features/admin/community_moderator_admin_contract_test.dart:88` يختبر إزالة Admin فقط. الإضافة المفيدة للبوابة هي اختبار سلسلة migrations على هويات تركيبية قديمة يعرض Admin وModerator بصورة مستقلة، دون جعل غياب بريد المراجع من migration الأحدث دليلًا كافيًا.

## 3. مسارات الوصول وما يمكن إعادة استخدامه

| النطاق | التنفيذ في المصدر المقروء | اختبار موجود يمكن إعادة استخدام دليله |
|---|---|---|
| انتظار الاستحقاق لا يحوّل المراجع تلقائيًا إلى Plans | `lib/features/commerce/presentation/premium_route_glass_gate.dart:190`؛ checking/unavailable قبل العرض المدفوع | `test/features/commerce/premium_route_unverified_retry_test.dart:14` و`:99` |
| Premium يفتح المسارات المشتركة | نفس gate؛ الوصول بعد التحقق من server authority | الاختبار السابق يغطي 15 نوع ميزة |
| Coach يعتمد رصيدًا موثقًا، وBoost مستقل عن الاشتراك | `premium_route_glass_gate.dart:183`؛ `lib/features/commerce/providers/commerce_providers.dart:374` | `test/features/commerce/ai_coach_credit_access_policy_test.dart` |
| Community مجاني | `premium_route_glass_gate.dart:74` يعيد child قبل قراءة billing | `test/features/community/free_friendship_access_contract_test.dart` |
| تبديل الحساب لا يرث النتيجة السابقة | `commerce_providers.dart:34` و`:224`؛ repository داخل `CommunityOwnerOperation` | `test/features/commerce/server_entitlement_owner_epoch_test.dart:59`؛ `verified_subscription_access_test.dart` |
| إعادة الفتح مع استحقاق سابق موثق | `lib/features/commerce/repositories/verified_entitlement_continuity_store.dart:54`؛ owner وbilling boundary | `verified_entitlement_continuity_store_test.dart:59` و`:85` |
| Free أو الإبطال الموثق يمسح الاستمرارية | `server_entitlement_repository.dart:319`؛ continuity stores | `verified_entitlement_session_cache_test.dart:56` |
| مدخل Goals ظاهر، وتخصيص التغذية محمي | `lib/app/router/app_router.dart:450` و`:453` | اختبارات settings exact expiry وpremium goal triggers |
| Analytics الأساسي منفصل عن Nutrition Analytics المدفوع | `app_router.dart:322` و`:618` | `test/p3_e5_006_analytics_premium_state_gate_test.dart` |
| الدايت المجاني لا يرث قفل المدفوع | `lib/features/nutrition_plans/presentation/nutrition_pathway_access_gate.dart:27` | `test/features/nutrition_plans/nutrition_pathway_access_policy_test.dart` |

هذه مطابقة مصدر واختبارات موجودة، لا نجاح رحلة الحساب الحقيقي على Android 33 أو iOS 36. لا حاجة إلى إعادة كل هذه الملفات لمجرد إضافة اسم بوابة سياسة؛ يُربط كل دليل ببصمة ملفاته وSHA تشغيله.

## 4. الموافقات والسحب وحدود النص والصوت والصور والصحة

- `lib/features/intelligence_center/services/remote_ai_consent_coordinator.dart:74` يقفل السحب فورًا ويثبته محليًا قبل انتظار الشبكة.
- `_grantCurrent` عند السطر 134 لا يفتح بعد الحفظ فقط؛ يقرأ موافقة policy v3 ويتحقق منها.
- مراقبة auth عند السطر 260 تمنع ردًا متأخرًا بعد A→B→A.
- `lib/features/intelligence_center/services/local_model_gateway_io.dart:299` يتحقق من الموافقة قبل بناء السياق وإرسال الطلب.
- `supabase/functions/ai-coach/server.ts:1058` يعيد فحص الموافقة في الخادم قبل الحجز أو المزود.
- `lib/features/intelligence_center/services/coach_cloud_privacy_boundary.dart:200` يسقط السياق غير اللازم ويحدد مجموعات البيانات، بدل إرسال السياق كله افتراضيًا.
- صورة الوجبة لها موافقة مستقلة في `lib/features/nutrition/presentation/meal_vision_consent_gate.dart:19`. الخادم يفحص receipt في `analyze-meal/index.ts:147` ويمنع مزودًا غير Gemini عند السطر 107.
- الصوت الخام مرفوض في `ai-coach/server.ts:1057`؛ المرسل هو النص المتعرف عليه. iOS يطلب on-device speech في `ios/Runner/BILSpeechBridge.swift:116`، وغياب الدعم لا يتحول بصمت إلى صوت سحابي من BIL.

الاختبارات الموجودة: `remote_ai_consent_orchestration_test.dart`، `remote_ai_consent_withdrawal_test.dart`، `remote_ai_consent_auth_session_test.dart`، `coach_remote_consent_preflight_test.dart`، و`cloud_voice_privacy_contract_test.dart` داخل `test/features/intelligence_center/`، إضافة إلى `test/platform_readiness/ios_healthkit_ai_privacy_disclosure_contract_test.dart`.

هذه أدلة للحدود المحلية والعقود؛ لا تثبت حركة SDK الفعلية أو تطابق App Privacy الحي. لا تغلق 5.1.2(i) بالكامل دون اعتماد إصلاح المتلقي والتحقق من الخدمة والحزمة المستهدفة. بيانات HealthKit والصورة والصوت لها حدود مستقلة في الدليل؛ لا يعتبر نجاح النص نجاحًا لبقيتها.

## 5. بلاغ Coach وطابور المراجعة

الزر ليس تجميليًا في العقد المختبر المعزول:

- `lib/features/intelligence_center/presentation/ai_coach_report_confirmation_sheet.dart:223` يوضح أن الإجابة المختارة والملاحظة فقط تصلان لمشرفي BIL وقد تتضمنان معلومات صحية.
- `lib/features/intelligence_center/services/ai_coach_safety_report_service.dart:58` يستعمل RPC المنتج.
- الإدخال والطابور والقرار في `supabase/migrations/20261014100000_ai_coach_safety_reports_v1.sql:67` و`:150` و`:181`.
- الطابور يتطلب `private.bil_lock_community_authority_v1`؛ يمنع مراجعة البلاغ الذاتي.
- عند القرار، يمسح `answer_text` و`user_note` عند السطر 225.
- اختبار GoTrue/RPC الحقيقي: `supabase/tests/local_supabase_product_rpc_e2e_test.mjs:67`؛ وصول البلاغ للطابور عند `:107`، والتكرار والمسح عند `:117`، وسحب صلاحية الجلسة عند `:132`.

الدليل السابق: [run 38734170433](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38734170433)، في نطاق Supabase المعزول المعلن بالتقرير الجامع. يمكن إعادة استخدامه إذا ثبت عدم تغير ملفات هذا العقد؛ لا حاجة لتكراره لمجرد إنشاء الملحق. **Production ووقت الاستجابة البشرية والحساب الفعلي: BLOCKED** حتى readback واختبار بيئة المراجعة المأذونة. وجود طابور برمجي لا يثبت معالجة البلاغات في وقت مناسب تشغيليًا.

## 6. APPLE & GOOGLE REVIEWER JOURNEY E2E

| الخطوة | ما يعاد استخدامه محليًا | الإثبات النهائي المتبقي |
|---|---|---|
| First Launch → Onboarding → Skip | `onboarding_flow_widget_test.dart`؛ `onboarding_review_mode_test.dart`؛ `first_use_reference_journey_test.dart` | تثبيت نظيف للحزمة النهائية |
| Login → Home | عقود auth/OAuth وowner-epoch | الحساب الحقيقي والجلسة الباردة والبلد وOTP |
| Goals → Premium → Analytics | shared gate وsettings expiry وanalytics tests | ضغط الوظائف الفعلية بالمراجع، بلا Plans خاطئ |
| Body Twin | trusted snapshot pipeline وdashboard trust tests | بيانات تركيبية معروفة، وحماية القيم المدفوعة عن Free |
| AI Coach | credit/access وconsent وlifecycle | رد فعلي على الحزمة، وصول ثابت ورصيد كافٍ، الرفض ثم السحب |
| AI Vision | consent/provider/quota tests | صورة تركيبية فعلية ومراجعة النتيجة، بلا تسجيل قبل التأكيد |
| Community | Free access وRPC/role tests | منشور تركيبي وبلاغ وحظر بأقل دور، دون Admin |
| Privacy | consent UI وlegal truth tests | إفصاحات الحزمة والخدمات وConsole متطابقة |
| Delete Account | `account_deletion_apple_fallback_test.dart` وعقود الحذف | حساب إتلافي منفصل؛ لا حذف حساب المراجعة الأساسي |
| Logout → Login → Reopen | owner isolation وcold continuity | لا بيانات للحساب السابق، ووصول المراجع مستمر |

الإضافة المفيدة بعد إصلاح المتلقي هي اختبار رحلة تنقل مركب يجمع loading→verified reviewer→Free→reviewer ويضغط وظائف فعلية، بدل الاكتفاء بعرض child نصي داخل gate. هذا اقتراح اختبار للوكيل الرئيسي، وليس نتيجة تنفيذ من المراجع.

يبقى اختبار signed artifact والحساب الحقيقي **BLOCKED**. متطلبات [Apple 2.1](https://developer.apple.com/app-store/review/guidelines/#app-completeness)، المقروءة في 15 أكتوبر 2026، تشمل وصول المراجع وخدمات خلفية متاحة؛ فتح عناوين الصفحات وحده لا يكفي.

## 7. قرار الجاهزية ضمن هذا النطاق

| البند | الحالة وحدودها |
|---|---|
| عيب recipient المكتشف على 769169f2 | إصلاح محلي مركز أبلغ به root؛ 10 قبل FAIL ثم 10 بعد PASS؛ GitHub والخدمة والحزمة لا تُفترض |
| فصل Admin عن Premium | موجود في المصدر؛ لا يثبت أدوار الحسابات الحية |
| Moderator التاريخي للمراجع | P0 BLOCKED؛ readback وخطة أقل صلاحية، دون mutation |
| Paywall/loading/Free/owner continuity | لا عيب مصدر جديد مؤكد من القراءة؛ الاختبارات السابقة تحتاج نسبتها الصحيحة |
| حدود موافقات النص والصورة والصوت والصحة | موجودة في المصدر، مع ضرورة اعتماد إصلاح المتلقي والتحقق من السلوك الفعلي |
| بلاغ AI يصل لمراجعة معزولة | دليل RPC حقيقي سابق؛ التشغيل البشري والخدمة المراجعة والحزمة BLOCKED |
| حسابا Store Reviewer على Android 33 وiOS 36 | لم يختبرهما هذا المراجع على artifact أو جهاز؛ BLOCKED |
| إغلاق رفض Google/Apple رسميًا | غير مثبت؛ لا Appeal أو رد متجر أو تغيير Console نفذ في هذه المراجعة |

لا يمنح هذا الملحق شهادة قبول متجر أو نجاح حزمة لم تُختبر. يوضع مع أدلة الوكيل الرئيسي وبقية الملاحق، ويُحفظ الفرق بين صلاحية المصدر للاختبار، وصحة الخادم المعزول، ونشر الخدمات، واختبار الحساب والحزمة الموقعة.


## تحديث الوكيل الرئيسي: تنفيذ سلسلة الأدوار المعزولة

أضيف الاختبار الدائم `supabase/tests/reviewer_administrator_moderator_chain_test.mjs`، ونفّذ الترحيلين الأصليين كاملين داخل PGlite0.5.8/PostgreSQL18.3 WASM ببيانات تركيبية فقط. نجحت **10/10 assertions**: المالك Admin الفعّال الوحيد، وغياب المالك يرفض مع rollback، والفهرس يرفض ثاني Admin فعّال، وإعادة التنفيذ مستقرة، ولا تتغير الاستحقاقات أو الأرصدة. هذا ليس اختبار RLS أوRPC ولا Production PostgreSQL17.

**الملاحظة المؤثرة أُثبتت في سلسلة المصدر:** هوية `bilhealth.app` التركيبية فقدت Admin وبقيت Moderator؛ لا يحوّل نجاح الاختبار هذه الزيادة إلى امتثال. [الإيصال والبصمات](evidence/policy-gate-20261015/reviewer-administrator-moderator-sql-result.json) يفصل SQL_REGRESSION=PASS عن COMPLIANCE=BLOCKED. المستخدم العادي بقي بلا Premium أوAdmin أوModerator أوTokens إضافية، والمشرف المستقل محفوظ.

لم تُقرأ صفوف الحسابات الحية ولم تتغير Production. وفق قيد المهمة على Production، خطة الإغلاق المحددة هي readback محدود للـUUID/الدور/الحق/مدته والحصة، ثم موافقة منفصلة على إزالة عضوية Moderator الزائدة بالـUUID الدقيق إن ثبت أنها غير مقصودة. لا إزالة لكل المشرفين، ولا إلغاء اشتراك أو رصيد. حساب مراجعة Premium يبقى منفصلًا عن حساب إشراف المحتوى وعن إدارة مالية ببيانات مراجعة معزولة ومعلنة.
