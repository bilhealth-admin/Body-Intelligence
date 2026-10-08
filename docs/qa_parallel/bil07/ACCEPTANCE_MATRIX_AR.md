# BIL-07 — مصفوفة القبول النهائية

**الحالة: READY_FOR_INTEGRATION.** تحقق نطاق BIL-07 محليًا على BASE
`1744788e6bfbdffc3a168bbaf36b3abf3e2c698a` / TREE `8f140791e1c2adcb21122ce64a65cb168bbe90d7`. العقد الخادمي ما زال **مقترحًا محليًا غير منشور**؛
`production_connected=false` و`production_deployed=false`.

## 1. الأدلة النهائية

| البوابة | النتيجة | الدليل |
|---|---|---|
| format | PASS exit0؛ 27 ملفًا، 0 تغيير | `tests/final/format_release.json` |
| analyze لنطاق الدور والـoverlay | PASS exit0؛ No issues found | `tests/final/analyze_release.json` |
| قنوات + routes/navigation | PASS **69/69** | `tests/final/channels_and_routing_release.json` |
| regression قريب BASE | PASS **97/97** | `tests/final/regression_release.json` |
| SQL/RLS/concurrency PostgreSQL17.11 | PASS **95/95 assertions** | `tests/sql/runtime_pg17_final/sql_results.json` |
| patch application | PASS | `tests/patch_application.json` |

الـ69 والـ97 = 166 حالة Flutter غير متداخلة. الـ95 assertions SQL نطاق مستقل.
لا تُحسب الجولات التاريخية المكررة. full portable/composition لكل الأدوار
مملوك لـBIL-00 بنص TASK، وليس شرطًا محليًا إضافيًا على BIL-07.

## 2. R1–R7

| المتطلب | قبول العميل | قبول الخادم / النتيجة |
|---|---|---|
| R1 Directory permission visibility | directory من repository، no auto-read/no auto-join، unavailable صريح | PostgreSQL: member/nonmember/banned/disabled وسuspended negative controls PASS |
| R2 Paging/send/idempotency/draft | overlap merge، explicit send، lost-response retry، owner/channel draft وABA fences PASS | transaction ordering، rollback، concurrent retry وunique idempotency PASS |
| R3 Authoritative read/unread | viewport+dwell+foreground+uncovered route، read ثم readback منفصل PASS | exact IDs، unknown/foreign/duplicate IDs، concurrent arrival، private unread sentinel PASS |
| R4 Presence | expiry→unknown، background invalidation، stale response fences، reconnect PASS | heartbeat unique owner/channel، TTL90s، block filtering، expired rows excluded PASS |
| R5 Membership/block/policy/text | client rejects/clears stale state، 2000 code points، no truncation، BASE contact policy PASS | RLS/ACL + membership/banned/disabled/policy/suspended + Unicode/control limits PASS |
| R6 Owner lifecycle | A→B→A، repository/channel replacement، close/revoke/restore fences PASS | RPC owner derives from auth.uid؛ owner spoof and unauthenticated/service/anon negatives PASS |
| R7 Preserve private chat | private routes/badge and policy review behavior PASS على overlay | SQL sentinel يثبت private messages/unread بلا تغيير؛ لا friends/rewards/join/accept/send تلقائي |

## 3. معايير TASK الصريحة

- **Directory visibility:** PASS على العميل والمحرك.
- **عضو/غير عضو/محظور:** PASS، بما فيها banned/suspended/disabled.
- **Pagination متداخل بلا فقد/duplicate:** PASS على العميل وSQL runtime.
- **send commit ثم response lost ثم retry بلا duplicate:** PASS فعليًا في SQL.
- **draft عند الإلغاء/channel switch/ABA:** PASS في اختبارات Flutter.
- **foreground/background/covered route + partial readback:** PASS.
- **القنوات لا تغير private unread:** PASS في Flutter regression وSQL sentinel.
- **presence منتهي الصلاحية:** PASS.
- **Realtime disconnect/reconnect:** PASS لدورة العميل؛ عقد v1 يعلن
  `realtime_available:false` ولا ينشئ feed، فيعمل polling وsafe failure.
- **SQL/RLS مع negative controls:** PASS 95/95 على PostgreSQL17.11.
- **عدم نشر contract:** مثبت؛ لا production connection/deploy/migration.

## 4. حدود النتيجة

هذه ليست شهادة production readiness. لا يوجد device E2E أو Supabase live أو
Realtime live أو store build أو نشر. التصميم النهائي/المراجع النهائية ودمج
كل الأدوار والـportable الكامل لدى BIL-00. وجود capability=false يعني أننا
لا ندعي مصدر Realtime غير موجود؛ الاختبارات تثبت reconnect/catch-up وسلوك
unknown/unavailable للعميل فقط.

محاولة full-repository analyze تاريخية في بيئة BIL-07 توقفت بسبب server -9؛
لم تُحوّل إلى PASS. analyze المحدد لنطاق الدور والـoverlay نجح، وTASK يضع
الفحص portable النهائي للتركيب الكامل لدى BIL-00. evidence read-only لسلامة
BASE نفسه موجود منفصلًا في `tests/base_ci/exact_base_1744788/` ولا يُحسب
ضمن اختبار عمل BIL-07.
