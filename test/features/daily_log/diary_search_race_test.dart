import 'dart:async';

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

final class _RaceFoodSearchAuthority extends FoodRuntimeSearchAuthority {
  _RaceFoodSearchAuthority(super.repository)
    : super(catalogResolver: () async => null);

  final pending = <String, Completer<List<Food>>>{};

  @override
  Future<List<Food>> search(String query, {int limit = 50}) =>
      pending.putIfAbsent(query, Completer<List<Food>>.new).future;
}

void main() {
  testWidgets('rapid whole-word input cannot leave stale food suggestions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = FoodRepository(database);
    final eggId = await repository.addFood(
      name: 'Eggs, Grade A, Large',
      category: 'protein',
      calories: 72,
      protein: 6.3,
      carbs: 0.4,
      fats: 4.8,
      servingSize: 50,
      servingUnit: 'g',
    );
    final appleId = await repository.addFood(
      name: 'Apple',
      category: 'fruit',
      calories: 52,
      protein: .3,
      carbs: 14,
      fats: .2,
      servingSize: 100,
      servingUnit: 'g',
    );
    final foods = await repository.getFoods();
    final egg = foods.singleWhere((food) => food.id == eggId);
    final apple = foods.singleWhere((food) => food.id == appleId);
    final authority = _RaceFoodSearchAuthority(repository);
    final selectedDate = DateTime(2026, 8, 24);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          seedCatalogProvider.overrideWith((ref) async {}),
          foodsProvider.overrideWithValue(AsyncData(foods)),
          dailyWaterProvider.overrideWithValue(const AsyncData(<WaterEntry>[])),
          usualMealsProvider(
            'breakfast',
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
                const {
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
          waterRepositoryProvider.overrideWithValue(WaterRepository(database)),
          measurementSystemProvider.overrideWithValue(
            const AsyncData(MeasurementSystem.metric),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DailyLogPage(initialMealType: 'breakfast'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final logFood = find.byKey(const Key('daily-meal-log-breakfast'));
    await tester.ensureVisible(logFood);
    await tester.tap(logFood);
    await tester.pump(const Duration(milliseconds: 600));

    final searchBar = find.byType(SearchBar).last;
    await tester.enterText(searchBar, 'a');
    await tester.pump(const Duration(milliseconds: 220));
    expect(authority.pending, contains('a'));

    await tester.enterText(searchBar, 'apple');
    await tester.pump(const Duration(milliseconds: 220));
    expect(authority.pending, contains('apple'));

    authority.pending['apple']!.complete([apple]);
    await tester.pump();
    authority.pending['a']!.complete([egg]);
    await tester.pumpAndSettle();

    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Eggs, Grade A, Large'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.idle();
  });
}
