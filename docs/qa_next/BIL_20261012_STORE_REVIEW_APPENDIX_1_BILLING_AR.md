# ملحق 1 — الحساب والفوترة والصلاحيات

تاريخ القراءة: 12 أكتوبر 2026. المراجع مستقل وقراءة فقط: لا كتابة، لا اختبار جديد، لا بناء، لا منح، لا متجر، لا متابعة للشاملة. المصدر كامل وثابت مع العمل غير الملتزم فوق 2c518ee4 ؛ بصمة v4: `d47f536bf052cd139f94aa6da0295f1a74dcd70e82ef29fd2029370773c75b36` ، 9656 ملفًا/5680 مدخل تشغيل. الإصلاحات اللاحقة لها بصمة واختبارات مستقلة؛ هذه الملاحظات لا تصف نسخ المتجر بأنها تغيرت.

المراجع: `/root/store_review_billing`. قرأ الوثائق الأربع ومسارات الاشتراك و Boost والاستعادة وحالات الوصول. النتيجة: لا دليل حساب مراجعة فعلي أو artifact مصحح، وأربع ملاحظات مصدرية محددة.

| البند | الدليل بالمصدر الثابت | إعادة الإنتاج المضبوطة / الأثر | الحكم |
|---|---|---|---|
| Android acknowledge غيرناجح دون exception | `verified_store_purchase_completion.dart:24–34` و `pending.dart:35–40` ؛ SDKAndroid0.5.2 يرجع BillingResultWrapper بينما generic3.3.0 يسقط النتيجة | اشتراك موثق ثم serviceUnavailable ؛ تمحى retry رغمعدم ack ؛ خطرردالشراءلاحقًا | P1 ، استنتاج المصدر؛ لا إخفاق هاتف مسجل |
| quota غيرقابل للقراءة يصبح deny موثقًا | `commerce_providers.dart:287,395`→`premium_route_glass_gate.dart:220,252` | HTTP200 مع{} أو string بدل total رقمي→BoostCTA بدل Unavailable ،يمحوآخرقراءةموثوقة | P2 ؛ يجبحمايةالمحتوى معتمييزالخطأعنصفرموثق |
| refundedBoost بعد restart لايتسوى | `store_backend.ts:1354` يرفض canonicalrevoked قبل ledger ؛ Boostprocessing73 يحتفظ unresolved | Boost قيدثم finish فشلو restart وردمبلغ→كل retry يرفضويحظرشراءجديد | P2 ؛لا credit لشراءمردود؛ fixturesactive+refunded لايغطي canonicalrevoked |
| PlansBoostcatalogchanged لا يجددالعرض | Plans63/341 و catalog_adapter316 ، Boostservice210 | عرضقديمثم catalog جديد→رفضصحيح،لكنالإعادةتستعملالعرضالقديم | P2 ؛سلامةالمبلغمحفوظة،تحتاج refresh قابلًا للوصول |

صحيح في القراءة: pending لا يمنح؛ verification وملكية/environment قبل delivery ؛ benefit موثققبل finish ؛اشتراك/Boost/dorAdmin مستقلون؛ A→B→A محروس؛إلغاءمنحةلايمحوالشراء؛لميعثرعلى revieweremailhardcode/bypass عام. fixtures لا تثبت StoreKit/Play أوحساب حي.

الحسابات الثلاث لكل منصة مقترحة فقط: `review-content` عادي بوصول مستقر ورصيد AI كافٍ؛ `review-purchase` منفصل باشتراك منتهٍ؛ `review-admin-isolated` دور محدود على بيانات تركيبية معزولة. لايُعطى review-content دورمالك. بيانات الدخولبالإنجليزية فيقنواتالمتجرالآمنة فقط؛لانشر password/JWT/receipt.

| سياسة رسمية | البند / النوع | الانطباق والإجراء الأدنى |
|---|---|---|
| [Google Billing](https://developer.android.com/google/play/billing/integrate) | acknowledgment ،متطلبتقني/مالي | احتفظبنفسالمنفعةالموثقةوب retry حتى ack حقيقي؛اختبر native nonOK |
| [Google reviewer access](https://support.google.com/googleplay/android-developer/answer/15748846) | وصولمستقروقابللإعادة،إلزامي | حساب فعليبلادفع/OTP/بلد/تدخلصاحب |
| [Apple complete review](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/) | الأدواروالاشتراكالمنتهي،إلزامي | حساباتمنفصلة+رحلات artifact موثقة |
| [Apple Guidelines](https://developer.apple.com/app-store/review/guidelines/) |3.1.1/3.1.2 ،إلزامي|IAP والاستعادة؛لاانتهاء credits المشتراة؛لاتعميمسياسة Google على Apple|
| [Pinned AndroidSDK](https://github.com/flutter/packages/blob/in_app_purchase_android-v0.5.2/packages/in_app_purchase/in_app_purchase_android/lib/src/in_app_purchase_android_platform.dart) | completePurchase ،عقدالتنفيذ | افحصنتيجة ack الفعلية،لا Future<void>فقط |

الحد المتبقي: إصلاحالحالاتالمثبتةواختبارها؛ artifact وتجربةالحسابالمخصصعلىجهاز؛تفعيلالعقودالمطلوبةبعدإذنمستقل. المراجع بقيقراءة فقطوأنهى عمله.
