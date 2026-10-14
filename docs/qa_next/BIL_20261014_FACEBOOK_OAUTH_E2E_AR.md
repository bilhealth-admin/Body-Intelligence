# إثبات رحلة Facebook OAuth من التطبيق إلى جلسة Supabase

- التاريخ: 2026-10-14
- الفرع: `integration/bil-qa-media-policy-20261011`
- HEAD الأساس: `e27a58984bff50b4bcf45044ea9893f344307e85`
- الحالة: شجرة العمل معدّلة؛ هذا الإثبات يخص ملفات الرحلة المبينة أدناه.

## النتيجة

نجحت رحلة OAuth على إعداد Android وإعداد iOS في اختبار Flutter تكاملي، من استدعاء `SupabaseAuthService.signInWithOAuth(Facebook)` حتى استقبال callback الموثوق، تبادل رمز PKCE عبر GoTrue، وظهور مستخدم في `currentSession`. استخدم الاختبار نقل HTTP محليًا وبيانات مستخدم ورمزًا اصطناعيين؛ لم يتصل بمزوّد Facebook أو مشروع Supabase حي، ولم يستخدم حسابًا أو رصيدًا حقيقيًا.

الاختبار يتحقق من رابط التفويض الخارجي ووجهته، `code_challenge_method=s256`، تطابق `code_challenge` مع `code_verifier` المرسل، callback إلى `https://www.bilhealth.com/auth/callback`، طلب `/auth/v1/token?grant_type=pkce` واحد، حذف verifier بعد نجاح التبادل، إنشاء جلسة بالهوية المتوقعة، وعدم تكرار التبادل عند إعادة تسليم callback نفسه.

## أوامر ونتائج الاختبار

اختبار الرحلة الكامل، نتيجته 2 ناجحان:

```powershell
flutter test --no-pub --concurrency 1 --reporter expanded --timeout 60s test/features/auth/facebook_oauth_end_to_end_test.dart
```

مجموعة عقود OAuth والمتصفح والترجمة التي شُغلت بعد إصلاح مسار Facebook، نتيجتها 62 ناجحًا:

```powershell
flutter test --no-pub --concurrency 1 --reporter expanded --timeout 60s test/features/auth/facebook_native_auth_flow_test.dart test/features/auth/ios_native_facebook_sign_in_contract_test.dart test/features/auth/android_native_oauth_contract_test.dart test/features/auth/oauth_browser_return_test.dart test/premium_login_oauth_contract_test.dart test/platform_readiness/premium_global_native_parity_contract_test.dart test/localization/bil_25_locale_fallback_closure_test.dart test/localization/closure_interfaces_runtime_copy_test.dart
```

المجموع عبر التشغيلين: 64 حالة ناجحة. ليس هذا اختبار أجهزة فعلية أو قبول متجر. تمثل Android وiOS في اختبار الرحلة إعدادَي المنصة داخل Flutter؛ استُبدل استدعاء فتح المتصفح بقناة اختبار، بينما بقي منطق OAuth وPKCE وGoTrue ومتحكم callback الفعلي من SDK المستخدم في التطبيق.

## حدود الإثبات وما بقي

- لم يُختبر تسجيل دخول حي إلى Facebook ولا موافقة مزود خارجي ولا شبكة Supabase منشورة.
- لم يُثبت فتح رابط Universal/App Link على هاتف Android أو iPhone؛ اختبارات العقود الحالية تتحقق من إعداد المصدر، ويلزم تثبيت artifact مناسب لاختبار نظام التشغيل فعليًا.
- لا يثبت هذا الاختبار حذف Meta SDK من ملف IPA/APK مبني؛ يثبت اختبارات المصدر وإعدادات Android/iOS، لا شجرة الاعتماد داخل binary موقّع.
- لا يثبت نجاح Google أو Apple؛ مساراتهما مستقلة.

لا يتطلب هذا الاختبار نشرًا أو تغييرًا في Console. قبل وصف الرحلة بأنها مجرّبة خارجيًا، يلزم بناء artifact من المصدر نفسه، تثبيته على Android وiOS، واستخدام حساب اختبار Facebook على بيئة Supabase معزولة مأذونة.

## بصمات ملفات الإثبات

SHA-256 للملفات المحورية وقت الاختبار:

| الملف | SHA-256 |
|---|---|
| `lib/features/auth/supabase_auth_service.dart` | `84a3156d48697c9899db65f3527120d055daded80a1976f74843fa32f96ccee2` |
| `lib/features/auth/premium_login_page.dart` | `a79e2f9180efcec8494b5f3d02e1c6e905842f50caff57e82e600ee77cea6533` |
| `lib/features/auth/bil_auth_callback_controller.dart` | `1e91efbb0f7f65415fe4896fedf59524a27abbc4e3bfffaf4875cdaea8b44aa0` |
| `test/features/auth/facebook_oauth_end_to_end_test.dart` | `ef32e750895c619d3437772bae6425ec57e7d744c8254b4bfb9c57f5158b5b36` |
| `test/features/auth/facebook_native_auth_flow_test.dart` | `14d02e1febb5bafb701d564eb0a0f31969a42bd0016b0ef130690c7ad035a978` |
| `pubspec.lock` | `5bde483736a61ddf4a7b192dfe66838ed2f3c53514970e3a1f9b3f37f9b16b38` |
| `android/app/src/main/AndroidManifest.xml` | `8f90912d6d2028180a17f35ca26f137c06a66a23014a58a73336f06bac71457e` |
| `ios/Runner/Info.plist` | `2da8b0c328f9426d1c766aa3f5562e7a0d3b9cd03884e2e2b5bec7626311f81a` |
