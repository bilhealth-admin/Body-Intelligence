import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily log amount conversion preserves non-mass serving semantics', () {
    expect(dailyLogAmountInGrams(amount: 125, unit: 'serving'), 125);
    expect(dailyLogAmountInGrams(amount: 2, unit: 'piece'), 2);
    expect(dailyLogAmountInGrams(amount: 1, unit: 'kg'), 1000);
    expect(
      dailyLogAmountInGrams(amount: 1, unit: 'oz'),
      closeTo(28.349523125, 1e-9),
    );
    expect(
      dailyLogAmountInGrams(amount: 1, unit: 'lbs'),
      closeTo(453.59237, 1e-9),
    );
    expect(dailyLogAmountInGrams(amount: 500, unit: 'milligrams'), 0.5);
    expect(dailyLogAmountInGrams(amount: double.nan, unit: 'g'), isNull);
  });

  testWidgets(
    'repository food selection saves one reviewed snapshot and survives reload',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final foods = FoodRepository(database);
      final foodId = await foods.addFood(
        name: 'Plain Greek yogurt',
        arabicName: 'زبادي يوناني سادة',
        category: 'Dairy',
        calories: 59,
        protein: 10.3,
        carbs: 3.6,
        fats: 0.4,
        servingSize: 100,
        servingUnit: 'g',
        isCustom: false,
        verified: true,
        source: 'USDA FoodData Central',
      );
      await foods.recordRecent(foodId);
      final food = (await database.select(database.foods).get()).singleWhere(
        (candidate) => candidate.id == foodId,
      );
      final selectedDate = DateTime(2026, 8, 14);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            seedCatalogProvider.overrideWith((ref) async {}),
            foodsProvider.overrideWithValue(AsyncData([food])),
            dailyMealsProvider.overrideWithValue(
              const AsyncData(<MealWithItems>[]),
            ),
            dailyWaterProvider.overrideWithValue(
              const AsyncData(<WaterEntry>[]),
            ),
            usualMealsProvider(
              'breakfast',
            ).overrideWith((ref) => Future.value(<UsualMealCandidate>[])),
            selectedLogDateProvider.overrideWith((ref) => selectedDate),
            selectedDailyLogProvider.overrideWithValue(const AsyncData(null)),
            diaryMealNamesProvider.overrideWithValue(
              const AsyncData(<String?>[null, null, null, null]),
            ),
            for (final key in const <String>[
              'diary.foodInsights',
              'diary.showAllMeals',
              'diary.showFoodTimestamps',
              'diary.useNetCarbs',
              'diary.alwaysShowWater',
            ])
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
            waterRepositoryProvider.overrideWithValue(
              WaterRepository(database),
            ),
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
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byType(SearchBar));
      await tester.pump();
      await tester.tap(find.byType(SearchBar));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Plain Greek yogurt'), findsOneWidget);
      await tester.tap(find.text('Plain Greek yogurt'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('USDA FoodData Central'), findsOneWidget);
      expect(
        find.byKey(const Key('daily-log-serving-choices')),
        findsOneWidget,
      );
      final save = find.widgetWithText(FilledButton, 'Save meal');
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final loggedMeals = await database.select(database.meals).get();
      final loggedItems = await database.select(database.mealItems).get();
      expect(loggedMeals, hasLength(1));
      expect(loggedItems, hasLength(1));
      expect(loggedItems.single.foodId, foodId);
      expect(loggedItems.single.quantity, 100);
      expect(loggedItems.single.calories, 59);
      expect(loggedItems.single.protein, 10.3);
      expect(loggedItems.single.servingSizeSnapshot, 100);
      expect(loggedItems.single.servingUnitSnapshot, 'g');
      expect(loggedItems.single.nutrientEvidenceMask, greaterThan(0));
      expect(loggedItems.single.foodVerifiedSnapshot, isTrue);
      expect(loggedItems.single.foodSourceSnapshot, 'USDA FoodData Central');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final reopenedItems = await database.select(database.mealItems).get();
      expect(reopenedItems.single.foodId, foodId);
    },
  );

  test(
    'atomic reviewed add rolls back a meal when its food is invalid',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await expectLater(
        MealRepository(database).addReviewedMealItemsAtomically(
          date: DateTime(2026, 8, 14),
          mealType: 'breakfast',
          items: const [(foodId: 999999, quantity: 100)],
        ),
        throwsStateError,
      );

      expect(await database.select(database.meals).get(), isEmpty);
      expect(await database.select(database.mealItems).get(), isEmpty);
    },
  );
}
