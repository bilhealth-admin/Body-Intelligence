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
    final client = File(
      'lib/features/nutrition/services/regional_barcode_network_resolver.dart',
    ).readAsStringSync();

    expect(sql, contains('bil_has_premium_barcode_access'));
    expect(sql, contains("'pro','premium','premium_ai_coach'"));
    expect(sql, contains('bil_barcode_shared_cache'));
    expect(edge, contains("return json({error:'premium_required'},403)"));
    expect(edge, contains('bil_get_cached_barcode'));
    expect(edge, contains('api.nal.usda.gov'));
    expect(edge, contains('food.gtinUpc'));
    expect(edge, contains('BIL_USDA_API_KEY'));
    expect(edge, contains("next_step:'capture_product_label'"));
    expect(client, contains("functions.invoke(\n        'barcode-lookup'"));
    expect(
      client,
      isNot(contains("String.fromEnvironment('BIL_USDA_API_KEY')")),
    );
  });
}
