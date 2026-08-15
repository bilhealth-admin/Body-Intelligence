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

  test('day target reaches Coach and explicit grams retain precision', () {
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
    expect(result['proteinG'], 155);
    expect(result['carbsG'], 180);
    expect(result['fatG'], 60);
    expect(result['fiberG'], 30);
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
}
