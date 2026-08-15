final class ExerciseCaloriePreferences {
  const ExerciseCaloriePreferences({
    this.includeInRemainingGoal = false,
    this.adjustMacroGoals = false,
  });

  final bool includeInRemainingGoal;
  final bool adjustMacroGoals;
}

final class AuthoritativeExerciseEnergy {
  const AuthoritativeExerciseEnergy({
    required this.kcal,
    required this.observedAt,
    required this.source,
    required this.confidence,
  });

  final double kcal;
  final DateTime observedAt;
  final String source;
  final double confidence;

  bool isValidFor(DateTime day) =>
      kcal.isFinite &&
      kcal >= 0 &&
      kcal <= 100000 &&
      confidence > 0 &&
      source.trim().isNotEmpty &&
      observedAt.toLocal().year == day.toLocal().year &&
      observedAt.toLocal().month == day.toLocal().month &&
      observedAt.toLocal().day == day.toLocal().day;
}

enum ExerciseCalorieAvailability { disabled, unavailable, applied }

final class ExerciseCalorieResult {
  const ExerciseCalorieResult({
    required this.availability,
    required this.baseCalorieGoal,
    required this.effectiveCalorieGoal,
    required this.remainingCalories,
    required this.proteinGoal,
    required this.carbohydrateGoal,
    required this.fatGoal,
    this.appliedExerciseKcal,
  });

  final ExerciseCalorieAvailability availability;
  final double baseCalorieGoal;
  final double effectiveCalorieGoal;
  final double remainingCalories;
  final double proteinGoal;
  final double carbohydrateGoal;
  final double fatGoal;
  final double? appliedExerciseKcal;
}

abstract final class ExerciseCaloriePolicy {
  static ExerciseCalorieResult calculate({
    required ExerciseCaloriePreferences preferences,
    required DateTime day,
    required double baseCalorieGoal,
    required double consumedCalories,
    required double baseProteinGoal,
    required double baseCarbohydrateGoal,
    required double baseFatGoal,
    AuthoritativeExerciseEnergy? energy,
  }) {
    final validEnergy = energy != null && energy.isValidFor(day);
    final applied = preferences.includeInRemainingGoal && validEnergy
        ? energy.kcal
        : 0.0;
    final effectiveCalories = baseCalorieGoal + applied;
    final adjustMacros =
        preferences.adjustMacroGoals && applied > 0 && baseCalorieGoal > 0;
    final scale = adjustMacros ? effectiveCalories / baseCalorieGoal : 1.0;
    return ExerciseCalorieResult(
      availability: !preferences.includeInRemainingGoal
          ? ExerciseCalorieAvailability.disabled
          : validEnergy
          ? ExerciseCalorieAvailability.applied
          : ExerciseCalorieAvailability.unavailable,
      baseCalorieGoal: baseCalorieGoal,
      effectiveCalorieGoal: effectiveCalories,
      remainingCalories: effectiveCalories - consumedCalories,
      proteinGoal: baseProteinGoal * scale,
      carbohydrateGoal: baseCarbohydrateGoal * scale,
      fatGoal: baseFatGoal * scale,
      appliedExerciseKcal: applied > 0 ? applied : null,
    );
  }
}
