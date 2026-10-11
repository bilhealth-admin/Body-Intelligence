# BIL 2026 — AI Vision Premium: تقرير تنفيذ جزئي يحتاج تحقق CI

المستودع: `bilhealth-admin/Body-Intelligence`، الفرع: `qa/bil-quality-ux-integration-20261009`.
الأساس الذي راجعناه: `aca278eb6ec1a094c51e5967ecd86b1ec63e32ca`.

## تغييرات الشيفرة المقترحة
- دمج شاشة مراجعة زجاجية مع بقية مسار BIL الحقيقي مع الحفاظ على نوعي الإرجاع الأصليين.
- تمرير مسار صورة المستخدم الأصلية فقط، بدون صورة افتراضية، وتكبيرها ثم العودة إلى المسودة.
- بطاقة نوع الوجبة ووقت المراجعة، مع تسمية إن كانت الكمية «مأكولة» أو «متبقية».
- المستخدم يحدد قبل/أثناء/بعد الأكل، ويؤكد الكمية المأكولة صراحة؛ اختيار البقايا يمسح القيمة حتى لا تسجل خطأ.
- + و− وإدخال يدوي للكمية وقائمة وحدات، مع فحص الكميات غير الصالحة والحفاظ على التعديلات في TextEditingControllers.
- بدائل التعرف تعيد تشغيل المطابقة الغذائية دون الاحتفاظ بمعرّف مطابق سابق؛ إضافة عنصر يدوي تمر أيضًا بالمطابقة؛ استبعاد مع إمكانية التراجع.
- مؤشر متحرك لثقة التعرف فقط، وليس دقة الطاقة/المغذيات؛ احترام تقليل الحركة.
- شاشة مصدر غذائي موثوق تعرض الملخص الكامل والسريع والقيم المثبتة فقط، وتكتب «غير متوفر» عند نقص الدليل. تحسب القيم للكمية التي راجعها المستخدم حين يمكن تحويل وحدتها.
- الحفاظ على مسار الحفظ الذري الأصلي وعدم أي تعديل لمنظومة الاشتراك أو الموافقة أو الداشبورد أو Production.

## ما لم يُثبت أو يُنفذ بعد
- لم يُختبر Flutter SDK على حاسوب هذه المحادثة؛ لا توجد Flutter أو Dart CLI هنا.
- لقطات شاشة فعلية وApple/Android real-device لم تُنتج بعد.
- لا توجد إعادة تحليل للصورة من داخل شاشة المراجعة ولا صورة مسح متحرك أثناء الطلب؛ تقديمهما يحتاج تعديل تدفق الطلب وحصص API بشكل آمن.
- لا يوجد تأكيد دائم عبر قاعدة البيانات لمنع إعادة إدراج request_id بعد إعادة تشغيل التطبيق؛ منع الضغط المتكرر أثناء التدفق قائم في مسارات التطبيق الأصلية.
- ردود AI Coach داخل محادثة Chat لم تعدّل؛ تغييرها خارج صفحة Vision يحتاج عقد أحداث منفصل ومنع التكرار.
- بقية لغات المشروع تستخدم RuntimeCopy؛ فحص تقديمها البصري على جميع 25 لغة لم يتم.
- لا يمكن اعتبار المنتج جاهزًا حتى نجاح `flutter analyze` وwidget tests وAndroid/iOS builds وسجل قراءة وجبة بعد الحفظ.

## فحص مطلوب على الفرع قبل الدمج
```
dart format --output=none --set-exit-if-changed lib/features/nutrition/presentation/meal_vision_premium_review.dart lib/features/nutrition/presentation/meal_vision_premium_match.dart lib/features/nutrition/presentation/meal_image_review_dialog.dart lib/features/daily_log/food_log_actions.dart lib/features/daily_log/daily_log_capture_actions.dart test/features/nutrition/meal_vision_premium_review_test.dart
flutter analyze --no-pub
flutter test --no-pub test/features/nutrition/meal_vision_premium_review_test.dart
flutter test --no-pub test/features/nutrition/meal_image_unified_review_contract_test.dart
flutter test --no-pub test/features/nutrition/meal_vision_domain_contract_test.dart
flutter test --no-pub test/features/daily_log/meal_photo_initial_action_test.dart
flutter test --no-pub test/architecture_source_file_size_guard_test.dart
```

## تعليمات التراجع
بعد التطبيق على فرع الاختبار فقط، `git revert <commit>`، ثم أعد فحوص الجودة. يمنع إعادة كتابة main أو نشر Supabase/المتاجر.
