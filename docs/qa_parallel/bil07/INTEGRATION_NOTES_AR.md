# BIL-07 — ملاحظات الدمج إلى BIL-00

**الحالة: READY_FOR_INTEGRATION.** تم اختبار owned source مع shared overlay
محليًا على BASE `1744788e6bfbdffc3a168bbaf36b3abf3e2c698a`. لا يوجد push/PR/CI dispatch/rerun أو نشر.

## ترتيب التطبيق

1. ابدأ من BASE/TREE المحددين أعلاه.
2. طبّق `owned.patch`؛ يضيف مصدر BIL-07 فقط تحت prefixes المملوكة.
3. راجع `integration-proposal.patch` وادمج hunks يدويًا مع تغييرات الأدوار
   الأخرى. المقترح يلمس خمس مسارات مشتركة فقط:
   - `lib/app/router/app_router.dart`
   - `lib/app/router/app_community_routes.dart`
   - `lib/features/community/presentation/community_hub_page.dart`
   - `lib/features/community/presentation/community_navigation_sheet.dart`
   - `tool/prebuild/run_code_tests.py`
4. أعد full portable/composition بعد دمج كل الأدوار. لا يعتبر BIL-07
   اختباره المحلي إثباتًا لتوافق جميع المقترحات المتوازية.

## بوابات BIL-07 التي أغلقت

- format PASS exit0.
- scoped analyze PASS exit0 / No issues found.
- channels+routing PASS69/69.
- nearby regression PASS97/97.
- PostgreSQL17.11 SQL/RLS/concurrency PASS95/95 assertions.
- patch application PASS.
- client reconnect/disconnect/catch-up PASS، بينما capability الخادم المقترح
  `realtime_available:false` ومسار v1 polling.

تفاصيل الأوامر والـexit codes والبصمات في `tests/`. لا تجمع الجولات السابقة
المتداخلة مع أرقام release النهائية.

## SQL server proposal

كل توسعة الخادم ضمن `tool/qa_parallel/bil07/sql/`. `channel_contract_v1.sql`
forward-only محلي ومقصود أن يرفض قاعدة ليست `bil07_local_*` أو host غير
loopback. تم اختباره فعليًا على PostgreSQL17.11 تحت مستخدم OS غير root.
حارسا loopback يستخدمان `pg_catalog.host(inet_server_addr())` لتجنب صيغة
CIDR (`127.0.0.1/32`) مع بقاء السماح محصورًا في127.0.0.1/::1.

**لا تطبق الملف نفسه على production.** إذا اعتمد BIL-00 العقد لاحقًا، يجب
إنشاء migration إنتاجية منفصلة ومراجعة grants/RLS/Realtime authorization
وفق قرار الخادم. `realtime_available:false` لا يُقلب دون feed وصلاحيات فعلية.

## analyze والـportable

المطلوب المحلي `analyze` لنطاق BIL-07 والملفات الجامعة المتأثرة نجح.
محاولة قديمة لـ`flutter analyze --no-pub` على كامل snapshot توقفت مع
analysis server -9؛ تبقى evidence تاريخية ولا تُسمى PASS. بنص TASK،
**فحص portable الكامل على التركيب النهائي لدى BIL-00**، لذلك لا تعد هذه
المحاولة فجوة تمنع تسليم الدور بعد إغلاق SQL/RLS.

## ما لم يتغير

- لا version/build 35/32.
- لا pricing/paywall/trial/AI quota.
- لا private chat semantics أو badge ownership.
- لا friends/rewards أو auto-join/auto-policy-accept/auto-send.
- لا pubspec.lock أو SDK/shared cache داخل التسليم.
- لا production Supabase/Cloudflare أو credentials أو device/store builds.
