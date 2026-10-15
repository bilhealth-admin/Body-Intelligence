# BIL — تنفيذ شهادة الفحص القصوى من text-18

## حالة التنفيذ

هذا سجل تنفيذ محدد لطلب text-18، وليس إعادة احتساب لنتائج الفروع السابقة. أُجريت التغييرات على الفرع `integration/bil-qa-media-policy-20261011` انطلاقًا من `2a9ea4e085094959ff5ae6d2d1e35890a41733e8`، وهو نفسه SHA البعيد عند بدء العمل. لا تُنسب نتائج هذا السجل إلى SHA أقدم أو إلى نسخة متجر.

**آخر تشغيل GitHub:** [Run 38697770620](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38697770620) على SHA `6149e8e92a859be28fd8449762088458142dbad1` انتهى بالفشل، وليس شهادة اعتماد. جرى استخراج أسباب الإخفاق من سجلات الـjobs، وأُصلحت في شجرة العمل التالية لإعادة الفحوص المتأثرة.

### نتيجة أول تشغيل GitHub وأسباب الفشل

| Job | النتيجة الفعلية على SHA 6149e8e | السبب والدليل |
|---|---|---|
| CodeQL Actions | PASS | اكتمل التحليل ورفع النتائج. |
| CodeQL Python | PASS | اكتمل التحليل ورفع النتائج. |
| CodeQL Java/Kotlin | Job FAIL؛ تحليل CodeQL ورفع نتائجه نجحا | محاكي API 33 أقلع، لكن السكربت أُرسل إلى `/usr/bin/sh` وفيه `set -euo pipefail`؛ رفضه `sh` بـ`Illegal option -o pipefail` قبل بدء اختبارات Flutter. |
| CodeQL JavaScript/TypeScript | Job FAIL قبل رفع CodeQL | أعاد Dart توليد `.deps` و`.map` بمسارات الحزم المحلية للـrunner؛ اختلف الملفان، بينما لم يظهر `web/drift_worker.dart.js` ضمن diff. كان الفحص يقارن الثلاثة كأنها كلها مخرجات ثابتة بين أنظمة التشغيل. |
| CodeQL Swift/iOS | Job CANCELLED عند حد 60 دقيقة | نجح بناء Swift ورفع CodeQL، وثُبّت تطبيق build 36 وشُغّل باردًا على iPhone Simulator بنظام Xcode 26.6. بدأ `flutter test` لكن بناء Xcode لاختبار التكامل لم ينته قبل إلغاء الـJob؛ لم تصل الاختبارات إلى نتيجة، ولم يبدأ iPad. حُفظ artifact رقم `11957831922` وفيه لقطة تشغيل iPhone وسجل يبيّن بداية بناء الاختبار فقط. |
| Local Supabase | Job FAIL بعد نجاح بدء Stack محلي مؤقت | `supabase db reset --local --no-seed` وصل إلى `202608140001_bil_account_deletion_idempotency.sql` ثم PostgreSQL رفض `LOCK TABLE` بـ`SQLSTATE 25P01: LOCK TABLE can only be used in transaction blocks`. لذلك تخطت بقية اختبارات migrations وAuth/RLS وStorage وRealtime وEdge Functions. |

الإصلاحات التالية أُضيفت بعد هذا التشغيل ولم تُختبر بعد على GitHub: مقارنة ملف Drift التنفيذي فقط والتحقق من وجود `.deps` و`.map`؛ تشغيل سكربت محاكي Android عبر Bash؛ رفع مهلة Swift إلى 180 دقيقة لأن التشغيل قطع بناء Xcode قبل نتيجة الاختبار؛ وإضافة معاملة صريحة حول خمسة migrations تحتوي أقفالًا أو `SET LOCAL` مع أقفال، حتى يصبح القفل ومهلته ضمن معاملة فعلية. سيُعاد تشغيل Workflow بعد تثبيت هذه التغييرات، وستظل نتيجة Run 38697770620 فشلًا تاريخيًا على SHA السابق.

## ما عُدّل

- استبدال تعبير stack-trace المتسبب في ReDoS بمنطق خطي داخل نسخة vendored موثقة، مع اختبار مدخل عدائي، وإعادة توليد `web/drift_worker.dart.js` وأصوله بواسطة Dart compiler.
- إضافة اختبار انحدار ReDoS واستخدام fork المحلي الموثق للحزمة عبر dependency override.
- تثبيت وجهة Google OAuth token على مضيف Google الرسمي، وإضافة حارسي URL دقيقين يعتمدان origin/host/scheme بدل فحوص substring، ثم استعمالهما في أدوات Apple وGoogle والروابط الموثوقة.
- قراءة ملف AAB والتحقق منه وحساب SHA-256 عبر file descriptor واحد مع التحقق من ثبات الملف؛ واستخدام `crypto.randomInt` في canary بدل اختيار عشوائي منحاز.
- فك HTML entities في نص ترجمة البحث عن الطعام مرة واحدة فقط، مع حالات اختبار تمنع الفك المتكرر.
- إغلاق `android:allowBackup` في manifest المثال الذي أشار إليه CodeQL.
- توسيع Workflow واحدة قابلة للتشغيل اليدوي لتضم CodeQL للغات المستهدفة، وبناءي debug offline لرقمي Android 33 وiOS 36، ورحلات محاكي Android، ورحلات iPhone/iPad simulator، واختبارات الشراء المعزولة، ودورة Supabase محلية معزولة تشمل migrations وSQL وAuth/RLS وStorage وRealtime وEdge Functions.
- إصلاح عقدة اختبار رفض الإيصال لتنتظر حالة التحقق النهائية بمهلة محدودة بدل عدد ثابت من دورات microtask. أُضيفت بوابة `BIL_PAYMENTS_ENABLED=true` إلى خطوة اختبار الدفع في GitHub لأن اختبارات واجهة الشراء تتطلبها، مع استمرار استخدام Native SDK fakes فقط.

لم تُعدّل هذه المرحلة الأسعار أو Trial أو إعدادات متجر حي أو بيانات Supabase Production أو `main`. لا تتضمن الاختبارات شراءً حقيقيًا أو رفعًا للمتاجر.

## نتائج تحقق المصدر المحلي

| الفحص | النتيجة | الحد الذي تثبته |
|---|---:|---|
| Flutter analyze الكامل بعد آخر تعديل Dart | PASS، `No issues found!` (34.5 ثانية) | تحليل المصدر الحالي؛ ليس build أو اختبار جهاز. |
| اختبارات الشراء/الاستعادة/إنهاء المتجر والـBoost وتأكيد الاشتراك | PASS، 97 حالة | Flutter tests مع Native SDK fakes وfixture config؛ لا StoreKit/Play حقيقي. |
| food-search Deno المركّز | PASS، 10 حالات | بوابة البحث وفك entities؛ لا اتصال USDA حقيقي. |
| PostgreSQL المعزول عبر PGlite | PASS، 74 assertion (21+10+3+14+26) | عقود SQL/migration محلية داخل PGlite؛ ليست قاعدة Supabase منشورة. |
| Node security/URL/OAuth/release contract | PASS، 29 حالة | اختبارات محلية بلا تغييرات متجر. |
| iOS Plus8 canary runtime | PASS، كل الحالات المعلنة في المخرج | runtime محلي؛ لا اعتماد مسؤول أو عملية متجر. |
| Deno fmt/lint لملفات food-search المتغيرة | PASS | تنسيق وفحص الملفات المحددة. |
| JavaScript syntax للملفات المتغيرة وملفي Supabase E2E | PASS | فحص parsing فقط للملفين E2E؛ تشغيل الخادم المحلي ينتظر GitHub runner. |
| actionlint لجميع ملفات Workflow | PASS، exit 0 | صحة تعريف Workflows، لا تنفيذ jobs. |
| Dart format check لثلاثة ملفات integration/driver | PASS، 0 تغييرات | تنسيق الملفات المحددة. |
| `git diff --check` | PASS | لا whitespace errors في diff الحالي. |
| npm audit لـ `supabase/tests` | PASS، 0 vulnerabilities | اعتماديات هذا مجلد الاختبارات فقط. |

أظهرت المحاولة الأولى لمجموعة الشراء أربع حالات فاشلة. ثلاث حالات كانت نتيجة غياب تعريف الاختبار الذي يفتح بوابة commerce، والحالة الرابعة كشفت أن انتظار microtasks الثابت قد يسبق اكتمال سلسلة Future. عُدّل إعداد workflow واختبار الانتظار، ثم نجحت المجموعة كاملة مرتين بصيغتها المركبة: 97/97. لم يُخفَ أي فشل أو يُحذف اختبار.

## CodeQL والأسرار

قبل دفع التغيير، واجهة Code Scanning على SHA البعيد `2a9ea4e` أظهرت 47 تنبيهًا مفتوحًا: 1 error و45 warning و1 note. توزيعها: 4 `actions/untrusted-checkout`، و1 `java/android/backup-enabled`، و1 `js/biased-cryptographic-random`، و1 `js/double-escaping`، و19 `js/file-access-to-http`، و1 `js/file-system-race`، و15 `js/http-to-file-access`، و1 `js/incomplete-hostname-regexp`، و2 `js/incomplete-url-substring-sanitization`، و1 `js/redos`، و1 `js/remote-property-injection`.

هذه أعداد التنبيهات على المصدر البعيد السابق. لم أُغلقها يدويًا ولم أعتبر تعديل الملفات إغلاقًا مثبتًا؛ الحكم الجديد ينتظر CodeQL على الالتزام الذي يتضمن الإصلاحات. من المتوقع أن تبقى تنبيهات checkout أو runtime metadata التي لا يثبت فحص المصدر الجديد أنها قابلة للمعالجة مفتوحة للمراجعة، ولا يجوز إخفاؤها.

هناك أيضًا تنبيه Secret Scanning منفصل لمفتاح Google API في `android/app/google-services.json`، بصلاحية لم تُحسم. لم يُطبع المفتاح أو يُدوّر أو تتغير إعدادات Google Cloud؛ هذا يحتاج مراجعة مالك Google Cloud. لا يوجد دليل في هذا السجل على صحة المفتاح أو استغلاله.

## ما سيشغله GitHub Actions

بعد دفع الالتزام إلى الفرع المسموح فقط، سيُشغّل `bil_codeql_security_extended.yml` يدويًا. النطاق المعرّف في الملف يشمل:

- CodeQL للغات وإعدادات build المعلنة في matrix، مع إعادة توليد Drift worker والتحقق من تطابق الأصول المولدة.
- Android API 33 emulator offline، وiOS iPhone/iPad simulators للرحلات المحددة؛ build debug بلا signing أو إرسال إلى متجر.
- اختبارات الشراء المركّزة أعلاه مع fake native SDK.
- Supabase CLI على stack محلي مؤقت، تطبيق migrations محلية واختبارات SQL، ثم Auth/RLS وStorage وRealtime وPGlite وDeno. الحسابات والبيانات تركيبية، والاتصال محصور بـloopback.
- حفظ logs ولقطات simulator كـworkflow artifacts مع SHA المصدر.

روابط الوثائق الرسمية المستخدمة للتحقق من حدود التنفيذ المحلي:

- Supabase CLI/local development: https://supabase.com/docs/guides/local-development/cli/getting-started
- Supabase Realtime protocol: https://supabase.com/docs/guides/realtime/protocol
- Supabase Storage access control: https://supabase.com/docs/guides/storage/security/access-control
- GitHub workflow dispatch: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows

لم تُنفذ بعد دورة محليّة على Supabase/PostgreSQL daemon من هذا الجهاز؛ اختبار هذه الدورة موجود كخطوة صريحة في Workflow ويُسجل هنا فقط بعد نجاح الـrunner. ولم يُجر اختبار هاتف فعلي أو iOS TestFlight أو Play Store/Apple Store.

## النتائج السابقة التي لا تخص هذا SHA

النتيجة التاريخية `9,843/9,843` ونتيجة Flutter analyze القديمة تخص SHA التطبيق `ef4b9f19f491426ba8663ba1a9d76f9af6fe0c67` وبصمة مدخلات الاختبار `80087ad7...` الواردة في تقارير أكتوبر السابقة. لا أعيد نسبتها لهذا المصدر، ولا أعيد تشغيل المجموعة القديمة وفق حد text-18.

تشغيل Android السابق الذي عرض Welcome على API 26/29/33/34/35/36 يثبت رحلة الإقلاع فقط على SHA سابق؛ لا يثبت رحلات Android 33 أو iOS 36 الجديدة، التي تنتظر Workflow الحالية.

## سجل التشغيل النهائي

سيُستكمل هذا القسم بعد إعادة التشغيل على SHA الإصلاح. لا يُنسب تشغيل Run 38697770620 إلى SHA الإصلاح:

- Commit/source SHA وtree SHA:
- GitHub Actions run ID والرابط:
- نتيجة CodeQL واللغات وعدد التنبيهات بعد المسح:
- Android 33 emulator:
- iOS iPhone/iPad simulators:
- Local Supabase migrations/SQL/Auth/RLS/Storage/Realtime/Functions:
- failures ومحاولات الإصلاح، إن وجدت:
- حدود الأدلة: لا signed release، ولا متجر فعلي، ولا Production، ولا جهاز فعلي:
