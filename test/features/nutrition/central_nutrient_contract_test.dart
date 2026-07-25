import 'package:body_intelligence_log/features/nutrition/domain/central_nutrient_contract.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('net carbohydrates are carbohydrates minus fiber', () {
    final result = netCarbohydrates(
      totalCarbohydrates: const AvailableNutrient.known(30),
      fiber: const AvailableNutrient.known(8),
    );
    expect(result.isAvailable, isTrue);
    expect(result.value, 22);
  });

  test('missing fiber keeps net carbohydrates unavailable', () {
    final result = netCarbohydrates(
      totalCarbohydrates: const AvailableNutrient.known(30),
      fiber: const AvailableNutrient.unknown(),
    );
    expect(result.isAvailable, isFalse);
    expect(result.value, isNull);
  });

  test('phosphorus is unavailable unless its evidence bit is explicit', () {
    expect(
      NutrientEvidenceMask.contains(0, TrackedNutrient.phosphorus),
      isFalse,
    );
    final knownZero = NutrientEvidenceMask.fromValues(phosphorus: 0);
    expect(
      NutrientEvidenceMask.contains(
        knownZero,
        TrackedNutrient.phosphorus,
      ),
      isTrue,
    );
  });
}
