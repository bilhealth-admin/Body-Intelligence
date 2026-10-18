# BIL — تسليم كاميرا Log Food وQuick Add + دمج Codex المحلي + سياسة Apple (17 أكتوبر 2026)

**حالة هذه الوثيقة:** نتائج GitHub على فرع اختباري مستقل فقط؛ ليست اعترافًا بإنجاز Codex المحلي ولا موافقة إصدار أو TestFlight.
**المستودع:** `bilhealth-admin/Body-Intelligence`
**أساس التعديلات المصورة:** `integration/bil-qa-media-policy-20261011` عند `ceb3570cc46c387f25e7e9821bb4aa4120b53d71`.
**فرع تدفق الصور:** `fix/bil-photo-entry-ux-20261017`.
**فرع سحب المنح السابق:** `fix/bil-admin-revoke-verified-free-20261017` (المرجع `becd992acef17f46fc06cf5859816ba5310e6146`).
**أصل طلبات إصلاح Codex الـ28+ للمشروع:** `docs/qa_next/BIL_20261016_CODEX_LOCAL_COACH_FULL_FIX_IOS37_ANDROID33_HANDOFF_AR.md`.

## أ. التصوير — ما رأيناه وما أصلحناه

### 1. كاميرا Log Food (الصورة المرفقة من المالك 17/10)
السلوك الخاطئ: `FoodLogPage` كان ينفذ `setState(mealImageBusy=true)` عند ضغط «Analyze a meal photo»، قبل أي اختيار كاميرا/معرض أو موافقة. ثم يستبدل `_buildBody` بمؤشر دوران؛ تظهر شاشة رمادية خلف ورقة اختيار المصدر، ويختفي نموذج Log Food.

**الإصلاح:**
- حفظ `mealPhotoRequestInFlight` كقفل يمنع النقرتين المتزامنتين **دون تغيير الواجهة** أثناء اختيار المصدر أو الموافقات.
- ترك `mealImageBusy=false` حتى تتوفر `XFile` غير فارغة وصالحة للتعامل معها، ثم إظهار التحليل فقط عند بداية `service.analyze(image)`.
- الإبقاء على الصورة المرجعية والفئات وتاريخ/نوع الوجبة وزر إلغاء ومراجعة النتيجة والتأكيد الصريح قبل حفظ أي شيء. لا تعديل للـHome ولا لشريط الأيقونات الخمس ولا أسعار الخطط.

### 2. Quick Add → Analyze meal photo
السلوك الخاطئ: `bil_quick_add_presenter.dart` يدفع `/quick-add/meal-camera` ثم يعرض `QuickAddMealCameraPage` فارغة مع `CircularProgressIndicator`، وبعدها يفتح كاميرا؛ شعور انتقالين/شاشة سوداء، مع فقدان الصفحة الأصلية في الخلفية.

**الإصلاح:**
- من ورقة Quick Add ذات الإجراءات السبعة، ينتقل الخيار «Photo» بعد إغلاق الورقة إلى قائمة **«Take a photo / Choose from device» فوق نفس التبويب الحالي** عبر `showBilModalBottomSheet<ImageSource>`. لا يتم دفع route مؤقت.
- الإلغاء، وسحب الورقة لأسفل، ورفض صلاحية الكاميرا، ورفض الموافقة أو عدم توفر الرصيد: لا ينشئ سجل طعام ولا يدفع شاشة تحميل ولا يضيع موضع المستخدم.
- بعد صورة كاميرا فعلية أو ملف معرض مع `showBilMediaReviewSheet` والموافقة الصريحة، فقط بعدها `context.push('/daily-log?foodLog=1&action=photo&from=...',extra:XFile)` إلى مسار Food Log الحالي ومراجعة التحليل والتسجيل الذري.
- الحفاظ على `BilRecoverableImagePicker` لأنشطته الخاصة بالصور، وطلب صلاحية الكاميرا عند الحاجة فقط، ولا تطلب صلاحية واسعة للمكتبة.
- وظيفة `showOptionalAccessOffer` أصبحت تدعم إعادة استخدام نفس شاشة العرض اختيارية خطط/إعادة التحقق من مواضع لا تحتوي `WidgetRef`، دون الالتفاف على اشتراك أو حصة Vision.
- أبقِ المسار التاريخي `/quick-add/meal-camera` خارج أي زرٍ ظاهر في هذا التعديل؛ على Codex تدقيق مرجعياته في آخر شجرة مصدر محلية قبل حذفه أو تحويله إلى Redirect آمن، لا تترك مدخلًا إداريًا مخفيًا.

**ملفات العمل المصورة:**
`lib/features/daily_log/food_log_page.dart`
`lib/features/daily_log/food_log_actions.dart`
`lib/app/router/bil_quick_add_presenter.dart`
`lib/app/router/bil_quick_add_photo_flow.dart` (جديد)
`lib/features/commerce/presentation/optional_access_offer.dart`
`test/app/router/bil_quick_add_presenter_test.dart`
`test/features/daily_log/quick_add_meal_camera_contract_test.dart`
`.github/workflows/bil_photo_entry_ux_targeted_20261017.yml`

### 3. دليل الاختبارات
- GitHub Actions مسار Camera UX `39036658915`: Flutter SDK 3.44.6؛ 26/26 اختبارات مركزة، و`flutter analyze` للملفات المعدلة دون مشاكل، وتشغيل `dart format` في بيئة CI.
- راجع التشغيل بعد تثبيت تنسيق Dart على الفرع؛ لا تعتمد «ناجح» قبل أن يكون أحدث commit/WORKTREE نفسه مطابقًا لما اختُبر.
- الأجزاء المستهدفة: إلغاء الورقة في Quick Add، اختيار مصدر فوق نفس الصفحة، عدم دفع Loading route، Food Log progress فقط بعد XFile، barcode/voice/vision/old premium flow.
- لا توجد تجربة كاميرا فعلية على جهاز المالك عبر هذه المحادثة، ولا اختبار 9800 حالة شامل لعمل Codex المحلي؛ لا ترفع صفة «جاهز للإصدار» لهذا التعديل وحده.

## ب. إصلاح مستقل واجب الدمج: إلغاء الهدية Premium → Free موثوقة
ثبت في Supabase Production أن منحة Haya الاختبارية مُلغاة، ولا توجد مشتريات متجر/Closed Test مستقلة. لكن نسخة Flutter السابقة تعرض `Subscription check unavailable` لأن `ServerEntitlementRepository` يرجع `FreePlan.createState()` بـ`localDefault` بدل Free موثقة حين تنجح **كل مصادر القراءة الثلاثة** وتعود بلا استحقاق نشط.
الفرع `fix/bil-admin-revoke-verified-free-20261017` يحمل الإصلاح في `lib/features/commerce/repositories/server_entitlement_repository.dart` + اختبار جديد. ثبتت نتيجة `27/27` و`flutter analyze` نظيف في تشغيل `39034708852`. لا تغيّر Production ولا تعِد منح Haya. لا تسمح بالانتقال إلى Free موثقة عند فشل أي RPC أو عند وجود شراء Apple/Google مستقل.

## ج. أوامر الاستلام لـCodex المحلي — **الحالة المحلية غير مثبتة**
اتصال Desktop Commander بجهاز Windows الخاص بالتنفيذ **غير متاح عند هذا التسليم**؛ وفرع `integration/bil-qa-media-policy-20261011` على GitHub لا يحوي كوميتات جديدة من Codex للإصلاحات المعلّقة (آخر remote HEAD المشاهد `ceb3570`، وثيقة handoff فقط). لذلك **لا يجوز القول إن AI Coach أو بقية الـ28+ بندًا قد اكتمل**.

المطلوب من Codex:
1. قبل أي خطوة: اعرض `git status --short` و`git branch --show-current` و`git rev-parse HEAD` و`git diff --stat` مع تقرير diff للملفات المعدلة غير الملتزمة، واحفظ نسخة احتياطية. أوقف أي auto-commit/auto-rebase/auto-HEAD shift. لا reset، لا clean، لا force push. اقرأ وثيقة `BIL_20261016_CODEX_LOCAL_COACH_FULL_FIX_IOS37_ANDROID33_HANDOFF_AR.md` كاملة.
2. اقرأ فروق **فرع الصور** و**فرع سحب المنحة** مقابل أساس `ceb3570` على GitHub، وقارن سطرًا بسطر مع الـworking tree المحلي. لا `git checkout` لملف فوق نسخة Codex المعدلة ولا `git merge` آليًا لفرع الصور؛ انقل الـhunks الضرورية بشكل واعٍ إلى نفس الشجرة المحلية، وادمج اختبارات الإصلاحين دون فقدان عمله.
3. أعطِ **تقرير حالة مدعوم بالأدلة** لكل جزء من خطة المدرب الذكي: (نفّذ/جزئي/لم ينفذ/محجوب) مع أسماء الملفات وdiff والاختبارات والمخرجات. شمل AI Coach response 503 (العميل مقابل Edge/Gemini)، الوميض والردود وتاريخ الدردشة وزر الرجوع والـQuick Add، notifications, media, exercise videos, Community Channels missing RPC, friends count, sync, purchases, Analytics, Home. عدم معرفة حالة Codex المحلية لا يعني النجاح.
4. نفذ إصلاح الصور مع المحافظة على الـ5 Bottom Tabs، شكل Home، Log Food، Trial/Prices، والضوابط الأمنية. راجع iOS/Android: فتح الكاميرا والمعرض، إلغاء المصدر، permission denied, Android lost-picker recovery, consent; صورة Review واحدة، ولا تسجيل قبل تأكيد، ولا تكرار نتيجة تحليل أو سحب رصيد.

## د. ترتيب الفحص والدمج الإلزامي **حسب آخر أمر المالك**
**تنفيذ جميع الإصلاحات محليًا** → **اختبارات مركزة لكل جزء** (ومنها الفرعان أعلاه ومدرب AI Coach) → **Golden/visual مقارنة بصرية** (لا `--update-goldens` أو تثبيت صور جديدة لإخفاء مشكلة إلا بمراجعة المالك) → **`dart format` شامل + `flutter analyze` شامل دون أي مشاكل** → **مجموعة Flutter الشاملة ≈9800+ على شجرة نهائية ثابتة، صفر FAIL** (يمكن 8 shards متوازية) → **تحقق Native/CI ذو الصلة إن لزم وفرق الملفات/ملكية المصدر** → **كوميت منتج واحد نظيف، ثم `push` إلى GitHub، مع HEAD ونتائج مفصلة للمالك**.

لا تبدأ توقيع/رفع iOS 37 أو Android 33 أو TestFlight/Play Production تلقائيًا بموجب هذا الطلب؛ سؤال المالك الحالي هو «كوميت نظيف مرفوع»، ثم يصدر قرار بناء/رفع منفصل.

## هـ. Apple/Google — البريد الأخير وموضع الإدارة
تم الاطلاع على تنبيه Apple الرسمي بتاريخ **16 أكتوبر 2026** «Updated App Review Guidelines are now available»:
- **1.2 UGC:** حماية المجتمع، المراجعة/التبليغ/الحظر، حماية من الصور الحميمة غير التوافقية/AI، وسرعة معالجة المحتوى المبلغ عنه.
- **2.3.14 Creative Assets:** الصور التسويقية والادعاءات واقعية وتمثل وظائف المنتج وليست أسعارًا أو وظائف مضللة.
- **2.5.19:** ممنوع وظائف مخفية/خاملة/غير موثقة في باينري iOS أو تفعيلها خفية بعد المراجعة. هذا يتطلب تدقيق **كامل** لشاشات وروابط/بوابات الإدارة المالية داخل Flutter؛ إذا تقرر نقلها للويب، أزل مدخلها ومنطقها من باينري العميل بدل إبقائها كميزة مخفية وراء route/flag، مع الحفاظ على إدارة Supabase/Web خارج التطبيق.
- **3.1.1(a):** لا تضف روابط شراء خارجية أو ممرات Payment إلا عند استحقاقات أو شروط Apple المطبقة في الأسواق المعنية؛ احتفظ بـStoreKit/Restore/المطابقة الفعلية للمشتريات.
- رسالة App Store Connect بتاريخ **14 أكتوبر** تعلن وجود مشكلة في submission لكنها **لا تعطي بند الرفض في الإيميل نفسه**؛ تحقق من Review Details في App Store Connect ولا تخمّن السبب.
- تدقيق ATT/App Privacy/Tracking، التراخيص، الصلاحيات (Camera/Gallery/Microphone/HealthKit)، البطاقات/تسميات Premium، ونسخ الصور المسموح بها، وإيضاح Notes for Review وأرصدة المراجعين دون مسار Paywall خاطئ. تدقيق Google Play policy/reviewer paywall أيضًا قبل أي رفع.
- **تأجيل العمل على لوحة إدارة الويب/نطاقها الآن** بناءً على قرار المالك؛ لا تعدّل Replit أو Supabase/منح المستخدمين لهذا المهمة. إزالة عناصر الإدارة المحمولة تُنفذ في شجرة Codex بعد تدقيق اعتماد البديل دون إفساد وظائف الاشتراك للمستخدمين أو طرق مراجعة المتاجر.

**قرار نهائي:** لا كوميت منتجات وpush باسم «جاهز» إلا بعد اجتياز هذا التسلسل من ملفات Codex المحلية نفسها. لا تستخدم نجاح CI منفصل على فرع الإصلاح كدليل نجاح كل ملفات Codex المحلية.
