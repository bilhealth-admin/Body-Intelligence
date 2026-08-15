import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active food routes use the verified scanner and honest fallbacks', () {
    final foodPage = File(
      'lib/features/nutrition/food_page.dart',
    ).readAsStringSync();
    final dailyActions = File(
      'lib/features/daily_log/daily_log_page_actions.dart',
    ).readAsStringSync();

    for (final source in [foodPage, dailyActions]) {
      expect(source, contains('FoodBarcodeScannerPage'));
      expect(source, contains('lookupBarcodeJourney'));
    }
    expect(foodPage, isNot(contains('Camera scanning remains disabled')));
    expect(dailyActions, contains('BIL will not invent nutrition values'));
  });

  test('meal persistence keeps evidence snapshots and reversible actions', () {
    final repository = File(
      'lib/data/repositories/meal_repository.dart',
    ).readAsStringSync();
    final mealEntry = File(
      'lib/features/daily_log/daily_log_meal_entry.dart',
    ).readAsStringSync();
    final dailyActions = File(
      'lib/features/daily_log/daily_log_page_actions.dart',
    ).readAsStringSync();

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
    expect(mealEntry, contains('watchFavorites'));
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

    expect(voice, contains('SpeechToText'));
    expect(image, contains('BIL_MEAL_VISION_ENDPOINT'));
    expect(image, contains('configured'));
    expect(imageContract, contains('confidence'));
  });
}
