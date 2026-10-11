# BIL — استرداد ودمج First Use والاحتفال بأدلة التنفيذ

الفرع الوحيد: `integration/bil-qa-media-policy-20261011`.
HEAD المصدر النهائي المختبَر: `62254928bcf33922d0659782adccece0e0228b6e`. بدأ الاسترداد من HEAD الفعلي `88721616e1d4e7d579c9963e7141e460c4978c08` بعد التحقق من GitHub وCI والمجلدات المحلية. كوميت التوثيق اللاحق يضيف الأدلة فقط ولا يغيّر مدخلات التطبيق والاختبارات.

## الجواب الحاسم

**الملفات العشرة الأصلية موجودة فعلًا واستُردّت من bytes الأصلية، وليست تنفيذًا مكتوبًا من الذاكرة.** تطابق كل ملف بين Worktree الأصلي والنسخة المحفوظة والإيصال. لكن وصف التنفيذ القديم بأنه «مطابق تمامًا» لا تؤيده المقارنة: الأصل ربط زر الإضافة، لكنه تجاوز قائمة Log Food، ووضع بعض الإرشادات inline، وSkip داخل البطاقة واحتفالًا مركزيًا. احتفظت بالأصل ثم أصلحت هذه الفروق في الدمج؛ لا أقدّم شهادة تطابق بكسلي أو جهاز فعلي.

استُخدم الفيديو نفسه الذي قرأه QA: حجم MP4 هو 59,053,938 bytes، وبصمته `e36c4c9fee9768315ca634b70b826cfdaf2ba8ddbfd7bb806f1d37c0a27b428c`. ZIP المحلي مختلف التغليف عن ZIP تقرير QA، لكن الفيديو داخله مطابق byte-for-byte. شاهدت لقطات 3/6/8/20/22/40/41.5/56 ثانية، وليست صورًا مولّدة أو وصفًا بديلًا للفيديو. [معرض المرجع](evidence/20261011-first-use-integrated/reference/reference-contact-sheet.png).

## الملفات العشرة المستردة وبصماتها

المصدر المحلي: `G:/BIL_Project/worktrees/bil-test-only-20261010`؛ الحفظ: `G:/BIL_Project/qa-preserved/first-use-before-final-closure-20261011`.
قاعدة الدمج: `944973ed3556ccb9b8cd8a09b451562aea3cf652`.
SHA256 للـpatch: `8364714ef80cd8ef8bc4af710cb339fb6692341d609f4cb232caf98020599205`؛ الاسم الفعلي المسترد `tracked-first-use.patch`.

| الملف | SHA256 الأصلي الكامل | الدليل |
|---|---|---|
| `lib/app/router/responsive_app_shell.dart` | `bd5c6fd1e9924d584e7f6b69f28c4a4844178bed497f70cbbac8a5da3341c71b` | [bytes الأصلية](evidence/20261011-first-use-integrated/recovered-original/lib/app/router/responsive_app_shell.dart.txt) |
| `lib/features/daily_log/food_log_actions.dart` | `d5c824ec93689ef0d3ffb4086210224e1b364c91a753f795658bb994d6e7082f` | [bytes الأصلية](evidence/20261011-first-use-integrated/recovered-original/lib/features/daily_log/food_log_actions.dart.txt) |
| `lib/features/daily_log/food_log_page.dart` | `44f6b5432360caeaa6e115f584825b68f22ebbf2ff4bbafdd5d152b9808fff4e` | [bytes الأصلية](evidence/20261011-first-use-integrated/recovered-original/lib/features/daily_log/food_log_page.dart.txt) |
| `lib/features/dashboard/widgets/dashboard_first_use_experience.dart` | `25435fc2b80e3f9e81957206c35db521905baef7bac23f206a4a0d4ad92fe25d` | [bytes الأصلية](evidence/20261011-first-use-integrated/recovered-original/lib/features/dashboard/widgets/dashboard_first_use_experience.dart.txt) |
| `lib/features/dashboard/widgets/first_meal_celebration.dart` | `985c46d31d01de74fcda040f702e270c2c7653d5c8df56b9f1c21e1e1f2545ff` | [bytes الأصلية](evidence/20261011-first-use-integrated/recovered-original/lib/features/dashboard/widgets/first_meal_celebration.dart.txt) |
| `lib/features/dashboard/widgets/first_use_context_coachmark.dart` | `1c1f4a7bf47150835a8afe094133edf51d177232044ffa33ea39192db131a263` | [bytes الأصلية](evidence/20261011-first-use-integrated/recovered-original/lib/features/dashboard/widgets/first_use_context_coachmark.dart.txt) |
| `lib/features/dashboard/widgets/first_use_glass_surface.dart` | `a22d05f58ab530607e7b8ebf82059bfe8694c082ac29e3ff27338190031dbafb` | [bytes الأصلية](evidence/20261011-first-use-integrated/recovered-original/lib/features/dashboard/widgets/first_use_glass_surface.dart.txt) |
| `lib/shared/widgets/bil_reference_bottom_bar.dart` | `2a399e040b44b24338eb0002b65ba139d667c40243738af4b2f45dffa9e8d4a5` | [bytes الأصلية](evidence/20261011-first-use-integrated/recovered-original/lib/shared/widgets/bil_reference_bottom_bar.dart.txt) |
| `lib/shared/widgets/first_use_guide_anchor.dart` | `6085b9690a5c2251e8a1089613e96ad4bd23c305b422ee0f44f2c753b12387fd` | [bytes الأصلية](evidence/20261011-first-use-integrated/recovered-original/lib/shared/widgets/first_use_guide_anchor.dart.txt) |
| `test/features/dashboard/first_use_reference_journey_test.dart` | `5f7d615d8021b4b4d04e0f51870501d9e0397b14fdb1292861a9b394d6c43d78` | [bytes الأصلية](evidence/20261011-first-use-integrated/recovered-original/test/features/dashboard/first_use_reference_journey_test.dart.txt) |

[إيصال الاسترداد والدمج](evidence/20261011-first-use-integrated/recovery-provenance.json) · [الـpatch الأصلي](evidence/20261011-first-use-integrated/recovered-original/tracked-first-use.patch) · [بصمات ملفات التنفيذ النهائي، منفصلة عن الأصل](evidence/20261011-first-use-integrated/final-changed-file-sha256.json).

## الدمج وحفظ إصلاحات QA

أنشأت Worktree معزولًا على G:؛ بقي المستودع الرئيسي المتسخ وWorktree الأصلي والنسخة المحفوظة دون مسح أو استبدال. جرى دمج الملفات الثمانية المتتبعة باستخدام Base/Current/Recovered مع `git merge-file`، واستُرد الملفان الجديدان ببصمتيهما. **صفر تعارضات نصية**. كوميت الاسترداد المستقل `19c3d66560f28d5d118083eb436492c126e995b8` يثبت الأصل قبل التصحيحات، ثم `786658391a2a9e3dc576364b8b828b54d348ea31` لربط الرحلة، ثم HEAD النهائي أعلاه لإغلاق ملاحظات التحليل.

لم تُستبدل ملفات Food Log كاملة فوق أحدث QA: بقيت مراجعة صورة المعرض عبر `showBilMediaReviewSheet<XFile>`، و`FileImage(File(image.path))`، وإيقاف الإلغاء/الاختيار الفارغ، و`reviewed.single` قبل التحليل؛ وبقيت أيقونات Cupertino على iOS وoutlined على Android والواردات اللازمة.

تحققت من أن إصلاحات Android32/iOS35 وQA الأصلية وFull السابق وCI الوسائط الناجح كلها أسلاف HEAD الحالي. Home الإنتاجي والساعة والـCommerce وSupabase وAndroid/iOS والأصول والاعتمادات لم تتغير من HEAD الاستلام. تغييرات شريط الهاتف ربط غير مرئي للهدف فقط؛ خمس الأيقونات وشكلها محفوظة، وGolden الساعة وHome/الآيباد أُعيد فحصها دون تحديث مراجعها. [فحص الحفظ والأنساب](evidence/20261011-first-use-integrated/preservation-and-final-validation.json)، [تطابق الملفات المحلية العشرة بعد الدمج](evidence/20261011-first-use-integrated/original-final-byte-check.json).

## المقارنة البصرية والتنفيذ خطوة بخطوة

الصور التالية إخراج Flutter جديد من الكود المدمج مع الخطوط العربية الحقيقية. Food Log والسجل وHome صفحات الإنتاج الفعلية، مع قاعدة SQLite اختبار محلية وطعام موسوم TEST. خلفية Home المبسطة في اختبار الرحلة موسومة TEST؛ **ليست دليل تصميم Home**. صور Home الحقيقي المستقلة هي الدليل المقابل للرئيسية.

| توقيت المرجع | التنفيذ المدمج والدليل الحالي | الحكم المحدد |
|---|---|---|
| 3s: زر + | [Home الحقيقي والهاتف](evidence/20261011-first-use-integrated/flutter/00-real-home-ar-390-guide.png)، [الآيباد](evidence/20261011-first-use-integrated/flutter/00-real-home-ar-1032-guide.png) | الفقاعة تتبع زر الإضافة الحقيقي؛ لا تحرك محتوى Home. Skip تحت الزجاج. |
| 6s: Log Food | [القائمة الفعلية](evidence/20261011-first-use-integrated/flutter/00-menu-ar.png) | الضغط على + أو CTA يفتح القائمة، وتُربط الفقاعة بعنصر Log Food الفعلي؛ لا انتقال يتجاوز هذه الخطوة. |
| 8s: البحث | [حقل البحث الفعلي](evidence/20261011-first-use-integrated/flutter/01-search-ar.png) | يتبع الهدف الحقيقي ويظل قابلًا للكتابة والتخطي. حيز لوحة المفاتيح اختُبر بـ260px؛ ليس تسجيل لوحة مفاتيح iOS فعلية. |
| 20s: اختيار الطعام | [زر النتيجة الحقيقي](evidence/20261011-first-use-integrated/flutter/02-choose-ar.png) | يشير إلى + القابل للنقر في BIL، بدل الإشارة إلى اسم غير تفاعلي. |
| 22s: الكمية | [حقل الكمية](evidence/20261011-first-use-integrated/flutter/03-quantity-ar.png) | نافذة الحصة الموجودة في BIL محفوظة؛ ليست نسخة شاشة Add Food الخارجية. الكمية قابلة للتحرير، وSkip لا يحفظ ولا يغلق الحقل. |
| 40s: الحفظ | [زر Add الحقيقي](evidence/20261011-first-use-integrated/flutter/04-ready-ar.png) | الفقاعة تتبع زر التأكيد الموجود؛ لا زر وهمي. تكرار الاستدعاء الفوري لا يغلق صفحة Food Log ولا يسجل عنصرًا ثانيًا. |
| 41–42s: النجاح | [احتفال عند صف الطعام](evidence/20261011-first-use-integrated/flutter/05-celebration-ar.png)، [إرشاد الأدوات بعده](evidence/20261011-first-use-integrated/flutter/06-success-ar.png) | علامة نجاح ذهبية وزجاج و120 قطعة/شريط مرسوم، بعد commit حقيقي فقط؛ مرة واحدة وغير حاجب للنقرات. |
| 56s: الأيام | [صف الأيام الفعلي في السجل](evidence/20261011-first-use-integrated/flutter/06-streak-ar.png) | **اختلاف متعمد للحفاظ على Home:** الرئيسية المعتمدة لا تضم صف الأيام الموجود في المرجع، لذلك الإرشاد عند محدد الأيام الحقيقي في Daily Log. لم أضف صفًا أو علامات تسجيل مصطنعة إلى Home. |

[Home الهاتف بعد Skip](evidence/20261011-first-use-integrated/flutter/00-real-home-ar-390-skipped.png) · [Home الآيباد بعد Skip](evidence/20261011-first-use-integrated/flutter/00-real-home-ar-1032-skipped.png) · [صور الرحلة الإنجليزية](evidence/20261011-first-use-integrated/flutter/05-celebration-en.png) · [معرض الأدلة](evidence/20261011-first-use-integrated/review.html).

السطح زجاجي فعلي بـBackdropFilter وتدرج وانعكاسات، مع حركة دخول وانتقال واحتفال؛ الخلفية الزجاجية نفسها ليست فيديو متحركًا باستمرار. تقليل الحركة يزيل القصاصات والحركة، ويعرض نجاحًا ثابتًا محدود المدة.

## الفحص الفعلي والإصلاحات

Flutter **3.44.6 / Dart 3.12.2**. لم تُشغّل Full8.

| المجموعة | PASS | FAIL المعتمد المتبقي | SKIP |
|---|---:|---:|---:|
| رحلة/إرشادات/احتفال/حفظ First Use النهائية — 8 ملفات | 56 | 0 | 0 |
| التكامل المتأثر — 16 ملفًا | 117 | 0 | 0 |
| الإجمالي المحلي Flutter | **173** | **0** | **0** |
| أدوات source-policy Python، مستقلة عن Flutter | 3 | 0 | 0 |

التكامل نفّذ 116 PASS وفشل اختبار عقد مصدر واحد يعتمد حرفيًا صيغة الاستدعاء القديمة. حدّثت التحقق ليطلب origin وcallbacks الإرشاد صراحةً مع استمرار Assertions الكاميرا/المراجعة، وأعدت الحالة منفردة: 1 PASS. لم أعد 116 حالة ناجحة بلا سبب. بعد تصحيح Analyze أُعيدت First Use كاملة: 56/56؛ احتُفظ بنتائج التكامل غير المتأثرة مع SHA تنفيذها الأصلي وسبب الاحتفاظ في سجل الحفظ، ولا تُنسب جولة قديمة زورًا إلى HEAD جديد.

الفحص يشمل ar/en و320/390/430، و1×/1.8×/2×، و1032×1376 للآيباد، والكمية 80g، وإلغاء الحصة، وSkip في القائمة والبحث والاختيار والكمية والحفظ، والحفظ الفاشل بواسطة SQLite trigger حقيقي، وA→B→A أثناء فتح الكمية، والحفظ مرة واحدة والاحتفال مرة واحدة، وRTL والنقرات مع تقليل الحركة. fr/es/tr اختُبرت فيها CTA والقائمة والترجمة والتخطي. لا شهادة لكل لغات التطبيق: copy الرحلة مؤلف لخمس لغات، واللغات الأخرى تستخدم fallback الإنجليزية.

أصلحت خروج بطاقة الآيباد وSkip من الشاشة بقياس الهدف الفعلي وتقييد موضع الفقاعة. بقي Rect محتوى Home ثابتًا قبل Skip وبعده. أوقفت بطاقة الاختيار القديمة عند فتح نافذة الكمية، وصححت اتجاه المؤشر إلى زر النتيجة، وجعلت Skip خارج الزجاج واضح التباين. حُفظت إصلاحات Controller وارتفاع أزرار Food Log الموجودة داخل العمل الأصلي. رُبط حفظ الحصة بالمستودعات والمالك الذي فتحها، مع منع التأكيد المتكرر واحتفال حساب آخر. لم تتغير معاملة الحفظ الذرية أو قواعد milestone الأساسية.

فشل helper الجديد أولًا في إغلاق Drift بسبب timers عند التخلص التلقائي من الشجرة؛ أصلحت تفكيك fixture وضخ الإغلاق قبل فحص invariants. لا تعطيل Assertions. احتُفظ أيضًا بخطأ compile الخاص بتحويل num إلى double أثناء تطوير موضع الاحتفال، وبخطأ الآيباد وسجلات إصلاحهما. [النتائج التفصيلية](evidence/20261011-first-use-integrated/local-test-results.json)، [الاعتماد الفعلي](evidence/20261011-first-use-integrated/effective-local-results.json)، [First Use بعد إصلاح CI](evidence/20261011-first-use-integrated/logs/first-use-post-ci-fix.jsonl)، [التكامل الأصلي](evidence/20261011-first-use-integrated/logs/affected-integration.jsonl)، [العقد المعاد](evidence/20261011-first-use-integrated/logs/camera-contract-fixed.jsonl).

## GitHub Actions والتحليل

- [CI النهائي **38119262120 — SUCCESS**](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38119262120) على HEAD `62254928bcf33922d0659782adccece0e0228b6e`. التنسيق ناجح، **Flutter Analyze الكامل: No issues found**، وsource-policy ناجح.
- مرحلة First Use والتكامل الإضافي داخل CI: **122 PASS / 0 FAIL / 0 SKIP** وفق JSON الفعلي؛ الحالات الثلاث السابقة للمجتمع نجحت منفردة، ثم Community Image **12/12**، ثم Focused media/account/review **80/80**. لا تُجمع المراحل المتداخلة كاختبارات فريدة.
- [CI الأول 38118620558 — FAILED](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38118620558): توقف قبل الاختبارات عند 10 ملاحظات Analyze: protected `setState` داخل extension، وترتيب child، وأقواس if، ووارد test غير مستعمل. استُخدمت `_updateState` الموجودة داخل State وصُححت الصياغة؛ لم تُخفض شدة التحليل أو تُضف ignore. بوابة التجميع منعت إعلان نجاح زائف.
- [CI السابق لـQA **38115649502 — SUCCESS**](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38115649502) على `aa7f73d8` محفوظ كسلف للمصدر الحالي؛ لا يُقدَّم كفحص First Use الجديد.
- محليًا نجح `dart analyze` لملف Food Log النهائي بلا تشخيصات، وstrict format للملفات المعدلة. محاولات التحليل الشامل Windows التي استُبدلت أثناء تغير المصدر لا تُنسب إلى نجاح نهائي؛ الاعتماد الشامل للتحليل هو CI أعلاه.

[سجل CI الأخضر](evidence/20261011-first-use-integrated/logs/ci-38119262120.log) · [نتائج JSON وأسماء الحالات](evidence/20261011-first-use-integrated/ci-final-results.json) · [JSON First Use](evidence/20261011-first-use-integrated/logs/ci-first-use-green.jsonl) · [حدود فحص المصدر](evidence/20261011-first-use-integrated/source-checks.json).

صور مستقلة أعاد CI إنتاجها من HEAD نفسه: [Home الهاتف](evidence/20261011-first-use-integrated/ci-flutter/00-real-home-ar-390-guide.png)، [Home الآيباد](evidence/20261011-first-use-integrated/ci-flutter/00-real-home-ar-1032-guide.png)، [الاحتفال](evidence/20261011-first-use-integrated/ci-flutter/05-celebration-ar.png)، [الأيام](evidence/20261011-first-use-integrated/ci-flutter/06-streak-ar.png). بقية صور CI في Artifact `bil-first-use-recovery-62254928bcf33922d0659782adccece0e0228b6e` على صفحة التشغيل.

## النواقص وحدود المطابقة

- نقل صف أيام مطابق للفيديو إلى Home أو تغيير شاشة حصة BIL إلى شاشة Add Food الخارجية يحتاج قرار تصميم جديد؛ لم أفعل ذلك ضمن قيد حماية Home وأحدث Food Log. التوجيه إلى عناصر BIL الفعلية مثبت، **لكن التطابق البكسلي الكامل مع تطبيق الفيديو غير معتمد**.
- لا جهاز iPhone/Android/iPad فعلي، ولا VoiceOver/TalkBack أو كيبورد نظام مصوّر أو haptics/audio أو قياس FPS على جهاز. الفيديو المرجعي يبدأ من Today ولا يعرض إنشاء الحساب؛ لا ادعاء اختبار التسجيل الشبكي أو مطابقته.
- اختبار حفظ/حسابات محلي بـSQLite حقيقي وProviders اختبار؛ ليس اختبارًا حيًا لـSupabase أو كاميرا أو AI. البث/الصحة/المتاجر ليست نطاق هذا الدمج.
- نجاح 8,528 السابق يخص QA السابق؛ لا يُعاد نسبه إلى First Use المدمج. Full8 مؤجل صراحةً وفق الأمر الحالي.

الأصل المحلي والنسخة المحفوظة باقيان دون تغيير. لا main أو Force Push أو دمج main، ولا تغيير Production/Supabase أو أسعار/Trial، ولا رفع نسخة متجر أو نشر.
