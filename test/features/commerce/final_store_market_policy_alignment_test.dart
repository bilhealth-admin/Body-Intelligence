import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> _quotedCodes(String source) => RegExp(
  r"'([A-Z]{2})'",
).allMatches(source).map((match) => match.group(1)!).toSet();

void main() {
  const migrationPath =
      'supabase/migrations/20260830180011_canonical_store_market_pricing_policy.sql';
  const pricingPath =
      'tool/apple_store_connect/canonical_store_pricing_2026-08-29.json';

  test(
    'canonical migration exactly matches the approved sale-market split',
    () {
      final migration = File(migrationPath).readAsStringSync();
      final unnestBlocks = RegExp(
        r'from unnest\(array\[(.*?)\]::text\[\]\) code',
        dotAll: true,
      ).allMatches(migration).toList(growable: false);
      expect(unnestBlocks, hasLength(2));

      final premiumCodes = _quotedCodes(unnestBlocks[0].group(1)!);
      final aiCodes = _quotedCodes(unnestBlocks[1].group(1)!);
      expect(premiumCodes, equals({'EG', 'IN', 'PK', 'TR'}));
      expect(aiCodes, hasLength(168));
      expect(aiCodes, contains('NG'));
      expect(aiCodes, isNot(contains('IN')));
      expect(premiumCodes.intersection(aiCodes), isEmpty);

      final pricing =
          jsonDecode(File(pricingPath).readAsStringSync())
              as Map<String, dynamic>;
      final marketPolicy = pricing['marketPolicy']! as Map<String, dynamic>;
      final expectedPremium =
          (marketPolicy['premiumOnlyIso2']! as List<dynamic>)
              .cast<String>()
              .toSet();

      expect(expectedPremium, premiumCodes);
      expect(marketPolicy['premiumAiCoachMarketCount'], aiCodes.length);
      expect(expectedPremium.length + aiCodes.length, 172);
    },
  );

  test('canonical pricing replaces research history without rewriting it', () {
    final pricing =
        jsonDecode(File(pricingPath).readAsStringSync())
            as Map<String, dynamic>;
    final display = pricing['displayPolicy']! as Map<String, dynamic>;
    final products = pricing['products']! as Map<String, dynamic>;
    final history = pricing['history']! as Map<String, dynamic>;

    expect(pricing['status'], 'canonical');
    expect(pricing['pricingAuthority'], 'device_store_localized_metadata');
    expect(
      display['annualSavingsBadgePolicy'],
      'rounded_percent_from_annual_vs_monthly_times_12',
    );
    expect(
      display['annualReferencePricePolicy'],
      'monthly_store_price_times_12',
    );
    expect(display['pricesMustBeStoreDerived'], isTrue);
    expect(display['hardcodedFlutterPricesAllowed'], isFalse);
    expect(
      (products['bil_premium'] as Map<String, dynamic>)['businessTargetUsd'],
      '2.50',
    );
    expect(
      (products['bil_premium']
          as Map<String, dynamic>)['appleReferencePriceUsd'],
      '2.49',
    );
    expect(
      (products['bil_premium_annual']
          as Map<String, dynamic>)['appleReferencePriceUsd'],
      '21.00',
    );
    expect(
      (products['bil_premium_ai_coach']
          as Map<String, dynamic>)['appleReferencePriceUsd'],
      '5.99',
    );
    expect(
      (products['bil_premium_ai_coach_annual']
          as Map<String, dynamic>)['appleReferencePriceUsd'],
      '49.99',
    );
    expect(history['historicalFilesRemainImmutable'], isTrue);
    expect(
      history['supersedesForActivePricing'],
      contains(
        'artifacts/pricing/BIL_FINAL_GLOBAL_STORE_PRICING_2026-08-28.json',
      ),
    );
  });

  test('unknown and held markets fail closed instead of becoming Premium', () {
    final migration = File(migrationPath).readAsStringSync();
    expect(migration, contains('sale_enabled = true'));
    expect(migration, contains("return coalesce(v_plan, 'not_for_sale')"));
    expect(migration, contains("return 'not_for_sale'"));
    expect(migration, isNot(contains("coalesce(v_plan, 'premium')")));

    for (final held in ['BY', 'CN', 'RU', 'CU', 'IR', 'KP', 'SD', 'SY']) {
      final enabledTwoLetterBlocks = RegExp(
        r'from unnest\(array\[(.*?)\]::text\[\]\) code',
        dotAll: true,
      ).allMatches(migration).map((match) => match.group(1)!).join();
      expect(_quotedCodes(enabledTwoLetterBlocks), isNot(contains(held)));
    }
  });

  test('all five immutable product IDs retain store authority', () {
    final catalog = File(
      'lib/features/commerce/domain/store_catalog_configuration.dart',
    ).readAsStringSync();
    final backend = File(
      'supabase/functions/verify-store-purchase/store_backend.ts',
    ).readAsStringSync();
    final pricing = File(pricingPath).readAsStringSync();

    for (final id in [
      'bil_premium',
      'bil_premium_annual',
      'bil_premium_ai_coach',
      'bil_premium_ai_coach_annual',
      'bil_ai_boost',
    ]) {
      expect(catalog, contains("'$id'"));
      expect(pricing, contains('"$id"'));
    }
    expect(
      backend,
      matches(RegExp(r'''productId\s*!==\s*["']bil_ai_boost["']''')),
    );
    expect(catalog, contains('Prices, trials, availability'));
    expect(catalog, contains('always read from the active store'));
  });
}
