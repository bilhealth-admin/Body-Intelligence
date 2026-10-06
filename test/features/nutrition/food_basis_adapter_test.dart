import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/nutrition/adapters/unified_food_adapter.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_quality_engine.dart';
import 'package:body_intelligence_log/features/nutrition/services/nutrition_calculation_engine.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'food_basis_fixtures.dart';

void main() {
  const adapter = UnifiedFoodAdapter();

  void expectUnavailable(UnifiedFood food) {
    expect(
      {
        for (final nutrient in FoodNutrient.values)
          nutrient: food.knownValue(nutrient),
      },
      {for (final nutrient in FoodNutrient.values) nutrient: null},
    );
    expect(food.verified, isFalse);
  }

  test('zero modern evidence is unknown for all thirteen nutrients', () {
    final row = basisFood(snapshot: basisSnapshot(values: const {}));
    expect(row.nutrientEvidenceMask, 0);
    expectUnavailable(adapter.adapt(row));
  });

  test('modern known zero and unknown are distinct for iron and vitamin C', () {
    final row = basisFood(
      snapshot: basisSnapshot(
        values: const {FoodNutrient.iron: 0, FoodNutrient.protein: 0},
      ),
    );
    final actual = adapter.adapt(row);
    expect(actual.knownValue(FoodNutrient.iron), 0);
    expect(actual.knownValue(FoodNutrient.protein), 0);
    expect(actual.knownValue(FoodNutrient.vitaminC), isNull);
    expect(actual.knownValue(FoodNutrient.calories), isNull);
  });

  test('all thirteen values scale from the immutable gram basis', () {
    final actual = adapter.adapt(basisFood());
    expect(actual.serving.grams, 40);
    final portion = const NutritionCalculationEngine().calculate(
      food: actual,
      grams: 120,
    );
    for (final nutrient in FoodNutrient.values) {
      expect(actual.knownValue(nutrient), basisNutrients[nutrient]);
      expect(portion.knownValue(nutrient), basisNutrients[nutrient]! * 3);
    }
  });

  for (final nutrient in FoodNutrient.values) {
    test(
      'a conflicting ${nutrient.name} column invalidates the whole modern row',
      () {
        final row = replaceBasisNutrient(
          basisFood(),
          nutrient,
          basisNutrients[nutrient]! + 1,
        );
        expectUnavailable(adapter.adapt(row));
      },
    );
  }

  for (final raw in <String>[
    '',
    '{invalid',
    '[]',
    jsonEncode({
      'schema': 'bil.food.basis.v2',
      'food': basisSnapshot().toJson(),
    }),
    jsonEncode({
      'schema': 'bil.food.basis.v1',
      'food': basisSnapshot().toJson(),
      'trusted': true,
    }),
  ]) {
    test('an invalid envelope never falls back to legacy macros: $raw', () {
      final actual = adapter.adapt(basisFood(raw: raw));
      expectUnavailable(actual);
      expect(actual.serving.grams, 0);
      expect(
        () => const NutritionCalculationEngine().calculate(
          food: actual,
          grams: 40,
        ),
        throwsStateError,
      );
    });
  }

  test('a missing modern envelope cannot acquire legacy known-zero values', () {
    final row = basisFood(
      snapshot: basisSnapshot(values: const {}),
    ).copyWith(foodEvidenceJson: const Value(null));
    expectUnavailable(adapter.adapt(row));
  });

  for (final example in <(String, Food Function(Food))>[
    ('serving amount', (row) => row.copyWith(servingSize: 100.0)),
    ('serving unit', (row) => row.copyWith(servingUnit: 'ml')),
    ('evidence mask', (row) => row.copyWith(nutrientEvidenceMask: 0)),
    ('source', (row) => row.copyWith(source: 'foundation')),
    ('verification', (row) => row.copyWith(verified: true)),
    ('food name', (row) => row.copyWith(name: 'Different food')),
  ]) {
    test('conflicting ${example.$1} is unavailable', () {
      expectUnavailable(adapter.adapt(example.$2(basisFood())));
    });
  }

  test('estimated source never grants verification or a foundation label', () {
    final row = basisFood(
      snapshot: basisSnapshot(kind: CoachFoodSourceKind.estimated),
    );
    final actual = adapter.adapt(row);
    expect(actual.source, FoodDataSource.unknown);
    expect(actual.sourceLabel, 'coach_food_v2:estimated');
    expect(actual.verified, isFalse);
    expect(actual.knownValue(FoodNutrient.calories), 123);
  });

  test(
    'legacy shared values keep their original required-core and mask semantics',
    () {
      final row = basisFood(
        snapshot: basisSnapshot(values: const {FoodNutrient.fiber: 0}),
        includeEvidence: false,
      );
      final actual = adapter.adapt(row);
      expect(actual.source, FoodDataSource.foundation);
      for (final nutrient in [
        FoodNutrient.calories,
        FoodNutrient.protein,
        FoodNutrient.carbohydrates,
        FoodNutrient.fat,
        FoodNutrient.fiber,
      ]) {
        expect(actual.knownValue(nutrient), 0);
      }
      expect(actual.knownValue(FoodNutrient.sodium), isNull);
    },
  );

  test('legacy default-zero iron and vitamin C carry no evidence', () {
    final actual = adapter.adapt(
      basisFood(
        snapshot: basisSnapshot(values: const {}),
        includeEvidence: false,
      ),
    );
    expect(actual.knownValue(FoodNutrient.iron), isNull);
    expect(actual.knownValue(FoodNutrient.vitaminC), isNull);
  });

  test('legacy positive iron and vitamin C remain usable evidence', () {
    final actual = adapter.adapt(basisFood(includeEvidence: false));
    expect(actual.knownValue(FoodNutrient.iron), 2);
    expect(actual.knownValue(FoodNutrient.vitaminC), 8);
  });

  for (final unit in ['ml', 'liter', 'cup', 'serving', 'piece', 'unknown']) {
    test(
      'legacy $unit without a gram basis cannot become grams by assumption',
      () {
        final row = basisFood(
          includeEvidence: false,
        ).copyWith(servingSize: 100, servingUnit: unit);
        final actual = adapter.adapt(row);
        expect(actual.serving.amount, 100);
        expect(actual.serving.unit, unit);
        expect(actual.serving.grams, 0);
        expect(
          FoodQualityEngine.assess(actual).issues,
          contains(FoodQualityIssue.missingServingBasis),
        );
        expect(
          () => const NutritionCalculationEngine().calculate(
            food: actual,
            grams: 100,
          ),
          throwsStateError,
        );
      },
    );
  }

  for (final measure in <(String, double, double)>[
    ('g', 40, 40),
    ('gram', 40, 40),
    ('grams', 40, 40),
    ('kg', .5, 500),
    ('mg', 500, .5),
    ('oz', 2, 56.69904625),
    ('lb', 1, 453.59237),
  ]) {
    test('legacy mass conversion remains exact for ${measure.$1}', () {
      final row = basisFood(
        includeEvidence: false,
      ).copyWith(servingSize: measure.$2, servingUnit: measure.$1);
      expect(adapter.adapt(row).serving.grams, measure.$3);
    });
  }
}
