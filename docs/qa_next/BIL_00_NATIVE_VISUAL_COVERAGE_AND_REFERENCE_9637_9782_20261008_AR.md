# BIL-00 — جرد المراجع وتوسيع الإثبات البصري الأصلي (8 أكتوبر 2026)

> **QA فقط / ليس موافقة نشر.** هذا المستند جزء من تسليم فرع `qa/coach-community-next-20261005`. يحظر تغيير `main`، أو Supabase Production، أو APK/AAB/IPA، أو الأسعار/Trial، أو تصميم Dashboard. لا يثبت أي screenshot وحده امتثال المتجر أو pixel parity.

## 1) فصل عائلات المراجع — لا دمج اصطناعي

| العائلة | هوية الاعتماد | الحكم |
|---|---|---|
| Coach المعتمد BIL | SHA256 `07f25ba0fffc661e5232a4fba6365ee3ff96cbea69636c2672b97f4fafce63d0` | مرجع Coach مستقل |
| Community المعتمد BIL | SHA256 `db67d1c6bb1f4ecd3c539ada3de72a980c610b7c1d2331c4796b7fa27e3bbea4` | مرجع Community مستقل، ثماني شاشات مفاهيمية |
| «مقترح جديد .zip» | SHA256 `7022bec63b1f6d4a032a1418a333e1c982930d8354963615a2be4455213beb17` | **146 ملف PNG متصل `IMG_9637.PNG` حتى `IMG_9782.PNG`**؛ إلهام/مقارنة منفصل، لا يتطابق مع `IMG_48xx` في `tool/visual_reference_manifest.dart` |
| إصدارات Native Flutter | GitHub Actions QA artifact `11555157708` على SHA `d1b67b7` | **155 PNG** مبدئيًّا: Coach 11 + Community 144، مطابقة bytes للحزمة السابقة؛ إثبات التقاط فقط، لا إثبات تطابق مرجع |

الصور الأصلية خاصة بالمستخدم وغير منسوخة إلى المستودع. `IMG_9782.PNG` عبارة عن لقطة لمحادثة نصية وليست مرجع واجهة Native؛ تحفظ بالجرد وتستبعد من التقييم البكسلي للتطبيق.

## 2) جرد تسلسلي أولي لحزمة `IMG_96xx/97xx`

التصنيف أدناه مبني على المعاينة البصرية للمصغرات، **وليس** خريطة موثقة routes/states. يجب مطابقة كل شاشة بمسار التطبيق وحالتها، أو تصنيفها صراحة reference-only.

| أرقام الملفات | العدد | العائلة المرئية | قيد الإغلاق |
|---|---:|---|---|
| `9637–9654` | 18 | Diary / Food Search / Quick Add / Home | Dashboard **read-only**؛ ممنوع أي تغيير بصري |
| `9655–9667` | 13 | Progress / nutrition analysis / weekly reports | تُقارن بالمسارات الموجودة فقط |
| `9668–9671` | 4 | Measurements | قياسات المستخدم يجب ألا تُستنتج من صور العينات |
| `9672–9673` | 2 | More menu | فصل native menus عن mockups |
| `9674–9680` | 7 | Food scan onboarding / Premium | تسعير واستحقاقات وTrial خارج نطاق التعديل |
| `9681–9701` | 21 | Cardio / exercise search and entry | لا تُنشأ ميزات وهمية من المرجع |
| `9702–9708` | 7 | Profile / fasting / sleep | مطابقة حالة/مصدر قبل بكسلات |
| `9709–9715` | 7 | Recipes | بيانات الوجبات وسجلها قابلة للتحقق |
| `9716–9723` | 8 | Workouts / routines | مقارنة Native وظيفية ثم بصرية |
| `9724–9733` | 10 | Goals / nutrition / notifications / steps | Dashboard لا يُمس بصريًا |
| `9734–9743` | 10 | Community / learning | مرجع BIL Community المعتمد له الأولوية |
| `9744–9749` | 6 | Friends / messages | Chat مباشر ليس قناة Community |
| `9750–9760` | 11 | Settings / privacy / security | لا خلط بين أمثلة MFP وعقود BIL |
| `9761–9766` | 6 | Onboarding / account / health | تحقق من مسار الدخول قبل وصفه |
| `9767–9773` | 7 | Help / support | لا تنسخ هوية منتج خارجي |
| `9774–9780` | 7 | Diary / Quick Add / water / weight / exercise | Dashboard تجميد بصري تام |
| `9781` | 1 | Workouts | لقطة مرجعية منفصلة |
| `9782` | 1 | محادثة نصية | ليست مرجع Native للشاشة |
| **الإجمالي** | **146** | | لا يجوز الادعاء بأن manifest القديم غطاها |

## 3) توسيع لقطات Flutter البرمجية دون لمس التطبيق

تم تجهيز امتداد اختبارات **فقط** في `test/features/community/community_polish_visual_test.dart`. يبقى الاختبار على شاشة Flutter الحقيقية مع Supabase synthetic `.invalid` وبدون Credentials أو Backend writes.

| Scene | واجهة Flutter الفعلية | Fixture | ماذا تثبت |
|---|---|---|---|
| `drafts` | `CommunityDraftsPage` | أربع صور مصغرة معتمدة من أصول BIL المحلية، مقيّدة الحجم ومتحقَّق من فك ترميزها | يُظهر 2×2 mosaic حقيقي وmetadata؛ لا يثبت التطابق البكسلي مع مرجع المالك |
| `circles` | `CommunityCirclesPage` | قائمتا 10K Steps وHealthy Eating عبر `ManagedCommunityCircle` | عرض Discovery وMembership وحجم النص |
| `moderation` | `CommunityPostModerationPage` | Moderator synthetic + منشور pending | عرض البطاقة وأزرار approve/reject دون اعتماد فعلي |
| `channels` | `CommunityChannelsPage` | 6 قنوات synthetic read-only ذات أسماء وتصنيفات حقيقية قابلة للإسقاط على slugs الخادم | عرض directory وunread badges وread-only؛ هذه ليست قنوات مُنشأة على Production |
| `channel_chat` | `CommunityChannelMessagesPage` | رسالتان اصطناعيتان + readback | واجهة conversation لقناة عامة لا Private DM |

المصفوفة المتوقعة: لكل مشهد نسختان لغة (ar/en)، وثيمان (light/dark)، وحجما نص (1/2) = **8 صور**؛ 5 مشاهد جديدة ×8=40 لقطة إضافية؛ المتوقّع Community **184** + Coach **11** = **195** لقطة. **هذا تقدير اختبار، ليس نتيجة CI؛ لا يُعتمد العدد حتى نجاح CI وإثبات artifact على SHA النهائي.**

## 4) مقارنة BIL المرجعية: فجوات لم تُغلق

- Coach: بُنية الأدوات والجدول والبطاقات تختلف عن اللوحة اليمنى المعتمدة؛ يجب محاذاة حالات conversation/confirm/readback قبل أي pixel score.
- Community feed: fixture لا يبرهن معرض أربع صور ولا جميع خيارات engagement.
- Notifications: fixture يثبت حدثًا، ولا يغطي كامل مصفوفة AI token rewards والـreceipts.
- Composer: أضيفت لقطات محرر Flutter الحقيقية بعد اختيار 3 صور BIL محلية عبر واجهة picker القابلة للحقن؛ تظهر 3 صور وخانة الإضافة الرابعة، وتُختبر حالات 200% text scale وRTL. **هذه ليست تجربة Gallery/Upload فعلية على جهاز**، وحد 1200 Unicode يبقى كما اعتمده المالك.
- Profile: تخطيط الرأس والبطاقات والأزرار مختلف؛ ما زال يحتاج مقارنة viewport/crop موحدة.
- Drafts: fixture يستخدم أربع صور BIL محلية حقيقية؛ أُضيف precacheImage قبل الالتقاط لأن اللقطة السابقة أظهرت مساحة بيضاء رغم وجود Image.memory في شجرة العناصر. لا يعني هذا نسخ صور المستخدم أو إثبات pixel-match.
- Feed: جرى ضبط `_CommunityPostMediaTile` ليملأ كامل خلية الـgallery بدل ترك فراغات ذات عرض كبير بين الصور الأربع.
- Composer: جرى إصلاح Overflow فعلي بمقدار 2dp عند 200% text scale في بطاقة `Add photos` عبر احتساب ارتفاع الأيقونة والفراغات والـpadding، دون تعطيل اختبارات الوصول.
- Circles/Moderation/Channels: زيادة تغطية screenshots لا تعني RLS/receipt/real-user validation.
- Reviewer: Android 32 المرفوض لم يتغير؛ إعادة تقديم build ليست ضمن صلاحية هذا الفرع.

## 5) Contract-compatible visual fixes after full regression

- Restored the approved Composer body at 150dp, photo rail at 100dp and Publish at 68dp, without reintroducing 200% font overflow.
- Restored Profile cover 80/248 and self quick-action minimum height 88.5dp.
- Restored 48dp minimum hit target for the Community compose action shortcuts, preserving touch accessibility.
- Injected repositories never revive previous-owner Feed content after queued A→B→A; the policy notice remains visible; production repository rebinding remains enabled.
- All original regression assertions remain unchanged.

## 6) بوابات الإغلاق

1. نجاح CI `flutter-checks` و `isolated-sql-contracts` و **كل** `portable-regression (0–3)` و `flutter-visual-capture` على SHA واحد؛ لا يُسمح بتخفيف assertions أو استبعاد الاختبارات.
2. مقارنة screenshots Native actuals بالمراجع الصحيحة بحالة ولغة وثيم وviewport مطابقين مع توثيق الاختلافات، لا الاكتفاء بنجاح capture.
3. إثبات flow: Coach commit/readback/correction/undo، Community Circle/Channel/Drafts/Moderation على مستخدم مصرح في بيئة غير Production.
4. اختبار متجر/جهاز فعلي يتطلب تفويضًا منفصلًا للبناء والتقديم. لا تُعلن موافقة Google Play أو تحديث versionCode32 نتيجة نجاح QA المحلي.

روابط المصدر: [CI 37786719854](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37786719854) و[CI 37790542565](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37790542565) و[Issue #8](https://github.com/bilhealth-admin/Body-Intelligence/issues/8).
