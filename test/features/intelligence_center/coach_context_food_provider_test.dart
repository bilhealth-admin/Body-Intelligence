import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/ai_platform/providers/product_intelligence_provider.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/providers/exercise_calorie_providers.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/life_context/providers/life_context_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../daily_log/daily_log_nutrition_fixtures.dart';
import '../nutrition/food_basis_fixtures.dart';

enum _Case {
  noDay,
  emptyMeal,
  unknownModern,
  knownZero,
  calorieOnly,
  partialCalories,
  malformedModern,
}

class _HealthFixture implements ConnectedHealthGateway {
  _HealthFixture(this.snapshot);

  final ConnectedHealthSnapshot snapshot;
  int loads = 0;
  int unexpectedCalls = 0;

  @override
  Future<ConnectedHealthSnapshot> load() async {
    loads++;
    return snapshot;
  }

  Never _unexpected() {
    unexpectedCalls++;
    throw StateError('The context test must not invoke a native side effect');
  }

  @override
  Future<ConnectedHealthSnapshot> synchronize() => _unexpected();

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() => _unexpected();

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() =>
      _unexpected();

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() => _unexpected();

  @override
  Future<void> openSystemSettings() => _unexpected();
}

List<MealItem> _items(_Case scenario, String ownerKey) => switch (scenario) {
  _Case.noDay || _Case.emptyMeal => const [],
  _Case.unknownModern => [modernDiaryItem(values: const {})],
  _Case.knownZero => [
    modernDiaryItem(
      values: {for (final nutrient in FoodNutrient.values) nutrient: 0},
      kind: CoachFoodSourceKind.userFixed,
      ownerKey: ownerKey,
    ),
  ],
  _Case.calorieOnly => [calorieOnlyDiaryItem()],
  _Case.partialCalories => [
    modernDiaryItem(),
    modernDiaryItem(
      id: 2,
      values: {...basisNutrients, FoodNutrient.calories: null},
    ),
  ],
  _Case.malformedModern => [
    modernDiaryItem().copyWith(foodEvidenceJson: const Value(null)),
  ],
};

Future<void> _seed(
  AppDatabase database,
  List<DateTime> days,
  _Case scenario,
) async {
  if (scenario == _Case.noDay) return;
  final ownerKey = LocalDatabaseScope.keyForOwner(database.localOwnerId);
  final items = _items(scenario, ownerKey);
  await database.transaction(() async {
    for (var index = 0; index < days.length; index++) {
      final mealId = index + 1;
      final meal = diaryMeal(const []).meal.copyWith(
        id: mealId,
        uuid: 'provider-meal-$mealId',
        date: days[index],
        dayKey: dayKeyFor(days[index]),
      );
      await database.into(database.meals).insert(meal.toCompanion(true));
      for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
        final itemId = mealId * 10 + itemIndex + 1;
        final item = items[itemIndex].copyWith(
          id: itemId,
          uuid: 'provider-item-$itemId',
          mealId: mealId,
          foodId: itemId,
        );
        await database
            .into(database.foods)
            .insert(
              basisFood()
                  .copyWith(id: itemId, uuid: 'provider-food-$itemId')
                  .toCompanion(true),
            );
        await database.into(database.mealItems).insert(item.toCompanion(true));
      }
    }
  });
}

void main() {
  for (final scenario in _Case.values) {
    test('actual Coach provider preserves ${scenario.name} evidence', () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'coach-context-provider-owner',
      );
      ProviderContainer? container;
      addTearDown(() async {
        container?.dispose();
        await database.close();
      });
      final now = DateTime.now();
      // Identical adjacent-day fixtures keep this real-clock test stable if
      // midnight passes during asynchronous SQLite reads. No fake clock,
      // platform process, or production clock override is involved.
      final days = [
        for (final offset in [-1, 0, 1])
          DateTime(now.year, now.month, now.day + offset),
      ];
      await _seed(database, days, scenario);
      await PreferencesRepository(database).setMany({
        'goal.calories': '2000',
        'goal.carbsPercent': '40',
        'goal.proteinPercent': '30',
        'goal.fatPercent': '30',
        exerciseCaloriesIncludedPreferenceKey: 'true',
        exerciseMacrosAdjustedPreferenceKey: 'false',
        CoachContextPreferences.storageKey: const CoachContextPreferences(
          focuses: {CoachContextFocus.nutrition, CoachContextFocus.training},
        ).encode(),
      });
      final rows = await MealRepository(database).watchAll().first;
      expect(rows, hasLength(scenario == _Case.noDay ? 0 : 3));
      final expectedOwner = LocalDatabaseScope.keyForOwner(
        database.localOwnerId,
      );
      for (final meal in rows) {
        expect(meal.ownerKey, expectedOwner);
        for (final item in meal.items) {
          final evidence = MealFoodEvidence.read(item, ownerKey: meal.ownerKey);
          expect(
            evidence.state,
            scenario == _Case.calorieOnly
                ? MealFoodEvidenceState.legacy
                : scenario == _Case.malformedModern
                ? MealFoodEvidenceState.invalid
                : MealFoodEvidenceState.valid,
          );
        }
      }
      // A fixture of already verified native readback, not a native adapter.
      final health = _HealthFixture(
        ConnectedHealthSnapshot(
          status: ConnectedHealthStatus.synchronized,
          platformSource: 'fixture-native-readback',
          availableSources: const ['fixture-native-readback'],
          signals: [
            for (final day in days)
              ConnectedHealthSignalView(
                key: 'activeEnergy',
                value: 300,
                unit: 'kcal',
                source: 'fixture-native-readback',
                observedAt: day,
                confidence: 1,
              ),
          ],
          importedCount: days.length,
          lastSyncAt: now,
          failureCode: null,
          deviceVerified: true,
        ),
      );
      final current = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          connectedHealthGatewayProvider.overrideWithValue(health),
          // The optional global engine is outside this nutrition assembly
          // test. Its documented unavailable state has no worker or retry.
          productIntelligenceOutputProvider.overrideWithValue(
            AsyncError(
              StateError(
                'Canonical engine intentionally unavailable in fixture',
              ),
              StackTrace.empty,
            ),
          ),
        ],
      );
      container = current;
      // Riverpod 3 pauses a StreamProvider when its last listener closes.
      // Keep the real database watches active until their first data arrives.
      final latestLogSubscription = current.listen(
        latestDailyLogProvider,
        (_, _) {},
      );
      final lifeContextSubscription = current.listen(
        insightLifeContextProvider,
        (_, _) {},
      );
      addTearDown(latestLogSubscription.close);
      addTearDown(lifeContextSubscription.close);
      expect(await current.read(latestDailyLogProvider.future), isNull);
      expect(await current.read(insightLifeContextProvider.future), isEmpty);
      await current.read(connectedHealthProvider.notifier).refresh();

      final snapshot = await current.read(coachContextSnapshotProvider.future);
      final today = snapshot.computedHealth['today']! as Map;
      final nutrition = today['nutrition']! as Map;
      final energy = today['exerciseEnergy']! as Map;
      final targets = snapshot.computedHealth['dailyTargets']! as Map;
      final sources = snapshot.computedHealth['dailyTargetSources']! as Map;
      expect(days.map(dayKeyFor), contains(today['day']));
      expect(targets['caloriesKcal'], 2000);
      expect(sources['caloriesKcal'], 'saved_percentage_goal');
      expect(energy['baseCaloriesKcal'], 2000);
      expect(energy['effectiveCalorieGoalKcal'], 2300);
      expect(energy['verifiedBurnedKcal'], 300);
      expect(energy['includedInRemaining'], isTrue);
      expect(energy['manualExerciseChangesAllowance'], isFalse);
      expect(snapshot.canonicalIntelligence['status'], 'unavailable');
      final expectedCalories = switch (scenario) {
        _Case.knownZero => 0.0,
        _Case.calorieOnly => 1905.0,
        _ => null,
      };
      expect(nutrition, contains('consumedCaloriesKcal'));
      expect(energy, contains('netCaloriesKcal'));
      expect(energy, contains('remainingCaloriesKcal'));
      if (expectedCalories == null) {
        expect(nutrition['consumedCaloriesKcal'], isNull);
        expect(energy['netCaloriesKcal'], isNull);
        expect(energy['remainingCaloriesKcal'], isNull);
        expect(nutrition['knownTotals'], isNot(contains('caloriesKcal')));
      } else {
        expect(nutrition['consumedCaloriesKcal'], expectedCalories);
        expect(energy['netCaloriesKcal'], expectedCalories - 300);
        expect(energy['remainingCaloriesKcal'], 2300 - expectedCalories);
        expect(nutrition['knownTotals'], contains('caloriesKcal'));
      }
      if (scenario == _Case.noDay) {
        expect(snapshot.nutritionDays, isEmpty);
      }
      if (scenario == _Case.calorieOnly) {
        expect(nutrition['knownTotals'], ['caloriesKcal']);
        final day = snapshot.nutritionDays.singleWhere(
          (day) => day.day == today['day'],
        );
        final item = (day.meals.single['items']! as List).single as Map;
        expect(item['entryType'], 'quick_add');
        expect(item['caloriesKcal'], 1905);
        expect(item, isNot(contains('food')));
        expect(item, isNot(contains('quantity')));
        expect(item, isNot(contains('proteinG')));
      }
      expect(health.loads, 1);
      expect(health.unexpectedCalls, 0);
    });
  }
}
