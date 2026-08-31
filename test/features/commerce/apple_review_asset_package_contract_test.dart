import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple review package uses truthful storefront metadata', () {
    final package =
        jsonDecode(
              File(
                'store_assets/review/apple/v1.0/manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final products = <String, Map<String, dynamic>>{
      for (final raw in package['files'] as List<dynamic>)
        (raw as Map<String, dynamic>)['productId'] as String: raw,
    };

    expect(products.keys.toSet(), {
      'bil_premium',
      'bil_premium_annual',
      'bil_premium_ai_coach',
      'bil_premium_ai_coach_annual',
      'bil_ai_boost',
    });

    for (final product in products.values) {
      expect(product['width'], 1170);
      expect(product['height'], 2532);
      expect(product['colorChannels'], 3);
      expect(product['hasAlpha'], isFalse);
      final image = File(product['file'] as String);
      expect(image.existsSync(), isTrue);
      expect(
        sha256.convert(image.readAsBytesSync()).toString(),
        product['sha256'],
      );
    }

    final premiumMonthly = products['bil_premium']!;
    expect(premiumMonthly['selectedTerm'], 'MONTHLY');
    expect(premiumMonthly['localizedPrice'], 'EGP 129.99');
    expect(premiumMonthly['currencyCode'], 'EGP');
    expect(premiumMonthly['storeCountryCode'], 'EGY');
    expect(premiumMonthly['currencyCode'], isNot('USD'));

    final premiumAnnual = products['bil_premium_annual']!;
    expect(premiumAnnual['selectedTerm'], 'ANNUAL');
    expect(premiumAnnual['localizedPrice'], 'EGP 999.99');
    expect(premiumAnnual['currencyCode'], 'EGP');
    expect(premiumAnnual['storeCountryCode'], 'EGY');
    expect(premiumAnnual['derivedSavingsBadge'], 'Save 36%');
    expect(
      premiumAnnual['badgeCalculation'],
      'round((129.99 * 12 - 999.99) / (129.99 * 12) * 100)',
    );

    final coachMonthly = products['bil_premium_ai_coach']!;
    expect(coachMonthly['selectedTerm'], 'MONTHLY');
    expect(coachMonthly['localizedPrice'], r'$5.99');
    expect(coachMonthly['currencyCode'], 'USD');
    expect(coachMonthly['storeCountryCode'], 'USA');

    final coachAnnual = products['bil_premium_ai_coach_annual']!;
    expect(coachAnnual['selectedTerm'], 'ANNUAL');
    expect(coachAnnual['localizedPrice'], r'$49.99');
    expect(coachAnnual['derivedSavingsBadge'], 'Save 30%');
    expect(
      coachAnnual['badgeCalculation'],
      'round((5.99 * 12 - 49.99) / (5.99 * 12) * 100)',
    );

    final boost = products['bil_ai_boost']!;
    expect(boost['selectedTerm'], 'ONE_TIME_CONSUMABLE');
    expect(boost['localizedPrice'], r'$2.49');
    expect(boost['discountBadge'], isNull);
  });

  test('release manifest does not describe unavailable Premium USD offers', () {
    final release =
        jsonDecode(
              File(
                'docs/release/BIL_APP_STORE_REVIEW_ASSET_MANIFEST_2026-08-29.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final package =
        release['localReviewScreenshotPackage'] as Map<String, dynamic>;
    final products = <String, Map<String, dynamic>>{
      for (final raw in package['products'] as List<dynamic>)
        (raw as Map<String, dynamic>)['productId'] as String: raw,
    };

    for (final productId in ['bil_premium', 'bil_premium_annual']) {
      final product = products[productId]!;
      expect(product['currencyCode'], 'EGP');
      expect(product['storeCountryCode'], 'EGY');
      expect(product.containsKey('localizedUsdPrice'), isFalse);
    }
  });
}
