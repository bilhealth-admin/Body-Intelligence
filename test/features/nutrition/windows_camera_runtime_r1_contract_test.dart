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

  test('mobile scanner has a live bidirectional scan beam', () {
    final scanner = File(
      'lib/features/nutrition/presentation/'
      'food_barcode_scanner_page.dart',
    ).readAsStringSync();

    expect(scanner, contains('_scanBeamController.repeat(reverse: true)'));
    expect(scanner, contains("Key('barcode-animated-scan-beam')"));
    expect(scanner, contains('final beamY ='));
    expect(scanner, contains('MaskFilter.blur'));
  });
}
