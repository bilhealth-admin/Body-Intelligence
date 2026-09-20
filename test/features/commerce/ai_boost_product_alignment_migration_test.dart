import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Boost migration restores the canonical StoreKit product constraint', () {
    final migration = File(
      'supabase/migrations/20260914101500_align_ai_boost_product_id_with_storekit.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains(
        'drop constraint if exists bil_ai_boost_purchases_product_id_check',
      ),
    );
    expect(
      migration,
      contains("check (product_id = 'bil_ai_boost')"),
    );
    expect(
      migration,
      isNot(contains("check (product_id = 'bil_ai_boost_499')")),
    );
  });
}
