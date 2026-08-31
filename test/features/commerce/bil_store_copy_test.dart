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

  test('Premium brand names stay exact across all 25 locales', () {
    const exactRuntimeBrands = <String>[
      'Premium',
      'BIL Premium',
      'Premium AI Coach',
      'Premium+',
      'BIL Premium+',
    ];

    for (final locale in RuntimeCopy.supported) {
      expect(
        BilStoreCopy.text(locale, 'premium'),
        'Premium',
        reason: '$locale must preserve the Premium brand name',
      );
      expect(
        BilStoreCopy.text(locale, 'ai_benefit_1'),
        contains('BIL Premium'),
        reason: '$locale must preserve BIL Premium in inherited benefits',
      );
      for (final brand in exactRuntimeBrands) {
        expect(
          RuntimeCopy.resolve(brand, locale) ?? brand,
          brand,
          reason: '$locale must preserve the exact $brand brand name',
        );
      }
    }
  });

  test(
    'AI tier states the complete inherited paid tier without repetition',
    () {
      for (final catalog in BilStoreCopy.catalogs.values) {
        final localizedPremium = catalog['premium']!.toLowerCase();
        expect(
          catalog['ai_benefit_1']!.toLowerCase(),
          contains(localizedPremium),
        );
        expect(
          catalog['premium_ai_coach']!.toLowerCase(),
          isNot(contains(localizedPremium)),
        );
        expect(catalog['premium_ai_detail'], contains('AI'));
      }
      expect(
        BilStoreCopy.catalogs['en']!['premium_ai_detail'],
        'BIL Free + every paid feature + AI Coach',
      );
    },
  );

  test('paywall copy permits one visible Premium label per tier route', () {
    for (final catalog in BilStoreCopy.catalogs.values) {
      final premiumTierVisibleCopy = <String>[
        catalog['premium']!,
        catalog['premium_store_title']!,
        catalog['premium_detail']!,
        for (final entry in catalog.entries)
          if (entry.key.startsWith('premium_benefit_')) entry.value,
      ].join(' ');
      final aiTierVisibleCopy = <String>[
        catalog['premium_ai_coach']!,
        catalog['premium_store_title']!,
        catalog['premium_ai_detail']!,
        catalog['ai_benefit_1']!,
        catalog['ai_benefit_2']!,
        catalog['ai_benefit_3']!,
        catalog['ai_benefit_4']!,
        for (final entry in catalog.entries)
          if (entry.key.startsWith('premium_benefit_') &&
              entry.key != 'premium_benefit_1')
            entry.value,
      ].join(' ');

      int premiumMentions(String value) {
        final haystack = value.toLowerCase();
        final needle = catalog['premium']!.toLowerCase();
        var count = 0;
        var start = 0;
        while (true) {
          final match = haystack.indexOf(needle, start);
          if (match < 0) return count;
          count += 1;
          start = match + needle.length;
        }
      }

      expect(premiumMentions(premiumTierVisibleCopy), 1);
      expect(premiumMentions(aiTierVisibleCopy), 1);
    }
  });

  test('one-Premium route contract holds across all 25 locales', () {
    final benefitKeys = BilStoreCopy.catalogs['en']!.keys
        .where((key) => key.startsWith('premium_benefit_'))
        .toList(growable: false);

    for (final locale in RuntimeCopy.supported) {
      final premiumToken = BilStoreCopy.text(locale, 'premium').toLowerCase();
      final premiumRoute = <String>[
        BilStoreCopy.text(locale, 'premium'),
        BilStoreCopy.text(locale, 'premium_store_title'),
        BilStoreCopy.text(locale, 'premium_detail'),
        for (final key in benefitKeys) BilStoreCopy.text(locale, key),
      ].join(' ').toLowerCase();
      final aiRoute = <String>[
        BilStoreCopy.text(locale, 'premium_ai_coach'),
        BilStoreCopy.text(locale, 'premium_store_title'),
        BilStoreCopy.text(locale, 'premium_ai_detail'),
        for (var index = 1; index <= 4; index++)
          BilStoreCopy.text(locale, 'ai_benefit_$index'),
        for (final key in benefitKeys)
          if (key != 'premium_benefit_1') BilStoreCopy.text(locale, key),
      ].join(' ').toLowerCase();

      int mentions(String value, String token) {
        var count = 0;
        var start = 0;
        while (true) {
          final match = value.indexOf(token, start);
          if (match < 0) return count;
          count += 1;
          start = match + token.length;
        }
      }

      final premiumTokens = {premiumToken, 'premium'};
      for (final token in premiumTokens) {
        expect(
          mentions(premiumRoute, token),
          lessThanOrEqualTo(1),
          reason: '$locale Premium route; token=$token; copy=$premiumRoute',
        );
        expect(
          mentions(aiRoute, token),
          lessThanOrEqualTo(1),
          reason: '$locale AI Coach route; token=$token; copy=$aiRoute',
        );
      }
      expect(
        premiumTokens
            .map((token) => mentions(premiumRoute, token))
            .reduce((left, right) => left > right ? left : right),
        1,
        reason: '$locale Premium route has no tier label',
      );
      expect(
        premiumTokens
            .map((token) => mentions(aiRoute, token))
            .reduce((left, right) => left > right ? left : right),
        1,
        reason: '$locale AI Coach route has no inheritance label',
      );
    }
  });

  test('tier summaries stay concise on compact paywall cards', () {
    for (final catalog in BilStoreCopy.catalogs.values) {
      expect(catalog['premium_detail']!.length, lessThanOrEqualTo(40));
      expect(catalog['premium_ai_detail']!.length, lessThanOrEqualTo(55));
    }
  });

  test('compact tier summaries remain localized across all 25 locales', () {
    for (final locale in RuntimeCopy.supported.where(
      (locale) => !BilStoreCopy.catalogs.containsKey(
        locale.toLowerCase().split(RegExp('[-_]')).first,
      ),
    )) {
      expect(
        BilStoreCopy.text(locale, 'premium_store_title'),
        isNot(BilStoreCopy.text('en', 'premium_store_title')),
        reason: '$locale:premium_store_title fell back to English',
      );
      expect(
        BilStoreCopy.text(locale, 'premium_detail'),
        isNot(BilStoreCopy.text('en', 'premium_detail')),
        reason: '$locale:premium_detail fell back to English',
      );
      expect(
        BilStoreCopy.text(locale, 'premium_ai_detail'),
        isNot(BilStoreCopy.text('en', 'premium_ai_detail')),
        reason: '$locale:premium_ai_detail fell back to English',
      );
    }
  });

  test('trial renewal disclosure is localized and store-price driven', () {
    for (final locale in RuntimeCopy.supported) {
      for (final key in const <String>[
        'trial_renews_monthly',
        'trial_renews_annually',
      ]) {
        final localized = BilStoreCopy.text(locale, key);
        expect(localized, contains('{price}'), reason: '$locale:$key');
        expect(
          localized.replaceAll('{price}', ''),
          isNot(matches(RegExp(r'[$€£]\s*\d|\d+[.,]\d{2}\s*(USD|EUR|GBP)'))),
          reason: '$locale:$key contains a hardcoded price',
        );
        if (locale != 'en') {
          expect(
            localized,
            isNot(BilStoreCopy.text('en', key)),
            reason: '$locale:$key fell back to English',
          );
        }
      }
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
      'premium_benefit_fitness_devices',
      'premium_benefit_community',
      'premium_benefit_5',
      'premium_benefit_trial',
      'ai_benefit_trial',
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
