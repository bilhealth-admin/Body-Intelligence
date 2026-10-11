# BIL 2026 — الإغلاق المحلي النهائي للاختبارات — 2026-10-11

الفرع المستهدف: `qa/bil-quality-ux-integration-20261009`، [PR #11](https://github.com/bilhealth-admin/Body-Intelligence/pull/11).

HEAD الكود المختبَر: `c1f1f47a627169fb692763d3a96dc81afcdc7b17`. بدأت الجولة من `06c365022f20e0f0c5d6e901b19a8efb1419b81f` دون رجوع أو إسقاط إصلاح. كوميت التسليم اللاحق يضيف الأدلة فقط، وترد بصمته في تعليق PR النهائي.

Flutter **3.44.6**، Dart **3.12.2**. جميع المجموعات الثماني انتهت بأكواد خروج 0 وحدث `done.success=true`، وحمّلت كل مجموعة ملفاتها الـ1253. استُخدمت ثمانية Worktrees منفصلة على نفس HEAD، بحد عمليتين متزامنتين و`--concurrency=1` لكل مجموعة.

## النتائج

| المرحلة | PASS | FAIL | SKIP |
|---|---:|---:|---:|
| arabic | 84 | 0 | 0 |
| p0 | 203 | 0 | 0 |
| focused | 272 | 0 | 0 |
| broad | 255 | 0 | 0 |
| Full 0–7 | 8528 | 0 | 3 |

Source: تنسيق 195 ملف Dart ناجح، والتحليل الكامل بلا أخطاء. اختبارات أداة التدرّج: 11/11 PASS. [Source log](logs/source-analyze.log)، [تفاصيل مراحل الاختبار](records/prior-stage-counts.json)، [بوابات الكود والبصمة](records/gates.json).

بعد إصلاح تجهيز الصورة أُعيدت مجموعة Vision العربية ومجموعة كمية Vision؛ احتُفظ فقط بنتائج المجموعات غير المتأثرة من `c2844272` بعد إثبات أن ملفاتها وكود التطبيق والأصول والاعتمادات لم تتغير. تحمل كل نتيجة محتفظ بها SHA التنفيذ القديم صراحةً في `gates.json`. Full كله نُفِّذ فعليًا على HEAD أعلاه؛ لا تُنسب جولة قديمة إليه.

| Full shard | PASS | FAIL | SKIP | Exit | السجل والتفاصيل |
|---|---:|---:|---:|---:|---|
| 0 | 1031 | 0 | 0 | 0 | [log](logs/full-shard-0.jsonl) · [cases/images](shards/0/result.json) |
| 1 | 1248 | 0 | 1 | 0 | [log](logs/full-shard-1.jsonl) · [cases/images](shards/1/result.json) |
| 2 | 963 | 0 | 0 | 0 | [log](logs/full-shard-2.jsonl) · [cases/images](shards/2/result.json) |
| 3 | 1353 | 0 | 1 | 0 | [log](logs/full-shard-3.jsonl) · [cases/images](shards/3/result.json) |
| 4 | 858 | 0 | 0 | 0 | [log](logs/full-shard-4.jsonl) · [cases/images](shards/4/result.json) |
| 5 | 1168 | 0 | 1 | 0 | [log](logs/full-shard-5.jsonl) · [cases/images](shards/5/result.json) |
| 6 | 1043 | 0 | 0 | 0 | [log](logs/full-shard-6.jsonl) · [cases/images](shards/6/result.json) |
| 7 | 864 | 0 | 0 | 0 | [log](logs/full-shard-7.jsonl) · [cases/images](shards/7/result.json) |

جمع Full **8531** حالة، ونفّذ **8528** منها، منها **8528 PASS و0 FAIL و3 SKIP**. لا يشمل العدد أحداث تحميل الملفات أو setUp/tearDown المخفية، ولا تُجمع أعداد المراحل المتداخلة كاختبارات فريدة. مفاتيح الملف+الاسم الفريدة: 8528؛ توجد ثلاثة أسماء مشتركة لحالات مستقلة داخل الشارد نفسه (أسماء community، ونسختا pt وzh). لم يُسند مفتاح إلى شاردين. العدد المنفَّذ مبني على IDs وtestDone الفعلية، وليس إزالة الأسماء المتكررة.

## حالات التخطي

1. `visual evidence check is truthful and read-only`: يحتاج حزمة الاعتماد البصري المستقلة غير المتتبعة في Git. حزمة المضيف التاريخية تضم 177 سجلًا، و151 سجلًا يشير إلى بصمات أدلة تختلف عن QA الحالية. لم تُنسخ الموافقات القديمة أو تُحدَّث تلقائيًا. ما زال هذا المتطلب غير منفّذ/غير معتمد للواجهة الحالية. [الفحص](records/legacy-visual-truth-skip-inspection.json).
2. بثّ التمرين العام: SKIP ضمن Full بسبب opt-in. شُغّل منفردًا باستخدام `BIL_LIVE_WORKOUT_STREAM_CHECK=true` ونجح **1 PASS / 0 FAIL / 0 SKIP**. HEAD، Range 32 bytes، المحتوى `ftyp`، وربط الكيان اختُبرت عبر عميل التطبيق الحقيقي دون مصادقة أو تنزيل فيديو كامل. [السجل](logs/live-workout-stream-opt-in.jsonl).
3. symlink: SKIP افتراضي على Windows CI. ثبت أن الجهاز يدعم الرابط الحقيقي، وشُغّلت الحالة الأصلية بـ`--run-skipped` ونجحت **1 PASS / 0 FAIL / 0 SKIP** دون تعديل شروط الرفض. [السجل](logs/windows-symlink-security-forced-case.jsonl).

إذن بعد الفحصين الإضافيين: **8530 حالة PASS فعلية، 0 FAIL، وحالة واحدة لم تُنفّذ**. نتائج Full الأصلية أعلاه تبقى 3 SKIP ولا يُعاد تصنيف سجلاتها. [أوامر ونتائج الفحصين](records/optional-check-results.json).

## الأخطاء والإصلاحات

- إصلاحا التطبيق السابقان في QA (إغلاق تكبير الصورة قبل فكّها، ورسالة Body Twin العربية ذات الوزن المتغيّر) محفوظان. فُحص الإغلاق مع تحميل معلّق حقيقي، وفُحصت رسالة Native/SQLite runtime عند 87.0 و92.8 و104.5 kg مع الحفاظ على الرقم ومنع النص الإنجليزي المتبقي.
- اختبار الإغلاق كان ينتظر `pumpAndSettle` بينما مؤشر التحميل يتحرك عمدًا. صُحّح توقيت الاختبار بإكمال دخول المسار، ثم الضغط على زر الإغلاق الحقيقي مع تحذيرات hit-test القاتلة مفعلة؛ بقيت Assertions الصورة الأصلية والتحميل والإغلاق كما هي. [الفشل الأصلي](logs/original-two-fixes.jsonl)، [إعادة الفحص](logs/zoom-final-narrow.jsonl)، [Body Twin](logs/body-twin-dynamic-narrow.jsonl).
- Goldens الـ29: مراجع قديمة بعد تغييرات المصدر المقصودة والخطوط الحقيقية؛ روجعت كل Master/Actual/Diff منفردة، ثم رُقِّي مرجع تلك الحالة وحده وأُعيد اختبارها وحدها بنجاح. لا `--update-goldens` جماعي، ولا تغيير thresholds أو تصميم التطبيق. الساعة الفضية وHome والآيباد محفوظة. [القرارات التفصيلية](records/individual-golden-approval.json)، [المعرض المحلي](golden-review/index.html)، [الفشل قبل الاعتماد](logs/goldens-before-individual-review.jsonl).
- Full التشخيصي الأول كشف أربع حالات Vision تتوارث مدخل FileImage معلّقًا من اختبار مغذيات في FakeAsync. صُحّح تجهيز الاختبار بإزالة مدخل الصورة نفسها ثم فكّ الملف الأصلي في `runAsync` والتحقق من `RawImage.image` على السطح المعروض. محاولة precache الأولى لم تكفِ؛ فشلها محفوظ. نجحت الحالات الأربع داخل Full النهائي أيضًا. [الفشل التشخيصي](logs/diagnostic-c2844272-full-shard-1.jsonl)، [المحاولة غير الكافية](logs/vision-matrix-fixed-shard1.jsonl)، [الإصلاح](logs/vision-matrix-eviction-shard1.jsonl)، [ملفا Vision: 76 PASS](logs/vision-eviction-affected-files.jsonl)، [تأكيد Full](records/vision-full-regression-confirmation.json).
- اختبار ترجمة `ReferenceDeltaRuntimeCopy` توقّع 17 عبارة رغم إضافة `over` لإصلاح Home. عُدّل العدد إلى 18 وأضيف تحقق وجود `over`، مع استمرار فحص اللغات الـ25 والنصوص والـplaceholders دون تخفيف. [إعادة الملف](logs/reference-copy-file.jsonl).

التشغيل التشخيصي على `c2844272` أكمل 0 و1 فقط: 0 ناجحة؛ 1 بها خمس إخفاقات اختبارات وحالتها المتخطاة. أُوقفت قائمة المجموعات الست غير المبدوءة لتوفير الوقت، دون قتل عمليتي Flutter الجاريتين؛ أنهتا ملفاتهما وأُصلحت الأسباب قبل Full النهائي. [السجل التاريخي](records/partial-full-original-results.json).

## الصور الجديدة

الصور التالية إخراج Flutter فعلي من الكود المختبَر، مع ملف وجبة واضح الوسم TEST FIXTURE، وليست تحليل AI أو صورة مستخدم حقيقية. الكمية 0.08 kg تتحول إلى 80 g وتعرض **76.0 kcal** بالفعل. العربية بخطوط فعلية، والساعة 11:30 باتجاه LTR داخل RTL. فُحصت 320/390/430 و1.8×/2×، والتكبير والإغلاق والمكونات والبدائل والكمية/الوحدة والمغذيات غير المتوفرة والـOverflow.

- [76 سعرة بعد تعديل الكمية](vision-current/functional_final_80g_nutrition.png).
- [الإغلاق أثناء فكّ الصورة المعلّق](vision-current/zoom_pending_original_decode.png).
- [الساعة 11:30](vision-current/clock_11_30_430_ar_dark_1.0x.png).
- [الوجبة الأصلية في المراجعة](vision-current/review_initial_430_ar_dark_1.0x.png).
- [تكبير الملف الأصلي](vision-current/original_photo_zoom_430_ar_dark_1.0x.png).

توجد صور إضافية ناتجة أثناء Full داخل مجلد كل شارد ورابط `cases/images` الخاص به.

## الحفظ والبصمات والحدود

بصمة مدخلات الكود/الاختبارات/المراجع: `29c1d190c4302e9759506b8ea3b0b61b3546b3696e739b3a8672645b43d722b3`؛ بصمة التدرج الخاصة بـHEAD: `77aee942beb18c9440e06850b50bc9ed2dab7939327d3ec35b2bd2bd209c6f93`. تحققت نهاية الجولة من HEAD و3511 بصمة ملف في كل Worktree، ومن غياب تغييرات كود أو مراجع. [الملفات وبصماتها](records/final-code-inputs.json)، [أسماء الملفات المعدلة](changed-code-files.txt)، [الأنساب منذ Android32/iOS35](records/ancestry-preservation.json).

تغييرات هذه الجولة: 29 مرجع PNG وأربعة ملفات اختبارات/تجهيز فقط؛ كود التطبيق مطابق لآخر QA المستلم `06c36502`. لا rollback ولا تعديل Home/Log Food/الساعة/خمس أيقونات التنقل، ولا تعطيل Assertions أو تخفيض thresholds.

عمل First Use والاحتفال المحلي على `944973ed` محفوظ دون دمج أو استبدال: 10 ملفات وبصماتها وpatch في `G:/BIL_Project/qa-preserved/first-use-before-final-closure-20261011`. **هذه الجولة لا تمثل تلك التعديلات غير المدمجة**. [إيصال الحفظ](records/first-use-preserved.json).

التحقق محلي على Windows/Flutter tester. لم تُختبر أجهزة Android/iPhone/iPad/Apple Watch حقيقية، أو الكاميرا/تحليل AI الحي، أو فكّ فيديو native على الهواتف، أو خدمات الصحة الأصلية، أو تجربة First Use الجديدة. فحص البث يثبت نقل HTTP فقط. لا توجد عيوب كود تطبيق باقية أثبتتها الاختبارات المنفذة؛ ما زالت حزمة الاعتماد البصري الخارجية تحتاج مراجعة منفصلة.

[الموارد](records/hardware.json) و[سجل RAM والتزامن](logs/full-memory.jsonl): أربع أنوية/ثمانية خيوط، 15.73 GiB RAM، حد عمليتين. ذروات Codex المؤقتة رُصدت دون OOM أو توقف شارد/Timeout؛ جميع شاردات Full اكتملت. لا دمج أو Force Push أو نشر أو تغيير Production/Supabase أو أسعار/Trial أو رفع نسخ متاجر.

## مراجعة Golden الفردية

| ID | الحالة | سبب الاعتماد الفردي | المقارنة | الاختبار المنفرد |
|---|---|---|---|---|
| G01 | `ai_430x932_ar_light_100` | اختيارات AI العربية: الخلفية الخضراء الخفيفة أصبحت محايدة، وحواف الصفوف والأيقونات أخف؛ نفس الخيارات المختارة والصورة. نافذة الموافقة ليست داخل هذه اللقطة. | [Master](golden-review/G01/master.png) · [Actual](golden-review/G01/actual.png) · [Diff](golden-review/G01/diff.png) | [PASS](logs/G01-narrow.jsonl) |
| G02 | `ar_rtl_small_dark_160` | Waist بالعربية 1.6x: سطح داكن محايد بدل الأخضر/الأسود، وحقل إدخال وحدود أكثر هدوءًا؛ نص التخطي والنطاق والصورة موجودة. | [Master](golden-review/G02/master.png) · [Actual](golden-review/G02/actual.png) · [Diff](golden-review/G02/diff.png) | [PASS](logs/G02-narrow.jsonl) |
| G03 | `en_ltr_small_light` | Waist EN: F8F9FB بدل الخلفية الخضراء، وحقل/تنبيه بخط وحدود أخف؛ عنوان Optional والصورة وSkip/Continue محفوظة. | [Master](golden-review/G03/master.png) · [Actual](golden-review/G03/actual.png) · [Diff](golden-review/G03/diff.png) | [PASS](logs/G03-narrow.jsonl) |
| G04 | `epic8_weekly_report_alltime_anchor` | All-time: Header والحدود الثقيلة صارت أهدأ؛ Member since=Unavailable، meals=0 وstreak=0days محفوظة. المرجع السابق outlined cards. | [Master](golden-review/G04/master.png) · [Actual](golden-review/G04/actual.png) · [Diff](golden-review/G04/diff.png) | [PASS](logs/G04-narrow.jsonl) |
| G05 | `epic8_weekly_report_calories_anchor` | Calories anchor: بطاقة السعرات خلفيتها بيضاء وحدود أفتح والعناوين تغيرت؛ logged0kcal/nofoods وgoal غير متوفر محفوظة. | [Master](golden-review/G05/master.png) · [Actual](golden-review/G05/actual.png) · [Diff](golden-review/G05/diff.png) | [PASS](logs/G05-narrow.jsonl) |
| G06 | `epic8_weekly_report_coverage_phone` | Coverage: بطاقتا Proteins/Sweet snacks وصف feedback تغيّر خطهما وهوامشهما؛ counts=1 وWater4.7L/Weight92.8kg باقية. | [Master](golden-review/G06/master.png) · [Actual](golden-review/G06/actual.png) · [Diff](golden-review/G06/diff.png) | [PASS](logs/G06-narrow.jsonl) |
| G07 | `epic8_weekly_report_empty_phone` | Empty state: بطاقات Calories/Frequent foods أفتح، وأيقونة طبق فارغ تغير وزنها؛ nofoods/goal— محفوظان. | [Master](golden-review/G07/master.png) · [Actual](golden-review/G07/actual.png) · [Diff](golden-review/G07/diff.png) | [PASS](logs/G07-narrow.jsonl) |
| G08 | `epic8_weekly_report_evidence_phone` | Evidence: حدود/خط بطاقات Proteins/Sweet snacks والfeedback تغيّرت؛ counts=1 و4.7L/92.8kg كما فيfixture. تغير scroll framing ناتج عن مقاييس النص. | [Master](golden-review/G08/master.png) · [Actual](golden-review/G08/actual.png) · [Diff](golden-review/G08/diff.png) | [PASS](logs/G08-narrow.jsonl) |
| G09 | `epic8_weekly_report_exercise_anchor` | Exercise: نفس noexercise/no steps وصف المصدر، وحدود وترويسة أهدأ ونصوص أصغر؛ All-time section موجود. | [Master](golden-review/G09/master.png) · [Actual](golden-review/G09/actual.png) · [Diff](golden-review/G09/diff.png) | [PASS](logs/G09-narrow.jsonl) |
| G10 | `epic8_weekly_report_frequent_anchor` | Frequent foods: أيقونة الطبق تغيرت، وحدود Frequent/Advanced/Macros أهدأ؛ nofoods و0g محفوظة. | [Master](golden-review/G10/master.png) · [Actual](golden-review/G10/actual.png) · [Diff](golden-review/G10/diff.png) | [PASS](logs/G10-narrow.jsonl) |
| G11 | `epic8_weekly_report_macro_tooltip` | Tooltip: نفس macronutrients/0g وNo macrodata، لكن سمك الحدود والخط وموقع tooltip مقارنة بسياق الصفحة تغير؛ يحتاج قرارtooltip فردي. | [Master](golden-review/G11/master.png) · [Actual](golden-review/G11/actual.png) · [Diff](golden-review/G11/diff.png) | [PASS](logs/G11-narrow.jsonl) |
| G12 | `epic8_weekly_report_macros_anchor` | Macros: نفس 0g/no macrodata وخيارNutrition importer؛ حدود البطاقة/الترويسة ومسافة قسمExercise تغيرت. | [Master](golden-review/G12/master.png) · [Actual](golden-review/G12/actual.png) · [Diff](golden-review/G12/diff.png) | [PASS](logs/G12-narrow.jsonl) |
| G13 | `epic8_weekly_report_nutrition_phone` | Nutrition: نفس الخضار والفواكه والبروتين/Sweet snacks وcounts1؛ أسطح وحواف وخط/أيقونات جديدة منcalm scope. | [Master](golden-review/G13/master.png) · [Actual](golden-review/G13/actual.png) · [Diff](golden-review/G13/diff.png) | [PASS](logs/G13-narrow.jsonl) |
| G14 | `epic8_weekly_report_phone_ltr_light` | LTR phone: Heroweek dates3/7 وFoodInsights نفسfixture؛ لونCanvas أبيض محايد، وخطAppBar أصغر وصورةhero/رموز أدق. | [Master](golden-review/G14/master.png) · [Actual](golden-review/G14/actual.png) · [Diff](golden-review/G14/diff.png) | [PASS](logs/G14-narrow.jsonl) |
| G15 | `epic8_weekly_report_phone_rtl_dark` | RTL dark: Week3/7 والتواريخ والعدد محفوظة؛ خلفيةداكنة محايدة وخط عربي/أيقونات أنحف منالمرجع. | [Master](golden-review/G15/master.png) · [Actual](golden-review/G15/actual.png) · [Diff](golden-review/G15/diff.png) | [PASS](logs/G15-narrow.jsonl) |
| G16 | `epic8_weekly_report_sources_phone` | Sources: feedback و4.7L/92.8kg ثم3900kcal/14700goal محفوظة؛ framing والأحجام والحدود بعدcalm scope تغيرت. | [Master](golden-review/G16/master.png) · [Actual](golden-review/G16/actual.png) · [Diff](golden-review/G16/diff.png) | [PASS](logs/G16-narrow.jsonl) |
| G17 | `facts_320x568_en_light_200` | Facts EN 320/2x: الخلفية والفونت والهوامش تغيرت؛ النص الطويل يمتد تحت viewport القابل للتمرير في المرجعين، والزر ثابت؛ ليس إثبات قص غير قابل للوصول. | [Master](golden-review/G17/master.png) · [Actual](golden-review/G17/actual.png) · [Diff](golden-review/G17/diff.png) | [PASS](logs/G17-narrow.jsonl) |
| G18 | `female_hip_light_160` | Hip 1.6x: سطح محايد وحقل أفتح وأيقونات أدق، مع الصورة والعنوان وخيارات التنقل نفسها؛ footer والتمرير يحتاجان تحقق جهاز. | [Master](golden-review/G18/master.png) · [Actual](golden-review/G18/actual.png) · [Diff](golden-review/G18/diff.png) | [PASS](logs/G18-narrow.jsonl) |
| G19 | `height_units_en_light_100` | Height EN: الحقل والسطح أخف، وصورة القياس نفسها مع recrop مختلف قليلًا؛ 170 cm والنطاق120–250 باقيان، يلزم اعتماد crop فردي. | [Master](golden-review/G19/master.png) · [Actual](golden-review/G19/actual.png) · [Diff](golden-review/G19/diff.png) | [PASS](logs/G19-narrow.jsonl) |
| G20 | `live_health_watch_compact_all_metrics` | المرجع واللقطة التاريخية كاناAhem (مربعات بدل14:22 وقراءات). الاختبارلايحمّل وجهًا صريحًا. بعدإصلاحtest يظهر14:22:08 و2198/80/300/4.8. يبقىفرقهيكلالساعةبالإضافةللخط؛ لايصلحمرجعAhem للقبولالتلقائي. | [Master](golden-review/G20/master.png) · [Actual](golden-review/G20/actual.png) · [Diff](golden-review/G20/diff.png) | [PASS](logs/G20-narrow.jsonl) |
| G21 | `permissions_light_160` | Permissions Android: نفس Health Connect وNot requested؛ إطار البطاقة والسطح والأيقونة والهوامش تغيرت، لا وصول لشبكة/صلاحية فعلية. | [Master](golden-review/G21/master.png) · [Actual](golden-review/G21/actual.png) · [Diff](golden-review/G21/diff.png) | [PASS](logs/G21-narrow.jsonl) |
| G22 | `plan_320x568_ar_dark_200` | Plan AR 320/2x: نفس عنوان خطة البداية وصورة الاختبار، مع سطح وخط محايدين؛ المحتوى تحت viewport قابل للتمرير ولا يمثل وحده خللًا. | [Master](golden-review/G22/master.png) · [Actual](golden-review/G22/actual.png) · [Diff](golden-review/G22/diff.png) | [PASS](logs/G22-narrow.jsonl) |
| G23 | `plan_dark_160` | Plan EN 1.6x: نفس1808kcal و126g في خطة الاختبار؛ خلفية/حدود وخط البطاقة تغيرت. يلزم مراجعة الصورة كاملة قبل أي اعتماد. | [Master](golden-review/G23/master.png) · [Actual](golden-review/G23/actual.png) · [Diff](golden-review/G23/diff.png) | [PASS](logs/G23-narrow.jsonl) |
| G24 | `premium_dashboard_desktop_after` | Desktop1440: وحدةcal والعرض الموثق للشريط/صفوفFood-Water-Weight وأبعادDiscover تغيّرت تاريخيًا؛ لاAhem. هذهHome محمية ويجب تأكيد اعتماد التغييرات السابقة فرديًا. | [Master](golden-review/G24/master.png) · [Actual](golden-review/G24/actual.png) · [Diff](golden-review/G24/diff.png) | [PASS](logs/G24-narrow.jsonl) |
| G25 | `premium_dashboard_light_corrected` | Light1024: نفس 0 واختبارالبيانات الفارغة؛ صفالقيم والWeight وأزرارFood-Water-Weight وDiscover تحركت مع مصدرالبطاقة الأحدث؛ ليستزيادة2px وحدها. | [Master](golden-review/G25/master.png) · [Actual](golden-review/G25/actual.png) · [Diff](golden-review/G25/diff.png) | [PASS](logs/G25-narrow.jsonl) |
| G26 | `premium_dashboard_phone_after` | Phone390: 0cal/— بدل0/— وrowheight/food-water-weight تبدلت مقارنةبمرجع5f026c؛ تغييراتأقدم منإصلاحHome2px، لا موافقةضمنية عليها. | [Master](golden-review/G26/master.png) · [Actual](golden-review/G26/actual.png) · [Diff](golden-review/G26/diff.png) | [PASS](logs/G26-narrow.jsonl) |
| G27 | `premium_dashboard_tablet_after` | Tablet1024: تغيّر صفالسعرات ووحدته ومسافاتWeight/Actions وDiscover، والقيم الأساسية باقية؛ يحتاجقرارHome محمي فردي. | [Master](golden-review/G27/master.png) · [Actual](golden-review/G27/actual.png) · [Diff](golden-review/G27/diff.png) | [PASS](logs/G27-narrow.jsonl) |
| G28 | `recipe_library_polish_phone` | Recipes: صورةShakshuka ومقادير225kcal/15.4g و25min/2 servings محفوظة؛ CalmCanvas وSearch/Chips/Card وحدودها تغيرت. | [Master](golden-review/G28/master.png) · [Actual](golden-review/G28/actual.png) · [Diff](golden-review/G28/diff.png) | [PASS](logs/G28-narrow.jsonl) |
| G29 | `workout_library_offline_empty_phone` | Workouts offline: tabs وأمانoffline والجمهور وكارتCardio محفوظة؛ الخطوط/أيقوناتالتبويب وحوافSearch/Card تغييرcalm scope، لا تحميلفيديوحي. | [Master](golden-review/G29/master.png) · [Actual](golden-review/G29/actual.png) · [Diff](golden-review/G29/diff.png) | [PASS](logs/G29-narrow.jsonl) |
