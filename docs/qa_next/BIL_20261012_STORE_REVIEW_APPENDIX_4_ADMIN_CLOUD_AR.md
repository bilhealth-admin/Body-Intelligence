# ملحق 4 — إدارة BIL والمجتمع والمنح والسحابة

تاريخ القراءة: 12 أكتوبر 2026. المراجع مستقل وقراءة فقط: لا كتابة، لا اختبار جديد، لا بناء، لا منح، لا متجر، لا متابعة للشاملة. المصدر كامل وثابت مع العمل غير الملتزم فوق 2c518ee4 ؛ بصمة v4: `d47f536bf052cd139f94aa6da0295f1a74dcd70e82ef29fd2029370773c75b36` ، 9656 ملفًا/5680 مدخل تشغيل. الإصلاحات اللاحقة لها بصمة واختبارات مستقلة؛ هذه الملاحظات لا تصف نسخ المتجر بأنها تغيرت.

المراجع: `/root/store_review_admin_cloud`. القرار **KEEP** للإدارة المحمية بالدور. البريدللتنبيه،ليسدفترصلاحيةأوموافقةمالية. لا Premium/Tokens→Admin ؛مصدرالمنفذ Auth والتفويضخادمي و POST.

| الملاحظة | السبب / إعادةالإنتاجالمحددة | الأثر والحد |
|---|---|---|
|P2 قفلصلاحيةالمنحفقطللاشتراك|require_administrator الجديديقفلصفالدور؛ RPCgift/compensation/reset تفحص EXISTS دونقفل؛أمسكصفالرصيدثمابدأمنحةواسحبالدورثمحررالرصيد|قدتلتزمالمنحةبعدالسحب؛ sourceconcurrency غير مختبرعلى Production ،مسارسابقلمينغلقبـ Admin7|
|P2tombstone غذاءعلىهدففارغ|A يحذف F ؛ Boffline يرفعوجبةجديدةبتعريف F القديم؛ C يستقبل tombstone ثم dependency ؛ rows221 يعودإذا F غائب، rows182 يدرج F نشطًا|الإحياءالمحليممكن،الخادم CAS يرفضإحياءهفيبقى conflict ؛اختبار tombstone السابقبدأبهدفمعبأ،ولا يثبتهذهالحالة|

المكتمل:إلغاءمنحةلا يحذفشراءالمتجر؛ CommunityV2 يحتفظبنسخةالمحتوىويقفلالدوروالمكافأةومفتاحالتكرار؛القرارالمالياللاحقللإدارةفقطوحدالمكافأةالأصليلايُلتفحوله. publish-only معطلافتراضيًا. العناوينلاتوعدبرصيددونإيصال.

CloudV2 إضافيمنفصلعن V1 ، owner من auth.uid ، consent/device/CAS/idempotency/tombstone/AES. migrationSHA`ccacdcef47bf2ff0e3d438826da6fc285015c4554e157834bdea052b5ee73966`. سجل SQL23 ودورة SQLiteA→PostgreSQL→SQLiteB حقيقيان محليًا؛**ليس Production ولا SupabaseAuth/PostgREST كاملًاولاهاتف 32/35**. غياب V2 يعرضعدمإتاحةصادقًا؛لايرسلمعنىجديدًا لـ RPC قديمة.

| دور فعلي / وظيفة | الفصل المطلوب |
|---|---|
|المستخدمالعادي/Premium/Boost|لاسلطةماليةأوإداريةمنالشراء|
|مشرفمحتوى/مجموعة|قرارمحتوىضمننطاقه،ليسمنحاشتراكأوتوكنات|
|إدارةالمنحالمخولـة|طلب POST وهوية Session تحققهالخادمومستفيد UUID وإيصال/idempotency|
|المالك|عملياتواسعةلا تُعطىلمراجعالمحتوى؛حدودالسياسةالكبيرةتحتاجقرارمالكولاأرقاممخترعة|

طريقةالمراجعة:حسابإداريمنفصلعلىبياناتتركيبيةوبيئة/نطاقمعزولمعلن،بنفسالتنفيذالحقيقي؛لا demo مزيفةولا ownerfinancialrights علىمستخدمينحقيقيين. الحسابلم يُنشأأويُختبر. NotesforReview تشرحالإدارةوالأدواروالعتادوالوصول؛لاتخفىالإدارةكتحايل.

| مرجع رسمي 12Oct | بند/نوع/الإجراء |
|---|---|
|[Apple Guidelines](https://developer.apple.com/app-store/review/guidelines/) |2.1/2.3/3.1/5.1 و TestFlight حوافز،إلزامي؛ disclosure/access/paidcredits و consent ؛وجودالإدارةليسسببرفضتلقائي|
|[Google App access](https://support.google.com/googleplay/android-developer/answer/15748846) و[transparency](https://support.google.com/googleplay/android-developer/answer/17006354) |إلزامي، الأدوارووظائفحقيقيةوقابلةللمراجعة|
|[PaymentsFAQ](https://support.google.com/googleplay/android-developer/answer/10281818) و[Ratings](https://support.google.com/googleplay/android-developer/answer/9898684) |مشتَرى/مكتسب/منحة منفصلة،لا revieworinstallreward|
|[UGC](https://support.google.com/googleplay/android-developer/answer/9876937) |بلاغوحظرداخلالتطبيق،استجابةوسلامةالمكافآت|
|[SupabaseRLS](https://supabase.com/docs/guides/database/postgres/row-level-security) و[migrations](https://supabase.com/docs/guides/deployment/database-migrations) |تقني/أمني:auth.uid/ACL/search_path/GRANT والتوافق/backup ؛فحصمصدرليسفحص Production|

المتبقي المحدد:إصلاحواختبارالسباقوال tombstone محليًا،قراراتالمالكالتشغيليةوحقوق المراجعة،نشرمأذونبعد backup/ACL/RLS/compatibility ،ثم deviceAuth/restart/keys/import/restore. الوثيقتانالسابقـتان«استعادة nutrition غيرمنفذة»تصفانمرحلة 11Oct ؛الوثيقةالأحدثتكملالتنفيذالمحلي. عدمالنشرليسبديلًالتصحيحعيبكود.
