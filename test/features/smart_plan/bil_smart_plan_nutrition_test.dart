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
  BilVerifiedRecipe serving(
    String id,
    BilPlanMealSlot slot, {
    double kcal = 500,
    double protein = 20,
    bool evidence = true,
  }) => BilVerifiedRecipe(
    id: id,
    slot: slot,
    nutrition: evidence
        ? BilPlanNutrients(
            values: {'kcal': kcal, 'proteinG': protein},
            source: 'fixture_source:$id',
          )
        : null,
  );

  Map<BilPlanMealSlot, List<BilVerifiedRecipe>> overlapping({
    double alternativeKcal = 500,
    double alternativeProtein = 20,
    bool evidence = true,
  }) => {
    BilPlanMealSlot.breakfast: [
      serving(
        'breakfast',
        BilPlanMealSlot.breakfast,
        kcal: 200,
        evidence: evidence,
      ),
    ],
    BilPlanMealSlot.lunch: [
      serving('shared', BilPlanMealSlot.lunch, evidence: evidence),
    ],
    BilPlanMealSlot.dinner: [
      serving('shared', BilPlanMealSlot.dinner, evidence: evidence),
      serving(
        'dinner-alternative',
        BilPlanMealSlot.dinner,
        kcal: alternativeKcal,
        protein: alternativeProtein,
        evidence: evidence,
      ),
    ],
  };

  test(
    'same-day diversity uses existing eligible alternatives without a target',
    () {
      final source = overlapping();
      final uses = <String, int>{'shared': 2};
      final selected = selectSmartPlanMeals(
        choices: source,
        target: null,
        useCount: uses,
        rotation: 0,
      );
      expect(selected.values.map((recipe) => recipe.id).toSet(), hasLength(3));
      expect(selected[BilPlanMealSlot.lunch]!.id, 'shared');
      expect(
        identical(
          selected[BilPlanMealSlot.dinner],
          source[BilPlanMealSlot.dinner]![1],
        ),
        isTrue,
        reason: 'Selection reuses the source serving, identity, and evidence.',
      );
      expect(uses, {'shared': 2});
    },
  );

  test(
    'scarce compatible pools still fill all slots and permit necessary repeats',
    () {
      final source = {
        for (final slot in BilPlanMealSlot.values)
          slot: [serving('only-safe-choice', slot)],
      };
      final selected = selectSmartPlanMeals(
        choices: source,
        target: null,
        useCount: {},
        rotation: 7,
      );
      expect(selected.keys.toSet(), BilPlanMealSlot.values.toSet());
      expect(
        selected.values.map((recipe) => recipe.id),
        everyElement('only-safe-choice'),
      );
    },
  );

  test(
    'fallback finds feasible diversity even when the first slot must change',
    () {
      final source = {
        BilPlanMealSlot.breakfast: [
          serving('shared', BilPlanMealSlot.breakfast),
          serving('breakfast-alternative', BilPlanMealSlot.breakfast),
        ],
        BilPlanMealSlot.lunch: [serving('shared', BilPlanMealSlot.lunch)],
        BilPlanMealSlot.dinner: [serving('dinner', BilPlanMealSlot.dinner)],
      };
      final selected = selectSmartPlanMeals(
        choices: source,
        target: null,
        useCount: {},
        rotation: 0,
      );
      expect(selected.values.map((recipe) => recipe.id).toSet(), hasLength(3));
      expect(selected[BilPlanMealSlot.breakfast]!.id, 'breakfast-alternative');
    },
  );

  test(
    'missing evidence permits safe diversity without inventing target nutrition',
    () {
      final selected = selectSmartPlanMeals(
        choices: overlapping(evidence: false),
        target: BilPlanNutrients(values: {'kcal': 1200}, source: 'saved_goal'),
        useCount: {},
        rotation: 0,
      );
      expect(selected.values.map((recipe) => recipe.id).toSet(), hasLength(3));
      expect(
        BilPlanNutrients.total(
          selected.values.map((recipe) => recipe.nutrition),
        ),
        isNull,
      );
    },
  );

  test(
    'identical source nutrient totals and target score prefer distinct meals',
    () {
      final selected = selectSmartPlanMeals(
        choices: overlapping(),
        target: BilPlanNutrients(values: {'kcal': 1200}, source: 'saved_goal'),
        useCount: {},
        rotation: 0,
      );
      expect(selected.values.map((recipe) => recipe.id).toSet(), hasLength(3));
      expect(
        BilPlanNutrients.total(
          selected.values.map((recipe) => recipe.nutrition),
        )!.values,
        {'kcal': 1200, 'proteinG': 60},
      );
    },
  );

  test('diversity never overrides a better saved nutrient-target fit', () {
    final selected = selectSmartPlanMeals(
      choices: overlapping(alternativeKcal: 700),
      target: BilPlanNutrients(values: {'kcal': 1200}, source: 'saved_goal'),
      useCount: {},
      rotation: 0,
    );
    expect(selected[BilPlanMealSlot.lunch]!.id, 'shared');
    expect(selected[BilPlanMealSlot.dinner]!.id, 'shared');
    expect(
      BilPlanNutrients.total(
        selected.values.map((recipe) => recipe.nutrition),
      )!.values,
      {'kcal': 1200, 'proteinG': 60},
    );
  });

  test(
    'a calorie tie cannot silently change another source nutrient total',
    () {
      final selected = selectSmartPlanMeals(
        choices: overlapping(alternativeProtein: 30),
        target: BilPlanNutrients(values: {'kcal': 1200}, source: 'saved_goal'),
        useCount: {},
        rotation: 0,
      );
      expect(selected[BilPlanMealSlot.dinner]!.id, 'shared');
      expect(
        BilPlanNutrients.total(
          selected.values.map((recipe) => recipe.nutrition),
        )!.values,
        {'kcal': 1200, 'proteinG': 60},
      );
    },
  );

  test(
    'an identical nutrient tie preserves the existing prior-use objective',
    () {
      final selected = selectSmartPlanMeals(
        choices: overlapping(),
        target: BilPlanNutrients(values: {'kcal': 1200}, source: 'saved_goal'),
        useCount: {'dinner-alternative': 1},
        rotation: 0,
      );
      expect(selected[BilPlanMealSlot.dinner]!.id, 'shared');
    },
  );
}
