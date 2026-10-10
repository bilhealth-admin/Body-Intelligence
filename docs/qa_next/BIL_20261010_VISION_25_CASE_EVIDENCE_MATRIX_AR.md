# BIL AI Vision — مصفوفة الإثبات للحالات الـ25

**المستودع والفرع:** `bilhealth-admin/Body-Intelligence`، `qa/bil-quality-ux-integration-20261009`، PR #11 Draft. هذه المصفوفة **تتبع لا شهادة جاهزية**. اللامستعمل/غير المختبر معلَّم بوضوح.

## مراجع فحوص فعلية
- [Fast P0 #38050194517](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38050194517): مصدر + 10/10 مجموعات نجحت على `432a0e56`.
- [Fast P0 #38053137136](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38053137136): المصدر + 11/11 مجموعات ذرّية/وحدات على `5957a1eb`، وكلها نجحت مع Aggregate.
- [Vision #38049022857](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38049022857): 12/12 focused وتحليل وبناء Android وiOS Simulator نجحت على `f7516e11`.
- [Vision #38053137123](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38053137123): focused/capture على `5957a1eb`، ويبقى اعتماد بناء الأجهزة حسب نتائج Actions النهائية.
- لا يُعاد اختراع بيانات غذائية من صور، ولا تُستخدم عبارة PASS شاملة لحالة تحتاج جهازًا فعليًا.
- كل أسماء الاختبارات أدناه أسماء ملفات تحت `test/features/nutrition` أو `test/features/intelligence_center` أو `test/features/global_platform` أو `test/features/daily_log` أو `test/parallel/bil02` كما هو موضح بالمستودع.

## التغطية حسب الحالة
| # | الحالة | اختبار/مسار موجود | حدود الإثبات |
|---|---|---|---|
| 01 | صورة واحدة واضحة | `meal_image_unified_review_contract_test.dart + meal_vision_domain_contract_test.dart` | تحقق parser/contract؛ كاميرا حقيقة مؤجلة |
| 02 | أصناف متعددة | `meal_vision_verified_commit_test.dart` | دفعة SQLite ذرية لوحدات مختلطة؛ UI متعدد الأصناف بصورة فعلية مؤجل |
| 03 | البقايا والمأكول جزئيًا | `meal_vision_premium_review_test.dart` | اختبار البقايا وتأكيد المأكول البرمجي |
| 04 | كمية مجهولة/صفر | `meal_vision_premium_review_test.dart + meal_vision_verified_commit_test.dart` | لا حفظ دون كمية صالحة |
| 05 | طعام غير معروف | `coach_media_page_overlay_test.dart + meal_vision_domain_contract_test.dart` | لا تخليق سجل غذائي؛ رحلة إضافة مخصصة تحتاج E2E |
| 06 | بديل لصنف مختلف | `meal_vision_premium_review_test.dart` | لا توريث verified record id للبديل |
| 07 | ثقة التعرف منخفضة | `meal_vision_domain_contract_test.dart` | نقل uncertainty/low-confidence؛ التنبيه الحقيقي على جهاز مؤجل |
| 08 | غياب مصدر غذائي معتمد | `coach_media_page_overlay_test.dart + food_basis_evidence_test.dart` | إيقاف الحفظ؛ Coach يسمح بملصق حديث مثبت بالمالك فقط |
| 09 | مغذيات ومعادن ناقصة | `meal_vision_verified_commit_test.dart + daily_log_nutrition_evidence_test.dart` | Evidence mask يصون unavailable بدل صفر |
| 10 | استجابة تحليل فارغة | `meal_vision_domain_contract_test.dart` | no-food/empty parsing؛ UI الرسالة الفعلية مؤجل |
| 11 | فشل اتصال | `vision_recovery_system_test.dart + epic6_voice_vision_gateway_test.dart` | فشل/retry وإيصال الطلب ثابت |
| 12 | مهلة طويلة | `vision_recovery_system_test.dart` | حد retry/lifecycle؛ اختبارات انقطاع الشبكة الحقيقية مؤجلة |
| 13 | فشل الكاميرا | `coach_media_page_overlay_test.dart` | native permission denial في mock؛ أجهزة حقيقية مؤجلة |
| 14 | رفض إذن معرض الصور | `coach_image_source_regression_test.dart` | platform error مترجم، no partial write |
| 15 | رفض موافقة AI | `vision_recovery_system_test.dart + meal_photo_initial_action_test.dart` | consent withdrawn/no raw image persisted؛ مراجعة فورية على جهاز مؤجلة |
| 16 | نفاد رصيد Vision | `meal_vision_quota_contract_test.dart + epic6_voice_vision_gateway_test.dart` | Boost/Coach quota حسابي، دون تعديل الاشتراك |
| 17 | غير متصل بالإنترنت | `vision_recovery_system_test.dart` | مسار التعافي؛ اختبار طيران/Offline فعلي مؤجل |
| 18 | النقر المزدوج على الإضافة | `meal_vision_verified_commit_test.dart` | same request replay/concurrent duplicate readback PASS |
| 19 | إلغاء قبل الحفظ | `coach_image_source_regression_test.dart + meal_vision_premium_review_test.dart` | لا صف/ولا receipt |
| 20 | فشل الحفظ وسط دفعة | `meal_vision_verified_commit_test.dart` | rollback كامل للوجبة والإيصال |
| 21 | رجوع/لوحة المفاتيح/المسودة | `coach_image_source_regression_test.dart + audited_route_return_source_contract_test.dart` | المسودة مصونة؛ لوحة المفاتيح على أجهزة حقيقية مؤجلة |
| 22 | أجهزة 320px/تابلت | `meal_vision_flutter_capture_test.dart` | لقطات Flutter محفوظة؛ مصفوفة 320/tablet يحتاج إثبات |
| 23 | تكبير الخط 1.8× و2× | `release_accessibility_regression_test.dart` | تغطية عامة؛ تجربة Vision 2x/overflow تحتاج إثبات منفصل |
| 24 | العربية RTL و25 لغة | `meal_image_language_regression_test.dart + meal_vision_quota_contract_test.dart` | لغات copy/parse ناجحة؛ لقطات RTL/الأجهزة ليست معتمدة |
| 25 | حفظ واحد وتحديث الإجماليات | `meal_vision_verified_commit_test.dart + meal_declared_unit_commit_test.dart` | SQLite مقدار/مغذيات/readback ثابت؛ Dashboard end-to-end يحتاج إثبات |

## شروط إطلاق قرار الاعتماد
1. كل اختبار source/p0/focused/broad/full على **نفس HEAD**؛ لا ترث شهادة نسخ أقدم.
2. حالات 01/02/13/14/17/21/22/23/24/25 تحتاج سيناريو هاتف Android وiPhone فعلي مع Camera/Picker/RTL/تكبير/Offline/رجوع، ومقارنة صور BIL في الظروف المحمية.
3. تأكيد من صفحة السجل والـDashboard أن الوجبة كُتبت مرة واحدة بكل مغذياتها الدقيقة، لا بمجرد إشعار `تم التسجيل`.
4. مراجعة Goldens الفردية؛ لا Auto `--update-goldens` لجميع الصور، ولا السماح بفشل صامت.
5. لا main، Production، الأسعار، Trial، build 32/35، PR merge قبل الاعتماد.

**سجل أصل الإصلاحات منذ نسختَي المتجر:** `docs/qa_next/BIL_20261010_STORE32_IOS35_TO_QA_COVERAGE_AND_TEST_LADDER_AR.md`.
