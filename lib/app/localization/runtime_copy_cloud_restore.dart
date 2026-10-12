import 'package:flutter/widgets.dart';

/// This extra, explicit choice does not enlarge the existing progress consent.
abstract final class CloudRestoreCopy {
  static String text(BuildContext context, String key) =>
      Localizations.localeOf(context).languageCode == 'ar'
      ? _arabic[key] ?? key
      : key;

  static const nutrition = 'Nutrition backup';
  static const goals = 'Goal backup';
  static const nutritionDetails =
      'Encrypted backup of your meals and portions, custom foods, recipes, and nutrient values and sources across your signed-in devices.';
  static const goalsDetails =
      'Encrypted backup of your custom calorie and nutrient goals, macro grams and percentages, locks, and daily schedules across your signed-in devices.';
  static const choice =
      'Optional and off until you choose it. Without consent, these records stay on this device. AI Coach conversations are not included.';
  static const disable =
      'Turning this off stops this backup. It does not delete local records or existing cloud copies.';
  static const unavailable =
      'This server cannot currently confirm support. These records stay on this device.';
  static const baseRequired = 'Enable Progress backup first.';
  static const signIn = 'Sign in to manage these choices.';
  static const checking = 'Checking backup support…';
  static const confirm = 'Enable encrypted backup';
  static const cancel = 'Keep on this device';
  static const failed = 'Could not confirm the change. Try again.';
  static const retry = 'Try again';

  static const _arabic = <String, String>{
    nutrition: 'نسخ التغذية احتياطيًا',
    goals: 'نسخ الأهداف احتياطيًا',
    nutritionDetails:
        'نسخة مشفّرة من وجباتك وحصصها وأطعمتك المخصصة ووصفاتك وقيم المغذيات ومصادرها، عبر أجهزتك المسجّل دخولها.',
    goalsDetails:
        'نسخة مشفّرة من أهداف السعرات والمغذيات المخصصة وغرامات الماكروز ونسبها وأقفالها والجداول اليومية، عبر أجهزتك المسجّل دخولها.',
    choice:
        'اختياري ومتوقف حتى تختاره. دون موافقة تبقى هذه السجلات على هذا الجهاز. لا يشمل محادثات AI Coach.',
    disable:
        'إيقافه يوقف هذا النسخ فقط، ولا يحذف سجلات الجهاز أو النسخ السحابية الموجودة.',
    unavailable:
        'تعذر تأكيد دعم الخادم حاليًا. تبقى هذه السجلات على هذا الجهاز.',
    baseRequired: 'فعّل «نسخ التقدّم احتياطيًا» أولًا.',
    signIn: 'سجّل الدخول لإدارة هذه الخيارات.',
    checking: 'جارٍ التحقق من دعم النسخ…',
    confirm: 'تفعيل النسخ المشفّر',
    cancel: 'الاحتفاظ بها على الجهاز',
    failed: 'تعذر تأكيد التغيير. حاول مجددًا.',
    retry: 'إعادة المحاولة',
  };
}
