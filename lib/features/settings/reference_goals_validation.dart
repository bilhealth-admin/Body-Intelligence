part of 'reference_goals_page.dart';

@visibleForTesting
({String? weeklyGoal, double? startingWeight, String? startingDate})
validateStoredGoalPreferences({
  required String? weeklyGoal,
  required String? startingWeight,
  required String? startingDate,
  required DateTime now,
}) {
  final parsedWeight = double.tryParse(startingWeight ?? '');
  final dateMatch = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})$',
  ).firstMatch(startingDate ?? '');
  final year = int.tryParse(dateMatch?.group(1) ?? '');
  final month = int.tryParse(dateMatch?.group(2) ?? '');
  final day = int.tryParse(dateMatch?.group(3) ?? '');
  final parsedDate = year == null || month == null || day == null
      ? null
      : DateTime(year, month, day);
  final canonicalDate =
      parsedDate != null &&
      parsedDate.year == year &&
      parsedDate.month == month &&
      parsedDate.day == day;
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final validDate = canonicalDate && !parsedDate.isAfter(endOfToday)
      ? '${parsedDate.year.toString().padLeft(4, '0')}-'
            '${parsedDate.month.toString().padLeft(2, '0')}-'
            '${parsedDate.day.toString().padLeft(2, '0')}'
      : null;
  return (
    weeklyGoal: _weeklyOptions.contains(weeklyGoal) ? weeklyGoal : null,
    startingWeight:
        parsedWeight != null &&
            parsedWeight.isFinite &&
            parsedWeight >= 20 &&
            parsedWeight <= 500
        ? parsedWeight
        : null,
    startingDate: validDate,
  );
}

const _weeklyPaceByOption = <String, double>{
  'Lose 0.2 kg per week': -.2,
  'Lose 0.5 kg per week': -.5,
  'Lose 0.8 kg per week': -.8,
  'Lose 1 kg per week': -1,
  'Maintain weight': 0,
  'Gain 0.2 kg per week': .2,
  'Gain 0.5 kg per week': .5,
};

@visibleForTesting
({
  String? weeklyGoal,
  double? weeklyPaceKg,
  double? startingWeight,
  String? startingDate,
})
resolveReferenceGoalPreferences({
  required String? weeklyGoal,
  required String? startingWeight,
  required String? startingDate,
  required String? onboardingPlan,
  required UserProfileData profile,
  required WeightEntry? firstWeight,
  required DateTime now,
}) {
  final manual = validateStoredGoalPreferences(
    weeklyGoal: weeklyGoal,
    startingWeight: startingWeight,
    startingDate: startingDate,
    now: now,
  );
  final fallbackWeight = firstWeight?.weight ?? profile.currentWeight;
  final fallbackDate = firstWeight?.date ?? profile.createdAt;
  final fallback = validateStoredGoalPreferences(
    weeklyGoal: null,
    startingWeight: '$fallbackWeight',
    startingDate:
        firstWeight?.dayKey ??
        '${fallbackDate.year.toString().padLeft(4, '0')}-'
            '${fallbackDate.month.toString().padLeft(2, '0')}-${fallbackDate.day.toString().padLeft(2, '0')}',
    now: now,
  );
  final pace = weeklyGoal == null
      ? NutritionPaceIntent.decode(onboardingPlan).weeklyPaceKg
      : _weeklyPaceByOption[manual.weeklyGoal];
  final option = weeklyGoal == null
      ? _weeklyPaceByOption.entries
            .where((entry) => entry.value == pace)
            .firstOrNull
            ?.key
      : manual.weeklyGoal;
  return (
    weeklyGoal: option,
    weeklyPaceKg: pace,
    startingWeight: startingWeight == null
        ? fallback.startingWeight
        : manual.startingWeight,
    startingDate: startingDate == null
        ? fallback.startingDate
        : manual.startingDate,
  );
}

@visibleForTesting
double? referenceGoalWeightInput(
  String raw,
  MeasurementSystem system, {
  required double initialKg,
  double minKg = 20,
  double maxKg = 500,
}) {
  final value = double.tryParse(raw.trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite) {
    return null;
  }
  final kg = UnitConverter.weightToKg(value, system);
  if (!kg.isFinite || kg < minKg || kg > maxKg) {
    return null;
  }
  // Opening and confirming the rounded display must not slowly alter the
  // original canonical value on repeated metric/imperial visits.
  final initialDisplay = double.parse(
    UnitConverter.weightFromKg(initialKg, system).toStringAsFixed(1),
  );
  return value == initialDisplay && initialKg >= minKg && initialKg <= maxKg
      ? initialKg
      : kg;
}

@visibleForTesting
String referenceGoalWeeklyIntent(String? existing, String option) {
  final pace = _weeklyPaceByOption[option];
  if (pace == null) {
    throw const FormatException('Unsupported weekly goal');
  }
  final Map<String, dynamic> values;
  if (existing == null) {
    values = {'version': 1};
  } else {
    final decoded = jsonDecode(existing);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('Unsupported onboarding intent');
    }
    values = Map<String, dynamic>.from(decoded);
  }
  values['weeklyPaceKg'] = pace;
  return jsonEncode(values);
}

List<String> _weeklyOptionsForDirection(String direction) => _weeklyOptions
    .where((option) {
      final pace = _weeklyPaceByOption[option]!;
      return direction == 'lose' && pace < 0 ||
          direction == 'gain' && pace > 0 ||
          direction == 'maintain' && pace == 0;
    })
    .toList(growable: false);
