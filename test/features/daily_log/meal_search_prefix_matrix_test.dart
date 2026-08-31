import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _RecordingFoodSearchAuthority extends FoodRuntimeSearchAuthority {
  _RecordingFoodSearchAuthority(super.repository)
    : super(catalogResolver: () async => null);

  final queries = <String>[];
  final resultNames = <String, List<String>>{};

  @override
  Future<List<Food>> search(String query, {int limit = 50}) async {
    final foods = await super.search(query, limit: limit);
    queries.add(query);
    resultNames[query] = foods.map((food) => food.name).toList(growable: false);
    return foods;
  }
}

void main() {
  for (final mealType in const <String>[
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ]) {
    testWidgets('$mealType route uses the shared incremental prefix search', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = FoodRepository(database);
      for (final name in const <String>['Apple', 'Apricot', 'Avocado']) {
        await repository.addFood(
          name: name,
          category: 'fruit',
          calories: 52,
          protein: .3,
          carbs: 14,
          fats: .2,
          servingSize: 100,
          servingUnit: 'g',
        );
      }
      final foods = await repository.getFoods();
      final authority = _RecordingFoodSearchAuthority(repository);
      final selectedDate = DateTime(2026, 8, 24);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            seedCatalogProvider.overrideWith((ref) async {}),
            foodsProvider.overrideWithValue(AsyncData(foods)),
            dailyWaterProvider.overrideWithValue(
              const AsyncData(<WaterEntry>[]),
            ),
            usualMealsProvider(
              mealType,
            ).overrideWith((ref) async => <UsualMealCandidate>[]),
            selectedLogDateProvider.overrideWith((ref) => selectedDate),
            selectedDailyLogProvider.overrideWithValue(const AsyncData(null)),
            diaryMealNamesProvider.overrideWithValue(
              const AsyncData(<String?>[null, null, null, null]),
            ),
            for (final key in const <String>{
              'diary.foodInsights',
              'diary.showAllMeals',
              'diary.showFoodTimestamps',
              'diary.useNetCarbs',
              'diary.alwaysShowWater',
            })
              dailyLogPreferenceProvider(key).overrideWithValue(
                AsyncData(
                  const <String>{
                    'diary.foodInsights',
                    'diary.showAllMeals',
                    'diary.alwaysShowWater',
                  }.contains(key),
                ),
              ),
            nutritionGoalScheduleProvider.overrideWithValue(
              const AsyncData(NutritionGoalSchedule()),
            ),
            userProfileProvider.overrideWithValue(const AsyncData(null)),
            foodRepositoryProvider.overrideWithValue(repository),
            foodRuntimeSearchAuthorityProvider.overrideWithValue(authority),
            mealRepositoryProvider.overrideWithValue(MealRepository(database)),
            waterRepositoryProvider.overrideWithValue(
              WaterRepository(database),
            ),
            measurementSystemProvider.overrideWithValue(
              const AsyncData(MeasurementSystem.metric),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: DailyLogPage(initialMealType: mealType, focusMealEntry: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(
        find.byKey(const Key('daily-meal-detail-title')),
      );
      expect(
        title.data,
        '${mealType[0].toUpperCase()}${mealType.substring(1)}',
      );
      expect(find.byKey(const Key('daily-meal-food-search-bar')), findsOne);

      final searchBar = find.byType(SearchBar).last;
      const sequence = <String>['a', 'ap', 'app', 'appl', 'apple'];
      const expectedCounts = <int>[3, 2, 1, 1, 1];
      for (var index = 0; index < sequence.length; index++) {
        final query = sequence[index];
        await tester.enterText(searchBar, query);
        await tester.pump(const Duration(milliseconds: 220));
        await tester.pumpAndSettle();

        expect(authority.queries.last, query, reason: '$mealType/$query');
        expect(
          authority.resultNames[query],
          hasLength(expectedCounts[index]),
          reason: '$mealType/$query',
        );
      }
      expect(find.text('Apple'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.idle();
    });
  }
}
