import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/analytics/analytics_page.dart';
import 'package:body_intelligence_log/features/analytics/nutrition_analytics_page.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/daily_check_in/daily_check_in_page.dart';
import 'package:body_intelligence_log/features/dashboard/dashboard_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/nutrition/providers/meal_vision_usage_provider.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_vision_usage_contract.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/food_page.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/food_barcode_scanner_page.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/history/progress_page.dart';
import 'package:body_intelligence_log/features/profile/premium_profile_page.dart';
import 'package:body_intelligence_log/features/profile/profile_summary_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/settings/settings_page.dart';
import 'package:body_intelligence_log/features/settings/local_export_range_page.dart';
import 'package:body_intelligence_log/features/settings/reference_goals_page.dart';
import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';
import 'package:body_intelligence_log/features/settings/sharing_privacy_settings_page.dart';
import 'package:body_intelligence_log/features/settings/account_password_page.dart';
import 'package:body_intelligence_log/features/settings/account_connection_settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'visual_evidence_font.dart';

final class _UnavailableHealthGateway implements ConnectedHealthGateway {
  const _UnavailableHealthGateway();

  @override
  Future<ConnectedHealthSnapshot> load() async =>
      const ConnectedHealthSnapshot.unavailable();

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() => load();

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() => load();

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() => load();

  @override
  Future<ConnectedHealthSnapshot> synchronize() => load();
}

final class _VisualRouteStack extends StatelessWidget {
  const _VisualRouteStack({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Navigator(
    pages: [
      const MaterialPage<void>(child: Scaffold(body: SizedBox.shrink())),
      MaterialPage<void>(child: child),
    ],
    onDidRemovePage: (_) {},
  );
}

void main() {
  setUpAll(loadVisualEvidenceFont);

  void setExplicitLightSettings() {
    SharedPreferences.setMockInitialValues({
      'bil_app_settings':
          '{"localeCode":"en","themeMode":"light",'
          '"highContrast":false,"reduceMotion":false}',
    });
  }

  Future<AppDatabase> database(
    WidgetTester tester, {
    bool profile = false,
    bool autoClose = true,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    if (autoClose) addTearDown(db.close);
    if (profile) {
      await UserProfileRepository(db).save(
        gender: 'male',
        age: 35,
        height: 181,
        currentWeight: 93.4,
        targetWeight: 85,
        activityLevel: 'light',
        exercises: true,
      );
    }
    return db;
  }

  List<MealWithItems> evidencedNutritionMeals() {
    final recordedAt = DateTime(2026, 8, 14, 8, 15);
    final mask = NutrientEvidenceMask.fromValues(
      calories: 620,
      protein: 34,
      carbohydrates: 71,
      fat: 19,
      fiber: 8,
      sodium: 540,
      sugar: 12,
    );
    return [
      MealWithItems(
        meal: Meal(
          id: 1,
          uuid: 'qa-nutrition-meal',
          date: DateTime(2026, 8, 14),
          dayKey: '2026-08-14',
          name: 'Breakfast',
          type: 'breakfast',
          createdAt: recordedAt,
          updatedAt: recordedAt,
          deletedAt: null,
          revision: 1,
          syncStatus: 'local',
        ),
        items: [
          MealItem(
            id: 1,
            uuid: 'qa-nutrition-item',
            mealId: 1,
            foodId: 1,
            quantity: 1,
            position: 0,
            calories: 620,
            protein: 34,
            carbs: 71,
            fats: 19,
            fiber: 8,
            sodium: 540,
            potassium: 0,
            calcium: 0,
            magnesium: 0,
            phosphorus: 0,
            sugar: 12,
            nutrientEvidenceMask: mask,
            foodSourceSnapshot: 'BIL QA evidence fixture',
            foodVerifiedSnapshot: false,
            servingSizeSnapshot: 1,
            servingUnitSnapshot: 'serving',
            createdAt: recordedAt,
            updatedAt: recordedAt,
            deletedAt: null,
            revision: 1,
            syncStatus: 'local',
          ),
        ],
        foodsById: const {},
      ),
    ];
  }

  Future<void> capture(
    WidgetTester tester, {
    required Widget page,
    required AppDatabase db,
    required String name,
    bool seedEmptyCatalog = false,
    bool captureTopmostScaffold = false,
    bool captureOverlay = false,
    bool finiteSettle = false,
    Future<void> Function(WidgetTester tester)? prepare,
    Food? foodOverride,
    bool stableDailyLog = false,
    List<MealWithItems>? dailyMealsOverride,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dashboardClockProvider.overrideWithValue(
            () => DateTime(2026, 8, 5, 9, 41, 12),
          ),
          connectedHealthGatewayProvider.overrideWithValue(
            const _UnavailableHealthGateway(),
          ),
          mealVisionUsageProvider.overrideWithValue(
            const AsyncData(MealVisionUsageSnapshot.unavailable()),
          ),
          liveHealthNowProvider.overrideWithValue(
            () => DateTime(2026, 8, 5, 9, 41, 12),
          ),
          progressClockProvider.overrideWithValue(
            () => DateTime(2026, 8, 14, 9, 41, 12),
          ),
          if (seedEmptyCatalog || stableDailyLog)
            seedCatalogProvider.overrideWith((ref) async {}),
          if (foodOverride != null)
            foodsProvider.overrideWithValue(AsyncData(<Food>[foodOverride])),
          if (foodOverride != null)
            foodRuntimeSearchAuthorityProvider.overrideWithValue(
              FoodRuntimeSearchAuthority(
                FoodRepository(db),
                catalogResolver: () async => null,
              ),
            ),
          if (stableDailyLog) ...[
            selectedLogDateProvider.overrideWith(
              (ref) => DateTime(2026, 8, 14),
            ),
            dailyMealsProvider.overrideWithValue(
              const AsyncData(<MealWithItems>[]),
            ),
            dailyWaterProvider.overrideWithValue(
              const AsyncData(<WaterEntry>[]),
            ),
            usualMealsProvider(
              'breakfast',
            ).overrideWithValue(const AsyncData(<UsualMealCandidate>[])),
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
            waterRepositoryProvider.overrideWithValue(WaterRepository(db)),
            measurementSystemProvider.overrideWithValue(
              const AsyncData(MeasurementSystem.metric),
            ),
          ],
          if (dailyMealsOverride != null) ...[
            selectedLogDateProvider.overrideWith(
              (ref) => DateTime(2026, 8, 14),
            ),
            dailyMealsProvider.overrideWithValue(AsyncData(dailyMealsOverride)),
            userProfileProvider.overrideWithValue(const AsyncData(null)),
          ],
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: visualEvidenceTheme(BilFlagshipTheme.light()),
          builder: (context, child) => visualEvidenceTextSurface(child),
          home: page,
        ),
      ),
    );
    if (finiteSettle) {
      await tester.pump(const Duration(milliseconds: 600));
    } else {
      await tester.pumpAndSettle();
    }
    if (prepare != null) {
      await prepare(tester);
      if (finiteSettle) {
        await tester.pump(const Duration(milliseconds: 300));
      } else {
        await tester.pumpAndSettle();
      }
    }
    await settleVisualAssetImages(tester);
    if (finiteSettle) {
      await tester.pump(const Duration(milliseconds: 300));
    } else {
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      captureOverlay
          ? find.byType(Overlay).first
          : captureTopmostScaffold
          ? find.byType(Scaffold).last
          : find.byType(Scaffold).first,
      matchesGoldenFile('goldens/visual_closure_$name.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
  }

  testWidgets('food catalog production empty state capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const FoodPage(),
      db: db,
      name: 'food_catalog_phone',
      seedEmptyCatalog: true,
    );
  });

  testWidgets('daily log repository food search production capture', (
    tester,
  ) async {
    final db = await database(tester);
    final repository = FoodRepository(db);
    final foodId = await repository.addFood(
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
    await repository.recordRecent(foodId);
    final food = (await db.select(db.foods).get()).singleWhere(
      (candidate) => candidate.id == foodId,
    );
    await capture(
      tester,
      page: const DailyLogPage(initialMealType: 'breakfast'),
      db: db,
      name: 'food_meal_search_phone',
      seedEmptyCatalog: true,
      foodOverride: food,
      stableDailyLog: true,
      captureOverlay: true,
      prepare: (tester) async {
        final logFood = find.byKey(const Key('daily-meal-log-breakfast'));
        await tester.ensureVisible(logFood);
        await tester.tap(logFood);
        await tester.pumpAndSettle();
        final searchBar = find.byType(SearchBar).last;
        await tester.enterText(searchBar, 'Plain Greek');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.text('Plain Greek yogurt'), findsOneWidget);
      },
    );
  });

  const catalogStates = <(String, String)>[
    ('favorites', 'Favorites'),
    ('recent', 'Recent'),
  ];
  for (final state in catalogStates) {
    testWidgets('food catalog ${state.$1} production state capture', (
      tester,
    ) async {
      final db = await database(tester);
      await capture(
        tester,
        page: const FoodPage(),
        db: db,
        name: 'food_catalog_${state.$1}_phone',
        seedEmptyCatalog: true,
        prepare: (tester) async {
          await tester.tap(find.text(state.$2));
          await tester.pumpAndSettle();
          expect(
            find.text(
              state.$1 == 'favorites'
                  ? 'Your favorites will stay one tap away'
                  : 'Recent foods appear after your first log',
            ),
            findsOneWidget,
          );
        },
      );
    });
  }

  for (final state in <(String, String?)>[
    ('verified_result', null),
    ('favorite_result', 'Favorites'),
    ('recent_result', 'Recent'),
  ]) {
    testWidgets('food catalog ${state.$1} production capture', (tester) async {
      final db = await database(tester);
      final repository = FoodRepository(db);
      final foodId = await repository.addFood(
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
      if (state.$2 == 'Favorites') await repository.setFavorite(foodId, true);
      if (state.$2 == 'Recent') await repository.recordRecent(foodId);
      if (state.$2 == 'Favorites') {
        expect((await repository.watchFavorites().first).single.id, foodId);
      }
      if (state.$2 == 'Recent') {
        expect((await repository.watchRecent().first).single.id, foodId);
      }
      await capture(
        tester,
        page: const FoodPage(),
        db: db,
        name: 'food_catalog_${state.$1}_phone',
        seedEmptyCatalog: true,
        prepare: state.$2 == null
            ? null
            : (tester) async {
                await tester.tap(find.text(state.$2!));
                await tester.pump(const Duration(milliseconds: 300));
              },
      );
    });
  }

  testWidgets('custom food production form capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const FoodPage(),
      db: db,
      name: 'custom_food_phone',
      seedEmptyCatalog: true,
      captureOverlay: true,
      prepare: (tester) async {
        await tester.tap(find.text('Custom food').first);
      },
    );
  });

  testWidgets('dashboard production populated phone capture', (tester) async {
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: const DashboardPage(),
      db: db,
      name: 'dashboard_phone',
    );
  });

  testWidgets('dashboard persisted nutrient goal card capture', (tester) async {
    final db = await database(tester, profile: true);
    await PreferencesRepository(
      db,
    ).setMany({'dashboard.nutrientGoalCards': 'fiber', 'goal.fiber': '30'});
    await capture(
      tester,
      page: const DashboardPage(),
      db: db,
      name: 'dashboard_nutrient_goal_card_phone',
      prepare: (tester) async {
        final card = find.byKey(const Key('dashboard-nutrient-card-fiber'));
        await tester.scrollUntilVisible(
          card,
          600,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        expect(card, findsOneWidget);
      },
    );
  });

  testWidgets('AI Coach conversation production phone capture', (tester) async {
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: ProviderScope(
        overrides: [
          coachContextSnapshotProvider.overrideWith(
            (ref) async => CoachContextSnapshot.empty(),
          ),
        ],
        child: const IntelligenceCenterPage(),
      ),
      db: db,
      name: 'ai_coach_conversation_phone',
    );
  });

  for (var page = 2; page <= 3; page++) {
    testWidgets('dashboard production vertical module page $page capture', (
      tester,
    ) async {
      final db = await database(tester, profile: true);
      await capture(
        tester,
        page: const DashboardPage(),
        db: db,
        name: 'dashboard_phone_$page',
        prepare: (tester) async {
          for (var step = 1; step < page; step++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -500),
            );
            await tester.pumpAndSettle();
          }
        },
      );
    });
  }

  testWidgets('dashboard production steps trend capture', (tester) async {
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: const DashboardPage(),
      db: db,
      name: 'dashboard_phone_4',
      prepare: (tester) async {
        final rail = find.byKey(const Key('dashboard-reference-trend-rail'));
        await tester.ensureVisible(rail);
        await tester.pumpAndSettle();
        final pages = find.descendant(
          of: rail,
          matching: find.byType(PageView),
        );
        await tester.drag(pages, const Offset(-320, 0));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: rail, matching: find.text('Steps')).hitTestable(),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('dashboard production Macros overview capture', (tester) async {
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: const DashboardPage(),
      db: db,
      name: 'dashboard_phone_5',
      prepare: (tester) async {
        final carousel = find.byKey(
          const Key('dashboard-calories-macros-horizontal'),
        );
        await tester.ensureVisible(carousel);
        await tester.drag(carousel, const Offset(-320, 0));
        await tester.pumpAndSettle();
        final macros = find.byKey(const Key('dashboard-reference-macros-card'));
        expect(macros, findsOneWidget);
      },
    );
  });

  for (final state in const [(page: 6, swipes: 2, title: 'Heart Healthy')]) {
    testWidgets('dashboard production ${state.title} overview capture', (
      tester,
    ) async {
      final db = await database(tester, profile: true);
      await capture(
        tester,
        page: const DashboardPage(),
        db: db,
        name: 'dashboard_phone_${state.page}',
        prepare: (tester) async {
          final carousel = find.byKey(
            const Key('dashboard-calories-macros-horizontal'),
          );
          await tester.ensureVisible(carousel);
          await tester.pumpAndSettle();
          for (var swipe = 0; swipe < state.swipes; swipe++) {
            await tester.drag(carousel, const Offset(-320, 0));
            await tester.pumpAndSettle();
          }
          expect(
            find.descendant(of: carousel, matching: find.text(state.title)),
            findsOneWidget,
          );
        },
      );
    });
  }

  testWidgets('daily log production empty day capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const DailyLogPage(),
      db: db,
      name: 'daily_log_empty_phone',
      stableDailyLog: true,
    );
  });

  testWidgets('daily log production middle sections capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const DailyLogPage(),
      db: db,
      name: 'daily_log_sections_middle_phone',
      stableDailyLog: true,
      prepare: (tester) async {
        final waterSection = find.byKey(const Key('daily-log-water-section'));
        for (
          var attempt = 0;
          attempt < 6 && waterSection.evaluate().isEmpty;
          attempt++
        ) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -420),
          );
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(waterSection);
        await tester.pumpAndSettle();
        expect(waterSection, findsOneWidget);
      },
    );
  });

  testWidgets('daily log production lower sections capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const DailyLogPage(),
      db: db,
      name: 'daily_log_sections_lower_phone',
      stableDailyLog: true,
      prepare: (tester) async {
        final contextLink = find.byKey(
          const Key('daily-log-body-context-link'),
        );
        for (
          var attempt = 0;
          attempt < 9 && contextLink.evaluate().isEmpty;
          attempt++
        ) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -420),
          );
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(contextLink);
        await tester.pumpAndSettle();
        expect(contextLink, findsOneWidget);
      },
    );
  });

  testWidgets('daily log meal-entry production capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const DailyLogPage(focusMealEntry: true),
      db: db,
      name: 'daily_log_meal_entry_phone',
      stableDailyLog: true,
    );
  });

  testWidgets('daily log water-entry production capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const DailyLogPage(initialAction: 'water'),
      db: db,
      name: 'daily_log_water_entry_phone',
      stableDailyLog: true,
      prepare: (tester) async {
        final waterSection = find.byKey(const Key('daily-log-water-section'));
        for (
          var attempt = 0;
          attempt < 4 && waterSection.evaluate().isEmpty;
          attempt++
        ) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -520),
          );
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(waterSection);
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('meal-photo truthful unavailable production capture', (
    tester,
  ) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const DailyLogPage(initialAction: 'photo'),
      db: db,
      name: 'meal_photo_unavailable_phone',
      captureOverlay: true,
      finiteSettle: true,
      stableDailyLog: true,
      prepare: (tester) async {
        expect(find.text('Meal Scan'), findsOneWidget);
        expect(find.text('STEP 1 OF 4'), findsOneWidget);
        expect(find.text('Scan your entire meal'), findsOneWidget);
        final next = tester.widget<FilledButton>(
          find.byKey(const Key('meal-image-guide-next')),
        );
        expect(next.onPressed, isNull);
        expect(
          find.text('Analysis allowance is unavailable right now.'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('barcode scanner truthful unavailable production capture', (
    tester,
  ) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const FoodBarcodeScannerPage(scannerEnabled: false),
      db: db,
      name: 'barcode_unavailable_phone',
    );
  });

  testWidgets('analytics production empty state capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const AnalyticsPage(),
      db: db,
      name: 'analytics_empty_phone',
    );
  });

  testWidgets('progress production steps summary capture', (tester) async {
    final db = await database(tester);
    final logs = DailyLogRepository(db);
    final now = DateTime(2026, 8, 14, 9, 41, 12);
    await logs.save(date: now.subtract(const Duration(days: 8)), steps: 6400);
    await logs.save(date: now.subtract(const Duration(days: 4)), steps: 8200);
    await logs.save(date: now.subtract(const Duration(days: 1)), steps: 7100);
    await capture(
      tester,
      page: const ProgressPage(),
      db: db,
      name: 'progress_steps_month_phone',
      prepare: (tester) async {
        expect(find.text('Average'), findsOneWidget);
        expect(find.text('Entries'), findsOneWidget);
      },
    );
  });

  testWidgets('progress production range picker capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const ProgressPage(),
      db: db,
      name: 'progress_range_picker_phone',
      captureOverlay: true,
      prepare: (tester) async {
        await tester.tap(find.byKey(const Key('progress-range-selector')));
        await tester.pumpAndSettle();
        expect(find.text('Select a date range'), findsOneWidget);
      },
    );
  });

  testWidgets('progress production metric picker capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const ProgressPage(),
      db: db,
      name: 'progress_metric_picker_phone',
      captureOverlay: true,
      prepare: (tester) async {
        await tester.tap(find.byKey(const Key('progress-metric-selector')));
        await tester.pumpAndSettle();
        expect(find.text('Select a measurement'), findsOneWidget);
      },
    );
  });

  testWidgets('progress production lower metric picker capture', (
    tester,
  ) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const ProgressPage(),
      db: db,
      name: 'progress_metric_picker_lower_phone',
      captureOverlay: true,
      prepare: (tester) async {
        await tester.tap(find.byKey(const Key('progress-metric-selector')));
        await tester.pumpAndSettle();
        final thigh = find.text('Thigh');
        await tester.scrollUntilVisible(
          thigh,
          180,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(thigh, findsOneWidget);
      },
    );
  });

  testWidgets('progress production body measurement empty capture', (
    tester,
  ) async {
    final db = await database(tester);
    await capture(
      tester,
      page: const ProgressPage(),
      db: db,
      name: 'progress_body_empty_phone',
      prepare: (tester) async {
        await tester.tap(find.byKey(const Key('progress-metric-selector')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hips'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('progress-empty-add')), findsOneWidget);
      },
    );
  });

  testWidgets('analytics production recorded trend capture', (tester) async {
    final db = await database(tester, profile: true);
    final weights = WeightRepository(db);
    final now = DateTime.now();
    for (var day = 28; day >= 0; day -= 4) {
      await weights.addWeight(
        96 - ((28 - day) * 0.09),
        date: now.subtract(Duration(days: day)),
      );
    }
    await capture(
      tester,
      page: const AnalyticsPage(),
      db: db,
      name: 'analytics_progress_phone',
    );
  });

  for (final range in <(String, String)>[
    ('seven_days', '7 days'),
    ('all_time', 'All'),
  ]) {
    testWidgets('analytics production ${range.$1} range capture', (
      tester,
    ) async {
      final db = await database(tester, profile: true);
      final weights = WeightRepository(db);
      final now = DateTime.now();
      for (var day = 84; day >= 0; day -= 7) {
        await weights.addWeight(
          96 - ((84 - day) * 0.05),
          date: now.subtract(Duration(days: day)),
        );
      }
      await capture(
        tester,
        page: const AnalyticsPage(),
        db: db,
        name: 'analytics_${range.$1}_phone',
        prepare: (tester) async {
          await tester.tap(find.text(range.$2));
          await tester.pumpAndSettle();
        },
      );
    });
  }

  testWidgets('profile production populated state capture', (tester) async {
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: const PremiumProfilePage(),
      db: db,
      name: 'profile_phone',
    );
  });

  testWidgets('profile summary repository state capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: ProviderScope(
        overrides: [
          profileMemberSinceProvider.overrideWithValue(
            DateTime.utc(2026, 7, 1),
          ),
          profileFriendsCountProvider.overrideWith((ref) async => null),
        ],
        child: const ProfileSummaryPage(),
      ),
      db: db,
      name: 'profile_summary_phone',
      captureTopmostScaffold: true,
    );
  });

  testWidgets('profile goals production lower section capture', (tester) async {
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: ProviderScope(
        overrides: [
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
        ],
        child: Navigator(
          initialRoute: '/goals',
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => settings.name == '/goals'
                ? const ReferenceGoalsPage()
                : const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      ),
      db: db,
      name: 'profile_goals_phone',
      prepare: (tester) async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -430));
      },
    );
  });

  for (var page = 1; page <= 2; page++) {
    testWidgets('nutrition goals production capture page $page', (
      tester,
    ) async {
      final db = await database(tester, autoClose: false);
      await capture(
        tester,
        page: Navigator(
          initialRoute: '/nutrition-goals',
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => settings.name == '/nutrition-goals'
                ? const ReferenceNutritionGoalsPage()
                : const Scaffold(body: SizedBox.shrink()),
          ),
        ),
        db: db,
        name: page == 1 ? 'nutrition_goals_phone' : 'nutrition_goals_phone_2',
        finiteSettle: true,
        prepare: page == 1
            ? null
            : (tester) async {
                final lastGoal = find.text('Iron');
                await tester.scrollUntilVisible(
                  lastGoal,
                  320,
                  scrollable: find.byType(Scrollable).first,
                );
                await tester.pump(const Duration(milliseconds: 100));
                expect(lastGoal, findsOneWidget);
                expect(tester.takeException(), isNull);
              },
      );
      await db.close();
      await tester.pump(const Duration(milliseconds: 1));
    });
  }

  testWidgets('settings production phone capture', (tester) async {
    setExplicitLightSettings();
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: const SettingsPage(),
      db: db,
      name: 'settings_phone',
    );
  });

  for (final settingsState in <(String, Widget)>[
    ('appearance_phone', const ReferenceAppearancePage()),
    ('diary_settings_phone', const ReferenceDiarySettingsPage()),
    ('default_search_tab_phone', const ReferenceDiarySearchTabPage()),
    ('diary_sharing_phone', const ReferenceDiarySharingPage()),
    ('meal_names_phone', const ReferenceMealNamesPage()),
    ('sharing_privacy_phone', const SharingPrivacySettingsPage()),
    ('email_settings_phone', const ReferenceEmailSettingsPage()),
    ('account_password_phone', const AccountPasswordPage()),
    (
      'facebook_settings_phone',
      const AccountConnectionSettingsPage(
        provider: AccountConnectionProvider.facebook,
      ),
    ),
    (
      'google_settings_phone',
      const AccountConnectionSettingsPage(
        provider: AccountConnectionProvider.google,
      ),
    ),
  ]) {
    testWidgets('${settingsState.$1} production capture', (tester) async {
      SharedPreferences.setMockInitialValues({});
      setExplicitLightSettings();
      final db = await database(tester);
      await capture(
        tester,
        page: _VisualRouteStack(child: settingsState.$2),
        db: db,
        name: settingsState.$1,
        finiteSettle: true,
        prepare: (tester) async {
          expect(tester.takeException(), isNull);
        },
      );
    });
  }

  testWidgets('email_settings_lower_phone production capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    setExplicitLightSettings();
    final db = await database(tester);
    await capture(
      tester,
      page: const _VisualRouteStack(child: ReferenceEmailSettingsPage()),
      db: db,
      name: 'email_settings_lower_phone',
      finiteSettle: true,
      prepare: (tester) async {
        final lastPreference = find.text('Someone accepts my group invitation');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -320));
        await tester.pump(const Duration(milliseconds: 100));
        expect(lastPreference, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('More production top capture', (tester) async {
    setExplicitLightSettings();
    final db = await database(tester);
    await capture(
      tester,
      page: const SettingsPage(),
      db: db,
      name: 'more_phone',
      prepare: (tester) async {
        expect(find.text('BIL member'), findsOneWidget);
        expect(find.text('Explore Premium'), findsOneWidget);
      },
    );
  });

  testWidgets('More production lower capture', (tester) async {
    setExplicitLightSettings();
    final db = await database(tester);
    await capture(
      tester,
      page: const SettingsPage(),
      db: db,
      name: 'more_lower_phone',
      prepare: (tester) async {
        final sync = find.text('Sync');
        await tester.scrollUntilVisible(
          sync,
          420,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 52));
        await tester.pumpAndSettle();
        expect(sync, findsOneWidget);
      },
    );
  });

  for (var page = 2; page <= 5; page++) {
    testWidgets('settings production phone capture page $page', (tester) async {
      setExplicitLightSettings();
      final db = await database(tester, profile: true);
      await capture(
        tester,
        page: const SettingsPage(),
        db: db,
        name: 'settings_phone_$page',
        prepare: (tester) async {
          for (var step = 1; step < page; step++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -700),
            );
            await tester.pumpAndSettle();
          }
          if (page == 2) expect(find.text('Daylight'), findsOneWidget);
        },
      );
    });
  }

  for (var page = 6; page <= 9; page++) {
    testWidgets('settings production phone capture page $page', (tester) async {
      setExplicitLightSettings();
      final db = await database(tester, profile: true);
      await capture(
        tester,
        page: const SettingsPage(),
        db: db,
        name: 'settings_phone_$page',
        prepare: (tester) async {
          for (var step = 1; step < page; step++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -420),
            );
            await tester.pumpAndSettle();
          }
        },
      );
    });
  }

  for (final analyticsTab in const [
    (0, 'calories'),
    (1, 'nutrients'),
    (2, 'macros'),
  ]) {
    testWidgets('nutrition analytics ${analyticsTab.$2} capture', (
      tester,
    ) async {
      final db = await database(tester);
      await capture(
        tester,
        page: NutritionAnalyticsPage(initialTab: analyticsTab.$1),
        db: db,
        name: 'nutrition_analytics_${analyticsTab.$2}_phone',
        dailyMealsOverride: evidencedNutritionMeals(),
        prepare: (tester) async {
          expect(find.text('Nutrition'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    });
  }

  testWidgets('local export selected-day capture', (tester) async {
    final db = await database(tester);
    await capture(
      tester,
      page: _VisualRouteStack(
        child: LocalExportRangePage(
          initialFrom: DateTime(2026, 8, 14),
          initialTo: DateTime(2026, 8, 14),
        ),
      ),
      db: db,
      name: 'local_export_selected_day_phone',
      captureTopmostScaffold: true,
      prepare: (tester) async {
        expect(find.text('Export local data'), findsOneWidget);
        expect(find.text('Create CSV export'), findsOneWidget);
      },
    );
  });

  testWidgets('daily check-in production phone capture', (tester) async {
    final db = await database(tester, profile: true);
    await capture(
      tester,
      page: const DailyCheckInPage(),
      db: db,
      name: 'daily_check_in_phone',
      prepare: (tester) async {
        final action = find.byKey(const ValueKey('daily-check-in-save'));
        await tester.scrollUntilVisible(
          action,
          260,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(action);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -48));
        await tester.pumpAndSettle();
        expect(action, findsOneWidget);
      },
    );
  });
}
