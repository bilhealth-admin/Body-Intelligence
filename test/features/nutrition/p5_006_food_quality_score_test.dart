import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_quality_score_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  UnifiedFood food({
    required String id,
    required Map<FoodNutrient, NutrientAmount> nutrients,
    bool verified = true,
  }) => UnifiedFood(
    id: id,
    name: id,
    category: 'test',
    serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
    nutrients: nutrients,
    source: FoodDataSource.foundation,
    sourceLabel: 'foundation',
    verified: verified,
    isCustom: false,
  );

  test('higher profile score is explainable and evidence-backed', () {
    final result = FoodQualityScoreEngine.score(
      food(
        id: 'lentils',
        nutrients: const <FoodNutrient, NutrientAmount>{
          FoodNutrient.calories: NutrientAmount.known(116),
          FoodNutrient.protein: NutrientAmount.known(9),
          FoodNutrient.carbohydrates: NutrientAmount.known(20),
          FoodNutrient.fat: NutrientAmount.known(0.4),
          FoodNutrient.fiber: NutrientAmount.known(8),
          FoodNutrient.sugar: NutrientAmount.known(1.8),
          FoodNutrient.sodium: NutrientAmount.known(2),
        },
      ),
    );

    expect(result.band, FoodProfileBand.higher);
    expect(result.profileScore, greaterThanOrEqualTo(70));
    expect(result.evidenceConfidence, 1);
    expect(result.reasons, contains(FoodQualityScoreReason.fiberDensity));
  });

  test('known zero remains evidence and is not treated as missing', () {
    final result = FoodQualityScoreEngine.score(
      food(
        id: 'zero-sodium',
        nutrients: const <FoodNutrient, NutrientAmount>{
          FoodNutrient.calories: NutrientAmount.known(100),
          FoodNutrient.protein: NutrientAmount.known(12),
          FoodNutrient.carbohydrates: NutrientAmount.known(8),
          FoodNutrient.fat: NutrientAmount.known(2),
          FoodNutrient.sodium: NutrientAmount.known(0),
          FoodNutrient.sugar: NutrientAmount.known(0),
        },
      ),
    );

    expect(result.hasSufficientEvidence, isTrue);
    expect(
      result.reasons,
      isNot(contains(FoodQualityScoreReason.highSodiumDensity)),
    );
  });

  test('missing core data yields limited evidence instead of false score', () {
    final result = FoodQualityScoreEngine.score(
      food(
        id: 'partial',
        verified: false,
        nutrients: const <FoodNutrient, NutrientAmount>{
          FoodNutrient.calories: NutrientAmount.known(100),
          FoodNutrient.protein: NutrientAmount.known(5),
        },
      ),
    );

    expect(result.band, FoodProfileBand.limitedEvidence);
    expect(result.profileScore, 50);
    expect(result.evidenceConfidence, lessThan(0.5));
    expect(
      result.reasons,
      contains(FoodQualityScoreReason.missingCoreNutrition),
    );
  });

  test('high sugar and sodium reduce score with explicit reasons', () {
    final result = FoodQualityScoreEngine.score(
      food(
        id: 'processed',
        nutrients: const <FoodNutrient, NutrientAmount>{
          FoodNutrient.calories: NutrientAmount.known(420),
          FoodNutrient.protein: NutrientAmount.known(3),
          FoodNutrient.carbohydrates: NutrientAmount.known(70),
          FoodNutrient.fat: NutrientAmount.known(15),
          FoodNutrient.sugar: NutrientAmount.known(30),
          FoodNutrient.sodium: NutrientAmount.known(700),
        },
      ),
    );

    expect(result.band, FoodProfileBand.lower);
    expect(result.reasons, contains(FoodQualityScoreReason.highSugarDensity));
    expect(result.reasons, contains(FoodQualityScoreReason.highSodiumDensity));
  });
}
