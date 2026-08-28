import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_nutrition_goal_resolver.dart';
import 'package:body_intelligence_log/features/nutrition/domain/macro_gram_goals.dart';
import 'package:body_intelligence_log/features/nutrition/domain/percentage_nutrition_goals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fallback = <String, double>{
    'caloriesKcal': 2000,
    'proteinG': 100,
    'carbsG': 250,
    'fatG': 67,
    'fiberG': 30,
  };

  test('active diet day target outranks stale explicit grams in Coach', () {
    const monday = NutritionGoalTarget(
      calories: 1800,
      carbsPercent: 40,
      proteinPercent: 30,
      fatPercent: 30,
    );
    final result = CoachNutritionGoalResolver.resolve(
      localDay: DateTime(2026, 8, 10),
      fallback: fallback,
      schedule: const NutritionGoalSchedule(dayTargets: {1: monday}),
      percentageGoals: PercentageNutritionGoals.resolve(
        calories: 2200,
        carbohydratesPercent: 50,
        proteinPercent: 25,
        fatPercent: 25,
      ),
      gramGoals: const MacroGramGoals(protein: 155),
    );

    expect(result['caloriesKcal'], 1800);
    expect(result['proteinG'], 135);
    expect(result['carbsG'], 180);
    expect(result['fatG'], 60);
    expect(result['fiberG'], 30);
  });

  test('active diet day target reports the same winning macro source', () {
    const monday = NutritionGoalTarget(
      calories: 1800,
      carbsPercent: 40,
      proteinPercent: 30,
      fatPercent: 30,
    );
    final resolution = CoachNutritionGoalResolver.resolveWithSources(
      localDay: DateTime(2026, 8, 10),
      fallback: fallback,
      schedule: const NutritionGoalSchedule(dayTargets: {1: monday}),
      gramGoals: const MacroGramGoals(
        protein: 155,
        carbohydrates: 210,
        fat: 65,
      ),
    );

    expect(resolution.targets['proteinG'], 135);
    expect(resolution.targets['carbsG'], 180);
    expect(resolution.targets['fatG'], 60);
    expect(resolution.sources['proteinG'], 'scheduled_percentage_goal');
    expect(resolution.sources['carbsG'], 'scheduled_percentage_goal');
    expect(resolution.sources['fatG'], 'scheduled_percentage_goal');
  });

  test('meal goal contract is exposed without dropping meal identity', () {
    const breakfast = NutritionGoalTarget(
      calories: 500,
      carbsPercent: 45,
      proteinPercent: 30,
      fatPercent: 25,
    );
    final targets = CoachNutritionGoalResolver.mealTargets(
      const NutritionGoalSchedule(mealTargets: {'breakfast': breakfast}),
    );

    expect(targets.keys, ['breakfast']);
    expect(targets['breakfast']?['caloriesKcal'], 500);
    expect(targets['breakfast']?['proteinPercent'], 30);
  });

  test('protein target retains the exact winning source', () {
    final explicit = CoachNutritionGoalResolver.resolveWithSources(
      localDay: DateTime(2026, 8, 10),
      fallback: fallback,
      fallbackSources: const {'proteinG': 'saved_plan_recommendation'},
      schedule: const NutritionGoalSchedule(),
      percentageGoals: PercentageNutritionGoals.resolve(
        calories: 2200,
        carbohydratesPercent: 50,
        proteinPercent: 25,
        fatPercent: 25,
      ),
      gramGoals: const MacroGramGoals(protein: 155),
    );
    expect(explicit.targets['proteinG'], 155);
    expect(explicit.sources['proteinG'], 'saved_gram_goal');

    final fallbackOnly = CoachNutritionGoalResolver.resolveWithSources(
      localDay: DateTime(2026, 8, 10),
      fallback: fallback,
      fallbackSources: const {'proteinG': 'saved_plan_recommendation'},
      schedule: const NutritionGoalSchedule(),
    );
    expect(fallbackOnly.targets['proteinG'], 100);
    expect(fallbackOnly.sources['proteinG'], 'saved_plan_recommendation');
  });
}
