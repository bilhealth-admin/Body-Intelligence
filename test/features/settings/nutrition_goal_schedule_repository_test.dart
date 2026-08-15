import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late NutritionGoalScheduleRepository repository;

  const weekday = NutritionGoalTarget(
    calories: 2200,
    carbsPercent: 45,
    proteinPercent: 30,
    fatPercent: 25,
  );
  const breakfast = NutritionGoalTarget(
    calories: 500,
    carbsPercent: 40,
    proteinPercent: 35,
    fatPercent: 25,
  );

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = NutritionGoalScheduleRepository(
      PreferencesRepository(database),
    );
  });

  tearDown(() => database.close());

  test('persists and resolves weekday and meal targets', () async {
    await repository.saveDay(DateTime.monday, weekday);
    await repository.saveMeal('breakfast', breakfast);

    final value = await repository.read();
    expect(value.targetFor(DateTime(2026, 8, 10))?.calories, 2200);
    expect(value.mealTargets['breakfast']?.proteinPercent, 35);
  });

  test('removes overrides and rejects invalid macro totals', () async {
    await repository.saveDay(DateTime.monday, weekday);
    await repository.saveDay(DateTime.monday, null);
    expect((await repository.read()).dayTargets, isEmpty);

    const invalid = NutritionGoalTarget(
      calories: 2000,
      carbsPercent: 50,
      proteinPercent: 50,
      fatPercent: 20,
    );
    expect(() => repository.saveMeal('lunch', invalid), throwsArgumentError);
  });

  test('corrupt storage safely decodes as an empty schedule', () {
    expect(NutritionGoalSchedule.decode('{bad').dayTargets, isEmpty);
    expect(NutritionGoalSchedule.decode('[]').mealTargets, isEmpty);
  });
}
