import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Premium barcode lookup is gated and server credentialed', () {
    final sql = File(
      'supabase/migrations/202608110009_bil_premium_barcode_gateway.sql',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/barcode-lookup/index.ts',
    ).readAsStringSync();
    final universalCache = File(
      'supabase/migrations/'
      '20260821052813_barcode_universal_product_cache.sql',
    ).readAsStringSync();
    final client = File(
      'lib/features/nutrition/services/regional_barcode_network_resolver.dart',
    ).readAsStringSync();
    final access = File(
      'lib/features/commerce/presentation/premium_barcode_access.dart',
    ).readAsStringSync();
    final dailyLog = File(
      'lib/features/daily_log/daily_log_capture_actions.dart',
    ).readAsStringSync();
    final foodPage = File(
      'lib/features/nutrition/food_page.dart',
    ).readAsStringSync();

    expect(sql, contains('bil_has_premium_barcode_access'));
    expect(sql, contains("'pro','premium','premium_ai_coach'"));
    expect(sql, contains('bil_barcode_shared_cache'));
    expect(edge, contains("return json({error:'premium_required'},403)"));
    expect(edge, contains('bil_get_cached_barcode'));
    expect(edge, contains('api.nal.usda.gov'));
    expect(edge, contains('food.gtinUpc'));
    expect(edge, contains('BIL_USDA_API_KEY'));
    expect(edge, contains("product_type', 'all"));
    expect(edge, contains('world.openfoodfacts.org/api/v3/product/'));
    expect(edge, contains('productNameFields'));
    expect(edge, contains("p_source: 'open_facts'"));
    expect(universalCache, contains("'bil','usda','open_facts'"));
    expect(edge, contains("next_step:'capture_product_label'"));
    expect(client, contains("functions.invoke(\n        'barcode-lookup'"));
    expect(
      client,
      isNot(contains("String.fromEnvironment('BIL_USDA_API_KEY')")),
    );
    expect(access, contains('verifiedSubscriptionStateProvider.future'));
    expect(access, contains('CommercePlan.pro'));
    expect(access, contains('CommercePlan.premium'));
    expect(access, contains('CommercePlan.premiumAiCoach'));
    expect(access, contains("context.push('/plans?focus=subscription')"));
    expect(
      RegExp('requestPremiumBarcodeAccess').allMatches(dailyLog).length,
      2,
    );
    expect(
      RegExp('requestPremiumBarcodeAccess').allMatches(foodPage).length,
      2,
    );
  });
}
