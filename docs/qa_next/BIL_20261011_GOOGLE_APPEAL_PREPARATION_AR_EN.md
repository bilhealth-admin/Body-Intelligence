# Google enforcement: evidence and an unsent appeal draft

فحص الأدلة الأصلية: 2026-10-11. الحزمة: `com.bilhealth.bodyintelligencelog`.
أكد المالك في هذه المهمة أنه **لم يقدم استئنافًا لقرار التعليق نفسه**. لم نرسل استئنافًا أو رسالة ولم نغيّر Console.

## Original decisions

| القرار | الدليل الأصلي | ما يثبته وما لا يثبته |
|---|---|---|
| 15 سبتمبر: Broken Functionality | بريد `1a0a8b77579fcd7a`، الصورة `IN_APP_EXPERIENCE-2101.png` | الصورة تُظهر شراء الشهرية والسنوية ورسالة المتجر أن العنصر غير موجود. لا تثبت أن كل أزرار التطبيق معطلة. SHA256: `DBEC6AD649C0300F36388B21AB8726746E5B3CBE9C4F26FBAA505266AA496119`. |
| 15 سبتمبر: Excessive Data Access for Declared Feature | بريد `1a0a8b76655ed230` | Android13 وقراءات BodyFat / RestingHeartRate / SleepSession مذكورة صراحةً. لا يجوز نسب هذا الإشعار تلقائيًا إلى 32. |
| 2 أكتوبر، 22:04 -07 | بريد `1a1002638f11e217` | رفض بسبب حجب المحتوى بالدفع؛ لا نختلق رقم نسخة غير مثبت في نص الإشعار. |
| 8 أكتوبر، 10:01 UTC: Rejected | بريد `1a11af591a4d0cb9`، versionCode32 | السبب الحرفي: `App content is restricted by a paywall`. الصورة `IN_APP_EXPERIENCE-6955.png` تُظهر مسار الإرشادات→Home→المزامنة→Goals→أهداف المغذيات→Plans. لا تكفي الصورة لمعرفة هوية الجلسة أو نتيجة تحقق الصلاحية. SHA256: `5F518CED5FF22A2D11038D1D77738C45C9FBE154C4D6DFFEA51F97BFD3B7BBD4`. |
| 8 أكتوبر، 19:38 UTC: Suspended | بريد `1a11d06ac8638e5b` | السبب الحرفي: `Repeated app rejections` ضمن Enforcement Process. التعليق مختلف عن رفض تحديث، ولا يثبت إنهاء حساب المطور. |

الملفات الأصلية محفوظة محليًا في `build/stage1-closure/google-original`؛ لا ننشر البريد أو روابط التحميل الموقعة أو بيانات دخول المراجع.
تعذرت قراءة الحالة الحالية في Play Console وApp Store Connect: اتصال المتصفح فشل عند الحصول على حالة الصفحة. تصريح المالك بأن build35 تحت المراجعة محفوظ، لكنه ليس قراءة مستقلة للحالة الحالية.

## Source findings and boundaries

المصدر المعلن لنسختي 32/35 هو `3f0085e6e6686f2e87e9cf14789e9e578ea64159`، وليس الكود المحلي المعدّل.
قراءة هذا المصدر أثبتت وجود preflight جديد للشراء في `verified_store_purchase_checkout.dart` يعيد الاستعلام عن المنتج قبل شراء فعلي. لذلك لا نستنتج أن عيب سبتمبر ما زال حاضرًا في 32 من الصورة القديمة. توفر المنتج الفعلي في بلد المراجع وعلى Play هو فحص متجر/جهاز ما زال مطلوبًا.
Manifest في المصدر نفسه، وفي الكود الحالي، يطلب Health Connect Steps/Distance/ActiveCaloriesBurned فقط؛ الأذونات الثلاث المرفوضة في13 غير موجودة في Manifest32. ذلك فحص مصدر، وليس تقريرًا عن الأذونات المعروضة على جهاز Play.

الاشتراك، رصيد AI، ودور الإدارة مسارات منفصلة. تجربة المالك بحساب Admin على35 لا تثبت تجربة حساب المراجع.
في المرحلة الحالية أصلحنا نطاق القفل: العنوان والأسماء والوحدات والمساعدة خارجه، والقيم المدفوعة وحدها محجوبة؛ Loading/Error لا يصبحان Free ولا ينتجان انتقالًا تلقائيًا إلى Plans. الواجهة الجديدة لا تحمل محتوى خاصًا للمعاينة دون تفويض. سجل الاختبارات النهائي يحدد الحالات والنسخة المختبرة.
لم نُعدّل binary32/35، ولم ننشر migrations أو Edge Functions. وظيفة `food-search` المنشورة ما زالت v60؛ تعديل memo محلي فقط.

## Readiness decision

**الملف ليس صالحًا للإرسال بوصف جميع المخالفات مُغلقة الآن.** الموانع المحددة هي:

1. غياب دليل دخول بارد ودافئ لحساب المراجع على artifact Play الفعلي، ثم فتح وإجراء وظيفة والرجوع بلا Plans غير مطلوب، مع رقم النسخة وبصمة artifact.
2. عدم قراءة الحالة الحالية للتعليق أو توفر المنتجات الفعلية في Console. يجب التحقق من الشهرية والسنوية على جهاز/متجر مأذون دون شراء حقيقي في هذه المهمة.
3. التغييرات المحلية الجديدة ليست نسخة متجر، وعقد المجتمع V2 وmemo البحث لم يُنشرا. لا يجوز وصفهما كخدمات متاحة للمراجع الآن.

هذه موانع إثبات ومطابقة نسخة، وليست انتظارًا لإنهاء Polish. يمكن للمالك بعد توفير الدليل الناقص واعتماد النص إرسال استئناف واحد عبر المسار الرسمي. لا نغيّر اسم الحزمة ولا ننشئ تطبيقًا لتجاوز التعليق. [Google enforcement/appeals](https://support.google.com/googleplay/android-developer/answer/2477981).

تعليمات المراجع يجب أن تكون بالإنجليزية، قابلة لإعادة الاستخدام، بلا شراء أو OTP إضافي، ومع وصول لكل الوظائف المطلوبة. تُجهّز البيانات في قناة آمنة ولا تُضاف إلى GitHub. [App access](https://support.google.com/googleplay/android-developer/answer/15748846).

## English draft — NOT SENT, complete evidence before use

Subject: Appeal preparation — Body Intelligence Log / com.bilhealth.bodyintelligencelog

Dear Google Play Policy Team,

We are requesting review of the suspension dated 8 October 2026 for repeated app rejections. We acknowledge the earlier reviewer-access issue described as “App content is restricted by a paywall,” the earlier purchase-item availability failure, and the Health Connect permission scope issue identified for version13.

We have reviewed these as separate issues. Our source changes and focused validation distinguish authentication, server-verified entitlement, AI credit and administrative authority. Entitlement verification failures do not redirect a reviewer to purchase, and access to reviewable functionality must not require a payment card or earned rewards. Paid-feature names remain readable while private paid values and actions remain protected.

The corrected source is [insert tested commit and evidence link after final closure]. It has not changed the already-delivered version32 binary. No new production backend changes have been deployed as part of this phase. [Insert the exact artifact version, source SHA, artifact SHA256 and clean-install reviewer test evidence when available. Do not replace this with local UI screenshots.]

We will provide reusable English reviewer instructions and secure credentials through App Access, with the required entitlement and AI balance verified through the normal server authorization model. There is no reviewer identity hidden in the mobile application and no requirement to buy or post to the community to complete review.

If the suspension prevents uploading a corrected release, please advise the official route for submitting the corrected artifact for review. We are not claiming that version32 has been updated or that the suspension has been lifted.

[Attach the completed issue-by-issue remediation evidence and confirm whether any other applications in the developer account need correction before submitting.]

Thank you for reviewing our request.

Body Intelligence Log team
