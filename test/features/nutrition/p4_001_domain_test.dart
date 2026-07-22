import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_deduplication_engine.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_quality_engine.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_search_normalizer.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_unit_engine.dart';
import 'package:body_intelligence_log/features/nutrition/services/gram_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P4-001 unified nutrition domain', () {
    test('missing nutrient remains different from known zero', () {
      const missing = NutrientAmount.missing();
      const zero = NutrientAmount.known(0);

      expect(missing.isKnown, isFalse);
      expect(missing.nullableValue, isNull);
      expect(zero.isKnown, isTrue);
      expect(zero.nullableValue, 0);
    });

    test('gram engine scales known values and preserves missing evidence', () {
      final scaled = GramEngine.scaleNutrients(
        nutrients: const <FoodNutrient, NutrientAmount>{
          FoodNutrient.protein: NutrientAmount.known(20),
          FoodNutrient.sodium: NutrientAmount.missing(),
        },
        grams: 50,
        basisGrams: 100,
      );

      expect(scaled[FoodNutrient.protein]!.value, 10);
      expect(scaled[FoodNutrient.sodium]!.isKnown, isFalse);
    });

    test('unit engine round trips supported mass units', () {
      for (final unit in FoodMassUnit.values) {
        final grams = FoodUnitEngine.toGrams(2.5, unit);
        expect(FoodUnitEngine.fromGrams(grams, unit), closeTo(2.5, 1e-10));
      }
    });

    test('Arabic and Persian text normalize consistently', () {
      expect(FoodSearchNormalizer.normalize('صَدْر دَجَاج'), 'صدر دجاج');
      expect(FoodSearchNormalizer.normalize('إجاص'), 'اجاص');
      expect(FoodSearchNormalizer.normalize('١٢۳'), '123');
      expect(FoodSearchNormalizer.normalizeBarcode(' ٦٢٢-123 '), '622123');
    });

    test('quality assessment explains reduced confidence', () {
      final food = _food(
        source: FoodDataSource.unknown,
        verified: false,
        arabicName: null,
        nutrients: const <FoodNutrient, NutrientAmount>{
          FoodNutrient.calories: NutrientAmount.known(100),
          FoodNutrient.protein: NutrientAmount.known(10),
          FoodNutrient.carbohydrates: NutrientAmount.known(5),
          FoodNutrient.fat: NutrientAmount.known(4),
        },
      );

      final assessment = FoodQualityEngine.assess(food);
      expect(assessment.confidence, isNot(FoodConfidenceLevel.high));
      expect(assessment.issues, contains(FoodQualityIssue.unknownSource));
      expect(assessment.issues, contains(FoodQualityIssue.unverified));
    });

    test(
      'deduplication identifies barcode candidates but never auto-merges',
      () {
        final left = _food(id: 'left', barcode: '6221234567890');
        final right = _food(id: 'right', barcode: '٦٢٢١٢٣٤٥٦٧٨٩٠');

        final assessment = FoodDeduplicationEngine.compare(left, right);
        expect(assessment.kind, FoodDuplicateKind.highConfidence);
        expect(assessment.reasons, contains('same-barcode'));
        expect(assessment.shouldAutoMerge, isFalse);
      },
    );
  });
}

UnifiedFood _food({
  String id = 'food-1',
  String? barcode,
  String? arabicName = 'طعام',
  FoodDataSource source = FoodDataSource.foundation,
  bool verified = true,
  Map<FoodNutrient, NutrientAmount>? nutrients,
}) {
  return UnifiedFood(
    id: id,
    name: 'Food',
    arabicName: arabicName,
    category: 'Test',
    barcode: barcode,
    serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
    nutrients:
        nutrients ??
        const <FoodNutrient, NutrientAmount>{
          FoodNutrient.calories: NutrientAmount.known(100),
          FoodNutrient.protein: NutrientAmount.known(10),
          FoodNutrient.carbohydrates: NutrientAmount.known(5),
          FoodNutrient.fat: NutrientAmount.known(4),
        },
    source: source,
    sourceLabel: source.name,
    verified: verified,
    isCustom: false,
  );
}
