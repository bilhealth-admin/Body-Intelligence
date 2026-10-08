# BIL-05 — مصفوفة المتطلبات

| المتطلب | حالة BASE | التغيير المحلي | حالة التحقق |
|---|---|---|---|
| receipt لصاحب المنشور بعد approve/reject/edit-needed | غير موصول | SQL forward-only يولد Activity receipt من `POST_REVIEW` مع source_key ثابت؛ عقد الخادم يملك approved/rejected فقط، لذلك rejected يُعرض للمستخدم كـ«يحتاج تعديلات» بدل اختراع decision ثالث | فحص بنيوي PASS؛ PostgreSQL NOT_RUN |
| +5 AI Tokens فقط بإثبات خادم | grant موجود أصلًا داخل `bil_moderate_community_post` | parser لا يعرض +5 إلا مع `tokens_granted=5` و`reward_reason=granted`؛ لا يوجد ledger mutation جديد | static PASS؛ Dart NOT_RUN |
| عدم المنح عند daily cap | الخادم يرجع 0 | receipt منفصل بلا وعد بالمنح ونص UI شرطي | static PASS |
| duplicate approval/retry | RPC الحالية idempotent وتعود duplicate | source_key واحد + لا grant جديد | static PASS؛ PostgreSQL NOT_RUN |
| فصل AI Tokens عن Gold | `rewardEarned` كان يفتح Rewards/Gold ويعرض AI pill عام | post moderation receipt يفتح post receipt route؛ generic reward لا يُسمى AI | static PASS؛ route overlay انتظار دمج |
| صور حتى 4 في الإشراف | BASE يهدرج media لكن UI يعرض الأولى | grid يستخدم `mediaItems.take(4)` | source review PASS؛ Flutter NOT_RUN |
| poll في الإشراف | RPC العامة لا تكشف pending poll للمشرف | moderator-only poll projection + read-only preview | static PASS؛ PostgreSQL/Flutter NOT_RUN |
| نص كامل | موجود SelectableText | محفوظ بلا قص | source review PASS |
| pending/hidden/reports | موجود | badges واضحة؛ hidden يعرض review content عند توفره | source review PASS |
| صلاحية admin/ABA | mutation server-verified لكن page بلا visit دائم | `CommunityModerationVisit` + fresh role check + owner-run + retirement A→B→A | static PASS؛ Flutter NOT_RUN |
| readback بعد mutation | BASE snackbar ثم reload غير منتظر | reload/readback awaited قبل success | source review PASS |
| receipt→post/back | لا route مباشر | owned read-only owner page + shared route proposal | انتظار دمج؛ Flutter NOT_RUN |
| New/Earlier صفحتان + partial readback | موجود في BASE | لم يُهدم؛ readback logic محفوظ | BASE evidence + source review؛ regression NOT_RUN |
| notification أثناء acknowledgement | BASE يسقط refresh أثناء busy | queued attention refresh ثم drain بعد acknowledgement | source review PASS؛ Flutter NOT_RUN |
| failed RPC بلا retry loop | visible scope يحجب failed ids حتى explicit event | محفوظ؛ queued refresh لا يعيد نفس RPC ذاتيًا | source review PASS |
| private messages/friendship unaffected | owner-scoped activity seen RPC منفصل | لا تغيير لهذه العقود | source review PASS |
