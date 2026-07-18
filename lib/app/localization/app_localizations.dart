import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = <Locale>[Locale('ar'), Locale('en')];

  static const Map<String, String> _ar = {
    'app_title': 'BIL – Body Intelligence Log',
    'welcome_back': 'مرحبًا بك من جديد',
    'dashboard': 'لوحة القيادة',
    'daily_log': 'السجل اليومي',
    'nutrition': 'التغذية',
    'history': 'السجل',
    'analytics': 'التحليلات',
    'settings': 'الإعدادات',
    'profile': 'الملف الشخصي',
    'weight': 'الوزن',
    'calories': 'السعرات',
    'protein': 'البروتين',
    'water': 'الماء',
    'save': 'حفظ',
    'onboarding_title': 'مرحبًا بك في BIL',
    'onboarding_body': 'يُحوِّل BIL بياناتك إلى رؤى عملية ومحددة.',
    'start': 'ابدأ',
    'next': 'التالي',
    'language': 'اللغة',
    'appearance': 'المظهر',
    'light': 'فاتح',
    'dark': 'داكن',
    'system': 'النظام',
    'english': 'الإنجليزية',
    'arabic': 'العربية',
    'profile_complete': 'اكتمال الملف الشخصي',
    'add_weight': 'إضافة وزن',
    'weight_history': 'سجل الوزن',
    'food_search': 'بحث عن الأطعمة',
    'custom_food': 'طعام مخصص',
    'daily_insights': 'الرؤى اليومية',
    'empty_state': 'لا توجد بيانات بعد. ابدأ بإضافة وزنك أو وجبتك الأولى.',
  };

  static const Map<String, String> _en = {
    'app_title': 'BIL – Body Intelligence Log',
    'welcome_back': 'Welcome back',
    'dashboard': 'Dashboard',
    'daily_log': 'Daily Log',
    'nutrition': 'Nutrition',
    'history': 'History',
    'analytics': 'Analytics',
    'settings': 'Settings',
    'profile': 'Profile',
    'weight': 'Weight',
    'calories': 'Calories',
    'protein': 'Protein',
    'water': 'Water',
    'save': 'Save',
    'onboarding_title': 'Welcome to BIL',
    'onboarding_body':
        'BIL turns your data into practical, explainable insight.',
    'start': 'Start',
    'next': 'Next',
    'language': 'Language',
    'appearance': 'Appearance',
    'light': 'Light',
    'dark': 'Dark',
    'system': 'System',
    'english': 'English',
    'arabic': 'Arabic',
    'profile_complete': 'Profile complete',
    'add_weight': 'Add weight',
    'weight_history': 'Weight history',
    'food_search': 'Food search',
    'custom_food': 'Custom food',
    'daily_insights': 'Daily insights',
    'empty_state': 'No data yet. Start by adding your first weight or meal.',
  };

  String get(String key) {
    final value = locale.languageCode == 'ar' ? _ar[key] : _en[key];
    return value ?? key;
  }

  static const Map<String, String> _arabicText = {
    'BIL is preparing your local data': 'يُجهّز BIL بياناتك المحلية',
    'Could not open your local data': 'تعذر فتح بياناتك المحلية',
    'Your data was not reset or uploaded. Try opening it again.':
        'لم يتم حذف بياناتك أو رفعها. حاول فتحها مرة أخرى.',
    'Try again': 'حاول مرة أخرى',
    'Enter a quantity from 0.1 to 100000.': 'أدخل كمية من 0.1 إلى 100000.',
    'Enter a water amount from 1 to 5000 ml.':
        'أدخل كمية ماء من 1 إلى 5000 مل.',
    'Could not load the food catalog.': 'تعذر تحميل دليل الأطعمة.',
    'Remove water entry': 'إزالة سجل الماء',
    'Remove meal item': 'إزالة عنصر الوجبة',
    'Remove meal item?': 'إزالة عنصر الوجبة؟',
    'Remove': 'إزالة',
    'from this meal?': 'من هذه الوجبة؟',
    'Verified': 'موثّق',
    'Unverified': 'غير موثّق',
    'Edit custom food': 'تعديل الطعام المخصص',
    'Delete custom food?': 'حذف الطعام المخصص؟',
    'Existing meal history keeps its nutrition snapshot. This food will no longer appear in search.':
        'سيحتفظ سجل الوجبات الحالي بلقطة التغذية، ولن يظهر هذا الطعام في البحث بعد الآن.',
    'Weight trend': 'اتجاه الوزن',
    'Loading your latest body data': 'جارٍ تحميل أحدث بيانات جسمك',
    'Your latest body data could not be loaded.':
        'تعذر تحميل أحدث بيانات جسمك.',
    'Measurement date': 'تاريخ القياس',
    'Measurement conditions': 'ظروف القياس',
    'morning': 'صباحًا',
    'afterBathroom': 'بعد استخدام الحمام',
    'beforeFoodDrink': 'قبل الطعام أو الشراب',
    'differentConditions': 'ظروف مختلفة',
    'A weight entry already exists for this date.':
        'يوجد قياس وزن بالفعل لهذا التاريخ.',
    'Recorded weight trend over time': 'اتجاه الوزن المسجل عبر الزمن',
    'Seven-day change': 'تغير سبعة أيام',
    'Smoothed weekly direction': 'الاتجاه الأسبوعي الممهّد',
    'At least four entries needed': 'نحتاج أربعة قياسات على الأقل',
    'week': 'أسبوع',
    'Scale trends include water, glycogen, digestive content, and measurement variation; they do not prove fat or muscle change.':
        'تشمل اتجاهات الميزان الماء والجليكوجين ومحتوى الجهاز الهضمي واختلاف ظروف القياس؛ ولا تثبت تغير الدهون أو العضلات.',
    'Settings': 'الإعدادات',
    'Language': 'اللغة',
    'Appearance': 'المظهر',
    'System': 'النظام',
    'Light': 'فاتح',
    'Dark': 'داكن',
    'Units': 'الوحدات',
    'Metric (kg, cm)': 'متري (كجم، سم)',
    'Imperial (lb, in)': 'إمبراطوري (رطل، بوصة)',
    'Profile and goals': 'الملف الشخصي والأهداف',
    'Analytics': 'التحليلات',
    'Privacy': 'الخصوصية',
    'Health disclaimer': 'إخلاء المسؤولية الصحية',
    'Export local data': 'تصدير البيانات المحلية',
    'App version': 'إصدار التطبيق',
    'Cloud sync': 'المزامنة السحابية',
    'Reset local data': 'إعادة ضبط البيانات المحلية',
    'Daily Log': 'السجل اليومي',
    'Add water': 'إضافة ماء',
    'Custom water amount': 'كمية ماء مخصصة',
    'Amount in milliliters': 'الكمية بالملليلتر',
    'Water progress': 'تقدم شرب الماء',
    'remaining': 'متبقٍ',
    'Hydration target reached': 'تم الوصول إلى هدف شرب الماء',
    'Custom amount': 'كمية مخصصة',
    'Did you weigh yourself today?': 'هل قست وزنك اليوم؟',
    'A comparable daily check-in improves trend confidence. Normal fluctuations are expected, and skipping is always allowed.':
        'يحسن القياس اليومي في ظروف متقاربة ثقة الاتجاه. التقلبات الطبيعية متوقعة، ويمكنك التخطي دائمًا.',
    "Today's weight": 'وزن اليوم',
    'Skip today': 'تخطي اليوم',
    'Save check-in': 'حفظ القياس',
    'Analysis reliability': 'موثوقية التحليل',
    'Insufficient data': 'بيانات غير كافية',
    'Emerging confidence': 'ثقة قيد التكوين',
    'Useful confidence': 'ثقة مفيدة',
    'Strong confidence': 'ثقة قوية',
    'Loading Today dashboard': 'جارٍ تحميل لوحة اليوم',
    'Today is up to date.': 'بيانات اليوم محدثة.',
    'Some local Today data could not be refreshed.':
        'تعذر تحديث بعض بيانات اليوم المحلية.',
    'consumed': 'مستهلك',
    'target': 'هدف',
    'above target reference': 'أعلى من الهدف المرجعي',
    'Meal type': 'نوع الوجبة',
    'Breakfast': 'الإفطار',
    'Lunch': 'الغداء',
    'Dinner': 'العشاء',
    'Snack': 'وجبة خفيفة',
    'Food': 'الطعام',
    'Save meal': 'حفظ الوجبة',
    'Save log': 'حفظ السجل',
    'Calculated nutrition': 'التغذية المحسوبة',
    'Weight history': 'سجل الوزن',
    'Seven-day trend': 'اتجاه سبعة أيام',
    'No weight entries yet.': 'لا توجد قياسات وزن بعد.',
    'Food catalog': 'دليل الأطعمة',
    'Custom food': 'طعام مخصص',
    'Create custom food': 'إنشاء طعام مخصص',
    'Cancel': 'إلغاء',
    'Save': 'حفظ',
    'Delete': 'حذف',
    'Continue': 'متابعة',
    'Complete your profile': 'أكمل ملفك الشخصي',
    'Gender (male/female)': 'الجنس البيولوجي (ذكر/أنثى)',
    'I understand BIL provides general information, not medical advice.':
        'أفهم أن BIL يقدم معلومات عامة وليس نصيحة طبية.',
    'Goal': 'الهدف',
    'Lose weight': 'خسارة الوزن',
    'Maintain weight': 'الحفاظ على الوزن',
    'Gain weight': 'زيادة الوزن',
    'Age': 'العمر',
    'Height (cm)': 'الطول (سم)',
    'Current weight (kg)': 'الوزن الحالي (كجم)',
    'Goal weight (kg)': 'الوزن المستهدف (كجم)',
    'Activity level': 'مستوى النشاط',
    'Add Daily Entry': 'إضافة سجل يومي',
    'Today': 'اليوم',
    'Diary': 'اليوميات',
    'Discover': 'اكتشف',
    'Progress': 'التقدم',
    'Insights': 'الرؤى',
    'More': 'المزيد',
    'Daily check-in': 'القياس اليومي',
    'Life context': 'سياق الحياة',
    'Water total': 'إجمالي الماء',
    'Water data unavailable': 'بيانات الماء غير متاحة',
    'Meals unavailable': 'بيانات الوجبات غير متاحة',
    'No meals for this day.': 'لا توجد وجبات لهذا اليوم.',
    'Quantity': 'الكمية',
    'Update': 'تحديث',
    'Meal saved locally.': 'تم حفظ الوجبة محليًا.',
    'Fiber': 'الألياف',
    'Sodium': 'الصوديوم',
    'Potassium': 'البوتاسيوم',
    'Magnesium': 'المغنيسيوم',
    'Calcium': 'الكالسيوم',
    'Sugar': 'السكر',
    'Search foods': 'ابحث عن طعام',
    'One best action': 'أفضل إجراء واحد',
    'Data honesty': 'موثوقية البيانات',
    'What changed today?': 'ما الذي تغير اليوم؟',
    'Body Twin': 'توأم الجسم',
    'Weekly review': 'المراجعة الأسبوعية',
    'Share Studio': 'استوديو المشاركة',
    'Create a privacy-safe progress image. Weight stays hidden.':
        'أنشئ صورة تقدم تحمي خصوصيتك. يظل الوزن مخفيًا.',
    'Challenges': 'التحديات',
    'Behavior-first private challenges with evidence-based progress.':
        'تحديات خاصة تركّز على السلوك ويُحسب تقدمها من الأدلة.',
    'Targets and plan': 'الأهداف والخطة',
    'Complete your profile first.': 'أكمل ملفك الشخصي أولًا.',
    'Enter whole-number targets in every field.':
        'أدخل أهدافًا بأرقام صحيحة في جميع الحقول.',
    'Plan saved. Historical records were not changed.':
        'تم حفظ الخطة. لم تتغير السجلات التاريخية.',
    'We recommend…': 'نوصي بـ…',
    'BMR': 'معدل الأيض الأساسي',
    'TDEE': 'إجمالي الإنفاق اليومي',
    'kcal': 'سعرة',
    'plan': 'خطة',
    'lose': 'خسارة',
    'maintain': 'ثبات',
    'gain': 'زيادة',
    'Confidence starts formula-based. Consistent weight and complete meal records are required before observed estimates become useful.':
        'تبدأ الثقة اعتمادًا على المعادلة. نحتاج إلى قياسات وزن منتظمة وسجلات وجبات مكتملة قبل أن تصبح التقديرات المرصودة مفيدة.',
    'Calories (kcal)': 'السعرات (سعرة)',
    'Protein (g)': 'البروتين (غ)',
    'Carbohydrates (g)': 'الكربوهيدرات (غ)',
    'Fat (g)': 'الدهون (غ)',
    'Fiber (g)': 'الألياف (غ)',
    'Water (ml)': 'الماء (مل)',
    'Using recommendation': 'باستخدام التوصية',
    'versus recommendation. Changing this may alter adherence and scenario interpretations.':
        'مقارنة بالتوصية. قد يؤثر التغيير في الالتزام وتفسير السيناريوهات.',
    'Saving…': 'جارٍ الحفظ…',
    'Save plan': 'حفظ الخطة',
    'Reset to recommended': 'العودة إلى الموصى به',
    'BIL does not recommend faster change as inherently better. If you have medical needs, pregnancy, an eating-disorder history, or clinician-directed targets, consult a qualified professional.':
        'لا يعتبر BIL التغيير الأسرع أفضل بطبيعته. عند وجود احتياجات طبية أو حمل أو تاريخ اضطراب أكل أو أهداف يحددها مختص، استشر مختصًا مؤهلًا.',
    'Personal experiments': 'التجارب الشخصية',
    'New experiment': 'تجربة جديدة',
    'Experiments are structured personal observations, not medical proof. Change one variable when practical and record missing data and limitations.':
        'التجارب ملاحظات شخصية منظمة وليست إثباتًا طبيًا. غيّر عاملًا واحدًا عندما يكون ذلك عمليًا وسجّل البيانات الناقصة والقيود.',
    'No experiment yet. Start with a cautious, measurable question such as whether a consistent protein breakfast affects your reported satiety.':
        'لا توجد تجربة بعد. ابدأ بسؤال حذر وقابل للقياس، مثل تأثير إفطار ثابت غني بالبروتين في شعورك المسجل بالشبع.',
    'No result recorded': 'لم تُسجل نتيجة',
    'insufficient': 'غير كافية',
    'low': 'منخفضة',
    'moderate': 'متوسطة',
    'confidence': 'ثقة',
    'adherence': 'التزام',
    'Active': 'نشطة',
    'required': 'المطلوب',
    'not specified': 'غير محدد',
    'Delete experiment': 'حذف التجربة',
    'Design an observation': 'صمّم ملاحظة',
    'Hypothesis': 'الفرضية',
    'One changed variable': 'عامل واحد متغير',
    'Factors to keep consistent': 'العوامل المطلوب تثبيتها',
    'Required data': 'البيانات المطلوبة',
    'Duration (3–90 days)': 'المدة (3–90 يومًا)',
    'Start': 'ابدأ',
    'Record observation': 'سجّل الملاحظة',
    'What did you observe?': 'ماذا لاحظت؟',
    'Adherence (0–100%)': 'الالتزام (0–100٪)',
    'Missing data and limitations': 'البيانات الناقصة والقيود',
    'Insufficient evidence': 'أدلة غير كافية',
    'Low confidence': 'ثقة منخفضة',
    'Moderate confidence': 'ثقة متوسطة',
    'This result is a personal observation, not medical proof.':
        'هذه النتيجة ملاحظة شخصية وليست إثباتًا طبيًا.',
    'Save observation': 'حفظ الملاحظة',
    'Close': 'إغلاق',
    'Local data export copied to the clipboard.':
        'تم نسخ تصدير البيانات المحلية إلى الحافظة.',
    'Reset all local data?': 'هل تريد حذف كل البيانات المحلية؟',
    'This permanently removes your profile, goals, logs, meals, custom foods, and settings. Type RESET to continue.':
        'سيؤدي هذا إلى حذف ملفك وأهدافك وسجلاتك ووجباتك وأطعمتك المخصصة وإعداداتك نهائيًا. اكتب RESET للمتابعة.',
    'Reset': 'حذف البيانات',
    'High contrast': 'تباين مرتفع',
    'Increase separation between text, controls, and surfaces.':
        'زيادة التمييز بين النصوص وعناصر التحكم والأسطح.',
    'Reduce motion': 'تقليل الحركة',
    'Minimize nonessential interface animation.':
        'تقليل حركات الواجهة غير الضرورية.',
    'Compare recommendations, assumptions, and your overrides.':
        'قارن التوصيات والافتراضات وتعديلاتك.',
    'Decision Memory': 'ذاكرة القرارات',
    'Review, rate, disable, or delete remembered actions.':
        'راجع الإجراءات المتذكّرة وقيّمها أو عطّلها أو احذفها.',
    'Test a cautious hypothesis and record limitations.':
        'اختبر فرضية حذرة وسجّل القيود.',
    'Your data remains on this device.': 'تبقى بياناتك على هذا الجهاز.',
    'BIL stores profile, weight, meals, foods, water, and preferences locally in SQLite. No data is uploaded while cloud services are disabled.':
        'يحفظ BIL الملف الشخصي والوزن والوجبات والأطعمة والماء والتفضيلات محليًا في SQLite. لا تُرفع أي بيانات ما دامت الخدمات السحابية معطلة.',
    'BIL provides general tracking information and cautious hypotheses. It does not diagnose, treat, or replace advice from a qualified healthcare professional.':
        'يقدم BIL معلومات متابعة عامة وفرضيات حذرة. لا يشخّص أو يعالج ولا يحل محل نصيحة مختص صحي مؤهل.',
    'Copy a JSON export to the clipboard.': 'انسخ تصدير JSON إلى الحافظة.',
    'Connected capabilities': 'الخدمات المتصلة',
    'Account': 'الحساب',
    'Ask BIL': 'اسأل BIL',
    'Subscriptions and purchases': 'الاشتراكات والمشتريات',
    'Community': 'المجتمع',
    'Coach platform': 'منصة المختص',
    'Remote update channel': 'قناة التحديث البعيد',
    'Configuration found, but verified registration/session activation is not enabled in this build.':
        'تم العثور على إعدادات، لكن التسجيل والجلسات الموثقة غير مفعّلة في هذا الإصدار.',
    'Requires Supabase client configuration and the BIL server boundary.':
        'يتطلب إعداد عميل Supabase وحدود خادم BIL.',
    'Configuration found, but verified outbox/inbox activation is not enabled in this build.':
        'تم العثور على إعدادات، لكن مزامنة الصادر والوارد الموثقة غير مفعّلة في هذا الإصدار.',
    'Local Mode is active. No data is uploaded.':
        'الوضع المحلي نشط. لا تُرفع أي بيانات.',
    'Server endpoint found, but the consent and rate-limit adapter is not activated.':
        'تم العثور على عنوان الخادم، لكن طبقة الموافقة وتحديد المعدل غير مفعّلة.',
    'Requires a server-side AI proxy. Model secrets are never accepted by the client.':
        'يتطلب وسيط ذكاء اصطناعي على الخادم. لا يقبل التطبيق أسرار النموذج.',
    'Payment configuration exists, but verified receipt/webhook activation is pending.':
        'إعداد الدفع موجود، لكن تفعيل الإيصالات وإشعارات الخادم الموثقة ما زال معلقًا.',
    'Purchases are not configured. No payment details are collected.':
        'المشتريات غير معدّة. لا تُجمع أي بيانات دفع.',
    'Requires authenticated identities, consent, moderation, and enforced server-side access policies.':
        'يتطلب هويات موثقة وموافقة وإشرافًا وسياسات وصول مفروضة على الخادم.',
    'Remote signed update configuration is not configured; platform stores remain authoritative.':
        'إعداد التحديث البعيد الموقّع غير مهيأ؛ تظل متاجر المنصات هي المرجع.',
    'Add weight': 'إضافة وزن',
    'Edit weight': 'تعديل الوزن',
    'Delete weight?': 'هل تريد حذف الوزن؟',
    'from history?': 'من السجل؟',
    'Could not load weight history': 'تعذر تحميل سجل الوزن',
    'More data needed': 'نحتاج إلى مزيد من البيانات',
    'BIL account': 'حساب BIL',
    'Your data, on your terms': 'بياناتك بشروطك',
    'Cloud accounts are optional. Local Mode remains fully usable and keeps data on this device.':
        'الحساب السحابي اختياري. يظل الوضع المحلي كامل الاستخدام ويحفظ البيانات على هذا الجهاز.',
    'Email': 'البريد الإلكتروني',
    'Password': 'كلمة المرور',
    'Show password': 'إظهار كلمة المرور',
    'Hide password': 'إخفاء كلمة المرور',
    'Sign in': 'تسجيل الدخول',
    'Account sign-in remains disabled until the verified server auth boundary is initialized.':
        'يظل تسجيل الدخول معطلًا حتى تفعيل حدود المصادقة الموثقة على الخادم.',
    'Cloud accounts are not configured in this build. No credentials will be accepted or stored.':
        'الحسابات السحابية غير مهيأة في هذا الإصدار. لن تُقبل أو تُحفظ أي بيانات دخول.',
    'Continue in Local Mode': 'المتابعة في الوضع المحلي',
    'Manual barcode lookup': 'البحث اليدوي بالباركود',
    'Barcode digits': 'أرقام الباركود',
    'Camera scanning is unavailable until a verified scanner adapter and permissions are configured.':
        'المسح بالكاميرا غير متاح حتى إعداد محول مسح موثّق والأذونات اللازمة.',
    'Search': 'بحث',
    'Barcode not found locally': 'الباركود غير موجود محليًا',
    'BIL will not invent nutrition values. You can create a food from the product label and this barcode will be prefilled.':
        'لن يخترع BIL قيمًا غذائية. يمكنك إنشاء طعام من ملصق المنتج وسيُملأ هذا الباركود مسبقًا.',
    'Not now': 'ليس الآن',
    'English, Arabic, keyword, or barcode':
        'الاسم العربي أو الإنجليزي أو كلمة مفتاحية أو باركود',
    'Could not load foods': 'تعذر تحميل الأطعمة',
    'No matching foods. Create a custom food.':
        'لا توجد أطعمة مطابقة. أنشئ طعامًا مخصصًا.',
    'Source': 'المصدر',
    'Verified catalog record': 'سجل موثّق في الدليل',
    'Not independently verified': 'غير موثّق بصورة مستقلة',
    'Normalized serving': 'الحصة القياسية',
    'Updated locally': 'آخر تحديث محلي',
    'verified': 'موثّق',
    'unverified': 'غير موثّق',
    'starter': 'دليل البداية',
    'custom': 'مخصص',
    'user': 'أنشأه المستخدم',
    'Remove favorite': 'إزالة من المفضلة',
    'Add favorite': 'إضافة إلى المفضلة',
    'English name': 'الاسم الإنجليزي',
    'Arabic name': 'الاسم العربي',
    'Barcode': 'الباركود',
    'Serving size': 'حجم الحصة',
    'Serving unit': 'وحدة الحصة',
    'Carbohydrates': 'الكربوهيدرات',
    'Fat': 'الدهون',
    'Calories': 'السعرات',
    'Protein': 'البروتين',
    'Required': 'مطلوب',
    'Enter a non-negative number': 'أدخل رقمًا غير سالب',
    'Remember recommendation responses': 'تذكّر ردود التوصيات',
    'When off, BIL does not store new action responses or outcomes. Existing memories remain available for deletion.':
        'عند التعطيل، لا يحفظ BIL ردودًا أو نتائج جديدة. تظل الذكريات الحالية متاحة للحذف.',
    'No recommendation responses have been stored. BIL will never invent outcomes.':
        'لم تُحفظ ردود على التوصيات. لن يخترع BIL نتائج.',
    'accepted': 'مقبول',
    'done': 'تم',
    'notSuitable': 'غير مناسب',
    'dismissed': 'تم التجاهل',
    'Outcome': 'النتيجة',
    'Helpful?': 'هل كان مفيدًا؟',
    'of 5': 'من 5',
    'Helpfulness': 'درجة الفائدة',
    'Delete memory': 'حذف الذاكرة',
    'Edit': 'تعديل',
    'Quick Add': 'إضافة سريعة',
    'Unavailable until the server-side AI consent and rate-limit boundary is configured.':
        'غير متاح حتى إعداد حدود موافقة الذكاء الاصطناعي وتحديد المعدل على الخادم.',
  };

  String text(String english) =>
      locale.languageCode == 'ar' ? (_arabicText[english] ?? english) : english;
}

extension AppLocalizationContext on BuildContext {
  AppLocalizations get strings => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
