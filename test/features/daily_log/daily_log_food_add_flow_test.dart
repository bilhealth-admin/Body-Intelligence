import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
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
      addTearDown(
        () => database.close().timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        ),
      );
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
        fiber: 2.4,
        sodium: 36,
        isCustom: false,
        verified: true,
        source: 'USDA FoodData Central',
      );
      await foods.recordRecent(foodId);
      final food = (await database.select(database.foods).get()).singleWhere(
        (candidate) => candidate.id == foodId,
      );
      final selectedDate = DateTime(2026, 8, 14);
      final premium = SubscriptionState(
        plan: CommercePlan.premium,
        entitlements: const {CommerceEntitlement.advancedIntelligence},
        authority: EntitlementAuthority.verifiedServer,
        isPurchasable: true,
        canRestorePurchases: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            verifiedSubscriptionStateProvider.overrideWithValue(
              AsyncData(premium),
            ),
            seedCatalogProvider.overrideWith((ref) async {}),
            foodsProvider.overrideWithValue(AsyncData([food])),
            foodRuntimeSearchAuthorityProvider.overrideWithValue(
              FoodRuntimeSearchAuthority(
                foods,
                catalogResolver: () async => null,
              ),
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

      final breakfastLog = find.byKey(const Key('daily-meal-log-breakfast'));
      expect(
        find.byKey(const Key('daily-meal-card-breakfast')),
        findsOneWidget,
      );
      await tester.ensureVisible(breakfastLog);
      await tester.pump();
      await tester.tap(breakfastLog);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      if (find.byType(SearchBar).evaluate().isNotEmpty) {
        final searchBar = find.byType(SearchBar).last;
        await tester.ensureVisible(searchBar);
        await tester.tap(searchBar);
        await tester.pumpAndSettle();
      }
      expect(find.text('All'), findsNothing);
      expect(find.text('My meals'), findsNothing);
      expect(find.text('My recipes'), findsNothing);
      expect(find.text('My foods'), findsNothing);
      expect(find.byKey(const Key('daily-search-meal-selector')), findsNothing);
      expect(find.byKey(const Key('daily-search-barcode')), findsNothing);
      expect(find.byKey(const Key('daily-search-voice')), findsNothing);
      expect(find.byKey(const Key('daily-search-meal-scan')), findsNothing);
      expect(find.byKey(const Key('daily-search-quick-add')), findsNothing);
      if (find.byType(SearchBar).evaluate().isNotEmpty &&
          find.text('Plain Greek yogurt').evaluate().isEmpty) {
        await tester.tap(find.byType(SearchBar).last);
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(SearchBar).last, 'Plain Greek');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Plain Greek yogurt'), findsOneWidget);
      await tester.tap(find.text('Plain Greek yogurt'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Nutrition Facts'), findsOneWidget);
      expect(
        find.byKey(const Key('daily-log-nutrition-facts')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily-log-nutrition-facts-expanded')),
        findsNothing,
        reason: 'Detailed nutrients stay collapsed until requested.',
      );
      await tester.ensureVisible(
        find.byKey(const Key('daily-log-nutrition-facts')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('daily-log-nutrition-facts')));
      await tester.pump();
      expect(
        find.byKey(const Key('daily-log-nutrition-facts-expanded')),
        findsOneWidget,
      );
      expect(find.textContaining('USDA FoodData Central'), findsNothing);
      expect(
        find.byKey(const Key('daily-log-meal-type-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily-log-serving-amount-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily-log-serving-unit-field')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('daily-log-focused-food-detail')),
          matching: find.byType(SearchBar),
        ),
        findsNothing,
      );
      expect(find.byKey(const Key('daily-log-water-shortcut')), findsNothing);
      final save = find.widgetWithText(FilledButton, 'Save meal');
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final loggedMeals = await database.select(database.meals).get();
      final loggedItems = await database.select(database.mealItems).get();
      await tester.pumpAndSettle();
      final foodRow = find.byKey(
        Key('daily-food-row-${loggedItems.single.id}'),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('daily-log-focused-meal-page')),
          matching: foodRow,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: foodRow, matching: find.text('Plain Greek yogurt')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('daily-meal-detail-summary')),
        findsOneWidget,
      );
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
      await tester.pump(const Duration(milliseconds: 50));
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
