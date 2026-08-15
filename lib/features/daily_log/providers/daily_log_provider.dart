import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/daily_log_repository.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../data/repositories/water_repository.dart';
import '../../foods/providers/food_provider.dart';
import '../../profile/providers/user_profile_provider.dart';

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

/// Authoritative open/closed snapshot for the selected diary day.
///
/// This is deliberately separate from [selectedDailyLogProvider]: completing
/// a diary freezes the nutrition snapshot, while reopening returns the day to
/// live meal totals.
final selectedDailyLedgerProvider = FutureProvider<AuthoritativeDailyLedger>((
  ref,
) {
  final date = ref.watch(selectedLogDateProvider);
  return ref.watch(dailyLogRepositoryProvider).readLedger(date);
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

final dailyLogPreferenceProvider = StreamProvider.family<bool, String>((
  ref,
  key,
) {
  const enabledByDefault = <String>{
    'diary.showAllMeals',
    'diary.foodInsights',
    'diary.alwaysShowWater',
  };
  return ref
      .watch(preferencesRepositoryProvider)
      .watch(key)
      .map(
        (value) =>
            value == null ? enabledByDefault.contains(key) : value == 'true',
      );
});

final diaryMealNamesProvider = StreamProvider<List<String?>>((ref) {
  final repository = ref.watch(preferencesRepositoryProvider);
  return Stream<List<String?>>.multi((controller) {
    final subscriptions = <dynamic>[];
    final values = List<String?>.filled(4, null);
    final received = List<bool>.filled(4, false);
    for (var i = 0; i < 4; i++) {
      subscriptions.add(
        repository.watch('diary.mealName.$i').listen((value) {
          values[i] = value;
          received[i] = true;
          if (received.every((ready) => ready)) {
            controller.add([
              for (final configured in values) configured?.trim(),
            ]);
          }
        }, onError: controller.addError),
      );
    }
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  });
});
