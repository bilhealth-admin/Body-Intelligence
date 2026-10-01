import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pre-final large-data and lifecycle stress stays inside CI budgets',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'bil-pre-final-stress-',
      );
      final file = File('${root.path}/stress.sqlite');
      AppDatabase? activeDatabase;

      try {
        final seeded = AppDatabase.forTesting(NativeDatabase(file));
        activeDatabase = seeded;
        await seeded.customSelect('SELECT 1').getSingle();

        final seed = Stopwatch()..start();
        final base = DateTime.utc(2023, 1, 1);
        await seeded.batch((batch) {
          for (var index = 0; index < 1000; index++) {
            batch.insert(
              seeded.weightEntries,
              WeightEntriesCompanion.insert(
                uuid: Value('stress-weight-$index'),
                date: Value(base.add(Duration(days: index))),
                dayKey: Value('stress-weight-day-$index'),
                weight: 80 + (index % 100) / 10,
              ),
            );
          }
          for (var index = 0; index < 1500; index++) {
            batch.insert(
              seeded.foods,
              FoodsCompanion.insert(
                uuid: Value('stress-recipe-$index'),
                name: 'Stress recipe $index',
                category: const Value('calculated-recipe'),
                calories: (400 + (index % 50)).toDouble(),
                protein: (20 + (index % 10)).toDouble(),
                carbs: (50 + (index % 20)).toDouble(),
                fats: (12 + (index % 8)).toDouble(),
                isCustom: const Value(true),
                source: const Value('pre-final-stress'),
              ),
            );
          }
        });

        final foods = await seeded.select(seeded.foods).get();
        expect(foods, hasLength(1500));

        const mealTypes = <String>['breakfast', 'lunch', 'dinner', 'snack'];
        await seeded.batch((batch) {
          for (var index = 0; index < 3000; index++) {
            batch.insert(
              seeded.meals,
              MealsCompanion.insert(
                uuid: Value('stress-meal-$index'),
                date: base.add(Duration(minutes: index)),
                dayKey: 'stress-meal-day-${index ~/ 4}',
                name: Value('Stress meal $index'),
                type: Value(mealTypes[index % mealTypes.length]),
              ),
            );
          }
        });
        final meals = await seeded.select(seeded.meals).get();
        expect(meals, hasLength(3000));

        await seeded.batch((batch) {
          for (var index = 0; index < meals.length; index++) {
            batch.insert(
              seeded.mealItems,
              MealItemsCompanion.insert(
                uuid: Value('stress-item-$index'),
                mealId: meals[index].id,
                foodId: foods[index % foods.length].id,
                quantity: const Value(100.0),
              ),
            );
          }
        });
        seed.stop();

        expect(seed.elapsed, lessThan(const Duration(seconds: 40)));

        final query = Stopwatch()..start();
        final weightCount = await seeded
            .customSelect(
              'SELECT COUNT(*) AS c FROM weight_entries WHERE deleted_at IS NULL',
            )
            .getSingle();
        final mealItemCount = await seeded
            .customSelect(
              'SELECT COUNT(*) AS c FROM meal_items WHERE deleted_at IS NULL',
            )
            .getSingle();
        final search = await FoodRepository(
          seeded,
        ).search('Stress recipe 1499');
        query.stop();

        expect(weightCount.read<int>('c'), 1000);
        expect(mealItemCount.read<int>('c'), 3000);
        expect(search.any((food) => food.name == 'Stress recipe 1499'), isTrue);
        expect(query.elapsed, lessThan(const Duration(seconds: 3)));

        final community = List<CommunityPost>.generate(
          5000,
          (index) => CommunityPost(
            id: 'stress-post-$index',
            authorId: 'stress-author-${index % 50}',
            authorName: 'QA Author ${index % 50}',
            body: 'Bounded community stress body $index',
            createdAt: base.add(Duration(seconds: index)),
          ),
        );
        community.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        expect(community.first.id, 'stress-post-4999');
        expect(community.take(40), hasLength(40));

        final conversation = List<Map<String, Object?>>.generate(
          2000,
          (index) => <String, Object?>{
            'role': index.isEven ? 'user' : 'assistant',
            'content': 'bounded pre-final context $index ${'x' * 120}',
          },
        );
        final contextTimer = Stopwatch()..start();
        final contextJson = jsonEncode(conversation);
        final decoded = jsonDecode(contextJson) as List<dynamic>;
        contextTimer.stop();
        expect(decoded, hasLength(2000));
        expect(utf8.encode(contextJson).length, lessThan(2 * 1024 * 1024));
        expect(contextTimer.elapsed, lessThan(const Duration(seconds: 2)));

        final baselineRss = ProcessInfo.currentRss;
        for (var iteration = 0; iteration < 40; iteration++) {
          await seeded
              .customSelect(
                'SELECT id, weight FROM weight_entries '
                'WHERE deleted_at IS NULL ORDER BY date DESC LIMIT 100',
              )
              .get();
          await seeded
              .customSelect(
                'SELECT meal_id, COUNT(*) AS c FROM meal_items '
                'WHERE deleted_at IS NULL GROUP BY meal_id LIMIT 100',
              )
              .get();
        }
        final rssDelta = ProcessInfo.currentRss - baselineRss;
        expect(rssDelta, lessThan(384 * 1024 * 1024));

        await seeded.close();
        activeDatabase = null;

        final startup = Stopwatch()..start();
        final startupDb = AppDatabase.forTesting(NativeDatabase(file));
        activeDatabase = startupDb;
        await startupDb
            .customSelect('SELECT COUNT(*) FROM meal_items')
            .getSingle();
        startup.stop();
        expect(startup.elapsed, lessThan(const Duration(seconds: 6)));
        await startupDb.close();
        activeDatabase = null;

        final reopen = Stopwatch()..start();
        for (var iteration = 0; iteration < 12; iteration++) {
          final reopened = AppDatabase.forTesting(NativeDatabase(file));
          await reopened.customSelect('SELECT COUNT(*) FROM foods').getSingle();
          await reopened.close();
        }
        reopen.stop();
        expect(reopen.elapsed, lessThan(const Duration(seconds: 20)));

        final bytes = await file.length();
        expect(bytes, greaterThan(0));
        expect(bytes, lessThan(512 * 1024 * 1024));

        // ignore: avoid_print
        print(
          'BIL_PRE_FINAL_STRESS '
          'seed_ms=${seed.elapsedMilliseconds} '
          'query_ms=${query.elapsedMilliseconds} '
          'context_ms=${contextTimer.elapsedMilliseconds} '
          'startup_ms=${startup.elapsedMilliseconds} '
          'reopen_ms=${reopen.elapsedMilliseconds} '
          'rss_delta=$rssDelta db_bytes=$bytes',
        );
      } finally {
        if (activeDatabase != null) {
          await activeDatabase.close();
        }
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
