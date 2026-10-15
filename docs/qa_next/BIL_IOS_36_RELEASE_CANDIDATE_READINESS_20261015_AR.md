# iOS 36 — Release Candidate Readiness

> تحديث الاستكمال: حالة text-7 إلى text-18 الأحدث وأسباب إخفاقات GitHub ونتائج إصلاحها موثقة في [تقرير المطابقة](BIL_TEXT7_18_RECONCILIATION_20261015_AR.md). هذه الوثيقة تحفظ الأدلة التاريخية على SHA المذكور فيها، ولا تمنح اعتماد متجر أو جهاز فعلي.


## تحديث الأدلة — 15 أكتوبر 2026

مصدر التوثيق الحالي يتضمن

## الحكم

**غير جاهز لـTestFlight أو App Store.** اختبارات Flutter السابقة اجتازت على مصدر التطبيق `ef4b9f19f491426ba8663ba1a9d76f9af6fe0c67`، لكن لا يوجد IPA 36 موقّع أو تثبيت على iPhone/iPad أو رفع TestFlight أو جلسة مراجعة على الحزمة نفسها. manifest ما زال `STAGING_MANIFEST_COMPLETE: NO` و`CANDIDATE_FROZEN_OR_ACCEPTED: NO`.

## ما ثبت

| البوابة | النتيجة |
|---|---|
| كود Flutter والاختبارات | 9,843 ناجحًا، 0 فشل/خطأ/تخطٍّ، و1,356 ملف اختبار؛ `flutter analyze --no-pub` بلا مشكلات. بصمة مدخلات المصدر `80087ad7b2ef76192e9f22c5be0af34edc53dfc2139eb1b63ad81eaf7416614e`. لا أعيد نسبة هذه النتيجة إلى commit البنية/التوثيق الأحدث. |
| GitHub focused QA | [Run 38653187976](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38653187976) ناجح على SHA التطبيق `ef4b9f19f491426ba8663ba1a9d76f9af6fe0c67`; ليس TestFlight أو جهازًا حقيقيًا. |
| Swift CodeQL | Run 38675377540 اكتمل في اللغات الخمس، لكن Code Scanning يعرض 47 تنبيهًا مفتوحًا على الفرع؛ بينها ReDoS عالي في worker الويب المولّد من stack_trace. راجع سجل التغطية؛ هذا ليس IPA متجرًا أو اختبار جهاز. |
| HealthKit / iOS Simulator | [Run 38662883181](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38662883181) على macOS 26 اكتمل بوضع `SIMULATOR_GATE=EVIDENCE_ONLY`; لا يثبت نافذة إذن HealthKit أو جهاز Apple فعليًا أو مصفوفة iPhone/iPad كاملة. |
| رقم الإصدار | manifest التحضيري: `1.0.0 (36)`. لا تغيير في App Store Connect أو رقم إصدار متجر حي. |
| مراجعة الخصوصية السابقة | مصدر Privacy Manifest وSDKs موثق في [تدقيق Apple](BIL_20261014_APPLE_STORE_PRIVACY_METADATA_AUDIT_AR.md). لم يتغير أي حقل App Privacy أو ASC في هذا التدقيق، ولا يوجد IPA لإعادة فحص SDKs المضمّنة. |

## ما لم يُختبر

لم يُبنَ IPA موقع أو يُرفع إلى TestFlight. لا تحقق حي من App Store Connect API، ولا مراجعة حساب على IPA، ولا تجربة شراء/استعادة StoreKit على تطبيق موقع. لم يُختبر iPad أو VoiceOver أو Dynamic Type أو أذونات HealthKit على جهاز، ولم تُفحص entitlements النهائية أو Privacy Manifest داخل حزمة فعلية.

كان تشغيل HealthKit السابق على `macos-15` قد توقف في تجميع `connectivity_plus` لأن Xcode SDK هناك لا يعرف `NWPath.isUltraConstrained`. شُغّل التصحيح على `macos-26` في Run 38662883181؛ اجتاز بوابة الكود/التنقل فقط، ولم يُظهر نافذة الإذن الأصلية. لذلك لم يثبت اختبار HealthKit وظيفيًا.

## شروط إعلان الجاهزية

1. مراجعة alert ReDoS العالي في CodeQL وتحديد معالجة معتمدة للحزمة upstream، ثم حفظ نتيجة HealthKit بوصفها دليل محاكي جزئيًا.
2. بعد موافقة المالك على التوقيع، إنشاء IPA 36 موقّع دون تفعيل خيار الرفع إلى TestFlight.
3. فحص bundle، التوقيع، entitlements، الخصوصية، SDKs وبيانات App Store Connect الفعلية على النسخة نفسها.
4. تثبيت IPA على iPhone وiPad، وتجربة تسجيل الدخول، الروابط والإشعارات، الخط الكبير، VoiceOver، HealthKit، StoreKit Sandbox، وإتاحة المراجع.
5. يراجع المالك نص App Privacy والبيانات الوصفية في ASC؛ لم تُغيّر أي بيانات متجر أو تُرسل مراجعة ضمن هذه المرحلة.

راجع مصفوفة الفحوص والقيود في [سجل التغطية الشامل](BIL_MAXIMUM_TEST_COVERAGE_REGISTER_20261015.md).
