import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../data/repositories/daily_log_repository.dart';
import '../../../data/repositories/water_repository.dart';

/// Single clock boundary for all Today/dashboard calculations.
///
/// Keeping the clock injectable prevents a dashboard render from combining
/// different calendar days across its header, streams, and intelligence
/// snapshot when midnight occurs, and makes visual evidence deterministic.
final dashboardClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final todayMealsProvider = StreamProvider<List<MealWithItems>>((ref) {
  final now = ref.watch(dashboardClockProvider)();
  return MealRepository(ref.watch(databaseProvider)).watchMealsForDate(now);
});

final todayWaterProvider = StreamProvider<List<WaterEntry>>((ref) {
  final now = ref.watch(dashboardClockProvider)();
  return WaterRepository(ref.watch(databaseProvider)).watchForDay(now);
});

final allMealsProvider = StreamProvider<List<MealWithItems>>((ref) {
  return MealRepository(ref.watch(databaseProvider)).watchAll();
});

final allWaterProvider = StreamProvider<List<WaterEntry>>((ref) {
  return WaterRepository(ref.watch(databaseProvider)).watchAll();
});

/// Historical activity evidence used by the dashboard trend cards.
///
/// Keeping this beside the other dashboard streams ensures the reference-style
/// Steps card is backed by the same local ledger as Progress, not a placeholder.
final dashboardDailyLogsProvider = StreamProvider<List<DailyLog>>((ref) {
  return DailyLogRepository(ref.watch(databaseProvider)).watchAll();
});
