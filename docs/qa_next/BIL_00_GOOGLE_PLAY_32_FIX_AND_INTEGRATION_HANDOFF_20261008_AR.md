# BIL-00 — Google Play 32: سجل الإصلاح التفصيلي وتسليم الاستكمال
**8 أكتوبر 2026 | QA ONLY | غير مكتمل / لا توجد موافقة Release**

> نقطة استلام صالحة لمحادثة أخرى. هذه الوثيقة تُحدّث التسليم `docs/qa_next/BIL_00_INTEGRATION_HANDOFF_2026-10-08_AR.md` ولا تلغيه. لا تعُد إلى دمج الحزم BIL-01…08. **اقرأ HEAD الحالي قبل أي تعديل**؛ آخر HEAD تم التحقق منه قبل حفظ هذه الوثيقة هو `a2fad76241c81ee4bd01d6315db7379de1140622`؛ وقد يتحرك بعد حفظ الوثيقة.

## 1. الهوية والقيود غير القابلة للتجاوز
- Repository: `bilhealth-admin/Body-Intelligence`.
- **الفرع الوحيد المسموح كتابته:** `qa/coach-community-next-20261005`. استخدم fast-forward ومقارنة SHA/expected_sha قبل نقل المرجع. لا تلمس `main`.
- مصدر إصدارَي المتاجر التاريخيين: `3f0085e6e6686f2e87e9cf14789e9e578ea64159`. Android مرفوض `1.0.0 / versionCode 32`؛ iOS محتمل تأثره `1.0.0 / build 35`.
- Production Supabase project ID: `tgmanzhqulksykhslrzb` — **لا تُعدّل Production، لا تنشر migrations/Functions، ولا تغيّر حقول المستخدمين أو منح المراجعة أو مفاتيح الدفع**.
- ممنوع نشر IPA/AAB، أو تغيير Android 32 / iOS 35، الأسعار، Trial، الدفع، أو رفع مراجعات المتاجر دون إذن جديد. لا تختبر شراءً حقيقيًا تلقائيًا. لا تستعمل reviewer email أو access token أو أسراره في test fixtures.
- Dashboard **مجمّد بصريًا**: لا تتغير هندسته أو بطاقاته أو الترتيب/المسافات/الأيقونات. BIL-01…08 مدموجة مسبقًا بالكوميت `c653fb55485369da62915953ccc0c721dd4cc9ed` ولا تُدمج مرة ثانية.

## 2. إثبات الرفض / حدود ما نعرفه
البريد الرسمي بتاريخ 2026-10-08: `Violation of Play Console Requirements`، سبب `App content is restricted by a paywall`، `Version code 32: In-app experience`، Screenshot `IN_APP_EXPERIENCE-6955.png`، Submission `39` (إرسال 5 أكتوبر، رفض 8 أكتوبر). يظهر في الرحلة نجاح الوصول للتطبيق ثم `Dashboard → Goals → advanced nutrition → Plans`. لم يصرح البريد بأسباب أخرى مثل privacy/ads/health.
- كوديكس قدّم فحص Production مباشرًا مستقلًا: حساب المراجع موجود ومؤكد وسجل دخولًا يوم 8 أكتوبر، `bil_ai_closed_test_grants.active=true` إلى 2027-10-05، `bil_subscriptions.plan_id=premium_ai_coach`/`lifecycle=active` و`bil_ai_coach_subscriptions` نشط و`plan:premium_ai_coach`، و`bil_get_ai_usage_status` أعاد 2500 included + 2500 paid = **5000**. وعزا المشكلة إلى التطبيق، لا إلى كلمة مرور أو رصيد.
- **تمييز الإثبات:** هذه نتائج فحص أبلغ عنها كوديكس/المستخدم؛ هذه الجولة لم تُعد فحص Production بهوية المراجع ولم تستخدم بياناته. الثابت باستقلالية في GitHub أن نموذج `premium_ai_coach` يرث `advancedIntelligence` وأن تحويل Goals إلى Plans عند false موجود في كود الإصدار 32. لقطة الرفض تثبت الانتقال، لكنها لا تثبت أي API فشل لحظة الضغط.
- لا تضف secret bypass أو hardcoded-success أو عضوية وهمية/مشتريات مزوّرة أو تعتبر Play Console مصدر استحقاق. حساب المراجع قد يحتاج فحصًا حقيقيًا على artifact Play لاحقًا بعد الحصول على إذن.

## 3. السبب البرمجي المؤكد والإصلاحات المنجزة على QA
### السلوك الأصلي الذي سبب انتقال الشاشة
- `lib/features/settings/reference_goals_components.dart` كان يعتمد على `verifiedSubscriptionStateProvider`، ثم يحسب `active = state.grants(CommerceEntitlement.advancedIntelligence) ?? false`.
- `lib/features/settings/reference_goals_page.dart` كان يعرّف `premiumGoalDestination(bool active, route) => active ? route : '/plans'`. هكذا قد يحوّل Free محليًا/استحقاقًا غير مُكتملًا أو نتيجة قديمة إلى Plans **قبل** دخول بوابة الميزة المحمية، رغم أن Meal Calories / Meal Macros / Exercise Calories لها Gates فعلية.
- `verifiedSubscriptionAccessProvider` هو عرض الاستحقاق الدقيق مع cutoff/owner وربط التحديث، لكنه لم يكن مستخدمًا في صفحة Goals القديمة.
- Grant الإدارة في `supabase/migrations/20260910014118_admin_subscription_grants.sql` يعطي `access_until` قصيرًا، لا وصولًا من الكود حتى تاريخ انتهاء المنحة الطويل؛ التطبيق يجدّد تصريحًا محدودًا. لا تمد فترة الوصول اصطناعيًا لتجاوز فشل الشبكة.
- `lib/features/commerce/repositories/server_entitlement_repository.dart` كان يسلسل قراءة جدول Closed Testing ثم mirror subscription؛ فشل قراءة الأولى قد ينقل المسار إلى fallback دون تجربة المرآة المدفوعة المستقلة. الإصلاح الجديد يواصل التحقق المنفصل؛ إذا تعذر إثبات عدم وجود منحة مستقلة، يجب أن تبقى نتيجة Free **غير موثقة**، لا تُعرض Paywall كأن الحساب Free.

### الكوميتات المتسلسلة (كلها QA وليست release)
1. `452383812e3d9db7fbbac4859450f54acbc98786`: أصلح Goals navigation / verified cutoff، وضع fail-closed Retry في Gate أهداف التغذية، اختبار Premium/Free/unknown، وإصلاح دور `anon` المكرر في fixture SQL المعزول.
2. `a44490fc8ad33b70623771bacf322bf74e94653d`: وسّع فرز unknown مقابل verified Free إلى `PremiumRouteGlassGate` و`PremiumNutritionGlass` وbarcode وMore/profile؛ أضاف owner regression واختبارات بوابات.
3. `bc46dc59874b35fcf613179446f6c9aba5af925c`: قراءة الاشتراكات منفصلة بعد انقطاع Closed Testing؛ refresh on app resume، وتجارب fixture لقراءة mirror مع خطأ Closed Testing.
4. `af0e413970b467d97932bdda9ee8e7fe9ade11aa`: حافظ على unknown overlay عندما تكون المرآة Free، وأضاف 15 feature-gate matrix، وصحح ثلاثة format paths.
5. `333432446df57daed51451e601cce793430f6fbe`: أضاف حماية Connected Health/recipes/workouts للـunknown، وعدّل CI ancestry fetch من 128 إلى 512 **دون تعطيل** `git merge-base --is-ancestor`.
6. `1cd3153810b8c976bb8a79495879ee03f0a61b87`: فصل helper مكتبة الوصفات للحفاظ على سقف حجم الملفات، وصحح تنسيق Checks الخاص بالتمارين.
7. `a2fad76241c81ee4bd01d6315db7379de1140622`: جعل دورة `AppLifecycleListener` آمنة في Headless Flutter tests، وفصل Refresh AI Coach عند resume؛ عدل اختبارات retry لقراءة شبكية اصطناعية وأصلح fixture باركود ليحمل فترة صلاحية موثقة.

**لا تعدّ هذه التغييرات إثباتًا لإزالة الرفض من نسخة Play 32؛ النسخة التي راجعها Google لم تتغير.** source تغيّر، وتحتاج artifact جديدًا منفصلًا بعد approval.

## 4. CI والاختبارات — آخر أدلة لا ينبغي تزيينها
- Latest branch HEAD قبل حفظ الوثيقة: `a2fad76241c81ee4bd01d6315db7379de1140622`.
- CI للـHEAD السابق:
  - `37778334674` على `af0e413`: failed قبل Flutter بسبب حد shallow history في frozen-base ancestor guard؛ دليل المقارنة من GitHub أظهر أن source released هو ancestor، فحُددت زيادة عمق التاريخ إلى 512 (وليس حذف guard).
  - `37781083258` على `3334324`: Git ancestry gate وصل إلى Flutter؛ فشل format والـarchitecture file-size، والـdownstream skipped. Recipe library تجاوز سقف 850 الاستثنائي وعُزل helper لاحقًا.
  - `37781886759` على `1cd3153`: failed؛ يلزم قراءة jobs/artifacts عند الاستكمال لمعرفة موضعه بالضبط.
  - **`37785213798` على `a2fad762`: completed / failed عند `Analyze all application source`؛ ثبت analyzer info: `unnecessary_import` في `lib/features/commerce/providers/commerce_providers.dart:3` لاستيراد `package:flutter/foundation.dart show FlutterError` لأنه متاح من `package:flutter/widgets.dart`. صحّح import بلا تقليل lint. Jobs visual/portable-regression/isolated-SQL skipped في هذا التشغيل؛ لا تدّع نجاحها.
- CI سابق على `4cd63c...`: `flutter-checks` و`flutter-visual-capture` نجحا، 3 regression shards مرت ورابع أُلغي عند إعادة CI؛ isolated SQL فشل لأن fixture حاول `CREATE ROLE anon` وهو موجود. أصلحت SQL fixture في `452383...`، لكن لم يُثبت بعد اجتياز SQL على أحدث SHA.
- حواجز مطلوب أن تكون كلها PASS على **SHA واحد أخير**: Dart formatter، flutter analyze بلا info/warning/error، focused tests، architecture/performance، 4/4 portable regression shards، isolated PostgreSQL17 SQL (بما فيه BIL08 migration مرتين وقيود ACL)، screenshots الفعلية. لا تزيل assertions أو تقلّص نطاق الاختبارات لتنجح.

## 5. تعليمات الاستكمال الفوري للمحادثة التالية
1. افحص HEAD الحالي وجميع CI runs. إذا لم يكن analyzer import ما يزال موجودًا لا تعِد تعديله؛ إن بقي، احذف الاستيراد الزائد فقط واعمل commit QA (أو راجع آخر CI إن كان Codex يصلح بالتوازي). **استخدم expected SHA lease ولا تستبدل تغييرات متزامنة**.
2. عالج جميع failures الفعلية للـCI على كل SHA جديد. لا تكتفِ بـanalyze؛ راجع نتائج widget/host وSQL والـvisual jobs. إن تعذر فك artifact في الموصل، سجلات job GitHub هي المصدر؛ وحين تكون run لا تزال جارية قد يرفض GitHub تنزيل السجل، فيُعاد بعد الانتهاء.
3. راجع كل مسارات الدفع فعليًا، لا Goals فقط: AI Coach `total_remaining>0`؛ Nutrition Analytics؛ 3 Goals Premium؛ Nutrition Programs؛ Weekly Report؛ Workout/Recipe Library/Import؛ Meal Planner؛ Connected Health؛ Barcode؛ `PremiumRouteGlassGate` وجميع `/plans` callers. احفظ fail-closed وowner isolation، وامنع أي Free قديم من Guest/previous owner أو pending refresh من خلق upsell كاذب.
4. اختبارات regres­sion اللازمة: guest→signed paid، grant after auth, delayed RPC, stale verified Free→new paid, same-owner refresh/error, resume, re-entry, sign-out/switch A→B→A, no owner leakage, quota=5000 vs 0, pending, revoked/expired boundary, verified Free lock, purchase/restore لا يمنح قبل التوثيق، ومقارنة behavior قبل الإصلاح وبعده. يجب اختبار تغيير الحساب مع in-flight futures.
5. لا تعد اختبار widget الذي يستبدل `verifiedSubscriptionStateProvider` مباشرة إثباتًا كاملًا لتكامل Supabase؛ الاختبار الأقوى `test/features/commerce/reviewer_subscription_mirror_fallback_test.dart` يستعمل `MockClient` وبيانات وهمية، ويجب تأكيد PASS بالـCI؛ يلزم أيضًا device E2E.
6. **القبول النهائي يحتاج إثبات جهاز فعلي:** بناء Android جديد **versionCode >32** فقط بعد تصريح منفصل، تثبيت Play testing artifact الحقيقي، تجربة reviewer account الفعلي، فيديو فتح AI Coach وGoals جميعها وnutrition analytics بلا شراء؛ جهاز Free يُقفل؛ ثم TestFlight iOS جديد **build >35** إذا تقرر إطلاق إصلاح Apple. لا ترفع builds أو تغير الإصدارات من هذا التفويض.
7. iOS StoreKit حقيقي: success/cancel/failure/pending/already-owned/restore/backend verify/unlock/relaunch/revoke/refund؛ mocks لا تفي بالشرط.
8. لا تُعلن "انتهيت" أو Release-ready ما دام CI أو visual parity أو device evidence ناقصًا.

## 6. BIL-00 الأصلي: الأعمال الموازية غير المغلقة
الحزم BIL-01…08 مدرجة في GitHub؛ المهمة تشمل أيضًا QA للحزم وvisual polish. **Dashboard ممنوع لمسه بصريًا**، AI Coach وCommunity حسب صور BIL المعتمدة، والباقي حسب reference ZIP MyFitnessPal (من Library). آخر جرد سابق: نحو 146 صورة مرجعية، 125 عناصر polish، 7 Dashboard مجمّدة، 3 billing/trial مقفلة، و42 صفحة مرشحة لم يحصل لها تطابق مرجعي موثّق، **pixel parity لم تُثبت**. 144 screenshot Community synthetic Flutter فعلية من CI سابق هي captures لا شهادة تطابق. لا تعِد تصميم Community/Dashboard ولا تبدّل مرجع Coach بـMFP.
حافظ على Food Search (+ دائري، لا "+ Add")، Customize Today=Log out، Exercise JSON لا يظهر نصًا بل عنوان الروتين، Food/Coach يسجلان في السجل الفعلي، وملفات supabase في QA لا تُنشر.

## 7. روابط أدلة سريعة
- [كوميت الإصدار التاريخي](https://github.com/bilhealth-admin/Body-Intelligence/commit/3f0085e6e6686f2e87e9cf14789e9e578ea64159)
- [أصل تكامل الحزم الثمانية](https://github.com/bilhealth-admin/Body-Intelligence/commit/c653fb55485369da62915953ccc0c721dd4cc9ed)
- [آخر كوميت تطبيقي كان معروفًا عند توثيق هذه الحالة](https://github.com/bilhealth-admin/Body-Intelligence/commit/a2fad76241c81ee4bd01d6315db7379de1140622)
- [CI الأخير الذي فشل analyzer](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37785213798)
- [سجل CI السابق](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37781083258)
- [مسار إصلاح Goals](https://github.com/bilhealth-admin/Body-Intelligence/commit/452383812e3d9db7fbbac4859450f54acbc98786)
- [مسار إصلاح قراءة Closed Test + subscription](https://github.com/bilhealth-admin/Body-Intelligence/commit/bc46dc59874b35fcf613179446f6c9aba5af925c)
- [معالجة connected health / workouts / recipes](https://github.com/bilhealth-admin/Body-Intelligence/commit/333432446df57daed51451e601cce793430f6fbe)
- الوثيقة الأصلية: `docs/qa_next/BIL_00_INTEGRATION_HANDOFF_2026-10-08_AR.md`.

**الوضع النهائي وقت تسليم هذه الوثيقة: إصلاحات كود على QA فقط؛ الاستحقاقات الحقيقية على artifact متجر لم تختبر؛ CI أحدث SHA أحمر؛ regression/SQL/Visual/device E2E لم تغلق؛ لا production/store modifications؛ لا إعلان اكتمال.**
