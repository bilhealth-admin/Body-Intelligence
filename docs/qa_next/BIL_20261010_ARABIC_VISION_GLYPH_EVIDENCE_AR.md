# BIL QA — تحسين مصداقية لقطات AI Vision العربية

**الفرع:** `qa/bil-quality-ux-integration-20261009`، PR #11 Draft. هذا تعديل **اختبارات تصوير Flutter فقط**، لا تغيير في خطوط التطبيق أو نسخ المتاجر أو أسعار الاشتراكات أو AI Vision production.

## الفشل المكتشف بمراجعة الصور، لا نتيجة الكود
- [Vision post-integration #38053137123](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38053137123) على `5957a1eb`: source/analyze + 12 focused + Android Debug + iOS Simulator + Flutter captures **PASS**.
- artifact `bil-vision-genuine-flutter-widget-renderings` يحوي أربع PNG حقيقية من `RenderRepaintBoundary.toImage` (860×1864). **بعد فتح الأربع** ظهر أن غالب نصوص العربية تظهر في بيئة Flutter Test كمربعات Ahem/tofu، رغم سلامة الأيقونات والأزرار والقياسات.
- إذن **نجاح توليد PNG ليس نجاح تمثيل الخط العربي**. لا يجوز اعتبار الصور إثباتًا لتجربة عربية فخمة أو RTL قبل إصلاح الخط والاطلاع على الناتج.

## السبب والإصلاح المحدود
- `visualEvidenceFont.dart` يحمّل `NotoNaskhArabic-Regular/Bold` تحت العائلة `NotoArabicEvidence`، لكنه يحمّل `RobotoEvidence` أيضًا، وغياب تحديد العائلة العربية داخل Theme وDefaultTextStyle يسمح للمحرك الآلي بالعودة إلى Ahem.
- داخل `test/features/nutrition/meal_vision_flutter_capture_test.dart` فقط: `visualEvidenceTheme(... fontFamily: 'NotoArabicEvidence')` + `visualEvidenceTextSurface(child,fontFamily:'NotoArabicEvidence')`. أضفنا تأكيدًا على `ThemeData.textTheme.bodyMedium.fontFamily`. لم نغير ملفات التطبيق الإنتاجية أو إصدارات الحزم.
- workflow مصغّر `bil_qa_vision_arabic_capture_20261010.yml` ينفّذ اختبار التصوير وحده ويرفع الأربع صور الناتجة؛ **لا يشغّل الثماني shards**.
- يجب التحقق بصريًا أن الحروف العربية أصبحت متصلة ومقروءة في الصور الأربع دون مربعات، وأن التحليل الكامل لا يخفي القيم غير المتوفرة ولا يختلق مغذيات؛ ثم الاحتفاظ بالأدلة برقم SHA.
- الصور لا تزال Flutter headless وليست تسجيلًا من هاتف فعلي؛ تبقى مهمة الفحص على أجهزة Android/iOS والمقاسات/25 لغة قائمة.

## الأعمال التي لا تتغير
- إصلاحات حفظ Vision بكمية أصيلة g/kg/piece/ml، dedupe المرتبط بالمالك، عزل الحسابات، والمغذيات المجهولة.
- Home/Dashboard محمي ولم نغيره؛ Overflow 1px حقيقي مشخص إلى `dashboard-reference-calories-card` الداخلي (216px متاح، 217px أطفال).
- Golden القديم يبقى أحمر إلى اعتماد مرجع فردي، ولا Auto-update.
