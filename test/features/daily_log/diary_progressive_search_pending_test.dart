import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
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
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/shared/widgets/bil_compact_activity_indicator.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _PhasedSearch extends FoodRuntimeSearchAuthority {
  _PhasedSearch(super.repository) : super(catalogResolver: () async => null);

  final visits = <({String query, StreamController<List<Food>> events})>[];

  @override
  Stream<List<Food>> searchProgressively(
    String query, {
    int limit = 50,
    Duration remoteDebounce = const Duration(milliseconds: 180),
  }) {
    final events = StreamController<List<Food>>();
    visits.add((query: query, events: events));
    return events.stream;
  }
}

Future<({Food food, _PhasedSearch authority, ProviderContainer container})>
_openSearch(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final repository = FoodRepository(database);
  await repository.addFood(
    name: 'بامية',
    arabicName: 'بامية',
    category: 'vegetable',
    calories: 33,
    protein: 1.9,
    carbs: 7.5,
    fats: .2,
    servingSize: 100,
    servingUnit: 'g',
  );
  final foods = await repository.getFoods();
  final authority = _PhasedSearch(repository);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      seedCatalogProvider.overrideWith((ref) async {}),
      foodsProvider.overrideWithValue(AsyncData(foods)),
      verifiedEntitlementOwnerSeedProvider.overrideWithValue(
        'diary-pending-qa',
      ),
      verifiedEntitlementOwnerProvider.overrideWith(
        (_) => Stream.value('diary-pending-qa'),
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
      dailyWaterProvider.overrideWithValue(const AsyncData(<WaterEntry>[])),
      usualMealsProvider(
        'breakfast',
      ).overrideWith((ref) async => <UsualMealCandidate>[]),
      selectedLogDateProvider.overrideWith((ref) => DateTime(2026, 11, 18)),
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
  );
  addTearDown(() async {
    for (final visit in authority.visits) {
      if (!visit.events.isClosed) unawaited(visit.events.close());
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    await tester.runAsync(database.close);
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const DailyLogPage(initialMealType: 'breakfast'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final meal = find.byKey(const Key('daily-meal-log-breakfast'));
  await tester.ensureVisible(meal);
  await tester.tap(meal);
  await tester.pump(const Duration(milliseconds: 600));
  final entry = find.byKey(const Key('daily-meal-food-search-bar'));
  await tester.tap(entry);
  await tester.pumpAndSettle();
  return (food: foods.single, authority: authority, container: container);
}

Future<void> _query(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(SearchBar).last, query);
  await tester.pump(const Duration(milliseconds: 220));
}

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      '${locale.toLanguageTag()} diary waits through intermediate empty phases',
      (tester) async {
        final fixture = await _openSearch(tester, locale);
        await _query(tester, 'بام');
        final events = fixture.authority.visits.last.events;
        for (var phase = 0; phase < 3; phase++) {
          events.add(const <Food>[]);
          await tester.pump();
          expect(
            find.byKey(const Key('daily-search-open-food-catalog')),
            findsNothing,
            reason: 'Pending is never the completed empty state',
          );
          expect(find.byKey(const Key('daily-search-pending')), findsOneWidget);
          expect(find.byType(BilCompactActivityIndicator), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          final indicator = tester.widget<CupertinoActivityIndicator>(
            find.byType(CupertinoActivityIndicator),
          );
          final color = indicator.color!;
          final rgb = <double>[color.r, color.g, color.b];
          expect(
            rgb.reduce((a, b) => a > b ? a : b) -
                rgb.reduce((a, b) => a < b ? a : b),
            lessThan(.08),
            reason: 'The existing operation wait stays neutral grey',
          );
        }
        events.add([fixture.food]);
        await tester.pump();
        expect(find.text('بامية'), findsOneWidget);
        expect(find.byKey(const Key('daily-search-pending')), findsNothing);
        // A usable local hit is already selectable while enrichment is pending.
        expect(events.isClosed, isFalse);
        expect(find.textContaining('On-device results'), findsNothing);
        unawaited(events.close());
        await tester.pump();
        expect(find.text('بامية'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('only a completed empty diary search offers catalog fallback', (
    tester,
  ) async {
    final fixture = await _openSearch(tester, const Locale('en'));
    await _query(tester, 'بام');
    final events = fixture.authority.visits.last.events;
    events.add(const []);
    await tester.pump();
    expect(find.textContaining('No match yet'), findsNothing);
    unawaited(events.close());
    await tester.pump();
    expect(find.byKey(const Key('daily-search-pending')), findsNothing);
    expect(find.textContaining('No match yet'), findsOneWidget);
    expect(
      find.byKey(const Key('daily-search-open-food-catalog')),
      findsOneWidget,
    );
  });

  testWidgets('filtered intermediate rows do not claim search has finished', (
    tester,
  ) async {
    final fixture = await _openSearch(tester, const Locale('ar'));
    await _query(tester, 'بام');
    final events = fixture.authority.visits.last.events;
    events.add([
      fixture.food.copyWith(
        name: 'Untranslated experimental food 739',
        arabicName: const Value(null),
        isCustom: false,
        source: 'USDA FoodData Central',
      ),
    ]);
    await tester.pump();
    expect(find.byKey(const Key('daily-search-pending')), findsOneWidget);
    expect(
      find.byKey(const Key('daily-search-open-food-catalog')),
      findsNothing,
    );
    events.add([fixture.food]);
    await tester.pump();
    expect(find.text('بامية'), findsOneWidget);
    expect(find.byKey(const Key('daily-search-pending')), findsNothing);
  });

  testWidgets('A to B to A cannot reuse the retired A stream', (tester) async {
    final fixture = await _openSearch(tester, const Locale('en'));
    await _query(tester, 'بام');
    final first = fixture.authority.visits.last.events;
    await _query(tester, 'tomato');
    await _query(tester, 'بام');
    final latest = fixture.authority.visits.last.events;
    expect(identical(first, latest), isFalse);
    first.add([
      fixture.food.copyWith(name: 'Retired', arabicName: const Value('قديم')),
    ]);
    await tester.pump();
    expect(find.text('قديم'), findsNothing);
    expect(find.byKey(const Key('daily-search-pending')), findsOneWidget);
    latest.add([fixture.food]);
    await tester.pump();
    expect(find.text('بامية'), findsOneWidget);
    expect(find.text('قديم'), findsNothing);
  });
}
