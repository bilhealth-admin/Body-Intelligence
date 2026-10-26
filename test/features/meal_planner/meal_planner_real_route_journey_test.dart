import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/app_router.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_brief_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/meal_planner/domain/meal_plan.dart';
import 'package:body_intelligence_log/features/meal_planner/presentation/meal_planner_page.dart';
import 'package:body_intelligence_log/features/nutrition/domain/dietary_preferences.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/smart_plan/data/bil_smart_plan_repository.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan.dart';
import 'package:body_intelligence_log/features/smart_plan/domain/bil_smart_plan_engine.dart';
import 'package:body_intelligence_log/features/smart_plan/presentation/bil_smart_plan_page.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_catalog.dart';
import 'package:body_intelligence_log/features/smart_plan/services/bil_smart_plan_clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
final _now = DateTime(2026, 10, 26, 12);

Future<void> _until(
  WidgetTester tester,
  bool Function() condition,
  String stage,
) async {
  for (var frame = 0; frame < 200 && !condition(); frame++) {
    // SQLite uses the actual event loop; an endless fake-clock settle would
    // prevent it from completing while the activity glyph schedules frames.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    final failure = tester.takeException();
    expect(failure, isNull, reason: stage);
  }
  expect(condition(), isTrue, reason: stage);
}

Future<void> _showAndTap(WidgetTester tester, Finder action) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  expect(
    action.hitTestable(),
    findsOneWidget,
    reason:
        'Target bounds: ${tester.getRect(action)}; '
        'view: ${tester.view.physicalSize}',
  );
  await tester.tap(action);
  await tester.pump();
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const tts = MethodChannel('bil/tts');
  setUp(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(tts, (call) async {
      if (call.method == 'stop') {
        return null;
      }
      throw MissingPluginException('Unexpected speech call: ${call.method}');
    });
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(tts, null);
  });
  late AppDatabase database;
  late PreferencesRepository preferences;
  late FoodRepository foods;
  late List<Food> catalog;

  setUp(() async {
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: _owner,
    );
    preferences = PreferencesRepository(database);
    foods = FoodRepository(database);
    await preferences.set(
      'mealPlanner.week.v1',
      WeeklyMealPlan(
        createdAt: _now,
        meals: const [PlannedMeal(day: 0, recipeId: 'bean_wrap')],
      ).encode(),
    );
    await foods.addFood(
      name: 'Bean and salad wrap',
      category: 'Synthetic fixture food',
      calories: 100,
      protein: 5,
      carbs: 10,
      fats: 3,
      servingSize: 100,
      servingUnit: 'g',
    );
    catalog = await foods.getFoods();
    final plan = const BilSmartPlanEngine().generate(
      BilPlanCreationRequest(
        ownerId: _owner,
        planId: 'local-white-screen-regression',
        startOn: _now,
        horizon: BilPlanHorizon.week,
        focus: BilPlanFocus.combined,
        workoutsPerWeek: 3,
        confirmedPreferences: true,
        adultConfirmed: true,
        workoutCatalog: await const BilSmartPlanCatalog().gymSessions(
          sessionMinutes: 35,
        ),
        recipeCatalog: const BilSmartPlanCatalog().recipes(
          dietary: const DietaryPreferences(),
        ),
      ),
      _now,
    );
    await BilSmartPlanRepository(
      preferences: preferences,
      currentOwnerId: () => _owner,
    ).save(plan, expectedRevision: 0);
  });
  tearDown(() => database.close());
  tearDownAll(() => AppRouter.router.dispose());

  for (final language in ['en', 'ar']) {
    for (final scenario in [
      'cold',
      'coach-my-plan',
      'queued-double-tap',
      'repeat-after-return',
      'dark',
      'small-phone-large-text',
    ]) {
      testWidgets('real production meal review journey $language $scenario', (
        tester,
      ) async {
        final largeText = scenario == 'small-phone-large-text';
        tester.view.physicalSize = largeText
            ? const Size(320, 568)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final router = AppRouter.router;
        final nested = scenario != 'cold';
        router.go(nested ? '/intelligence-center' : '/meal-planner');
        final access = SubscriptionState(
          plan: CommercePlan.premiumAiCoach,
          entitlements: const {},
          authority: EntitlementAuthority.verifiedServer,
          currentPeriodEndsAt: DateTime(2030),
          isPurchasable: false,
          canRestorePurchases: false,
        );
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(database),
                preferencesRepositoryProvider.overrideWithValue(preferences),
                seedCatalogProvider.overrideWith((ref) async {}),
                foodsProvider.overrideWithValue(AsyncData(catalog)),
                foodRepositoryProvider.overrideWithValue(foods),
                foodRuntimeSearchAuthorityProvider.overrideWithValue(
                  FoodRuntimeSearchAuthority(
                    foods,
                    catalogResolver: () async => null,
                  ),
                ),
                mealRepositoryProvider.overrideWithValue(
                  MealRepository(database),
                ),
                userProfileProvider.overrideWithValue(const AsyncData(null)),
                selectedLogDateProvider.overrideWith((ref) => _now),
                dailyWaterProvider.overrideWithValue(const AsyncData([])),
                selectedDailyLogProvider.overrideWithValue(
                  const AsyncData(null),
                ),
                diaryMealNamesProvider.overrideWithValue(
                  const AsyncData([null, null, null, null]),
                ),
                nutritionGoalScheduleProvider.overrideWithValue(
                  const AsyncData(NutritionGoalSchedule()),
                ),
                for (final meal in ['breakfast', 'lunch', 'dinner', 'snack'])
                  usualMealsProvider(meal).overrideWith((ref) async => []),
                verifiedEntitlementOwnerIdProvider.overrideWithValue(_owner),
                verifiedEntitlementOwnerProvider.overrideWith(
                  (ref) => Stream.value(_owner),
                ),
                verifiedSubscriptionAccessProvider.overrideWithValue(
                  AsyncData(access),
                ),
                verifiedSubscriptionStateProvider.overrideWithValue(
                  AsyncData(access),
                ),
                aiCoachCreditAccessProvider.overrideWithValue(
                  const AsyncData(true),
                ),
                aiCoachUsageStatusLoaderProvider.overrideWithValue(
                  () async => {
                    'credits': {'total_remaining': 1000},
                  },
                ),
                coachContextSnapshotProvider.overrideWith(
                  (ref) async => CoachContextSnapshot.empty(),
                ),
                coachHealthBriefProvider.overrideWith(
                  (ref) async => CoachContextSnapshot.empty(),
                ),
                bilSmartPlanClockProvider.overrideWithValue(() => _now),
              ],
              child: MaterialApp.router(
                theme:
                    (scenario == 'dark'
                            ? BilFlagshipTheme.dark(isArabic: language == 'ar')
                            : BilFlagshipTheme.light(
                                isArabic: language == 'ar',
                              ))
                        .copyWith(platform: TargetPlatform.iOS),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
                  child: child!,
                ),
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                routerConfig: router,
              ),
            ),
          );
          if (nested) {
            final planTab = find.byKey(
              const Key('coach-workspace-tab-/smart-plan'),
            );
            final workspace = find.byKey(
              const Key('coach-reference-workspace'),
            );
            await _until(
              tester,
              () => workspace.evaluate().isNotEmpty,
              'Coach',
            );
            if (largeText) {
              // At 200% text on a short phone the lazy Overview list must be
              // scrolled, just as a user does, before its tab row is built.
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                planTab,
                100,
                scrollable: find
                    .descendant(
                      of: workspace,
                      matching: find.byType(Scrollable),
                    )
                    .first,
              );
            }
            expect(planTab, findsOneWidget);
            await _showAndTap(tester, planTab);
            final review = find.widgetWithText(
              OutlinedButton,
              language == 'ar' ? 'مراجعة الوجبات' : 'Review meals',
            );
            if (largeText) {
              final planScroll = find.descendant(
                of: find.byType(BilSmartPlanPage),
                matching: find.byType(Scrollable),
              );
              await _until(
                tester,
                () => planScroll.evaluate().isNotEmpty,
                'Loaded My Plan scroll view',
              );
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                review,
                200,
                scrollable: planScroll.first,
                maxScrolls: 50,
              );
            }
            await _until(
              tester,
              () => review.evaluate().isNotEmpty,
              'Actual My Plan approved day',
            );
            await _showAndTap(tester, review);
          }
          final rounds = scenario == 'repeat-after-return' ? 2 : 1;
          for (var round = 0; round < rounds; round++) {
            final recipe = find.text('Bean and salad wrap');
            if (largeText) {
              final plannerScroll = find.descendant(
                of: find.byType(MealPlannerPage),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Scrollable &&
                      widget.axisDirection == AxisDirection.down,
                ),
              );
              await _until(
                tester,
                () => plannerScroll.evaluate().isNotEmpty,
                'Loaded Meal Planner scroll view',
              );
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                recipe,
                200,
                scrollable: plannerScroll.first,
                maxScrolls: 50,
              );
            }
            await _until(
              tester,
              () => recipe.evaluate().isNotEmpty,
              'Actual saved Meal Planner week',
            );
            await _showAndTap(tester, recipe);
            final reviewLog = find.widgetWithText(
              FilledButton,
              language == 'ar' ? 'راجع وسجّل' : 'Review and log',
            );
            await tester.ensureVisible(reviewLog);
            await tester.pumpAndSettle();
            expect(reviewLog.hitTestable(), findsOneWidget);
            if (scenario == 'queued-double-tap') {
              final callback = tester
                  .widget<FilledButton>(reviewLog)
                  .onPressed!;
              callback();
              callback();
            } else {
              await tester.tap(reviewLog);
            }
            await tester.pump();
            await _until(
              tester,
              () => find.byType(DailyLogPage).evaluate().isNotEmpty,
              'Actual diary must replace the recipe sheet',
            );
            expect(
              GoRouterState.of(
                tester.element(find.byType(DailyLogPage)),
              ).uri.path,
              '/daily-log',
            );
            final searchEntry = find.byKey(
              const Key('daily-meal-food-search-bar'),
            );
            final search =
                tester.widget<SearchBar>(searchEntry).controller!
                    as SearchController;
            await _until(tester, () => search.isOpen, 'Actual diary search');
            expect(search.text, 'Bean and salad wrap');
            expect(find.byType(SearchBar).hitTestable(), findsWidgets);
            expect(
              await tester.runAsync(
                () => database.select(database.meals).get(),
              ),
              isEmpty,
            );
            expect(
              await tester.runAsync(
                () => database.select(database.mealItems).get(),
              ),
              isEmpty,
            );
            search.closeView(null);
            await tester.pumpAndSettle();
            final back = find.byKey(const Key('daily-meal-detail-back'));
            expect(back.hitTestable(), findsOneWidget);
            await tester.tap(back);
            await _until(
              tester,
              () => find.byType(MealPlannerPage).evaluate().isNotEmpty,
              'Cancel returns to the real Meal Planner',
            );
            expect(
              GoRouterState.of(
                tester.element(find.byType(MealPlannerPage)),
              ).uri.path,
              '/meal-planner',
            );
            expect(find.byType(DailyLogPage), findsNothing);
            expect(find.byType(ErrorWidget), findsNothing);
            expect(tester.takeException(), isNull);
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 100));
        }
      });
    }
  }
}
