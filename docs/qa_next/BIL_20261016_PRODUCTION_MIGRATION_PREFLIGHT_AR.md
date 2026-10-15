# فحص ترحيلات Production قبل التنفيذ — 16 أكتوبر 2026

> تصحيح هوية ملزم بعد هذه اللقطة: أكد المالك أن الحسابين المسمّيين هنا personal_test_a وpersonal_test_b حسابا اختبار شخصيان، وليسا حسابي مراجعة متجر. حساب المتجر المخصص store_review تحقق الجذر أنه Admin=false وModerator=false. عطل ترحيل owner-only إدارة personal_test_b اعتمادًا على التصنيف الخاطئ السابق؛ أعاد الجذر الصف الشخصي من النسخة الأصلية بترحيل Production `20261015231142` بعد تحقق معزول33PASS. لا توصية بإزالة Moderator أو منح/حقوق شخصية، ولا إعادة تلقائية لـowner-only. جداول هذا التقرير تحفظ قراءة ما قبل التنفيذ تاريخيًا؛ لم يجر هذا العامل تغييرات الأدوار. توصية الخطوة10 القديمة مسحوبة في الحالة المصححة.

هذه مراجعة قراءة فقط من العامل `production_migration_preflight`. المصدر: `integration/bil-qa-media-policy-20261011`، HEAD `ed963053c62cc549cbe50757279bd39d73a10e35`، وشجرة العمل محفوظة كما هي. لم أعدل التطبيق أو SQL أو الاختبارات، ولم أشغل اختبارًا أو أطبق ترحيلًا أو أنشر Edge. الجذر وحده ينفذ التغييرات المأذونة.

**القرار: 11 ترحيلًا محليًا قابلة للتنفيذ بعد تحقق البصمات والنسخ الخاص؛ ترحيل إيصالات المنشور V2 محجوب بصيغته الحالية بسبب اختلاف Production مؤكد.** لا تعني الجاهزية هنا اختبار هاتف أو شراء متجر أو نجاح رحلة مراجع.

## ما تحقق حيًا

المشروع `tgmanzhqulksykhslrzb`. آخر timestamp محفوظ في القراءة: `2026-10-15 22:44:26.291526+00`، أي 16 أكتوبر بتوقيت القاهرة. `server_version=17.6`؛ ونسخة البنية `17.6.1.155`/الحالة الصحية موثقتان لدى الجذر. لا CREATE لـanon أوauthenticated على public.

- حُصرت 94 تسمية object مرجعية من الملفات الاثني عشر: 49 موجودة مسبقًا، و45 غائبة تساوي بالضبط **33 دالة جديدة + 11 جدولًا جديدًا + sequence واحدة**. لم يظهر اعتماد سابق غائب بالاسم. فُحصت أيضًا الأعمدة والقيود والفهارس وACL/RLS والسياسات وtriggers للجداول القائمة ذات الصلة.
- الدالة القائمة الوحيدة المعاد تعريفها مباشرة ضمن الملفات هي `bil_admin_private.require_administrator(uuid)`: `pg_get_functiondef` يثبت جسم NOT EXISTS القديم بلا FOR SHARE، لا تطابقًا مع الإصلاح المحلي.
- دوال patch الائتمان الأربع موجودة؛ في كل تعريف حي **ظهور واحد بالضبط** للعبارة الأصلية المطلوبة، بلا القفل الجديد. دوال patch سلامة المجتمع الثماني موجودة ولكل منها BEGIN واحدة مطابقة لشرط الحقن. لا يعتمد الحكم على سجل migration وحده.
- `bil_ai_boost_store_state` موجودة، RLS=true، ولا SELECT لـanon أوauthenticated أوservice_role. ترحيل SELECT الخادم مطلوب فعلًا.
- مصنف الاتصال الحالي deterministic/invoker؛ authenticated يستطيع EXECUTE حاليًا، service_role لا يستطيع. الترحيل الأخير يثبت authenticated ويضيف service_role فقط.
- السجل الحي يحتوي في 5 أكتوبر: `community_post_receipts_and_earn_v1`، `community_post_push_resume_v1`، `community_review_queue_alignment_v1`، `community_reward_receipt_seen_sync_v1`. هذه الإضافات **غير موجودة كملفات 5 أكتوبر محلية**. هذا اختلاف نشر حقيقي، وليس سببًا لإعادة تطبيق كل التاريخ القديم.
- `bil_admin_private.subscription_commands/subscription_grants` موجودان ومحميان، رغم اختلاف تواريخ الأسماء المحلية. لا إعادة لإنشائهما.

## ترتيب الملفات الأحد عشر المسموح بفحصها للنشر

الترتيب أدناه يحافظ على ترتيب المصدر مع استثناء الإيصالات المحجوبة. كل خطوة معاملة منفردة ومحدودة وتحقق بعدي؛ عند اختلاف غير متوقع يتوقف التنفيذ ولا ينتقل تلقائيًا إلى التالي.

| الترتيب | الملف في supabase/migrations | الأثر والتبعية |
|---|---|---|
| 1 | `20261007130000_bil08_community_profile_activity_v1.sql` | RPC للردود والإعجابات؛ اعتمادات Social-v2 موجودة. إعجابات الملف لصاحبها فقط، والردود تخضع لمرئية الملف والمنشور والعضو. لا تغيير عقود V1 قائمة. |
| 2 | `20261011193000_community_review_revision_v2.sql` | جداول خاصة ونسخة محتوى وإيصالات تشغيل وRPC V2؛ يعتمد على moderation V1/media/polls القائمة. لا إعادة تعريف V1 في هذا الملف. `allow_publish_only=false` تبقى كما هي. المكافأة runtime تستعمل سياسة 5 القائمة/دفترها الفريد؛ لا منحة عند DDL. |
| 3 | `20261011211500_admin_authority_transaction_lock.sql` | FOR SHARE على صف Admin في helper المالي؛ يبقى service-role JWT والتحقق من actor، وتبقى EXECUTE الخاصة محجوبة عن أدوار العملاء. |
| 4 | `20261012052335_cloud_nutrition_goals_restore_v2.sql` | جداول/RPC مستقلة للغذاء والأهداف؛ لا لمس V1، ولا موافقة تلقائية أو نسخ بيانات. موافقة cloud_sync الأساسية + scope صريح + جهاز غير مبطل؛ قفل المالك نفسه كالعقد الحي. جدول الأجهزة يوفر default للـplatform فعليًا. |
| 5 | `20261012202029_admin_credit_authority_transaction_lock.sql` | patch محافظ لتعريفات الأربع؛ لا تشغيل reset/إشعار/منحة. يحفظ الهوية والتوقيعات وACL والدفاتر والأرقام والسياسات. يسبق سحب Admin في الخطوة 10. |
| 6 | `20261012204610_boost_refund_tombstone_service_read.sql` | SELECT لـservice_role فقط على حالة refund، بعد فشل مغلق إذا RLS غائب أو وصول عميل غير متوقع. لا تغيير رصيد أو شراء أو tombstone. |
| 7 | `20261013062209_community_message_delivery_v2.sql` | سجل idempotency خاص وRPC مصادقة؛ تبقى INSERT القديمة وtriggers الأصلية للسياسة والحظر والحد والإشعارات. لا إرسال رسالة أثناء الترحيل. |
| 8 | `20261013062221_community_safety_report_review_v1.sql` | helper سلطة + patch الثماني + قراءة/قرار بلاغ محدد وblocked list لصاحبها. يحفظ توقيعات V1، ولا يمنح Moderator اشتراكًا/رصيدًا. يجب حفظ ومقارنة تعريفات الثماني قبل/بعد. |
| 9 | `20261014100000_ai_coach_safety_reports_v1.sql` | يعتمد على helper الخطوة 8 وعلى usage events القائمة. البلاغ يشارك جوابًا اختاره المستخدم بموافقة، لا prompt أو محادثة/ملف صحي كامل؛ القرار يمحو answer/note ويحفظ إيصالًا. صلاحية إشراف فعلية، لا Premium. |
| 10 | `20261015090000_restore_single_owner_administrator.sql` | **تغيير سلطة حي**: إبقاء المالك Admin الوحيد، وتعطيل Admin غير المالك، وفهرس يمنع Admin ثانيًا. يترك Moderator والاستحقاقات والاشتراكات والأرصدة كما هي. الربط الحي أدناه يحدد أثره الحالي بدقة. |
| 11 | `20261015090100_allow_authenticated_community_contact_guard.sql` | EXECUTE على مصنف نصي deterministic لـauthenticated وservice_role. لا RLS جديدة أو إذن بيانات عام. |

لا تُنفذ الخطوات بإعادة تشغيل كل migrations القديمة، أو `db push --include-all` دون مطابقة. يجب أن تسجل أداة النشر الملفات/البصمات المطبقة وتقرأ سجلها بعد كل معاملة؛ اختلاف timestamp التاريخي لا يبرر إعادة الترحيل.

**شرط سياسة منفصل عن نجاح SQL:** وثيقة التوافق 11 أكتوبر، السطر66، تطلب اعتماد مدة احتفاظ دفتر التدقيق قبل النشر؛ والإغلاق الأحدث 13 أكتوبر، السطر86، يربطه بما قبل التفعيل. لا تتضمن الوثيقتان مدة معتمدة محددة. جداول review/reward operations تحفظ UUID التدقيق دون FK ولا TTL تلقائيًا؛ ومدة30يوم في قائمة بلاغ AI هي نافذة عرض وليست purge. لا يختار المنفذ مدة من عنده، ولا يحذف سجلات أو يعلن إغلاق سياسة الاحتفاظ بسبب إذن SQL العام. على الجذر تحديد ما إذا كان إذن المالك الحالي يغطي عقد الاحتفاظ القائم، وربط تفعيل V2 بسياسة معتمدة؛ إذا لم يحسم ذلك تبقى بوابة السياسة مفتوحة حتى مع جاهزية schema التقنية.

## بصمات المصدر المجمد

| الملف | SHA-256 |
|---|---|
| `20261007130000_bil08_community_profile_activity_v1.sql` | `a881cbd06c5b08813b9d02ab38162112169f7edddb4132644423ac53fda8706e` |
| `20261011193000_community_review_revision_v2.sql` | `3b226e77790319bd716f6963f4cc455529a6e3c5945ef1edc9794d8fdc2d4a85` |
| `20261011211500_admin_authority_transaction_lock.sql` | `e10b82d4b2abbfab9f3c558be344cc20b18e4ca890cf62851d0e3e05b1a6c93d` |
| `20261012052335_cloud_nutrition_goals_restore_v2.sql` | `ccacdcef47bf2ff0e3d438826da6fc285015c4554e157834bdea052b5ee73966` |
| `20261012202029_admin_credit_authority_transaction_lock.sql` | `a53858dfac88c3e5ba7dd311608b5a1832602c26d0fd25afcf17e12757cbf402` |
| `20261012204610_boost_refund_tombstone_service_read.sql` | `045a80617915ddc4f6b36a460925bedca36c1c950f96b721d835bd5af369a267` |
| `20261013062209_community_message_delivery_v2.sql` | `321b00a6f5b483c6ae555911c1153c4174fe78a2b4ff49d15c7c10487502a00d` |
| `20261013062221_community_safety_report_review_v1.sql` | `8846b0e94d6fee14b76597c05bebb3f9239d71d0e0399127698fbaec7ef30e18` |
| `20261014100000_ai_coach_safety_reports_v1.sql` | `aaad8ac351dd43983cffb7b4ad63491715c55aa3d59b490f1c32b0f30a13540f` |
| `20261014113000_community_post_review_receipts_v2.sql` | `4ac4a5e372e9a33d2daeb94cb286343c196d8324c3796048c9abd357bc4a91f9` |
| `20261015090000_restore_single_owner_administrator.sql` | `4e46262ba06f8aa368c508a1f0937d28dd931f5642feeecffca943ab2a9be973` |
| `20261015090100_allow_authenticated_community_contact_guard.sql` | `b01e111cc8a099d4ee93e13194a563837ae95d7e145e86503eb741b418446f03` |

أي اختلاف بهذه البصمات يستلزم إعادة القراءة قبل التنفيذ. التعليقات التاريخية «unpublished/no authorization» تصف مرحلة إعداد الملف؛ لا تتغلب على إذن المالك الحالي المحدد الذي ينفذه الجذر.

## أدوار الحسابات: نتيجة مصغرة بلا عناوين أو UUID

الـaliases تطابق الهويات التي حددها المالك في الجلسة. count=1 لكل alias؛ لا عنوان حساب أو مفتاح أو رصيد منشور في هذا التقرير.

| alias | Admin نشط | Moderator | منحة اختبار نشطة | entitlement projection نشط | سجل اشتراك متجر نشط |
|---|---|---|---|---|---|
| owner | نعم | نعم | نعم | نعم | نعم |
| personal_test_a | لا | لا | لا | لا | لا |
| personal_test_b | نعم | نعم | نعم | نعم | نعم |

إجمالي Admin النشط=2، منهم owner=1 وغير المالك=1. إجمالي Moderators=2، والـnon-owner overlap=1. فهرس single-active غير موجود. لذلك، في هذه اللقطة، الترحيل 15090000 يعطل Admin لـpersonal_test_b وحده ويبقي owner؛ **لا يزيل Moderator لـpersonal_test_b**. عدم وجود استحقاق A لا يعني فشل الدخول أو غياب حق UI بذاته؛ والـsubscription flag سجل قاعدة فقط، ليس اختبار متجر/مراجع.

قبل تغيير صفوف السلطة يحتفظ الجذر بنسخة خاصة محدودة للصفين المتأثرين وربط هويتهما، وبقيم active/granted_by/reason؛ هذا التقرير alias-only ليس نسخة صفوف صالحة للاسترجاع. لا تستنتج من عضوية Moderator للحساب الشخصي وجود صلاحية زائدة لمراجع متجر. لا تُزال عضويته أو منحه بهذا التقرير. وفق تحقق الجذر، حساب store_review المخصص ليس Admin أوModerator؛ تبقى رحلة المراجع الفعلية بوابة مستقلة.

## استثناء واجب: إيصالات المنشورات V2

**لا يُنشر `20261014113000_community_post_review_receipts_v2.sql` منفردًا أو كما هو.** اعتماد جداول V2 محقق بعد الخطوة 2، لكن التوافق مع إضافات 5 أكتوبر يفشل منطقيًا:

- trigger الحي `bil_post_approval_receipt_v1` على grant يستدعي `private.bil_emit_post_receipt_v1`: يكتب سجل V1، وإشعارًا موجبًا عند tokens>0 بمصدر `post-ai-reward:<post>`، وpush بمصدر `post-event:post_approved:<post>:<owner>`.
- trigger `bil_post_rejection_receipt_v1` يكتب حدث الرفض وpush بمصدر `post-event:post_rejected:<post>:<owner>`.
- V2 يترك هذين ويضيف triggers تُنتج `post-moderation-receipt-v2:<post>`. المفاتيح مختلفة، لذا لا يمنع unique index تكرار push لكل اعتماد/رفض أو تكرار Activity للاعتماد ذي المكافأة. لا تكرار صرف مالي مستنتج؛ العيب هنا ازدواج fan-out.
- V1 ليس مخلفًا يمكن حذفه: `bil_list_my_post_events_v1` و`bil_mark_my_post_events_seen_v1` وrequeue/seen sync تستعمل دفتره. تعطيل hook دون بديل يكتب الدفتر يوقف أحداثًا جديدة لهذه العقود.
- `bil_emit_post_receipt_v1(...,p_push=false)` يمنع push فقط؛ Activity الموجب لا يزال يُنشأ. إعادة الاستدعاء على event_key موجود ترجع قبل Activity/push.
- receipt عملية V2 قد يحمل `duplicate_decision` أو`duplicate_receipt` من V1 مع operation ID جديد؛ emitter V2 الحالي لا يقبل هذين السببين. يجب ألا يولد adapter إشعارًا جديدًا لقرار مكرر.

### شروط adapter قبل نشر إيصالات مصححة

لا تنفيذ مصدر في هذه المراجعة. المقترح الذي يعتمده الجذر بعد انتهاء الشاملة: الاحتفاظ بالدفتر والـhooks والـRPC والتوقيعات، واستعمال event_key/push V1 canonical مع إثراء Activity الموجب الموجود بدل إنشاء ثان. تدقيق الجسم/FK/قيود events وإيصالات المصدر قبل أي إعادة تعريف.

1. تحقق داخل المعاملة من وجود الـ3 دوال الأصلية وبصماتها وACL وtrigger bodies أدناه، والجداول/القيود/seen/requeue التي حُفظت. أي اختلاف غير متوقع يرفع exception قبل تغيير؛ لا best-effort.
2. ثبت ربط العملية/المستفيد/النسخة وidempotency. للقرار الأصلي eligible، يستطيع adapter استدعاء emitter V1 مع p_push=false. موضع trigger V2 `bil_community...` يسبق `bil_post...` أبجديًا حاليًا؛ يجب اختبار أي اعتماد على هذا صراحة وعدم تحويله إلى افتراض خفي.
3. المكافأة الموجبة: احتفظ بـkind=`reward_earned` وcopy_key=`community_post_ai_reward_v1` وsource=`post-ai-reward:<post>` وmetadata.receipt_id وtokens/currency/decision التي تستعملها seen sync. إن احتاج العميل parser آخر يلزم تعديل متوافق مختبر؛ لا تكسر شرطه ببديل غير معترف به.
4. الصفر بسبب daily cap: دفتر V1 يكتب `post_approved`، tokens=0، reason=`daily_cap_reached`، دون Activity قديمة. الرفض يكتب `post_rejected` و0/`not_applicable`. إضافة Activity للصفر/الرفض تحتاج ربط seen خاصًا بها إلى دفتر V1 حتى لا تعيد queue إشعارًا شاهده المستخدم.
5. push canonical مصدره event_key V1 ليظل requeue يعمل. requeue الحي يتطلب: owner/device enabled، آخر24h، `no_eligible_tokens`، dispatched موجود، event.seen_at=NULL، لا delivered attempt، حالة المنشور الحالية مطابقة، وحد10. لا حذف تاريخ أو إعادة صفوف سبق تسليمها.
6. seen sync الحي للموجب فقط يشترط old.seen_at NULL→new غيرNULL، kind/copy/source أعلاه، metadata.receipt_id مطابق، event_kind=post_approved وai_tokens>0. لا تسمية «preserved» إن تغير واحد دون تغطية.
7. تبقى publish-only=false. المسار deferred/مكافأة لاحقة له اختبار منفصل؛ لا تحول حدث approved مؤجلًا سابقًا إلى payload مختلف على event_key ثابت دون سياسة توافق صريحة.
8. الاختبار المعزول التالي يعيد **الشكل الملتقط من Production**، لا migrations المحلية وحدها: V1 عميل/مراجعة، V2، 5/0/rejected، lost-response/retry/concurrency، seen من الطريقتين، requeue بعد جهاز/استئناف، no duplicate Activity/push/credit، وعدم تكرار التاريخ. لا حاجة لتشغيل ذلك على مستخدمين حقيقيين.
9. يكون تركيب adapter والـV2 replacement وتغيير hooks عند الحاجة معاملة واحدة تحت حاجز كتابة محدود؛ لا نافذة بين ملف V2 غير الآمن وملف التصحيح. الأصل المحجوب لا يُطبّق أولًا كخطوة منفصلة.

بصمات `pg_get_functiondef` الأصلية الحية:

| الدالة | SHA-256 |
|---|---|
| private.bil_emit_post_receipt_v1 | d89003128960bd5def9825390177f66b8d78685f3bdbced32c5b714dbe0346b9 |
| private.bil_post_approval_receipt_trigger_v1 | 376a58c5d559b598ac7f58263c0dcd4ea9e2f871efb038d491077483b424e447 |
| private.bil_post_rejection_receipt_trigger_v1 | 87d266f61b12c26a7a3358616141745d2e7d9272525c32f9718637c3123be222 |
| private.bil_sync_post_receipt_seen_v1 | cc41e9129608859987e8090580215d585912fbaf104836a3c4d12ed779812fa5 |
| private.bil_requeue_post_notices_for_owner_v1 | fc227e8ced1f1a54ed4d164dbb5dc517ec15b01b5277690fdae27618043961f3 |

بصمات `pg_get_triggerdef(oid,true)`: approval=`4167f57b0629ef52e7af6fc8fb9ff8351991c6e2208f4e8a7d034c5d130b8780`، rejection=`a051c9a4bcf1e17598ba414bd606f9a0ffc74cd05ffa6ff848b9d03133ff9d83`، seen-sync=`935c97b980b59c205ec09559fd183c37eb73addaa1421e821e7b1714810f174c`. النصوص الأصلية كاملة محفوظة في النسخة الخاصة.

## النسخة الخاصة والتحقق قبل/بعد

مجلد ignored: `build/qa/policy-gate-20261015/production-preflight/`. UTF-8، catalog/DDL فقط، لا صفوف صحة أو أرصدة أو عناوين مستخدمين. ملخص الأدوار aliases فقط.

| الملف الخاص | الحجم bytes | SHA-256 |
|---|---:|---|
| catalog-before.json | 148159 | 7423eceb4ee1769000f798a834641f8ec4ecc7a83d87e7e3af8b743cebdb2cb7 |
| functions-before.json | 80449 | f0f2629e51fda5982441138d68d97ef9c9dda091821885ea7c07ef8247191c20 |
| legacy-receipts-before.json | 21477 | 6fdc902f6bcbe82be81857a90b6ef91e22f02e9e36208f351e5d90983a0bdb07 |
| read-only-findings.json | 30154 | 3373aed51385ff792ce0ad9dac6a0cb9762062be1ccc4d46a15273865cc7c6c8 |

`functions-before.json` يحفظ 19 تعريفًا وتوقيعات/نتائج وACL وowners وhashes، يشمل helpers و12 RPC قائمة متأثرة والدوال المرجعية. `catalog-before.json` يحفظ 27 relation قائمة وأعمدتها/defaults/constraints/indexes/policies/triggers. ملف legacy يضيف جدول الأحداث والـ3 triggers و7 دوال legacy والـactivity helper.

قبل التنفيذ يعيد الجذر القراءة مرة واحدة: تحقق المصدر/HEAD، مقارنة بصمات التعريفات القائمة مع النسخة الملتقطة، أسماء الـobjects الغائبة، وACL/RLS والفهارس، وalias/count السلطة. عند تطابقها فقط تطبق الملفات المحددة. الترحيل الذي لا يضبط timeout بنفسه ينفذ عبر قناة محدودة موثوقة؛ يجب ضمان atomicity خصوصًا Cloud V2 التي لا تضم BEGIN/COMMIT صريحين.

بعد كل خطوة: سجل اسم migration الحي الجديد، قارن نص/توقيعات الدوال الجديدة بالمصدر، وراجع grants/RLS والسياسات والفهارس والـtriggers. المتوقع بعد الأحد عشر: 29 من 33 دالة جديدة حاضرة، وتظل دوال إيصالات V2 الأربع غائبة؛ لا trigger V2 للإيصالات؛ Admin=owner فقط، Moderator للمرجع B باقٍ، لا تغيير مقصود بالاشتراكات/المنح/الشراء/الأرصدة. اجعل معاينة الفشل مصادقةً محدودة بلا بيانات حقيقية؛ لا grant/reset/رسالة/بلاغ فعلي فقط لإثبات النشر.

مسار التراجع: لإصلاح تعريف قائم يستعاد تعريفه الكامل وACL من النسخة الخاصة بعد التحقق من هوية الإصدار الجاري، أو يعطل إصدار RPC الجديد مع إبقاء الجداول/الإيصالات. لا DROP لدفتر أو tombstone أو credit. بيانات السلطة تُستعاد من النسخة الخاصة المحدودة بعد إزالة/تعديل الفهرس الجديد ضمن إجراء مدقق إذا لزم؛ لا تعاد صلاحيات المراجع تلقائيًا عند فشل عقد آخر. fan-out الذي أُرسل لا يسترجع بتراجع DDL، ولذلك يمنع التكرار قبل النشر. لا حذف/صرف تعويضي آلي.

## Edge والنسخ القديمة وحدود الدليل

القراءة الحية الجديدة تطابق metadata السابقة: AI Coach106، verify-store-purchase93، global-reset62، community-push-dispatch56، food-search60. لم ينشر العامل أي منها، وإذن SQL لا يُحوّل تلقائيًا إلى نشر Edge.

- profile/review/messaging/safety/Cloud V2 RPC تستدعيها Flutter مباشرة. إضافة SQL تكفي لإتاحة endpoint؛ ليست دليل نجاح رحلة واجهة أو مصادقة جهاز.
- أقفال helper/الائتمان/المجتمع تحمي RPC القائمة التي تستعملها Edge الحالية فور تركيبها. لا تستلزم تبديل endpoint أو تغيير ردود32/35.
- SELECT حالة refund يجهز اعتماد القراءة في `verify-store-purchase/store_backend.ts` المحلي؛ لا يثبت نشر verifier المصحح. إصلاح recipient واشتراكات global-reset، memo food-search، وتعديلات dispatch/AI الأخرى تعتمد على إصدار Edge منفصل مع مراجعة ونشر مأذونين. لا تنسب SQL إليها.
- عقود Android32/iOS35 تبقى بأسمائها وتوقيعاتها وردودها القديمة، وتتلقى حماية القفل نفسها. لا تُحول semantics جديدة إلى V1. العميل33/36 يستعمل عقودًا مضافة وموافقة scope صريحة، ويظل artifact/device/store مستقلًا.

الدليل المعزول التاريخي المقروء من reconciliation على source `19972310`: [Supabase38734170433](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38734170433) نجح بكل migrations المحلية، SQL9/9، Node34/34، دورة SQLite→GoTrue/PostgREST/PG→SQLite1/1، PG/PGlite74/74 وDeno358/358، على صورةPG17.11.0.004. لا إعادة تشغيل من هذا العامل. **هذا لا يغطي إضافات Production الأربع في5أكتوبر غير الموجودة محليًا**، ولا يحوّل report إلى PASS Production على17.6. البناء والشراء والمراجع لا تثبت بهذه الأعداد.

مراجع المنهج الحالية: [Supabase grants/RLS](https://supabase.com/docs/guides/api/securing-your-api)، [Database functions](https://supabase.com/docs/guides/database/functions)، [Changelog](https://supabase.com/changelog). قُرئ changelog.md وsearch_docs؛ إعلان TLS12 بتاريخ12أكتوبر يخص نوفمبر، ولا يغير ترتيب SQL المقترح هنا. تاريخ القراءة16أكتوبر2026.
