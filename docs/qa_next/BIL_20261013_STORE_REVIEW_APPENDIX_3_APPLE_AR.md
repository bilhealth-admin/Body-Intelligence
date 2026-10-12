# المراجع الثالث: Apple والخصوصية والواجهة

قرأ المراجع المستقل `/root/final_apple_privacy_review` النسخة الكاملة e9bab65c بتاريخ 13 أكتوبر؛ أعاد حساب SHA256 لجميع الملفات البالغ عددها 9727 وبصمة 5692 مدخلًا، دون اختلاف. لم يبنِ Swift أو يشغّل هاتفًا أو يعدّل متجرًا. المراجعة الأصلية للسياسات الكاملة ومصفوفة الانطباق محفوظة في الملحق 3 بتاريخ 12 أكتوبر؛ هذا فحص لفروقها، وليس ادعاء قراءة متجر جديدة.

وجد P2 في تعافي bootstrap: استخدام context.strings من State أعلى MaterialApp لا يملك AppLocalizations؛ لذلك يسبب فشل الحماية خطأ null-check عند بناء Retry. بعد تسليم القراءة، وبإذن محدد من الوكيل الرئيسي، أضاف المراجع delegates وBuilder محليًا واختبارًا للـState الحقيقية والقناة. تشغيل الاختبارات والإغلاق مسؤولية الوكيل الرئيسي. السبلاش والثيم والأذونات مستقلة ولم تتغير.

يستثني حاجز native آباء Application Support/Documents/Library Preferences من النسخ الاحتياطي ويقرأ خصائصها للتحقق. لا يقبل مسارًا من Dart ولا يحذف أو ينقل بيانات. ينتظر Dart التأكيد، ويدمج الطلبات، ويعيد التحقق عند الفتح؛ يستعمله 13 مسار AppSupport. الخطأ يبقي الكتّاب محجوبين ولا يغيّر بيانات الصحة. جهاز Apple وتجميع Swift وخصائص iCloud الفعلية غير مثبتة؛ لا ادعاء بتغيير build35.

راجع Before/Actual/Diff للحالة Golden259 منفردة: إضافة Terms/Privacy مع Restore/Manage والمجتمع المجاني واضحة. راجع صور Home والساعة والسبلاش المحفوظة. لا اعتماد جماعي أو تفسير HIG/Glass كرفض تلقائي. الصور ناتجة عن Widgets Flutter حقيقية، وليست artifact هاتف.

السياسات المنطبقة في [Apple Guidelines](https://developer.apple.com/app-store/review/guidelines/): 1.2 للمحتوى UGC، و1.4.1 للصحة والمصادر، و2.1 للاكتمال ووصول المراجع، و2.3 لـmetadata، و3.1.1/3.1.2 لـIAP/restoration/subscriptions، و5.1.1/5.1.2 للخصوصية والموافقة والحذف، و5.1.3 للصحة وiCloud. إعدادات SDK والتوقيع وPrivacy Manifest تحتاج فحص artifact بمصفوفة Xcode المثبتة؛ Source/Golden لا يثبتانها. الحساب الإضافي بحسب الدور، والحساب المنتهي لاختبار الشراء، يطابقان [Apple complete review](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/).

نبقي إدارة BIL بتفويض الخادم ونشرحها؛ لا يحصل المراجع على Owner لبيانات حقيقية. بيانات الصحة وAI تتطلب إفصاحًا وموافقة فعلية. لا ضمان قبول، ولا استبدال وظيفة بدليل مكتوب.

## تأكيد مستقل بعد الإصلاح

قرأ المراجع السجل الخام: 10 testStart فعلية و10 testDone success بلا skip أو error؛ ضمن 101 نجاح ثابت في المجموعة المتأثرة. أعاد Before خطأ AppLocalizations.of/ancestor context، والحالة المصلحة نجحت. الحاجز يبقي الكتّاب محجوبين حتى التأكيد، والسبلاش محفوظ، والضغط على Retry والرد المتأخر اختُبرا. البصمات في final-independent-fix-confirmations.json. لا تجميع Swift أو device/artifact أو حساب مراجعة فعلي مثبت.
