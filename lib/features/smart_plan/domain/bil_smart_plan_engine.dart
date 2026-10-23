import 'bil_smart_plan.dart';
import 'bil_smart_plan_nutrition.dart';

/// Only app-verified catalog IDs may reach the generated, saved schedule.
final class BilVerifiedWorkout {
  BilVerifiedWorkout({
    required this.id,
    required Iterable<String> exerciseIds,
    required this.minutes,
  }) : exerciseIds = List.unmodifiable(exerciseIds) {
    if (id.isEmpty ||
        this.exerciseIds.isEmpty ||
        this.exerciseIds.length > 12 ||
        minutes < 5 ||
        minutes > 120) {
      throw ArgumentError('invalid_verified_workout');
    }
  }
  final String id;
  final List<String> exerciseIds;
  final int minutes;
}

final class BilVerifiedRecipe {
  const BilVerifiedRecipe({
    required this.id,
    required this.slot,
    this.nutrition,
  });
  final String id;
  final BilPlanMealSlot slot;
  final BilPlanNutrients? nutrition;
}

final class BilVerifiedPlanPhase {
  const BilVerifiedPlanPhase({required this.month, required this.sessionIds});
  final int month;
  final List<String> sessionIds;
}

final class BilPlanCreationRequest {
  BilPlanCreationRequest({
    required this.ownerId,
    required this.planId,
    required this.startOn,
    required this.horizon,
    required this.focus,
    required this.workoutsPerWeek,
    required this.confirmedPreferences,
    required this.workoutCatalog,
    required this.recipeCatalog,
    this.adultConfirmed = false,
    this.ageYears,
    this.underMedicalReview = false,
    this.highRiskSymptoms = false,
    this.requestedDailyCalories,
    this.targetWeightKg,
    this.currentWeightKg,
    this.targetBy,
    this.setup,
    this.phases = const [],
    this.nutritionTargets = const {},
  });

  final String ownerId, planId;
  final DateTime startOn;
  final BilPlanHorizon horizon;
  final BilPlanFocus focus;
  final int workoutsPerWeek;
  final bool confirmedPreferences;
  final bool adultConfirmed;
  final int? ageYears;
  final bool underMedicalReview, highRiskSymptoms;
  final int? requestedDailyCalories;
  final double? currentWeightKg, targetWeightKg;
  final DateTime? targetBy;
  final List<BilVerifiedWorkout> workoutCatalog;
  final List<BilVerifiedRecipe> recipeCatalog;
  final BilPlanSetup? setup;
  final List<BilVerifiedPlanPhase> phases;
  final Map<String, BilPlanNutrients> nutritionTargets;
}

enum BilPlanSafetyResult { ready, needsClinicianReview, invalid }

final class BilPlanSafetyAssessment {
  const BilPlanSafetyAssessment(this.result, this.reasons);
  final BilPlanSafetyResult result;
  final List<String> reasons;
}

/// No AI-calculated calorie prescriptions or medical assertions.
abstract final class BilPlanSafety {
  static BilPlanSafetyAssessment assess(BilPlanCreationRequest request) {
    final reasons = <String>[];
    for (final value in [request.currentWeightKg, request.targetWeightKg]) {
      if (value != null && (!value.isFinite || value < 20 || value > 500)) {
        reasons.add('invalid_weight_input');
      }
    }
    if (!request.adultConfirmed ||
        (request.ageYears != null && request.ageYears! < 18)) {
      reasons.add('adult_assessment_required');
    }
    if (!request.confirmedPreferences) reasons.add('confirm_preferences');
    if (request.workoutsPerWeek < 0 ||
        request.workoutsPerWeek > 6 ||
        request.ownerId.isEmpty ||
        request.planId.isEmpty) {
      reasons.add('invalid_schedule_input');
      return BilPlanSafetyAssessment(BilPlanSafetyResult.invalid, reasons);
    }
    if (request.focus != BilPlanFocus.nutrition &&
        request.workoutsPerWeek == 0) {
      reasons.add('choose_training_frequency');
    }
    if (request.focus != BilPlanFocus.nutrition &&
        request.setup?.environment == BilPlanEnvironment.home &&
        request.workoutsPerWeek > 3) {
      reasons.add('home_strength_recovery_days_required');
    }
    if (request.focus != BilPlanFocus.nutrition &&
        request.workoutCatalog.isEmpty) {
      reasons.add('no_verified_workout');
    }
    if (request.focus != BilPlanFocus.training &&
        request.recipeCatalog.isEmpty) {
      reasons.add('no_compatible_recipes');
    }
    if (request.focus != BilPlanFocus.training) {
      for (final slot in BilPlanMealSlot.values) {
        if (!request.recipeCatalog.any((recipe) => recipe.slot == slot)) {
          reasons.add('incomplete_meal_catalog_${slot.name}');
        }
      }
    }
    if (reasons.isNotEmpty) {
      return BilPlanSafetyAssessment(BilPlanSafetyResult.invalid, reasons);
    }
    if (request.highRiskSymptoms) reasons.add('symptoms_need_assessment');
    if (request.requestedDailyCalories != null &&
        request.requestedDailyCalories! < 1200) {
      reasons.add('low_energy_intake_needs_review');
    }
    if (request.currentWeightKg != null &&
        request.targetWeightKg != null &&
        request.targetBy != null &&
        request.targetWeightKg! < request.currentWeightKg!) {
      final delta = request.currentWeightKg! - request.targetWeightKg!;
      final days = BilPlanDate.atMidnight(
        request.targetBy!,
      ).difference(BilPlanDate.atMidnight(request.startOn)).inDays;
      if (days <= 0 || delta / days * 7 > 1) {
        reasons.add('rapid_weight_change_needs_review');
      }
    }
    if (request.underMedicalReview) reasons.add('existing_medical_review');
    return BilPlanSafetyAssessment(
      reasons.isEmpty
          ? BilPlanSafetyResult.ready
          : BilPlanSafetyResult.needsClinicianReview,
      List.unmodifiable(reasons),
    );
  }
}

/// Deterministic schedule generation, not a medical prescription.
/// Long plans are roadmaps, reviewed weekly, rather than fixed six-month doses.
final class BilSmartPlanEngine {
  const BilSmartPlanEngine();

  BilSmartPlan generate(BilPlanCreationRequest request, DateTime now) {
    final safety = BilPlanSafety.assess(request);
    if (safety.result != BilPlanSafetyResult.ready) {
      throw StateError(
        'smart_plan_requires_review:${safety.reasons.join(',')}',
      );
    }
    final anchor = BilPlanDate.atMidnight(request.startOn);
    final length = BilPlanDate.durationDays(request.horizon, anchor);
    final scheduledWeekdays = <int>{};
    for (var i = 0; i < request.workoutsPerWeek; i++) {
      scheduledWeekdays.add(i * 7 ~/ request.workoutsPerWeek);
    }
    final workouts = request.workoutCatalog;
    final mealSlots = <BilPlanMealSlot, List<BilVerifiedRecipe>>{
      for (final slot in BilPlanMealSlot.values)
        slot: request.recipeCatalog
            .where((recipe) => recipe.slot == slot)
            .toList(growable: false),
    };
    var workoutIndex = 0;
    final mealUses = <String, int>{};
    final days = <BilPlanDay>[];
    for (var day = 0; day < length; day++) {
      final date = BilPlanDate.iso(anchor.add(Duration(days: day)));
      final weekIndex = day ~/ 7;
      final civilDate = anchor.add(Duration(days: day));
      var monthIndex = 1;
      while (monthIndex < 6 &&
          !civilDate.isBefore(BilPlanDate.afterMonths(anchor, monthIndex))) {
        monthIndex++;
      }
      final sourcePhase = request.phases
          .where((phase) => phase.month == monthIndex)
          .firstOrNull;
      BilPlanWorkout? workout;
      if (request.focus != BilPlanFocus.nutrition &&
          scheduledWeekdays.contains(day % 7)) {
        final phaseWorkouts = sourcePhase == null
            ? workouts
            : [
                for (final id in sourcePhase.sessionIds)
                  workouts.singleWhere((workout) => workout.id == id),
              ];
        if (phaseWorkouts.isEmpty) {
          throw StateError('smart_plan_missing_phase_catalog');
        }
        final choice = phaseWorkouts[workoutIndex % phaseWorkouts.length];
        workoutIndex++;
        workout = BilPlanWorkout(
          templateId: choice.id,
          exerciseIds: choice.exerciseIds,
          minutes: request.setup?.sessionMinutes ?? choice.minutes,
        );
      }
      final meals = <BilPlanMeal>[];
      if (request.focus != BilPlanFocus.training) {
        final selected = selectSmartPlanMeals(
          choices: mealSlots,
          target: request.nutritionTargets[date],
          useCount: mealUses,
          rotation: day + weekIndex,
        );
        for (final slot in BilPlanMealSlot.values) {
          final choice = selected[slot]!;
          meals.add(BilPlanMeal(slot: slot, recipeId: choice.id));
          mealUses.update(choice.id, (count) => count + 1, ifAbsent: () => 1);
        }
      }
      final phase = sourcePhase != null
          ? 'gym-month-$monthIndex'
          : switch (weekIndex) {
              < 2 => 'foundation',
              < 6 => 'consistency',
              < 12 => 'progression',
              _ => 'review_and_adapt',
            };
      days.add(
        BilPlanDay(date: date, phase: phase, workout: workout, meals: meals),
      );
    }
    return BilSmartPlan(
      id: request.planId,
      ownerId: request.ownerId,
      horizon: request.horizon,
      focus: request.focus,
      startDate: BilPlanDate.iso(anchor),
      status: BilPlanStatus.draft,
      revision: 1,
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
      days: days,
      setup: request.setup,
    );
  }
}
