import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_profile.dart';
import 'package:body_intelligence_log/features/profile/profile_locale_copy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profileKeys = <String>[
    'Email address',
    'Goals',
    'Update weight, nutrition, and fitness goals',
    'Calories & macro plan',
    'Plan details & recommendations',
    'Dietary system',
    'Estimated time to goal',
    'Goal timeline',
    'Already at goal',
    'Maintenance plan · no countdown',
    'Current weight is within the goal range. This is an estimate, not a guarantee.',
    'Maintenance has no completion date. This is an estimate, not a guarantee.',
    'loss',
    'gain',
  ];
  const dietarySummaryKeys = <String>[
    'Omnivore',
    'Pescatarian',
    'Vegetarian',
    'Vegan',
    'Balanced',
    'High protein',
    'Low carb',
    'Keto',
    'Mediterranean',
    'Plant-forward',
  ];

  const visibleProfileKeys = <String>[
    'Profile',
    'Try again',
    'Complete your profile first.',
    'Personal details',
    'Display name',
    'Profile photo',
    'Add photo',
    'Change photo',
    'Email address',
    'Not added',
    'Body details',
    'Height',
    'Sex',
    'Female',
    'Male',
    'Date of birth',
    'Location & preferences',
    'Location',
    'Not set',
    'Postal code',
    'Time zone',
    'Units',
    'Metric · kg, cm, ml',
    'Imperial · lb, ft',
    'Dietary system',
    'Loading…',
    'Unavailable',
    'Goals',
    'Update weight, nutrition, and fitness goals',
    'Health goals',
    'Current weight',
    'Goal weight',
    'Activity level',
    'Sedentary',
    'Lightly active',
    'Moderately active',
    'Active',
    'Very active',
    'Calories & macro plan',
    'Plan details & recommendations',
    'Advanced body measurements',
    'Goal timeline',
    'Estimated time to goal',
    'Save health profile',
  ];
  const profileArabic = <String, String>{
    'Profile': 'الملف الشخصي',
    'Try again': 'إعادة المحاولة',
    'Complete your profile first.': 'أكمل إعداد ملفك أولًا.',
    'Personal details': 'البيانات الشخصية',
    'Display name': 'الاسم الظاهر',
    'Profile photo': 'الصورة الشخصية',
    'Add photo': 'إضافة صورة',
    'Change photo': 'تغيير الصورة',
    'Email address': 'البريد الإلكتروني',
    'Not added': 'غير مضاف',
    'Body details': 'بيانات الجسم',
    'Height': 'الطول',
    'Sex': 'الجنس',
    'Female': 'أنثى',
    'Male': 'ذكر',
    'Date of birth': 'تاريخ الميلاد',
    'Location & preferences': 'الموقع والتفضيلات',
    'Location': 'الموقع',
    'Not set': 'غير محدد',
    'Postal code': 'الرمز البريدي',
    'Time zone': 'المنطقة الزمنية',
    'Units': 'الوحدات',
    'Metric · kg, cm, ml': 'متري · كغ، سم، مل',
    'Imperial · lb, ft': 'إمبراطوري · رطل، قدم',
    'Dietary system': 'النظام الغذائي',
    'Loading…': 'جارٍ التحميل…',
    'Unavailable': 'غير متاح',
    'Goals': 'الأهداف',
    'Update weight, nutrition, and fitness goals':
        'حدّث أهداف الوزن والتغذية واللياقة',
    'Health goals': 'الأهداف الصحية',
    'Current weight': 'الوزن الحالي',
    'Goal weight': 'الوزن المستهدف',
    'Activity level': 'مستوى النشاط',
    'Sedentary': 'حركة محدودة',
    'Lightly active': 'نشاط خفيف',
    'Moderately active': 'نشاط متوسط',
    'Active': 'نشاط مرتفع',
    'Very active': 'نشاط مكثف',
    'Calories & macro plan': 'خطة السعرات والماكروز',
    'Plan details & recommendations': 'تفاصيل الخطة والتوصيات',
    'Advanced body measurements': 'قياسات الجسم المتقدمة',
    'Goal timeline': 'الجدول الزمني للهدف',
    'Estimated time to goal': 'الوقت التقديري للوصول إلى الهدف',
    'Save health profile': 'حفظ الملف الصحي',
  };

  test('Profile priority copy resolves exactly across all 25 locales', () {
    final locales = AppLocalizations.supportedLocales;
    final tags = locales.map(BilLocalePolicy.canonicalTag).toSet();

    expect(locales, hasLength(25));
    expect(tags, hasLength(25));
    expect(tags, ProfileRuntimeCopy.supported);
    expect(ProfileRuntimeCopy.balanced, isTrue);

    for (final locale in locales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final english in profileKeys) {
        final resolved = RuntimeCopy.resolve(english, tag);
        expect(resolved, isNotNull, reason: '$english must resolve for $tag');
        expect(
          resolved!.trim(),
          isNotEmpty,
          reason: '$english must not be blank for $tag',
        );
        if (tag != 'en') {
          expect(
            resolved,
            isNot(equals(english)),
            reason: '$english must not fall back to English for $tag',
          );
        }
        expect(
          AppLocalizations(locale).text(english),
          resolved,
          reason: 'runtime copy must preserve the exact locale tag $tag',
        );
        expect(
          profileLocaleTextForLocale(locale, english, 'ترجمة عربية'),
          resolved,
          reason: 'Profile must use the reviewed $tag copy for $english',
        );
      }
    }
  });

  test('Profile keeps Portuguese and Chinese regional variants distinct', () {
    expect(
      RuntimeCopy.resolve('Goals', 'pt-BR'),
      isNot(RuntimeCopy.resolve('Goals', 'pt-PT')),
    );
    expect(
      RuntimeCopy.resolve('Email address', 'zh-Hans'),
      isNot(RuntimeCopy.resolve('Email address', 'zh-Hant')),
    );
    expect(
      RuntimeCopy.resolve('Estimated time to goal', 'zh-Hans'),
      isNot(RuntimeCopy.resolve('Estimated time to goal', 'zh-Hant')),
    );
  });

  test('Dietary summary labels use reviewed copy in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final english in dietarySummaryKeys) {
        final expected = ProfileRuntimeCopy.values[english]![tag]!;
        expect(expected.trim(), isNotEmpty, reason: '$tag:$english');
        expect(RuntimeCopy.resolve(english, tag), expected);
        expect(AppLocalizations(locale).text(english), expected);
      }
    }
  });

  test('timeline and weekly-session dynamic copy cover exactly 25 locales', () {
    expect(profileTimelineCopyBalanced, isTrue);

    final englishRange = profileGoalTimelineRangeText(
      const Locale('en'),
      minimumWeeks: '3',
      maximumWeeks: '7',
      earliestDate: '1/9/2026',
      latestDate: '29/9/2026',
    );
    final englishSupporting = profileGoalTimelineSupportingText(
      const Locale('en'),
      direction: 'loss',
      lowRate: '0.25',
      highRate: '0.50',
      adherence: '80',
    );
    final englishWeekly = profileWeeklySessionsTextForLocale(
      const Locale('en'),
      4,
    );

    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      final direction = profileLocaleTextForLocale(locale, 'loss', 'نزول');
      final range = profileGoalTimelineRangeText(
        locale,
        minimumWeeks: '3',
        maximumWeeks: '7',
        earliestDate: '1/9/2026',
        latestDate: '29/9/2026',
      );
      final supporting = profileGoalTimelineSupportingText(
        locale,
        direction: direction,
        lowRate: '0.25',
        highRate: '0.50',
        adherence: '80',
      );
      final weekly = profileWeeklySessionsTextForLocale(locale, 4);

      expect(range, isNot(contains('{')), reason: '$tag range placeholders');
      expect(
        supporting,
        isNot(contains('{')),
        reason: '$tag supporting placeholders',
      );
      expect(weekly, isNot(contains('{')), reason: '$tag weekly placeholders');
      if (tag != 'en') {
        expect(
          range,
          isNot(englishRange),
          reason: '$tag range English fallback',
        );
        expect(
          supporting,
          isNot(englishSupporting),
          reason: '$tag supporting English fallback',
        );
        expect(
          weekly,
          isNot(englishWeekly),
          reason: '$tag weekly English fallback',
        );
      }
    }
  });

  test('every visible Profile label has native copy in all 25 locales', () {
    final missing = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      for (final english in visibleProfileKeys) {
        final resolved = profileLocaleTextForLocale(
          locale,
          english,
          profileArabic[english]!,
        );
        if (resolved.trim().isEmpty || (tag != 'en' && resolved == english)) {
          missing.add('$tag:$english');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
