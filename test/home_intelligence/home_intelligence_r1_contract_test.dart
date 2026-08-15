@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('R1 restores responsive summary and online barcode method', () {
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();
    final authority = File(
      'lib/features/nutrition/services/food_runtime_search_authority.dart',
    ).readAsStringSync();

    expect(
      summary,
      contains('final phone = MediaQuery.sizeOf(context).width < 600;'),
    );
    expect(summary, contains('phone ? 1.20 : layout.metricChildAspectRatio'));

    expect(
      authority,
      contains('Future<FoodRuntimeBarcodeResult> _resolveOnlineBarcode('),
    );
    expect(authority, contains('_networkBarcodeResolver.resolve(barcode)'));
    expect(authority, contains('this._networkBarcodeResolver ='));
  });
}
