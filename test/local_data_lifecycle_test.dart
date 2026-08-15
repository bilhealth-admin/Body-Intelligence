import 'dart:convert';

import 'package:body_intelligence_log/app/services/local_data_lifecycle_service.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/challenge_repository.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
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
        servingSize: 1,
        servingUnit: 'serving',
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
      expect(json['schemaVersion'], 20);
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
        'decisionOutcomeTransitions',
        'personalExperiments',
        'challenges',
        'preferences',
      ]) {
        expect(json, contains(key));
      }
    },
  );

  test('CSV export exposes the three promised evidence datasets', () async {
    final files = await LocalDataLifecycleService(database).exportCsvFiles();
    expect(files.keys, {
      'BIL-progress.csv',
      'BIL-meal-nutrition.csv',
      'BIL-exercise.csv',
    });
    for (final entry in files.entries) {
      expect(entry.value, isNotEmpty, reason: entry.key);
      expect(entry.value, contains('recordType'), reason: entry.key);
    }
  });

  test(
    'CSV export uses documented schema and inclusive local date range',
    () async {
      await WeightRepository(
        database,
      ).addWeight(80, date: DateTime(2026, 8, 1, 8), note: 'outside-range');
      await WeightRepository(
        database,
      ).addWeight(79, date: DateTime(2026, 8, 10, 21), note: 'inside-range');
      await DailyLogRepository(database).save(
        date: DateTime(2026, 8, 10, 23),
        steps: 7500,
        exerciseNotes: 'Evening walk',
      );

      final files = await LocalDataLifecycleService(
        database,
      ).exportCsvFiles(from: DateTime(2026, 8, 10), to: DateTime(2026, 8, 10));

      expect(
        files['BIL-progress.csv']!.split('\r\n').first,
        '"recordType","date","weightKg","measurementContext","note"',
      );
      expect(files['BIL-progress.csv'], contains('inside-range'));
      expect(files['BIL-progress.csv'], isNot(contains('outside-range')));
      expect(files['BIL-exercise.csv'], contains('Evening walk'));
      expect(files['BIL-exercise.csv'], contains('7500'));
    },
  );

  test('export date range rejects reversed dates', () {
    expect(
      () => LocalExportDateRange(
        from: DateTime(2026, 8, 11),
        to: DateTime(2026, 8, 10),
      ),
      throwsArgumentError,
    );
  });

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
      servingSize: 1,
      servingUnit: 'serving',
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
    expect(
      await database.select(database.decisionOutcomeTransitions).get(),
      isEmpty,
    );
  });
}
