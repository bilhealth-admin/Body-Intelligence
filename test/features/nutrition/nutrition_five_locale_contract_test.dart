import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nutrition presentation has a five-locale copy contract', () {
    final files = <String>[
      'lib/features/nutrition/food_page.dart',
      'lib/features/nutrition/presentation/food_catalog_overview.dart',
      'lib/features/nutrition/presentation/food_catalog_tile.dart',
      'lib/features/nutrition/presentation/food_barcode_scanner_page.dart',
      'lib/features/nutrition/presentation/catalog_packs_page.dart',
      'lib/features/nutrition/services/meal_voice_input_service.dart',
      'lib/features/nutrition_plans/presentation/nutrition_pathways_page.dart',
    ];
    final source = files
        .map((path) => File(path).readAsStringSync())
        .join('\n');
    final copy = File(
      'lib/features/nutrition/presentation/nutrition_copy.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('arabic ?')));
    expect(source, isNot(contains('_arabic ?')));
    expect(source, isNot(contains('ar ?')));
    for (final locale in const ['fr', 'es', 'tr']) {
      expect(copy, contains("'$locale': {"));
    }
    expect(source, contains('nutritionText'));
  });
}
