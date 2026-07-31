import 'package:body_intelligence_log/app/services/performance_budgets.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/performance_samples.dart';

void main() {
  test(
    'database startup and 1000-food search stay within local budgets',
    () async {
      final startup = Stopwatch()..start();
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.customSelect('SELECT 1').getSingle();
      startup.stop();

      await database.batch((batch) {
        for (var index = 0; index < 1000; index++) {
          batch.insert(
            database.foods,
            FoodsCompanion.insert(
              name: index == 731
                  ? 'Benchmark target oats'
                  : 'Catalog food $index',
              arabicName: Value('طعام $index'),
              category: const Value('benchmark'),
              keywords: Value(index == 731 ? 'target grain' : 'catalog'),
              calories: 100,
              protein: 5,
              carbs: 15,
              fats: 2,
            ),
          );
        }
      });

      final repository = FoodRepository(database);
      final searchSamples = <Duration>[];
      Food? expectedResult;
      for (var sample = 0; sample < 5; sample++) {
        final stopwatch = Stopwatch()..start();
        final results = await repository.search('target');
        stopwatch.stop();
        searchSamples.add(stopwatch.elapsed);
        expect(results.single.name, 'Benchmark target oats');
        expectedResult ??= results.single;
        expect(results.single.id, expectedResult.id);
      }
      final medianSearch = PerformanceSamples.median(searchSamples);
      const catastrophicOutlierCeiling = Duration(milliseconds: 1500);

      // Report every sample so host scheduling noise remains visible while the
      // hard 500 ms product budget is evaluated against a robust odd-sample
      // median instead of one scheduler-sensitive observation.
      // ignore: avoid_print
      print(
        'BIL_PERF startup_ms=${startup.elapsedMilliseconds} '
        'search_samples_ms=${searchSamples.map((sample) => sample.inMilliseconds).join(',')} '
        'search_median_ms=${medianSearch.inMilliseconds}',
      );
      expect(startup.elapsed, lessThan(PerformanceBudgets.databaseStartup));
      expect(medianSearch, lessThan(PerformanceBudgets.foodSearch));
      expect(
        searchSamples.every((sample) => sample < catastrophicOutlierCeiling),
        isTrue,
        reason: 'A search sample exceeded the 1500 ms safety ceiling.',
      );
    },
  );

  test(
    'empty-query ranking remains deterministic for large local catalogs',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await database.batch((batch) {
        for (var index = 0; index < 1000; index++) {
          batch.insert(
            database.foods,
            FoodsCompanion.insert(
              name: index == 812
                  ? 'Preferred target food'
                  : 'Catalog food $index',
              arabicName: Value('طعام $index'),
              category: const Value('benchmark'),
              keywords: const Value('catalog'),
              calories: 100,
              protein: 5,
              carbs: 15,
              fats: 2,
            ),
          );
        }
      });

      final repository = FoodRepository(database);
      final preferredMatches = await repository.search('Preferred target food');
      final preferredId = preferredMatches
          .firstWhere((food) => food.name == 'Preferred target food')
          .id;
      await repository.recordRecent(preferredId);
      await repository.recordRecent(preferredId);
      await repository.setFavorite(preferredId, true);

      final ranked = await repository.search('');
      expect(ranked, isNotEmpty);
      expect(ranked.first.id, preferredId);
    },
  );
}
