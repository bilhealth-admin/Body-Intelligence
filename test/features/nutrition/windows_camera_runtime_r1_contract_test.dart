import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows scanner has an executable camera path', () {
    final scanner = File(
      'lib/features/nutrition/presentation/'
      'food_barcode_scanner_page.dart',
    ).readAsStringSync();

    expect(scanner, contains('SimpleBarcodeScanner.scanBarcode'));
    expect(scanner, contains('Future<void> _startWindows()'));
    expect(scanner, contains('TargetPlatform.windows'));
    expect(scanner, contains('onScan: _startWindows'));
    expect(scanner, contains('mobileScannerSupported && !isWindows'));
    expect(scanner, contains('Open laptop camera'));
  });
}
