import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/dart_library_source.dart';

void main() {
  test('R2 preserves nutrients, Arabic display, and semantic dedupe', () {
    final repository = File(
      'lib/features/nutrition/repositories/usda_core_catalog_repository.dart',
    ).readAsStringSync();
    final materializer = readDartLibrarySource(
      'lib/data/repositories/food_repository.dart',
    );
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
    expect(materializer, contains('incomingEvidenceMask'));
    expect(materializer, contains('hasNewEvidence'));
    expect(materializer, contains('incomingCalories ?? byUuid.calories'));
    expect(materializer, contains('incomingProtein ?? byUuid.protein'));
    expect(authority, contains('byIdentity'));
    expect(
      foodPage,
      contains("final arabic = Localizations.localeOf(context)"),
    );
    expect(foodPage, contains('value: food.fiber'));
    expect(foodPage, contains('value: food.sodium'));
    expect(foodPage, contains('value: food.potassium'));
    expect(foodPage, contains('_localizedNutrientNumber'));
    expect(foodPage, contains("FoodNutrient.fiber => 'Fiber'"));
    expect(foodPage, contains("FoodNutrient.sodium => 'Sodium'"));
    expect(foodPage, contains("FoodNutrient.potassium => 'Potassium'"));
  });
}
