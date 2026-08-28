import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store/paywall copy is balanced across five production locales', () {
    expect(BilStoreCopy.catalogs.keys.toSet(), {'ar', 'en', 'fr', 'es', 'tr'});
    final keys = BilStoreCopy.catalogs['en']!.keys.toSet();
    for (final catalog in BilStoreCopy.catalogs.values) {
      expect(catalog.keys.toSet(), keys);
      expect(catalog.values.every((value) => value.trim().isNotEmpty), isTrue);
    }
  });

  test('catalog has final tier vocabulary and no monetary literals', () {
    for (final catalog in BilStoreCopy.catalogs.values) {
      expect(catalog['free'], isNotEmpty);
      expect(catalog['premium'], isNotEmpty);
      expect(catalog['premium_ai_coach'], isNotEmpty);
      expect(catalog['ai_boost'], contains('BIL AI'));
      expect(
        catalog.values.join(' '),
        isNot(matches(RegExp(r'[$€£]\s*\d|\d+[.,]\d{2}\s*(USD|EUR|GBP)'))),
      );
    }
  });

  test('explicit Premium benefits are localized in all 25 locales', () {
    const keys = <String>[
      'premium_store_title',
      'premium_benefit_1',
      'premium_benefit_2',
      'premium_benefit_barcode',
      'premium_benefit_dashboard',
      'premium_benefit_recipes',
      'premium_benefit_workouts',
      'premium_benefit_strength_plans',
      'premium_benefit_meal_plan',
      'premium_benefit_programs',
      'premium_benefit_reports',
      'premium_benefit_fasting',
      'premium_benefit_sleep',
      'premium_benefit_body',
      'premium_benefit_medical_devices',
      'premium_benefit_5',
      'premium_benefit_trial',
    ];

    expect(RuntimeCopy.supported, hasLength(25));
    for (final locale in RuntimeCopy.supported) {
      for (final key in keys) {
        final localized = BilStoreCopy.text(locale, key);
        final english = BilStoreCopy.text('en', key);
        expect(localized.trim(), isNotEmpty, reason: '$locale:$key is empty');
        if (locale != 'en') {
          expect(
            localized,
            isNot(english),
            reason: '$locale:$key fell back to English',
          );
        }
      }
    }
  });

  test('workout inventory is two explicit video benefits', () {
    final english = BilStoreCopy.catalogs['en']!;
    final arabic = BilStoreCopy.catalogs['ar']!;
    expect(english['premium_benefit_workouts'], '300+ home workout videos');
    expect(
      english['premium_benefit_strength_plans'],
      '100+ video-guided weight-training plans',
    );
    expect(
      arabic['premium_benefit_workouts'],
      'أكثر من 300 فيديو تمارين منزلية',
    );
    expect(
      arabic['premium_benefit_strength_plans'],
      'أكثر من 100 خطة تمارين رفع أثقال بالفيديو',
    );
  });

  test('AI Boost sells the BIL coach experience in all 25 locales', () {
    const keys = <String>[
      'boost_eyebrow',
      'boost_detail',
      'boost_benefit_1',
      'boost_benefit_2',
      'boost_benefit_3',
      'boost_benefit_4',
      'boost_benefit_5',
    ];
    for (final locale in RuntimeCopy.supported) {
      for (final key in keys) {
        final localized = BilStoreCopy.text(locale, key);
        expect(localized.trim(), isNotEmpty, reason: '$locale:$key is empty');
        if (locale != 'en') {
          expect(
            localized,
            isNot(BilStoreCopy.text('en', key)),
            reason: '$locale:$key fell back to English',
          );
        }
      }
    }
    final marketing = BilStoreCopy.catalogs.values
        .expand((catalog) => catalog.values)
        .join(' ')
        .toLowerCase();
    expect(marketing, isNot(contains('openai')));
    expect(marketing, isNot(contains('gemini')));
  });
}
