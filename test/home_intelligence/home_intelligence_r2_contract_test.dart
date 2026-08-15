@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hybrid barcode miss contract is deterministic and offline-safe', () {
    final integration = File(
      'test/features/nutrition/food_runtime_catalog_integration_test.dart',
    ).readAsStringSync();

    expect(integration, contains('_NotFoundNetworkResolver'));
    expect(integration, contains('networkBarcodeResolver:'));
    expect(
      integration,
      contains('local, catalog, and regional network miss reports notFound'),
    );
  });

  test('dashboard contracts match the approved readable tile design', () {
    final closure = File(
      'test/product_owner_review_closure_contract_test.dart',
    ).readAsStringSync();
    final visual = File(
      'test/product_owner_visual_review_r6_contract_test.dart',
    ).readAsStringSync();

    expect(closure, contains("contains('maxLines: 2')"));
    expect(closure, contains("contains('FittedBox(')"));
    expect(closure, contains("contains('BoxFit.scaleDown')"));
    expect(visual, contains('phone ? 190 : 172'));
    expect(visual, contains('phone ? 1.20'));
  });
}
