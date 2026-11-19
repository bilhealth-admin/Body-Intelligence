import 'dart:convert';

/// Persisted onboarding intent, rather than a frozen calorie recommendation.
/// Missing legacy data is different from an unreadable selected pace.
final class NutritionPaceIntent {
  const NutritionPaceIntent._(this.weeklyPaceKg);

  static const storageKey = 'onboarding.plan.v1';
  final double? weeklyPaceKg;

  @override
  bool operator ==(Object other) =>
      other is NutritionPaceIntent && other.weeklyPaceKg == weeklyPaceKg;

  @override
  int get hashCode => weeklyPaceKg.hashCode;

  static NutritionPaceIntent decode(String? raw) {
    if (raw == null) return const NutritionPaceIntent._(null);
    final data = jsonDecode(raw);
    if (data is! Map || data['version'] != 1) {
      throw const FormatException('Unsupported onboarding pace');
    }
    final pace = data['weeklyPaceKg'];
    if (pace is! num || !pace.isFinite || pace < -1 || pace > .5) {
      throw const FormatException('Invalid onboarding pace');
    }
    return NutritionPaceIntent._(pace.toDouble());
  }

  /// A changed goal direction retires the old direction's selected pace.
  /// Current weight/activity still determine TDEE; the existing floor remains.
  ({int calories, int fats})? targetsFor({
    required double tdee,
    required String goalType,
  }) {
    final pace = weeklyPaceKg;
    if (pace == null ||
        !(goalType == 'lose' && pace < 0 ||
            goalType == 'gain' && pace > 0 ||
            goalType == 'maintain' && pace == 0)) {
      return null;
    }
    final calculated = (tdee + pace * 7700 / DateTime.daysPerWeek).round();
    final calories = calculated < 1200 ? 1200 : calculated;
    return (calories: calories, fats: (calories * .30 / 9).round());
  }
}
