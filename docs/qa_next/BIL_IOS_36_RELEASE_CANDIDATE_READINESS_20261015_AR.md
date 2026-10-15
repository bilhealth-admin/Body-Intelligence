# iOS 36 — Release Candidate Readiness

> تحديث الاستكمال: حالة text-7 إلى text-18 الأحدث وأسباب إخفاقات GitHub ونتائج إصلاحها موثقة في [تقرير المطابقة](BIL_TEXT7_18_RECONCILIATION_20261015_AR.md). هذه الوثيقة تحفظ الأدلة التاريخية على SHA المذكور فيها، ولا تمنح اعتماد متجر أو جهاز فعلي.


## استكمال بوابة السياسات — فوق اللقطة السابقة

المرجع الحالي هو [بوابة Apple وGoogle](BIL_20261015_APPLE_GOOGLE_POLICY_COMPLIANCE_GATE_AR.md) وملحقها التقني: إصلاحات موافقة الصوت وrecipient والـSDK وTink وOkHttp واحتفاظ أيقونة الإشعار موثقة بأدلتها. المصدر ما زال dirty فوق769169f2 حتى حفظ الإصلاحات واختبار CI النهائي؛ لا تُنسب الشاملة القديمة إليه. فحص GitHub الحي يؤكد أن38749537030 انتهى cancelled، و38748152719 و38738008732 انتهيا failure؛ ليست تشغيلات جارية ولا نجاحًا جديدًا. التوقيع والرفع وحساب المراجع الفعلي ما زالت غير مثبتة.

## لقطة المصدر769169f2 السابقة

هذه خلاصة 15 أكتوبر التي تعلو على اللقطة التاريخية أدناه:

- مصدر المنتج المحفوظ`769169f2dd00f7e3dbcbce763285d2b81c2e9d60` على الفرع المسموح. Flutter Analyze كامل **PASS، 313.0 ثانية**، والمجموعات المحلية المتأثرة 45/59/25PASS مع Golden 1× دون تحديث؛ نتيجة9,843 تبقى خاصة بمصدرهاef4b9f19.
- generic Simulator bundle أصلح خطأ TARGET_BUILD_DIR وأثبتcrypto/settings على iPhone وiPad في 38734174747. تلك الرحلة فشلت في features، فلا تُصنّف مصفوفة native كاملة ناجحة.
- إضافة secure-cache على iPhone/iPad في38738008732 انتهت failure؛ رحلةfeatures على769169f2 في38748152719 انتهت failure أيضًا، مع فصل عائق تنزيل Android عن عيب iOS. لا يُدّعى اجتيازها مسبقًا أو اختبارHealthKit حقيقي على هاتف.
- ReDoS أُصلح وثبت؛ حالة CodeQL الأحدث 25 fixed/28 open. الرقم 47 open وشرط إصلاح ReDoS أدناه محفوظان كتاريخ سابق، لا كعمل غير منجز يُعاد.
- لا IPA 36 موقّع أو TestFlight جديد، ولا جلسة حساب المراجع على Artifact نهائي، ولا تغيير App Store Connect. معالجة مشكلة الصحة في المصدر لا تغيّر تلقائيًاbinary 35 المثبّت على هاتف المالك.

## اللقطة التاريخية المحفوظة

## تحديث الأدلة — 15 أكتوبر 2026

هذه الفقرة تحفظ لقطة التوثيق السابقة؛ الحالة الأحدث أعلاه.

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

لم يُبنَ IPA موقع أو يُرفع إلى TestFlight. قراءةASC اللاحقة31GET مثبتة في إضافةالسياسات أدناه؛ لا إثبات36 منها، ولا مراجعة حساب على IPA، ولا تجربة شراء/استعادة StoreKit على تطبيق موقع. لم يُختبر iPad أو VoiceOver أو Dynamic Type أو أذونات HealthKit على جهاز، ولم تُفحص entitlements النهائية أو Privacy Manifest داخل حزمة فعلية.

كان تشغيل HealthKit السابق على `macos-15` قد توقف في تجميع `connectivity_plus` لأن Xcode SDK هناك لا يعرف `NWPath.isUltraConstrained`. شُغّل التصحيح على `macos-26` في Run 38662883181؛ اجتاز بوابة الكود/التنقل فقط، ولم يُظهر نافذة الإذن الأصلية. لذلك لم يثبت اختبار HealthKit وظيفيًا.

## شروط إعلان الجاهزية

1. مراجعة alert ReDoS العالي في CodeQL وتحديد معالجة معتمدة للحزمة upstream، ثم حفظ نتيجة HealthKit بوصفها دليل محاكي جزئيًا.
2. بعد موافقة المالك على التوقيع، إنشاء IPA 36 موقّع دون تفعيل خيار الرفع إلى TestFlight.
3. فحص bundle، التوقيع، entitlements، الخصوصية، SDKs وبيانات App Store Connect الفعلية على النسخة نفسها.
4. تثبيت IPA على iPhone وiPad، وتجربة تسجيل الدخول، الروابط والإشعارات، الخط الكبير، VoiceOver، HealthKit، StoreKit Sandbox، وإتاحة المراجع.
5. يراجع المالك نص App Privacy والبيانات الوصفية في ASC؛ لم تُغيّر أي بيانات متجر أو تُرسل مراجعة ضمن هذه المرحلة.

راجع مصفوفة الفحوص والقيود في [سجل التغطية الشامل](BIL_MAXIMUM_TEST_COVERAGE_REGISTER_20261015.md).


## تحديث بوابة السياسات — 15 أكتوبر 2026

**اعتماد ما قبل الإرسال BLOCKED.** نجاحات المصدر السابقة محفوظة، ولا تثبت حساب مراجع أو حزمة موقعة للتغييرات الجديدة. راجع [التقرير الموحد](BIL_20261015_APPLE_GOOGLE_POLICY_COMPLIANCE_GATE_AR.md) و[المطابقة الرباعية الحالية](BIL_20261015_APP_PRIVACY_FOUR_WAY_RECONCILIATION_AR.md). لم تُعد الشاملة ذات 9,843 حالة، وتُنسب الفحوص المتأثرة لبصماتها فقط.

قراءة ASC والرفض الحي وGoogle Policy Status وGmail نجحت؛ لم يعد عائق القراءة القديم قائمًا لهذه الصفحات. ما زالت Apple ترفض build35 بسبب بيانات tracking الثلاث دون ATT، وما زال Google معلقًا. App Access وData Safety وسجل Appeal السابق غير محسومة. إغلاق المتجر وSDK/runtime وحسابا المراجع وSandbox والحزم الفعلية تظل مستقلة عن اختبارات المصدر.

CodeQL48 خضع لإثبات وصول Numeric RTI من45 حالة ناجحة، بتصنيف false positive محدد؛ لم يُغلق التنبيه في GitHub. إجمالي التشغيل الموثق 28 مفتوحًا و25 أُصلحت، ولا يمثل عدد47 التاريخي الحالة الحالية. Android Lint وPlay Insights يظلان BLOCKED_VENDOR بعطل أداة موثق دون تعطيل قواعد؛ لا يُحوّل تشغيل source-regressions ذلك إلى PASS.
