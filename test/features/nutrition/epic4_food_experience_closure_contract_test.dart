import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active food routes use the verified scanner and honest fallbacks', () {
    final foodPage = File(
      'lib/features/nutrition/food_page.dart',
    ).readAsStringSync();
    final dailyActions =
        [
              'daily_log_page_actions.dart',
              'daily_log_mutation_actions.dart',
              'daily_log_capture_actions.dart',
            ]
            .map(
              (name) => File('lib/features/daily_log/$name').readAsStringSync(),
            )
            .join('\n');

    for (final source in [foodPage, dailyActions]) {
      expect(source, contains('FoodBarcodeScannerPage'));
      expect(source, contains('lookupBarcodeJourney'));
    }
    expect(foodPage, isNot(contains('Camera scanning remains disabled')));
    expect(
      dailyActions,
      contains('MealNutritionResolution.verifiedFoodRecord'),
    );
    expect(dailyActions, contains('exact != null && exact.verified'));
    expect(dailyActions, contains("visionCopy.text('no_match')"));
  });

  test('meal persistence keeps evidence snapshots and reversible actions', () {
    final repository =
        [
              'meal_repository.dart',
              'meal_repository_queries.dart',
              'meal_repository_copying.dart',
            ]
            .map(
              (name) => File('lib/data/repositories/$name').readAsStringSync(),
            )
            .join('\n');
    final mealEntry = File(
      'lib/features/daily_log/daily_log_meal_entry.dart',
    ).readAsStringSync();
    final dailyActions =
        [
              'daily_log_page_actions.dart',
              'daily_log_mutation_actions.dart',
              'daily_log_capture_actions.dart',
            ]
            .map(
              (name) => File('lib/features/daily_log/$name').readAsStringSync(),
            )
            .join('\n');

    for (final snapshotField in [
      'nutrientEvidenceMask',
      'foodSourceSnapshot',
      'foodVerifiedSnapshot',
      'servingSizeSnapshot',
      'servingUnitSnapshot',
    ]) {
      expect(repository, contains(snapshotField));
    }
    expect(repository, contains('duplicateMealItem'));
    expect(repository, contains('repeatMeal'));
    expect(repository, contains("syncStatus: const Value('pendingDelete')"));
    expect(mealEntry, contains('isFavorite(selectedFood!.id)'));
    expect(mealEntry, contains('setFavorite(selectedFood!.id, !favorite)'));
    expect(mealEntry, contains('repeatMeal'));
    expect(dailyActions, contains('recordRecent'));
  });

  test('optional capture routes stay real and explicitly configured', () {
    final voice = File(
      'lib/features/nutrition/services/meal_voice_input_service.dart',
    ).readAsStringSync();
    final image = File(
      'lib/features/nutrition/services/meal_image_analysis_service.dart',
    ).readAsStringSync();
    final imageContract = File(
      'lib/features/nutrition/services/meal_image_gateway_contract.dart',
    ).readAsStringSync();
    final environment = File(
      'lib/app/environment/app_environment.dart',
    ).readAsStringSync();

    expect(voice, contains('SpeechToText'));
    expect(image, contains('AppEnvironment.mealVisionEndpoint'));
    expect(environment, contains('BIL_MEAL_VISION_ENDPOINT'));
    expect(image, contains('configured'));
    expect(imageContract, contains('confidence'));
  });
}
