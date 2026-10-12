# المراجع الثاني: Google والتعليق والاستئناف

المراجع المستقل `/root/final_review_decision_draft`؛ قراءة فقط بتاريخ 13 أكتوبر 2026، على النسخة الكاملة الثابتة e9bab65c. قرأ الرسائل الأصلية الخمس في Gmail، والمرفقين المحليين 2101 و6955 وبصماتهما، والسياسات الرسمية. لم يشغّل اختبارات أو يغيّر Console أو يرسل رسالة.

| توقيت UTC الأصلي | القرار المثبت |
|---|---|
| 16 سبتمبر 05:36:26 | أذونات Health Connect مفرطة، version13: BodyFat/RestingHeartRate/SleepSession |
| 16 سبتمبر 05:36:28 | Broken Functionality/Unresponsive UI؛ المرفق 2101 يعرض item could not be found؛ رقم النسخة غير مذكور في النص |
| 3 أكتوبر 05:04:26 | paywall؛ المرفق 4980؛ رقم النسخة غير مذكور |
| 8 أكتوبر 10:01:02 | paywall/Play Console Requirements، version32؛ المرفق 6955 يعرض Goals→Plans |
| 8 أكتوبر 19:38:58 | Suspended بسبب Repeated app rejections؛ لا إثبات لإنهاء حساب المطور أو حذف بيانات BIL |

اختلاف هذه التواريخ عن 15 سبتمبر و2 أكتوبر في الوثائق القديمة ناتج عن عرض UTC مقابل -0700، وليس قرارًا إضافيًا. أكد المالك عدم تقديم Appeal للتعليق نفسه. المرفق لا يثبت هوية جلسة المراجع أو استحقاقها.

يجهز المصدر API36 وAndroid IAP0.5.2/Billing8؛ لم يُثبت ذلك في artifact أو merged manifest/dependency graph. حالات Checking/Error تعرض retry؛ اختيار الصور نظامي دون صلاحيات التخزين القديمة؛ نطاق Health Connect هو Steps/Distance/ActiveCalories فقط؛ وروابط HTTPS للشروط والخصوصية فعلية. لم تتغير binary32، والمرشح 33 غير مبني. لم تُنشر العقود المحلية الجديدة.

القرار: المسودة جاهزة، لكن ملف الإثبات غير جاهز للإرسال. المتطلبات الثلاثة المحددة هي: artifact مصحح وبصمته وجهازه؛ حساب وصول فعلي مستقر ومجرّب دون شراء أو بطاقة أو OTP غير متاح أو نشر لكسب الرصيد؛ ومطابقة كل مخالفة مع نسختها وخدماتها وmetadata والأذونات والمنتجات. يتطلب البناء وتهيئة الحساب والنشر عند الحاجة إذنًا منفصلًا. لا انتظار لـPolish غير متعلق، ولا اشتراط رفع نسخة إلى Play إذا منع التعليق الرفع؛ يُطلب مسار إعادة التقديم الرسمي مع شرح القيد.

| مصدر رسمي مقروء في 13 أكتوبر | الانطباق والنوع |
|---|---|
| [App Access](https://support.google.com/googleplay/android-developer/answer/15748846) | إلزامي: دخول ووصول متكرران من أي موقع، وتعليمات إنجليزية |
| [Enforcement](https://support.google.com/googleplay/android-developer/answer/2477981) | إلزامي: المسار الرسمي لاستئناف التعليق؛ لا تحايل بحزمة بديلة |
| [Target API](https://support.google.com/googleplay/android-developer/answer/11926878) و[Billing](https://developer.android.com/google/play/billing/deprecation-faq) | متطلب نشر تقني: API36 وBilling8+؛ يلزم artifact لإثباتهما |
| [User Data](https://support.google.com/googleplay/android-developer/answer/10144311) | إلزامي: مطابقة الجمع الفعلي وSDKs والحذف والسياسة العامة وData Safety |
| [Health Content](https://support.google.com/googleplay/android-developer/answer/16679511) | إلزامي: التصريح الصحي والعتاد والتوافق، وتجنب ادعاء طبي غير مثبت |
| [UGC](https://support.google.com/googleplay/android-developer/answer/9876937) و[AI Content](https://support.google.com/googleplay/android-developer/answer/13985936) | إلزامي: قبول الشروط والبلاغ والحظر والاستجابة، وإبلاغ محتوى AI داخل التطبيق |
| [Payments](https://support.google.com/googleplay/android-developer/answer/10281818) | إلزامي بحسب البرنامج والمنطقة: فصل المبيع عن المكتسب والمنح؛ لا تعميم لاستثناء بلد |

لم تثبت حالة Console الحالية أو مسارات الإصدار أو App Access أو IAP. لا نستنتج أن metadata الحالية خاطئة؛ تُقارن لاحقًا بالمنتج الفعلي. تغيير الصور بسبب Polish اختياري، ويجب أن يطابق النسخة المقدمة. لا ادعاء بوجود Story غير منفذة أو قبول مضمون.
