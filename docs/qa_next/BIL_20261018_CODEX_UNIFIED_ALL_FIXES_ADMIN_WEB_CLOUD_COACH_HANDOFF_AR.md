# BIL 2026 — تكليف Codex المحلي: استلام كوميت الإصلاحات الموحّد + الإدارة + السحاب + AI Coach

**التاريخ:** 18 أكتوبر 2026. **المالك:** المشروع BIL / Body Intelligence Log.
**المستودع:** `bilhealth-admin/Body-Intelligence`.
**نقطة الأصل المقصودة:** `ceb3570cc46c387f25e7e9821bb4aa4120b53d71` على `integration/bil-qa-media-policy-20261011`.
**فرع التسليم الوحيد:** `handoff/bil-20261018-unified-codex-reconciliation`، وهو ONE SQUASH COMMIT فوق نقطة الأصل، وليس نسخًا من فروع متعددة أو طلبًا بعمل عشرات cherry-picks.
**النتيجة المتوقعة من Codex:** دمج واعٍ في الشجرة المحلية الفعلية، إنجاز الناقص، اختبارات مرتبة دون تجاوز، ثم **كوميت منتج واحد نظيف + push + توقف**؛ لا نشر Production أو متجر من دون إذن نشر مستقل.

## 0. اتفاقات غير قابلة للتفاوض
1. Windows Codex DESKTOP-PO6C3QG كان **Offline** عند التسليم؛ الشجرة المحلية غير المرئية قد تحتوي مئات التعديلات غير الملتزمة. لا تفترض أن هذا الكوميت أحدث أو أفضل من إصلاح Codex المحلي لكل ملف.
2. **أول خطوة:** اعرض HEAD/branch/status/diff/untracked. انسخ تغييرات المستخدم المحلية إلى مكان آمن غير قابل للكتابة وأثبت SHA، ثم `git fetch origin handoff/bil-20261018-unified-codex-reconciliation`. لا checkout/merge/reset/clean/stash pop أو cherry-pick أعمى في الشجرة المتّسخة؛ استخدم worktree منفصلًا للمقارنة والمراجعة hunk-by-hunk.
3. قارِن `git diff ceb3570cc46c387f25e7e9821bb4aa4120b53d71..origin/handoff/bil-20261018-unified-codex-reconciliation`. احصر لكل ملف: (أ) ما أُصلح في الأصل، (ب) ما نفذه Codex محليًا، (ج) أفضل دمج مثبت بالاختبار، (د) أي تغير مرئي متعمَّد أو فقد محتمل. لا تُضحِّ بوظائف مقابل Golden أخضر.
4. الأولوية لسلامة البيانات والمشتريات والموافقة الصحيحة والخصوصية، ثم الأداء والاستقرار، ثم polish التصميم اللؤلؤي/الزجاجي. لا تلمس Home/Dashboard أو تبويبات الأسفل الخمسة أو الأسعار/Trial دون طلب مستقل. احتفظ بوظائف كاميرا Log Food وQuick Add والبروتوكول المحلي للبحث.

## 1. ما يحتويه كوميت الاستلام الموحّد فعليًا
- إصلاح كاميرا **Log Food** واختيار الصور فوق نفس الشاشة حتى بدء التحليل؛ وQuick Add photo بلا صفحة وسيطة، إلغاء بلا حجز AI credits.
- بحث الطعام في صفحة الوجبة نفسها (Today / Logbook)، debounce ونتائج تدريجية محلية/سحابية، عدم إظهار Empty كاذب، الحفاظ على النص والـFocus وعدم نقل المسار، زر (+) في `Foods in this meal` حقيقي، وتحديث قائمة الوجبات بعد حفظ ذري.
- بطاقات لؤلؤية لتحذيرات Camera/Microphone/Speech/Barcode/Profile مع إبقاء نوافذ صلاحيات iOS/Android الأصلية في وقتها. ممنوع مطالبة iOS بأذونات عبر بطاقة مزيفة قبل نافذة النظام، وممنوع تجاوز/فتح Settings تلقائيًا بعد رفض المستخدم.
- إزالة **مدخل ومسار إدارة AI Coach المحمول `/admin/ai-coach`** فقط، بدون إزالة تحقق الصلاحيات على الخادم.
- كاش المجتمع لا يخترع روابط `/object/sign/` خاصة غير موقعة؛ يحافظ على النص وmetadata مع hydration موقّعة، ومخرجات مزامنة مفصلة تحدد offline/owner mismatch/consent/partial/entitlement.
- استرداد تهنئة الشراء المؤكد غير المعروض مرة واحدة فقط بعد إعادة تشغيل التطبيق من دون تغيير أي entitlement أو رصيد؛ تصحيح copy الاستثناء العام للكابتن حتى لا يزعم أن إجراء سابقًا لم يُنفذ قطعًا.
- تصنيف `reconciliation_forbidden` في خدمة `verify-store-purchase` إلى 403 بدل 503 **في شيفرة المصدر فقط**؛ حماية التحقق والاستحقاقات باقية، **لم ينشر التغيير إلى Supabase Production**.
- إصلاح تقرير أداة Android 16KB `import sys` فقط؛ لا يعني ذلك أن مشكلة GNU_RELRO حُلّت.
- مشروع BIL-07 Channels: RPCs عامة/خاصة خاضعة للهوية، عضوية وحظر وتقارير وإخفاء المحتوى، no-seed، idempotent send، read/readback، presence، وحدود جديدة 20 رسالة/60 ثانية و300/24 ساعة لكل مستخدم؛ نسخة UI آمنة للإبلاغ والحظر. **مهاجرات SQL مقترح staging فقط لا تنفذ آليًا في Production**.
- **إصلاح مستقل تم دمجه داخل نفس كوميت التسليم:** سحب الهدية الإدارية Premium إلى **Free موثقة** فقط عند نجاح قراءات Closed-Test + Store + admin RPC الثلاث، ودون حرمان مشتري Apple/Google من اشتراكه أو تحويل فشل القراءة إلى Free موثقة.
- تصحيح اختبارات More القديمة التي كانت تتوقع شاشة الإدارة المحذوفة. هذه اختبارات حقيقية لم تُحذف أو تُعطَّل.

## 2. توضيح حاسم: أين تتم الموافقات والإدارة؟
**الواقع الحالي وليس تصورًا:** مسار `/community/moderation` ما زال موجودًا في `lib/app/router/app_community_routes.dart` ويفتح `CommunityPostModerationPage` المقيّدة بدور moderator موثق من الخادم. يحتوي إجراءات approve/reject للمنشورات، ومكافأة 5 tokens عند تحقق server receipt، وبلاغات المنشورات والتعليقات وبلاغات AI Coach. المستخدم يرى منشوراته pending/approved/rejected في `CommunityMyPostsPage`. الواجهة `community_moderator_admin_panel.dart` و`community_member_access_admin_panel.dart` موجودة كملفات، وقد لا تكون مرتبطة بمسار ظاهر؛ تحقق فعليًا من binary/routes.
- توجد أدلة عن **BIL Admin Web للمنح/سحب Premium**؛ لا تخلط وجودها بنجاح نقل **طابور موافقات المنشورات وبلاغات القنوات** إلى صفحة ويب مستقلة.
- المطلوب النهائي: **واجهة ويب منفصلة وآمنة للمشرفين والمالك** لمراجعة المنشورات والبلاغات والمكافآت وتعليق الأعضاء والموافقات، بصلاحيات خادمية وaudit log وفصل بين الأدوار؛ تطبيق الهاتف يبقى للمستخدمين ونشر المحتوى وحالة الموافقة والإبلاغ والحظر.
- **لا تزل `/community/moderation` أو ملفاته نهائيًا قبل وجود بديل ويب يعمل ويجتاز E2E للمالك والمشرف ومعالجة البلاغات.** لا تترك المراجعات بلا جهة؛ ولا تُطلق نسخة فيها إدارة مخفية/dormant تخالف Apple 2.5.19. إذا لم تُنجز واجهة الويب أو يلزم تكليف/استضافة مستقلان: أوقف إطلاق النسخة، وثّق العائق، وأبقِ الحالة الحالية functional في التطوير حتى الانتقال الآمن. لا تنقل مفاتيح service_role إلى المتصفح أو الهاتف.
- وظائف إدارة تقارير القنوات المتاحة في SQL candidate ليست لوحة ويب فعلية، ولا تؤسس غرفًا عامة تلقائيًا. اختبار PGlite/PostgREST بمحاكيات المستخدمين **لا يعادل ترحيل Production**.

## 3. Cloud — ما لم يُحل بعد، وكيف يُثبت الحل
**ممنوع كتابة `Cloud all fixed` دون دليل.** فحص Production السابق بالقراءة فقط وجد:
- `bil07_*` للقنوات غير منشورة، ولذلك صفحات قنوات المجتمع في الباينري الموجود قد تعرض Retry حتى لو نجحت مهاجرات CI المعزولة.
- وظائف Edge `ai-coach` و`analyze-meal` عرفت أخطاء HTTP 503، وكذلك `verify-store-purchase`. بعضها رفض أمني `reconciliation_forbidden` فلا تُضعف Play Integrity أو مفاتيح المتجر أو شروط الموافقة لإخفاء الخطأ.
- تحقق بالتسلسل: schema/RLS/RPC/version drift → multi-owner Auth staging → Edge function code and safe logs → timeout/backoff/idempotency → signed media cache → sync consent/restore conflict and owner transitions → notification navigation → real Health/Ads/Payments contracts.
- استخدم Staging/ephemeral مع حسابات **وهمية** وأدلة HTTP/SQL، وقراءة فقط في Production. إذا استلزم الإصلاح نشر وظائف أو migrations أو تعديل grants للمستخدمين: ارفع خطة deployment/rollback/evidence للمالك أولًا. **لا تغيّر Production مباشرة داخل هذا الدمج**.
- الشفافية المطلوبة: `VERIFIED / FAILED / NOT TESTED / DEPLOYMENT BLOCKED` لكل خدمة؛ لا تتجاهل الاختبار الفاشل ولا تتنقل بين حسابات حقيقية.

## 4. AI Coach — لا تعلن الكابتن جاهزًا دون كل شرط
- اقرأ الوثيقة الأصلية **كاملة**: `docs/qa_next/BIL_20261016_CODEX_LOCAL_COACH_FULL_FIX_IOS37_ANDROID33_HANDOFF_AR.md`، ولا تسقط أيًا من ملاحظاتها الـ20 أو الإضافات الست ومواضع الصوت/التوقيت/RTL/المحادثات/العودة/نوافذ الخيارات/المكافآت/flicker والبلاغات.
- ادمج مع عمل Codex المحلي: قلّل rebuild/stream flicker، احفظ محتوى النص والترتيب والحالة أثناء الخلفية، اجعل keyboard/unfocus/voice recognition العربي فعليًا مع native prompts، أصلح قائمة (...) وحوارات حذف/تسمية المحادثات والتنقل الآمن، وطرق صرف credits حسب acknowledgement وليس التخمين.
- تحقق من استجابة الكابتن **وظيفيًا ضد backend staging**: سؤال بسيط ثم سياق محلي بعد موافقة، تغيير لغة/timezone، تقدير الوزن عند الغياب إذا كان مصرحًا، تصحيح يستبدل السابق، عدادات Tokens، إشعارات، رفض network و503 وعدم فقد أو تكرار user questions، وقفل cross-owner data. لا تُرسل سجلات صحية حساسة إلى CI.
- اختبارات Coach المخصصة المعزولة نجحت سابقًا (140 حالة في `39063805002`) لكن **هذا ليس إثبات نجاح AI Coach الحي في Production** ولا إغلاق إصلاحات Codex المحلية.

## 5. مواضع تعارض المرجعيات والاختبارات — لا تخفِ الفشل
**حزمة الاختبارات التي خضعت للمراجعة (غير مدموجة في Codex بعد):**
- المصدر/More على Windows أصبح أخضر بعد تصحيح انتظار `Administration` المحذوف من الهاتف. لكن تشغيل Full QA `39070955984` **فشل في focused Goldens**: `epic15_iphone_69_en_02_daily_log.png` فرق 3.18%، والعربي فرق 3.02%، و`visual_closure_daily_log_meal_entry_phone.png` فرق 1.76%، وأحد الاختبارات لم يجد `Plain Greek yogurt`. احتفظ بصور diff الأصلية قبل تعديل الرسم أو الـgoldens، افصل التغيّر المقصود عن الوميض/race، وأعد الاختبارين على Windows نفسه. **ممنوع Golden update تلقائي/قسرًا.**
- Android unsigned build 33 في `39070988786`: تم توليد AAB بعد إزالة `integration_test` الخاطئ من release registrant، ثم فشل فحص ELF الموقّع بالـSHA على `base/lib/arm64-v8a/libdartjni.so`: **GNU_RELRO end not 16 KB aligned**. هذه مشكلة ELF فعلية؛ لا يجزئ مجرد إصلاح Python ولا تعطيل checker أو إزالة scanner الأساسي. جرّب تحديث موثوق للتبعية أو البناء الأصلي/NDK واحتفظ بمقارنة bytes `.so` وreadelf وإثبات Bundletool وPixel emulator 16KB. لا تختلق PASS.
- iOS unsigned QA 37 في فرع `qa/bil07-ios37-unsigned-native-20261017` خضع لتعديلات Native permission/test خاصة أثناء الفحوص؛ **لا تنقل الملف الأخير منه بلا نتائج Green ومقارنة مصدر Codex المحلي**، وخصوصًا نصوص أذونات iOS بعد الرفض. لازم توقيع/إقلاع محاكي/ختام اختبارات أولًا.

## 6. الترتيب الإلزامي للدمج والاختبار والإغلاق
1. اعزل المحلي وأثبت Head ثم استلم **كوميت الحزمة الموحّد** قراءةً أولًا. اعمل reconciliation matrix لكل أصل/معدل/test، ولا تنقل تبديل route او permission يلغي عملك المحلي.
2. أكمل كل المتبقي بالأولوية: ضوابط reviewer UI/web، السحاب، AI Coach، الصلاحيات Native، قنوات المجتمع، الصور والمزامنة، ثم Golden. احتفظ بـRLS وpurchase proof وPostgREST permissions.
3. **اختبارات مركزة** متدرّجة لكل تعديل مع 25 لغة/RTL وحالة المالك A→B→A والتعاقب الزمني/404/503/تكرار إرسال. بعد PASS كامل: **جميع Golden** كاملة، ثم **تنسيق Dart صارم + Flutter analyze شامل**، ثم **Flutter tests الشاملة ~9,800+ عبر الثماني مجموعات بدون skip أو failures**، ثم فحوص Native/16KB والأذونات/المتاجر/إعادة التثبيت والرجوع.
4. عند إصلاح حالة فاشلة أعد اختبارها المركز أولًا، ثم أعد بوابات الاعتماد اللازمة على **نفس الشجرة الثابتة**؛ لا تعمل `dart format` أثناء الشاملة بما يغير الملفات المختبرة، ولا تسمِّ flaky test نجاحًا.
5. حضّر iOS **build 37** وAndroid **versionCode 33** كمرشحين موقَّعين **للاختبار فقط** إذا كانت صلاحيات التوقيع والتخزين آمنة ومطلوبة؛ لا ترفع TestFlight/Play/Production تلقائيًا دون تكليف رفع منفصل. أبقِ Android/iOS store-version metadata صحيحًا.
6. بعد **كل PASS فقط**: راجع `git status` و`git diff` و`git log`، اعمل **كوميت منتج واحد نظيف** على فرع Codex المحلي الأصلي بعد الدمج (لا force push)، ثم push وقدم SHA وPR/link ونتائج الوظائف والإخفاقات والإثباتات والمعلقات، **ثم توقف**. إذا بقيت بوابة فاشلة لا تعمل كوميت إعلان جاهزية منتج، بل سلّم block واضحًا.

## 7. قائمة القراءة المرجعية غير القابلة للسقوط
1. `docs/qa_next/BIL_20261016_CODEX_LOCAL_COACH_FULL_FIX_IOS37_ANDROID33_HANDOFF_AR.md`.
2. `docs/qa_next/BIL_20261017_LOGFOOD_QUICKADD_CAMERA_CODEX_MERGE_AR.md`.
3. `docs/qa_next/BIL_20261017_FOOD_SEARCH_PERMISSION_ADMIN_CODEX_HANDOFF_AR.md`.
4. `docs/qa_next/BIL_20261017_V36_RUNTIME_RELIABILITY_ISOLATED_AUDIT_AR.md`.
5. `docs/qa_next/BIL_20261017_BIL07_CHANNELS_ISOLATED_PROPOSAL_AR.md` مع `BIL_20261017_POSTGRES_POSTGREST_ISOLATED_E2E_AR.md`.
6. `docs/qa_next/BIL_20261017_ADMIN_GRANT_REVOKE_TO_VERIFIED_FREE_HANDOFF_AR.md` وخريطة استحقاقات Apple/Google منفصلة عن الهدايا.
7. الملفات المسجلة في `git diff --name-status ceb3570..origin/handoff/bil-20261018-unified-codex-reconciliation`، وكل test وCI حتى لو عنوانه QA فقط.

## 8. حدود الإثبات
**هذه الحزمة تضم إصلاحات حقيقية مختبرة على فروعها، لكن لا توجد شهادة نجاح للشجرة بعد دمج Codex المحلي، ولا ثبوت أن Production fully healthy أو أن AI Coach صار يرد فورًا أو أن Admin Web استلم كل الموافقات، ولا نجاح iOS37/Android33 النهائي.** تأكيد هذه الادعاءات يحتاج تشغيل المستخدم والتواقيع والفحوص المحددة أعلاه.
