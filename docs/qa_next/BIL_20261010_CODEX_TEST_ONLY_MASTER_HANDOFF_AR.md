# BIL 2026 — التسليم الموحد لكوديكس: إصلاح الاختبارات فقط
**التاريخ 10 أكتوبر 2026. حالة الملف: جرد وتسليم، وليس اعتماد إصدار أو دليل نجاح اختبار جديد.**

## 1. نقطة الحقيقة والصلاحيات
- Repository: bilhealth-admin/Body-Intelligence
- Branch الوحيد: qa/bil-quality-ux-integration-20261009
- Pull request: https://github.com/bilhealth-admin/Body-Intelligence/pull/11 — Draft/Open/Unmerged.
- HEAD المراجع قبل هذا التسليم: 49c13b9ee121cef359dee97a1f18cefa821de818. اقرأ HEAD الحالي دائمًا أولًا؛ Commit وثيقة التسليم سيضيف نقطة أحدث.
- آخر Commit اجتاز P0 (11) وVision (12) وAndroid Debug وiOS Simulator: 5957a1eb5ad191f1945955f31dd49d9172587799. لا ترجع إليه، ولا تفقد ما جاء بعده.
- مصدر Android code 32 / iOS build 35: 3f0085e6e6686f2e87e9cf14789e9e578ea64159. تاريخ QA يتحدر منه؛ لا يُعاد نسخ الأعمال ولا squash للتاريخ.
- Codex مخصص **لإصلاح مشاكل الاختبارات وتهيئة تشغيلها محليًا فقط**؛ الإصلاحات الحقيقية في التطبيق من صلاحية محادثة التطوير الأساسية. لا تغيّر كود التطبيق لمعالجة assertion؛ قدم التشخيص والملف والسطر واقتراح الإصلاح وارجع لصاحب الطلب.
- ممنوع main أو الدمج أو force push أو النشر أو تعديل Supabase Production أو الدفع والأسعار وTrial وحصص AI والـBoost أو نسخ المتاجر. لا تلمس Dashboard/Home المحمي أو Log Food أو الشريط السفلي ذي خمس وجهات، ولا تغيّر Golden تلقائيًا.

## 2. ماذا نحفظ دون فقد
- BIL-00 وBIL-01…08 الموجودة في QA؛ QUALITY PR #10 وفرع UX PR #9. عند جرد سابق كان 49 UX blob مطابقًا و23 مسارًا متداخلًا مختلفًا؛ التعارض لا يُحل باستبدال ملف كامل دون مقارنة.
- AI Coach: ثبات النص أثناء الظهور، عدم وميض Feedback/Sources، الحفاظ على emoji/graphemes، نقل الرسائل وعدم فشل route، التسجيل الفعلي وليس جملة «تم التسجيل» فقط، عزل الحساب وتوثيق المصدر وتصحيح القيد بدل التكرار.
- Vision Premium: صورة الطعام الأصلية، الثقة في التعرف لا السعرات، تعدد الأصناف والبدائل والبقايا والمأكول، تأكيد الكمية، سند الغذاء الموثوق، الملخص والكامل والمعادن/الألياف/صافي الكارب، إظهار غير متوفر بوضوح. SQLite batch atomic + rollback + request replay dedupe + tenant isolation. احتفظ بالوحدات الحقيقية g/kg/oz/lb/mg مع أساس وزن، وpiece/ml دون اختلاق غرامات.
- First Use: Glass/coachmarks وأنيميشن هادئ، زر Skip في كل خطوة أسفل البطاقة لمراجعي Google/Apple، احتفال أول وجبة فقط بعد الحفظ مرة واحدة لكل مالك، reduced-motion.
- Community: نشر ثابت دون نقر مكرر، Scroll/Pagination، عودة صحيحة من إشعار الرسائل والموافقات في cold/warm start، عدم شاشة بيضاء أو stuck back. Customize Today: أزرار لا تومض وتراجع صحيح عند فشل الحفظ.
- Connected Health/Sleep: أسماء Apple Watch والمصادر المقروءة بدل JSON؛ لا تختلق جهازًا أو قياسات. Notifications / settings / Profile / More: أيقونات رمادية مسطحة بلا shadow/gradient، SF/Material بحسب السياق، 48dp hit targets، RTL/LTR.
- Home/Dashboard: لا تتغير الهوية أو Captain BIL أو 5 tabs أو العرض المعتمد أو Log Food. السعرات المستهلكة/الهدف/المتبقي/التجاوز قيم حقيقية. ظل الوزن الأخضر/السهم/الساعة/Body Twin عناصر طلبها المالك ومراجعتها بصريًا لا تعني الإذن بإعادة تصميم Home.
- UX reference 146: المرجع/المسارات في docs/visual_2026/reference_146_inventory.csv وflutter_route_coverage.csv. ليس هناك إثبات مطابقة كل مرجع؛ Goldens المراجعة منفردة فقط، مع السماح الصريح بكل تغيير.
- Google Play code 32: رفض بسبب الوصول المحجوب للمراجع وراء Paywall؛ ورد تعليق/إزالة التطبيق بعد الرفض المتكرر. تتضمن المخاطر أزرارًا غير فعالة وصلاحيات Health Connect زائدة. التحقق من صلاحيات حساب المراجع وتعليمات الوصول والمسارات دون تغيير الأسعار أو منح Premium مزيف. لا رفع Android 33 ولا استئناف تلقائي.

## 3. آخر إخفاقات مثبتة ودقيقة
- على 49c13b9: Flutter Analyze قال No issues found، لكن Source Gate فشل في Dart format لملفين:
  test/features/nutrition/meal_vision_flutter_capture_test.dart
  test/launch_readiness/navigation_and_more_master_closure_test.dart
  وبالتالي بقيت P0/focused/broad/full متخطاة. لا تعتبرها اختبارات كود فاشلة.
- Arabic capture فشل قبل الرسم بسبب تنسيق test؛ حتى بعد تصحيحه يجب فتح PNG الأربع للحروف العربية المتصلة، وإثبات عدم ظهور مربعات Ahem. تغيير Theme في test لا يكفي وحده.
- على d6029699 نجحت المجموعات الخمس focused وCommunity cold-back، وفشلت 5 broad بمجموع 45 حالات؛ 29 Golden غير معتمدة. ليست 45 عيبًا إنتاجيًا مثبتًا.
- عطل حقيقي: 1px RenderFlex overflow في dashboard-reference-calories-card لـEnglish LTR مقاسات 320/390/430. اختبارات probe تبقى حمراء؛ Home محمي، فلا تغير الكود ولا تكتم exception.
- Vision matrix: 25 حالة بالتفصيل في docs/qa_next/BIL_20261010_VISION_25_CASE_EVIDENCE_MATRIX_AR.md، بعضها unit/widget مثبت، لكن الأجهزة الفعلية/Camera/Picker/Offline/RTL 2x وSQLite-to-Dashboard لم تعتمد بعد.
- Goldens: docs/qa_next/BIL_20261010_VISUAL_GOLDEN_29_INDIVIDUAL_REVIEW_AR.md. لا --update-goldens عشوائي ولا تخفيض thresholds ولا تحديث master-image لمجرد نتيجة مختلفة.

## 4. مصدر Production: قراءة فقط، دون تعديل
فُحص مشروع Supabase Production tgmanzhqulksykhslrzb في 10 أكتوبر 2026: ACTIVE_HEALTHY؛ دوال analyze-meal v103 وai-coach v106 وfood-search v60 تعمل بنشر مستقل. هذا لا يثبت مطابقة source المحلي مع cloud. لا deploy أو export/write.
Security Advisors أظهر WARN للدالة public.bil_preview_community_invite_v1 المسموح بتنفيذها لـanon مع SECURITY DEFINER، و145 دالة AUTHENTICATED SECURITY DEFINER، وتحذير حماية كلمات المرور المسربة. هذه تنبيهات مراجعة سياق/صلاحيات، لا حكمًا بوجود ثغرة ولا إذنًا بإصلاح Production.
References: https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable ، https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable ، https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## 5. سلم Codex الاقتصادي المحلي
استخدم Python 3.10+ وFlutter 3.44.6 على فرع QA:
python tools/qa/bil_codex_test_ladder.py --through-stage arabic
بعد إصلاح تنسيق الملفات فقط: Source format/Analyze ثم Arabic Capture المنفرد.
ثم:
python tools/qa/bil_codex_test_ladder.py --through-stage p0
python tools/qa/bil_codex_test_ladder.py --through-stage focused
python tools/qa/bil_codex_test_ladder.py --through-stage broad
وفقط إن كانت كلها خضراء على نفس HEAD والعمل المحلي بلا تعديل:
python tools/qa/bil_codex_test_ladder.py --through-stage full --parallel 3
البرنامج يعيد استعمال نجاح نفس HEAD ونفس بصمة التعديلات فقط، ويسجل النتائج في build/bil-codex-qa؛ تغيير الملفات يلغي صلاحية النجاح السابق. لا تشغل full عند فشل Gate سابقة. إن كان البرنامج نفسه معطوبًا أصلحه كتجهيز اختبارات لا كتغيير التطبيق.

## 6. مراجعة مستقلة لاحقة من المحادثة الأساسية
بعد تسليم Codex، ستعيد محادثة التطوير اختبارات الاستقرار المتقدمة: Flutter unit/widget/integration وSQLite readback، Android/iOS Debug+Simulator ثم الهاتفين الفعليين، Widget tree وGolden per-screen، 320/390/430/tablet، themes و25 لغة/RTL و1.8x/2x وVoiceOver/TalkBack، التنقل deeplink/restart، Lifecycle/background/permissions/offline/timeouts، التزامن والتكرار وتبديل الحساب، الأداء/التسرب والذاكرة/الطاقة/crash، أمان RLS/authorization ودفع المتاجر وبيانات حقيقية مخفية الهوية. كل نوع يتطلب دليلًا، ولا تعني قائمة الفحوص أنها نُفذت.

## 7. مراجع إلزامية موجودة ولا تُستبدل
- PR #11 handoff: https://github.com/bilhealth-admin/Body-Intelligence/pull/11#issuecomment-6098144449
- PR #11 cumulative history: https://github.com/bilhealth-admin/Body-Intelligence/pull/11#issuecomment-6098098577
- docs/qa_next/BIL_20261010_STORE32_IOS35_TO_QA_COVERAGE_AND_TEST_LADDER_AR.md
- docs/qa_next/BIL_20261010_FIRST_USE_HANDOFF_TO_NEXT_CHAT_AR.md
- docs/qa_next/BIL_20261010_AI_VISION_QA_FORMAL_HANDOFF_AR.md
- docs/qa_next/BIL_20261010_VISION_P0_DURABLE_REPLAY_AND_COACH_PROVENANCE_AR.md
- docs/qa_next/BIL_20261010_VISION_MIXED_UNITS_NO_FABRICATED_GRAMS_AR.md
- docs/qa_next/BIL_20261010_BROAD_FAIL_CLASSIFICATION_AND_CONTRACT_RECONCILIATION_AR.md
- docs/qa_next/BIL_20261010_DASHBOARD_OVERFLOW_AND_MORE_CONTRACT_QA_AR.md
- docs/qa_next/BIL_20261010_ARABIC_VISION_GLYPH_EVIDENCE_AR.md

## 8. تسليم Codex العائد
أرسل إلى PR #11 تعليقًا واضحًا يتضمن: exact branch/HEAD، status نظيف أو diff paths، مجموعة ملفات الاختبار التي أصلحها ولماذا، format/analyze وArabic PNG evidence، كل Gate أعداد success/fail/skip مع أوامر التشغيل وروابط logs، تصنيف كل Golden اختلاف/fixture/عيب، ما يحتاج إصلاحًا إنتاجيًا ممنوعًا عليه، وما يلزم الأجهزة الحقيقية. ارفع test-only patches على نفس QA branch في commits صغيرة قابلة للمراجعة، ثم **توقف تمامًا** دون Merge/Deploy/Store. لا تقل READY ما لم تثبت الأدلة.
