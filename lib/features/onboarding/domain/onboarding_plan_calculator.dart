import '../../../engine/body_model_engine.dart';
import '../../../engine/body_profile.dart';
import '../../../engine/daily_targets.dart';
import '../models/onboarding_draft.dart';
import 'adult_eligibility.dart';

final class OnboardingPlanResult {
  const OnboardingPlanResult({
    required this.model,
    required this.targets,
    required this.weeklyPaceKg,
    required this.targetDate,
    required this.assumptions,
  });

  final BodyModelResult model;
  final DailyTargets targets;

  /// Negative is loss, positive is gain, zero is maintenance.
  final double weeklyPaceKg;
  final DateTime? targetDate;
  final List<String> assumptions;
}

final class OnboardingPlanValidation {
  const OnboardingPlanValidation.valid() : code = null;
  const OnboardingPlanValidation.invalid(this.code);

  final String? code;
  bool get isValid => code == null;
}

/// Applies the app's existing Mifflin-St Jeor body model while making the
/// explicitly selected weekly pace real. No result is returned when the pace
/// would fall outside the current plan repository's supported nutrition range.
final class OnboardingPlanCalculator {
  const OnboardingPlanCalculator._();

  static const kilocaloriesPerKilogram = 7700.0;

  static OnboardingPlanValidation validate(
    OnboardingDraft draft, {
    DateTime? on,
  }) {
    final birthDate = draft.birthDate;
    if (birthDate == null) {
      return const OnboardingPlanValidation.invalid('birth_date_required');
    }
    if (!BilAdultEligibility.isEligibleBirthDate(birthDate, on: on)) {
      return const OnboardingPlanValidation.invalid('adult_required');
    }
    if (!const {'male', 'female'}.contains(draft.sex)) {
      return const OnboardingPlanValidation.invalid('sex_required');
    }
    if (draft.activity == null) {
      return const OnboardingPlanValidation.invalid('activity_required');
    }
    if (draft.goals.isEmpty) {
      return const OnboardingPlanValidation.invalid('goal_required');
    }
    final weightGoalCount = draft.goals
        .where(
          (goal) =>
              goal == OnboardingGoal.loseWeight ||
              goal == OnboardingGoal.maintainWeight ||
              goal == OnboardingGoal.gainWeight,
        )
        .length;
    if (weightGoalCount > 1) {
      return const OnboardingPlanValidation.invalid('conflicting_weight_goals');
    }
    if (draft.countryRegion.trim().length < 2) {
      return const OnboardingPlanValidation.invalid('country_required');
    }
    final height = draft.heightCm;
    if (height == null || !height.isFinite || height < 120 || height > 250) {
      return const OnboardingPlanValidation.invalid('height_out_of_range');
    }

    final targetValidation = validateTargetWeight(draft);
    if (!targetValidation.isValid) return targetValidation;

    final pace = draft.weeklyPaceKg ?? 0;
    if (draft.primaryWeightGoal == 'maintain') {
      if (pace.abs() > .001) {
        return const OnboardingPlanValidation.invalid(
          'maintenance_pace_must_be_zero',
        );
      }
    } else if (!pace.isFinite || pace <= 0 || pace > maxSafePaceKg(draft)) {
      return const OnboardingPlanValidation.invalid('pace_out_of_range');
    }

    for (final value in <double?>[draft.waistCm, draft.neckCm, draft.hipsCm]) {
      if (value != null && (!value.isFinite || value < 20 || value > 300)) {
        return const OnboardingPlanValidation.invalid(
          'measurement_out_of_range',
        );
      }
    }
    if (draft.sex == 'male' &&
        draft.waistCm != null &&
        draft.neckCm != null &&
        draft.waistCm! <= draft.neckCm!) {
      return const OnboardingPlanValidation.invalid('waist_must_exceed_neck');
    }
    if (draft.sex == 'female' &&
        draft.waistCm != null &&
        draft.neckCm != null &&
        draft.hipsCm != null &&
        draft.waistCm! + draft.hipsCm! <= draft.neckCm!) {
      return const OnboardingPlanValidation.invalid(
        'circumference_relationship_invalid',
      );
    }
    return const OnboardingPlanValidation.valid();
  }

  /// Validates only the values that are available on the target-weight step.
  /// Weekly pace belongs to the following step and must not block navigation.
  static OnboardingPlanValidation validateTargetWeight(OnboardingDraft draft) {
    final current = draft.currentWeightKg;
    final target = draft.targetWeightKg;
    if (current == null || !current.isFinite || current < 20 || current > 500) {
      return const OnboardingPlanValidation.invalid(
        'current_weight_out_of_range',
      );
    }
    if (target == null || !target.isFinite || target < 20 || target > 500) {
      return const OnboardingPlanValidation.invalid(
        'target_weight_out_of_range',
      );
    }

    switch (draft.primaryWeightGoal) {
      case 'lose':
        if (target >= current) {
          return const OnboardingPlanValidation.invalid(
            'loss_target_must_be_lower',
          );
        }
        break;
      case 'gain':
        if (target <= current) {
          return const OnboardingPlanValidation.invalid(
            'gain_target_must_be_higher',
          );
        }
        break;
      default:
        if ((target - current).abs() > .1) {
          return const OnboardingPlanValidation.invalid(
            'maintenance_target_must_match',
          );
        }
        break;
    }
    return const OnboardingPlanValidation.valid();
  }

  static double maxSafePaceKg(OnboardingDraft draft) {
    final current = draft.currentWeightKg ?? 0;
    if (draft.primaryWeightGoal == 'lose') {
      return (current * .01).clamp(.1, 1.0).toDouble();
    }
    if (draft.primaryWeightGoal == 'gain') {
      return (current * .005).clamp(.1, .5).toDouble();
    }
    return 0;
  }

  static List<double> paceOptions(OnboardingDraft draft) {
    if (draft.primaryWeightGoal == 'maintain') return const <double>[0];
    final candidates = draft.primaryWeightGoal == 'lose'
        ? const <double>[.25, .5, .75, 1]
        : const <double>[.1, .25, .5];
    final max = maxSafePaceKg(draft);
    final options = candidates.where((value) => value <= max + .0001).toList();
    if (options.isEmpty) options.add(double.parse(max.toStringAsFixed(2)));
    return List.unmodifiable(options);
  }

  static OnboardingPlanResult calculate(
    OnboardingDraft draft, {
    DateTime? now,
  }) {
    final validation = validate(draft, on: now);
    if (!validation.isValid) throw StateError(validation.code!);

    final age = BilAdultEligibility.ageOn(draft.birthDate!, on: now);
    final profile = BodyProfile(
      age: age,
      gender: draft.sex!,
      height: draft.heightCm!,
      weight: draft.currentWeightKg!,
      targetWeight: draft.targetWeightKg!,
      activityLevel: draft.activity!,
      exercises: draft.regularExercise,
      goalType: draft.primaryWeightGoal,
      waistCm: draft.waistCm,
      neckCm: draft.neckCm,
      hipCm: draft.sex == 'female' ? draft.hipsCm : null,
    );
    final model = BodyModelEngine.calculate(profile);
    final pace = draft.weeklyPaceKg ?? 0;
    final signedPace = switch (draft.primaryWeightGoal) {
      'lose' => -pace,
      'gain' => pace,
      _ => 0.0,
    };
    final dailyEnergyChange =
        signedPace * kilocaloriesPerKilogram / DateTime.daysPerWeek;
    final calories = (model.tdeeKcal + dailyEnergyChange).round();
    if (calories < 1200 || calories > 6000) {
      throw StateError('pace_energy_out_of_supported_range');
    }

    final proteinBase = draft.primaryWeightGoal == 'maintain'
        ? draft.currentWeightKg!
        : draft.targetWeightKg!;
    final proteinMultiplier =
        draft.regularExercise ||
            draft.goals.contains(OnboardingGoal.buildMuscle)
        ? 1.8
        : 1.4;
    final protein = (proteinBase * proteinMultiplier).round().clamp(30, 400);
    final fats = (calories * .30 / 9).round().clamp(20, 300);
    final carbs = ((calories - protein * 4 - fats * 9) / 4).round();
    if (carbs < 20 || carbs > 1000) {
      throw StateError('pace_macros_out_of_supported_range');
    }
    final targets = DailyTargets(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      potassium: model.targets.potassium,
      sodium: model.targets.sodium,
      fiber: model.targets.fiber,
      water: model.targets.water,
    );

    final difference = (draft.targetWeightKg! - draft.currentWeightKg!).abs();
    final weeks = pace <= 0 ? null : (difference / pace).ceil();
    final calculatedAt = now ?? DateTime.now();
    final targetDate = weeks == null || weeks == 0
        ? null
        : calculatedAt.add(Duration(days: weeks * DateTime.daysPerWeek));
    return OnboardingPlanResult(
      model: model,
      targets: targets,
      weeklyPaceKg: signedPace,
      targetDate: targetDate,
      assumptions: <String>[
        'Mifflin-St Jeor estimate from age, sex, height and current weight',
        'Baseline activity is separate from logged exercise',
        'Weekly energy estimate uses 7,700 kcal per kilogram',
        'Food intake, activity and scale weight can change the forecast',
      ],
    );
  }
}
