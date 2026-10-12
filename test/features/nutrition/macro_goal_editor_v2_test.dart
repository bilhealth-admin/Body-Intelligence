import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/nutrition/domain/macro_goal_editor.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrient_daily_references.dart';

void main() {
  const start = MacroGoalAllocation(1000, 45, 20, 35);
  test('screenshot 1000 kcal percentages produce exact grams', () {
    expect(start.grams(MacroGoal.carbohydrate), 112.5);
    expect(start.grams(MacroGoal.protein), 50);
    expect(start.grams(MacroGoal.fat), closeTo(38.888888, .000001));
  });
  test(
    'grams calculate percentage and last edited protein survives low carbs',
    () {
      final protein = start.edit(MacroGoal.protein, 120, inGrams: true);
      final carbs = protein.edit(
        MacroGoal.carbohydrate,
        50,
        inGrams: true,
        previous: MacroGoal.protein,
      );
      expect(carbs.protein, 48);
      expect(carbs.grams(MacroGoal.protein), 120);
      expect(carbs.carbohydrate, 20);
      expect(carbs.fat, 32);
    },
  );
  test('explicit protein lock protects it from carbohydrate edits', () {
    final next = start.edit(
      MacroGoal.carbohydrate,
      5,
      locked: {MacroGoal.protein},
    );
    expect(next.protein, 20);
    expect(next.fat, 75);
  });
  test('two locked siblings reject an impossible change without mutation', () {
    expect(
      () => start.edit(
        MacroGoal.carbohydrate,
        5,
        locked: {MacroGoal.protein, MacroGoal.fat},
      ),
      throwsFormatException,
    );
    expect(start.carbohydrate, 45);
    expect(start.protein, 20);
    expect(start.fat, 35);
  });
  test('locked grams survive energy change; percentages remain coherent', () {
    final next = start.withCalories(
      2000,
      locked: {MacroGoal.protein},
      gramLocks: {MacroGoal.protein},
    );
    expect(next.grams(MacroGoal.protein), 50);
    expect(next.protein, 10);
    expect(next.carbohydrate + next.protein + next.fat, closeTo(100, 1e-9));
  });
  test('locked percentages survive energy change', () {
    final next = start.withCalories(2000, locked: {MacroGoal.protein});
    expect(next.protein, 20);
    expect(next.grams(MacroGoal.protein), 100);
  });
  test('known zero and full precision remain different from absent values', () {
    final next = start.edit(MacroGoal.carbohydrate, 0);
    expect(next.toPreferences()['goal.carbsGrams'], '0.0');
    expect(next.toPreferences(), hasLength(7));
    for (final goal in MacroGoal.values) {
      expect(
        double.parse(
          next.toPreferences()['goal.${MacroGoalAllocation.key(goal)}Grams']!,
        ),
        next.grams(goal),
      );
    }
  });
  test('reject nonfinite and overallocated inputs', () {
    for (final value in [double.nan, double.infinity, -1.0, 101.0]) {
      expect(() => start.edit(MacroGoal.protein, value), throwsFormatException);
    }
    expect(() => start.withCalories(0), throwsFormatException);
  });
  test('FDA references have correct units and no invented total-sugar DV', () {
    expect(NutrientDailyReferences.values['goal.calciumMg'], 1300);
    expect(NutrientDailyReferences.values['goal.potassium'], 4700);
    expect(NutrientDailyReferences.values['goal.fiber'], 28);
    expect(NutrientDailyReferences.values.containsKey('goal.sugar'), isFalse);
    expect(
      NutrientDailyReferences.values.containsKey('goal.transFat'),
      isFalse,
    );
  });
  test(
    'contradictory stored percentages must not silently rebalance on edit or calorie change',
    () {
      const invalid = MacroGoalAllocation(1000, 80, 80, 80);
      expect(() => invalid.edit(MacroGoal.protein, 20), throwsFormatException);
      expect(() => invalid.withCalories(2000), throwsFormatException);
      expect(invalid.toPreferences()['goal.carbsPercent'], '80.0');
    },
  );
}
