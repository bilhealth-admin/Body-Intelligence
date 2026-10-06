import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/domain/exercise_calorie_policy.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../daily_log/daily_log_nutrition_fixtures.dart';
import '../nutrition/food_basis_fixtures.dart';

const _contextKeys = <String>[
  'caloriesKcal',
  'proteinG',
  'carbsG',
  'fatG',
  'sodiumMg',
];

MealWithItems _meal(
  List<MealItem> items, {
  Map<int, Food> foods = const {},
  String? ownerKey = 'owner-a',
}) => diaryMeal(items, foods: foods, ownerKey: ownerKey);

Map<String, Object?> _totals(CoachNutritionDay day) =>
    Map<String, Object?>.from(day.toJson()['totals']! as Map);

Map<String, Object?> _item(CoachNutritionDay day, [int index = 0]) =>
    Map<String, Object?>.from(
      (day.meals.single['items']! as List)[index] as Map,
    );

CoachContextSnapshot _context(List<CoachNutritionDay> days) =>
    CoachContextSnapshot(
      generatedAt: DateTime(2026, 10, 6),
      profile: const {},
      weights: const [],
      nutritionDays: days,
      waterHistory: const [],
      computedHealth: const {
        'dailyTargets': {
          'caloriesKcal': 2000,
          'proteinG': 150,
          'carbsG': 200,
          'fatG': 70,
        },
      },
    );

void main() {
  const twoKnown = <String, double>{
    'caloriesKcal': 246,
    'proteinG': 20,
    'carbsG': 24,
    'fatG': 6,
    'sodiumMg': 400,
  };
  for (final entry in const <String, FoodNutrient>{
    'caloriesKcal': FoodNutrient.calories,
    'proteinG': FoodNutrient.protein,
    'carbsG': FoodNutrient.carbohydrates,
    'fatG': FoodNutrient.fat,
    'sodiumMg': FoodNutrient.sodium,
  }.entries) {
    test('${entry.key} requires every item, preserving other known totals', () {
      final known = modernDiaryItem();
      final missing = modernDiaryItem(
        id: 2,
        values: {...basisNutrients, entry.value: null},
      );
      for (final rows in [
        [known, missing],
        [missing, known],
      ]) {
        final day = assembleCoachNutritionDays([_meal(rows)]).single;
        final knownIndex = rows.first.id == known.id ? 0 : 1;
        final missingIndex = 1 - knownIndex;
        expect(day.knownTotals, isNot(contains(entry.key)));
        expect(_totals(day), isNot(contains(entry.key)));
        expect(_item(day, knownIndex)[entry.key], basisNutrients[entry.value]);
        expect(_item(day, missingIndex), isNot(contains(entry.key)));
        for (final other in _contextKeys.where((key) => key != entry.key)) {
          expect(day.knownTotals, contains(other));
          expect(_totals(day)[other], isA<double>());
          expect(_totals(day)[other], twoKnown[other]);
        }
        if (entry.value != FoodNutrient.sodium) {
          expect(
            _context([day]).nutritionRemainingFor(DateTime(2026, 10, 6)),
            isNull,
          );
        }
      }
    });
  }

  test('calorie-only retains 1905 without inventing macro evidence', () {
    final day = assembleCoachNutritionDays([
      _meal(
        [calorieOnlyDiaryItem()],
        foods: {1: basisFood().copyWith(name: 'Not an eaten food')},
      ),
    ]).single;
    expect(_totals(day), {'caloriesKcal': 1905.0});
    expect(day.knownCalories, 1905);
    expect(_item(day), {
      'itemId': 1,
      'entryType': 'quick_add',
      'caloriesKcal': 1905.0,
    });
    for (final key in _contextKeys.skip(1)) {
      expect(_item(day), isNot(contains(key)));
    }
    expect(
      _context([day]).nutritionRemainingFor(DateTime(2026, 10, 6)),
      isNull,
    );
  });

  test('documented zero remains zero, including the energy policy', () {
    final day = assembleCoachNutritionDays([
      _meal([
        modernDiaryItem(
          values: {for (final nutrient in FoodNutrient.values) nutrient: 0},
        ),
      ]),
    ]).single;
    expect(_totals(day), {for (final key in _contextKeys) key: 0.0});
    expect(day.knownCalories, 0);
    expect(
      _context([day]).nutritionRemainingFor(DateTime(2026, 10, 6)),
      {'caloriesKcal': 2000, 'proteinG': 150, 'carbsG': 200, 'fatG': 70},
    );
    expect(_energy(day).remainingCalories, 2000);
  });

  for (final raw in <String?>[null, '{invalid']) {
    for (final empty in [false, true]) {
      test('modern envelope $raw with empty=$empty has no legacy fallback', () {
        final row = modernDiaryItem(
          values: empty ? const {} : basisNutrients,
        ).copyWith(foodEvidenceJson: Value(raw));
        final day = assembleCoachNutritionDays([
          _meal([row], foods: {row.foodId: basisFood()}),
        ]).single;
        expect(day.knownTotals, isEmpty);
        expect(_totals(day), isEmpty);
        expect(_item(day), {
          'itemId': row.id,
          'food': 'historical-food',
        });
        expect(day.knownCalories, isNull);
        expect(_energy(day).remainingCalories, isNull);
        expect(
          _context([day]).nutritionRemainingFor(DateTime(2026, 10, 6)),
          isNull,
        );
      });
    }
  }

  test('modern public food also requires the containing database owner', () {
    final row = modernDiaryItem();
    final day = assembleCoachNutritionDays([
      _meal([row], ownerKey: null, foods: {row.foodId: basisFood()}),
    ]).single;
    expect(day.knownTotals, isEmpty);
    expect(day.knownCalories, isNull);
    expect(_item(day), {'itemId': row.id, 'food': 'historical-food'});
  });

  test('modern projection disagreement cannot claim a known calorie sum', () {
    final row = modernDiaryItem().copyWith(calories: 0);
    final day = assembleCoachNutritionDays([
      _meal([row], foods: {row.foodId: basisFood()}),
    ]).single;
    expect(_totals(day), isEmpty);
    expect(_item(day)['food'], 'historical-food');
    expect(day.knownCalories, isNull);
  });

  test('fixed food evidence belongs to the containing meal owner', () {
    final row = modernDiaryItem(
      kind: CoachFoodSourceKind.userFixed,
      ownerKey: 'owner-a',
    );
    final right = assembleCoachNutritionDays([
      _meal([row], ownerKey: 'owner-a'),
    ]).single;
    expect(right.knownCalories, 123);
    expect(_item(right)['food'], 'Cooked food');
    for (final owner in <String?>['owner-b', null]) {
      final wrong = assembleCoachNutritionDays([
        _meal(
          [row],
          ownerKey: owner,
          foods: {row.foodId: basisFood()},
        ),
      ]).single;
      expect(_totals(wrong), isEmpty);
      expect(_item(wrong)['food'], 'historical-food');
      expect(wrong.knownCalories, isNull);
    }
  });

  test('a saved count conversion requires its own owner binding', () {
    final food = basisSnapshot();
    final portion = CoachFoodPortion(
      food: food,
      quantity: CoachFoodQuantity(
        grams: food.basisGrams,
        evidence: CoachFoodQuantityEvidence(
          kind: CoachFoodQuantityKind.userDeclared,
          description: 'One saved item',
          conversion: CoachFoodQuantityConversion(
            inputAmount: 1,
            inputUnit: 'item',
            gramsPerUnit: food.basisGrams,
            source: CoachFoodSourceEvidence(
              kind: CoachFoodSourceKind.userFixed,
              ref: 'fixture:personal-portion',
              revision: '1',
              ownerKey: 'owner-a',
            ),
          ),
        ),
      ),
    );
    final row = modernDiaryItem().copyWith(
      foodEvidenceJson: Value(portion.encodeForStorage()),
    );
    final right = assembleCoachNutritionDays([
      _meal([row], ownerKey: 'owner-a'),
    ]).single;
    expect(right.knownCalories, 123);
    for (final owner in <String?>['owner-b', null]) {
      final wrong = assembleCoachNutritionDays([
        _meal([row], ownerKey: owner),
      ]).single;
      expect(wrong.knownTotals, isEmpty);
      expect(wrong.knownCalories, isNull);
      expect(_item(wrong)['food'], 'historical-food');
    }
  });

  test('modern name survives mutable catalog rename and absence', () {
    final row = modernDiaryItem();
    for (final foods in <Map<int, Food>>[
      {row.foodId: basisFood().copyWith(name: 'Later catalog name')},
      const {},
    ]) {
      final day = assembleCoachNutritionDays([
        _meal([row], foods: foods),
      ]).single;
      expect(_item(day)['food'], 'Cooked food');
      expect(day.knownCalories, 123);
    }
  });

  test('legacy core zeros keep their contract and use their legacy name', () {
    final row = modernDiaryItem(values: const {}).copyWith(
      foodSourceSnapshot: 'catalog',
      foodEvidenceJson: const Value(null),
    );
    final day = assembleCoachNutritionDays([
      _meal([row], ownerKey: null, foods: {row.foodId: basisFood()}),
    ]).single;
    expect(_totals(day), {
      'caloriesKcal': 0.0,
      'proteinG': 0.0,
      'carbsG': 0.0,
      'fatG': 0.0,
    });
    expect(_item(day)['food'], 'Cooked food');
    expect(day.knownCalories, 0);
  });

  test('authoritative day key wins over a different timestamp date', () {
    final source = _meal([modernDiaryItem()]);
    final day = assembleCoachNutritionDays([
      MealWithItems(
        meal: source.meal.copyWith(date: DateTime.utc(2026, 10, 7)),
        items: source.items,
        ownerKey: source.ownerKey,
      ),
    ]).single;
    expect(day.day, '2026-10-06');
    expect(
      _context([day]).nutritionRemainingFor(DateTime(2026, 10, 6))![
        'caloriesKcal'
      ],
      1877,
    );
  });

  test('overflow never becomes a known infinite total', () {
    final row = modernDiaryItem().copyWith(
      foodSourceSnapshot: 'catalog',
      foodEvidenceJson: const Value(null),
      calories: 1e308,
    );
    final day = assembleCoachNutritionDays([
      _meal([row, row.copyWith(id: 2)]),
    ]).single;
    expect(day.knownCalories, isNull);
    expect(_totals(day), isNot(contains('caloriesKcal')));
    expect(_energy(day).remainingCalories, isNull);
  });

  final incompleteDays = <CoachNutritionDay?>[
    null,
    assembleCoachNutritionDays([_meal(const [])]).single,
    assembleCoachNutritionDays([
      _meal([modernDiaryItem(values: const {})]),
    ]).single,
  ];
  for (var index = 0; index < incompleteDays.length; index++) {
    test('derived energy is unavailable for missing evidence case $index', () {
      final day = incompleteDays[index];
      expect(day?.knownCalories, isNull);
      final energy = _energy(day);
      expect(energy.remainingCalories, isNull);
      expect(energy.baseCalorieGoal, 2000);
      expect(energy.effectiveCalorieGoal, 2000);
    });
  }

  test('an empty meal has no nutrient evidence', () {
    final day = assembleCoachNutritionDays([_meal(const [])]).single;
    expect(day.knownTotals, isEmpty);
    expect(day.knownCalories, isNull);
    expect(_totals(day), isEmpty);
  });
}

ExerciseCalorieResult _energy(CoachNutritionDay? day) =>
    ExerciseCaloriePolicy.calculate(
      preferences: const ExerciseCaloriePreferences(),
      day: DateTime(2026, 10, 6),
      baseCalorieGoal: 2000,
      consumedCalories: day?.knownCalories,
      baseProteinGoal: 150,
      baseCarbohydrateGoal: 200,
      baseFatGoal: 70,
    );
