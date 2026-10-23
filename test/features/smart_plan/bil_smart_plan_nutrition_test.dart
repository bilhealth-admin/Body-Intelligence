import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrition_goal_snapshot.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_nutrition.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_nutrition_goals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 10, 23);
  BilPlanNutrients? resolve(
    Map<String, String> saved, {
    Map<String, double> suggestions = const {},
  }) => BilSmartPlanNutritionGoals.forDate(
    date: date,
    snapshot: NutritionGoalSnapshot.resolve(saved, suggestions),
    schedule: const NutritionGoalSchedule(),
  );
  test(
    'only saved reviewed targets influence plan; profile suggestion and malformed legacy remain separate',
    () {
      expect(resolve({}, suggestions: {'goal.calories': 2000}), isNull);
      expect(resolve({'dailyCalories': '1800'}), isNull);
      expect(resolve({'goal.calories': 'NaN'}), isNull);
      final target = resolve({
        'goal.calories': '1800',
        'goal.proteinGrams': '100',
      });
      expect(target!.values, {'kcal': 1800, 'proteinG': 100});
      expect(target.source, 'saved_manual_nutrition_goals');
    },
  );
  test(
    'weekday pathway outranks manual goal with the same 4-4-9 saved contract',
    () {
      final target = BilSmartPlanNutritionGoals.forDate(
        date: date,
        snapshot: NutritionGoalSnapshot.resolve({'goal.calories': '2400'}, {}),
        schedule: NutritionGoalSchedule(
          dayTargets: {
            date.weekday: const NutritionGoalTarget(
              calories: 1800,
              carbsPercent: 50,
              proteinPercent: 25,
              fatPercent: 25,
            ),
          },
        ),
      );
      expect(target!.values, {
        'kcal': 1800,
        'proteinG': 112.5,
        'carbohydrateG': 225,
        'fatG': 50,
      });
      expect(target.source, 'saved_daily_nutrition_schedule');
    },
  );
  test(
    'a six-month target map uses calendar dates across DST and retains distinct weekday goals',
    () {
      final targets = BilSmartPlanNutritionGoals.forPlan(
        start: date,
        horizon: BilPlanHorizon.sixMonths,
        snapshot: NutritionGoalSnapshot.resolve({}, {}),
        schedule: const NutritionGoalSchedule(
          dayTargets: {
            DateTime.friday: NutritionGoalTarget(
              calories: 1800,
              carbsPercent: 50,
              proteinPercent: 25,
              fatPercent: 25,
            ),
            DateTime.saturday: NutritionGoalTarget(
              calories: 2000,
              carbsPercent: 50,
              proteinPercent: 25,
              fatPercent: 25,
            ),
          },
        ),
      );
      expect(targets['2026-10-30']!.values['kcal'], 1800);
      expect(targets['2026-10-31']!.values['kcal'], 2000);
      expect(targets.containsKey('2026-10-29'), isFalse);
    },
  );
  Map<BilPlanMealSlot, List<BilVerifiedRecipe>> recipes({
    bool evidence = true,
  }) => {
    for (final slot in BilPlanMealSlot.values)
      slot: [
        BilVerifiedRecipe(
          id: '${slot.name}-small',
          slot: slot,
          nutrition: evidence
              ? BilPlanNutrients(
                  values: {'kcal': 200},
                  source: 'fixture_source',
                )
              : null,
        ),
        BilVerifiedRecipe(
          id: '${slot.name}-medium',
          slot: slot,
          nutrition: evidence
              ? BilPlanNutrients(
                  values: {'kcal': 500},
                  source: 'fixture_source',
                )
              : null,
        ),
      ],
  };
  test(
    'real selection changes with saved target while recipes and source portions remain unchanged',
    () {
      final source = recipes();
      final selected = selectSmartPlanMeals(
        choices: source,
        target: BilPlanNutrients(values: {'kcal': 1500}, source: 'saved_goal'),
        useCount: {},
        rotation: 0,
      );
      expect(
        selected.values.map((recipe) => recipe.id),
        everyElement(endsWith('-medium')),
      );
      expect(
        BilPlanNutrients.total(
          selected.values.map((recipe) => recipe.nutrition),
        )!.values['kcal'],
        1500,
      );
      expect(source.values.expand((rows) => rows).length, 6);
    },
  );
  test(
    'missing nutrient evidence never becomes a made-up number or prescribed portion',
    () {
      final source = recipes(evidence: false);
      final selected = selectSmartPlanMeals(
        choices: source,
        target: BilPlanNutrients(values: {'kcal': 1500}, source: 'saved_goal'),
        useCount: {},
        rotation: 1,
      );
      expect(
        selected.values.map((recipe) => recipe.id),
        everyElement(endsWith('-medium')),
      );
      expect(
        BilPlanNutrients.total(
          selected.values.map((recipe) => recipe.nutrition),
        ),
        isNull,
      );
    },
  );
}
