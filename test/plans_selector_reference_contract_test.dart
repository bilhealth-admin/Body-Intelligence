import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plan selector uses canonical tiers and device-store prices', () {
    final source = [
      'lib/features/commerce/presentation/bil_store_plans_page.dart',
      'lib/features/commerce/presentation/bil_dynamic_store_offers.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(source, contains('BilDynamicStoreOffers('));
    expect(source, contains('StoreCatalogConfiguration.storefrontProductIds'));
    expect(source, contains('VerifiedStoreCatalogAdapter'));
    expect(source, contains('selectedOffer.localizedPrice'));
    expect(source, isNot(contains("const Text('BIL Plus')")));
    expect(source, isNot(contains("const Text('BIL Pro')")));
  });
}
