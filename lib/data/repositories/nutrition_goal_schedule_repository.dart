import 'dart:convert';

import 'preferences_repository.dart';

const nutritionGoalSchedulePreferenceKey = 'goals.nutritionSchedule.v1';

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

  Map<String, Object> toJson() => {
    'calories': calories,
    'carbsPercent': carbsPercent,
    'proteinPercent': proteinPercent,
    'fatPercent': fatPercent,
  };

  static NutritionGoalTarget? fromJson(Object? value) {
    if (value is! Map) return null;
    double? number(String key) => (value[key] as num?)?.toDouble();
    final target = NutritionGoalTarget(
      calories: number('calories') ?? 0,
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

class NutritionGoalSchedule {
  const NutritionGoalSchedule({
    this.dayTargets = const {},
    this.mealTargets = const {},
  });

  final Map<int, NutritionGoalTarget> dayTargets;
  final Map<String, NutritionGoalTarget> mealTargets;

  NutritionGoalTarget? targetFor(DateTime date) => dayTargets[date.weekday];

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
    final current = await read();
    final days = Map<int, NutritionGoalTarget>.of(current.dayTargets);
    target == null ? days.remove(weekday) : days[weekday] = target;
    await _write(
      NutritionGoalSchedule(dayTargets: days, mealTargets: current.mealTargets),
    );
  }

  Future<void> saveMeal(String mealType, NutritionGoalTarget? target) async {
    if (!_mealTypes.contains(mealType)) throw ArgumentError.value(mealType);
    if (target != null && !target.isValid) throw ArgumentError.value(target);
    final current = await read();
    final meals = Map<String, NutritionGoalTarget>.of(current.mealTargets);
    target == null ? meals.remove(mealType) : meals[mealType] = target;
    await _write(
      NutritionGoalSchedule(dayTargets: current.dayTargets, mealTargets: meals),
    );
  }

  Future<void> replaceDayTargets(Map<int, NutritionGoalTarget> targets) async {
    if (targets.keys.any((day) => day < 1 || day > 7) ||
        targets.values.any((target) => !target.isValid)) {
      throw ArgumentError.value(targets);
    }
    final current = await read();
    await _write(
      NutritionGoalSchedule(
        dayTargets: Map<int, NutritionGoalTarget>.of(targets),
        mealTargets: current.mealTargets,
      ),
    );
  }

  Future<void> _write(NutritionGoalSchedule value) => _preferences.set(
    nutritionGoalSchedulePreferenceKey,
    jsonEncode(value.toJson()),
  );
}
