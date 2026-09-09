import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_presentation_localizer.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:body_intelligence_log/features/nutrition/services/trusted_food_network_search_resolver.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    testWidgets('$tag diary search and food detail render at 160% text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final foods = FoodRepository(database);
      final foodId = await foods.addFood(
        name: 'Chicken breast',
        arabicName: 'صدر دجاج',
        category: 'Poultry',
        calories: 165,
        protein: 31,
        carbs: 0,
        fats: 3.6,
        servingSize: 100,
        servingUnit: 'g',
        fiber: 0,
        sodium: 74,
        isCustom: false,
        verified: true,
        source: 'USDA FoodData Central',
      );
      await foods.recordRecent(foodId);
      final food = (await database.select(database.foods).get()).single;
      final selectedDate = DateTime(2026, 8, 22);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            seedCatalogProvider.overrideWith((ref) async {}),
            foodsProvider.overrideWithValue(AsyncData([food])),
            dailyWaterProvider.overrideWithValue(
              const AsyncData(<WaterEntry>[]),
            ),
            usualMealsProvider(
              'breakfast',
            ).overrideWith((ref) async => <UsualMealCandidate>[]),
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
            foodRepositoryProvider.overrideWithValue(foods),
            foodRuntimeSearchAuthorityProvider.overrideWithValue(
              FoodRuntimeSearchAuthority(
                foods,
                catalogResolver: () async => null,
                networkSearchResolver: const _TeffGateway(),
              ),
            ),
            mealRepositoryProvider.overrideWithValue(MealRepository(database)),
            waterRepositoryProvider.overrideWithValue(
              WaterRepository(database),
            ),
            measurementSystemProvider.overrideWithValue(
              const AsyncData(MeasurementSystem.metric),
            ),
            verifiedSubscriptionStateProvider.overrideWithValue(
              AsyncData(
                SubscriptionState(
                  plan: CommercePlan.free,
                  entitlements: FreePlan.entitlements,
                  authority: EntitlementAuthority.verifiedServer,
                  isPurchasable: true,
                  canRestorePurchases: true,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: BilFlagshipTheme.light(
              isArabic: BilLocalePolicy.isRtlTag(tag),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child ?? const SizedBox.shrink(),
            ),
            home: const DailyLogPage(initialMealType: 'breakfast'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tag diary');

      final logFood = find.byKey(const Key('daily-meal-log-breakfast'));
      await tester.ensureVisible(logFood);
      await tester.tap(logFood);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(TabBar), findsNothing, reason: '$tag tabs');
      expect(
        find.byKey(const Key('daily-search-meal-selector')),
        findsNothing,
        reason: '$tag keeps the meal fixed on its dedicated page',
      );
      expect(tester.takeException(), isNull, reason: '$tag search');

      const query = 'chicken';
      final resultLocale = FoodPresentationLocalizer.resultLocaleForQuery(
        query: query,
        interfaceLocaleTag: tag,
      );
      expect(
        resultLocale,
        'en',
        reason: '$tag English query owns the result language',
      );
      final expectedName = FoodPresentationLocalizer.foodName(
        name: food.name,
        arabicName: food.arabicName,
        localeTag: resultLocale,
        source: food.source,
      );
      expect(
        find.text(expectedName),
        findsNothing,
        reason: '$tag remains empty before a query',
      );
      if (tag == 'ar') {
        await tester.enterText(find.byType(SearchBar).last, 'تيف مطبوخ');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1500));
        final trustedTeffName = FoodPresentationLocalizer.foodName(
          name: 'Teff, cooked',
          localeTag: 'ar',
          source: 'USDA FoodData Central',
        );
        expect(
          find.text(trustedTeffName),
          findsOneWidget,
          reason:
              'Explicit Arabic search must not hide a trusted USDA cloud hit',
        );
      }
      await tester.enterText(find.byType(SearchBar).last, query);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text(expectedName), findsOneWidget, reason: '$tag food name');
      final verifiedBadge = find.byKey(
        const Key('daily-search-verified-food-badge'),
      );
      expect(verifiedBadge, findsOneWidget, reason: '$tag verified badge');
      final verifiedIcon = find.descendant(
        of: verifiedBadge,
        matching: find.byIcon(Icons.verified_rounded),
      );
      expect(verifiedIcon, findsOneWidget, reason: '$tag verified icon');
      expect(
        tester.widget<Icon>(verifiedIcon).color,
        const Color(0xFF087A43),
        reason: '$tag verified green',
      );
      final addFood = find.byKey(const Key('daily-search-add-food-action'));
      expect(addFood, findsOneWidget, reason: '$tag styled add action');
      expect(
        tester.widget(addFood),
        isA<FilledButton>(),
        reason: '$tag add action uses a filled tonal button',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: '$tag localized search result',
      );
      await tester.tap(find.text(expectedName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const Key('daily-log-focused-food-detail')),
        findsOneWidget,
        reason: '$tag focused detail',
      );
      for (final repeatedControl in const <String>[
        'daily-search-barcode',
        'daily-search-voice',
        'daily-search-meal-scan',
        'daily-search-quick-add',
      ]) {
        expect(
          find.byKey(Key(repeatedControl)),
          findsNothing,
          reason: '$tag no repeated $repeatedControl in detail',
        );
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('daily-log-focused-food-detail')),
          matching: find.byType(SearchBar),
        ),
        findsNothing,
        reason: '$tag no repeated food search in detail',
      );
      expect(
        find.byKey(const Key('daily-log-meal-type-field')),
        findsOneWidget,
        reason: '$tag has one clear meal-type choice',
      );
      expect(
        find.byKey(const Key('daily-log-water-shortcut')),
        findsNothing,
        reason: '$tag has no repeated diary water section',
      );
      expect(
        find.byKey(const Key('daily-log-exercise-section')),
        findsNothing,
        reason: '$tag keeps exercise outside the focused food editor',
      );
      expect(
        find.byKey(const Key('daily-log-body-context-link')),
        findsNothing,
        reason: '$tag keeps body context outside the focused food editor',
      );
      expect(
        find.byKey(const Key('daily-log-save-meal-action')),
        findsOneWidget,
        reason: '$tag preserves the focused save action',
      );
      expect(
        find.byKey(const Key('daily-log-food-premium-group')),
        findsOneWidget,
        reason: '$tag keeps paid macro and nutrient values under one gate',
      );
      expect(
        find.byKey(const Key('premium-nutrition-glass')),
        findsOneWidget,
        reason: '$tag has one Premium glass group without repeated badges',
      );
      final nutritionFacts = find.byKey(const Key('daily-log-nutrition-facts'));
      await tester.ensureVisible(nutritionFacts);
      await tester.pump();
      expect(nutritionFacts, findsOneWidget, reason: '$tag Nutrition Facts');
      final detailException = tester.takeException();
      if (detailException is FlutterError) {
        // Kept intentionally: a failing locale prints the exact overflowing
        // widget instead of only the short RenderFlex summary.
        debugPrint(detailException.toStringDeep());
      }
      expect(detailException, isNull, reason: '$tag detail');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.idle();
    });
  }
}

class _TeffGateway extends TrustedFoodNetworkSearchResolver {
  const _TeffGateway();

  @override
  Future<List<UnifiedFood>> search(String query, {int limit = 10}) async {
    if (query.trim() != 'تيف مطبوخ') return const <UnifiedFood>[];
    return const <UnifiedFood>[
      UnifiedFood(
        id: 'usda:172672',
        name: 'Teff, cooked',
        category: 'Foundation',
        serving: FoodServing(amount: 100, unit: 'g', grams: 100),
        nutrients: <FoodNutrient, NutrientAmount>{
          FoodNutrient.calories: NutrientAmount.known(101),
          FoodNutrient.protein: NutrientAmount.known(3.87),
          FoodNutrient.carbohydrates: NutrientAmount.known(19.86),
          FoodNutrient.fat: NutrientAmount.known(0.65),
        },
        source: FoodDataSource.foundation,
        sourceLabel: 'USDA FoodData Central — verified',
        verified: true,
        isCustom: false,
      ),
    ];
  }
}
