import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  const before = NutritionGoalTarget(
    calories: 1800,
    carbsPercent: 50,
    proteinPercent: 20,
    fatPercent: 30,
  );
  const next = NutritionGoalTarget(
    calories: 2124,
    carbsPercent: 49,
    proteinPercent: 21,
    fatPercent: 30,
  );

  setUp(() async {
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'a',
    );
    final repository = NutritionGoalScheduleRepository(
      PreferencesRepository(database),
    );
    await repository.saveDay(DateTime.monday, before);
    await repository.saveMeal('breakfast', before);
  });
  tearDown(() => database.close());

  test(
    'day save rolls back if owner retires while the transaction reads',
    () async {
      final preferences = _PausedScheduleRead(database);
      final repository = NutritionGoalScheduleRepository(preferences);
      var current = true;
      final saving = repository.saveDay(
        DateTime.monday,
        next,
        isCurrent: () => current,
      );
      final rejected = expectLater(saving, throwsStateError);
      await preferences.entered.future;
      current = false;
      preferences.release.complete();
      await rejected;
      final saved = await repository.read();
      expect(saved.dayTargets[DateTime.monday]!.calories, before.calories);
      expect(saved.mealTargets['breakfast']!.calories, before.calories);
    },
  );

  test(
    'owner retirement after SQL write rolls back day and meal saves',
    () async {
      for (final meal in [false, true]) {
        var current = true;
        final preferences = _RetiredAfterWrite(database, () => current = false);
        final repository = NutritionGoalScheduleRepository(preferences);
        await expectLater(
          meal
              ? repository.saveMeal('breakfast', next, isCurrent: () => current)
              : repository.saveDay(
                  DateTime.monday,
                  next,
                  isCurrent: () => current,
                ),
          throwsStateError,
        );
        final saved = await repository.read();
        expect(saved.dayTargets[DateTime.monday]!.calories, before.calories);
        expect(saved.mealTargets['breakfast']!.calories, before.calories);
      }
    },
  );
}

class _PausedScheduleRead extends PreferencesRepository {
  _PausedScheduleRead(super.database);
  final entered = Completer<void>();
  final release = Completer<void>();
  bool paused = false;

  @override
  Future<String?> get(String key) async {
    final value = await super.get(key);
    if (key == nutritionGoalSchedulePreferenceKey && !paused) {
      paused = true;
      entered.complete();
      await release.future;
    }
    return value;
  }
}

class _RetiredAfterWrite extends PreferencesRepository {
  _RetiredAfterWrite(super.database, this.retire);
  final void Function() retire;

  @override
  Future<void> set(String key, String value) async {
    await super.set(key, value);
    if (key == nutritionGoalSchedulePreferenceKey) retire();
  }
}
