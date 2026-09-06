import 'package:body_intelligence_log/features/nutrition/presentation/food_barcode_scanner_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('barcode gallery picker contains native picker failures', () async {
    final failure = PlatformException(code: 'picker_unavailable');

    final result = await guardBarcodeGalleryPick<String>(
      () async => throw failure,
    );

    expect(result.value, isNull);
    expect(result.error, same(failure));
  });

  test('barcode gallery picker preserves user cancellation', () async {
    final result = await guardBarcodeGalleryPick<String>(() async => null);

    expect(result.value, isNull);
    expect(result.error, isNull);
  });
}
