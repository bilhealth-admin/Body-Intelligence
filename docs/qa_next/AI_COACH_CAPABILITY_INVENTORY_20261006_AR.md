# جرد قدرات AI Coach — 2026-10-06

## مصدر الجرد وحدود الإثبات

جرد مصدر التطبيق المنشور عند `6f4ccc1374d643678bee02db39951cab14c573a4`.
اجتاز QA checkpoint `7046710f8625aa1b2b9915cc6beff4011c37fefa` [الجولة الكاملة](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37545878945)،
6985 حالة regression عبر 1136 ملفًا. تدقيق القدرات أدناه قراءة مصدر؛ وجود الدالة لا يثبت تغطية كل سيناريو أو اكتمال تجربة المستخدم.
إصلاح سياق الطعام P0 في هذه الدفعة يضيف 34 حالة تنتظر تنفيذ CI عند حفظ هذا الجرد.

| نطاق المصدر | Canonical tools | Action types |
|---|---:|---:|
| المنشور | **23** | **24** |
| Food host WIP بإضافة log_foods وreplace_meal_item | **25** | **26** |

تحقق الجذر من العددين المنشورين مباشرة من registry وenum. الأداتان الغذائيتان الإضافيتان من العمل المحلي؛ لا تُنسبان إلى الفرع قبل دمجهما.
تتوزع الأدوات المنشورة إلى 9 كتابات بمعاملات، وعمليتي إعدادات، وقراءتين، و9 عمليات تنقل، وتسجيل خروج فعلي.

## الأوامر المنشورة

| Canonical IDs | نوع التنفيذ والمستودع | Readback / Undo | الحدود المثبتة |
|---|---|---|---|
| `quick_add_macros` | `transactional_write` — `MealRepository / CoachMealCommand.quickMacros` | durable meal operation؛ operation journal + item CAS + transcript recovery | 1905 يبقى إدخال سعرات فقط؛ لا foods/macros مختلقة. اقتراح السعرات يحتاج تأكيدًا جديدًا. |
| `update_meal_item`، `delete_meal_item`، `move_meal_item` | `transactional_write` — `MealRepository Coach commands` | durable meal operation؛ operation journal + item CAS + transcript recovery | حراسة quantityGrams من وحدة legacy تدخل ضمن Food host WIP؛ لا تُنسب للمنشور. |
| `log_water`، `log_weight`، `update_goal`، `save_measurements`، `save_memory` | `transactional_write` — `CoachNativeCommandRepository.prepare/commit/undo` | _commitReadback after transaction؛ journal/full snapshot CAS in the active session; transcript recovery missing | owner/epoch guards موجودة. تحويل pounds إلى kg موجود؛ لا ادعاء تغطية كل اللهجات. استعادة Undo بعد إعادة فتح المحادثة ناقصة. |
| `set_theme_mode`، `set_language` | `settings_write` — `AppSettingsController / AppSettingsService.save` | requested value, not independent committed readback؛ closure restoring the prior value; no version CAS or durable recovery | الحفظ فعلي؛ readback المستقل وUndo الآمن ما زالا بحاجة للإغلاق. |
| `read_nutrition_remaining`، `read_profile_identity` | `read` — `coachContextSnapshotProvider` | current context؛ not applicable | identity يقرأ displayName فقط. P0 قيد التنفيذ على CI؛ سياستا no-day/missing-target في nutritionRemainingFor خارج هذه الدفعة. |
| `navigate`، `open_weight_log`، `open_meals`، `open_meals_yesterday`، `open_workouts`، `open_plan`، `open_report`، `manage_subscription`، `request_account_deletion` | `route_only` | no committed write؛ not applicable | yesterday يختار يوم السجل ولا ينسخ وجبة. subscription يفتح plans؛ deletion يفتح help بعد التأكيد. لا شراء أو حذف حساب منفذ. |
| `sign_out` | `auth_side_effect` — `Supabase auth` | auth.currentSession == null؛ none | تسجيل خروج فعلي؛ لم تُنفذ مكالمة auth خلال هذا التدقيق. |

يقيد `CoachActionAdmission.bind` نوع الأداة والوسائط المسموح بها ويطلب operationId للكتابة.
بوابة الأذونات تفصل القراءة والتأكيد والسماح بالكتابة، وتحتفظ العمليات الحساسة/destructive بتأكيدها.
owner/epoch/repository guards تلغي العمليات القديمة. tier الافتراضي للـdescriptor لا يغير entitlement أو quotas.

مسارات `openDailyLog`، `openAiCoachSubscription`، `buyAiBoost` الموجودة كـenum هي handoff كذلك.
فتح صفحة في التطبيق لا يُسجل كقدرة Coach للكتابة في مستودعها.

## شريحة الطعام المحلية

`log_foods` و`replace_meal_item` تمران في WIP عبر native preparation وreviewId محلي،
ومراجعة immutable ذات 13 مغذيًا nullable، ثم معاملة مستودع وcommitted readback.
تظل source confidence مستقلة عن quantity evidence؛ Personal BIL مرتبط بالمالك والإصدار والتأكيد الصريح.
لا تُستعار قيم USDA من model payload، ولا تتحول ml تلقائيًا إلى g. استعادة المراجعة التاريخية لا تعيد قراءة كتالوج أو قواعد حديثة.

أثبت host-r9 محليًا **99 PASS** قبل انقطاع البيئة. digest:
`4f2d44b62fd676a2ff63450eb8eea901a64beb65cf1f73b6f3e43ad21b2fe77a`.
إصلاح نقل صنف من batch ثم التصحيح التالي مغلق ضمن هذا الدليل المحلي؛
`_rememberCoachFoodCommit` يضيق correctionRows إلى result.after عند تعدد meal UUID.
هذه النتيجة لا تمثل نجاحًا على GitHub إلى أن تُدمج bytes المتحقق منها ويُعاد اختبارها.

## قدرات التطبيق التي تحتاج ربطًا إضافيًا بـCoach

- recipe serving يملك `TrustedRecipeDiaryService.addServing`، لكن لا canonical commit tool مقابلًا.
- workouts/plans لها واجهات ومستودعات، وأوامر Coach الحالية تفتح المسارات.
- sleep/day close/reopen/reminders/exports/units/fasting ليست أوامر كتابة canonical مكتملة.
- Community composer/chat/follow/moderation تبقى وظائف مستقلة؛ لا نشر أو إرسال أو متابعة أو policy acceptance آليًا من Coach.
- إدارة قائمة/حذف الذاكرة متاحة كواجهة؛ الأداة canonical المنشورة هي save_memory.
- Voice يمرر transcript لمسار الاستعلام؛ هذا الجرد لا يثبت تشغيل أجهزة أو مزودي صوت.
- photo/barcode لم يغلقا مسار typed verified food review-to-commit بعد.

## ترتيب الإكمال

1. تحقق CI من P0 للسياق الغذائي.
2. دمج Food host وPersonal BIL على SHA واحد مع الصور والاختبارات.
3. استعادة Undo للأوامر غير الغذائية بعد إعادة فتح المحادثة.
4. readback مستقل وCAS Undo للإعدادات.
5. تصحيح day/type فقط و«زي أمس».
6. ربط photo/barcode بمراجعة غذاء موثقة.
7. توصيل أوامر محلية إضافية على مراحل مع readback واختبارات واضحة.

## مراجع المصدر

- registry: [lib/features/intelligence_center/domain/bil_tool_registry.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/domain/bil_tool_registry.dart)
- action_types: [lib/features/intelligence_center/domain/intelligence_action.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/domain/intelligence_action.dart)
- admission: [lib/features/intelligence_center/domain/coach_action_admission.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/domain/coach_action_admission.dart)
- permission: [lib/features/intelligence_center/domain/coach_action_permission.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/domain/coach_action_permission.dart)
- execution: [lib/features/intelligence_center/presentation/intelligence_action_flow.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/presentation/intelligence_action_flow.dart)
- meal_execution: [lib/features/intelligence_center/presentation/intelligence_meal_action_flow.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/presentation/intelligence_meal_action_flow.dart)
- meal_recovery: [lib/features/intelligence_center/presentation/intelligence_meal_recovery.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/presentation/intelligence_meal_recovery.dart)
- meal_commands: [lib/data/repositories/meal_repository_coach_commands.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/data/repositories/meal_repository_coach_commands.dart)
- meal_food: [lib/data/repositories/meal_repository_coach_food.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/data/repositories/meal_repository_coach_food.dart)
- meal_journal: [lib/data/repositories/meal_repository_coach_journal.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/data/repositories/meal_repository_coach_journal.dart)
- meal_undo: [lib/data/repositories/meal_repository_coach_undo.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/data/repositories/meal_repository_coach_undo.dart)
- native_repository: [lib/features/intelligence_center/services/coach_native_command_repository.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/services/coach_native_command_repository.dart)
- native_execution: [lib/features/intelligence_center/presentation/intelligence_native_action_flow.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/presentation/intelligence_native_action_flow.dart)
- context: [lib/features/intelligence_center/services/coach_context_provider.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/services/coach_context_provider.dart)
- context_assembly: [lib/features/intelligence_center/services/coach_context_assembly.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/services/coach_context_assembly.dart)
- context_domain: [lib/features/intelligence_center/domain/coach_context_snapshot.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/domain/coach_context_snapshot.dart)
- meal_evidence: [lib/data/database/meal_food_evidence.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/data/database/meal_food_evidence.dart)
- food_basis: [lib/data/database/food_basis_evidence.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/data/database/food_basis_evidence.dart)
- food_domain: [lib/features/intelligence_center/domain/food_v2/coach_food_v2.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/domain/food_v2/coach_food_v2.dart)
- settings: [lib/app/services/app_settings_provider.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/app/services/app_settings_provider.dart)
- settings_storage: [lib/app/services/app_settings_service.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/app/services/app_settings_service.dart)
- navigation: [lib/features/intelligence_center/domain/bil_navigation_registry.dart](https://github.com/bilhealth-admin/Body-Intelligence/blob/6f4ccc1374d643678bee02db39951cab14c573a4/lib/features/intelligence_center/domain/bil_navigation_registry.dart)

البيانات المنظمة: [evidence/ai_coach_capability_inventory_20261006.json](evidence/ai_coach_capability_inventory_20261006.json).
تبقى قيود QA وProduction والمتاجر وأرقام 35/32 والأسعار وTrial والموارد المدفوعة كما قررها المالك.
