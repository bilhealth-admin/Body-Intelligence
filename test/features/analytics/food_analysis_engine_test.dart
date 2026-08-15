import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/features/analytics/domain/food_analysis_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FoodAnalysisItemSnapshot item({
    required int foodId,
    required String name,
    required double protein,
    required bool proteinKnown,
    bool verified = true,
    String source = 'usda',
  }) {
    return FoodAnalysisItemSnapshot(
      foodId: foodId,
      foodName: name,
      nutrientEvidenceMask: proteinKnown
          ? NutrientEvidenceMask.bit(TrackedNutrient.protein)
          : 0,
      values: {TrackedNutrient.protein: protein},
      source: source,
      verified: verified,
    );
  }

  test('ranks and aggregates evidenced nutrient contributors', () {
    final result = FoodAnalysisEngine.analyze(
      nutrient: TrackedNutrient.protein,
      items: [
        item(foodId: 1, name: 'Lentils', protein: 9, proteinKnown: true),
        item(foodId: 2, name: 'Yogurt', protein: 12, proteinKnown: true),
        item(foodId: 1, name: 'Lentils', protein: 9, proteinKnown: true),
      ],
    );

    expect(result.coverage, FoodAnalysisCoverage.complete);
    expect(result.knownTotal, 30);
    expect(result.contributors.first.foodName, 'Lentils');
    expect(result.contributors.first.value, 18);
    expect(result.contributors.first.entryCount, 2);
    expect(result.contributors.first.share, closeTo(.6, .0001));
  });

  test('preserves missing evidence as unknown instead of a zero', () {
    final result = FoodAnalysisEngine.analyze(
      nutrient: TrackedNutrient.protein,
      items: [
        item(foodId: 1, name: 'Known', protein: 10, proteinKnown: true),
        item(foodId: 2, name: 'Unknown', protein: 500, proteinKnown: false),
      ],
    );

    expect(result.coverage, FoodAnalysisCoverage.partial);
    expect(result.knownTotal, 10);
    expect(result.unknownEntryCount, 1);
    expect(result.contributors, hasLength(1));
  });

  test('exposes verification provenance without excluding the record', () {
    final result = FoodAnalysisEngine.analyze(
      nutrient: TrackedNutrient.protein,
      items: [
        item(
          foodId: 1,
          name: 'Custom meal',
          protein: 20,
          proteinKnown: true,
          verified: false,
          source: 'custom',
        ),
      ],
    );

    expect(result.contributors.single.allSnapshotsVerified, isFalse);
    expect(result.contributors.single.sources, {'custom'});
  });

  test('invalid evidenced values are counted as unknown', () {
    final result = FoodAnalysisEngine.analyze(
      nutrient: TrackedNutrient.protein,
      items: [
        item(
          foodId: 1,
          name: 'Broken snapshot',
          protein: double.nan,
          proteinKnown: true,
        ),
      ],
    );

    expect(result.coverage, FoodAnalysisCoverage.none);
    expect(result.unknownEntryCount, 1);
    expect(result.contributors, isEmpty);
  });
}
