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
