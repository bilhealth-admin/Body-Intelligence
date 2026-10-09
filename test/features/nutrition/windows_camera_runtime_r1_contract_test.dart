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
    // The painter is a Dart part of the same scanner library, so verify the
    // animation and the actual beam painting across both source files.
    final painter = File(
      'lib/features/nutrition/presentation/'
      'food_barcode_scanner_painter.dart',
    ).readAsStringSync();
    expect(scanner, contains("part 'food_barcode_scanner_painter.dart'"));
    expect(painter, contains("part of 'food_barcode_scanner_page.dart'"));
    expect(painter, contains('final beamY ='));
    expect(painter, contains('MaskFilter.blur'));
  });
}
