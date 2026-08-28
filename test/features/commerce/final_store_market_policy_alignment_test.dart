import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> _quotedCodes(String source) => RegExp(
  r"'([A-Z]{2})'",
).allMatches(source).map((match) => match.group(1)!).toSet();

void main() {
  const migrationPath =
      'supabase/migrations/20260828220000_final_store_market_policy_alignment.sql';

  test('final migration exactly matches the approved sale-market matrix', () {
    final migration = File(migrationPath).readAsStringSync();
    final unnestBlocks = RegExp(
      r'from unnest\(array\[(.*?)\]::text\[\]\) code',
      dotAll: true,
    ).allMatches(migration).toList(growable: false);
    expect(unnestBlocks, hasLength(2));

    final premiumCodes = _quotedCodes(unnestBlocks[0].group(1)!);
    final aiCodes = _quotedCodes(unnestBlocks[1].group(1)!);
    expect(premiumCodes, equals({'EG', 'NG', 'PK', 'TR'}));
    expect(aiCodes, hasLength(168));
    expect(premiumCodes.intersection(aiCodes), isEmpty);

    final matrix =
        jsonDecode(
              File(
                'artifacts/pricing/BIL_FINAL_GLOBAL_STORE_PRICING_2026-08-28.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final rows = (matrix['rows'] as List<dynamic>).cast<Map<String, dynamic>>();
    final approvedAppleRows = rows.where(
      (row) =>
          row['apple_official_market'] == true &&
          row['apple_launch_status'] == 'مقترح للبيع',
    );
    final expectedPremium = approvedAppleRows
        .where((row) => row['plan'] == 'Premium فقط')
        .map((row) => row['iso']! as String)
        .toSet();
    final expectedAi = approvedAppleRows
        .where((row) => row['plan'] == 'Premium + AI Coach')
        .map((row) => row['iso']! as String)
        .toSet();

    expect(expectedPremium, premiumCodes);
    expect(expectedAi, aiCodes);
    expect(expectedPremium.length + expectedAi.length, 172);
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

  test('all five immutable product IDs retain the correct authority', () {
    final catalog = File(
      'lib/features/commerce/domain/store_catalog_configuration.dart',
    ).readAsStringSync();
    final backend = File(
      'supabase/functions/verify-store-purchase/store_backend.ts',
    ).readAsStringSync();
    final migration = File(migrationPath).readAsStringSync();

    for (final id in [
      'bil_premium',
      'bil_premium_annual',
      'bil_premium_ai_coach',
      'bil_premium_ai_coach_annual',
      'bil_ai_boost',
    ]) {
      expect(catalog, contains("'$id'"));
      expect(migration, contains("'$id'"));
    }
    expect(backend, contains("productId !== 'bil_ai_boost'"));
    expect(migration, contains('bil_store_registry_canonical_product_mapping'));
  });
}
