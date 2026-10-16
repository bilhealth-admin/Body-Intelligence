# إصلاح تجهيز Gradle لبوابة السياسات — 2026-10-16

- التشغيل الفاشل: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38826857218 على المصدر 36c46e353fafcc3b01451b5fbc122fb1b4875aae.
- السبب المثبت: `./gradlew: No such file or directory`؛ ملفات wrapper مستثناة من Git عمدًا. فحص merged manifest اللاحق لم يجد المخرجات بسبب هذا الفشل.
- الإصلاح: تجهيز ملفات wrapper من cache نسخة Flutter المثبتة 3.44.6، بنفس مصدر Flutter وسلوك النسخ عند الغياب فقط؛ تجهيز local.properties للمسارات المحلية قبل استدعاء Gradle مباشرة. لا بناء APK ولا تغيير إصدار Gradle أو SHA256 المثبت أو اعتماديات التطبيق.
- التحقق المحلي: اختباران ناجحان يشملان checkout نظيفًا، تكرار التجهيز، حفظ الملفات الموجودة وخصائص Gradle حرفيًا، وحفظ الإعدادات الأخرى، والفشل المغلق عند غياب wrapper. actionlint وفحص whitespace ناجحان.
- لم يُشغّل Android Gradle فعليًا محليًا ضمن هذا الإصلاح؛ نجاح مسار GitHub المعدل ينتظر تشغيل البوابة على الكوميت الجديد.
- الشاملة الأصلية https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38826857261 بقيت تعمل على مصدرها الأصلي، والتحليل فيها نجح. لم تُلغَ ولم تُكرر، ولا تُنسب نتيجتها إلى تغيير workflow اللاحق.
- لا تعديل على التطبيق أو Goldens أو Production أو المتاجر.
