# BIL — تسليم إصلاح بحث الوجبة وزر الإضافة والصلاحيات وإزالة الإدارة المحمولة — 17 أكتوبر 2026

## المصادر والحدود
- الفرع `fix/bil-meal-permissions-search-admin-ready-20261017` ينطلق من كوميت إصلاح الكاميرا `bd13908fa80698116e29d6749b33ea2cb82690ed`.
- `git diff ceb3570..HEAD` يعرض إصلاح الكاميرا مع إصلاحات البحث/الصلاحيات والإدارة؛ `git diff bd13908..HEAD` يعرض إضافات هذه الدفعة فقط.
- هذا فرع تعديل وQA منفصل؛ حالة Codex المحلية غير مؤكدة، فلا تُبدّل الشجرة دون جرد ونسخ احتياطية ومقارنة hunks. لا reset/clean/force push ولا تعديلات Production ولا auto-commit.

## أعمال المصدر
1. استبدال SearchAnchor فوق DailyLog ببحث inline في نفس صفحة Breakfast/Lunch/Dinner/Snack، بما يحفظ query/keyboard/stream ويزيل شاشة البحث الثانية ووميضها.
2. استبدال Icon الزخرفي غير الفعال في Foods in this meal بـIconButton مستجيب مع semantics؛ توفير إضافة داخل القائمة غير الفارغة أيضًا.
3. توحيد rationale/recovery الخاصة بالكاميرا والصوت/ميكروفون في BilPearlAlertDialog؛ iOS native prompt الأول لا يُستبدل، وAndroid voice disclosure يبقى، واختيار Settings صريح لا تلقائي.
4. Barcode داخل FoodLog يتحقق من native Camera permission قبل scanner، والمعرض يستخدم system picker دون صلاحية واسعة، والتحليل يتطلب Vision consent والرصيد القائم.
5. تحسين حوارات الباركود/الصوت/موافقة Vision وبعض أحداث طعام DailyLog لتناسق Pearl.
6. إزالة mobile admin route من GoRouter ومدخله من More وقناة قراءة admin access في الشاشة؛ لا يتغير تحقق الإدارة server-side ولا قواعد community reporting/moderation. ملفات المصدر القديمة غير المرتبطة بالباينري تبقى لاختبارات التوافق، ويجب تدقيق AOT tree-shaking قبل النشر.
7. اختبارات UI للسلوك الفعلي ولإزالة مسار admin واختبارات البحث RTL/locale ورجوع الطعام؛ workflow مركزة مستقلة.

## قبول/امتثال
- سياسة Apple تحديث 16/10: UGC (1.2)، Creative assets (2.3.14)، Native recording consent (2.5.14)، Hidden features (2.5.19)، StoreKit external purchase caveats؛ Android minimum scoped runtime permissions وAndroid Photo Picker؛ تدقيق مصدر فقط، لا ادعاء تدقيق Production أو اكتمال كل سياسات المتاجر.
- فحص أصل System Permission Android Camera/RECORD_AUDIO وصياغة iOS NSCamera/NSMicrophone/NSSpeechRecognitionUsageDescription; تجربة حقيقية على أجهزة ضرورية.
- تحقق وظيفي: `فول` و`فو` و`فورتت`، لوغ بوك وتوداي، تغيير الحروف بسرعة، انتظار النتائج من الجهاز والسحابة، إلغاء واستئناف، + أثناء الوجبة الفارغة والممتلئة، السحب/رجوع و keyboard، العربية/25 لغة، صلاحيات deny/allow/never ask/restricted، وعدم تجاوز entitlements أو Vision AI consent.

## إلى Codex
1. اقرأ أيضًا `docs/qa_next/BIL_20261016_CODEX_LOCAL_COACH_FULL_FIX_IOS37_ANDROID33_HANDOFF_AR.md` و`docs/qa_next/BIL_20261017_LOGFOOD_QUICKADD_CAMERA_CODEX_MERGE_AR.md` كاملتين مع هذه الوثيقة.
2. اعرض الحالة المحلية الأصلية HEAD, branch, status, diff, files وحافظ عليها. اسحب الفرع في صورة مرجع فقط؛ ادمج الhunks المناسبة مع إصلاحاتك المحلية ولا تستخدم cherry-pick أعمى ولا overwrite.
3. أكمل قائمة AI Coach القديمة والطلبات الست الجديدة وتحقق من كل ملف ودليل.
4. جهّز أرقام المرشحات iOS build 37 وAndroid versionCode 33 دون توقيع أو رفع متجر الآن.
5. الاختبارات: مركزة لكل عنصر → Golden كاملة → dart format/Flutter analyze شامل → Flutter tests كاملة ~9800+ صفر FAIL → فحوص Native/16KB والخصوصية ذات الصلة → مراجعة الشجرة الثابتة.
6. فقط بعد النجاح على Worktree النهائي ارفع **كوميت منتج واحد نظيف** على فرعك الأصلي وقدّم SHA ورابط الاختبارات ثم **توقف**. لا TestFlight أو Play أو Production إلا بتكليف منفصل.

### تدقيق تكميلي
- Food Log مستقل: إخفاء حالة "لا توجد أطعمة" أثناء البحث الفعلي، إزالة الرسالة المكررة، تحويل عنوان النتائج إلى «نتائج البحث»، وتهدئة الطلبات السريعة لمدة 160ms دون تبديل الصفحة.
