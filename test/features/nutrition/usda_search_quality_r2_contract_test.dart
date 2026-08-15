import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/dart_library_source.dart';

void main() {
  test('R2 preserves nutrients, Arabic display, and semantic dedupe', () {
    final repository = File(
      'lib/features/nutrition/repositories/usda_core_catalog_repository.dart',
    ).readAsStringSync();
    final materializer = File(
      'lib/data/repositories/food_repository.dart',
    ).readAsStringSync();
    final authority = File(
      'lib/features/nutrition/services/food_runtime_search_authority.dart',
    ).readAsStringSync();
    final foodPage = readDartLibrarySource(
      'lib/features/nutrition/food_page.dart',
    );

    expect(repository, contains('arabicName: _assistance.arabicNameFor'));
    expect(repository, contains('FoodNutrient.sodium'));
    expect(repository, contains('FoodNutrient.potassium'));
    expect(repository, contains('FoodNutrient.fiber'));
    expect(materializer, contains('storedCoreIsZero'));
    expect(materializer, contains('incomingHasCoreEvidence'));
    expect(authority, contains('byIdentity'));
    expect(
      foodPage,
      contains("final arabic = Localizations.localeOf(context)"),
    );
    expect(foodPage, contains('food.fiber.toStringAsFixed(1)'));
    expect(foodPage, contains('food.sodium.toStringAsFixed(0)'));
    expect(foodPage, contains('food.potassium.toStringAsFixed(0)'));
    expect(foodPage, contains("nutritionText(context, 'fiber'"));
    expect(foodPage, contains("nutritionText(context, 'sodium'"));
    expect(foodPage, contains("nutritionText(context, 'potassium'"));
  });
}
