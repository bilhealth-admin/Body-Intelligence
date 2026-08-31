import 'dart:convert';

import '../../intelligence_center/domain/coach_context_preferences.dart';
import '../models/onboarding_draft.dart';

/// Existing BIL consumers that receive an onboarding priority.
///
/// This contract deliberately names only production capabilities. A goal may
/// be shown by onboarding only when it has at least one real downstream
/// consumer here; no success state is invented for an unavailable feature.
enum OnboardingGoalConsumer {
  weightGoal,
  calorieAndMacroPlan,
  nutritionAndMealPlanning,
  activityAndWorkoutRecommendations,
  sleepAndRecovery,
  fastingAndHabits,
  bodyMeasurementsAndBodyTwin,
  aiCoachContext,
}

final class OnboardingGoalBindings {
  const OnboardingGoalBindings._();

  static const storageKey = 'onboarding.goalPriorities.v1';

  static const consumers = <OnboardingGoal, Set<OnboardingGoalConsumer>>{
    OnboardingGoal.loseWeight: {
      OnboardingGoalConsumer.weightGoal,
      OnboardingGoalConsumer.calorieAndMacroPlan,
      OnboardingGoalConsumer.nutritionAndMealPlanning,
      OnboardingGoalConsumer.activityAndWorkoutRecommendations,
      OnboardingGoalConsumer.bodyMeasurementsAndBodyTwin,
      OnboardingGoalConsumer.aiCoachContext,
    },
    OnboardingGoal.maintainWeight: {
      OnboardingGoalConsumer.weightGoal,
      OnboardingGoalConsumer.calorieAndMacroPlan,
      OnboardingGoalConsumer.nutritionAndMealPlanning,
      OnboardingGoalConsumer.activityAndWorkoutRecommendations,
      OnboardingGoalConsumer.bodyMeasurementsAndBodyTwin,
      OnboardingGoalConsumer.aiCoachContext,
    },
    OnboardingGoal.gainWeight: {
      OnboardingGoalConsumer.weightGoal,
      OnboardingGoalConsumer.calorieAndMacroPlan,
      OnboardingGoalConsumer.nutritionAndMealPlanning,
      OnboardingGoalConsumer.activityAndWorkoutRecommendations,
      OnboardingGoalConsumer.bodyMeasurementsAndBodyTwin,
      OnboardingGoalConsumer.aiCoachContext,
    },
    OnboardingGoal.buildMuscle: {
      OnboardingGoalConsumer.calorieAndMacroPlan,
      OnboardingGoalConsumer.nutritionAndMealPlanning,
      OnboardingGoalConsumer.activityAndWorkoutRecommendations,
      OnboardingGoalConsumer.bodyMeasurementsAndBodyTwin,
      OnboardingGoalConsumer.aiCoachContext,
    },
    OnboardingGoal.improveNutrition: {
      OnboardingGoalConsumer.calorieAndMacroPlan,
      OnboardingGoalConsumer.nutritionAndMealPlanning,
      OnboardingGoalConsumer.aiCoachContext,
    },
    OnboardingGoal.planMeals: {
      OnboardingGoalConsumer.nutritionAndMealPlanning,
      OnboardingGoalConsumer.aiCoachContext,
    },
    OnboardingGoal.activityFitness: {
      OnboardingGoalConsumer.activityAndWorkoutRecommendations,
      OnboardingGoalConsumer.aiCoachContext,
    },
    OnboardingGoal.sleepRecovery: {
      OnboardingGoalConsumer.sleepAndRecovery,
      OnboardingGoalConsumer.aiCoachContext,
    },
    OnboardingGoal.fastingHabits: {
      OnboardingGoalConsumer.fastingAndHabits,
      OnboardingGoalConsumer.aiCoachContext,
    },
    OnboardingGoal.stressWellbeing: {
      OnboardingGoalConsumer.sleepAndRecovery,
      OnboardingGoalConsumer.fastingAndHabits,
      OnboardingGoalConsumer.aiCoachContext,
    },
  };

  static Set<CoachContextFocus> suggestedAiFocuses(Set<OnboardingGoal> goals) {
    final result = <CoachContextFocus>{};
    for (final goal in goals) {
      switch (goal) {
        case OnboardingGoal.loseWeight:
        case OnboardingGoal.maintainWeight:
        case OnboardingGoal.gainWeight:
        case OnboardingGoal.buildMuscle:
          result
            ..add(CoachContextFocus.nutrition)
            ..add(CoachContextFocus.training)
            ..add(CoachContextFocus.analytics);
          break;
        case OnboardingGoal.improveNutrition:
        case OnboardingGoal.planMeals:
          result.add(CoachContextFocus.nutrition);
          break;
        case OnboardingGoal.activityFitness:
          result.add(CoachContextFocus.training);
          break;
        case OnboardingGoal.sleepRecovery:
        case OnboardingGoal.fastingHabits:
        case OnboardingGoal.stressWellbeing:
          result.add(CoachContextFocus.habits);
          break;
      }
    }
    return Set.unmodifiable(result);
  }

  static String encode(Set<OnboardingGoal> goals) => jsonEncode({
    'version': 1,
    'goals': goals.map((goal) => goal.name).toList()..sort(),
  });

  static Set<OnboardingGoal> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final value = jsonDecode(raw);
      if (value is! Map || value['version'] != 1 || value['goals'] is! List) {
        return const {};
      }
      final names = (value['goals'] as List).map((item) => '$item').toSet();
      return Set.unmodifiable(
        OnboardingGoal.values.where((goal) => names.contains(goal.name)),
      );
    } on Object {
      return const {};
    }
  }
}
