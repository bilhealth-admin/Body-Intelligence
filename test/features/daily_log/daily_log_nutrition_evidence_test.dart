import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_nutrition_evidence.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../nutrition/food_basis_fixtures.dart';
import 'daily_log_nutrition_fixtures.dart';

void main() {
  for (final nutrient in TrackedNutrient.values) {
    test('${nutrient.name} total requires every immutable item value', () {
      final known = modernDiaryItem();
      final missing = modernDiaryItem(
        id: 2,
        values: {
          ...basisNutrients,
          MealFoodEvidence.foodNutrient(nutrient): null,
        },
      );
      final expected = basisNutrients[MealFoodEvidence.foodNutrient(nutrient)]!;
      expect(
        DailyLogNutritionEvidence.forItems([
          known,
          modernDiaryItem(id: 3),
        ]).total(nutrient),
        expected * 2,
      );
      expect(
        DailyLogNutritionEvidence.forItems([known, missing]).total(nutrient),
        isNull,
      );
    });
  }

  test(
    'empty core display is explicitly zero but no evidence is fabricated',
    () {
      final empty = DailyLogNutritionEvidence.forMeals(const []);
      for (final nutrient in TrackedNutrient.values) {
        expect(empty.total(nutrient), isNull);
        expect(empty.total(nutrient, emptyAsZero: true), 0);
      }
      expect(empty.netCarbs, isNull);
      final unknown = DailyLogNutritionEvidence.forItems([
        modernDiaryItem(values: const {}),
      ]);
      for (final nutrient in TrackedNutrient.values) {
        expect(unknown.total(nutrient, emptyAsZero: true), isNull);
      }
    },
  );

  test(
    'each meal carries its own fixed-product owner to evidence validation',
    () {
      final a = modernDiaryItem(
        kind: CoachFoodSourceKind.userFixed,
        ownerKey: 'owner-a',
      );
      final b = modernDiaryItem(
        id: 2,
        kind: CoachFoodSourceKind.userFixed,
        ownerKey: 'owner-b',
      );
      expect(
        DailyLogNutritionEvidence.forMeals([
          diaryMeal([a], ownerKey: 'owner-a'),
          diaryMeal([b], ownerKey: 'owner-b'),
        ]).total(TrackedNutrient.calories),
        246,
      );
      expect(
        DailyLogNutritionEvidence.forMeals([
          diaryMeal([a], ownerKey: 'owner-b'),
          diaryMeal([b], ownerKey: 'owner-b'),
        ]).total(TrackedNutrient.calories),
        isNull,
      );
    },
  );

  test(
    'null or corrupt modern JSON never falls back to legacy column zeros',
    () {
      for (final json in [null, '{invalid']) {
        final item = modernDiaryItem(
          values: const {},
        ).copyWith(foodEvidenceJson: Value(json));
        final evidence = DailyLogNutritionEvidence.forItems([item]);
        for (final nutrient in TrackedNutrient.values) {
          expect(evidence.total(nutrient, emptyAsZero: true), isNull);
        }
      }
    },
  );

  test('calorie-only preserves 1905 without food nutrients or net carbs', () {
    final evidence = DailyLogNutritionEvidence.forItems([
      calorieOnlyDiaryItem(),
    ]);
    expect(evidence.total(TrackedNutrient.calories), 1905);
    for (final nutrient in TrackedNutrient.values) {
      if (nutrient != TrackedNutrient.calories) {
        expect(evidence.total(nutrient), isNull);
      }
    }
    expect(evidence.netCarbs, isNull);
  });

  test(
    'legacy core zeros remain known while optional columns need evidence',
    () {
      final legacy = modernDiaryItem(values: const {}).copyWith(
        foodSourceSnapshot: 'catalog',
        foodEvidenceJson: const Value(null),
      );
      final evidence = DailyLogNutritionEvidence.forItems([legacy]);
      for (final nutrient in [
        TrackedNutrient.calories,
        TrackedNutrient.carbohydrates,
        TrackedNutrient.protein,
        TrackedNutrient.fat,
      ]) {
        expect(evidence.total(nutrient), 0);
      }
      expect(evidence.total(TrackedNutrient.fiber), isNull);
      expect(evidence.netCarbs, isNull);
    },
  );

  test('a finite legacy item cannot produce an infinite displayed total', () {
    final large = modernDiaryItem(values: const {}).copyWith(
      foodSourceSnapshot: 'catalog',
      foodEvidenceJson: const Value(null),
      calories: 1e308,
    );
    expect(
      DailyLogNutritionEvidence.forItems([
        large,
        large.copyWith(id: 2),
      ]).total(TrackedNutrient.calories),
      isNull,
    );
  });
}
