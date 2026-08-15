import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nutrition sources contain no binary visible copy or mojibake', () {
    final roots = [
      Directory('lib/features/nutrition'),
      Directory('lib/features/nutrition_plans'),
    ];
    final files = roots
        .expand((root) => root.listSync(recursive: true))
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final binaryVisibleCopy = RegExp(
      r'''(?:arabic|_arabic|languageCode\s*==\s*['"]ar['"])\s*\?\s*['"]''',
    );
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(binaryVisibleCopy.hasMatch(source), isFalse, reason: file.path);
      for (final marker in const ['Ã', 'Â', 'Ø', 'Ù', '�']) {
        expect(source.contains(marker), isFalse, reason: file.path);
      }
    }
  });

  test('identity and meal-image copy explicitly cover five locales', () {
    for (final path in const [
      'lib/features/nutrition/presentation/product_identity_copy.dart',
      'lib/features/nutrition/services/meal_image_gateway_contract.dart',
    ]) {
      final source = File(path).readAsStringSync();
      for (final locale in const ['en', 'ar', 'fr', 'es', 'tr']) {
        expect(source, contains("'$locale':"), reason: '$path: $locale');
      }
    }
  });
}
