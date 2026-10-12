# المراجع الرابع: الإدارة والمجتمع والسحابة

المراجع المستقل `/root/fourth_admin_cloud_independent_final`؛ قراءة فقط بتاريخ 13 أكتوبر، لنسخة e9bab65c الكاملة: 9727 ملفًا و5692 مدخلًا فوق 2c518ee4، تشمل العمل غير الملتزم. لم يكتب أو يشغّل اختبارًا أو يقرأ أو يعدّل Production أو حسابات حقيقية.

**القرار KEEP.** لا عيب متبقٍ مؤكد في الفروق. Premium/Tokens لا يمنحان دورًا. الحساب الإداري للمراجعة منفصل ومحدود، ببيانات معزولة معلنة وبالتنفيذ الحقيقي نفسه. البريد للتنبيه، وليس دفتر رصيد أو مصدر تفويض. publish-only معطل افتراضيًا ويتطلب سياسة المالك؛ لا حذف لإدارة عاملة أو إخفاء لها.

| التنفيذ | مراجعة الاختبار والنتيجة |
|---|---|
| قفل 4 RPC قديمة بـFOR SHARE على actor فعال قبل الأثر | Admin9: سباق baseline مثبت، وثبات signatures/ACL، وخمسة مسارات إصلاح، و15 API denial، وrollback صريح للإيصال والرصيد وoutbox؛ ليس اختبار فشل Push فعليًا |
| UUID وtombstone دائمة في SQLite فارغة، وتاريخ UTC دون invented zero | codec.apply داخل معاملة؛ دليل تاريخي مسموح دون إحياء الغذاء؛ أُعيدت 59 حالة ضمن 91 PASS بعد التنسيق |
| موافقتان منفصلتان لـnutrition/goals؛ الترقية لا تفعلهما | سحب الموافقة يمنع الاستمرار والتطبيق؛ حراسة A→B→A/JWT، وowner من الخادم |
| V2/CAS وإيصالات وعلاقات ومؤشر داخل المعاملة | SQL23 PASS؛ V1 MD5 قبل/بعد: b4a56dfd2c6b2d7d38ad2dbf92f5e03f؛ ليس اختبار binary32/35 |
| SQLiteA→تشفير AES/.NET→PostgreSQL محلي→SQLiteB | 1 PASS/cycle: 5 سجلات أصلية، وإعادة رفع 6، واختلاف IDs محلية/UUID، و19 مغذيًا، وtransFat مجهول وcholesterol صفر معلوم، وحصة جزئية، وgoals/CAS/deletion/retry |
| فصل المحتوى عن المكافأة | قرار على النسخة المستعرضة؛ المستفيد ونسخة السياسة واليوم الأصلي وحد الخادم وإيصال prevent duplicate؛ grant لاحقة من admin لا من content mod |
| FirstUse | done فقط عند غيابه؛ لا إعادة احتفال أو منحة أو اشتراك أو دور عند restore |

قارن المراجع 79 ملفًا مع أدلة Admin9/Cloud23/cycle؛ فرق codec وحده هو await/cascade/trailing comma، وهو محايد دلاليًا. القيمة non_whitespace_characters_identical=false؛ لا ندّعي تطابق الملفات حرفيًا. نتيجة 91 PASS بعده تطابق 79 ملفًا. hashes: adminlock a53858dfac88c3e5ba7dd311608b5a1832602c26d0fd25afcf17e12757cbf402؛ restoreV2 ccacdcef47bf2ff0e3d438826da6fc285015c4554e157834bdea052b5ee73966؛ moderationV2 3b226e77790319bd716f6963f4cc455529a6e3c5945ef1edc9794d8fdc2d4a85.

حدود الدليل: SQLite/PostgreSQL محلي بهويات تركيبية، وليس Supabase Auth/PostgREST كاملة أو هاتفًا أو Production. يلزم backup وفحص ACL/RLS والتوافق ثم نشر مأذون، وحساب فعلي وجهاز، واعتماد سياسة احتفاظ دفتر التدقيق وpublish-only قبل التفعيل. يعلن العميل الجديد عدم الإتاحة عند غياب العقد؛ العقود الحالية لا تتغير بالتوثيق.

قرأ المراجع بتاريخ 13 أكتوبر [Apple1.2/1.6/2.1/2.3.1](https://developer.apple.com/app-store/review/guidelines/)، و[GoogleAppAccess](https://support.google.com/googleplay/android-developer/answer/15748846)، و[UGC](https://support.google.com/googleplay/android-developer/answer/9876937)، و[SupabaseRLS](https://supabase.com/docs/guides/database/postgres/row-level-security). لا يوجد نص يرفض لوحة إدارة داخلية تلقائيًا؛ القرار استنتاج هندسي قائم على الأمان والإفصاح، وليس ضمان قبول.
