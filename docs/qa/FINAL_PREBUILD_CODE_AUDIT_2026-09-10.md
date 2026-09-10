# BIL — Final Pre-Build Code & Repository Audit

Task: `BIL-PREBUILD-20260910`; branch: `codex/bil-unified-release-20260909`.
Baseline: `8d48db48a9b8b5c59b6c10e8a26868bf590de13f`.

**النتيجة الكودية: العيوب المعروفة المكتشفة في هذا التدقيق أُغلقت ضمن حدود التحقق أدناه.**
هذا تدقيق كود، وليس ضمانًا بانعدام جميع الأخطاء أو شهادة جاهزية نشر.
تقارير QA المجاورة أدلة تاريخية، وليست إثباتًا لإعادة تنفيذ إجراءات إنتاجية هنا.

## A. Repository Audit

جُردت شجرة الملفات المتتبعة وغير المتجاهلة كاملة، لا الـdiff فقط: Flutter/Dart،
Riverpod، GoRouter، Drift/SQLite، Swift/Kotlin bridges، Supabase SQL/RLS/Edge،
Cloudflare Worker، الاعتمادات والأقفال، الترجمة، البناء والخصوصية وأدوات الإصدار.
الفحص يجمع المسح النصي والتحليل الآلي ومراجعة المسارات الحساسة؛ لا يُدّعى فحص
بصري أو قراءة بشرية لكل سطر بيانات مولد أو لكل مكتبة خارجية.

قُرئت README ودستور الإصدار ومراجع المعمارية والبيانات والبناء ومطابقة طلبات
المالك. لا AGENTS.md داخل الشجرة. تعليمات المالك الحديثة حاكمة على المستندات القديمة.
كان index فارغًا و327 ملفًا سابقًا متغيرًا؛ لا reset/checkout لإزاحة عمل المالك.
النسخة المحفوظة قبل التعديل:
`G:\BIL_Project\audit_backups\prebuild_20260910_code_only_verified`.
327 ملفًا، 25,195,847 بايت؛ SHA-256 للـmanifest:
`031B175E1317D536E330A5CDBECBBA9437488B58FF21A27FCF3F7BAED2FC3946`.
الـdiff يشمل دفعة المالك الأصلية والإصلاحات المكملة، وليس كله عمل هذا التدقيق.
ملفات golden السابقة محفوظة كأصول سابقة غير مفحوصة بصريًا، لا كدليل جديد.

## B–D. Bugs Found / Root Causes / Fixes

| العيب المثبت | السبب الجذري | الإصلاح |
| --- | --- | --- |
| reset يراكم 2,500 كل مرة | trigger يمنح مبلغًا ثابتًا | إضافة `max(0, 2500-(granted-used))` فقط، مع قفل صف الرصيد وسجل الزيادة الفعلية بما فيها صفر. الرصيد الأعلى لا يُنقص. |
| تكرار reset بعد الاستهلاك يحتاج إثبات تنفيذ مستقل عن الرصيد | تحديث الرصيد وحده ليس idempotency | حفظ `(reset_id,owner_id)` حتى حين الزيادة صفر؛ replay لا يمنح ثانية، وطلب جديد يملأ الفرق. |
| تحديث الملف قد يحذف الأهداف التابعة أو يكرر الملف تحت التزامن | REPLACE يحذف الصف، والقراءة/الكتابة منفصلتان | transaction وUPSERT يحفظان الهوية والمراجعة والأهداف؛ اختبارات Drift فعلية RED/GREEN. |
| NaN يتجاوز حدود الهدف | المقارنات وحدها لا ترفض NaN | التحقق من isFinite قبل الحفظ. |
| طلب إذن صحة صريح قد يضيع خلف تحديث تلقائي | دمج عمليات مختلفة في future واحد | طابور مرتب؛ دمج التكرار المتجاور من النوع نفسه فقط، مع حماية التخلص من المتحكم ومن الانتظار الدائري. |
| فتح بحث الطعام تلقائيًا بقي في مسار Quick Add ثانٍ | focus=meal يستدعي الفتح من initState/didUpdateWidget | إبقاء توجيه الوجبة والتمرير، وإزالة الفتح التلقائي؛ الفتح بضغط المستخدم فقط. |
| Quick Macro قد يحفظ مرتين أو يلمس controllers بعد الإغلاق | حارس حفظ متأخر وملكية خارج lifecycle | widget يملك controllers ويتخلص منها، حارس قبل await، وmounted بعد اختيار الوقت؛ المفقود لا يتحول لصفر. |
| نتيجة إعجاب قد تنتقل لمنشور آخر بعد إزالة بطاقة | stateful siblings بلا هوية ثابتة | مفاتيح post.id على العناصر الخارجية في Saved/My Posts؛ اختبار رد متأخر لا يستبدل بيانات المنشور التالي. |
| الاستعادة/واجهة الشراء قد تعلن نتيجة قبل تحقق الإيصال | futures وnative callbacks غير مرتبة | قفل فوري وطابور callbacks، انتظار الاستعادة للتسوية، وفشل acknowledgment يمنع إعادة الشراء المباشر. |
| رد فتح شراء/كتالوج قد يستبدل معاملة أحدث | لا تمييز لترتيب أحداث المتجر | generation يمنع ردًا قديمًا من استبدال pending/verified؛ للاشتراك وBoost والأسعار. |
| stream error قد يترك pending دائمًا | تجاهل الخطأ لمجرد busy | فشل صادق لا يسمح بإعادة الخصم إن لم يكن تحقق إيصال جارٍ؛ التحقق الجاري يحتفظ بنتيجته. |
| Worker لا يحترم منحة الإدارة أو يرفض مشتركًا بعد 72 ساعة | مصدر منحة مفقود وخلط verified_at بالانتهاء | مصادر وصول مستقلة، lease إداري قصير، وحد انتهاء المتجر الفعلي؛ تعطل مصدر لا يلغي الآخر الصحيح. |
| نسختان من push dispatcher | منطق منسوخ في نقاط دخول | تنفيذ مركزي ونقطتا دخول للتوافق؛ فحص السر الداخلي بمقارنة digests ثابتة الطول. |
| Android lint/موارد locale غير صحيحة | سمة API 27 في values العامة، ورمز id بدل in | qualifiers مناسبة ومولد locale مطابق؛ أُعيد compile/lint. |
| قواعد backup الحديثة غير صريحة | الاعتماد على allowBackup فقط | dataExtractionRules تستثني بيانات التطبيق من cloud backup وdevice transfer؛ اختبار XML. |
| ثغرات تبعيات تطوير | sharp قديم وJUnit 4.12 انتقالي | override محدود لـsharp 0.35.4 وقيد JUnit 4.13.2 عند وجوده فقط؛ لا mass upgrade. |
| قبول نتائج مكررة كدليل، وقفل monitor قابل للسباق | عد الصفوف فقط؛ Test-Path ثم كتابة ملف | validator مستقل لـ31 هوية فريدة والتليمترية؛ FileShare.None طوال التنفيذ. اختبار الدوال المعزولة فقط. |
| أداة التحليل تضيع تفاصيل compiler | استعمال متغير PowerShell النظامي error | متغير محلي مستقل؛ اختبار RED/GREEN يحفظ الملف والسطر وseverity/message. |
| اختبارات PostgreSQL تعتمد مسار diagnostics متجاهل | اعتماد غير قابل للاستنساخ | package/lock محليان وPGlite 0.5.8 مثبت؛ تشغيل جديد بـnpm ci ثم 31 فحصًا. |
| جرد الـdiff يتغير بعد staging ويفشل whitespace gate على Windows | التصنيف من index بدل HEAD، rename detection وnewline الافتراضي | المقارنة مع HEAD و`--no-renames` وLF صريح؛ regression test للتصنيف/النقل/نهاية السطر، وتسوية EOF لتسعة fixtures SQL بلا تغيير منطقها. |

## E. Regressions / قرارات المالك المحمية

- الحائط يحكمه credits.total_remaining، لا Premium. إلغاء المنحة الإدارية لا
  يلغي شراء Apple/Google، ولا يخلط حساب Boost بحصة الاشتراك.
- لا تعديل لملف ai_coach_settings_usage_widgets.dart ولا فرض تغيير عداد
  `0 of 0 left this week` الذي طلب المالك إبقاءه.
- لا واجهة JSON مُعادة. النماذج والبحث اليدوي ودليل مصدر المكونات محفوظة.
- تسعة fixtures تاريخية أضافتها محاولة تدقيق سابقة سُحبت بعد اعتراض المالك إلى
  backup قابل للاستعادة؛ لم تعد مرجعًا للمنتج/الاختبارات. الاختبارات تتبع
  كتالوج الـ1500 الحالي، ولا تزرع بيانات قديمة لإسكات فشل.
- اختبارات مصدر قديمة عُدّلت لتتبع parts المستخرجة، وتنسيق النص وحجم الساعة
  المعتمد سابقًا. لم يُغير المنتج لاسترضاء تلك التوقعات. اختبار سباق البحث
  يحتفظ بتأكيد رفض رد a القديم بعد apple، مع فتح صريح من المستخدم.
- الإعلانات مؤجلة؛ لا تغيير signing أو version أو سياسات Social v2.

## F. Duplication

أُزيل تكرار push dispatcher وfallback Quick Macro. جرى جرد exact duplicates
وأسماء classes والمستدعين. أربعة أسماء متشابهة ليست تنفيذًا مكررًا: BodyTwin
الحتمي مقابل foundation state، OneBestAction اليومي مقابل ترتيب المرشحين،
DashboardComposition كـwidget مقابل geometry، وMealVisionUsage للمزوّد مقابل
الحصة. لم تُدمج مسؤوليات مختلفة لمجرد الاسم. المسح heuristic لا يثبت رياضيًا
انعدام كل تشابه دلالي.

## G. Dead / Legacy Code

حُذف Quick Macro fallback غير المستدعى (نحو 229 سطرًا وignore غير لازم) بعد
تتبع المراجع. حُذفت ثلاث نسخ احتياطية مصدرية بلا مراجع: نسختا dashboard
before_card_height ونسخة Windows CMake .bak؛ نسخ مطابقة محفوظة في
`obsolete_tracked_backups/` تحت backup التدقيق، ويمكن استعادتها.
رُوجعت TODO/FIXME/HACK/TEMP/XXX؛ تشمل matchers ومتغيرات أدوات وقيود codecs
upstream. لم تُحذف وظائف مكتبة أو compatibility bridges بناءً على التخمين.

## H. Architecture / State Integrity

| المعلومة | المصدر الحاكم | حد المزامنة |
| --- | --- | --- |
| الحساب | Supabase Auth | providers تتغير بتغير owner، بلا تسرب منحة حساب سابق |
| الملف/الهدف/السجل المحلي | Drift schema 21 | validation ثم transaction ثم تحديث المستهلكين، بلا REPLACE للهوية |
| اشتراك مدفوع | إيصال متحقق وbil_subscriptions | callback محلي/اسم خطة مخزن ليس entitlement |
| منحة الإدارة | RPC محمي وجدول خاص وlease قصير | لا تعديل إيصالات المتاجر أو إلغائها |
| حصص المدرب | ledger/quota/reservation بالخادم | الإشارة المحلية تطلب reload ولا تختلق رصيدًا |
| الصحة | قراءة أصلية بتاريخ/مصدر/وحدة مقبولة | اكتمال طلب التفويض لا يثبت إذن جميع القراءات؛ لا أعمدة تمثيلية |
| الوصفات | كتالوج الإصدار ودليل مكوناته | البطاقة والمدرب والحفظ واليوميات تستهلك الحساب نفسه |

استخراج parts أبقى هوية libraries وخصوصيتها؛ لا migration للـframework.
دورات import الأربع تخص conditional factories وre-exports توافقية وrouter/auth
كسول التهيئة؛ لا تكرار initialization أو recursion تنفيذي مثبت فيها. لم تُعد
كتابة المعمارية لإزالة coupling بلا ضرورة. صُححت README/ARCHITECTURE/DATABASE
من وصف schema 13/سلطة محلية فقط إلى schema 21 والسلطات الفعلية المنفصلة.

## I. iOS Code Quality

مراجعة Swift bridges وInfo.plist/entitlements/privacy manifest وXcode/SwiftPM،
خيط UI ودورة الحياة وHealthKit وApple Sign in والصوت والكاميرا والرموز الأصلية.
طلب HealthKit عند الحاجة النظامية فقط، وإرشادات مراجعة عند عدم إمكان إعادة
شاشة التفويض؛ لا اختراع ضمان لعرضها. اختبارات المصدر وwidget semantics
والترجمة/RTL/text scaling لا تثبت VoiceOver أو مظهر iPhone. Swift compiler
غير متاح على Windows؛ لا يُصنف فحصه ناجحًا.

## J. Android Code Quality

أُعيد compileDebugKotlin وlintDebug وحل debugRuntimeClasspath بعد آخر إصلاح.
لا assemble أو Flutter release build. رُوجعت API 26/36 وJVM 17 وHealth
Connect/BLE/permissions/lifecycle/back/insets/exported components/deep links.
بقيت 22 ملاحظة غير حاجبة: سمات نظام حديثة تتجاهلها الإصدارات الأقدم، صلاحيات
legacy مقيدة بـmaxSdk، موارد ديناميكية، styles توافقية، واقتراحات KTX/ترقية.
لا suppressions جديدة لإخفاء خطأ. 15 قاعدة IconDetector بصرية استُبعدت
باستخدام init script لهذه المهمة فقط؛ normal release lint لم يُضعف، وهذه
القواعد NOT RUN.

## K. Security / Dependency Audit

مسح redacted للمصدر الحالي وتاريخ Git، مع مراجعة كل مرشح مقابل مصدره المحدد.
نتائج الماسح الخام محفوظة حتى عندما تكون FAIL؛ التصنيف اللاحق مستقل ويفشل
لأي مرشح جديد غير مفهوم. publishable/anon ليست service-role secrets؛ fixture
PEM السالب يُرفض بمحلل crypto الحقيقي. لا كشف أسرار أو allowlist شامل.

اختبارات PostgreSQL تنفذ القيود وRLS/ACL والدوال الحقيقية المعنية، وتثبت منع
المستخدم العادي/anon من الإدارة والكتابة الخاصة، وحفظ paid receipts وBoost.
استُخدمت إرشادات Supabase/Postgres للأقفال والصلاحيات الصريحة وإرشادات
Cloudflare لحدود الطلب وسلطات الوصول المستقلة؛ لا نشر أو تغيير Auth إنتاجي.

فُحصت إحداثيات 231 حزمة Pub، و14 npm من Deno lock، و212 Maven محلولة، إضافة
إلى npm audit للـWorker واختبارات PostgreSQL. النتائج الأخيرة لهذه المجموعات
لا تحمل ثغرات مُبلّغًا عنها بعد الإصلاح المحدود. JSR/روابط Deno القياسية وحل
تبعيات iOS الأصلي ليست مشمولة بإثبات OSV هذا. مرجع JUnit:
[تنبيه المشروع الأصلي](https://github.com/junit-team/junit4/security/advisories/GHSA-269g-pwp5-87pp).

## L. Performance Code Review

ملخص revision يستخدم aggregate بدل تحميل السجل كاملًا؛ منع العمل المكرر
يشمل تهيئة المتجر وcallbacks وقراءات الصحة. controllers/timers/listeners تتبع
lifecycle، والقراءة اليومية محدودة. بوابة timing محلية للمنطق ليست benchmark
للإطارات/البطارية/الذاكرة/الشبكة على الجهاز؛ لم يُشغّل profiling.

## M. Tests / Baseline / Re-audit

الدليل المحلي: `build/diagnostics/prebuild_code_audit_20260910/`؛ يحفظ run_gate.py
الأمر والتوقيت وexit code والمدة والسجل. الجولات الحمراء والمنقطعة ليست PASS.
Baseline كشف 26 ملف تنسيق Dart و53 require-await في test doubles وثغرة sharp
ومشاكل Android وتوقعات اختبارات قديمة؛ عولجت الأسباب ثم أعيدت الفحوص المتأثرة.

PGlite: 21 فحص إدارة و10 reset عبر migrations/RPCs/triggers فعلية. تشمل
1,500→2,500 و2,485→2,500 وثبات 2,500 و7,500 وreservations/replay/reset عام
واشتراك مدفوع غير فارغ لم يتغير. PGlite يسلسل الطلبات؛ ليس دليل تنازع جلسات
PostgreSQL مستقلة أو rehearsal كامل لقاعدة الإنتاج.
Deno: 186 اختبارًا بشبكة تشغيل معطلة؛ Worker: 49 في 5 ملفات عبر HTTP/R2
محليين. Python/Node للإصدار والتغذية والأدوات لها أوامر وأدلة منفصلة.
الجولات المتداخلة لا تجمع بوصفها اختبارات فريدة.

انتهت الجولة الكاملة ثم إعادة الملفات المتأثرة. نتيجة التغطية الأخيرة:
947/947 ملفًا ضمن الاختيار المسموح، `missing=[]` و`failed_or_stale={}`؛ منها
15 ملفًا بمرشح أسماء يستبعد الحالات المحظورة، وليس كل حالات تلك الملفات.
15 ملف اختبار كاملًا و5 ملفات device integration لم تُشغّل، وهي مسجلة بالسبب.
فشل سبعة توقعات قديمة في الجولة الأولى حُفظ كدليل ثم أُغلق بإعادة ملفاتها.
اختبارات المتجر الجديدة احتاجت تصحيح fixture إلى بيانات StoreKit بمدة اشتراك
وعروض صريحة؛ لم يُضعف شرط التحقق، وأُعيد compiler والاختبار.
الـWindows symlink test المستبعد أصلًا شُغّل صراحة بـ`--run-skipped` ونجح؛
الجولة الأخيرة للمتجر وملفه 23/23، منها 11 لحالات ترتيب المعاملة. لم تُضف skips.

| مجموعة الاختبارات | أمر التشغيل / اسم سجل run_gate | النتيجة المنفذة |
| --- | --- | --- |
| Flutter headless | `python tool/prebuild/run_code_tests.py final` ثم `final_flutter_followup` و`final_flutter_store_and_symlink_verified` | 947 ملفًا مغطى؛ أسماء الحالات/المخرجات محفوظة في السجلات |
| تحقق تغطية الإعادة | `python tool/prebuild/verify_code_tests.py` | 947/947؛ صفر فشل/نقص/قدم دليل |
| Deno Edge | `deno test --config supabase/functions/deno.json --allow-env --allow-read --deny-net supabase/functions` | 186/186 |
| Worker | `npm test` داخل `cloudflare/workout-runtime` | 49/49 في 5 ملفات |
| PostgreSQL | `npm ci --prefix supabase/tests --ignore-scripts` ثم `npm test --prefix supabase/tests` | 31/31 |
| Python release | `python -m unittest discover -s tool/release -p test_*.py` | 82/82 |
| Python wellness | `python -m unittest discover -s tool/wellness_content -p test_*.py` | 18/18 |
| Python nutrition | `final_nutrition_python` و`final_nutrition_tools` | 42/42 و10/10 |
| Python recipes | `python -m unittest discover -s tool/recipe_catalog -p test_*.py` | 9/9 |
| Python audit harness | `python -m unittest discover -s tool/prebuild -p test_*.py` | 16/16 |
| Node store/site tools | `final_node_unit` | 39/39؛ بلا طلبات إنتاجية |
| Node reviewer policy | `final_node_reviewer` | 26/26؛ fixtures محلية |
| Node canary policy | `final_node_canary` | assertions ناجحة عبر HTTP محقون، لا canary حي |
| Dependency parser / staging isolation | `final_dependency_scanner_formatted` / `final_worker_check` | 3/3 و5/5 |
| Local timing only | `final_flutter_performance` | اختباران؛ startup 194 ms ووسيط البحث 2 ms على هذا المضيف فقط |

الدليل المفصل لكل ملف: `build/diagnostics/prebuild_code_audit_20260910/final_code_test_coverage.json`.
السجل المحدد فيه يربط الملف بالأمر والتوقيت والنتيجة؛ لا تستبدل نتيجة إعادة
جزئية نجاحَ ملف كامل، ولا نتيجة قديمة إصلاحًا أحدث. الأوامر الكاملة لبقية
المجموعات محفوظة في ملفات JSON المناظرة لاسم السجل أعلاه.

### انحراف نطاق موثق

في baseline سابق شوّه flutter.bat/cmd مرشح regex، فاشتغلت أربعة اختبارات
golden في ملف benchmark وفشلت خلاف القيد. أُبلغ المالك؛ لم تُفتح النتائج
بصريًا ولم تُحدّث المراجع. تلك الجولة ليست دليل code-only صالحًا. أُصلح runner
باستدعاء Dart/snapshot مباشرة بلا shell، وأضيف اختبار argv لكل مرشح ومنع
fallback للـbatch. البصري في الجولة النهائية NOT RUN؛ لا يُدعى أن محاولة
بصرية لم تحدث مطلقًا خلال التاريخ السابق.

## N. Verification Matrix

| Gate | الحالة | دليل / حدود |
| --- | --- | --- |
| جرد Git والشجرة والمراجع والـconflicts | PASS | 5,178 مسارًا قبل staging، بما فيها مسارات الحذف؛ لا علامات تعارض أو أخطاء Python/XML في المسح |
| Dart analyzer — lib / tool / integration_test / test_driver | PASS | `--fatal-infos`؛ صفر errors/warnings/infos؛ تحليل integration ليس تشغيله |
| Dart analyzer — test، بعد آخر fixture | PASS | `final_dart_test_analysis_close`؛ No issues found |
| Dart formatter — إغلاق آخر fixture | PASS | `final_dart_format_close`؛ 2,279 ملفًا، صفر تغييرات مطلوبة |
| Flutter final coverage + re-audit | PASS | 947/947؛ لا فشل معروف متبقٍ؛ الاستبعادات صريحة |
| اختبارات SQL / Edge / Worker / Python / Node أعلاه | PASS | النتائج والأوامر في M، بلا عمليات حسابات إنتاجية |
| Deno lint / fmt / check | PASS | 60 ملف TS؛ صفر أخطاء؛ لا suppressions جديدة |
| Worker TypeScript / generated types / staging boundaries | PASS | `npm run check`؛ types check وtsc و5 اختبارات عزل |
| Android Kotlin compiler + code-only Lint | PASS | `compileDebugKotlin`, `lintDebug`؛ 910 tasks، 21 منفذة و889 up-to-date؛ 22 warning روجعت |
| PowerShell syntax | PASS | ParseFile لـ128 ملفًا، صفر أخطاء؛ لا تنفيذ برامج الأجهزة |
| JavaScript/MJS/Bash syntax | PASS | 69 ملفًا؛ `node --check` و`bash --noprofile --norc -n` فقط |
| Build/privacy configuration source contracts | PASS | XML/plist/privacy/entitlements + اختبارات المصدر وGradle؛ ليس signed build |
| Dangerous duplication / dead-code review | PASS | صفر مجموعات exact code duplicates؛ 4 أسماء و4 دورات مقصودة روجعت، 22 TODO candidate روجعت |
| Pub / Deno npm / Maven advisory queries | PASS | 231 / 14 / 212 إحداثية محلولة؛ صفر نتائج ثغرات لهذه المجموعات بعد الإصلاح |
| npm dependency audit | PASS | Worker وPGlite، صفر vulnerabilities |
| Gitleaks current + historical candidate review | PASS | 31 مرشحًا في المصدر و39 في تاريخ 451 commit صُنفت جميعًا؛ raw FAIL محفوظ، صفر سر صالح مكشوف مثبت أو مرشح غير محسوم |
| Final source diff validation | PASS | `git diff --check` و`git diff --cached --check` بعد إصلاح EOF؛ تطابق 478 مسارًا مع القائمة المراجعة |
| Swift compiler / Xcode / SwiftLint / iOS native dependency resolution | NOT RUN | الأدوات غير متاحة على Windows |
| actionlint / PSScriptAnalyzer | NOT RUN | غير متاحين؛ syntax/source contracts أعلاه ليسا بديلًا مزعومًا عنهما |
| JSR/Deno URL-native / iOS-native vulnerability scan | NOT RUN | ليست ضمن إحداثيات OSV/npm/Maven المفحوصة |
| Android IconDetector rules (15) | NOT RUN | مستبعدة من هذا التدقيق وحده بسبب منع تحليل الصور |
| iPhone/Android device, simulator/emulator, native permissions and store flow | NOT RUN | مرحلة المالك اللاحقة |
| Visual/golden/screenshot/image/video/profiling acceptance | NOT RUN | الجولة النهائية لا تنفذها؛ حادثة baseline في M ليست PASS |
| APK/AAB/IPA, release signing, CI, production deployment | NOT RUN | غير مطلوبة ضمن هذه المرحلة |

PASS هنا يصف البوابة المسماة وحدودها فقط. محاولات FAIL السابقة محفوظة في
السجلات، لا تُمحى ولا تُستخدم بديلًا عن آخر نتيجة متحققة.

## O. Unverified Runtime Items

**NOT VERIFIED IN THIS CODE-ONLY AUDIT**:

- الأجهزة والمحاكيات والصور/الفيديو وvisual/pixel regression، المظهر وVoiceOver/TalkBack الفعليان.
- HealthKit/Health Connect/BLE، كاميرا الباركود وإضافة الصديق، الميكروفون والاستئناف على جهاز.
- شراء/استعادة/تجديد/إلغاء متجر، وصول push أو منحة لحساب حقيقي.
- signed build/AAB/IPA/R8 release وSwift/Xcode وSwiftPM native resolution و16 KB لحزمة جديدة وCI/رفع متجر.
- production migration rehearsal، تنازع PostgreSQL متعدد الجلسات، ونشر آخر Edge/Worker/migration. لا نشر خلال التدقيق.

## P. Remaining Risks / Next Phase

نجاح الكود لا يلغي الحدود أعلاه. migration reset الجديدة تجهز السلوك؛ الهاتف
لا يتغير قبل نشر الخادم المناسب والبناء لاحقًا. اختبار حساب المالك المخصص
للمنح والإلغاء الشهري/السنوي والمجتمع والأصدقاء والباركود مرحلة لاحقة بتأكيده
بعد كل خطوة. لم تُنفذ كتابة على ذلك الحساب، ولا نشر منشور أو إضافة صديق هنا.
الإلغاء الإداري يقتصر على المنحة الإدارية، لا اشتراك Apple/Google المدفوع.
لا توجد Critical/High معروفة غير معالجة في المصادر والاعتمادات التي شملها
التحقق؛ هذا لا يحوّل التبعيات والمنصات غير المفحوصة إلى PASS. بقي تحذير
توافق Gradle 10 المستقبلي من الأدوات الحالية، لا خطأ في Gradle 9.1 المستخدم؛
لم تُرقَّ سلسلة البناء جماعيًا لإزالته. لا تحفظ صور QA السابقة بوصفها دليلًا
بصريًا جديدًا لهذا الـcommit.

## Q. Final Commit

رسالة الـcommit الواحد: `fix: finalize BIL pre-build integrity and balance resets`.
هوية النسخة هي commit الذي يحتوي هذا التقرير؛ يُسلّم hash والتحقق من نظافة
الشجرة في الرد النهائي بعد إنشائه، ولا يضمّن التقرير hash لنفسه.

[قائمة الملفات الكاملة ومنشأ كل تغيير](PREBUILD_CHANGED_FILES_2026-09-10.md)
تحصر 478 مسارًا؛ Git قد يجمع مساري نقل مورد اللغة في rename واحد. هذه الدفعة
تضم تغييرات المالك الـ327 الأصلية مع الإصلاحات المراجعة، لا استبدالها.
ملخص الـdiff: سلامة البيانات والصحة والشراء، reset غير تراكمي، تبويبات الإدارة
ومنحها المنفصلة، المحافظة على تدفقات التغذية/المدرب/المجتمع التي طلبها المالك،
حدود المنصات والأمان، اختبارات regression وأدوات/أدلة إعادة التدقيق. الأصول
الثنائية السابقة لم تُعرض أو تُغيّر خلال التدقيق. لا push أو نشر أو بناء إصدار.
