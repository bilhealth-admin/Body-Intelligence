# BIL GitHub maximum certification — final audit record

> تحديث الاستكمال: نتيجة هذه الوثيقة تاريخية على SHA المذكور فيها. حالة text-7 إلى text-18 الأحدث وأسباب إخفاقات GitHub ونتائج إصلاحها موثقة في [تقرير المطابقة](BIL_TEXT7_18_RECONCILIATION_20261015_AR.md). لا تعني نتيجة 9,843 السابقة اختبار SHA أحدث، ولا تعني builds المحاكيات نجاح متجر أو جهاز فعلي.


> **تحديث الحالة:** الفقرات أدناه تسجل لقطة أُعدّت عند commit `234b75d1`. يعلو عليها هذا الملحق الأحدث عند اختلاف الحالة أو عدد Workflows.

## استكمال التحقق حتى 15 أكتوبر 2026

مصدر الأدلة الجديدة هو aca3afbd91fce9cf146e9ecd1aa22283897c4e7c على الفرع integration/bil-qa-media-policy-20261011، فوق 533a68d9a20e9b9aae119010c10286cbe3b01a07. أصلح 533 قراءة النشاط المستأنف وانتظار أول إطار؛ وأضاف aca شرط ظهور محتوى لا يقل عن 5% وزرًا مفعّلًا قابلًا للنقر في شجرة Android UIAutomator، مع إعادة الفحص حتى 30 محاولة. لم يتغير lib أو مدخلات Flutter أو Goldens أو migrations أو pubspec. نتيجة 9,843 حالة تظل منسوبة إلى SHA التطبيق ef4b9f19f491426ba8663ba1a9d76f9af6fe0c67 وبصمة المدخلات 80087ad7b2ef76192e9f22c5be0af34edc53dfc2139eb1b63ad81eaf7416614e، ولم تُعد الشاملة لعدم تغير مدخلاتها.

كانت 38669439414 خضراء كاذبًا، وكشفت 38671525669 قصورًا في الحارس. وبعد إصلاح 533، بدت 38673538296 خضراء أيضًا، لكن مراجعة صورها رفضتها: خمسة محاكيات بقيت على شاشة الإقلاع الزرقاء وواحد فقط عرض Welcome؛ لذا كان فحص الإطار وحده غير كافٍ. أصلح aca شرط المحتوى والتفاعل. التشغيل الأخير 38675377553 نجح على API 26/29/33/34/35/36 بعد المحاولة الثانية؛ أُعيدت الوظيفتان الفاشلتان فقط. فشل API 26 في المحاولة الأولى بسبب نافذة تعطل تطبيق Messages في صورة المحاكي مع بقاء BIL مستأنفًا، وتعذر API 36 قبل بناء التطبيق بسبب أرشيف NDK تالف؛ اختفى السببان في المحاولة الثانية. الصور النهائية تعرض Welcome، وكلها اجتازت حد المحتوى وزر التفاعل، بلا نافذة تعطل أو ANR من BIL. اختبارات الحارس المحلية 5/5، وpy_compile وbash -n وgit diff --check ناجحة. هذه أدلة تشغيل Android معزول وليست اختبار جهاز أو متجر.

### مصفوفة الإقلاع الحالية — تشغيل 38675377553 على aca3afbd

| API | المحاولات | نسبة محتوى BIL في الإطار | زر تفاعلي في UIA | APK SHA-256 | Screenshot SHA-256 |
|---:|---:|---:|---|---|---|
| 26 | 4 | 72.77% | نعم | debfc8aa4a56cb8bb1acfbaad30a4d8e368f78ac8ba398464cc4a17ad7f41858 | 7bb3fe29f0ad24323d9ca363a73737112951eb94a753350a0cfb0e4998db90a6 |
| 29 | 4 | 72.77% | نعم | 8407b98d0e2a13df4336c00cc65341e7c5125ff9e89a5f671f9f7f8d06060da6 | cf52bc59b572348b23c225d7be0a5a2b80dcc0cd80fdbcf001541e89258e2a1a |
| 33 | 5 | 64.15% | نعم | f8c80dc01f985b8496e875b86511bb2f84b13e1a658fbbb11f0862d703faa7d0 | e09bde541d91f4664b43c5cda9fc01124008f52a022c78615752a4768a7a0caa |
| 34 | 4 | 64.15% | نعم | f69cf7324bae24784edaf3ec38e3c8e74431e6d755b1fb3889f50de099061a0f | f477785ed50d2796f2bd44c1fb08546dea4954d5642876e14b666f8314cb33f6 |
| 35 | 3 | 64.15% | نعم | 6b89d044e874e74accee13914ccfd3af3eea3b1ad3daa9a29d7005a17113a345 | 39dc1f9e9be9ae4e54d96cf30f461cc92164158153f32667603e79d38b1b7b50 |
| 36 | 3 | 64.15% | نعم | 598a51ade8d5beb13b947e81b8840f72ea45337c0a242ae28582882c2e819ae8 | 28e4bb50ed917dc22aa7bc8fa7bcbb7c878ce25940e9aa862a014109737f872c |

جميع المخرجات من APK debug بإعداد offline؛ لا تتصل بـSupabase أو الدفع أو الإعلانات أو المجتمع أو push. كل ملفات السجلات النهائية تسجل frame_ready=true وapp_content_ready=true، ولا تسجل FATAL EXCEPTION أو ANR أو نافذة تعطل نظامية. هذه hashes للـAPK واللقطة في Artifacts GitHub، ولا تمثل توقيع Release.

بصمات مخرجات تشغيل Android المرفوضة من [38669439414](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38669439414) محفوظة محليًا من Artifact GitHub؛ ملفات APK أدناه debug موقعة بمفتاح debug فقط وليست حزم Release موقعة، والخانات لا تثبت AAB أو واجهة صحيحة:

| API | APK debug SHA-256 | لقطة الإقلاع SHA-256 | ما ظهر في اللقطة |
|---:|---|---|---|
| 26 | `ec5dd07a5dbdf66a0846cf723eb238a7ef75115dba793a6296a612db37810ebf` | `12f3068ebfecf69d1617e4997e64ba558af8a3bf0ee42b8e54d82c2d7a632975` | لون الإقلاع فقط |
| 29 | `0d41af35b35729b178fe85aae98af7d2f4cbf3545a121d39d746feef9daa2be2` | `91d92d72f125945d14c34598affb57ee18cd038c00c967e039fb7c92ecb6cc74` | لون الإقلاع فقط |
| 33 | `1a03c4eb4928019f3487a29b84df1ff52ac8fe2518a5611605df6c71a634aaf3` | `acdb3397b4291caeae5b82a75a9db64ea18bab304e11750f886e0081237a8a94` | «System UI isn't responding» |
| 34 | `12c10051e55422ecc17ec426c42a124d5f90f33412693408e7cb47030086ba35` | `c546f9fbe4e5162de098e2dc5ee30a1b5901667e05d3dbcac4fe40b293461af5` | «Pixel Launcher isn't responding» |
| 35 | `543fe65a296e481e887168d9328b48743b6be35c9f68fa1ccecde4b81c8ddd33` | `35b1c30bc59b691b3d6de94ba4529f89eaf37c20e298f82cd22df78959d4053b` | لون الإقلاع فقط |
| 36 | `36f93aa2a6b6924514c6c73a8ae7e6db93498ec01c2c5958bf0e77fbe1daaf95` | `1cca72473abe6df18d3f0cff9dd682037b232582075fbfd634dab04d59640519` | لون الإقلاع فقط |

أدلة التشغيل التشخيصي [38671525669](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38671525669) على SHA `7485c7cc`؛ كل هذه الوظائف انتهت فاشلة من ناحية الحارس، ولا تُعد نجاحات اختبار:

| API | المرحلة | لقطة الفشل SHA-256 | مراجعة الدليل |
|---:|---|---|---|
| 26 | `verify-first-frame-content` | `b716544fd6eaafc3c2a528894282e4791245e5bc9e6a9c5b5570fe7327c90c16` | سطح أسود في لقطة مبكرة؛ النشاط والشجرة الدلالية جاهزان، وأول رسم مسجل بعد 7.405 ثانية. |
| 29 | `wait-for-app-foreground` | `0af95575d0e64a2938c8636695ecc39262f69883b81df7a413c4d92c684664b7` | شاشة ترحيب BIL مرئية؛ سطر النشاط الأمامي موجود في سجل النشاط. |
| 33 | `wait-for-app-foreground` | `471dcdcb96c78074aa0a4c5107795b9ddeb22f6dd72128f95962f4b5bd65536a` | شاشة ترحيب BIL مرئية؛ لا يظهر تنبيه ANR في سجل هذا التشغيل. |
| 34 | `wait-for-app-foreground` | `a07427f1654a238f237cb10ab7e73afd348005610972119da92d8855fcf54b6d` | شاشة ترحيب BIL مرئية؛ لا يظهر تنبيه ANR في سجل هذا التشغيل. |
| 35 | `wait-for-app-foreground` | `28e4bb50ed917dc22aa7bc8fa7bcbb7c878ce25940e9aa862a014109737f872c` | شاشة ترحيب BIL مرئية؛ سطر النشاط الأمامي موجود في سجل النشاط. |
| 36 | `wait-for-app-foreground` | `28e4bb50ed917dc22aa7bc8fa7bcbb7c878ce25940e9aa862a014109737f872c` | شاشة ترحيب BIL مرئية؛ سطر النشاط الأمامي موجود في سجل النشاط. |

محاولات المشغّل السابقة موثقة كما هي: [38664635568](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38664635568) تعطيل Wi‑Fi غير المسموح؛ [38666730495](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38666730495) حالة ADB غير مستقرة؛ [38668236678](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38668236678) مسح قبل التثبيت. CodeQL السابق على `7485c7cc` في [38671525638](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38671525638) منفصل عن أحدث تشغيل [38673538483](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38673538483) على `533a68d9`. لا أنسب نتيجة إلى SHA آخر.

عدد ملفات `.github/workflows/*.yml` الآن **60**: الـ58 المفصلة في التقرير السابق، مع CodeQL ومصفوفة Android المعزولة. `actionlint` اجتاز 60/60. `zizmor` لم يبلغ عن نتائج أمنية، لكنه أظهر تحذير تحليل لملف iOS واحد؛ لذلك لا أصنف تغطيته الكاملة على أنها نظيفة بلا قيد. فحص Gitleaks للتغييرات المرحلية كان صفرًا. مسح تاريخ Git الكامل على المصدر السابق سجل 16,733 مطابقة heuristic (16,719 عامة، 12 في نمط مفتاح خاص ضمن كود/اختبارات، ومطابقة Sumo واحدة عابرة لحقلي CSV)؛ لم تُمسح هذه النتائج ولا أصف تاريخ الأسرار بأنه نظيف. يبقى تنبيه GitHub المفتوح لمفتاح Google API بصلاحية غير معلومة.

الشاملة السابقة تظل **9,843/9,843** وflutter analyze بلا أخطاء على SHA التطبيق ef4b9f19 وبصمة مدخلات Flutter الموثقة؛ لم تُعد على SHA أحدث لأن مدخلات Flutter لم تتغير. ملفات PNG التشخيصية الـ44 تحت test/**/failures/ محفوظة خارج commits. كوميتا حارس الاختبار 533a68d9 وaca3afbd غير موقعين حسب حالة Git N؛ لا يوجد AAB 33 أو IPA 36 موقّع أو جهاز حقيقي أو اختبار متجر. لم تتغير إعدادات Play أو ASC أو Production ولم يُرسل Appeal.

## إجابات المالك المباشرة

1. **هل الشاملة نجحت؟** نعم على مصدر التطبيق `ef4b9f19f491426ba8663ba1a9d76f9af6fe0c67` وبصمة مدخلات `80087ad7b2ef76192e9f22c5be0af34edc53dfc2139eb1b63ad81eaf7416614e`: 9,843/9,843، و1,356 ملف اختبار، بلا فشل أو خطأ أو تخطٍّ، والتحليل الكامل بلا ملاحظات. لم تُعد الشاملة لأن هذا التدقيق لم يغير `lib/` أو `test/` أو migrations أو Flutter dependencies. هذا لا يعني أن كامل مجلد Git الحالي له SHA الاختبار نفسه.
2. **هل اختُبر حساب المراجع على نسخة فعلية؟** لا. لم يُختبر أي حساب مراجعة على AAB 33 أو IPA 36. لم تُنشأ جلسات مستخدمين، ولم تُستخدم بيانات اعتماد متجر.
3. **هل المحتوى المدفوع وAI متاحان للمراجع دون شراء؟** لم يثبت ذلك على binary متجر. اختبارات المصدر لا تكفي لإجابة قبول المراجع، ولا أصف وصول Premium أو AI بأنه ناجح قبل اختبار الحساب والحزمة الفعليين.
4. **هل شراء المستخدم العادي وRestore وBoost سليمة؟** عقود المصدر اجتازت الاختبارات الموجودة، لكن StoreKit/Play Sandbox لم يُشغّل على إصدار موقع هنا؛ لا توجد نتيجة شراء/استعادة/Refund حقيقية أو إيصال متجر في هذا التدقيق.
5. **هل نبقي الإدارة؟** نعم. فصل المشرف عن الاشتراك والرصيد مناسب. مراجعتها يجب أن تكون بدور محدود وببيانات اصطناعية في بيئة معزولة، ولا تُعطى صلاحيات المالك أو بيانات المستخدمين الحقيقيين. لم تُختبر جلسة Admin حقيقية في هذا التدقيق.
6. **هل يرسل Appeal الآن؟** لا. المطلوب قبل قرار المالك: إغلاق مراجعات Google الخمسة على build 33 محدد، AAB مصحح قابل للتثبيت، اختبار وصول المراجع على AAB نفسه، والتحقق من حالة الاستئناف السابق قبل استهلاك المحاولة. لم أفتح Console أو أرسل Appeal.
7. **ما الذي يحتاج متجرًا أو جهازًا أو قرارًا؟** يحتاج Google Cloud مالكًا لمراجعة قيود مفتاح API المفتوح؛ يحتاج Google Play AAB 33 وحساب مراجعة وقراءة Console؛ يحتاج Apple IPA 36 ومراجعة SDK/Privacy Manifest/ASC؛ ويحتاج كلاهما أجهزة فعلية وStore Sandbox. لم تتغير إعدادات Console أو ASC، ولم يُرفع بناء أو تُنشر خدمة.

## المصدر والتغييرات

| البند | النتيجة |
|---|---|
| الفرع | `integration/bil-qa-media-policy-20261011` فقط |
| الأب المتحقق قبل التغيير | `eb7d095aeb09c76770a3a2173cee2771d06153ff`، مطابق للبعيد قبل الدفع |
| commit التغييرات الهندسية | `234b75d1e8b449d17701663695afeffdfca1f991`، دُفع fast-forward بلا force إلى الفرع نفسه |
| نطاق commit | 31 ملفًا: 25 Workflow قائمًا محدثًا، CodeQL workflow، Dependabot config، قفزة اعتماد Cloudflare، وسجلا تجهيز Android 33/iOS 36. لم يتغير `lib/`, `test/`, `supabase/migrations/`, `main`, الأسعار أو Trial. |
| العمل غير الملتزم المحفوظ | 44 ملف PNG تشخيصي من `test/**/failures/` بقيت خارج الكوميت؛ لم تحذف أو تعدّل Goldens. |
| اكتمال الالتزام | Git LFS `post-commit` لم يعمل بسبب خطأ fork في Git Bash؛ أُكمل يدويًا، ثم `git lfs fsck` نجح. |

التقرير التفصيلي للـ58 Workflow السابقة موجود في [الشهادة السابقة](BIL_20261014_GITHUB_COMPLETE_RELEASE_CERTIFICATION_AR.md). أصبح العدد 60 بإضافة CodeQL ومصفوفة Android المعزولة، ومرّت الملفات الـ60 على `actionlint`.

## نتائج المصدر وGitHub

| الفحص | النتيجة الدقيقة |
|---|---|
| Flutter full suite / analyze | PASS على SHA التطبيق `ef4b9f19f491426ba8663ba1a9d76f9af6fe0c67`; 9,843 نجاحًا / 1,356 ملفًا / 0 فشل وخطأ وتخطٍّ؛ analyze بلا مشكلات. مصدر النتيجة وبصمتها محفوظان في تقرير الإغلاق السابق. |
| GitHub focused QA | [38653187976](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38653187976) PASS على SHA التطبيق `ef4...`; ليس اختبار جهاز أو متجر. |
| Instant Experience | [38659886270](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38659886270) PASS على commit audit `234b75d...`. |
| CodeQL | Workflow 38675377540 على aca3afbd اكتمل بنجاح في اللغات الخمس. واجهة Code Scanning على الفرع تعرض 47 تنبيهًا مفتوحًا: 1 عالي (error)، 45 warning، 1 note؛ منها alert 5 من js/redos في web/drift_worker.dart.js:13335، وخريطة المصدر تربطه بـ stack_trace 1.12.1 في trace.dart:55. المصدر الحالي لـ stack_trace 1.12.2 ما زال يتضمن التعبير نفسه؛ لا يوجد إصلاح upstream مثبت. لم أعدّل bundle مولّدًا ولا أصف الفحص بأنه نظيف. [Alert 5](https://github.com/bilhealth-admin/Body-Intelligence/security/code-scanning/5)؛ [المصدر الرسمي للحزمة](https://github.com/dart-lang/tools/blob/main/pkgs/stack_trace/lib/src/trace.dart#L53-L62). |
| iOS HealthKit simulator | [38662883181](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38662883181) على macOS 26 اكتمل بدليل إطار/تنقل فقط (`EVIDENCE_ONLY`)، دون نافذة إذن HealthKit أو جهاز فعلي. تشغيل macOS 15 السابق [38656374929](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38656374929) تعطل في compile dependency لغياب `NWPath.isUltraConstrained` من SDK القديم. |
| Workflow lint | `actionlint` 1.7.12، 60/60، exit 0. `zizmor` 1.30.1، 0 نتائج، exit 0؛ ظهر تحذير parser غير قاتل لملف iOS، لذلك لم تُعلن نظافة التحليل الكامل. |
| Cloudflare | `npm run check` PASS؛ TypeScript و5 staging-isolation tests. `npm test` PASS؛ 5 ملفات و49 اختبارًا. `npm ci` PASS. |
| Dependencies/security | OSV post-fix 0؛ Grype 0؛ Trivy 0 vulnerability/misconfiguration/secret findings، وواحد LOW MIT license notice (`jose`). |
| SBOM | Syft: 540 artifact entries؛ CycloneDX: 656 components؛ SPDX: 541 packages. CycloneDX SHA-256 `8F530E3C6B61287744BE94DAA539EDE3D8E7262B875B6CB41954A7510AE00A2C`. جرد مصدر لا شهادة artifact. |
| Gitleaks | Staged diff 0؛ Actions log 0؛ GitHub artifact 0. Broad checkout scan فيه 17,254 heuristic matches؛ 8 في ملفات Workflow المعدلة كلها على أسطر خارج التغييرات. لا يُعد هذا clean-history assertion. |
| Semgrep | BLOCKED محليًا: `semgrep-core` فشل في rule validation على Windows/Python 3.14 ولم ينتج تقريرًا صالحًا؛ لم يُحسب PASS. |

وقت دفع commit 234b75d1 لم تكن هناك GitHub Actions runs نشطة على الفرع. لم ينتج ذلك الدفع إلا تشغيلين: Instant Experience وCodeQL. لا يُشغّل دفع توثيق الإغلاق توقيعًا أو نشرًا أو تغيير مصدر أو خدمة.

## أمان GitHub ومفتاح Firebase

- إعدادات المستودع العام: Secret Scanning مفعّل، Push Protection مفعّل، Dependabot security updates مفعّل، وعدد Dependabot alerts = 0. تحقق صلاحية الأسرار وأنماط المزود غير القياسية معطلان.
- يوجد Secret Scanning alert مفتوح واحد نوعه `google_api_key` مع `publicly_leaked=true` و`validity=unknown` في `android/app/google-services.json`. لم يظهر المفتاح في التقرير. يلزم مالك Google Cloud مراجعة قيود APIs، خصوصًا استبعاد APIs غير اللازمة، ثم يقرر إن كان يحتاج تدويرًا.
- Dependabot يراقب 6 ecosystems؛ حد طلبات ترقية النسخ العادية `0` وcooldown 7 أيام. إعداد cooldown للتحديثات العادية لا يؤخر Security Updates. راجع [توثيق GitHub للتبريد](https://docs.github.com/en/code-security/how-tos/secure-your-dependencies/optimizing-pr-creation-version-updates).
- لا توجد Rulesets أو حماية للفرع integration. لم أضفها كي لا أغيّر صلاحيات الدمج أو أحبس المالك في Required Checks غير متحققة.
- `verify.yml` أزيل منه إدخال `github.base_ref` داخل shell source. أُغلقت صلاحية `contents: write` على مستوى Job الكاتب فقط، وأضيفت قيود عدم حفظ اعتماد checkout في مسارات القراءة. تمت مراجعة 25 Workflow مع إبقاء المسارات التاريخية والأهداف القديمة دون تشغيل عشوائي.
- لم يُفعّل GitHub Code Quality. Workflow CodeQL اكتمل على SHA aca3afbd، لكن فيه 47 تنبيهًا مفتوحًا، منها تنبيه ReDoS عالي الخطورة موضح أعلاه.

## Android 33 وiOS 36

| المنصة | المصدر/CI | Emulator/جهاز | artifact/Store | القرار |
|---|---|---|---|---|
| Android 33 | تشغيل 38675377553 ناجح على SHA aca3afbd بعد المحاولة الثانية، 6/6 APIs مع Welcome وزر تفاعلي؛ يثبت الإقلاع فقط ولا يعيد نسبة نتيجة Flutter السابقة. | لا جهاز فعلي ولا حساب Play على حزمة. | لا AAB موقع ولا merged-manifest نهائي أو Play build جديد | غير جاهز؛ خمسة ملفات Google غير مغلقة |
| iOS 36 | Flutter source pass على SHA التطبيق ef4...؛ HealthKit 38662883181 دليل محاكي جزئي؛ CodeQL 38675377540 نجح في اللغات الخمس | لا iPhone/iPad حقيقي ولا مصفوفة VoiceOver/Dynamic Type | لا IPA موقع، لا TestFlight، لا App Store Connect تحقق | غير جاهز؛ manifest غير مكتمل |

تفاصيل كل منصة في [جاهزية Android 33](BIL_ANDROID_33_RELEASE_CANDIDATE_READINESS_20261015_AR.md) و[جاهزية iOS 36](BIL_IOS_36_RELEASE_CANDIDATE_READINESS_20261015_AR.md). سجلات التهيئة والتحليلات السابقة: [Google](BIL_20261014_GOOGLE_APPEAL_EVIDENCE_AR.md) و[Apple](BIL_20261014_APPLE_STORE_PRIVACY_METADATA_AUDIT_AR.md).

## قرار المتاجر والسياسة

الإدارة تبقى. لا حاجة إلى حذفها أو نقلها للبريد؛ المطلوب فصل الدور المالي عن المشرف واستخدام بيانات اختبار اصطناعية للمراجعة. لا يوجد دليل أن حساب المراجعة الحقيقي اختبر Premium/AI على إصدار متجر.

لا ترسل Google Appeal الآن. بعد إثبات الإصلاح على AAB 33 وحساب المراجع، راجع حالة المحاولة السابقة؛ إشعار التعليق قد يقيّد فرص التقديم. [إرشادات App Access من Google Play](https://support.google.com/googleplay/android-developer/answer/15748846) و[سياسات المطور](https://play.google.com/about/developer-content-policy/) تحددان المتطلبات، لكن القبول يتطلب الحزمة والحساب الفعليين.

لا توجد خطوة إرسال إلى Apple الآن. أنشئ IPA 36 بعد موافقة المالك على التوقيع، ثم افحص App Privacy وSDKs/Privacy Manifest والـentitlements والحساب على الحزمة. راجع [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) و[إرشادات اكتمال المراجعة](https://developer.apple.com/cn/help/app-review/before-submitting-for-review/complete-review/).

لم يتم تغيير Console أو ASC أو RLS أو Production، ولم تُشغّل عملية شراء أو منحة أو حذف أو رسالة حقيقية. لم تُرسل مراسلة أو Appeal.

\n