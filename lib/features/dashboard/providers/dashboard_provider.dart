import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../data/repositories/water_repository.dart';

final todayMealsProvider = StreamProvider<List<MealWithItems>>((ref) {
  return MealRepository(
    ref.watch(databaseProvider),
  ).watchMealsForDate(DateTime.now());
});

final todayWaterProvider = StreamProvider<List<WaterEntry>>((ref) {
  return WaterRepository(
    ref.watch(databaseProvider),
  ).watchForDay(DateTime.now());
});

final allMealsProvider = StreamProvider<List<MealWithItems>>((ref) {
  return MealRepository(ref.watch(databaseProvider)).watchAll();
});

final allWaterProvider = StreamProvider<List<WaterEntry>>((ref) {
  return WaterRepository(ref.watch(databaseProvider)).watchAll();
});
