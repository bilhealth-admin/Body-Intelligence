# BIL P0 — إصلاح رجوع Premium إلى Free بعد سحب المنحة الإدارية

**التاريخ:** 2026-10-17
**الحالة:** الإصلاح موجود في فرع مستقل، ولا يحتوي على أي تعديل Production أو Store أو CI release.
**Branch:** `fix/bil-admin-revoke-verified-free-20261017`.
**الملفات الأساسية:** `lib/features/commerce/repositories/server_entitlement_repository.dart` و`test/features/commerce/admin_revocation_verified_free_regression_test.dart`.

## الواقعة المؤكدة
بعد منح Premium لمدة 30 يومًا للحساب التجريبي `Haya1ksa2@gmail.com` نجح فتح المحتوى داخل التطبيق. بعد سحب نفس المنحة من BIL Admin Web ظهرت صفحة `Nutrition Programs → Subscription check unavailable` بدل حالة Free الطبيعية.

- **Production SQL:** المنحة نفسها `revoked_at` غير فارغة؛ عدد المنح النشطة رجع إلى 5. لا يوجد لهذا الحساب اشتراك مدفوع من المتجر ولا Closed-Test grant ولا استحقاق آخر.
- **Supabase logs:** الجهاز يستدعي `bil_ai_closed_test_grants` و`bil_subscriptions` و`bil_get_my_admin_subscription` مع HTTP 200 عدة مرات بعد السحب. هذا ليس تأخر إلغاء منحة على الخادم.
- **Flutter root cause:** `_storeCurrent` عندما تكون `bil_subscriptions` فارغة يستعمل `_transientFallback`، ويُعيد `FreePlan.createState()` بصلاحية `localDefault`؛ `composeAdminSubscriptionAccess()` يعيد نفس الحالة إذا كان RPC المنحة `null`. بعدها `PremiumRouteGlassGate` يرفض Free المحلية لأن `authority != verifiedServer`، فتظهر `Subscription check unavailable` بلا توقف.

## الإصلاح
القراءة الحالية لثلاثة مصادر منفصلة تُستخدم لإثبات Free **فقط** إذا:
1. انتهى طلب Closed-Test بنجاح ولم يظهر أي منح مدفوعة.
2. انتهت قراءة Store mirror بنجاح وعادت بلا صف، ولا توجد continuity مدفوعة موثقة سارية.
3. انتهى RPC المنحة الإدارية بنجاح وأعاد `null` (لا منحة حالية).

عند تحقق الثلاثة تُنشأ `Free` بـ`EntitlementAuthority.verifiedServer`. أما إذا فشلت أي قراءة فيجب أن تبقى النتيجة `localDefault` غير متحققة (Retry) **ولا** تُعرض باعتبارها Free موثقة. وتبقى مشتريات المتجر الموثقة محمية ومستقلة، ولا يغير التطبيق أي سجل SQL أو صلاحية.

## نتيجة الاختبارات
- Flutter `3.44.6`، `flutter analyze` للملفين المعدلين: **0 مشاكل**.
- GitHub Actions focused 27/27: **PASS** بتاريخ 17 أكتوبر، بالمرجع `39034300021`:
  https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/39034300021
- تشمل الحالات: Free بعد سحب المنحة، Premium أثناء المنحة، Premium من متجر مستقل، فشل أي واحد من مصادر القراءة، انتقال Premium→Free، اختبارات المراجعين، owner epoch، وبوابة Premium.
- بعد نجاح الاختبارات ثُبّت تنسيق Dart للملف الجديد في commit `656e4bd967a6edd4c254c4f4c8af40fbe6272ee3`، وأعيد تشغيل نفس CI للنسخة المنسقة.

## تكليف Codex المحلي — لا تبدأ من الصفر
اقرأ **الملفين المعدلين فقط** من الفرع المستقل، وقارنهما بالـworking tree المحلي؛ **لا تسحب كامل الفرع ولا تستبدل شغلك المحلي ولا تحرك HEAD تلقائيًا**. ادمج إصلاح سحب المنحة مع أحدث شغل محلي إن كان نفس الملف عُدّل. شغّل الاختبارات المركزة المذكورة وبعد نجاحها فقط وسّع تدريجيًا مع QA النسخة المقبلة. لا تُعد اختبار 9800 حالة مرة بعد مرة ولا ترفع نسخة جديدة وحدك قبل طلب المالك. لا تعدّل Supabase Production أو منح Haya.

### قبول الجهاز قبل صدور البناء
- حساب Haya المسحوبة منحتُه: يظهر Free الطبيعي أو بوابة Premium المدفوعة عند زيارة `Nutrition Programs`، لا رسالة `Subscription check unavailable` حين تكون مصادر التحقق كلها ناجحة.
- أي منحة نشطة أخرى تظل Premium؛ شراء Apple/Google مستقل يظل Premium بعد سحب الهدية.
- فشل RPC أو فشل مصدر متجر/Closed-Test يظل Unavailable/Retry، ولا يفترض Free غير مصرح لها.
- تغيّر صاحب الحساب A→B→A يمنع تسريب الاشتراكات أو reuse لنتيجة قديمة.
- **الإصلاح يتطلب نسخة Flutter جديدة**؛ لا يمكن إصلاح الباينري المثبت بإعادة نشر Supabase وحدها.

### حدود العمل
لا تحذف إدارة المنح من Flutter في هذا الفرع ولا تغيّر أي واجهات Home/Log Food أو Pricing/Trial أو Production. إزالة الإدارة المحمولة مهمة إطلاق منفصلة بعد التحقق من استضافة الويب الدائمة.
