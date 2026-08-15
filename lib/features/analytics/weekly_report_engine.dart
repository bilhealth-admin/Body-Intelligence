import 'dart:collection';

final class WeeklyNutritionObservation {
  const WeeklyNutritionObservation({
    required this.dayKey,
    required this.calories,
    required this.proteinG,
    this.carbsG = 0,
    this.fatG = 0,
    required this.sodiumMg,
    this.foodCategory,
    this.foodName,
  });
  final String dayKey;
  final double calories, proteinG, carbsG, fatG, sodiumMg;
  final String? foodCategory;
  final String? foodName;
}

final class WeeklyWaterObservation {
  const WeeklyWaterObservation({required this.dayKey, required this.amountMl});
  final String dayKey;
  final int amountMl;
}

final class WeeklyWeightObservation {
  const WeeklyWeightObservation({
    required this.dayKey,
    required this.observedAt,
    required this.weightKg,
  });
  final String dayKey;
  final DateTime observedAt;
  final double weightKg;
}

final class WeeklyActivityObservation {
  const WeeklyActivityObservation({
    required this.dayKey,
    this.steps,
    this.exerciseNotes,
  });
  final String dayKey;
  final int? steps;
  final String? exerciseNotes;
  bool get hasExercise => exerciseNotes?.trim().isNotEmpty == true;
}

final class WeeklyReportDay {
  const WeeklyReportDay({
    required this.dayKey,
    required this.hasNutrition,
    required this.hasWater,
    required this.hasWeight,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.sodiumMg,
    required this.waterMl,
    this.steps,
  });
  final String dayKey;
  final bool hasNutrition, hasWater, hasWeight;
  final double calories, proteinG, carbsG, fatG, sodiumMg;
  final int waterMl;
  final int? steps;
  bool get hasAnyRecord =>
      hasNutrition || hasWater || hasWeight || steps != null;
}

enum WeeklyReportConfidence { insufficient, low, medium, high }

final class WeeklyReportSnapshot {
  WeeklyReportSnapshot({
    required Iterable<WeeklyReportDay> days,
    required this.mealCount,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.totalSodiumMg,
    required this.totalWaterMl,
    required this.latestWeightKg,
    required this.weightDirectionKg,
    required this.confidence,
    required Iterable<String> sources,
    required Iterable<String> limitations,
    Map<String, int> foodCategoryCounts = const {},
    this.totalSteps,
    this.exerciseDays = 0,
    this.allTimeMealCount = 0,
    this.allTimeFoodCount = 0,
    this.allTimeWeightCount = 0,
    this.allTimeExerciseDays = 0,
    this.allTimeSteps,
    this.dailyCalorieGoal,
    this.loggingStreakDays = 0,
    Map<String, int> frequentFoods = const {},
  }) : days = UnmodifiableListView(days),
       sources = UnmodifiableListView(sources),
       limitations = UnmodifiableListView(limitations),
       foodCategoryCounts = Map.unmodifiable(foodCategoryCounts),
       frequentFoods = Map.unmodifiable(frequentFoods);
  final List<WeeklyReportDay> days;
  final int mealCount;
  final double totalCalories,
      totalProteinG,
      totalCarbsG,
      totalFatG,
      totalSodiumMg;
  final int? totalSteps, allTimeSteps;
  final int? dailyCalorieGoal;
  final int exerciseDays,
      allTimeFoodCount,
      allTimeMealCount,
      allTimeWeightCount,
      allTimeExerciseDays;
  final int loggingStreakDays;
  final int totalWaterMl;
  final double? latestWeightKg, weightDirectionKg;
  final WeeklyReportConfidence confidence;
  final List<String> sources, limitations;
  final Map<String, int> foodCategoryCounts;
  final Map<String, int> frequentFoods;
  int get trackedDays => days.where((day) => day.hasAnyRecord).length;
  int get missingDays => days.length - trackedDays;
  bool get isEmpty => trackedDays == 0;
}

/// Builds a seven-day report from saved observations only. Missing days remain
/// explicitly missing; the engine never estimates intake or tissue change.
final class WeeklyReportEngine {
  const WeeklyReportEngine();

  WeeklyReportSnapshot build({
    required DateTime asOf,
    required Iterable<WeeklyNutritionObservation> nutrition,
    required Iterable<WeeklyWaterObservation> water,
    required Iterable<WeeklyWeightObservation> weights,
    Iterable<WeeklyActivityObservation> activity = const [],
    required int mealCount,
    int allTimeMealCount = 0,
    int allTimeFoodCount = 0,
    int allTimeWeightCount = 0,
    int allTimeExerciseDays = 0,
    int? allTimeSteps,
    int? dailyCalorieGoal,
    int loggingStreakDays = 0,
  }) {
    if (mealCount < 0) {
      throw ArgumentError.value(mealCount, 'mealCount');
    }
    final end = DateTime.utc(asOf.year, asOf.month, asOf.day);
    final start = end.subtract(const Duration(days: 6));
    final keys = [
      for (var offset = 0; offset < 7; offset++)
        _key(start.add(Duration(days: offset))),
    ];
    final allowed = keys.toSet();
    final nutritionByDay = <String, List<WeeklyNutritionObservation>>{};
    final foodCategoryCounts = <String, int>{};
    final foodCounts = <String, int>{};
    for (final row in nutrition) {
      _finite(row.calories, 'calories');
      _finite(row.proteinG, 'proteinG');
      _finite(row.carbsG, 'carbsG');
      _finite(row.fatG, 'fatG');
      _finite(row.sodiumMg, 'sodiumMg');
      if (row.calories < 0 ||
          row.proteinG < 0 ||
          row.carbsG < 0 ||
          row.fatG < 0 ||
          row.sodiumMg < 0) {
        throw ArgumentError('Nutrition observations cannot be negative.');
      }
      if (allowed.contains(row.dayKey)) {
        nutritionByDay.putIfAbsent(row.dayKey, () => []).add(row);
        final category = row.foodCategory?.trim().toLowerCase();
        if (category != null && category.isNotEmpty) {
          foodCategoryCounts.update(
            category,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
        final foodName = row.foodName?.trim();
        if (foodName != null && foodName.isNotEmpty) {
          foodCounts.update(foodName, (value) => value + 1, ifAbsent: () => 1);
        }
      }
    }
    final waterByDay = <String, int>{};
    for (final row in water) {
      if (row.amountMl <= 0 || row.amountMl > 5000) {
        throw ArgumentError.value(row.amountMl, 'amountMl');
      }
      if (allowed.contains(row.dayKey)) {
        waterByDay.update(
          row.dayKey,
          (value) => value + row.amountMl,
          ifAbsent: () => row.amountMl,
        );
      }
    }
    final validWeights = <WeeklyWeightObservation>[];
    for (final row in weights) {
      _finite(row.weightKg, 'weightKg');
      if (row.weightKg < 20 || row.weightKg > 500) {
        throw ArgumentError.value(row.weightKg, 'weightKg');
      }
      if (allowed.contains(row.dayKey)) {
        validWeights.add(row);
      }
    }
    validWeights.sort((a, b) => a.observedAt.compareTo(b.observedAt));
    final weightKeys = validWeights.map((row) => row.dayKey).toSet();
    final activityByDay = {
      for (final row in activity.where((row) => allowed.contains(row.dayKey)))
        row.dayKey: row,
    };
    final days = <WeeklyReportDay>[];
    for (final key in keys) {
      final nutrients = nutritionByDay[key] ?? const [];
      days.add(
        WeeklyReportDay(
          dayKey: key,
          hasNutrition: nutrients.isNotEmpty,
          hasWater: waterByDay.containsKey(key),
          hasWeight: weightKeys.contains(key),
          calories: nutrients.fold(0, (sum, row) => sum + row.calories),
          proteinG: nutrients.fold(0, (sum, row) => sum + row.proteinG),
          carbsG: nutrients.fold(0, (sum, row) => sum + row.carbsG),
          fatG: nutrients.fold(0, (sum, row) => sum + row.fatG),
          sodiumMg: nutrients.fold(0, (sum, row) => sum + row.sodiumMg),
          waterMl: waterByDay[key] ?? 0,
          steps: activityByDay[key]?.steps,
        ),
      );
    }
    final tracked = days.where((day) => day.hasAnyRecord).length;
    final nutritionDays = days.where((day) => day.hasNutrition).length;
    final confidence = switch ((tracked, nutritionDays, validWeights.length)) {
      (0, _, _) || (_, 0, 0) => WeeklyReportConfidence.insufficient,
      (< 4, _, _) => WeeklyReportConfidence.low,
      (_, >= 5, >= 2) => WeeklyReportConfidence.high,
      _ => WeeklyReportConfidence.medium,
    };
    return WeeklyReportSnapshot(
      days: days,
      mealCount: mealCount,
      totalCalories: days.fold(0, (sum, day) => sum + day.calories),
      totalProteinG: days.fold(0, (sum, day) => sum + day.proteinG),
      totalCarbsG: days.fold(0, (sum, day) => sum + day.carbsG),
      totalFatG: days.fold(0, (sum, day) => sum + day.fatG),
      totalSodiumMg: days.fold(0, (sum, day) => sum + day.sodiumMg),
      totalWaterMl: days.fold(0, (sum, day) => sum + day.waterMl),
      latestWeightKg: validWeights.isEmpty ? null : validWeights.last.weightKg,
      weightDirectionKg: validWeights.length < 2
          ? null
          : validWeights.last.weightKg - validWeights.first.weightKg,
      confidence: confidence,
      sources: const [
        'local.meals+meal_items',
        'local.water_entries',
        'local.weight_entries',
      ],
      limitations: [
        if (tracked < 7) '${7 - tracked} day(s) have no saved records.',
        if (nutritionDays < 5)
          'Nutrition coverage is incomplete; totals describe logged food only.',
        if (validWeights.length < 2)
          'At least two measured weights are required for a direction.',
        'Weight direction alone cannot identify fat or muscle change.',
        'This report is informational and is not a medical diagnosis.',
      ],
      foodCategoryCounts: Map.unmodifiable(foodCategoryCounts),
      totalSteps: activityByDay.values.any((row) => row.steps != null)
          ? activityByDay.values.fold<int>(
              0,
              (sum, row) => sum + (row.steps ?? 0),
            )
          : null,
      exerciseDays: activityByDay.values.where((row) => row.hasExercise).length,
      allTimeMealCount: allTimeMealCount,
      allTimeFoodCount: allTimeFoodCount,
      allTimeWeightCount: allTimeWeightCount,
      allTimeExerciseDays: allTimeExerciseDays,
      allTimeSteps: allTimeSteps,
      dailyCalorieGoal: dailyCalorieGoal,
      loggingStreakDays: loggingStreakDays,
      frequentFoods: Map.fromEntries(
        (foodCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(5),
      ),
    );
  }

  static void _finite(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'must be finite');
    }
  }

  static String _key(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
  }
}
