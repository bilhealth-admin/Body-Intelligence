# BIL-07 — عقد قنوات المجتمع v1، مقترح محلي غير منشور

الأصل المجمد: 1744788e6bfbdffc3a168bbaf36b3abf3e2c698a، والشجرة
8f140791e1c2adcb21122ce64a65cb168bbe90d7.

هذا المجلد يضيف عقدًا مستقلًا للقنوات العامة وfixtures معلنة واختبارات
PostgreSQL قابلة للتشغيل. لا يعدل الرسائل الخاصة أو جداول الدوائر أو قبول
السياسة. لم يتصل بخادم الإنتاج ولم ينشر migration أو Realtime.

## حالة التحقق وحدودها

- تشغيل المحرك المحلي: **PASS** على PostgreSQL **17.11** داخل cluster
  disposable جديد، بقاعدة `bil07_local_*` على `127.0.0.1` فقط، وتحت مستخدم
  نظام غير مميز `oai`. النتيجة النهائية: **95 PASS / 0 FAIL**، exit0، ثم
  أُوقف cluster وحُذف مساره المؤقت. `production_connected=false` و
  `production_deployed=false`.
- تشمل الجولة الفعلية ACL/RLS negative controls، منع owner spoof، صلاحيات
  RPC، العضوية/الحظر/التعطيل/السياسة، حد النص، idempotency بعد فقد الرد،
  pagination المتداخل، exact readback، presence TTL، سباقات المعاملات مع
  commit/rollback، وإثبات عدم تغيير private messages/unread.
- أثناء أول تشغيل فعلي كشف PostgreSQL17.11 فرق تمثيل `inet`:
  `inet_server_addr()::text` يعيد `127.0.0.1/32`. عُدل حارسا البيئة فقط
  إلى `pg_catalog.host(inet_server_addr())`، فيبقى الشرط مقصورًا صراحة على
  `127.0.0.1` أو `::1` دون توسيع أي صلاحية أو تعطيل أي assertion.
- نجح سابقًا فحص grammar لملفات SQL وPL/pgSQL بواسطة pglast7.7 وفحص AST
  لملفات Python. وبعد تعديل الحارس، قامت PostgreSQL17.11 نفسها بقراءة
  وتنفيذ ملفات SQL النهائية كاملة؛ وهذا هو الدليل التنفيذي الأعلى من فحص
  parser وحده.
- fixture يحتوي أشكال جداول وهوية وبيانات مصطنعة، مع أجسام ست دوال BASE
  منقولة دون تعديل. ليس استعادة backend كاملًا أو اختبار Auth/PostgREST حيًا.
  المصادر وGit blobs وبصمات SHA256 في `base_helper_sources.json`.
- لا توجد مطالبة بجهاز أو Supabase حي أو push أو benchmark. عقد v1 يعلن
  `realtime_available:false` ولا ينشئ publication أو grants لـRealtime؛
  مسار v1 المعلن هو polling، وغياب feed يفشل بأمان ولا يتحول إلى success وهمي.

## الملفات والتشغيل

| الملف | الغرض |
|---|---|
| channel_contract_v1.sql | عقد forward-only، بلا بيانات seed |
| bootstrap_fixture.sql | هويات وأشكال جداول محلية مصطنعة فقط |
| base_helpers_fixture.sql | أجسام دوال BASE المطلوبة، بلا تعديل |
| base_helper_sources.json | مصدر BASE وGit blob وSHA256 لكل دالة مقتطفة |
| channels_fixture.sql | General/Nutrition/Workouts/Mindset وقناة معطلة، كلها fixtures |
| integration_tests.py | أوامر بأدوار عادية وnegative controls واتصالات متزامنة |
| loopback_runner.py | إنشاء cluster مؤقت واختباره وإيقافه وحذف مساره الخاص |
| static_check.py | grammar وAST فقط، دون تشغيل قاعدة |

المشغل لا يقبل DSN/host/database، بل ينشئ قاعدة bil07_local_* على
127.0.0.1 ومنفذ محلي متاح. يزيل متغيرات PG الموروثة ولا يقرأ .env أو
service files. يكتب الأوامر وexit codes والسجلات وبصمات المصدر. يتطلب
PostgreSQL 15 أو أحدث محليًا، ويسجل الإصدار الفعلي دون افتراض مطابقته
للإنتاج. مثال:

    BIL07_POSTGRES_BIN=/path/to/postgresql/bin \
    python tool/qa_parallel/bil07/sql/loopback_runner.py \
      --output /absolute/scratch/bil07_sql_evidence

مع حزم مستخرجة قد يلزم LD_LIBRARY_PATH إلى libpq للعملية الحالية فقط.
عند root، يستعمل المشغل حسابًا محليًا موجودًا غير مميز: postgres ثم nobody،
أو BIL07_PG_OS_USER. لا ينشئ حساب نظام؛ الهوية غير mapped تعني NOT_RUN.

    PYTHONPATH=/path/to/isolated/pglast \
    python tool/qa_parallel/bil07/sql/static_check.py \
      --output /absolute/scratch/bil07_static_evidence

## واجهات JSON

كل RPC يعيد contract_version:1 وowner_id المطابق لـauth.uid() وserver_time
بصيغة timestamp مع offset. لا تقبل الواجهات owner كوسيط. غياب RPC أو
اختلاف الإصدار أو قيم capabilities يجعل العميل يعرض عدم التوفر؛ لا
fallback ناجح ببيانات fixture أثناء الاستعمال الفعلي.

| RPC | الوسائط | الحقول الإضافية |
|---|---|---|
| bil07_channel_capabilities_v1 | لا شيء | max_text_code_points:2000، max_page_size:100، max_receipt_ids:100، read_receipts:"exact_message_ids_v1"، presence_ttl_seconds:90، presence_heartbeat_seconds:30، heartbeat_seconds:30، realtime_available:false |
| bil07_channel_directory_v1 | p_after_id:uuid?=null، p_limit:int=50 | channels، next_after_id:uuid? |
| bil07_channel_messages_v1 | p_channel_id:uuid، p_before_sequence:bigint?=null، p_after_sequence:bigint?=null، p_limit:int=50 | channel_id، messages، has_more، next_before_sequence، next_after_sequence |
| bil07_channel_send_v1 | p_channel_id، p_client_message_id:uuid، p_text:text | channel_id، message، idempotent_replay:bool |
| bil07_channel_read_v1 | p_channel_id، p_message_ids:uuid[] | channel_id، acknowledged_message_ids، unread_count |
| bil07_channel_readback_v1 | p_channel_id، p_message_ids:uuid[] | حقول read بقراءة مستقلة دون كتابة |
| bil07_channel_presence_v1 | p_channel_id، p_heartbeat:bool=false | channel_id، online_count، expires_at:timestamp?، ttl_seconds:90، valid_until |

عنصر channels يحتوي id وslug وtitle وdescription وvisibility وenabled
وmembership وcan_read وcan_send وmax_text_code_points وunread_count
وlatest_sequence. visibility إما public أو members. العضوية active/none؛
حالات banned والمعطل تخفى من الدليل. latest_sequence عداد ترتيب القناة
الملتزم به؛ قد توجد فجوات مرئية عند حذف رسالة أو حظر مؤلفها، فلا يفترض
العميل أن كل رقم يمثل رسالة متاحة. الحد الأعلى للعداد والأعداد الصحيحة
9007199254740991 للمحافظة على دقة JSON.

عنصر messages يحتوي id وchannel_id وsequence وauthor_id و
author_display_name وtext وclient_message_id وcreated_at وis_read.
اسم المؤلف nullable إذا كانت خصوصية BASE لا تسمح بإظهار ملفه. مفتاح
retry nullable للرسائل التي لا يملكها القارئ. رسالة المالك is_read=true
ولا تحتاج إيصال وارد؛ باقي الرسائل تقرأ من إيصالات المالك الفعلية.

## العضوية والحماية

| الحالة | الدليل وقراءة الرسائل | إرسال | heartbeat |
|---|---|---|---|
| غير مسجل أو Community suspended | رفض | رفض | رفض |
| قناة public وعضوية none | متاح | رفض | رفض، والقراءة لا تنشئ حضورًا |
| قناة members وعضوية none | مخفي/رفض | رفض | رفض |
| عضو active | متاح وفق الرؤية | يحتاج قبول السياسة الحالية | متاح |
| banned بالقناة | القناة مخفية والقراءة مرفوضة | رفض | رفض |
| قناة disabled | مخفية/رفض | رفض | رفض |

لا توجد وظيفة join أو إنشاء عضوية. إدارة الدليل والعضويات مهمة خادم
لاحقة للمنسق؛ fixture لا يتحول إلى seed تلقائي. هذه العضوية مستقلة عن
الدوائر ولا تستورد ملفًا من BIL-06.

الحراس المعاد استخدامهم هم bil_can_use_community و
bil_assert_community_publish_ready وbil_social_member_visible_v2 و
bil_social_profile_visible_v2 وbil_community_contact_exchange_violation.
حظر أي طرف للآخر يمنع إسقاط رسائله واسمه وحضوره للقارئ. حظر القناة يمنع
صاحب العضوية من استعمالها ولا يحذف تاريخه تلقائيًا؛ الإزالة تستعمل
removed_at.

الجداول الخمسة الجديدة محمية بـRLS default deny وسحب كل grants من
PUBLIC/anon/authenticated/service_role. الواجهات العامة SECURITY INVOKER،
والتنفيذ ذو الامتيازات داخل private فقط مع حراس auth.uid() ومسار بحث
ثابت. EXECUTE يقتصر على الواجهات السبعة المحددة. الدوال المساعدة غير
متاحة للعميل. لا توجد table writes إلى bil_messages أو private unread.

## الترتيب وإعادة المحاولة

العداد ليس sequence مستقلًا في PostgreSQL. الإرسال يمسك قفل صف القناة
طوال المعاملة ثم يزيد العداد ويضيف الرسالة في المعاملة نفسها. الإرسال
التالي ينتظر commit أو rollback، كي لا تتاح رسالة ذات رقم أعلى قبل
رسالة أقدم لم تلتزم بعد. rollback يعيد العداد. ترتيب الأقفال: حالة عضو
BASE، صف القناة، العضوية، ثم السياسة. يفحص قبول السياسة بعد الانتظار.

القيد الفريد هو channel_id/author_id/client_message_id. retry بالنص ذاته
يعيد نفس الرسالة؛ نص مختلف يرفض channel_idempotency_payload_mismatch.
يحفظ النص تمامًا بما فيه المسافات. نفس المفتاح لمالك آخر أو قناة أخرى
مستقل، ورسالة أزالها المشرف لا يعيد retry إنشاءها. تعاد فحوص الصلاحية
والسياسة قبل replay.

بلا cursors يعاد أحدث page تصاعديًا. before يعيد الأقدم، وafter يعيد أول
page أحدث من cursor تصاعديًا. الجمع بينهما أو limit خارج1..100 يرفض.
has_more يخص الاتجاه المطلوب. cursorا النتيجة أدنى وأعلى sequence فيها،
أو null للصفحة الفارغة. مؤشر catchup يؤخذ من page الخادم؛ acknowledgement
الإرسال الخاص لا يجيز تجاوز رسالة أخرى وصلت قبله.

## القراءة والحضور والنص

الإيصالات IDs منفردة، وليست «كل شيء حتى آخر رسالة». readback يتقاطع مع
المطلوب الذي ما زال مرئيًا وواردًا ويخص القناة وله إيصال للمالك الحالي.
التكرار لا يكرر السجل، وID مجهول أو من قناة أخرى لا يمنح acknowledgement.
يوجد طلب readback مستقل بعد mutation؛ العدد وحده لا يثبت قراءة المجموعة.
فتح الدليل أو تحميل page لا يكتب إيصالًا. وقت snapshot العد يلتقط قبل
SELECT؛ لا يستعمل انتهاء استجابة متأخرة لتجاوز snapshot أحدث.

قيد حضور channel_id/owner_id يمنع عد الشخص مرتين. heartbeat يستعمل ساعة
الخادم وصلاحية90 ثانية. valid_until للعدد الكامل مستقل عن expires_at
لصاحب الطلب، ولا يتجاوز30 ثانية أو أقرب انتهاء بين المحتسبين. انتهاء
الصلاحية أو فشل المصدر أو غياب capability يعني unknown؛ صفر صالح عندما
يرجعه مصدر متحقق. لا تعديل في schema realtime أو publication أو grants
لإنشاء feed. مسار v1 هو polling.

الحد **2000 Unicode code points** مع السماح بـtab/LF/CR. تمنع باقي ASCII
controls وDEL، وU+0000 غير صالح أصلًا في PostgreSQL text. لا قص أو trim
أو Unicode normalization. تعتبر مجموعة whitespace التالية فارغة إذا
كانت وحدها كل النص: 9,10,13,32,160,5760,8192..8202,8232,8233,8239,8287,
12288,65279. تطبق دالة BASE لمنع تبادل بيانات الاتصال؛ العينات تشمل بريدًا
ورابطًا وهاتفًا وhandle ودعوة عربية وتاريخًا مسموحًا. لا يدعى تطابق لغوي
شامل لكل regex تاريخي غير معدل في BASE.

## نتيجة بوابة التنفيذ المحلية

أغلقت بوابة SQL/RLS محليًا على PostgreSQL17.11: **95/95 assertion PASS**.
شملت الاختبارات ACL وRLS مستقلة مع grants مؤقتة داخل rollback، منع owner
spoof، تداخل صفحات/وصول جديد، commit مع ضياع استجابة ثم retry، retry
متزامن، rollback، سباقات تعطيل/حظر/تعليق/سياسة، readback جزئي، انتهاء
الحضور، وsentinel الرسائل الخاصة بلا تغيير.

هذا لا يحول الملف إلى migration منشور. النشر يحتاج migration منفصلًا يراجعه
BIL-00 ويزيل قيد loopback فقط بعد تفويض لاحق. Realtime مستقبلًا يحتاج عقد
permissions/publication مستقلًا؛ قلب `realtime_available` وحده غير كافٍ.
لم ينشر أي contract جديد ولم يُتصل بالإنتاج.

المراجع الفنية: [RLS في Supabase](https://supabase.com/docs/guides/database/postgres/row-level-security)،
[أقفال PostgreSQL](https://www.postgresql.org/docs/current/explicit-locking.html)،
[pglast 7.7](https://pypi.org/project/pglast/7.7/).
