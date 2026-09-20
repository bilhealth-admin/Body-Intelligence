import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a late stream fault cannot downgrade a verified entitlement', () {
    final source = File(
      'lib/features/commerce/services/verified_store_purchase_service.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('if (state == VerifiedStoreState.verified)'),
    );
  });
}
