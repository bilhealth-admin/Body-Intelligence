import 'dart:convert';

import 'preferences_repository.dart';

const nutritionGoalSchedulePreferenceKey = 'goals.nutritionSchedule.v1';

const defaultNutritionGoalPreferenceKeys = <String>[
  'goal.calories',
  'goal.carbsPercent',
  'goal.proteinPercent',
  'goal.fatPercent',
  'goal.carbsGrams',
  'goal.proteinGrams',
  'goal.fatGrams',
];

class NutritionGoalTarget {
  const NutritionGoalTarget({
    required this.calories,
    required this.carbsPercent,
    required this.proteinPercent,
    required this.fatPercent,
  });

  final double calories;
  final double carbsPercent;
  final double proteinPercent;
  final double fatPercent;

  /// Builds a target from the units shown to users in the schedule editor.
  /// Macro energy must agree with [calories] so the stored target cannot drift
  /// between the schedule, dashboard, and meal rows.
  factory NutritionGoalTarget.fromGrams({
    required double calories,
    required double carbsGrams,
    required double proteinGrams,
    required double fatGrams,
  }) {
    final values = [calories, carbsGrams, proteinGrams, fatGrams];
    if (!values.every((value) => value.isFinite && value >= 0) ||
        calories <= 0) {
      throw ArgumentError('Calories and macro grams must be valid.');
    }
    final macroCalories = carbsGrams * 4 + proteinGrams * 4 + fatGrams * 9;
    if (macroCalories <= 0 || (macroCalories - calories).abs() > 0.5) {
      throw ArgumentError(
        'Macro grams must provide the selected calorie goal.',
      );
    }
    return NutritionGoalTarget(
      calories: calories,
      carbsPercent: carbsGrams * 4 / calories * 100,
      proteinPercent: proteinGrams * 4 / calories * 100,
      fatPercent: fatGrams * 9 / calories * 100,
    );
  }

  double get carbsGrams => calories * carbsPercent / 400;
  double get proteinGrams => calories * proteinPercent / 400;
  double get fatGrams => calories * fatPercent / 900;

  Map<String, Object> toJson() => {
    'calories': calories,
    'carbsPercent': carbsPercent,
    'proteinPercent': proteinPercent,
    'fatPercent': fatPercent,
    'carbsGrams': carbsGrams,
    'proteinGrams': proteinGrams,
    'fatGrams': fatGrams,
  };

  static NutritionGoalTarget? fromJson(Object? value) {
    if (value is! Map) return null;
    double? number(String key) {
      final raw = value[key];
      if (raw is num) return raw.toDouble();
      if (raw is String) return double.tryParse(raw.trim());
      return null;
    }

    final calories = number('calories') ?? 0;
    final carbsGrams = number('carbsGrams');
    final proteinGrams = number('proteinGrams');
    final fatGrams = number('fatGrams');
    if (carbsGrams != null && proteinGrams != null && fatGrams != null) {
      try {
        final target = NutritionGoalTarget.fromGrams(
          calories: calories,
          carbsGrams: carbsGrams,
          proteinGrams: proteinGrams,
          fatGrams: fatGrams,
        );
        if (target.isValid) return target;
      } on ArgumentError {
        // Fall through to the legacy percentage representation.
      }
    }
    final target = NutritionGoalTarget(
      calories: calories,
      carbsPercent: number('carbsPercent') ?? 0,
      proteinPercent: number('proteinPercent') ?? 0,
      fatPercent: number('fatPercent') ?? 0,
    );
    return target.isValid ? target : null;
  }

  bool get isValid =>
      calories.isFinite &&
      calories > 0 &&
      carbsPercent.isFinite &&
      proteinPercent.isFinite &&
      fatPercent.isFinite &&
      carbsPercent >= 0 &&
      proteinPercent >= 0 &&
      fatPercent >= 0 &&
      (carbsPercent + proteinPercent + fatPercent - 100).abs() < 0.01;
}

/// Rebuilds the user's default target from the atomic preference snapshot.
///
/// Gram values are authoritative when all three are present and agree with
/// calories. Older installs that only persisted percentages remain supported.
NutritionGoalTarget? defaultNutritionGoalTargetFromPreferences(
  Map<String, String?> values,
) {
  double? number(String key) {
    final parsed = double.tryParse(values[key]?.trim() ?? '');
    return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
  }

  final calories = number('goal.calories');
  if (calories == null || calories <= 0) return null;

  final carbsGrams = number('goal.carbsGrams');
  final proteinGrams = number('goal.proteinGrams');
  final fatGrams = number('goal.fatGrams');
  if (carbsGrams != null && proteinGrams != null && fatGrams != null) {
    try {
      return NutritionGoalTarget.fromGrams(
        calories: calories,
        carbsGrams: carbsGrams,
        proteinGrams: proteinGrams,
        fatGrams: fatGrams,
      );
    } on ArgumentError {
      // A stale or partially migrated gram snapshot must not hide a valid
      // legacy percentage target below.
    }
  }

  final target = NutritionGoalTarget(
    calories: calories,
    carbsPercent: number('goal.carbsPercent') ?? double.nan,
    proteinPercent: number('goal.proteinPercent') ?? double.nan,
    fatPercent: number('goal.fatPercent') ?? double.nan,
  );
  return target.isValid ? target : null;
}

class NutritionGoalSchedule {
  const NutritionGoalSchedule({
    this.dayTargets = const {},
    this.mealTargets = const {},
  });

  final Map<int, NutritionGoalTarget> dayTargets;
  final Map<String, NutritionGoalTarget> mealTargets;

  /// Resolves a weekly target for the caller's local civil day.
  ///
  /// Callers intentionally pass the local day used by their UI rather than a
  /// UTC instant. This keeps Sunday/Monday and daylight-saving boundaries
  /// deterministic without storing a device time-zone assumption in the
  /// schedule itself.
  NutritionGoalTarget? targetFor(DateTime localDay) =>
      dayTargets[localDay.weekday];

  Map<String, Object> toJson() => {
    'days': dayTargets.map((key, value) => MapEntry('$key', value.toJson())),
    'meals': mealTargets.map((key, value) => MapEntry(key, value.toJson())),
  };

  static NutritionGoalSchedule decode(String? source) {
    if (source == null || source.trim().isEmpty) {
      return const NutritionGoalSchedule();
    }
    try {
      final root = jsonDecode(source);
      if (root is! Map) return const NutritionGoalSchedule();
      final days = <int, NutritionGoalTarget>{};
      final rawDays = root['days'];
      if (rawDays is Map) {
        for (final entry in rawDays.entries) {
          final day = int.tryParse('${entry.key}');
          final target = NutritionGoalTarget.fromJson(entry.value);
          if (day != null && day >= 1 && day <= 7 && target != null) {
            days[day] = target;
          }
        }
      }
      final meals = <String, NutritionGoalTarget>{};
      final rawMeals = root['meals'];
      if (rawMeals is Map) {
        for (final entry in rawMeals.entries) {
          final key = '${entry.key}';
          final target = NutritionGoalTarget.fromJson(entry.value);
          if (_mealTypes.contains(key) && target != null) meals[key] = target;
        }
      }
      return NutritionGoalSchedule(dayTargets: days, mealTargets: meals);
    } on FormatException {
      return const NutritionGoalSchedule();
    }
  }
}

NutritionGoalTarget? resolveDailyNutritionGoal({
  required NutritionGoalSchedule schedule,
  required DateTime date,
  required NutritionGoalTarget? defaultGoal,
}) => schedule.targetFor(date) ?? defaultGoal;

const _mealTypes = {'breakfast', 'lunch', 'dinner', 'snack'};

class NutritionGoalScheduleRepository {
  NutritionGoalScheduleRepository(this._preferences);

  final PreferencesRepository _preferences;

  Future<NutritionGoalSchedule> read() async => NutritionGoalSchedule.decode(
    await _preferences.get(nutritionGoalSchedulePreferenceKey),
  );

  Stream<NutritionGoalSchedule> watch() => _preferences
      .watch(nutritionGoalSchedulePreferenceKey)
      .map(NutritionGoalSchedule.decode);

  Future<void> saveDay(int weekday, NutritionGoalTarget? target) async {
    if (weekday < 1 || weekday > 7) throw ArgumentError.value(weekday);
    if (target != null && !target.isValid) throw ArgumentError.value(target);
    await _mutate((current) {
      final days = Map<int, NutritionGoalTarget>.of(current.dayTargets);
      target == null ? days.remove(weekday) : days[weekday] = target;
      return NutritionGoalSchedule(
        dayTargets: days,
        mealTargets: current.mealTargets,
      );
    });
  }

  Future<void> saveMeal(String mealType, NutritionGoalTarget? target) async {
    if (!_mealTypes.contains(mealType)) throw ArgumentError.value(mealType);
    if (target != null && !target.isValid) throw ArgumentError.value(target);
    await _mutate((current) {
      final meals = Map<String, NutritionGoalTarget>.of(current.mealTargets);
      target == null ? meals.remove(mealType) : meals[mealType] = target;
      return NutritionGoalSchedule(
        dayTargets: current.dayTargets,
        mealTargets: meals,
      );
    });
  }

  Future<void> replaceDayTargets(Map<int, NutritionGoalTarget> targets) async {
    if (targets.keys.any((day) => day < 1 || day > 7) ||
        targets.values.any((target) => !target.isValid)) {
      throw ArgumentError.value(targets);
    }
    await _mutate(
      (current) => NutritionGoalSchedule(
        dayTargets: Map<int, NutritionGoalTarget>.of(targets),
        mealTargets: current.mealTargets,
      ),
    );
  }

  Future<void> _mutate(
    NutritionGoalSchedule Function(NutritionGoalSchedule current) derive,
  ) async {
    await _preferences.update(nutritionGoalSchedulePreferenceKey, (source) {
      final next = derive(NutritionGoalSchedule.decode(source));
      return jsonEncode(next.toJson());
    });
  }
}
