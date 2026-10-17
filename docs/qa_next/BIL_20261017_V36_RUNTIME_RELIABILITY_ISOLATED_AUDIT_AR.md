# BIL — تدقيق وإصلاحات الاعتمادية بمعزل عن Codex — 17 أكتوبر 2026

## نطاق مصدر نسخة 36 وبوابة العزل
- ملف IPA رقم 36 وAndroid 33 مقيّدان بالمصدر المجمد `a6f0a9a15188aabca0dcb739269ab17079ed4504`.
- بدأت الحزمة الجديدة من `ef4647302784a1b2e556c9a16defca14abebb302` الذي يضم إصلاحات الكاميرا والبحث وزر (+) وإزالة إدارة الهاتف المعتمدة مسبقًا.
- فرع مستقل: `qa/bil-v36-reliability-coach-isolated-20261017`؛ لا تعديل لـintegration الخاص بكوديكس أو main أو iOS/Android أو Production.
- لا محاولة ادعاء اختبارات الأجهزة الحقيقية أو اعتماد متجر. نتائج CI المستهدفة محدودة بالكوميت المختبر؛ وGolden/الشاملة والباينري مسؤولية مرحلة التكامل بعد مراجعة النتائج.

## المشكلات المؤكدة ومحدودية الحل
1. **قنوات المجتمع P0:** يعتمد باينري v36 على `bil07_channel_capabilities_v1`, `bil07_channel_directory_v1`, `bil07_channel_messages_v1`؛ الفحص القرائي لـProduction لم يجد هذه الوظائف. هذه فجوة أصلية لقاعدة البيانات، **ليست أصلحت** بتغيير صفحة Retry؛ نحتاج schema/RLS/RPC خادم حقيقيًا + اختبارات اشتراك/هوية متعددة، وإطلاقًا خادميًا مصرحًا منفصلًا.
2. **Store/AI Vision 503 P0:** في سجلات 16 و17 أكتوبر توجد 503 فعلية للشراء وVision وCoach. لا نلغي Mobile Integrity أو consent أو الحصص لإسكاتها. تحتاج سجلات خادم مع أكواد آمنة دون بيانات المستخدم وربط فترة نشر نسخ الدوال.
3. **الصور الخاصة P1:** كاش Community كان يركّب URL `/storage/v1/object/sign/{path}` دون JWT token أصلي؛ يُحافظ الإصلاح على النص والوسائط المصرح بها metadata فقط، ويؤجل الصورة إلى hydration الموقعة فعلًا. **لا يكشف صورة خاصة أو يمنح صلاحية كاش دائمة**. تحسين سرعة صور القرص المفوضة يحتاج مرحلة إضافية مع cache invalidation.
4. **المزامنة P1:** توحيد رسائل More وSharing Privacy لتوضح offline، اختلاف الحساب، الاشتراك، الموافقة، نقص دعم الخادم، التعارض والانتظار دون الادعاء باكتمال النسخة الاحتياطية. لا إرسال أو تخزين بيانات جديد.
5. **شراء مؤكد بلا تهنئة P2:** سجل التهنئة المرئي يسمح باستعادة حجز `reserved` غير المعروض **مرة واحدة فقط في عملية تطبيق جديدة** مع CAS وتطابق المالك/المنتج/البيئة وحد 24 ساعة، دون تعديل الاستحقاق/الرصيد أو تكرار العرض ضمن نفس العملية. القديمة بلا session تعالج بعد انتظار دقيقتين.
6. **AI Coach P1:** في مسار الاستثناء العام، لا يجوز الادعاء أن «البيانات لم تتغير» بعد خطأ قد يقع بعد تنفيذ إجراء سابق. صار يذكر بقاء سؤال المستخدم ويحذر من التكرار قبل retry؛ المحافظة على retry واحد ونفس سؤال المستخدم. معالجة سبب HTTP 503 الخادمي وبقية تنميق الكابتن تحتاج مرحلة أخرى بالتكامل الواعي مع Codex المحلي.
7. **فيديوهات التمارين P1:** كتالوج 302 لا يثبت تنزيل/تشغيل 302؛ بوابة HEAD تتطلب Content-Length, ETag, byte ranges. يلزم اختبار أصل الفيديو/CDN و401/403/404/timeout عبر بيئة معزولة، لا تضحية بالتحقق من SHA أو تراخيص العرض.
8. **Android 16KB:** تشغيل AAB المجمد فشل أداة تدقيق ELF/Python بخطأ `NameError: sys not defined`؛ لا يدّعي هذا وحده ELF غير متوافق. يحتاج فصل خطأ checker عن فشل binary actual.

## بوابات القبول
- تشغيل `dart format` و`flutter analyze` مركزين، واختبارات: عدم تسريب توكن URLs والصور المحذوفة/تبديل مالك؛ 25 locales للمزامنة حسب السياسة؛ تأكيد شراء مرة فقط/إعادة تشغيل/إلغاء/حساب أو متجر مختلف؛ retry Coach مع استمرار نص الرسالة وعدم تأكيد عدم تغيير كل البيانات.
- منع أي شراء أو خدمة فعلية في CI؛ كل الأمثلة تابعة لاختبارات محلية SQLite/Flutter.
- بعد نجاح QA المركز، يبقى Full Flutter 9800+/Goldens، Play 16KB/native/SDK وiOS device وعمليات شراء Sandbox والتكامل الخادمي قبل تأكيد نسخ 37/33.
- لا يوجد امتياز لتغيير إنتاج أو نشر متاجر في هذا العمل؛ قرار النشر يحتاج خطوة مستقلة صريحة.

### First isolated CI feedback (before acceptance)
- Analysis passed; the first combined functional run exposed three purchase widget tests missing the required commerce fixture flags. The tests were not removed: a separate store_widgets job now uses a fake .invalid URL, mock store and blocked HTTP, without production requests or credentials.
- AI Coach source assertion was narrowed to the obsolete full phrase, preserving valid guarantees in other branches.
- Format output changed seven files in disposable CI; source formatting must be committed and a strict zero-diff format gate verified before final handoff.
