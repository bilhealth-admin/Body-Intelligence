import 'package:body_intelligence_log/features/exercise_calorie_controls/domain/exercise_calorie_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 8, 10, 12);

  test('does not change goals when the preference is disabled', () {
    final result = ExerciseCaloriePolicy.calculate(
      preferences: const ExerciseCaloriePreferences(),
      day: day,
      baseCalorieGoal: 2000,
      consumedCalories: 1500,
      baseProteinGoal: 120,
      baseCarbohydrateGoal: 220,
      baseFatGoal: 60,
      energy: AuthoritativeExerciseEnergy(
        kcal: 400,
        observedAt: day,
        source: 'Health Connect',
        confidence: 1,
      ),
    );
    expect(result.availability, ExerciseCalorieAvailability.disabled);
    expect(result.effectiveCalorieGoal, 2000);
    expect(result.remainingCalories, 500);
    expect(result.appliedExerciseKcal, isNull);
  });

  test('fails closed when authoritative energy evidence is absent', () {
    final result = ExerciseCaloriePolicy.calculate(
      preferences: const ExerciseCaloriePreferences(
        includeInRemainingGoal: true,
        adjustMacroGoals: true,
      ),
      day: day,
      baseCalorieGoal: 2000,
      consumedCalories: 1500,
      baseProteinGoal: 120,
      baseCarbohydrateGoal: 220,
      baseFatGoal: 60,
    );
    expect(result.availability, ExerciseCalorieAvailability.unavailable);
    expect(result.effectiveCalorieGoal, 2000);
    expect(result.proteinGoal, 120);
  });

  test('rejects stale energy from another day', () {
    final result = ExerciseCaloriePolicy.calculate(
      preferences: const ExerciseCaloriePreferences(
        includeInRemainingGoal: true,
      ),
      day: day,
      baseCalorieGoal: 2000,
      consumedCalories: 1500,
      baseProteinGoal: 120,
      baseCarbohydrateGoal: 220,
      baseFatGoal: 60,
      energy: AuthoritativeExerciseEnergy(
        kcal: 400,
        observedAt: day.subtract(const Duration(days: 1)),
        source: 'Apple Health',
        confidence: 1,
      ),
    );
    expect(result.availability, ExerciseCalorieAvailability.unavailable);
    expect(result.remainingCalories, 500);
  });

  test('applies verified energy and adjusts macros only when requested', () {
    final result = ExerciseCaloriePolicy.calculate(
      preferences: const ExerciseCaloriePreferences(
        includeInRemainingGoal: true,
        adjustMacroGoals: true,
      ),
      day: day,
      baseCalorieGoal: 2000,
      consumedCalories: 1500,
      baseProteinGoal: 120,
      baseCarbohydrateGoal: 220,
      baseFatGoal: 60,
      energy: AuthoritativeExerciseEnergy(
        kcal: 500,
        observedAt: day,
        source: 'Health Connect',
        confidence: .9,
      ),
    );
    expect(result.availability, ExerciseCalorieAvailability.applied);
    expect(result.effectiveCalorieGoal, 2500);
    expect(result.remainingCalories, 1000);
    expect(result.proteinGoal, 150);
    expect(result.carbohydrateGoal, 275);
    expect(result.fatGoal, 75);
  });
}
