# مطابقة تكليفات text-7 إلى text-18 مع المصدر والأدلة — 15 أكتوبر 2026

هذا هو مدخل الاستكمال الحالي. قُرئت الملفات الاثنا عشر كاملة، من `text-7.txt` إلى `text-18.txt`، بما فيها 7 و8 لإزالة التباس نقطة البداية. تعليمات المرفقات تُراجع في ضوء أوامر المالك اللاحقة؛ لا تُنفذ أوامر نشر أو شراء أو تهيئة حساب حي بمجرد ورودها في مستند تاريخي.

## نقطة الاستمرار

- Repository: `bilhealth-admin/Body-Intelligence`.
- الفرع الوحيد: `integration/bil-qa-media-policy-20261011`.
- Worktree: `G:/BIL_Project/worktrees/bil-ios36-audit-snapshot-20261014`.
- HEAD عند بدء المطابقة: `7a797819d882674b6b7ed83a546c23ff3922c312`؛ البعيد `53ff3c8c867f1c862eab4aceafc1318c10bb4616`.
- المجلد الأساسي على فرع آخر وبداخله عمل غير ملتزم؛ لا تعديل فيه. صور إخفاقات Golden الموجودة في worktree محفوظة خارج commits.
- لا تُعاد الشاملة السابقة 9,843/9,843. نفذت على dirty HEAD `e27a58984bff50b4bcf45044ea9893f344307e85` ثم حُفظ مصدرها المطابق في `ef4b9f19f491426ba8663ba1a9d76f9af6fe0c67`؛ بصمتها `80087ad7b2ef76192e9f22c5be0af34edc53dfc2139eb1b63ad81eaf7416614e`. تغيرت لاحقًا تبعية `stack_trace` واختبارات/عقود محددة؛ تُفحص آثارها بصورة مركزة وتبقى الشاملة منسوبة إلى مصدرها.
- تشغيل GitHub `38713591000` على `1478f4ed` كان جاريًا عند القراءة؛ Swift CodeQL انتهى، ورحلات iPhone/iPad كانت جارية. لا يُلغى أو يُكرر.

## مصفوفة المطابقة

| ID | التكليف ومصدره | ما تحقق من الموجود | العمل المتبقي أو حدود الإثبات |
|---|---|---|---|
| R01 | حماية المصدر والأعمال والاختبارات — 7،8،14،16–18 | worktree/branch/HEAD والبعيد والتعديلات الأصلية جُردت | حفظ كل دليل جديد مع SHA؛ لا reset/clean/force/main |
| R02 | إغلاق إخفاقات الشاملة والتحليل وGolden — 7،12،14،17 | سجل الإخفاقات التاريخية ونتيجة 9,843 النهائية موجودان؛ لا يُعاد تشغيلهما بلا أثر جديد | تحقق من السجل الأصلي وبصمة الملفات التي تغيرت بعده؛ focused فقط عند الحاجة |
| R03 | HealthKit/Health Connect والعزل A→B→A — 7–10،14،16–18 | إغلاق المصدر موثق مع 157/157 للصحة/الصلاحيات؛ لم يتغير `lib` بعد SHA الشاملة | لا تعاد المجموعة المنجزة؛ HealthKit/Health Connect الفعليان وتدفقات النظام على جهاز تبقيان بوابة جهاز |
| R04 | الصوت والنص وMeal Vision ومزود AI والموافقة — 7–10،14،16–18 | 81/81 للسياق والموافقة و132/132 لـVision/الصوت/الوحدات محفوظة؛ رفض الصوت الخام قبل الموافقة/حجز الاستخدام | لا إعادة لتلك الاختبارات؛ هذه ليست أسئلة/صور حية إلى مزود AI أو اختبار هاتف |
| R05 | Meta/Facebook OAuth وAdMob وTracking/ATT — 7–10،14،16–18 | تقارير SDK/OAuth وقرار عدم الاستنتاج من manifest وحده موجودة | فحص مصدر الحالي؛ IPA/merged manifests وشبكة SDK الفعلية بوابات artifact/device |
| R06 | بلاغ AI والأسباب الأربعة والبطاقة والخصوصية و`privacy` القديم — 10–18 | Flutter UI/service/admin وmigration وSQL وAPI بلاغ AI بجلسة موقعة فعلية نجحت على Supabase معزولة؛ run38734170433 | سلوك Production وartifact المراجع غير مثبتين؛ ليس نقصًا في اختبار SQL المحلي |
| R07 | AI Reports / Community Reports / Reviews / Grants والأدوار — 11–18 | التبويبات مستقلة؛ فصل المراجعين عن مالك الإدارة محفوظ في المصدر الأحدث | التحقق من SQL/RLS والإدارة وإلغاء السلطة؛ الحسابات الحقيقية على artifact لم تثبت |
| R08 | الاستعادة الفعلية والتوافق 32/35 وCAS/tombstones — 7،14،16–18 | SQLite A→Supabase GoTrue/PostgREST/PostgreSQL→B وrenderer مستقلة PASS؛ 19 مغذيًا وnull/zero وCAS/tombstones وToday/goals/analytics/Coach reader | توافق32/35 على مستوى المصدر/SQL محفوظ؛ لم يثبت binary قديم على جهاز مع خادم منشور |
| R09 | الشراء والاستعادة وBoost والفشل والتكرار والوصول — 7،9–10،14،16–18 | 97 اختبار شراء مركزًا و74 فحص PostgreSQL سابقًا، وحالات pending/refund/ownership موثقة | StoreKit/Play رسمي وحسابا المراجع على الحزمة بوابات متجر/جهاز |
| R10 | EULA/Privacy/manage links ومصفوفة Apple/Google — 7،9–10،14 | تقارير قانونية وسياسات ورفضات تاريخية موجودة | تحقق الروابط ونطاق الإصلاح؛ لا تغيير Console/ASC ولا Appeal في هذا الاستكمال |
| R11 | جرد كل Workflows وأمان تشغيلها وNode/runner — 16–18 | 60 workflow جردت وactionlint PASS؛ إصلاحات SQL/KVM/native-only ومشغلات معزولة ذات نطاق معلن | لا تشغيل signing/deployment أو workflows تغير المتاجر؛ GitHub checkouts لا تعني اعتماد إصدار |
| R12 | 47 CodeQL وReDoS وعدم تعديل المولد يدويًا — 17–18 | 25 fixed/28 open في run38734392616؛ ReDoS fixed؛ ID52/53 خاصة بالجلسة التركيبية Exclusive0600؛ triage لكل ID | high48 generated RTI reachability لم يحسم؛ لا dismiss أو تغيير مولد يدويًا |
| R13 | أسرار وتبعيات وSBOM وأمن API والتشفير — 16–18 | OSV/Grype/Trivy/Syft/Gitleaks السابقة محفوظة؛ MobSF فعلي offline APK33 اكتمل مع ملاحظات؛ AES native API36 PASS | المفتاح العام وrelease binary/final SDK/network يحتاجان دليلًا منفصلًا؛ لا ادعاء خلو كامل |
| R14 | Android APIs وميزات حقيقية وLifecycle/16KB — 9–10،14،16–18 | 6/6 إقلاع سابق محفوظ؛ native crypto على API36/WHPX PASS؛ KVM/airplane setup صُححت مع أسبابها | وظيفة API33 native على19972310 جارية؛ لا Android هاتف أو AAB موقع |
| R15 | iPhone/iPad كامل وSDK/permissions — 7،14،16–18 | debug36/Swift CodeQL نجحا على1478؛ فشل تحميل crypto بسبب TARGET_BUILD_DIR، لا اختبار assertion | مسار native-only generic bundles على iPhone/iPad جارٍ؛ لا إلغاء التشغيل القديم أو ادعاء نجاح مسبق |
| R16 | تفاعل التطبيق والوسائط والتنقل والتوطين وإمكانية الوصول — 7،14،16–18 | اختبارات Flutter وGolden والصور السابقة محفوظة | native journeys لا تساوي رحلة دخول حقيقية؛ مراجعة gaps من الاختبارات الموجودة |
| R17 | أداء/fault/fuzz/mutation/coverage — 16–18 | 10,000 generated cases و380,014 تحققًا و5/5 behavioral mutants محليًا؛ تغطية VM محصورة للملف؛ benchmark السابق محفوظ | تشغيل القياس الجديد في GitHub قادم؛ لا coverage/mutation شاملة ولا قياس أداء هاتف/Production |
| R18 | Android33/iOS36 والحزم والتوقيع والنشر — 7،9،14،16–18 | أرقام المرشحين ومسار fail-closed موجودة؛ لا حزمة توزيع موقعة جديدة | حزم موقعة وأجهزة ومتاجر ونشر Production بوابات مستقلة؛ لا تتحول إلى PASS |

الفهرس التفصيلي لأنواع الفحوص هو `BIL_MAXIMUM_TEST_COVERAGE_REGISTER_20261015.md`؛ التقارير السابقة تبقى أدلة تاريخية ولا تُنسخ نتائجها إلى SHA أحدث.

## أسباب GitHub التي أُعيد التحقق منها

1. Run `38716505124` / SHA `53ff3c8c`: ملف الرسائل المحجوبة أدخل `id` رغم column-level INSERT؛ إصلاح fixture في `f3ab218b` وأُدرج في الدفع الجديد `d362c8e4`، ولا تغيير Production.
2. التشغيل نفسه: غياب بلاغ AI كان خطأ fixture مثبتًا محليًا. `queue_ids` احتوت ID الحقيقي، لكن صف الحالة الأول ظل `initial_queue=NULL` لأن `INSERT` أنشأ صفًا ثانيًا. استُبدلت الإضافات بتحديث الصف الوحيد مع قيد singleton. نجح SQL نفسه كاملًا بعدها دون تغيير migration المنتج أو تخفيف assertions.
3. التشغيل نفسه: كل ملفات SQL العشرة أظهرت `No plan found in TAP output`؛ هي assertions SQL عادية بينما workflow استعمل pg_prove/pgTAP. تضييق glob في f3ab وحده لا يصلح عدم توافق المشغل.
4. Run `38713591000`: وظيفة Android اجتازت البناء وCodeQL واختبارات الشراء الـ97، ثم توقفت قبل native integration: `Permission Denial` عند إرسال `AIRPLANE_MODE` من shell. عولجت التهيئة بـ`cmd connectivity airplane-mode enable` والتحقق من حالته. هذا خطأ مشغّل، ولا يثبت فشل رحلة التطبيق أو نجاحها. كان النوع نفسه ظاهرًا في سجل إقلاع سابق؛ البحث في السجل جزء من منع تكراره.
5. إخفاقات الترحيل/تهيئة هوية المشرف السابقة لا يعاد تخمينها؛ تربط بإصلاحاتها الحالية ثم تختبر على بيئة معزولة.
6. محاولات push السابقة توقفت بسبب fork داخل استدعاء `git rev-parse` في hook محلي. حُفظت نسخة hook ثم عولج استخراج مساره بتوسيع shell يدعم `/` و`\` دون إنشاء process إضافي؛ ملف PowerShell وفحص Git LFS بقيا كما هما. تشغيل hook بمدخل فارغ نجح (exit 0). لا `--no-verify` أو تغيير `core.hooksPath` أو force.

## الإثبات المحلي الجديد ونطاقه

| الفحص | النتيجة والمصدر |
|---|---|
| SQL قبل الإصلاح | FAIL متوقع مع إعادة إنتاج العيب؛ PostgreSQL 17.6، loopback، مستخدمون تركيبيون؛ `ai-sql-before-v2.json` |
| SQL بعد الإصلاح | PASS؛ 10:43:24–10:43:39 UTC؛ إرسال/تكرار/رفض غير المشرف/طابور/قرار/مسح نص وملاحظة/rollback؛ `ai-sql-after.json` |
| سلامة الاختبار | نفس migration SHA-256 قبل/بعد `aaad8ac351dd43983cffb7b4ad63491715c55aa3d59b490f1c32b0f30a13540f`؛ بيانات fixture أُعيدت فارغة والـcluster أُوقف |
| إدارة المشرفين | `flutter test --no-pub --reporter expanded test/features/admin/community_moderator_admin_contract_test.dart`: 3/3، دون تجاوز صلاحيات Free أو ترقية حساب مراجعة إلى Admin |
| Workflows | actionlint 1.7.12: 60/60، exit 0 بعد تعديل مشغّل SQL وإضافة ملف API |
| Shell/Python/Node | `bash -n` لمشغّل Android، `py_compile` لمشغّل PostgreSQL، `node --check` لملف API الجديد، و`git diff --check`: exit 0 |
| تنقيح أدلة الأمن | 3/3 unittest: لا نص مطابق أو secret أو error message خام في التقرير العام؛ المخرجات الفارغة لا تتحول إلى CLEAN_SCAN |
| Flutter Analyze كامل | PASS، `No issues found!`، 1014.9 ثانية على HEAD `7a797819`؛ لا اختلاف Dart/dependencies/analysis_options عن HEAD أثناءه؛ `flutter-analyze.json` |
| أسرار staged diff | PASS بعد مراجعة بصمتي المصدر المذكورتين أدناه، 0 leaks؛ لا allowlist جديدة |

أدلة JSON المنقحة محفوظة في `evidence/text7-18-reconciliation-20261015/`. لا مفاتيح أو JWT أو كلمات مرور فيها. timestamps هي UTC. اختبار PostgreSQL هنا لا يشغل GoTrue/PostgREST؛ لا يسمى دورة Supabase كاملة.

خريطة الأثر من SHA الشاملة إلى HEAD البداية حصرت تغير مدخلات Flutter في ستة ملفات: `native_feature_splashes_test.dart`، و`pubspec.yaml`/`pubspec.lock` لتثبيت stack_trace المصحح، واختبار إدارة المشرفين، وانتظار اختبار queue، واختبار ReDoS الجديد. لا اختلاف `lib`/`ios`/`android` في هذه المقارنة. اختبار انتظار الشراء وReDoS لهما أدلة مركزة في تقرير text-18؛ إدارة المشرفين تحققت هنا 3/3؛ native splashes ضمن وظيفة iOS الجارية وإعادة Android المتأثرة. لا يكفي هذا لإعادة تسمية الـ9,843 كمجموعة شُغلت على SHA جديد.

ملف `local_supabase_product_rpc_e2e_test.mjs` يغلق نقصًا في تصميم الاختبار السابق، الذي أثبت RLS على جدول fixture عام فقط. الملف الجديد يستعمل جلسات Auth موقعة فعلًا مع RPC المنتج لبلاغ AI (الموافقة، الطابور، القرار، التكرار، سحب الدور)، ولـRestore V2 (AES-GCM حقيقي، جهازان، null مقابل صفر، CAS متزامن، صفحات، tombstone، عزل حساب وسحب موافقة/جهاز). SQL فيه لتهيئة هوية moderator تركيبية والتنظيف فقط. لا يدعي استعادة SQLite أو مرور Flutter UI؛ دليله مكمل لدورة A→PostgreSQL→B السابقة. غياب Docker المحلي يمنع تشغيل واجهات Supabase على Windows الحالي؛ لذلك يبقى هذا الجزء NOT RUN حتى نتيجة الخادم المعزول في GitHub.

## نتيجة مراجعة CodeQL الحالية

حُفظت جميع حالات الـ51 instance في `evidence/text7-18-reconciliation-20261015/codeql-triage.json` مع مسار/سطر/ID/SHA. الاستعلام الذي لا يحدد ref قد يرجع صفرًا من الفرع الافتراضي؛ لم يستخدم للحكم على التكامل.

- 25 instance حالتها `fixed` على تحليل `699abff3`، بما فيها ReDoS؛ لا تنسب «47 مفتوحة» القديمة إلى المصدر الحالي.
- IDs 32–46 باستثناء ما ليس موجودًا: 15 تحذير `http-to-file-access` في حفظ تقارير JSON أو صور مأذونة بوجهة محلية. عُرضت مواضع الكتابة ولم يظهر تنفيذ للمحتوى المنزّل. هذه مراجعة قصد ومسار وليست ضمانًا لكل إدخال ممكن.
- IDs 28،30،31،49،50،51: 6 `file-access-to-http` لاستدعاءات API ذات origin مثبت أو رفع assets إلى وجهة Apple المسموح بها، مع منع redirect. لا شُغلت أدوات تغيير المتاجر أو canary الحي أثناء هذا التدقيق.
- IDs 1–4: checkout لـSHA ينتجه job integration موثوق بنفس workflow، `persist-credentials:false`؛ workflow مقيد بفرع QA تاريخي ثابت. تغيير checkout إلى `github.sha` سيختبر مصدرًا آخر، فلم ينفذ لتجميل عدد التنبيهات.
- ID 48 high: source map يقود من `self.location.href` عبر معالجة Uri إلى `_instanceType`/`_Universe.findErasedType` في Dart SDK `rti.dart`. مفتاح الكتابة عند النهاية هو `constructor.name`، وليس نص URL مباشرة؛ مسار التلوث يحتاج تحقق قابلية الوصول قبل وصفه بثغرة مؤكدة أو false positive. لم يثبت استغلال، ولم يُغلق التنبيه أو يُعدل JavaScript المولد يدويًا. metadata في runtime كائن عادي، فلا يصح الادعاء أنه null-prototype.

أُبقيت التنبيهات الـ26 مفتوحة لدى GitHub؛ نجاح عملية التحليل لا يعني مسحًا خاليًا من التنبيهات. تبقى مراجعة مفتاح Google API المنفصلة من صلاحيات مالك Google Cloud، دون طباعة المفتاح أو اختباره على خدمة مدفوعة.

مصادر منهج الإصلاح: [Supabase test db يستعمل pgTAP](https://supabase.com/docs/reference/cli/supabase-test-db)، [أمر ConnectivityService الرسمي](https://android.googlesource.com/platform/packages/modules/Connectivity/+/refs/heads/main/service/src/com/android/server/ConnectivityService.java)، [CodeQL network data written to file](https://codeql.github.com/codeql-query-help/javascript/js-http-to-file-access/)، [CodeQL file data in outbound request](https://codeql.github.com/codeql-query-help/javascript/js-file-access-to-http/)، [CodeQL remote property injection](https://codeql.github.com/codeql-query-help/javascript/js-remote-property-injection/). تاريخ القراءة 15 أكتوبر 2026.

## Semgrep وفحص الأسرار — عدم تكرار التشخيص القديم

نسخة Semgrep 1.181.0 ومحركها يعملان في أمر version على Windows بعد تحميل ملفات `.pth` لتثبيت `--target` المعزول؛ ذلك لا يثبت نجاح scan. محاولة الفحص أُوقفت قبل إنتاج JSON صالح. تشخيص قاعدة واحدة ببيانات تركيبية فقط أثبت `Unix_error: Invalid argument socketpair` من المحرك، وتكرر مع `--jobs 1`. ليس هناك دليل OOM أو عيب قاعدة في BIL، ولا يصح الاكتفاء برسالة عامة عن Python 3.14.

أضيف مسار يدوي `source_audit_only` إلى workflow القائمة، لا workflow نشر جديدة. ينفذ Semgrep CE المجاني المثبت بإصدار محدد على Linux مع `p/security-audit` و`p/secrets`، دون حساب خدمة أو رفع source أو telemetry. هذه خصائص [الفحص المحلي الرسمي](https://github.com/semgrep/semgrep/blob/develop/README.md). JSON الخام والـlog الخام يبقيان في runner المؤقت؛ الأدلة العامة تشمل ID/مسار/سطر/شدة/count فقط. نجاح تشغيل المحرك منفصل عن وجود findings أو أخطاء جزئية. لا يُحتسب هذا المسار منفذًا حتى تسجيل نتيجته.

المسار نفسه يعيد CodeQL لـActions/JavaScript/Python فقط لأن ملفات مشغلات من هذه اللغات تغيرت؛ لا builds أصلية أو إعادة Swift. وظيفة Android تحفظ APK الـdebug المعزول وبصمته للفحص الساكن، دون اعتباره AAB توزيع أو شهادة 16KB نهائية.

Gitleaks للـstaged diff التقط اثنتين من بصمات ملفات migration كـ`generic-api-key` لأن اسم الملف في مفتاح JSON احتوى `access` متبوعًا بـSHA-256. قورنت القيم ببصمات ملفات المصدر وثبت أنها hashes، دون أي credential. حُفظت كل البصمات مع فصل حقل `path` عن `sha256` في الدليل المنشور، بلا allowlist أو إسكات قاعدة؛ يلزم نجاح إعادة الفحص قبل commit.

## ترتيب الاستكمال الحالي

1. حفظ سجلات GitHub الأصلية وبصمات المرفقات ومراجعة باقي الأدلة الموجودة.
2. إعادة إنتاج SQL AI الأصلي محليًا، إصلاح السبب المثبت، والتحقق من أسلوب تشغيل SQL الصحيح دون حذف assertion.
3. استخراج فشل Android وانتظار iOS الجاري، ثم معالجة كل فشل مثبت في الجزء المتأثر فقط.
4. مراجعة التنبيهات والفحوص المستقلة غير المغطاة وتحديث سجل التغطية بما ثبت، لا بما خُطط له.
5. تنسيق/تحليل واختبارات متأثرة عند تغير المصدر، ثم رفع آمن وتشغيل GitHub المتأثر بعد اكتمال التحقق المحلي الممكن.
6. تحديث هذا التقرير والفهرس وجاهزية المنصتين بنتيجة صريحة وحدودها، ثم التسليم.

## المصدر المحفوظ وتشغيل الأجزاء المتأثرة

اجتازت التعديلات فحوصها المحلية ثم حُفظت في `d362c8e4c771b474595a1b3059b562519b46b758` ودُفعت fast-forward إلى الفرع المسموح. لا تعديل لكوميت منشور أو main. فشل MSYS في `post-commit` بعد إنشاء الكوميت؛ نُفذ `git-lfs post-commit` نفسه بنجاح ثم حُوّل hook إلى `exec git-lfs` لتفادي fork الزائد. فحص LFS عند push عمل ولم يتجاوز. التوقيع التشفيري GPG غير موجود؛ SHA وبصمات المدخلات لا تدعي أنها توقيع شهادة.

| النطاق | Run / المصدر | الحالة عند بدء المتابعة |
|---|---|---|
| migrations/SQL/Auth/RLS/RPC/Storage/Realtime/Edge المعزولة | [38726355481](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38726355481) — `d362c8e4` | جارٍ؛ لا نتيجة نجاح بعد |
| Android API33 وCodeQL Java/Kotlin | [38726365073](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38726365073) — `d362c8e4` | جارٍ؛ لا نتيجة نجاح بعد |
| Semgrep وCodeQL Actions/JS/Python | [38726373457](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38726373457) — `d362c8e4` | جارٍ؛ لا نتيجة نجاح بعد |
| iPhone/iPad السابق | [38713591000](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38713591000) — `1478f4ed` | تُترك وظيفة iOS لتكمل؛ لا إعادة أو إلغاء لها |

كل dispatch يختار الوظائف المعلنة في نطاقه فقط؛ `skipped` لوظيفة خارج هذا النطاق لا يعني تخطي test أو assertion بداخلها. لم تُشغّل الشاملة أو أي build توزيع موقع أو Production.

### نتيجة Supabase الأولى على d362c8e4 ومنع تكرار سببها

اجتازت جميع migrations والتحقق من فصل الأدوار وملفات SQL التسعة بنجاح في `38726355481`. انتهت بذلك أسباب F01/F02/F03 على خادم Supabase/PostgreSQL المعزول نفسه. توقفت اختبارات API الأربع عند اختيار الحاوية، قبل signup أو RPC: الاسم الحقيقي `supabase_db_Body-Intelligence` استبعده regex الذي يقبل lowercase فقط. هذه أربعة parent tests فشلت في التهيئة لسبب واحد، وليست أربعة أعطال بوظائف المنتج.

وُحد اختيار الحاوية في helper يتحقق من الاسم الصريح `BIL_LOCAL_DB_CONTAINER` الموجود فعلًا، ويقبل أحرف Docker الصحيحة، ويرفض الحاوية غير الموجودة أو الغامضة بدل اختيار أول قاعدة. اختبارات Node المحلية 5/5 تشمل الاسم الحقيقي كما ورد في log، والـlowercase، والتعدد، والفقد، والاسم غير الآمن. لا تغيير SQL أو صلاحيات المستخدم لتجاوز العيب. تُعاد وظيفة Supabase وحدها بعد نجاح هذه الحالات وSyntax وactionlint؛ إنشاء stack جديد يتطلب إعادة migrations والتحقق نفسه لأن الحالة المؤقتة لا تعاد من تشغيل سابق.

### نتيجة الفحص الساكن الأولى على d362c8e4

تشغيل Semgrep نجح تقنيًا وفحص 5,130 مسارًا، لكن نتيجته **PARTIAL**: 13 finding واثنان Timeout؛ لا يسمى clean. 10 findings عند imports XML في أدوات Python لفحص manifests/config/UIA محلية، واثنان audit على urllib في أداة ترجمة كتالوج موثوق وفي shutdown لخادم الاختبار، وواحد يطابق `<script>` في اختبار رفض رابط المجتمع نفسه. severity في قاعدة import لا يثبت ثغرة في تطبيق Flutter. تراجع مصادر الإدخال لكل موضع وتبقى الملاحظات معلنة؛ لا أضيف استيرادًا مموهًا أو suppression لإخفائها.

حُفظ التقرير العام المنقح في `evidence/text7-18-reconciliation-20261015/semgrep-d362c8e4.json`. تحفظ النسخة التالية من sanitizer مسار timeout وrule ID أيضًا، دون نص مطابق؛ ورفعت مهلة القاعدة إلى 60 ثانية للفحص التالي دون استثناء ملف أو قاعدة. اجتازت اختبارات sanitizer الثلاثة بعد التعديل. CodeQL JS/Python نجحا في التشغيل نفسه وبقي ref-specific عدد التنبيهات 26 مفتوحة/25 fixed عند قراءة النتيجة؛ نجاح Actions يضاف بعد تأكيد ختام الوظيفة.

### إغلاق فجوة اختبار الدورة الكاملة، دون إعادة كتابة الاستعادة

اختبار `cloud_restore_postgres_cycle_test.dart` كان يستعمل SDK Supabase وSQLite حقيقيتين، لكن Auth كان اصطناعيًا أمام bridge PostgreSQL المحلي. أضيف له وضع `supabase_local` محدود: يأخذ جلسة GoTrue موقعة من signup تركيبي، يتحقق منها عبر `auth.getUser()` فعلًا، ويسجل الموافقة الأساسية ثم موافقتي nutrition/goals عبر RPC. بعد ذلك يستعمل **نفس** fixture والـtransport والـengine والقرّاء والـassertions الموجودة، لا نسخة JSON من الاختبار.

خطوة CI الجديدة تشغّل هذا الوضع على stack Supabase المحلي نفسه، مع قاعدتي A/B مستقلتين وقاعدة renderer مستقلة تُستعاد من الخادم أيضًا. التحقق يشمل 19 مغذيًا، null مقابل صفر، الحصة، المصادر، اختلاف IDs المحلية، إعادة المحاولة بعد فقد رد ملتزم، صفحات، أهداف/أقفال، CAS وحلًا صريحًا وحذفًا، ثم repositories وToday والأهداف والتحليلات وسياق أهداف المدرب. جلسة Auth وSQLite لا ترفع ضمن artifact؛ يرفع proof ولقطات Flutter فقط. مصدر صلاحية عرض قارئ Premium اصطناعي معلن داخل fixture؛ هذه ليست رحلة شراء أو محادثة AI حية.

لمنع كسر الدورة السابقة اختُبر الملف المعدل **مرة واحدة** محليًا على PostgreSQL أصلي وAES/.NET: 1/1 PASS، دون skip/failure/error، وبصمة مصدر ثابتة. ظهرت Today والأهداف والتحليلات فعليًا في Flutter؛ لا هاتف أو Supabase Auth في هذا الإثبات المحلي. ثم نجح `flutter analyze --no-pub` الكامل بعد آخر تعديل Dart، بلا ملاحظات خلال **213.2 ثانية**. دليل النتيجتين `client-cycle-local-regression.json` و`flutter-analyze-final.json`. لا إعادة للشاملة 9,843.

أُلغي شرط نافذة PowerShell المنفصلة من runner القديم طبقًا لأمر المالك؛ البروتوكول الكامل يبقى داخل المحادثة وlog. حُمي عنوان shutdown من ملف config تالف بحيث لا يرسل POST لخادم خارجي، واجتازت حالات العنوان الآمن/الخبيث/الملتبس الثلاثة محليًا. لم تتغير معادلات أو شاشات التطبيق.

## نتائج المصدر 73785549 والإصلاحات التالية

`7378554969fa5249e4aa071bea769062caa5cc1a` محفوظ ومرفوع fast-forward. ما سبق عن «جارٍ» أو «NOT RUN» يمثل وقت بدء التشغيل؛ النتائج المحددة هنا هي الأحدث:

| التشغيل | النتيجة الفعلية | سبب الإعادة المحدودة |
|---|---|---|
| Supabase `38729694517` | جميع migrations وملفات SQL التسعة PASS؛ API: **28/29 PASS** بلا skip؛ جلسات GoTrue وبلاغ AI وRestore V2 وCAS والعزل نجحت | فشل تجهيز Storage، قبل إثبات Storage/Realtime كاملين؛ لم تصل الخطوات اللاحقة إلى دورة Flutter أو NPM/Deno |
| Source audit `38729699048` | الوظائف الأربع PASS؛ Semgrep: **5,135 مسارًا، 13 finding، صفر أخطاء**؛ لا يسمى clean | انتهى timeout السابق؛ findings تبقى معلنة وفق مراجعة حدود الإدخال أعلاه |
| Android `38726365073` | debug APK33 وJava/Kotlin CodeQL و**97/97** اختبارات شراء PASS؛ native لم يبدأ | log يثبت منع الوصول إلى `/dev/kvm`، وإقلاع software استغرق 774,668ms ثم فشل unlock قبل test |
| iOS `38713591000` | debug36 وSwift CodeQL PASS، صورة launch فعلية على Simulator محفوظة | تحميل اختبار crypto فشل عند `TARGET_BUILD_DIR` بعد Xcode build؛ صفر assertions native؛ ليس timeout أو فشل تشفير مثبتًا |

الـStorage fixture كان يولد `CREATE POLICY bil-ci-…_select` دون quoting؛ أُعيد إنتاج syntax error على PostgreSQL 17.6 ثم نجح DDL بعد استعمال أسماء آمنة محدودة ومعاملة تجهيز واحدة. cleanup القديم عبر SQL فشل وغطى الخطأ الأول؛ أصبح حذف الملفات/الدلو عبر Storage API للدلو التركيبي المحدد فقط، مع إظهار سبب العملية الأصلية وأخطاء التنظيف منفصلين. 8/8 اختبارات helper/selector محلية PASS، وDDL قبل/بعد وcleanup PASS. صلاحية service role المستعملة للتنظيف تخص stack CI المحلي فقط؛ اختبارات المستخدم نفسها تستعمل JWT موقعة وanon key. لا تغيير migration أو RLS منتج.

أضيفت خطوة KVM نفسها التي نجحت في workflow الإقلاع ذي APIs الست، مع شرط read/write صريح؛ لا تمديد أعمى للمهلة. المسار `android_native_only` يشغل الملفات الأصلية الثلاثة على runner جديد، دون إعادة CodeQL أو اختبارات الشراء الناجحة.

كود Flutter المثبت 3.44.6 يبين أن طلب إعدادات Xcode الخاص بـdevice يمكن أن يعيد map فارغة، بينما generic simulator build نجح. لا يثبت السجل السبب الأعمق للطلب الفارغ لغياب verbose لذلك الاستدعاء؛ لم يُخمن عيب Xcode project. مشغّل iOS الجديد يبني **كل entrypoint اختباري حقيقي** لـgeneric simulator ثم يستعمل `--use-application-binary` لتشغيل نفس bundle على iPhone وiPad. دعم `.app` مثبت في `IOSApp.fromPrebuiltApp` بالمصدر المثبت، وdriver التشفير مأخوذ من integration_test المثبتة؛ لا تغيير Flutter SDK أو app. المسار native-only على ARM لا يكرر Swift CodeQL المنجز. Syntax وactionlint للـ60 workflow PASS؛ تنفيذ Simulator الجديد ما زال مطلوبًا.

على Windows أُنشئ AVD مستقل API36/WHPX ثم ثبت فعليًا أن broadcast القديم مرفوض من shell UID2000 وأن أمر ConnectivityService الجديد يعمل ويستعيد الحالة الأصلية؛ `android-api36-connectivity.json`. محاولة تشغيل حالة crypto اصطدمت قبل الاختبار بـJava loopback في Gradle. probe صغير أثبت أن مجلد temp قصيرًا لهذه العملية يحل selector/TCP؛ إعادة الاختبار الأصلي بهذا الإعداد نجحت **1/1**: AES-256-GCM وlegacy v1 byte layout على API36/WHPX فعلية. لا تثبت Keystore custody أو API33 أو هاتفًا أو build توزيع. حُفظ `android-api36-native-crypto.json`، واستعيد وضع الشبكة وأغلق المحاكي المملوك للاختبار. المحاولة الوسيطة أكملت APK ثم توقف عارض Python عن طباعة رمز Unicode؛ لم تنسب نتيجتها إلى PASS، وشغلت الحالة النهائية عبر shell الداخلي مباشرةً دون ذلك العارض. لم تتغير إعدادات الجهاز العامة أو SDK التطبيق. WSL يفشل بـ`HCS_E_SERVICE_NOT_AVAILABLE`؛ لا تفعيل ميزات Windows أو restart.

### فحص APK المعزول المطلوب في 16–18

أُعد MobSF المجاني v4.5.3 من الصورة الرسمية المثبتة بالبصمة `sha256:5113fbad0727445dda01afdccafea5e107bfa8632ead8a169492f5caa8aa1b7c`. المدخل هو debug APK33 المحفوظ من build الناجح أعلاه، مع التحقق من SHA-256 ومن أن الفروق اللاحقة QA فقط. الحاوية بلا شبكة أو ports أو host mounts؛ REST الداخلي loopback فقط. لا إرسال APK/source إلى SaaS ولا اختبار ديناميكي أو خدمة مدفوعة. يرفع ملخص قواعد وشدة وعداد ملفات دون قيم مطابقة أو مفاتيح أو source خام. 3/3 اختبارات تنقيح/هوية/فشل نقص أقسام PASS محليًا. **الفحص نفسه لم ينفذ بعد**؛ لا يتحول تجهيز الأداة إلى نتيجة MASVS أو release AAB.

المراجع الأولية: [MobSF v4.5.3](https://github.com/MobSF/Mobile-Security-Framework-MobSF/releases/tag/v4.5.3)، [Storage bucket API](https://github.com/supabase/storage-js/blob/master/src/StorageBucketApi.ts). قرئت 15 أكتوبر 2026.

## آخر إجراء وخطوة تالية

تُحفظ إصلاحات تجهيز Storage وKVM وتشغيل iOS وMobSF بعد فحوصها المحلية، ثم تُشغل وظائفها المعزولة المتأثرة فقط. الفشل في API لا يمنع جمع دليل دورة SQLite أو Deno المستقلة بعد نجاح migrations؛ يبقى job فاشلًا إذا فشلت أي خطوة، دون `continue-on-error` لإخفائها. لا إعادة للشاملة أو شراء أو حساب حي أو Production أو تغيير واجهات أو Golden.

### حدود فحص OWASP المطلوب، والإغلاق التنفيذي لكل نقص

طوبق نطاق الإثبات مع عائلات [OWASP MASVS الرسمية](https://mas.owasp.org/MASVS/) بتاريخ 15 أكتوبر 2026. هذا جرد أدلة، وليس شهادة مطابقة. عدم اكتمال حزمة توزيع أو اختبار هاتف لا يحول كودًا ناقصًا إلى «لم ننشر»؛ حالات native/API غير المكتملة أعلاه تبقى اختبارات تنفيذ مطلوبة وتتابع فعليًا.

| العائلة | الإثبات المتاح | ما يلزم لإغلاق الباقي |
|---|---|---|
| STORAGE | مصدر `FlutterSecureCloudSecretStore` وnamespacing لكل owner، اختبارات العزل السابقة، فحص تسرب الأسرار المنقح | فحص Keychain/Keystore الفعلي وbackup/logs على حزمة نهائية؛ اختبار AES لا يثبت حفظ المفتاح في hardware |
| CRYPTO | AES-GCM حقيقي على Android API36، fixture legacy ثابتة، تشفير/فك فعلي في دورة PostgreSQL والـRPC | نتيجة iOS الأصلية من الوظيفة الحالية؛ استعادة/تدوير مفتاح على جهاز مع حزمة موقعة تبقى بوابة مستقلة |
| AUTH | GoTrue signup/JWT/refresh وRLS وowner spoof ورفض JWT تالف؛ سحب دور moderator/device مع جلسة موقعة قائمة | حسابا المراجع الحقيقيان على artifact؛ OAuth ومزود الهوية ليسا ممثلين بـsignup التركيبي |
| NETWORK | فحص مدخلات URL للـrunner ومنع redirect؛ RPC عبر loopback مع هوية حقيقية | اعتراض TLS وشبكة SDK/AI على حزمة هاتف؛ loopback HTTP المعزول ليس إثبات TLS Production |
| PLATFORM | بناء plugins وCodeQL Java/Swift، أوامر النظام على API36؛ Native UI قيد الاختبار | إشعارات/روابط/أذونات Health الأصلية على النظام، وTalkBack/VoiceOver فعلي؛ صور Widget وحدها لا تغلقها |
| CODE | التحليل الكامل PASS، الشاملة السابقة محفوظة، source/dependency scanners؛ التنبيهات المتبقية معلنة | high RTI reachability لم يحسم؛ لا dismiss أو ترقيع مولد. MobSF static debug لا يغني عن فحص release binary |
| RESILIENCE | fail-closed release configuration وعزل jobs؛ اختبار retry/CAS/tombstone | Play Integrity/App Attest والتوقيع/anti-tamper على حزم توزيع مع بيئاتها؛ لا نتيجة dynamic pentest مدعاة |
| PRIVACY | اختبارات الموافقات المنفصلة ورفض الصوت الخام وبيانات البلاغ المحددة وعزل الحسابات؛ لا بيانات حية في الأدلة | تطابق الإفصاح مع IPA/AAB النهائي وسلوك SDK الفعلي؛ المفتاح العام يحتاج تحقق قيود مالك Google Cloud |

الاختبارات الموجودة للأداء والـbenchmark جزء من الشاملة السابقة؛ لا تسمى قياس سرعة Production أو أداء جهاز. لا توجد حتى الآن حملة fuzz/mutation أو نسبة coverage كاملة؛ لا يتحول count assertions أو تعدد الملفات إلى هذه المقاييس. توثيق هذا النقص صريح، وليس blocker بسبب غياب إذن نشر: يحتاج نطاق corpus/targets وقياس مستقل، مع أولوية إغلاق إخفاقات API/native المثبتة الحالية دون إعادة المنجز. لم تربط خدمة خارجية جديدة أو حساب أداة مدفوعة.

### التشغيل المحدود بعد تحقق الإصلاحات محليًا

حُفظت التغييرات في `19972310fea6284b59f3cfba5874223fac3f4607` ودُفعت fast-forward. الأوامر الفعلية:

```text
gh workflow run bil_codeql_security_extended.yml --ref integration/bil-qa-media-policy-20261011 -f supabase_only=true
gh workflow run bil_codeql_security_extended.yml --ref integration/bil-qa-media-policy-20261011 -f android_native_only=true -f ios_native_only=true
gh workflow run bil_codeql_security_extended.yml --ref integration/bil-qa-media-policy-20261011 -f mobsf_only=true -f android_artifact_run=38726365073
gh workflow run bil_codeql_security_extended.yml --ref integration/bil-qa-media-policy-20261011 -f source_audit_only=true
```

التشغيلات: [Supabase 38734170433](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38734170433)، [Native 38734174747](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38734174747)، [MobSF 38734179059](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38734179059)، [فحص مشغلات المصدر 38734392616](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38734392616). بدء تشغيلها ليس PASS. Source audit يعاد لأن مشغلات Python/JS/Actions جديدة أضيفت، ولا يعيد الشاملة أو بناء Java/Swift المنجز.

## النتائج المكتملة على 19972310

- **Supabase 38734170433 — SUCCESS**: كل migrations المتسلسلة مع preflight فصل الأدوار؛ SQL **9/9**؛ Node API/helper **34/34، صفر fail/skip**؛ دورة Flutter SQLite A→GoTrue/PostgREST/PostgreSQL→B **1/1**؛ PostgreSQL/PGlite **74/74**؛ Deno Edge Functions **358/358**. اختبارات Deno تستخدم حدود مزودين مزيفة معلنة، ولا تمثل شراء متجر أو طلب AI حي؛ SQL/RLS وAuth وStorage وRealtime أعلاه استعملت stack معزولة فعلية. PostgreSQL الصورة الفعلية `17.11.0.004` عبر CLI `2.121.0`، وليست نسخة PG17.6 المحلية السابقة.
- دورة SQLite تضمنت قواعد A/B وrenderer مستقلة، وتشفيرًا حقيقيًا، و19 مغذيًا، وحصة/علاقات/هويات، ومجهولًا مقابل صفر، وأقفالًا وأهدافًا ذات مصدر، وفقد رد بعد commit، وإعادة محاولة وصفحات وتعارض CAS وحلًا صريحًا وحذفًا. `cycle-proof.json` يثبت مراحل partial/conflict ثم completed الصحيحة؛ لا حذف partial من التقرير. مصدر AES داخل Flutter VM هنا .NET loopback، وتطابق Android native اختُبر منفصلًا أعلاه.
- فُتحت صور Flutter الثلاث المستعادة من server وفُحصت بصريًا: Today والأهداف وتحليلات التغذية؛ الإجمالي **246** والهدف **1000** والمتبقي **754** في Today والتحليلات. هذه بيانات تركيبية للفحص، ليست اقتراحًا صحيًا أو أرقامًا مأخوذة من صور المالك. الصور بجانب `cycle-proof.json` في دليل evidence. سياق أهداف AI Coach اختُبر عبر قارئ التطبيق، وليس استنتاجًا من JSON أو محادثة مزود حي. حالة أول وجبة بقيت منجزة ولم تُغير حقوق الشراء.
- **MobSF 38734179059 — التقرير اكتمل**: تحقق APK SHA-256 `93f0e343ba8243a2225e5aa271750a1272cda153cc35ec4ac3eb2ab745fcc412`، package BIL وbuild33 وmin26/target36. التقرير يضم **10 ملاحظات manifest**؛ منها `app_is_debuggable` المتوقع في هذا debug، وتحذيرات exported/permission وminSDK. يلزم فحص المكوّن/الحماية في release النهائي قبل نسبتها إلى عيب قابل للاستغلال. `code_findings` فارغة؛ لا تُسمى إثبات خلو كود Flutter أو إثبات نجاح decompilation لكل class لعدم حفظ تعدادها في هذا الملخص. لا تسرب source أو APK إلى SaaS، والحاوية كانت `--network none`. نجاح بناء APK في producer مثبت؛ فشل native اللاحق فيه بقي مسجلًا ولم يتحول إلى نجاح.
- **Source audit 38734392616 — SUCCESS في الوظائف الأربع**: Semgrep فحص **5,141 مسارًا، 15 finding، صفر أخطاء**. الزيادتان audit على urllib داخل MobSF؛ العنوان loopback ثابت داخل حاوية بلا شبكة. النتائج الحالية **FINDINGS_REVIEW**. CodeQL الحالي **25 fixed/28 open**؛ الزيادتان IDs52/53 في fixture الجلسة الخاصة. ID52 يحذر من exists/write، لكن الحماية الفعلية `flag: wx` تنشئ الملف حصريًا ذريًا و`mode: 0600`، فلا يعتمد الأمان على exists؛ وID53 كتابة مقصودة لجلسة GoTrue تركيبية إلى الملف الخاص ليقرأها Flutter، ثم حذفها. لا artifact للجلسة، ولا dismiss يدوي. الـhigh48 يبقى غير محسوم وفق فقرة الوصول أعلاه.

دليل النتائج والأوقات وSHA في `ci-19972310-results.json`. هذه الأعداد مجموعات مختلفة؛ لا تجمع على أنها عدد حالات فريدة عالميًا.

### قياس إضافي محصور للأهداف — لا إعادة للشاملة

أضيف مشغّل QA مستقل لـ`macro_goal_editor.dart` غير المعدل: seed **20261015**، **10,000 حالة مولّدة** و**380,014 تحققًا** للطاقة 4/4/9، حدود النسب، التحويل غرام↔نسبة، قفل الغرام/النسبة وثبات serialization ورفض المدخلات غير المحدودة. سماحية المقارنة المطلقة `1e-7` أصغر كثيرًا من دقة العرض ولا تخفي فرقًا غذائيًا.

نجحت محليًا، وكشفت **5/5 تعديلات سلوكية خاطئة مقصودة** على نسخ مؤقتة: معامل دهون خاطئ، السماح بتحرير مقفل، السماح بقيمة غير finite، فقد قفل الغرام، وتجاوز سقف تحقق السعرات. لم يُمس المصدر الحقيقي؛ hash قبل/بعد مطابق. محاولات الـmutants المتوقعة ليست إخفاقات المنتج؛ لا يحتسب compile error كقتل mutant. صُحح أولًا تشخيص العارض لنص Dart `Bad state` ثم نجح القياس النهائي.

تغطية VM للملف المستهدف فقط: أسطر **78/81**، دوال **7/8**، فروع **24/27**. ليست نسبة تغطية للتطبيق ولا mutation score شاملًا. يستخدم coverage المثبتة في package map دون إضافة SDK/package؛ لا تسرب VM service URI في التقرير. `macro-generated-local.json` يحفظ زمن التشغيل والهدف والبصمة والنطاق. أُضيف إلى مسار source audit لكي ينفذ في GitHub أيضًا؛ لا إعادة Native/Supabase ناجحة لأجل هذا المشغّل.
