# ملحق 2 — Google والتعليق والاستئناف

تاريخ القراءة: 12 أكتوبر 2026. المراجع مستقل وقراءة فقط: لا كتابة، لا اختبار جديد، لا بناء، لا منح، لا متجر، لا متابعة للشاملة. المصدر كامل وثابت مع العمل غير الملتزم فوق 2c518ee4 ؛ بصمة v4: `d47f536bf052cd139f94aa6da0295f1a74dcd70e82ef29fd2029370773c75b36` ، 9656 ملفًا/5680 مدخل تشغيل. الإصلاحات اللاحقة لها بصمة واختبارات مستقلة؛ هذه الملاحظات لا تصف نسخ المتجر بأنها تغيرت.

المراجع: `/root/store_review_google`. راجع Gmail الأصلي وصورالمرفقاتالمحفوظة وسياسات Google الحالية والمصدرالثابت. لا Appeal وفقإجابةالمالك؛لم يُنشئهأويرسله.

| القرار الأصلي | النسخة / الدليل | الحكم الصحيح |
|---|---|---|
|16 سبتمبر: HealthConnect غيرمبرر|13 ؛ BodyFat/RestingHeartRate/SleepSession|الأذوناتمصُححةبالمصدربـ Steps/Distance/ActiveCaloriesBurned فقط؛يلزم mergedmanifest وهاتفو Consoledeclaration|
|16 سبتمبر: BrokenFunctionality/UnresponsiveUI|مرفق 2101 ، SHA256`DBEC6AD6…496119` مطابقسجلالمرفقالقديم|الصورةتُظهرمنتجشراءلميمكنالعثورعليه؛لااختراع version أوإرجاعالسببإلى Google بلا catalog حي|
|3 أكتوبر: paywall|مرفق 4980 ؛لا version في body|يخصرحلته،لا يُفترضبقاءكلهفي 32|
|8 أكتوبر 10:01:02UTC: Rejected/PlayConsoleRequirements|32 ؛ IN_APP_EXPERIENCE-6955 ؛ SHA`5F518CED…3B7BBD4` مطابق|Goals→Plans ظاهر؛الصورةلا تثبتهويةالجلسةأواستحقاقالخادم|
|8 أكتوبر 19:38:58UTC: Suspended/EnforcementProcess|Repeatedapprejections|تعليقالتطبيق،وليسإثباتإنهاءحسابالمطورأوحذفالبيانات|

الصورالأصليةشوهدتمن `build/stage1-closure/google-original/6955` و 2101 ؛بصماتهاماتطابقوثيقةالاستئنافالمحفوظة. أسماءالملاحظاتالرسميةمنالبريدلا تُستبدلبتفسيرالصورة.

محاولة Console12 أكتوبر 20:00UTC: التبويب PolicyStatus موجود،لكن CDP فشلمرتينعند Emulation.setFocusEmulationEnabled(10s). لم ينقرويعيدالتحميل. أحدثحالة Console/Appeal/tracks/IAP/AppAccess غير متحققة؛عنوانالتبويبوخبرالاختفاءليساإثبات حالة.

فيالمصدر:targetSdk/compileSdk36 ؛ in_app_purchase_android0.5.2 يقفل Billing8.0.0 بالمصدرالرسميللحزمة؛لا AAB/dependencygraph نهائي. البواباتتميز Checking/Retry عن Free ،والـ Plans فعلاختياري؛الرصيدوالدورمستقلان. إبلاغ AI وسيرطلبحذفالحسابموجودان،لكن completion والروابطالخارجيةوالخادم المنشورغيرمثبتة.

| سياسة رسمية / تاريخ 12Oct | النوع / الانطباق | الدليل والإجراء الأدنى |
|---|---|---|
| [App Access](https://support.google.com/googleplay/android-developer/answer/15748846) |إلزامي،  paid/AIlogin|حسابثابتبلادفعأو OTP ومُجربعلى artifact|
| [Suspension/Appeal](https://support.google.com/googleplay/android-developer/answer/2477981) |إلزامي، قضية 8Oct|Appeal واحدةبإذنالمالك؛ draft الآندونانتظار Polish|
| [Payments](https://support.google.com/googleplay/android-developer/answer/10281818) |إلزامي، مشتَرىمقابل مكتسب|لاتبديلالعملةأوحقوقالشراءولا incentivereview|
| [User Data](https://support.google.com/googleplay/android-developer/answer/10144311) |إلزامي،  health/auth/SDK|مطابقة DataSafety/سياسةالحذفوالاحتفاظوالتشفيروال consent للاستخدامالفعلي|
| [Health apps](https://support.google.com/googleplay/android-developer/answer/16679511) |إلزامي،  HealthConnect|تبريرالنطاقالمستخدمفقط/تصريحصحي؛لاادعاءجهازطبي|
| [Permissions](https://support.google.com/googleplay/android-developer/answer/16558241) |إلزامي، صورة/ميكروفون|إذنلحظةالاستخدام،لاتوسيعالنطاقبلامبرر|
| [UGC](https://support.google.com/googleplay/android-developer/answer/9876937) |إلزامي،  community|بلاغ/حظر/قبولالشروطواستجابةتشغيلية|
| [GenerativeAI](https://support.google.com/googleplay/android-developer/answer/13985936) |إلزامي،  Coach/Vision|إبلاغ AI الموجوديحتاجرحلةجهازوخادمفعلي|
| [TargetAPI](https://support.google.com/googleplay/android-developer/answer/11926878) و[Billing](https://developer.android.com/google/play/billing/integrate) |نشر تقني|API36 و Billing8 بالمصدر؛يلزم artifact نهائي،لاترقيةعشوائية|
| [Policy corpus](https://play.google.com/about/developer-content-policy/) |عمر/شفافية/روابط/metadata|Health ليستشرط 18+عامًا؛إعلانالفئةالحقيقيةولاوعد Story غيرمنفذة|

القرار: **قبل الإرساليَلزم artifact مصحح+حسابمراجعةفعليمُجرب+إثباتمعالجةالأذونات/الشراء/paywall ومطابقةخدماتوإعلاناتالمتجر**. البناءليس مأذونًا بهذهالمراجعة؛خطوتهطلبإذنمحددبعدتثبيت SHA والاختبارات. عندمنعالرفع/IAP بسببتعليق Console يشرح appeal ذلكويطلبالمسارالرسمي لإعادةالتقديم،لايعالَجكتعطيلكودولايُشترطرفعقبلإعداد Appeal. Android32 لمتتغير. لا إرسال الآنولااستئنافمكررولاضمانقبول.
