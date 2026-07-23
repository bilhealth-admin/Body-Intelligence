import 'package:body_intelligence_log/app/services/performance_budgets.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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
      final cold = Stopwatch()..start();
      final coldResults = await repository.search('target');
      cold.stop();
      final warm = Stopwatch()..start();
      final warmResults = await repository.search('target');
      warm.stop();

      // Printed values provide reproducible host evidence without embedding a
      // machine-specific timing claim in production UI.
      // ignore: avoid_print
      print(
        'BIL_PERF startup_ms=${startup.elapsedMilliseconds} '
        'search_cold_ms=${cold.elapsedMilliseconds} '
        'search_warm_ms=${warm.elapsedMilliseconds}',
      );
      expect(startup.elapsed, lessThan(PerformanceBudgets.databaseStartup));
      expect(cold.elapsed, lessThan(PerformanceBudgets.foodSearch));
      expect(warm.elapsed, lessThan(PerformanceBudgets.foodSearch));
      expect(coldResults.single.name, 'Benchmark target oats');
      expect(warmResults.single.id, coldResults.single.id);
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
