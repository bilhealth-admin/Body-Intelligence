import 'dart:convert';

import '../../../data/repositories/nutrition_goal_schedule_repository.dart';

enum DietFatLevel { lighter, medium, richer }

/// The macro the user most recently chose. The allocator preserves this value
/// and rebalances the other two macros inside the fixed calorie target.
enum DietMacroComponent { carbs, protein, fat }

extension DietFatLevelAllocation on DietFatLevel {
  /// Share of the non-carbohydrate calories assigned to fat.
  /// The balance is assigned to protein so total energy remains fixed.
  double get remainingEnergyShare => switch (this) {
    DietFatLevel.lighter => .35,
    DietFatLevel.medium => .50,
    DietFatLevel.richer => .65,
  };
}

class DietMacroTarget {
  const DietMacroTarget({
    required this.calories,
    required this.carbsGrams,
    required this.proteinGrams,
    required this.fatGrams,
  });

  final double calories;
  final double carbsGrams;
  final double proteinGrams;
  final double fatGrams;

  double get calculatedCalories =>
      carbsGrams * 4 + proteinGrams * 4 + fatGrams * 9;

  bool get isValid =>
      calories.isFinite &&
      calories > 0 &&
      carbsGrams.isFinite &&
      proteinGrams.isFinite &&
      fatGrams.isFinite &&
      carbsGrams > 0 &&
      proteinGrams > 0 &&
      fatGrams > 0 &&
      (calculatedCalories - calories).abs() < .0001;

  NutritionGoalTarget toScheduledGoal() {
    final macroEnergy = calculatedCalories;
    return NutritionGoalTarget(
      calories: calories,
      carbsPercent: carbsGrams * 4 / macroEnergy * 100,
      proteinPercent: proteinGrams * 4 / macroEnergy * 100,
      fatPercent: fatGrams * 9 / macroEnergy * 100,
    );
  }
}

abstract final class DietMacroAllocator {
  static DietMacroTarget? allocate({
    required double calories,
    required double carbsGrams,
    required DietFatLevel fatLevel,
  }) {
    if (!calories.isFinite ||
        !carbsGrams.isFinite ||
        calories <= 0 ||
        carbsGrams <= 0) {
      return null;
    }
    final carbohydrateEnergy = carbsGrams * 4;
    final remainingEnergy = calories - carbohydrateEnergy;
    if (remainingEnergy <= 0) return null;
    final fatEnergy = remainingEnergy * fatLevel.remainingEnergyShare;
    final proteinEnergy = remainingEnergy - fatEnergy;
    final target = DietMacroTarget(
      calories: calories,
      carbsGrams: carbsGrams,
      proteinGrams: proteinEnergy / 4,
      fatGrams: fatEnergy / 9,
    );
    return target.isValid ? target : null;
  }

  /// Reconciles a direct user edit without changing the fixed calorie target.
  ///
  /// The edited macro is preserved exactly. The remaining energy is shared by
  /// the other two macros in their current energy ratio. If both are zero, the
  /// pathway's configured fat balance supplies a deterministic starting ratio.
  /// This makes every accepted edit satisfy 4C + 4P + 9F = calories.
  static DietMacroTarget? rebalance({
    required DietMacroTarget current,
    required DietMacroComponent edited,
    required double grams,
    required DietFatLevel fallbackFatLevel,
  }) {
    if (!current.isValid || !grams.isFinite || grams <= 0) return null;
    final editedFactor = edited == DietMacroComponent.fat ? 9.0 : 4.0;
    final editedEnergy = grams * editedFactor;
    if (editedEnergy >= current.calories) return null;
    final remainingEnergy = current.calories - editedEnergy;

    double carbsEnergy = current.carbsGrams * 4;
    double proteinEnergy = current.proteinGrams * 4;
    double fatEnergy = current.fatGrams * 9;

    void splitRemaining(
      double firstWeight,
      double secondWeight,
      void Function(double first, double second) assign,
    ) {
      final total = firstWeight + secondWeight;
      if (total > 0) {
        assign(
          remainingEnergy * firstWeight / total,
          remainingEnergy * secondWeight / total,
        );
        return;
      }
      final fatShare = fallbackFatLevel.remainingEnergyShare;
      assign(remainingEnergy * (1 - fatShare), remainingEnergy * fatShare);
    }

    switch (edited) {
      case DietMacroComponent.carbs:
        carbsEnergy = editedEnergy;
        splitRemaining(proteinEnergy, fatEnergy, (protein, fat) {
          proteinEnergy = protein;
          fatEnergy = fat;
        });
        break;
      case DietMacroComponent.protein:
        proteinEnergy = editedEnergy;
        splitRemaining(carbsEnergy, fatEnergy, (carbs, fat) {
          carbsEnergy = carbs;
          fatEnergy = fat;
        });
        break;
      case DietMacroComponent.fat:
        fatEnergy = editedEnergy;
        splitRemaining(carbsEnergy, proteinEnergy, (carbs, protein) {
          carbsEnergy = carbs;
          proteinEnergy = protein;
        });
        break;
    }

    final target = DietMacroTarget(
      calories: current.calories,
      carbsGrams: carbsEnergy / 4,
      proteinGrams: proteinEnergy / 4,
      fatGrams: fatEnergy / 9,
    );
    return target.isValid ? target : null;
  }

  /// Keeps the user's current distribution when the fixed calorie target is
  /// changed. There is deliberately no artificial calorie floor or ceiling;
  /// any finite positive target can be represented by the macro equation.
  static DietMacroTarget? rescale({
    required DietMacroTarget current,
    required double calories,
  }) {
    if (!current.isValid || !calories.isFinite || calories <= 0) return null;
    final scale = calories / current.calories;
    final target = DietMacroTarget(
      calories: calories,
      carbsGrams: current.carbsGrams * scale,
      proteinGrams: current.proteinGrams * scale,
      fatGrams: current.fatGrams * scale,
    );
    return target.isValid ? target : null;
  }
}

class DietDraft {
  const DietDraft({
    required this.pathwayId,
    required this.calories,
    required this.fatLevel,
    required this.carbsByWeekday,
    this.proteinByWeekday = const {},
    this.fatByWeekday = const {},
    this.pregnancyTrimester,
    this.prePregnancyCalories,
  });

  final String pathwayId;
  final double calories;
  final DietFatLevel fatLevel;
  final Map<int, double> carbsByWeekday;
  final Map<int, double> proteinByWeekday;
  final Map<int, double> fatByWeekday;
  final int? pregnancyTrimester;
  final double? prePregnancyCalories;

  Map<int, DietMacroTarget>? resolveWeek() {
    final targets = <int, DietMacroTarget>{};
    for (var weekday = 1; weekday <= 7; weekday += 1) {
      final carbs = carbsByWeekday[weekday];
      if (carbs == null) return null;
      final protein = proteinByWeekday[weekday];
      final fat = fatByWeekday[weekday];
      final target = protein == null && fat == null
          ? DietMacroAllocator.allocate(
              calories: calories,
              carbsGrams: carbs,
              fatLevel: fatLevel,
            )
          : protein != null && fat != null
          ? DietMacroTarget(
              calories: calories,
              carbsGrams: carbs,
              proteinGrams: protein,
              fatGrams: fat,
            )
          : null;
      if (target == null) return null;
      if (!target.isValid) return null;
      targets[weekday] = target;
    }
    return targets;
  }

  Map<String, Object?> toJson() => {
    'pathwayId': pathwayId,
    'calories': calories,
    'fatLevel': fatLevel.name,
    'carbsByWeekday': carbsByWeekday.map(
      (key, value) => MapEntry('$key', value),
    ),
    'proteinByWeekday': proteinByWeekday.map(
      (key, value) => MapEntry('$key', value),
    ),
    'fatByWeekday': fatByWeekday.map((key, value) => MapEntry('$key', value)),
    'pregnancyTrimester': pregnancyTrimester,
    'prePregnancyCalories': prePregnancyCalories,
  };

  String encode() => jsonEncode(toJson());

  static DietDraft? decode(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    try {
      final value = jsonDecode(source);
      if (value is! Map) return null;
      Map<int, double>? decodeDays(Object? source, {required bool required}) {
        if (source == null && !required) return <int, double>{};
        if (source is! Map) return null;
        final days = <int, double>{};
        for (final entry in source.entries) {
          final day = int.tryParse('${entry.key}');
          final grams = (entry.value as num?)?.toDouble();
          if (day != null && day >= 1 && day <= 7 && grams != null) {
            days[day] = grams;
          }
        }
        return days;
      }

      final days = decodeDays(value['carbsByWeekday'], required: true);
      final proteinDays = decodeDays(
        value['proteinByWeekday'],
        required: false,
      );
      final fatDays = decodeDays(value['fatByWeekday'], required: false);
      if (days == null || proteinDays == null || fatDays == null) return null;
      final fatName = '${value['fatLevel'] ?? ''}';
      final draft = DietDraft(
        pathwayId: '${value['pathwayId'] ?? ''}',
        calories: (value['calories'] as num?)?.toDouble() ?? 0,
        fatLevel: DietFatLevel.values.firstWhere(
          (candidate) => candidate.name == fatName,
          orElse: () => DietFatLevel.medium,
        ),
        carbsByWeekday: days,
        proteinByWeekday: proteinDays,
        fatByWeekday: fatDays,
        pregnancyTrimester: (value['pregnancyTrimester'] as num?)?.toInt(),
        prePregnancyCalories: (value['prePregnancyCalories'] as num?)
            ?.toDouble(),
      );
      return draft.resolveWeek() == null ? null : draft;
    } on FormatException {
      return null;
    }
  }
}

class DietPreset {
  const DietPreset({
    required this.pathwayId,
    required this.calories,
    required this.fatLevel,
    required this.carbsByWeekday,
  });

  final String pathwayId;
  final double calories;
  final DietFatLevel fatLevel;
  final Map<int, double> carbsByWeekday;

  DietDraft toDraft() => DietDraft(
    pathwayId: pathwayId,
    calories: calories,
    fatLevel: fatLevel,
    carbsByWeekday: Map<int, double>.of(carbsByWeekday),
    pregnancyTrimester: pathwayId == 'pregnancy' ? 1 : null,
    prePregnancyCalories: pathwayId == 'pregnancy' ? calories : null,
  );
}

Map<int, double> uniformWeeklyCarbs(double grams) => {
  for (var day = 1; day <= 7; day += 1) day: grams,
};

abstract final class PregnancyNutritionGuidance {
  static const extraCaloriesByTrimester = <int, double>{1: 0, 2: 340, 3: 452};
  static const ironSupplementMilligrams = (30.0, 60.0);
  static const folicAcidSupplementMicrograms = 400.0;
  static const iodineMicrograms = 250.0;
  static const calciumLowIntakeMilligrams = (1500.0, 2000.0);

  static DietDraft forTrimester({
    required double prePregnancyCalories,
    required int trimester,
  }) {
    final extra = extraCaloriesByTrimester[trimester];
    if (extra == null ||
        !prePregnancyCalories.isFinite ||
        prePregnancyCalories <= 0) {
      throw ArgumentError('Invalid pregnancy nutrition inputs.');
    }
    final calories = prePregnancyCalories + extra;
    final carbs = calories * .50 / 4;
    return DietDraft(
      pathwayId: 'pregnancy',
      calories: calories,
      fatLevel: DietFatLevel.medium,
      carbsByWeekday: uniformWeeklyCarbs(carbs),
      pregnancyTrimester: trimester,
      prePregnancyCalories: prePregnancyCalories,
    );
  }
}
