import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
import 'package:body_intelligence_log/features/onboarding/domain/onboarding_goal_bindings.dart';
import 'package:body_intelligence_log/features/onboarding/domain/onboarding_plan_calculator.dart';
import 'package:body_intelligence_log/features/onboarding/models/onboarding_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OnboardingDraft valid({
    Set<OnboardingGoal> goals = const {OnboardingGoal.loseWeight},
    double target = 70,
    double pace = .5,
  }) => OnboardingDraft(
    preferredName: 'BIL User',
    goals: goals,
    activity: 'moderate',
    regularExercise: true,
    birthDate: DateTime(1990, 1, 1),
    sex: 'female',
    countryRegion: 'Egypt',
    heightCm: 170,
    currentWeightKg: 80,
    targetWeightKg: target,
    weeklyPaceKg: pace,
    waistCm: 82,
    neckCm: 34,
    hipsCm: 98,
  );

  test('selected weekly pace changes the persisted calorie recommendation', () {
    final slower = OnboardingPlanCalculator.calculate(
      valid(pace: .25),
      now: DateTime(2026, 8, 30),
    );
    final faster = OnboardingPlanCalculator.calculate(
      valid(pace: .75),
      now: DateTime(2026, 8, 30),
    );

    expect(slower.targets.calories, greaterThan(faster.targets.calories));
    expect(slower.weeklyPaceKg, -.25);
    expect(faster.weeklyPaceKg, -.75);
    expect(slower.targetDate!.isAfter(DateTime(2026, 8, 30)), isTrue);
  });

  test('unsafe pace and contradictory target never produce fake plan', () {
    expect(
      OnboardingPlanCalculator.validate(valid(pace: 5)).code,
      'pace_out_of_range',
    );
    expect(
      OnboardingPlanCalculator.validate(valid(target: 90)).code,
      'loss_target_must_be_lower',
    );
    expect(
      () => OnboardingPlanCalculator.calculate(valid(pace: 5)),
      throwsStateError,
    );
  });

  test('corrupt drafts with conflicting weight directions fail closed', () {
    final corrupt = valid(
      goals: const {OnboardingGoal.loseWeight, OnboardingGoal.gainWeight},
    );

    expect(
      OnboardingPlanCalculator.validate(corrupt).code,
      'conflicting_weight_goals',
    );
    expect(() => OnboardingPlanCalculator.calculate(corrupt), throwsStateError);
  });

  test('age gate uses exact date of birth', () {
    final minor = valid().copyWith(birthDate: DateTime.now());
    expect(OnboardingPlanCalculator.validate(minor).code, 'adult_required');
  });

  test('muscle goal changes macros without inventing weight gain', () {
    final maintain = valid(
      goals: const {OnboardingGoal.improveNutrition},
      target: 80,
      pace: 0,
    );
    final muscle = maintain.copyWith(goals: const {OnboardingGoal.buildMuscle});
    final baseline = OnboardingPlanCalculator.calculate(maintain);
    final strengthened = OnboardingPlanCalculator.calculate(muscle);

    expect(muscle.primaryWeightGoal, 'maintain');
    expect(
      strengthened.targets.protein,
      greaterThanOrEqualTo(baseline.targets.protein),
    );
  });

  test('every visible goal reaches at least one real production consumer', () {
    expect(
      OnboardingGoalBindings.consumers.keys,
      containsAll(OnboardingGoal.values),
    );
    for (final goal in OnboardingGoal.values) {
      final consumers = OnboardingGoalBindings.consumers[goal];
      expect(consumers, isNotNull, reason: goal.name);
      expect(consumers, isNotEmpty, reason: goal.name);
      expect(
        consumers,
        contains(OnboardingGoalConsumer.aiCoachContext),
        reason: goal.name,
      );
    }
  });

  test('goal preferences determine actual AI context boundaries', () {
    final nutrition = OnboardingGoalBindings.suggestedAiFocuses(const {
      OnboardingGoal.improveNutrition,
      OnboardingGoal.planMeals,
    });
    final habits = OnboardingGoalBindings.suggestedAiFocuses(const {
      OnboardingGoal.sleepRecovery,
      OnboardingGoal.fastingHabits,
    });
    expect(nutrition, {CoachContextFocus.nutrition});
    expect(habits, {CoachContextFocus.habits});
  });

  test('explicit empty AI context scope does not expand on decode', () {
    final encoded = const CoachContextPreferences(
      focuses: <CoachContextFocus>{},
    ).encode();
    expect(CoachContextPreferences.decode(encoded).focuses, isEmpty);
  });
}
