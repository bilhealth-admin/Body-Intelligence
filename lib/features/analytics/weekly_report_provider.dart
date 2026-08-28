import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../data/database/date_keys.dart';
import '../../data/database/app_database.dart';
import '../../engine/body_profile.dart';
import '../../engine/plan_engine.dart';
import '../dashboard/providers/dashboard_provider.dart';
import '../dashboard/providers/dashboard_preferences_provider.dart';
import '../daily_log/providers/daily_log_provider.dart';
import '../daily_log/domain/daily_body_context_codec.dart';
import '../connected_health/providers/connected_health_provider.dart';
import '../exercise_calorie_controls/providers/exercise_calorie_providers.dart';
import '../nutrition/domain/percentage_nutrition_goals.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import '../wellness/domain/fasting_session.dart';
import 'weekly_report_engine.dart';

final weeklyReportClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final accountCreatedAtProvider = Provider<DateTime?>((ref) {
  // Weekly reports are local-first and must render before optional cloud
  // initialization completes (and in tests/local-only builds where it never
  // starts). Accessing Supabase.instance before that boundary asserts.
  if (!AppEnvironment.supabaseRuntimeReady) return null;
  final supabase = Supabase.instance;
  return DateTime.tryParse(supabase.client.auth.currentUser?.createdAt ?? '');
});

/// End date of the seven-day report window. Users may inspect any historical
/// week; future windows are never selected by the UI.
final selectedWeeklyReportDateProvider = StateProvider<DateTime>(
  (ref) => ref.watch(weeklyReportClockProvider)(),
);

/// Presentation controller for the measured weekly report.
///
/// Repository-backed streams are the only inputs. Their loading/error states
/// flow through this provider, while calculation remains deterministic and
/// offline in [WeeklyReportEngine].
final weeklyReportProvider = FutureProvider.autoDispose<WeeklyReportSnapshot>((
  ref,
) async {
  final meals = await ref.watch(allMealsProvider.future);
  final water = await ref.watch(allWaterProvider.future);
  final weights = await ref.watch(weightHistoryProvider.future);
  final latestWeight = await ref.watch(latestWeightProvider.future);
  final bodyMeasurements = await ref.watch(
    bodyMeasurementHistoryProvider.future,
  );
  final dailyLogs = await ref.watch(dailyLogRepositoryProvider).getAll();
  final connectedHealth = ref.watch(connectedHealthProvider).value;
  final profile = await ref.watch(userProfileProvider.future);
  final activeGoal = await ref.watch(activeGoalProvider.future);
  final plan = profile == null
      ? null
      : await ref.watch(planSettingProvider(profile.uuid).future);
  final goalSchedule = await ref.watch(nutritionGoalScheduleProvider.future);
  Future<double?> savedGoal(String key) =>
      ref.watch(dashboardNutrientGoalProvider(key).future);
  final savedCalorieGoal = await savedGoal('goal.calories');
  final savedCarbsPercent = await savedGoal('goal.carbsPercent');
  final savedProteinPercent = await savedGoal('goal.proteinPercent');
  final savedFatPercent = await savedGoal('goal.fatPercent');
  final savedPercentageGoals = PercentageNutritionGoals.resolve(
    calories: savedCalorieGoal ?? 0,
    carbohydratesPercent: savedCarbsPercent ?? 0,
    proteinPercent: savedProteinPercent ?? 0,
    fatPercent: savedFatPercent ?? 0,
  );
  final asOf = ref.watch(selectedWeeklyReportDateProvider);
  final cutoff = asOf.subtract(const Duration(days: 6));
  bool recent(DateTime value) =>
      dayKeyFor(value).compareTo(dayKeyFor(cutoff)) >= 0 &&
      dayKeyFor(value).compareTo(dayKeyFor(asOf)) <= 0;
  final weekMeals = meals.where((entry) => recent(entry.meal.date)).toList();
  final recommendedCalorieGoal = profile == null
      ? null
      : PlanEngine.recommend(
          BodyProfile(
            age: profile.age,
            gender: profile.gender,
            height: profile.height,
            weight: latestWeight?.weight ?? profile.currentWeight,
            targetWeight: profile.targetWeight,
            activityLevel: profile.activityLevel,
            exercises: profile.exercises,
            goalType: activeGoal?.type ?? 'maintain',
            waistCm: bodyMeasurements.firstOrNull?.waistCm ?? profile.waist,
            neckCm: bodyMeasurements.firstOrNull?.neckCm ?? profile.neck,
            hipCm: bodyMeasurements.firstOrNull?.hipsCm,
          ),
        ).targets.calories.toDouble();
  final fallbackCalorieGoal =
      savedPercentageGoals?.calories ??
      plan?.overrideCalories?.toDouble() ??
      recommendedCalorieGoal;
  final reportEnd = DateTime(asOf.year, asOf.month, asOf.day);
  final reportDays = [
    for (var offset = 0; offset < 7; offset++)
      reportEnd.subtract(Duration(days: offset)),
  ];
  final dailyLogsByDay = {
    for (final entry in dailyLogs.where((entry) => recent(entry.date)))
      entry.dayKey: entry,
  };
  final sleepByDay = <String, WeeklySleepObservation>{};
  for (final entry in dailyLogsByDay.values) {
    final hours = entry.sleepHours;
    if (hours != null && hours.isFinite && hours > 0 && hours <= 24) {
      sleepByDay[entry.dayKey] = WeeklySleepObservation(
        dayKey: entry.dayKey,
        hours: hours,
        observedAt: entry.date,
      );
    }
  }
  if (connectedHealth?.deviceVerified == true) {
    for (final signal in connectedHealth!.signals.where(
      (signal) => signal.key == 'sleep' && signal.unit == 'h',
    )) {
      final day = _connectedSleepDay(signal.observedAt, signal.attributes);
      final key = dayKeyFor(day);
      if (!recent(day) ||
          !signal.value.isFinite ||
          signal.value <= 0 ||
          signal.value > 24) {
        continue;
      }
      final candidate = WeeklySleepObservation(
        dayKey: key,
        hours: signal.value,
        observedAt: signal.observedAt,
        deviceVerified: true,
      );
      final current = sleepByDay[key];
      if (current == null ||
          !current.deviceVerified ||
          candidate.observedAt.isAfter(current.observedAt)) {
        sleepByDay[key] = candidate;
      }
    }
  }
  final preferences = ref.watch(preferencesRepositoryProvider);
  final fastingHistory = FastingHistoryCodec.decode(
    await preferences.get('wellness_fasting_history_v1'),
  );
  final weeklyActivity = <WeeklyActivityObservation>[
    for (final day in reportDays)
      if (dailyLogsByDay[dayKeyFor(day)] != null ||
          authoritativeExerciseEnergyForDay(connectedHealth, day) != null)
        WeeklyActivityObservation(
          dayKey: dayKeyFor(day),
          steps: dailyLogsByDay[dayKeyFor(day)]?.steps,
          exerciseNotes: dailyLogsByDay[dayKeyFor(day)]?.exerciseNotes,
          estimatedBurnedCaloriesKcal: estimatedExerciseCaloriesFromNotes(
            dailyLogsByDay[dayKeyFor(day)]?.exerciseNotes,
          ),
          verifiedActiveEnergyKcal: authoritativeExerciseEnergyForDay(
            connectedHealth,
            day,
          )?.kcal,
        ),
  ];
  final calorieGoalsByDay = <String, double>{};
  for (var offset = 0; offset < 7; offset++) {
    final day = reportEnd.subtract(Duration(days: offset));
    final goal = goalSchedule.targetFor(day)?.calories ?? fallbackCalorieGoal;
    if (goal != null) calorieGoalsByDay[dayKeyFor(day)] = goal;
  }
  return const WeeklyReportEngine().build(
    asOf: asOf,
    mealCount: weekMeals.length,
    nutrition: [
      for (final meal in weekMeals)
        for (final item in meal.items)
          WeeklyNutritionObservation(
            dayKey: meal.meal.dayKey,
            calories: item.calories,
            proteinG: item.protein,
            carbsG: item.carbs,
            fatG: item.fats,
            sodiumMg: item.sodium,
            foodCategory: meal.foodsById[item.foodId]?.category,
            foodName: meal.foodsById[item.foodId]?.name,
          ),
    ],
    water: [
      for (final item in water.where((entry) => recent(entry.occurredAt)))
        WeeklyWaterObservation(dayKey: item.dayKey, amountMl: item.amountMl),
    ],
    weights: [
      for (final item in weights.where((entry) => recent(entry.date)))
        WeeklyWeightObservation(
          dayKey: dayKeyFor(item.date),
          observedAt: item.date,
          weightKg: item.weight,
        ),
    ],
    activity: weeklyActivity,
    sleep: sleepByDay.values,
    fasting: [
      for (final entry in fastingHistory.where(
        (entry) => recent(entry.endedAt),
      ))
        WeeklyFastingObservation(
          dayKey: dayKeyFor(entry.endedAt),
          durationMinutes: entry.duration.inMinutes,
          reachedTarget: entry.reachedTarget,
        ),
    ],
    bodyContext: [
      for (final item in dailyLogs.where((entry) => recent(entry.date)))
        if (DailyBodyContextCodec.engineTypes(item.notes).isNotEmpty)
          WeeklyBodyContextObservation(
            dayKey: item.dayKey,
            types: DailyBodyContextCodec.engineTypes(item.notes),
          ),
    ],
    allTimeMealCount: meals.length,
    allTimeFoodCount: meals.fold<int>(
      0,
      (total, meal) => total + meal.items.length,
    ),
    allTimeWeightCount: weights.length,
    allTimeExerciseDays: dailyLogs
        .where((entry) => entry.exerciseNotes?.trim().isNotEmpty == true)
        .length,
    allTimeSteps: dailyLogs.any((entry) => entry.steps != null)
        ? dailyLogs.fold<int>(0, (sum, entry) => sum + (entry.steps ?? 0))
        : null,
    dailyCalorieGoal: fallbackCalorieGoal?.round(),
    calorieGoalsByDay: calorieGoalsByDay,
    loggingStreakDays: computeWeeklyLoggingStreak(asOf, <String>{
      ...meals.map((entry) => entry.meal.dayKey),
      ...water.map((entry) => entry.dayKey),
      ...weights.map((entry) => dayKeyFor(entry.date)),
      ...dailyLogs
          .where(_hasRecordedDailyEvidence)
          .map((entry) => entry.dayKey),
    }),
  );
});

DateTime _connectedSleepDay(
  DateTime observedAt,
  Map<String, Object?> attributes,
) {
  final endedAt = DateTime.tryParse(attributes['endedAt']?.toString() ?? '');
  return (endedAt ?? observedAt).toLocal();
}

/// Reads only explicit estimates persisted by the workout engine. Plain text
/// notes and malformed/unsupported payloads never become invented burn data.
double? estimatedExerciseCaloriesFromNotes(String? notes) {
  if (notes == null || notes.trim().isEmpty) return null;
  var total = 0.0;
  var found = false;
  for (final line in notes.split('\n')) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) continue;
      final value = decoded['estimatedCaloriesKcal'];
      if (value is! num) continue;
      final estimate = value.toDouble();
      if (!estimate.isFinite || estimate <= 0 || estimate > 5000) continue;
      total += estimate;
      found = true;
    } on FormatException {
      // Manual notes remain valid exercise evidence, but not calorie evidence.
    }
  }
  return found ? total : null;
}

int computeWeeklyLoggingStreak(DateTime asOf, Set<String> recordedDays) {
  var streak = 0;
  var day = DateTime(asOf.year, asOf.month, asOf.day);
  while (recordedDays.contains(dayKeyFor(day))) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

bool _hasRecordedDailyEvidence(DailyLog entry) {
  return entry.steps != null ||
      entry.exerciseNotes?.trim().isNotEmpty == true ||
      entry.notes?.trim().isNotEmpty == true ||
      entry.sleepHours != null ||
      entry.weight != null ||
      entry.water != null ||
      entry.calories != null ||
      entry.protein != null ||
      entry.carbs != null ||
      entry.fats != null;
}
