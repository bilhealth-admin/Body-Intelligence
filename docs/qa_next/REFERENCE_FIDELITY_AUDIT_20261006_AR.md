# تدقيق مطابقة مراجع Community وAI Coach — 2026-10-06

## الحالة والنطاق

هذا مستند تدقيق، وليس إعلان إغلاق بصري أو وظيفي. الصور المفحوصة خرجت من Flutter عند checkpoint `86bc94851b1020b0533956328d577292b39a1da1` على الفرع المأذون `qa/coach-community-next-20261005`. جرت أيضًا قراءة المصدر الجاري بعد هذا checkpoint، مع الفصل أدناه بين نتائج الصورة الثابتة وإصلاحات المصدر التي تحتاج إعادة التقاط.

لا يثبت نجاح اختبارات الالتقاط مطابقة المرجع. ملف `effective-source.json` داخل artifact يصرح بأن `reference_parity_verified: false`، وأنه لم يُنشأ store build ولم يتصل التنفيذ بـProduction. لم تُعدّل الصور الأصلية، ولم يُعتمد screenshot حالي باعتباره golden بديلًا.

## الأدلة القابلة للتتبع

| العنصر | القيمة |
|---|---|
| المستودع | `bilhealth-admin/Body-Intelligence` |
| SHA صور Flutter | `86bc94851b1020b0533956328d577292b39a1da1` |
| Workflow run | [37496383841](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37496383841) |
| Artifact | [11427204445](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37496383841/artifacts/11427204445) |
| Artifact metadata API | [GitHub artifact metadata](https://api.github.com/repos/bilhealth-admin/Body-Intelligence/actions/artifacts/11427204445) |
| SHA256 لملف ZIP الذي نُزّل وفُحص | `50491544230880bf9b16812a98119726404b8cd68835f0a5fde56aac0ab58018` |
| حجم ZIP | `21,879,122` bytes |
| أدوات إنشاء الصور وفق artifact | Flutter `3.44.6` stable، Dart `3.12.2` |
| مصدر manifest | `effective-source.json` داخل artifact؛ يضم SHA المصدر وبصمات الملفات المسجلة في عملية الالتقاط |

المراجع الأصلية موجودة في حزمة المالك `BIL_HANDOFF_2026-10-06.zip`، وليست مضافة إلى المستودع بواسطة هذا التدقيق:

| المرجع الأصلي | الأبعاد | SHA256 الملزم |
|---|---|---|
| `references/COMMUNITY_APPROVED.png` | `1122×1402` | `db67d1c6bb1f4ecd3c539ada3de72a980c610b7c1d2331c4796b7fa27e3bbea4` |
| `references/AI_COACH_APPROVED.png` | `1024×1536` | `07f25ba0fffc661e5232a4fba6365ee3ff96cbea69636c2672b97f4fafce63d0` |

### ماذا يغطي الالتقاط الحالي؟

يوجد داخل artifact مجلد `community/` يحوي **144 PNG**: ثمانية سيناريوهات لغة/مظهر/حجم نص، لكل منها 18 اسم واجهة. السيناريوهات الثمانية هي `en/ar × light/dark × 1/2`؛ لا تعني ثمانية أسطح المرجع.

الأسماء هي: `actions`, `chat`, `comments`, `composer`, `creator_profile`, `feed`, `find_people`, `friends`, `member_profile`, `messages`, `my_code`, `my_posts`, `profile`, `rewards`, `safety`, `saved`, `updates`, `welcome`. مثال تسمية: `community/feed_en_light_1.png`.

مصدر هذه المصفوفة هو `test/features/community/community_polish_visual_test.dart`. الـviewport المنطقي `414×896`، والإخراج بنسبة `1.5`، فتبلغ الصور `621×1344`. لا تتضمن المصفوفة صورًا لصفحة Drafts المستقلة أو Circles أو طابور moderation.

يوجد أيضًا مجلد `coach/` يحوي **10 PNG** ضمن سبعة اختبارات في `test/qa_next/coach_reference_workspace_capture_test.dart`، بما يشمل workspace بلغتين ومقياسي نص، timeline، locked state، ومحادثة محفوظة. صور Coach بحجم `780×1688`.

لوحتا المرجع تحتويان هواتف ومحتوى بأبعاد مختلفة عن مخرجات الاختبار. لم يُحسب pixel score أو MAE؛ سيكون ذلك مضللًا دون ضبط viewport وحالة البيانات وحدود الجزء المقارن. المطابقة أدناه فحص بصري للمكونات وترتيبها، مع مراجعة المصدر لتحديد الوظائف الموجودة والناقصة.

## مصفوفة أسطح Community الثمانية

| السطح | دليل الصورة الحالية | الموجود فعليًا | اختلاف المصدر/الواجهة | فجوة الالتقاط والتحقق المتبقية |
|---|---|---|---|---|
| **1. Home / Explore** | `community/feed_en_light_1.png` | العنوان والبحث والإشعارات، Explore/Following/Circles، مداخل إنشاء المنشور، الشريط السفلي، وبطاقة منشور فعلية. | صف Explore ثانٍ أسفل التبويبات، ومسافات ومربع بدء نشر أكبر من المرجع. البطاقة تضيف دائرة/عدد منشورات/وسوم/معاينة تعليق ضمن ترتيب أكثر طولًا. شريط التفاعل يستخدم thumbs-up والمشاهدات وقلبًا منفصلًا، بينما المرجع يفصل like/comments عن bookmark/share في صف مدمج. | أول منشور في fixture بلا صور؛ هذا لا يثبت غياب gallery. يلزم منشور بأربع صور وavatars محملة، ثم مقارنة ارتفاع البطاقة وترتيب العنوان/النص/Read more/الصور/الإجراءات. |
| **2. Notifications / Activity** | `community/updates_en_light_1.png`، `community/updates_ar_dark_1.png` | رأس Notifications وعودة وإعدادات وفلاتر All/Approvals/Mentions/Comments وقسم New وحدث فعلي. المصدر يضم تقسيم New/Earlier وأجزاء reward receipt. | مصدر checkpoint كان لا يعرض incoming requests/unread messages رغم جلبها. الإصلاح الجاري يعيد ملخصات العدد authoritative ويمنع all caught up كاذبة؛ هذه الصور تسبقه. الشريط السفلي فاتح داخل dark mode. | fixture يعرض قبول صداقة واحدًا. يلزم approval + AI-token receipt + like + comment preview + mention + Earlier، إضافةً إلى counts/retry/return. يجب إعادة الالتقاط بعد الإصلاح الجاري، مع الاحتفاظ باختبارات dwell/foreground/owner/partial readback. |
| **3. Composer** | `community/composer_en_light_1.png`، `community/composer_ar_light_2.png` | عنوان/body، صور، poll، location، circle، mentions/collaboration، hashtags، save/publish ومسار retry. إصلاحات R5 owner/proof وUnicode جارية في المصدر. | النموذج أطول من المرجع: حقول كبيرة، مربع Media، أقسام hashtags/topics، شريط خيارات أفقي، ثم Save draft/Add photo/Publish في ثلاثة صفوف كاملة. AppBar لا يحتوي Drafts(count). المرجع يستخدم رأس Create a Post، صف صور مدمجًا، خيارات اختيارية في صفوف قصيرة، وزري Save draft/Publish متجاورين. | يلزم التقاط إدخال حقيقي بأربع صور/poll/موضوعات، مع body عند الحد، ثم error/retry وretained input وعودة Drafts. وقوع خيارات تحت الجزء المرئي لا يعني أنها غير منفذة. |
| **4. Profile** | `community/creator_profile_en_light_1.png`، `community/member_profile_en_light_1.png` | صورة غلاف/avatar، اسم ومقاييس وbio وأفعال حساب/صداقة؛ self quick actions حقيقية: My posts/Drafts/Saved/Stats. | hero أعلى وأكثر ازدحامًا مع contributor/level/progress panel إضافية. تبويبات المحتوى Moments/Reviews، بينما المرجع Posts/Replies/Media/Likes. الصفحة المستقلة لا تضع dock في Scaffold. | الغلاف/avatar الفارغان في fixture لا يثبتان غياب دعم الصور. يلزم fixture بصور عامة مصرح بها ومنشورات متنوعة؛ لا اختلاق profession/location/website أو Premium badge ولا تغيير privacy للمطابقة. الإصلاح الجاري يعالج keys وresponsive filter، وليس كامل المطابقة. |
| **5. Drafts** | **لا صورة للصفحة المستقلة.** `saved_*.png` تمثل Saved فقط. | `/community/drafts` مستقل عن وجود profile؛ cards تحوي title/excerpt وآخر حفظ وphoto count/poll/topics وEdit/Continue وselect/delete. | `_previewTile` يستخدم صورة واحدة `112×94` مع `+N`، بينما المرجع يعرض collage ‏2×2. ترتيب metadata يحتاج مقارنة مباشرة. | يلزم التقاط مسودتين غنيتين بالصور/poll، وحالة حساب بلا profile، ثم editor return وsave/retry/select/delete. لا يُقبل Saved screenshot دليلًا على Drafts. |
| **6. Circles / Groups** | **لا صورة.** | تحميل الدوائر وJoin/Leave/Pending وrefresh، مع فتح feed الدائرة وإمكانية النشر فيها. | الصفحة قائمة Cards بوصف ومقاييس وأفعال. لا تحتوي Search + Create + Discover/My Circles/Invites كما في المرجع. | يلزم بناء/ربط بنية الصفحة المطلوبة من بيانات العضوية الفعلية، ثم التقاط discover/member/pending/invite/empty/error states. لا تُضاف أزرار شكلية دون مسار repository. |
| **7. Community Chat** | `community/chat_en_light_1.png` و`community/messages_*.png` | محادثات خاصة: thread مع مستخدم واحد، تحميل الرسائل وإرسالها، وقائمة inbox حسب الطرف الآخر. | هذه المسارات تستخدم `loadMessages(userId)` و`sendMessage(to)`؛ لا تمثل قائمة channels المرجعية General/Nutrition/Workouts/Mindset، online count وunread لكل channel. البحث داخل feature لم يجد تنفيذ channel/group-chat مستقلًا. | يجب ربط قدرة channel/community chat المطلوبة، ثم اختبار عضوية/قراءة/إرسال/account switch وcapturing. لا تُعاد تسمية private chat باعتبارها إغلاق السطح المرجعي. |
| **8. Moderation / Earn** | `community/rewards_en_light_1.png`، **دون صورة لطابور moderation** | يوجد مصدر moderation فعلي يقرأ pending/hidden/reports، ويطلب تأكيد approve/reject، ويعرض نتيجة `tokensGranted == 5` وduplicate. | الصورة تعرض BIL Gold quests، وليس review queue أو AI-token receipt. `_routeForAction` يعيد `/community` لأفعال valuable_post/create_post/community_post؛ لا يفتح composer مع شرح المكافأة. | يلزم capture للـqueue وapprove/reject/readback/duplicate ثم +5 AI-token author receipt. ربط Earn → composer مع eligibility explanation وبلا auto-publish، مع إبقاء نظام Gold منفصلًا وسياساته القائمة. |

### نقاط المصدر التي يجب تطويرها مباشرة

جميع المسارات أدناه نسبية إلى جذر المستودع؛ لا توجد نسخة UI موازية معتمدة بديلًا عنها.

| السطح | نقاط المصدر |
|---|---|
| Home | `lib/features/community/presentation/community_feed_reference_header.dart`؛ `community_feed_tab.dart`؛ `community_post_card.dart`؛ `community_post_widgets.dart` في المجلد نفسه |
| Activity | `lib/features/community/presentation/community_notifications_page.dart`؛ `community_notifications_rendering.dart`؛ `community_notifications_reference_widgets.dart`؛ `community_notification_read_receipts.dart`؛ `community_visible_activity_scope.dart` |
| Composer | `lib/features/community/presentation/community_post_composer_page.dart`؛ `community_post_composer_rendering.dart`؛ `community_post_composer_reference_sections.dart`؛ `community_post_composer_toolbar.dart`؛ `community_post_composer_owner_scope.dart` |
| Profile | `lib/features/community/presentation/community_member_profile_page.dart`؛ `community_member_profile_header.dart`؛ `community_member_profile_content.dart`؛ `community_member_profile_creator_widgets.dart` |
| Drafts | `lib/features/community/presentation/community_member_profile_drafts.dart`؛ `community_drafts_rendering.dart`؛ `lib/app/router/app_community_routes.dart` |
| Circles | `lib/features/community/presentation/community_circles_page.dart` |
| Chat | `lib/features/community/presentation/community_messages_page.dart`؛ `community_chat_page.dart` |
| Moderation/Earn | `lib/features/community/presentation/community_post_moderation_page.dart`؛ `community_rewards_page.dart`؛ `community_rewards_cards.dart` |

## الشريط السفلي الملزم من مرجع Coach

المكوّن الحالي `lib/shared/widgets/bil_reference_bottom_bar.dart` يستخدم الترتيب المنطقي الصحيح **Home / AI Coach / Quick Add / Community / More**، وتنعكس جهة العرض في RTL. هذا هو قرار المالك حتى داخل Community؛ لا تُنسخ تسميات الشريط الأقدم من لوحة Community عند تعارضها معه.

فجوتان مثبتتان في المصدر وقت التدقيق:

1. `BilReferenceBottomBar.dark` افتراضيًا `false`. استدعاءا Community Hub وNotifications لا يمرران `dark`، بينما Coach يمرر `true`. لذلك تظهر قاعدة بيضاء فاتحة داخل لقطة `updates_ar_dark_1.png` الداكنة. نقاط الإصلاح هي `community_hub_page.dart` و`community_notifications_rendering.dart` مع اختبار theme فعلي.
2. يحمل الزر الأوسط اسم Quick Add في المكوّن، لكن Community Hub يعترض index 2 لفتح `_openComposer()`، بينما Coach وNotifications يستخدمان route `/daily-log`. يحتاج المسار إلى توحيد وفق القرار المطلوب، مع إبقاء مدخل Composer الصريح داخل Community واختبارات back/pending operation.

تحتاج أبعاد dock والمسافات والأيقونات والـselection glow إلى مقارنة بقياسات viewport موحدة. وجود مكوّن واحد أو ترتيب labels صحيح لا يثبت exact visual parity. عدم ظهور dock في capture الـCoach workspace المعزول لا يثبت غيابه عن صفحة Coach الكاملة؛ يظهر في capture المحادثة الكاملة. أما Profile فمصدر صفحته المستقلة نفسه لا يضع dock.

## AI Coach: التمييز بين UI موجود ومسار command مكتمل

`coach/coach_workspace_en_1.0.png` يعرض greeting وChat/Insights/Plan/Progress/Tools، أربع macro tiles، Today's Focus، وأفعال photo/voice/quick add/scan. تختلف كثافة الصفحة: أحجام ومسافات أكبر، عنوان Plan Tools إضافي، وموضع timeline والاقتباس مختلف ضمن المساحة المرئية. يلزم مقارنة الصورة بمرجع Coach بعد ضبط حالة البيانات والـviewport، دون إعادة تصميم أخرى.

`coach/coach_conversation_persisted.png` يعرض محادثة محفوظة فعلية ورسالة صريحة بأن المثال لم يضف شيئًا إلى السجل حتى تأكيد action حقيقي. هذه الصورة لا تعرض multi-food review card قابلة لـConfirm/Adjust، ولا receipt غنيًا من committed readback، ولا صور الأطعمة والكميات ومصدر/ثقة منفصلين، ولا Undo مرتبطًا بالعملية والإصدار. لذلك هي دليل rendering/persistence فقط، وليست دليل تنفيذ Food V2.

الجرد الوظيفي المفصل، بما فيه descriptors/handlers/repositories/permission admission وcorrection/undo والفجوات، محفوظ في [COACH_CAPABILITY_INVENTORY_20261006.md](COACH_CAPABILITY_INVENTORY_20261006.md). ترتيب الاعتماد الأدنى:

1. admission موحد للـcanonical action/tool IDs مع إعادة فحص الصلاحية عند التنفيذ.
2. Undo آمن على العناصر التي أنشأتها العملية، مع حماية meal قائم مسبقًا وربط operation/version.
3. مسار native متعدد الأطعمة يحفظ في repository/Drift ويقرأ النتيجة committed، ثم يبني rich receipt من تلك النتيجة.
4. unknown nutrition يبقى unknown، وفصل source/confidence/quantity confidence، ثم date/timezone/correction/calorie-only/per-user fixed products وفق الجرد.
5. capture حقيقي لمسار review → confirm → committed receipt → correction/undo، ثم مطابقة شكل البطاقات. لا تُستخدم بطاقة ثابتة أو generated image كدليل تنفيذ.

## R5: حد ما تثبته الصور

تمت معاينة ناتج `test/qa_next/community_entry_capture_test.dart` بأسماء `entry-en-light.png` و`entry-ar-dark.png` ضمن مجموعة R5 المنفصلة. تظهر شاشة Flutter بحقل اسم واحد، دعوة Save profile/create BIL Code، زر عودة، RTL، ونص الخصوصية. هذه الصور ليست ضمن artifact المرجع أعلاه، ولا تمثل قياسًا مقابل panel onboarding أصلي؛ لوحة Community لا تحتوي ذلك panel.

إثبات إنشاء profile/BIL Code والخصوصية والـowner boundaries وoptional photo failure مصدره اختبارات R5 وقراءة repository، وليس screenshot. لا يغيّر هذا التدقيق حالة clearance؛ إصلاحات المصدر بعد checkpoint تحتاج تحليلًا واختبارات والتقاطًا جديدًا عند SHA نهائي واحد.

## جدول التحقق المتبقي

| بند التحقق | الموجود | المتبقي قبل الإغلاق |
|---|---|---|
| أصالة المرجعين | الاسمان والأبعاد وSHA256 أعلاه؛ تمت معاينتهما دون تغيير | استمرار مقارنة كل دورة بنفس الملفين الأصليين، دون ترقية screenshot مختلف إلى golden |
| أصالة Flutter artifact | run/artifact/SHA/ZIP digest مثبتة؛ 144 Community +10 Coach PNG | إعادة التقاط المصدر المدمج بعد إصلاحات R5/owner/Unicode/notifications/Profile وتسجيل SHA/hash جديدين |
| الأسطح الثمانية | mapping مصدر/صورة موضح أعلاه | إضافة Drafts/Circles/moderation؛ إثبات channel chat مستقل بدل private chat |
| بيانات المقارنة | fixtures deterministic موجودة | صور/avatars/four-image post، notifications متنوعة وAI-token receipt، drafts غنية، وqueue حالات فعلية دون الاتصال بـProduction |
| Navigation | labels وترتيب منطقي مشترك | dark/light الصحيح، توحيد فعل Quick Add، back والمقاصد الفعلية، وحضور dock في الصفحات المطلوبة |
| R5 | name-only entry والتقاطات منفصلة واختبارات مخصصة موجودة | clearance نهائي عند SHA واحد مع owner/refresh/disposal/optional photo وعدم حجب الدخول |
| Unicode/composer persistence | حدود وعمل owner/proof جارٍ في المصدر بعد checkpoint | اختبارات 1200 Unicode، النص غير المقطوع، الأربع صور/poll، idempotency/retry/account switch ثم captures |
| Activity | receipt/visibility architecture موجودة؛ الإصلاح الجاري يعيد attention counts | جميع اختبارات foreground/dwell/covered route/failed RPC/partial readback/owner، مع لا auto-accept ولا تصفير خاص |
| Moderation/Earn | approve/reject و5-token readback branches موجودة بالمصدر | proof لمسار Earn → composer، author eligibility/reward receipt/duplicate، وفصل Gold عن AI Tokens |
| Coach Food V2 | workspace ومحادثة محفوظة وجرد capability موجودة | native transactional path + committed receipt + correction/versioned undo + provenance/unknown/date cases |
| التحليل والانحدار | الأدلة السابقة والـbaseline محفوظة لدى فريق QA | format/analyze/focused/capture ثم portable regression الأربع shards على المصدر النهائي؛ لا حذف assertions أو exclusions لتجاوز الفشل |
| Pixel/function parity | مراجعة مكونات ومصدر فقط | توحيد مساحة المقارنة والبيانات، قياس الفروق وإصلاحها، واختبار الوظائف المرتبطة بكل مكوّن |

## قرارات المالك التي تتقدم على أرقام الرسم

المطلوب التنفيذي هو **1200 Unicode character semantics، أربع صور، +5 AI Tokens للمنشور المؤهل بعد approval، وفصل AI Tokens عن Gold**. بعض أرقام لوحة المفهوم مختلفة؛ لا تُنقل إلى التطبيق. لا auto-publish، ولا auto-follow، ولا قبول سياسة أو جعل discoverability عامة نيابة عن المستخدم، ولا اختلاق بيانات شخصية أو USDA أو macro values من أجل جعل الصورة مشابهة.

يبقى العمل على QA فقط، دون تغيير iOS 35 / Android 32 أو main أو Production أو الأسعار/الدفع/Trial أو استخدام موارد مدفوعة. هذا التدقيق لا يصرح ببناء متجر أو نشر سحابي.
