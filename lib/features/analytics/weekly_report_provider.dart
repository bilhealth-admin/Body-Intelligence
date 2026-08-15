import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../data/database/date_keys.dart';
import '../../data/database/app_database.dart';
import '../dashboard/providers/dashboard_provider.dart';
import '../daily_log/providers/daily_log_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import 'weekly_report_engine.dart';

final weeklyReportClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final accountCreatedAtProvider = Provider<DateTime?>((ref) {
  if (!AppEnvironment.cloudConfigured) return null;
  final supabase = Supabase.instance;
  if (!supabase.isInitialized) return null;
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
  final dailyLogs = await ref.watch(dailyLogRepositoryProvider).getAll();
  final profile = await ref.watch(userProfileProvider.future);
  final plan = profile == null
      ? null
      : await ref.watch(planSettingProvider(profile.uuid).future);
  final asOf = ref.watch(selectedWeeklyReportDateProvider);
  final cutoff = asOf.subtract(const Duration(days: 6));
  bool recent(DateTime value) =>
      dayKeyFor(value).compareTo(dayKeyFor(cutoff)) >= 0 &&
      dayKeyFor(value).compareTo(dayKeyFor(asOf)) <= 0;
  final weekMeals = meals.where((entry) => recent(entry.meal.date)).toList();
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
    activity: [
      for (final item in dailyLogs.where((entry) => recent(entry.date)))
        WeeklyActivityObservation(
          dayKey: item.dayKey,
          steps: item.steps,
          exerciseNotes: item.exerciseNotes,
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
    dailyCalorieGoal: plan?.overrideCalories ?? plan?.recommendedCalories,
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
