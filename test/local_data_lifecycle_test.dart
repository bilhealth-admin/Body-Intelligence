import 'dart:convert';

import 'package:body_intelligence_log/app/services/local_data_lifecycle_service.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/challenge_repository.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  test(
    'export includes every durable local collection and schema metadata',
    () async {
      await UserProfileRepository(database).save(
        gender: 'female',
        age: 32,
        height: 165,
        currentWeight: 70,
        targetWeight: 65,
        activityLevel: 'light',
        exercises: true,
      );
      await FoodRepository(database).addFood(
        name: 'Export food',
        category: 'custom',
        calories: 100,
        protein: 5,
        carbs: 15,
        fats: 2,
      );
      await ChallengeRepository(
        database,
      ).start(type: 'water', title: 'Export challenge', targetDays: 7);

      final json =
          jsonDecode(
                await LocalDataLifecycleService(
                  database,
                ).exportJson(displayUnits: 'imperial'),
              )
              as Map<String, dynamic>;
      expect(json['format'], 'BIL local export v3');
      expect(json['schemaVersion'], 15);
      expect(json['selectedDisplayUnits'], 'imperial');
      expect(json['profile'], isNotNull);
      for (final key in const [
        'goals',
        'planSettings',
        'weights',
        'dailyLogs',
        'foods',
        'favorites',
        'recentFoods',
        'meals',
        'mealItems',
        'waterEntries',
        'lifeContext',
        'decisionMemory',
        'personalExperiments',
        'challenges',
        'preferences',
      ]) {
        expect(json, contains(key));
      }
    },
  );

  test('clear all removes user data across new and inherited tables', () async {
    await UserProfileRepository(database).save(
      gender: 'male',
      age: 40,
      height: 180,
      currentWeight: 90,
      targetWeight: 85,
      activityLevel: 'moderate',
      exercises: true,
    );
    await FoodRepository(database).addFood(
      name: 'Delete food',
      category: 'custom',
      calories: 100,
      protein: 5,
      carbs: 15,
      fats: 2,
    );
    await ChallengeRepository(
      database,
    ).start(type: 'protein', title: 'Delete challenge', targetDays: 7);

    await LocalDataLifecycleService(database).clearAll();

    expect(await database.select(database.userProfile).get(), isEmpty);
    expect(await database.select(database.foods).get(), isEmpty);
    expect(await database.select(database.challenges).get(), isEmpty);
    expect(await database.select(database.planSettings).get(), isEmpty);
    expect(await database.select(database.personalExperiments).get(), isEmpty);
  });
}
