# BIL 2026 — تسليم تنفيذي نهائي إلى Codex: إصلاح التطبيق محليًا ثم QA كامل ثم iOS 37 / Android 33

**الأولوية: أمر المالك في 16 أكتوبر 2026، وهذا هو نطاق العمل الكامل لهذه الدفعة. اقرأ هذا الملف كاملًا، بما فيه شروط الرفض والقبول، ولا تعتمد على ملخص الرسالة الصغيرة.**
**هذا المستند وثيقة تكليف فقط، وليس إصلاحًا أو نجاح اختبارات أو اعتماد إصدار.**
المستودع: `bilhealth-admin/Body-Intelligence`؛ فرع التنفيذ **الوحيد** `integration/bil-qa-media-policy-20261011`.
SHA المرجعي قبل إنشاء وثيقة التسليم هذه: `9fc42c1f71d960030eaec1c0be9883c042450ad8`. اقرأ أحدث HEAD المحلي والبعيد قبل كل تعديل/اختبار/كوميت؛ لا تستخدم SHA التاريخي وكأنه HEAD الحالي. لا فرع مؤقت جديد، لا `main`، لا `reset --hard`، لا `clean -fd`، لا force push، ولا فقدان أي تعديل محلي قائم. **لا تحريك HEAD أو commit تلقائيًا أثناء الإصلاح والاختبارات**. كوميت وثيقة التسليم المنفصل من ChatGPT ليس كوميت اعتماد المنتج، ولا يعني نجاح أي اختبار.

## 0. عقد العمل والأمان — غير قابل للتفاوض

1. استلم الحالة الموجودة دون إعادة التطوير من الصفر. احصر `git status --porcelain=v1`، `git branch --show-current`، `git rev-parse HEAD`، `git rev-parse origin/integration/bil-qa-media-policy-20261011`، وملفات worktree غير الملتزمة؛ احتفظ بها وصالحها، ولا تكتب فوقها. إذا تغيّر HEAD بواسطة عملية أخرى، أوقف الكتابة، قارِن، ثم استأنف بالمصدر الصحيح. أوقف فقط أتمتة التحريك الآلي للكوميت/HEAD، لا اختبارات المستخدم الجاري تشغيلها، ولا تتجاوز hooks.
2. **التنفيذ الحقيقي أولًا محليًا**: أصلح Flutter/Dart وSwift وAndroid والاختبارات المتأثرة على Worktree المستخدم مع تشغيل محلي فعلي. لا ترفع كوميت منتج ولا تبني نسخة متجر حتى تثبت النتائج. لا تكتفِ بكتابة تعليمات أو وصف «تم الإصلاح» أو اختبارات نصية تبحث عن سلسلة في الملف.
3. احفظ `Dashboard/Home` بصريًا ووظيفيًا، وشريط الأيقونات **الخمس**، و`Log Food`، ونظام الشراء والاشتراكات وTrial والأسعار والحقوق والأرصدة وموافقة إرسال البيانات للذكاء الاصطناعي. لا تغيّر نوع الحساب أو صلاحيات المستخدم لتجاوز خطأ. احفظ بيانات المستخدم والمحفظة/Gold وAI credits وتاريخ المحادثة قبل/بعد، ولا تمس `main` أو Google Play Production. لا حذف للصورة/الملفات أو إعادة توليد Golden baseline لجعل الاختبار يمر.
4. صحح تدفقات الكود والأخطاء التي رآها المالك على **iPhone حقيقي / نسخة TestFlight 36**، لا تخمّن أنها محض مشكلة بيئة CI. صيانة IA Coach واجهات الهاتف منفصلة عن خدمة Supabase السحابية.
5. افحص Production **قراءة فقط** ومطابقتها لكود Edge Functions/Migrations/Storage/Auth/RLS/Realtime/AI credits والبيانات/الرصيد الحالي دون سحب بيانات المستخدم الخام أو أسراره إلى Git. أي نشر تغييرات سحابية ضرورية يتم فقط بعد إصلاحات واختبارات فعالة وقرار منفصل واضح بالمخاطر والنسخ والرجوع، ولا تُجرِّب إصلاح 503 بتبديل API keys أو تعطيل ضمانات.
6. ترتيب الموافقة التنفيذية المطلوب: **إصلاح جميع البنود محليًا → اختبارات مركزة متدرجة لكل جزء بعد إصلاحه → `dart format` + `flutter analyze` شامل صفر خطأ → اختبار Flutter الشامل المحلي مرة واحدة على مصدر مجمّد يقارب 9,800+ حالة، صفر FAIL/ERROR/غير مبرر SKIP → اختبارات Android/iOS native والتكامل والخصوصية/الأمن اللازمة → مراجعة الفروقات، بصمات ملفات المصدر، وعدم تغير HEAD أثناء التحقق → فقط بعدها كوميت منتج نظيف واحد متماسك إلى الفرع الأصلي وpush → تحقق CI الضروري والبناء الموقّع Android 33 / iOS 37 ورفع iOS 37 إلى TestFlight**. عند أي فشل أصلحه، شغّل المركز من جديد، ثم أعِد الشاملة **بعد اكتمال جميع الإصلاحات** وليس عند كل فشل. لا تختصر الشاملة إلى 11 اختبارًا وتسمّيها 9,800.
7. **لا كوميت ولا رفع GitHub قبل اجتياز الشاملة كاملة** باستثناء وثيقة التكليف الحالية التي رُفعت من ChatGPT بترخيص المالك. لا توقيع ولا متجر قبل تثبيت المصدر المصحح. لا تعلن «انتهيت» إلا بوجود سجل الاختبارات والـHEAD والبصمات ونتائج البناء الحقيقية. إذا منع جهاز/نظام التشغيل اختبارًا (مثل iOS native على Windows)، صرّح BLOCKED وشغّله عبر macOS runner مصدريًا بعد اجتياز الاختبارات المحلية؛ لا تسمّه PASS.

## 1. إصلاح جميع ملاحظات AI Coach على نسخة 36 (1–20، مع غياب الرقم 7 في تعداد المالك)

الصور التي أرسلها المالك من جهاز iPhone في هذه المحادثة تُظهر الأعطال واقعًا، وهي المرجع التجريبي بجانب المصدر. ملفات المصدر الأساسية: 
`lib/features/intelligence_center/presentation/intelligence_center_page.dart`،
`intelligence_reference_chat_body.dart`،
`intelligence_query_flow.dart`،
`intelligence_reference_workspace_flow.dart`،
`intelligence_conversation_viewport.dart`،
`intelligence_coach_menu.dart`،
`intelligence_coach_reference_header.dart`،
`intelligence_conversation_history.dart`،
`workspace/coach_reference_workspace.dart`،
`lib/shared/widgets/chat_history_viewport.dart`،
`lib/shared/widgets/bil_glass_press_feedback.dart`،
`lib/app/router/app_router.dart` و`responsive_app_shell.dart`.

### 1.1 الكيبورد (1 و2)
- عند الضغط على إرسال في الحقل أو على زر الإرسال، أغلق لوحة المفاتيح بوضوح وبأمان بعد التقاط النص؛ استدعِ focus unfocus في لحظة صحيحة مع `ask()` ومنع lost draft/race. الحالي `TextField.onSubmitted: (_) => ask()` والزر `onPressed: ask` دون `unfocus` صريح.
- أضف dismiss بالسحب الطبيعي من سجل الرسائل وبالنقر خارج المدخل؛ السحب من جسم المحادثة/الفراغ يجب أن يغلق الكيبورد. الحالي `CoachAnchoredHistory` يستخدم `ScrollViewKeyboardDismissBehavior.onDrag` لكن نطاقه لا يضم كل الشاشة؛ لا تكسِر القراءة أو اختيار النص أو سحب الرسائل.
- اختبر بالعربية والإنجليزية، زر وReturn والإرسال مع طلب معلّق، العرض الصغير/التدوير، وفتح وإغلاق الكيبورد دون نقل الرسائل أو وميض.

### 1.2 الوميض والتمرير (3 و12)
- عند الدخول الأول، منع إعادة رسم أو استبدال كامل شاشة المدرب عند `entryWelcomeTimer`/`conversationReady`/`coachHealthBriefProvider`/`coachContextSnapshotProvider` وتحديث AI credits/المزامنة. لا تثبت الواجهة عبر كتم البيانات أو إخفاء الأخطاء، ولا تنشئ polling دائمًا.
- السهم الدائري الزجاجي الظاهر منتصف الشاشة عند الضغط على أزرار مختلفة مصدره أيضًا `lib/shared/widgets/bil_glass_press_feedback.dart`: مكوّن عالمي يسجل `pointerRouter.addGlobalRoute` وينشئ `OverlayEntry` عند تتبّع الأسهم. أصلح جذريًا «زجاج التفاعل» دون فقاعات في وسط الشاشة أو عشوائية خارج الزر، واحفظ UI semantics واتجاه RTL والتنقل، ولا تُزل الضغط الطبيعي من الأزرار الأخرى. اختبر أيضًا Community/Post Composer/Memory.
- ميّز ذلك عن زر «أحدث الرسائل» في `ChatHistoryViewport` (`centerJumpButton: true`)؛ لا تعرضه إذا كانت أحدث رسالة مرئية، ولا تجعله يقفز داخل التاريخ أثناء القراءة أو ينتشر على الشاشة.

### 1.3 إغلاق القوائم والرجوع (4 و5 و6 و8 و9 و10 و11 و14 و15)
- قائمة (...) هي `_CoachMenuSheet` في `intelligence_coach_menu.dart` و`_showCoachMenuSheet` في `intelligence_reference_workspace_flow.dart`. الضغط في المنطقة المعتمة خارج البطاقة يغلقها، وكذلك swipe-down من أي موضع مناسب دون إفساد Scroll/drag داخلها؛ راجع `showModalBottomSheet` وحجم الحاجز وPointer capture.
- شاشة «نظرة عامة» `CoachReferenceWorkspace` تظهر داخل `_referenceOverview` وليس كـGoRouter route؛ أضف زر رجوع ظاهرًا ومتوافقًا مع RTL يعود إلى محادثة المدرب ويحفظ المحادثة والمدخل والتمرير.
- الانتقال من نظرة عامة إلى «تحليلات / الخطة / التقدم / الأدوات / مسح المنتج / ماء مسجل / وجبات / وزن / ما يعرفه BIL عني» يجب أن يحفظ **المصدر الحقيقي** ويعود إليه بنقرة Back واحدة، وليس القفز للداشبورد أو Today. لا تكتفِ بتغيير رسمة السهم:
  - `workspace/coach_reference_workspace.dart` يستعمل `onRoute('/analytics')` و`onRoute('/plan')` و`onRoute('/daily-log')` و`onRoute('/daily-log?foodLog=1&action=barcode')` و`onRoute('/daily-log/water')` و`onRoute('/weight-history')`.
  - `lib/features/analytics/analytics_page.dart`: `showDashboardBack` يفرض `context.go('/dashboard')`، حتى عندما جاء المستخدم من Coach؛ اصلح بناءً على مصدر موثوق.
  - `lib/features/profile/plan_navigation_contract.dart`: `PlanPageOrigin` يقبل dashboard/profile فقط، و`lib/features/profile/plan_page.dart` يستخدم `context.go(widget.origin.returnLocation)`؛ أضف معالجة صريحة آمنة لمصدر Coach أو pop مناسب، دون قبول return URL اعتباطي.
  - `lib/features/daily_log/daily_water_page.dart`: `PopScope(canPop:false)` + `context.go(returnPath ?? '/daily-log')` يفسران الرجوع الخاطئ؛ مرر مصدرًا موثوقًا أو استخدم history إذا موجود.
  - `lib/app/router/bil_quick_add_presenter.dart` لديه whitelist لـ`/intelligence-center`؛ لا تلغِ whitelist ولا تسمح Open Redirect.
  - «إضافة سريعة» من Workspace يجب أن تفتح واجهة Quick Add الأصلية متعددة الإجراءات، لا الانتقال المباشر إلى Today.
  - «مسح المنتج» يرجع إلى Coach؛ لا يتجاوز صلاحيات الوصول أو مسار Food Log.
  - `_CoachHero` وإشارات Back والمكونات المشتركة يجب أن تتبع RTL (السهم العربي إلى **يمين** بالموضع/الاتجاه الصحيح) وتعمل مع زر العودة الفيزيائي وiOS swipe-back حيث ينطبق، ولا تعرض سهمًا إضافيًا.
- جدول قبول التنقل: Coach chat → (...) → Overview → Analytics → Back → Overview → Back → Chat؛ كرر Plan / Water / Barcode / Quick Add / Weight History / Memory؛ ثم كرر الرحلات من Dashboard/Today والإشعار/الرابط المباشر وتأكد أن الأصول الأخرى لم تنكسر.

### 1.4 المحادثات والتصميم (13 و17 و18 و19)
- `intelligence_conversation_history.dart` يعرض `subtitle: Text(createdAt)` كنص ISO مثل `2026-10-16T07:03:31.066563`؛ أزله من البطاقات وفق طلب المالك، ويمكن حفظ timestamp داخليًا للفرز فقط. صمّم البطاقات Pearl/Glass خفيفة متناسقة مع بقية التطبيق؛ لا تفقد سجل المحادثات أو خاصية التسمية اليدوية/الحذف.
- أزل اختصار «اكسب» **المكرر من رأس المدرب فقط** في `CommunityGoldBalanceAction(compact:true)`، وأبقِ نظام Earn/Rewards ووظائفه داخل مجتمع BIL. صغّر بطاقة Gold الحقيقية (وليست قيمة وهمية) وضعها **في نفس صف عنوان «المدرب الذكي» بجانب العدسة** كما طلب المالك، دون تعارض مع portrait/history/more أو مقياس الخط.
- العنوان الفرعي `'شريك صحتك، معك دائمًا'` مضبوط `fontSize:9` في `intelligence_coach_reference_header.dart`؛ كبّره بشكل واضح (تقريبًا 12–13 منطقيًا ثم راجع بصريًا 320/375/430 وعند text scale 1.3–2.0).
- نص فقاعات المستخدم والرد صغير لأن `_coachConversationBodyStyle` يأخذ `textTheme.bodySmall`؛ ارفع الحجم بما يلائم العربية والشاشات الصغيرة مع احترام Dynamic Type والتباين وإمكان التحديد/النسخ وRTL (لا تختصر الارتفاع أو تقص النصوص).
- أزل فراغات غير مبررة في واجهة محادثة قليلة الرسائل، مع حماية سلوك scroll-to-latest وStable message anchor؛ لا تقلّب مواضع الردود إذا وصلت أثناء قراءة تاريخ قديم.
- عرض وزن `83.30000000000001 kg` في `workspace/coach_reference_workspace.dart` هو Float formatting عارض: تنسيق معقول بحسب الوحدة/الدقة فقط، دون تغيير القيمة المحفوظة.

### 1.5 الصوت العربي و«+» (16 و20)
- على iOS: `lib/features/intelligence_center/presentation/intelligence_conversation_voice.dart` يضبط `SpeechListenOptions(localeId:null, autoDetectLanguage:true)`. جسر `ios/Runner/BILSpeechBridge.swift` يختار `let locale = requestedLocale ?? .current`، أي لغة جهاز Apple الحالية، ولا يقوم بالكشف التلقائي الفعلي على iOS. عند واجهة عربية وتسجيل عربي، اختر أول locale عربي يدعمه المحرك مثل `ar-EG` أو `ar-SA` وفق `SFSpeechRecognizer.supportedLocales` واللغة/بلد الجهاز، مع fallback صريح منضبط؛ لا تفرض العربية على تسجيل إنجليزي مقصود أو تعطل multilingual Android. اختبار تسجيل جمل عربية حقيقية ونتائج نهائية/جزئية وتصحيح النص وحساب الصلاحيات، والحفاظ على «الصوت الخام لا يرسل إلى Gemini».
- `_buildCoachPermissionMenu()` في `intelligence_coach_menu.dart` يستخدم `PopupMenuButton<CoachActionPermissionMode>` بـRead only/Ask before write/Write allowed. **هذه صلاحيات فعلية وليست كذبًا في الكود** (`domain/coach_action_permission.dart`). انقل التحكم بها إلى إعدادات المدرب مع شرح حقيقة كل وضع؛ لا تحذف `CoachActionPermissionGate` أو موافقات العمليات الحساسة.
- اجعل (+) بجوار مُدخل السؤال قائمة «اسأل مدربك» فخمة وخفيفة تعرض اختصارات حقيقية، مثل: «حلّل وزني»، «ماذا آكل اليوم؟»، «كم بروتين بقي؟»، «حلّل يومي»، «كم ماء بقي؟»، «ما خطوة اليوم التالية؟»، «خطتي هذا الأسبوع». يجب أن تُمرر الطلبات إلى مسار `ask()` الحقيقي، وتقرأ فقط `CoachContextSnapshot`/السجلات المؤكدة؛ لا تولّد اقتراحًا ملفقًا ولا تكتب طعامًا تلقائيًا أو تنفق أرصدة دون موافقة/سير عمل صحيح. إن كان السياق ناقصًا فأخبر المستخدم بدل نسبة أرقام مختلقة. احفظ صلاحيات الخصوصية لكل زر.
- هذا (+) يختلف عن زر (+) ذي الأيقونات الخمس في شريط BIL العام: **لا تغيير لذلك الشريط**.

### 1.6 خطأ «المدرب غير متاح» في Production (مستقل وأولوية P0)
- صور iPhone تُظهر ردود 503 متكررة، ومراجعة Supabase المباشرة في محادثة التسليم كشفت خمس استجابات HTTP **503** إلى `/functions/v1/ai-coach` صباح 16 أكتوبر ضمن نافذة 03:45–04:20 UTC. لا تحكم من نجاح اختبار Dart بأن الخدمة تعمل.
- المصدر `supabase/functions/ai-coach/server.ts`: `geminiCall`/`run` يعيدان 503 لأخطاء واسعة (مثل provider not configured, quota/429 mapped, provider_http, RPC failures)، ووثّق أن السبب **لم يُثبت** بعد. افحص redacted function/request logs حسب requestId، حالة `ai-coach` المرفوعة (آخر نسخة مقروءة 107)، أسرار Gemini وجودها/صلاحيتها **دون عرض قيمها**، موديل primary/fallback، استجابة provider، consent/RLS والـreservation/settlement؛ لا تكرر طلبات مدفوعة بلا داعٍ.
- اختبر الاستجابة مع snapshot اصطناعي، 429/5xx/timeout/network/invalid body/AI consent، idempotency, reserved credits refund-on-failure وعدم تكرار الاستهلاك، وإرجاع Error UI قابل لإعادة المحاولة ويعرض سببًا آمنًا. لا تغيّر نموذج Gemini أو policy أو tokens أو أي Production deployment عشوائيًا؛ لا تضع credentials في Git.

## 2. الإضافات الست الجديدة من المالك (لا تسقط واحدة)

**N1 — أيقونات النوم مثل «More».** افحص `lib/features/wellness/presentation/sleep_tracker_experience.dart` و`sleep_tracker_schedule.dart` و`sleep_tracker_page.dart`. استبدل أسلوب أيقونات النوم غير المتناسق بالأيقونات الصغيرة الرمادية النظيفة المتبعة في More / `BilSemanticIcons`، مع مقياس 44–48 للنقر وRTL/Light/Dark، دون تغيير أي معنى أو بيانات نوم/HealthKit. اختبار بصري/semantics.

**N2 — فيديوهات مكتبة التمارين لا تظهر.** افحص `bil_workout_routines_page.dart` و`bil_workout_videos_wall.dart` و`bil_workout_routine_media.dart` و`bil_workout_fullscreen_video.dart` و`wellness_video_stream.dart` و`wellness_content_pack_manager.dart`. كود المشروع يتطلب حزم وسائط **مثبتة وموثوقة مع SHA/MIME/license** ولا يعد روابط الاكتشاف غير المثبتة فيديوهات صالحة؛ اكتشف لماذا العناصر الفعلية لا تظهر: جرد الكتالوج/الحزم والترخيص/ملفات الوسائط/الـURL والـHEAD/Content-Length/Range/ETag وcache والتشغيل على Android/iOS. أصلح المصدر/التسليم/إظهار الحالة الحقيقية، مع Retry واضح، ودليل تشغيل فيلم موثوق على جهاز/Simulator يدعمه. **ممنوع تركيب فيديو وهمي أو كشف المحتوى المدفوع أو تعطيل فحص السلامة أو تسمية صورة ثابتة «فيديو».**

**N3 — «قنوات المجتمع» تظهر «إعادة المحاولة».** افحص `lib/features/community/channels/presentation/community_channels_route.dart` و`community_channels_page.dart` و`application/community_channels_controller.dart` و`data/supabase_community_channels_repository.dart`. تحقق من اشتراط Sign-In/Community policy/entitlements وRPCs `bil07_channel_capabilities_v1` وبقية `bil07_*` على Production؛ ترجمة أكواد `PGRST202`/`42883`/`42P01` للميزات غير المنشورة أو `42501` لـRLS، والتغييرات في Realtime subscriptions؛ انسخ بنية Production ضمن Supabase محلي افتراضي واختبر Directory/Channel Read/Send/ReadReceipt/Retry/ABA. لا تفتح RLS أو تزيل موافقة المجتمع لتجاوز Retry. إذا Cloud RPC غير منشورة، جهز migration صالحة منفصلة واختبر rollback والتوافق قبل أي Production deployment.

**N4 — عدد الأصدقاء وتكرارهم وزجاج المنشورات/اللحظات.** افحص `lib/features/community/presentation/community_member_profile_header.dart` حيث `profile.friendCount` يُعرض في `ActionChip`، وكذلك مصدر `CommunityProfileOverview` وقائمة `community_friends_tab.dart`. أثبت بالـSQL/RPC المسموح أن العدد يمثل **علاقات accepted النشطة الفعلية** للمستخدم الصحيح، وليس Pending أو Followers أو Cached projection قديم، مع احترام block/privacy وsession/owner والتزامن. احذف فقط صف «الأصدقاء» **المكرر أسفل عداد الرأس** دون إخفاء العدد الصحيح أو تعطيل الوصول إلى قائمة الأصدقاء. `community_member_profile_content.dart` يعرض تبويبات/بطاقات اللحظات والمنشورات بتلوين غير مطابق؛ استخدم بطاقات Pearl/Glass بلون خفيف وبدون خلفيات داكنة متضاربة، وراجع الفرق بين Moments وReviews/Posts في الواجهة الحالية حتى لا تغيّر تصنيف المحتوى.

**N5 — المزامنة لا تعمل.** راجع `lib/features/cloud_platform/services/cloud_manual_sync_service.dart` و`cloud_session_sync_coordinator.dart` و`cloud_auto_sync_coordinator.dart` و`providers/cloud_manual_sync_status_provider.dart` و`lib/features/settings/sharing_privacy_cloud_sync_tile.dart`. افحص أسباب `consent` و`auth`/session وConnectivity وCloudAccountKey وDevice identity وCAS/ledger، وتصفية أنواع السجلات الفعلية (في المصدر الحالي `profile/weight/hydration` فقط ضمن selective policy) و`pending/conflict/push/pull`. اختبر A→B→A، offline→online، تسجيل الخروج وتبديل المستخدم، رفض الموافقة، صفر/Null/Conflict، التكرار/التعليق/refresh دون تسريب أو سحق تعديلات. لا تعرض «نجحت المزامنة» إلا عند `CloudManualSyncDisposition.completed` مع server readback وأن `pending=0`؛ ميّز Partial/Blocked مع رسائل عربية مفهومة. **لا تغيّر سياسة موافقة النسخ الاحتياطي أو توسع أنواع البيانات المرفوعة بلا مراجعة خصوصية.**

**N6 — تدقيق Production كامل.** قارن المستودع المحفوظ بحالة Supabase الحية قراءة فقط: المهاجرات وschema + وظائف `ai-coach` و`analyze-meal` و`verify-store-purchase` و`food-search` (أحدث نسخ رُصدت 107/104/94/61 على الترتيب، تحقق حيًا مجددًا)، RLS/Security definer, accounts reviewer/owner separation, community channel RPC, storage public avatars/private community files, key retention, image/video latency, credits/grants/entitlements/refund ledger/notification receipts, scheduled functions, consent/AI provider, cloud synchronization, SDK/ATT/Google. اربط كل ملاحظة بالـSHA/نسخة الدالة وسجل redacted وإثبات قراءة، وقارن الجداول وعقود التوافق القديمة 35/32 دون تغيير بيانات حقيقية. أي نقص: أضف إصلاحًا محليًا واختبارًا عليه، وموافقة مهنية على الأثر قبل نشر Production؛ لا تزعم «كل Production PASS» بسبب اختبار محلي.

## 3. خلل iOS Native + نسختا الإصدار الجديدة — إلزامي

### iOS 36 السابقة ليست بناءً فاشلًا
- الـIPA **iOS 36** نجحت في GitHub من تشغيل `38844200115`، بما فيه التوقيع وApple App Store Connect validation وخطوة TestFlight upload. لذلك رقم النسخة التالية المطلوب هو **iOS build 37**، ولا تعدّل/تستبدل TestFlight build 36 في مكانها.
- الذي فشل سابقًا تشغيل محاكي مستقل `38845256457`، في `lib/features/intelligence_center...` ليست المشكلة: المهمة `iPhone and iPad native tests` بنت/وقّعت QA simulator Runner، لكن `flutter drive --use-application-binary` لم يستطع فتح التطبيق على iPhone بسبب `FBSOpenApplicationServiceErrorDomain: SBMainWorkspace denied`. نتيجة الاختبار FAIL؛ رحلات iPad لم تُنفذ. الأدلة: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38845256457/artifacts/12023202418.
- شخّص توقيع ad-hoc entitlement bundle/launch / framework embedding / iOS simulator version / runtime / bootstrap و`.github/scripts/bil_ios36_native_integration.sh` و`bil_ios_simulator_adhoc_sign.py`، واجمع `simctl spawn log show` و`launchd`/FBS وcodesign/entitlements بدون الأسرار. لا تعالجها بإلغاء جميع Native tests أو بالتوقيع الإنتاجي على Simulator؛ اختبر على macOS Runner/Simulator فعليين وأثبت وصول الـentrypoint إلى الحالات ثم نجاحها. لا تستنتج من هذه المشكلة أن TestFlight 36 فشلت في البناء.
- اعمل كذلك تجربة فعلية لنسخة 37 على iPhone وiPad إن توفر الجهاز مع ميكروفون عربي، Keyboard، ATT/SDK/network، Purchase Sandbox/Restore وHealthKit؛ إن لم تتوفر أجهزة فعلية صرّح بالحدود ولا تزيف نجاحها.
- قضية Apple 5.1.2(i) السابقة تتعلق بادعاءات App Privacy Tracking لـUser/Device/Product Interaction مقابل ATT. التحقق من IPA 37 ونشاط SDK الحقيقي والإفصاح يجب أن يكون مستقلًا عن نجاح CI؛ لا تغيّر الملصق إلى No Tracking من غير دليل ولا ترسل App Review دون اعتماد سياسة.

### Android build 33 ما زال يحتاج إصلاحًا حقيقيًا
- لا تغيّر Android `versionCode 33` عند بناء المرشح التالي إلا إذا تبيّن من سجل Google Play أن هذا الرقم استُخدم بالفعل وفرض النظام زيادته؛ لا تحاول نشر Google Play/Appeal هنا.
- آخر Android 33 فشل بوابة 16 KB **بعد بناء AAB**: `libdartjni.so` لديها `GNU_RELRO end not aligned to 16 KB`، و`tool/release/verify_android_16k_alignment.py` لديها استثناء إضافي `NameError: sys is not defined` يخفي السبب الدقيق. الدليل المرفوع: https://github.com/bilhealth-admin/Body-Intelligence/issues/12 وhttps://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38844200159.
- أصلح مصدر المكتبة native/gradle/NDK أو استراتيجية تضمينها بما يضمن محاذاة صحيحة لكل ABI و`PAGE_ALIGNMENT_16K` وELF LOAD + GNU_RELRO في AAB الموقع النهائي. إصلاح `import sys` وحده لا يحل المكتبة. امنع إلغاء التحقق أو التغاضي عن الفشل فقط لتمرير بناء.
- بعد نجاح التحليل والشاملة على المصدر المجمد، شغّل مرشحي Android 33 **AAB موقع** وiOS 37 **IPA موقع** من الـHEAD المعتمد نفسه، حدّث manifests وبصمات SHA256 والتوقيع وASC metadata السليمة. ارفع **iOS 37 فقط إلى TestFlight** بعد PASS لكل بوابات التوقيع والتحقق. لا ترفع Android إلى Play، ولا ترسل iOS إلى App Review، ولا تمس Production متاجر/أسعار/Trial.

## 4. إغلاق الاختبارات: لا تكرر أخطاء الفحوص السابقة

بعد تنفيذ جميع البنود، أولًا شغّل هذه المجموعات المركزة فعلًا محليًا (وأضف tests جديدة حيث توجد فجوة؛ لا تعتمد على عقود `contains` وحدها):
1. Coach keyboard focus/submit/outside/drag + repeated init/idle/render/scroll & reply load/503/retry/credits.
2. Modal barrier dismissal + glass overlay & arrow RTL on Coach/Community/Post Composer/Decision Memory.
3. Coach workspace route round-trips for Analytics/Plan/Water/Barcode/Quick Add/Weight/Memory/Back, plus from Dashboard/notifications/deep links.
4. Arabic iOS native speech locale, all 25 supported localizations and Android multilingual cases, first permissions, speech errors, edit correction, privacy.
5. Conversation storage/rename/delete, clean readable title, typography accessibility Dynamic Type at 320/375/430 points and iPad.
6. Sleep icons; verified media catalog/free vs paid/video cache/HEAD/ETag/Range/range playback/failure; no false videos.
7. Community channels actual local RPC/Auth/RLS/Realtime/policy/retry; friendCount accepted only, no duplicate friend row, Posts/Moments glass/no clipping.
8. Cloud Sync A→B→A/owner/consent/offline/auth encryption/restore/pending/conflict and production-readback simulation.
9. Store commerce regression, AI Coach permissions and new quick prompts, 503 credit reservation/settlement, production schema migration compatibility.
10. Shared component regressions outside Coach, build release lint/security/privacy, Golden visuals where appropriate with original reference unchanged.

المراجع الحالية للاختبارات تشمل:
- `test/features/intelligence_center/coach_page_lifecycle_regression_test.dart`،
`coach_conversation_rename_ui_test.dart`،
`ai_coach_navigation_receipt_test.dart`،
`coach_action_permission_test.dart`،
`coach_speech_policy_test.dart`،
`ai_coach_starter_prompts_contract_test.dart`،
`ai_coach_failure_surface_regression_test.dart`،
`test/shared/widgets/chat_history_viewport_regression_test.dart`،
`test/app_keyboard_dismiss_contract_test.dart`،
`test/app/router/audited_route_return_source_contract_test.dart`،
`test/features/daily_log/daily_water_page_navigation_test.dart`،
`test/parallel/bil07/community_channels_route_test.dart`،
`test/features/community/community_reference_navigation_test.dart`.
راجع الاختبارات الموجودة لبقية البنود ووسّعها بما يطابق سلوك iPhone الحقيقي.
- بعد نجاح المركز: `dart format --output=none --set-exit-if-changed` (على الملفات المعنية) و`flutter analyze` الشامل بأثر ثابت، ثم `flutter test` المحلي الشامل **في تشغيل نهائي واحد على مصدر غير متحرك**. حدّد عدد test cases من السجل الحقيقي لا عدد الملفات؛ الهدف ≈9,800+ نجاح و0 فشل و0 خطأ و0 تخطٍّ بلا مبرر. الفحص التاريخي `9889 PASS` على SHA `36c46e...` لا يثبت نجاح المصدر الجديد.
- لا تستخدم force/skip/quarantine/name filtering/disabled tests أو تعديل expected images لغرض «الأخضر». عند فشل مجموعة، أصلح السبب الحقيقي ومركزه، ثم الشاملة **مرة واحدة عند اكتمال الحزمة**، مع تسجيل كل حالة وسببها.

## 5. شروط الإغلاق والتسليم

يجب أن يتضمن تقرير Codex النهائي في `docs/qa_next`: أحدث HEAD الأصلي قبل/بعد، قائمة ملفات تغيّرت وسبب كل تغيير، بنود المالك العشرين والستة الجديدة **مع كل حالة DONE/PASS/BLOCKED ودليلها**، نتائج المركز والمجموعات/Flutter Analyze والشاملة بالعدادات والدقائق/المصدر الثابت، محاكيات الأجهزة، Production read-only audit ونتائج 503/قنوات المجتمع/Cloud Sync، security and privacy caveats، نتائج توقيع Android 33/16 KB وiOS 37، رابط TestFlight upload والتعامل مع Apple processing، Artifact hash/provenance، وما بقي يتطلب جهازًا حقيقيًا أو متاجر. راجع اختلافات git وحرّر تقريرًا غير متناقض قبل الـcommit الأخير.

**لا تعتبر رفع كوميت أو إنشاء IPA/AAB كافيًا إن بقيت الشاشة ترمش أو التنقل يذهب لDashboard أو المدرب يُرجع 503 أو video/channels/sync لا تعمل. لا تعلن جاهزية إصدار حتى تجتاز بوابات المستخدم الفعلية.**

**أمر Codex النهائي:** أكمل العمل محليًا بالكامل دون طلب أذونات متكررة في نطاق هذا التكليف، لا ترفع أي كوميت منتج قبل PASS التحليل والشاملة، ثم ارفع كوميتًا نظيفًا واحدًا للفرع الأصلي وشغّل بناء Android 33 وiOS 37 الموقعين وارفع 37 إلى TestFlight فقط. إذا اصطدمت بمانع فعلي لا يمكن تجاوزه دون الإخلال بالأمان، لا تتظاهر بالإكمال: أثبته بدليله وطلبه المحدد.