import 'body_composition_engine.dart';
import 'body_profile.dart';
import 'daily_targets.dart';
import 'hydration_engine.dart';
import 'nutrition_engine.dart';
import 'activity_factor.dart';

/// Versioned, deterministic output shared by plan, calories/macros, progress,
/// dashboard and coach consumers. Values are estimates, never diagnoses.
class BodyModelResult {
  const BodyModelResult({
    required this.version,
    required this.profile,
    required this.bmrKcal,
    required this.tdeeKcal,
    required this.composition,
    required this.targets,
  });

  final String version;
  final BodyProfile profile;
  final double bmrKcal;
  final double tdeeKcal;
  final BodyCompositionResult composition;
  final DailyTargets targets;
}

class BodyModelEngine {
  const BodyModelEngine._();

  static const version = 'body-model-v1';

  static BodyModelResult calculate(BodyProfile profile) {
    _validate(profile);
    final sexOffset = profile.gender.trim().toLowerCase() == 'male' ? 5 : -161;
    final bmr =
        10 * profile.weight +
        6.25 * profile.height -
        5 * profile.age +
        sexOffset;
    final tdee =
        bmr * activityFactor(_normalizeActivity(profile.activityLevel));
    final composition = BodyCompositionEngine.calculate(
      gender: profile.gender,
      age: profile.age,
      heightCm: profile.height,
      currentWeightKg: profile.weight,
      waistCm: profile.waistCm,
      neckCm: profile.neckCm,
      hipCm: profile.hipCm,
    );
    final targets = NutritionEngine.calculate(profile: profile, tdee: tdee);
    return BodyModelResult(
      version: version,
      profile: profile,
      bmrKcal: bmr,
      tdeeKcal: tdee,
      composition: composition,
      targets: DailyTargets(
        calories: targets.calories,
        protein: targets.protein,
        carbs: targets.carbs,
        fats: targets.fats,
        potassium: targets.potassium,
        sodium: targets.sodium,
        fiber: targets.fiber,
        water: HydrationEngine.calculate(profile),
      ),
    );
  }

  static void _validate(BodyProfile profile) {
    if (profile.age < 16 || profile.age > 120) {
      throw ArgumentError.value(profile.age, 'age', 'must be 16..120');
    }
    if (!profile.height.isFinite || profile.height <= 0) {
      throw ArgumentError.value(profile.height, 'height');
    }
    if (!profile.weight.isFinite || profile.weight <= 0) {
      throw ArgumentError.value(profile.weight, 'weight');
    }
    final gender = profile.gender.trim().toLowerCase();
    if (gender != 'male' && gender != 'female') {
      throw ArgumentError.value(profile.gender, 'gender');
    }
  }

  static String _normalizeActivity(String value) => switch (value) {
    'veryActive' => 'very_active',
    _ => value,
  };
}
