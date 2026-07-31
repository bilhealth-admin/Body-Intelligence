import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../../engine/daily_targets.dart';

class PlanRepository {
  PlanRepository(this.database);
  final AppDatabase database;

  Stream<PlanSetting?> watchForProfile(String profileUuid) {
    return (database.select(
      database.planSettings,
    )..where((row) => row.profileUuid.equals(profileUuid))).watchSingleOrNull();
  }

  Future<PlanSetting?> getForProfile(String profileUuid) {
    return (database.select(
      database.planSettings,
    )..where((row) => row.profileUuid.equals(profileUuid))).getSingleOrNull();
  }

  Future<void> save({
    required String profileUuid,
    required DailyTargets recommended,
    int? calories,
    int? protein,
    int? carbs,
    int? fats,
    int? fiber,
    int? water,
  }) async {
    _validate(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      fiber: fiber,
      water: water,
    );
    final existing = await getForProfile(profileUuid);
    await database
        .into(database.planSettings)
        .insertOnConflictUpdate(
          PlanSettingsCompanion(
            id: existing == null ? const Value.absent() : Value(existing.id),
            uuid: existing == null
                ? const Value.absent()
                : Value(existing.uuid),
            profileUuid: Value(profileUuid),
            recommendedCalories: Value(recommended.calories),
            recommendedProtein: Value(recommended.protein),
            recommendedCarbs: Value(recommended.carbs),
            recommendedFats: Value(recommended.fats),
            recommendedFiber: Value(recommended.fiber),
            recommendedWater: Value(recommended.water),
            overrideCalories: Value(calories),
            overrideProtein: Value(protein),
            overrideCarbs: Value(carbs),
            overrideFats: Value(fats),
            overrideFiber: Value(fiber),
            overrideWater: Value(water),
            createdAt: existing == null
                ? const Value.absent()
                : Value(existing.createdAt),
            updatedAt: Value(DateTime.now()),
            revision: Value((existing?.revision ?? 0) + 1),
            syncStatus: const Value('pending'),
          ),
        );
  }

  Future<void> reset({
    required String profileUuid,
    required DailyTargets recommended,
  }) => save(profileUuid: profileUuid, recommended: recommended);

  void _validate({
    int? calories,
    int? protein,
    int? carbs,
    int? fats,
    int? fiber,
    int? water,
  }) {
    bool outside(int? value, int min, int max) =>
        value != null && (value < min || value > max);
    if (outside(calories, 1200, 6000) ||
        outside(protein, 30, 400) ||
        outside(carbs, 20, 1000) ||
        outside(fats, 20, 300) ||
        outside(fiber, 10, 100) ||
        outside(water, 1000, 10000)) {
      throw ArgumentError(
        'One or more plan targets are outside supported ranges',
      );
    }
  }
}
