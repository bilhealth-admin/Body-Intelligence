from pathlib import Path
import json,subprocess,hashlib
root=Path.cwd();src=root/'build/qa-final-closure';dest=root/'tools/qa/evidence/20261011-final-closure'
summary=json.loads((dest/'summary.json').read_text(encoding='utf-8'));full=json.loads((src/'full-results.json').read_text(encoding='utf-8'));stages=json.loads((src/'prior-stage-counts.json').read_text(encoding='utf-8'));goldens=json.loads((src/'individual-golden-approval.json').read_text(encoding='utf-8'))
head=summary['tested_code_head'];assert full['passed']
text=f"""# BIL 2026 — الإغلاق المحلي النهائي للاختبارات — 2026-10-11

الفرع المستهدف: `qa/bil-quality-ux-integration-20261009`، [PR #11](https://github.com/bilhealth-admin/Body-Intelligence/pull/11).

HEAD الكود المختبَر: `{head}`. بدأت الجولة من `06c365022f20e0f0c5d6e901b19a8efb1419b81f` دون رجوع أو إسقاط إصلاح. كوميت التسليم اللاحق يضيف الأدلة فقط، وترد بصمته في تعليق PR النهائي.

Flutter **3.44.6**، Dart **3.12.2**. جميع المجموعات الثماني انتهت بأكواد خروج 0 وحدث `done.success=true`، وحمّلت كل مجموعة ملفاتها الـ1253. استُخدمت ثمانية Worktrees منفصلة على نفس HEAD، بحد عمليتين متزامنتين و`--concurrency=1` لكل مجموعة.

## النتائج

| المرحلة | PASS | FAIL | SKIP |
|---|---:|---:|---:|
"""
for stage in ['arabic','p0','focused','broad']:
 t=stages['stages'][stage]['totals'];text+=f"| {stage} | {t['PASS']} | {t['FAIL']} | {t['SKIP']} |\n"
t=summary['full_totals'];text+=f"| Full 0–7 | {t['PASS']} | {t['FAIL']} | {t['SKIP']} |\n"
text+="""
Source: تنسيق 195 ملف Dart ناجح، والتحليل الكامل بلا أخطاء. اختبارات أداة التدرّج: 11/11 PASS. [Source log](logs/source-analyze.log)، [تفاصيل مراحل الاختبار](records/prior-stage-counts.json)، [بوابات الكود والبصمة](records/gates.json).

بعد إصلاح تجهيز الصورة أُعيدت مجموعة Vision العربية ومجموعة كمية Vision؛ احتُفظ فقط بنتائج المجموعات غير المتأثرة من `c2844272` بعد إثبات أن ملفاتها وكود التطبيق والأصول والاعتمادات لم تتغير. تحمل كل نتيجة محتفظ بها SHA التنفيذ القديم صراحةً في `gates.json`. Full كله نُفِّذ فعليًا على HEAD أعلاه؛ لا تُنسب جولة قديمة إليه.

| Full shard | PASS | FAIL | SKIP | Exit | السجل والتفاصيل |
|---|---:|---:|---:|---:|---|
"""
for key,r in sorted(full['shards'].items()):text+=f"| {key} | {r['PASS']} | {r['FAIL']} | {r['SKIP']} | {r['exit_code']} | [log](logs/full-shard-{key}.jsonl) · [cases/images](shards/{key}/result.json) |\n"
text+=f"""
الإجمالي في Full: **{summary['visible_case_executions']}** حالة، منها **{t['PASS']} PASS و0 FAIL و3 SKIP**. لا يشمل العدد أحداث تحميل الملفات أو setUp/tearDown المخفية، ولا تُجمع أعداد المراحل المتداخلة كاختبارات فريدة. عدد هويات الحالات الفريدة: {summary['unique_case_identities']}؛ لم تُسند هوية حالة إلى شاردين.

## حالات التخطي

1. `visual evidence check is truthful and read-only`: يحتاج حزمة الاعتماد البصري المستقلة غير المتتبعة في Git. حزمة المضيف التاريخية تضم 177 سجلًا، و151 سجلًا يشير إلى بصمات أدلة تختلف عن QA الحالية. لم تُنسخ الموافقات القديمة أو تُحدَّث تلقائيًا. ما زال هذا المتطلب غير منفّذ/غير معتمد للواجهة الحالية. [الفحص](records/legacy-visual-truth-skip-inspection.json).
2. بثّ التمرين العام: SKIP ضمن Full بسبب opt-in. شُغّل منفردًا باستخدام `BIL_LIVE_WORKOUT_STREAM_CHECK=true` ونجح **1 PASS / 0 FAIL / 0 SKIP**. HEAD، Range 32 bytes، المحتوى `ftyp`، وربط الكيان اختُبرت عبر عميل التطبيق الحقيقي دون مصادقة أو تنزيل فيديو كامل. [السجل](logs/live-workout-stream-opt-in.jsonl).
3. symlink: SKIP افتراضي على Windows CI. ثبت أن الجهاز يدعم الرابط الحقيقي، وشُغّلت الحالة الأصلية بـ`--run-skipped` ونجحت **1 PASS / 0 FAIL / 0 SKIP** دون تعديل شروط الرفض. [السجل](logs/windows-symlink-security-forced-case.jsonl).

إذن بعد الفحصين الإضافيين: **{t['PASS']+2} حالة PASS فعلية، 0 FAIL، وحالة واحدة لم تُنفّذ**. نتائج Full الأصلية أعلاه تبقى 3 SKIP ولا يُعاد تصنيف سجلاتها. [أوامر ونتائج الفحصين](records/optional-check-results.json).

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

بصمة مدخلات الكود/الاختبارات/المراجع: `{summary['semantic_input_sha256']}`؛ بصمة التدرج الخاصة بـHEAD: `{summary['ladder_fingerprint']}`. تحققت نهاية الجولة من HEAD و3511 بصمة ملف في كل Worktree، ومن غياب تغييرات كود أو مراجع. [الملفات وبصماتها](records/final-code-inputs.json)، [أسماء الملفات المعدلة](changed-code-files.txt)، [الأنساب منذ Android32/iOS35](records/ancestry-preservation.json).

تغييرات هذه الجولة: 29 مرجع PNG وأربعة ملفات اختبارات/تجهيز فقط؛ كود التطبيق مطابق لآخر QA المستلم `06c36502`. لا rollback ولا تعديل Home/Log Food/الساعة/خمس أيقونات التنقل، ولا تعطيل Assertions أو تخفيض thresholds.

عمل First Use والاحتفال المحلي على `944973ed` محفوظ دون دمج أو استبدال: 10 ملفات وبصماتها وpatch في `G:/BIL_Project/qa-preserved/first-use-before-final-closure-20261011`. **هذه الجولة لا تمثل تلك التعديلات غير المدمجة**. [إيصال الحفظ](records/first-use-preserved.json).

التحقق محلي على Windows/Flutter tester. لم تُختبر أجهزة Android/iPhone/iPad/Apple Watch حقيقية، أو الكاميرا/تحليل AI الحي، أو فكّ فيديو native على الهواتف، أو خدمات الصحة الأصلية، أو تجربة First Use الجديدة. فحص البث يثبت نقل HTTP فقط. لا توجد عيوب كود تطبيق باقية أثبتتها الاختبارات المنفذة؛ ما زالت حزمة الاعتماد البصري الخارجية تحتاج مراجعة منفصلة.

[الموارد](records/hardware.json) و[سجل RAM والتزامن](logs/full-memory.jsonl): أربع أنوية/ثمانية خيوط، 15.73 GiB RAM، حد عمليتين. ذروات Codex المؤقتة رُصدت دون OOM أو توقف شارد/Timeout؛ جميع شاردات Full اكتملت. لا دمج أو Force Push أو نشر أو تغيير Production/Supabase أو أسعار/Trial أو رفع نسخ متاجر.

## مراجعة Golden الفردية

| ID | الحالة | سبب الاعتماد الفردي | المقارنة | الاختبار المنفرد |
|---|---|---|---|---|
"""
for g in goldens:
 observation=g['observation'].replace('|','/').replace('\n',' ');text+=f"| {g['id']} | `{g['name']}` | {observation} | [Master](golden-review/{g['id']}/master.png) · [Actual](golden-review/{g['id']}/actual.png) · [Diff](golden-review/{g['id']}/diff.png) | [PASS](logs/{g['id']}-narrow.jsonl) |\n"
(dest/'README.md').write_bytes(text.encode('utf-8'))
print('Final Arabic report written',flush=True)
