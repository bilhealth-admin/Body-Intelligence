import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/daily_log_repository.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../data/repositories/water_repository.dart';
import '../../foods/providers/food_provider.dart';

final selectedLogDateProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

final dailyLogRepositoryProvider = Provider<DailyLogRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return DailyLogRepository(database);
});

final latestDailyLogProvider = StreamProvider<DailyLog?>((ref) {
  final repository = ref.watch(dailyLogRepositoryProvider);
  return repository.watchLatest();
});

final selectedDailyLogProvider = StreamProvider<DailyLog?>((ref) {
  final date = ref.watch(selectedLogDateProvider);
  return ref.watch(dailyLogRepositoryProvider).watchForDay(date);
});

final dailyMealsProvider = StreamProvider<List<MealWithItems>>((ref) {
  final date = ref.watch(selectedLogDateProvider);
  return ref.watch(mealRepositoryProvider).watchMealsForDate(date);
});

final usualMealsProvider =
    FutureProvider.family<List<UsualMealCandidate>, String>(
      (ref, type) => ref.watch(mealRepositoryProvider).usualMeals(type: type),
    );

final waterRepositoryProvider = Provider<WaterRepository>((ref) {
  return WaterRepository(ref.watch(databaseProvider));
});

final dailyWaterProvider = StreamProvider<List<WaterEntry>>((ref) {
  final date = ref.watch(selectedLogDateProvider);
  return ref.watch(waterRepositoryProvider).watchForDay(date);
});
