# دليل لقطات Flutter لسبلاشات الميزات — 2026-10-14

## المصدر والحدود

- المستودع: `G:/BIL_Project/worktrees/bil-stage1-closure-20261011`
- الفرع: `integration/bil-qa-media-policy-20261011`
- HEAD وقت التوثيق: `e27a58984bff50b4bcf45044ea9893f344307e85`
- شجرة العمل تحتوي تغييرات غير ملتزمة؛ لذلك SHA وحده لا يعرّف كل المصدر الذي أُنتجت منه اللقطات.
- لم يتغير السبلاش الرئيسي للتطبيق.

## التنفيذ

تستخدم الوصفات والفيديوهات والنوم والدايت صور بطاقات Dashboard المضمّنة نفسها، داخل قالب ترحيب لؤلؤي موحّد مع صورة ناعمة بلا إطار ظاهر، وخطوط الثيم الحالي ومؤشر انتظار. مدة البوابة `2200ms` لكل الأنواع الأربعة، بينما يظل تحميل الصفحة والبيانات يبدأ خلف طبقة الانتظار. يعرض القالب النص كاملًا على الشاشة الصغيرة وتكبير الخط، ويحترم تقليل الحركة.

| الميزة | أصل الصورة المضمّنة |
|---|---|
| الوصفات | `assets/images/flagship/bil_meal_discovery_v1.png` |
| الفيديوهات | `assets/images/flagship/bil_movement_v1.png` |
| النوم | `assets/images/flagship/bil_sleep_insights_v2.png` |
| الدايت | `assets/images/nutrition_plans/carb_cycling_lifestyle_v1.webp` |

## الدليل المرئي

أنشأ اختبار Flutter widget لقطات فعلية من الشجرة الحالية: 4 ميزات × 6 مشاهد = 24 ملف PNG. المشاهد تغطي العربية والإنجليزية، الفاتح والداكن، شاشة 390، وشاشة 320 مع تكبير نص 2× وتقليل الحركة.

المجلد: `build/stage1-closure/feature-splashes-dashboard-photos-after147/`

| الميزة | مثال عربي فاتح 320px مع تكبير 2× | مثال إنجليزي فاتح 390px |
|---|---|---|
| الوصفات | `recipes_ar_light_320_2.0x.png` | `recipes_en_light_390_1.0x.png` |
| الفيديوهات | `videos_ar_light_320_2.0x.png` | `videos_en_light_390_1.0x.png` |
| النوم | `sleep_ar_light_320_2.0x.png` | `sleep_en_light_390_1.0x.png` |
| الدايت | `diet_ar_light_320_2.0x.png` | `diet_en_light_390_1.0x.png` |

## لقطات محتوى رسائل AI Coach

بعد مراجعة الطوابع الزمنية، أُعيد تشغيل اختبار تصوير Flutter على ملفات العرض الحالية بدل الاعتماد على مجموعة أقدم. الاختبار ولّد 10 لقطات من بيانات SQLite تركيبية: خمسة أنماط (نص، وجبة، ملخص يوم، مقارنة، وزن) بالعربية الفاتحة والإنجليزية الداكنة. هذه لقطات لمكوّن جسم رسالة Coach الفعلي، وليست صورة شاشة جهاز كاملة.

المجلد: `build/stage1-closure/coach-message-presentation-latest-20261014/`

| النمط | لقطة عربية فاتحة |
|---|---|
| نص طبيعي | `text_ar_light.png` |
| وجبة | `meal_ar_light.png` |
| ملخص يوم | `day_ar_light.png` |
| مقارنة | `comparison_ar_light.png` |
| رسم الوزن | `weight_ar_light.png` |

أمر الاختبار: `flutter test --no-pub test/features/intelligence_center/coach_message_presentation_capture_test.dart` — نجحت الحالات العشر (`+10 All tests passed`). بيانات الوزن في اللقطة لها ثلاث قياسات فقط بتواريخها الفعلية؛ يوضح النص وجود 28 يومًا بلا قياس وأن النقاط لا تكفي لاستنتاج اتجاه.

## التحقق المسجل

- اختبار ربط صورة كل ميزة ببايتات صورة Dashboard القائمة: 7/7.
- اختبار البوابة والمدة المحددة وإمكانية الوصول وتقليل الحركة وحالة الصورة المفقودة: 29/29.
- اختبار لقطات Flutter أنشأ 24 صورة عبر المشاهد المذكورة أعلاه.
- اختبار لقطات AI Coach على المصدر الحالي نجح 10/10 وأنشأ 10 صور.
- `flutter analyze --no-pub` الكامل نجح بعد الإصلاحات الأخيرة، وفق سجل هذه الجولة.
- لم يُعَد تشغيل هذه الفحوص أثناء كتابة هذا التقرير.

## حد اختبار الجهاز

بُني APK تصحيح محلي، لكن مشغّل Android لم يثبت التطبيق أو يفتحه لأن حالة اتصال المحاكي لم تثبت. لذلك لا توجد هنا نتيجة اختبار جهاز Android أو iOS أو متجر. لقطات التصميم أعلاه من Flutter widget tests مباشرة، وليست صور محاكي أو جهاز.

## الملفات ذات الصلة

- `lib/shared/widgets/bil_feature_entry_splash.dart`
- `lib/shared/widgets/bil_pearl_feature_welcome.dart`
- `test/shared/widgets/bil_feature_entry_dashboard_photo_test.dart`
- `test/shared/widgets/bil_feature_entry_splash_test.dart`
- `test/qa_next/feature_splashes_capture_test.dart`
- `test/qa_next/feature_splashes_test_support.dart`
