import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/services/settings_store.dart';
import 'package:body_intelligence_log/app/router/bil_quick_add_sheet.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/analytics/analytics_page.dart';
import 'package:body_intelligence_log/features/auth/account_gateway_page.dart';
import 'package:body_intelligence_log/features/auth/auth_language_selector.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_collection_item_gate.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_label_badge.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_nutrition_glass.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_page.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:body_intelligence_log/features/life_context/providers/life_context_provider.dart';
import 'package:body_intelligence_log/features/nutrition/food_page.dart';
import 'package:body_intelligence_log/features/nutrition_plans/presentation/nutrition_pathways_page.dart';
import 'package:body_intelligence_log/features/profile/profile_summary_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/premium_meal_features_page.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  testWidgets('auth language selector reflects the saved Arabic locale', (
    tester,
  ) async {
    final settingsService = AppSettingsService(store: _MemorySettingsStore());
    await settingsService.save(
      AppSettings(localeCode: 'ar', themeMode: 'light'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsServiceProvider.overrideWithValue(settingsService),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: Center(child: AuthLanguageSelector())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('auth-language-selector-label')))
          .data,
      'العربية',
    );
    expect(find.text('English'), findsNothing);
  });

  testWidgets('Arabic account gateway actions inherit a real Arabic family', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final settingsService = AppSettingsService(store: _MemorySettingsStore());
    await settingsService.save(
      AppSettings(localeCode: 'ar', themeMode: 'light'),
    );
    final router = GoRouter(
      initialLocation: '/gateway',
      routes: [
        GoRoute(
          path: '/gateway',
          builder: (_, _) => const AccountGatewayPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('login')),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const Scaffold(body: Text('onboarding')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsServiceProvider.overrideWithValue(settingsService),
          databaseProvider.overrideWithValue(database),
          validRecoverySnapshotProvider.overrideWith((_) async => false),
          userProfileProvider.overrideWith((_) => Stream.value(null)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          theme: ThemeData(useMaterial3: true, fontFamily: 'ArabicEvidence'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester
          .widget<Text>(find.byKey(const Key('auth-language-selector-label')))
          .data,
      'العربية',
    );
    final accountAction = tester.widget<FilledButton>(
      find.byKey(const Key('gateway-account-action')),
    );
    final localAction = tester.widget<TextButton>(
      find.byKey(const Key('gateway-continue-locally')),
    );
    expect(
      accountAction.style?.textStyle
          ?.resolve(const <WidgetState>{})
          ?.fontFamily,
      'ArabicEvidence',
    );
    expect(
      localAction.style?.textStyle?.resolve(const <WidgetState>{})?.fontFamily,
      'ArabicEvidence',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
    await database.close();
    await tester.pump();
  });

  testWidgets('one page-level glass group renders at most one Premium label', (
    tester,
  ) async {
    final free = SubscriptionState(
      plan: CommercePlan.free,
      entitlements: const {},
      authority: EntitlementAuthority.verifiedServer,
      isPurchasable: true,
      canRestorePurchases: true,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Column(
              children: [
                PremiumNutritionGlass(child: SizedBox(height: 64, width: 280)),
                PremiumNutritionGlass(
                  showLabel: false,
                  child: SizedBox(height: 64, width: 280),
                ),
                PremiumNutritionGlass(
                  showLabel: false,
                  child: SizedBox(height: 64, width: 280),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/plans',
          builder: (_, _) => const Scaffold(body: Text('plans')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verifiedSubscriptionStateProvider.overrideWithValue(AsyncData(free)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Premium').hitTestable(), findsOneWidget);
    expect(find.byKey(const Key('premium-nutrition-glass')), findsNWidgets(3));
  });

  testWidgets(
    'a paid collection route keeps one page label over all locked previews',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Column(
                children: [
                  const PremiumLabelBadge(),
                  for (var index = 0; index < 3; index++)
                    SizedBox(
                      width: 280,
                      height: 64,
                      child: PremiumCollectionItemGate(
                        locked: true,
                        tier: 'BIL PREMIUM',
                        showLabel: false,
                        onUpgrade: () {},
                        child: Text('Locked preview $index'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      _expectAtMostOneVisiblePremium(tester);
      expect(find.text('Premium'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('premium-collection-upgrade')),
        findsNWidgets(3),
      );
    },
  );

  testWidgets(
    'real daily log, meal, food, analytics and dashboard routes never show '
    'more than one Premium word',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Future<void> verifyRoute(
        Widget page, {
        required Key readyKey,
        Offset? scrollBy,
      }) async {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => page),
            GoRoute(
              path: '/plans',
              builder: (_, _) => const Scaffold(body: Text('plans')),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              verifiedSubscriptionStateProvider.overrideWithValue(
                AsyncData(_verifiedFreeState()),
              ),
              weightHistoryProvider.overrideWith((_) => Stream.value(const [])),
              allMealsProvider.overrideWith((_) => Stream.value(const [])),
              allWaterProvider.overrideWith((_) => Stream.value(const [])),
              dashboardDailyLogsProvider.overrideWith(
                (_) => Stream.value(const []),
              ),
              insightLifeContextProvider.overrideWith(
                (_) => Stream.value(const []),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            ),
          ),
        );
        await tester.pump();
        for (var attempt = 0; attempt < 20; attempt++) {
          if (find.byKey(readyKey).evaluate().isNotEmpty) break;
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          find.byKey(readyKey),
          findsOneWidget,
          reason:
              'Route ${page.runtimeType} did not reach ready state. '
              'Visible text: ${tester.widgetList<Text>(find.byType(Text)).map((item) => item.data ?? item.textSpan?.toPlainText()).whereType<String>().toList()}',
        );
        _expectAtMostOneVisiblePremium(tester);
        if (scrollBy != null) {
          await tester.drag(find.byType(Scrollable).first, scrollBy);
          await tester.pump();
          _expectAtMostOneVisiblePremium(tester);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        router.dispose();
        await database.close();
        await tester.pump();
      }

      await verifyRoute(
        const DailyLogPage(),
        readyKey: const Key('daily-log-today-summary'),
        scrollBy: const Offset(0, -460),
      );
      await verifyRoute(
        const DailyLogPage(initialMealType: 'breakfast', focusMealEntry: true),
        readyKey: const Key('daily-meal-detail-premium-group'),
      );
      await verifyRoute(
        const FoodPage(),
        readyKey: const Key('food-barcode-premium-group'),
      );
      await verifyRoute(
        const AnalyticsPage(),
        readyKey: const Key('analytics-range-thirtyDays'),
        scrollBy: const Offset(0, -460),
      );

      final dashboardRouter = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: PremiumDashboardBenchmark(
                arabic: false,
                actionTitle: '',
                actionReason: '',
                actionEvidence: '',
                confidence: '',
                onAction: null,
                dailyIntelligence: SizedBox.shrink(),
                bodyTwinSummary: '',
                bodyTwinEvidence: '',
                nutritionSummary: '',
                nutritionEvidence: '',
                trendSummary: '',
                trendEvidence: '',
                loggingItems: [],
                caloriesGoal: 2000,
                proteinConsumed: 40,
                proteinGoal: 100,
                carbohydratesConsumed: 80,
                carbohydratesGoal: 200,
                fatConsumed: 30,
                fatGoal: 60,
                fiberEvidenceValue: 12,
                fiberGoal: 30,
                sodiumEvidenceValue: 800,
                sodiumGoal: 2300,
                nutrientDashboardPreset: 'Heart healthy',
                visibleSections: {
                  DashboardSectionIds.calories,
                  DashboardSectionIds.macros,
                },
                premiumUnlocked: false,
              ),
            ),
          ),
          GoRoute(
            path: '/plans',
            builder: (_, _) => const Scaffold(body: Text('plans')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            verifiedSubscriptionStateProvider.overrideWithValue(
              AsyncData(_verifiedFreeState()),
            ),
          ],
          child: MaterialApp.router(routerConfig: dashboardRouter),
        ),
      );
      await tester.pumpAndSettle();
      _expectAtMostOneVisiblePremium(tester);
      await tester.drag(
        find.byKey(const Key('dashboard-calories-macros-horizontal')),
        const Offset(320, 0),
      );
      await tester.pumpAndSettle();
      _expectAtMostOneVisiblePremium(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      dashboardRouter.dispose();
    },
  );

  testWidgets(
    'connected health route renders one glass group without repeated Premium',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            connectedHealthGatewayProvider.overrideWithValue(
              const _PremiumOnceHealthGateway(),
            ),
            verifiedSubscriptionStateProvider.overrideWithValue(
              AsyncData(_verifiedFreeState()),
            ),
          ],
          child: const MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: ConnectedHealthPage(),
          ),
        ),
      );
      // The route owns a live clock/pulse. Resolve its immediate providers
      // without pumpAndSettle, which is intentionally impossible here.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(
        find.byKey(const Key('fitness-devices-premium-gate')),
        360,
      );
      _expectAtMostOneVisiblePremium(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await database.close();
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  testWidgets('quick add, profile, pathways, meal settings and route glass '
      'each render at most one visible Premium word', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> clear() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    Widget localizedApp(Widget home) => MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: BilQuickAddSheet(
            onFood: () {},
            onBarcode: () {},
            onVoice: () {},
            onPhoto: () {},
            onExercise: () {},
            onNotes: () {},
            onSearch: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _expectAtMostOneVisiblePremium(tester);
    await clear();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeNutritionPathwayProvider.overrideWithValue(
            const AsyncData(null),
          ),
        ],
        child: localizedApp(const NutritionPathwaysPage()),
      ),
    );
    await tester.pumpAndSettle();
    _expectAtMostOneVisiblePremium(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -480));
    await tester.pump();
    _expectAtMostOneVisiblePremium(tester);
    await clear();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((_) => Stream.value(null)),
          weightHistoryProvider.overrideWith((_) => Stream.value(const [])),
          measurementSystemProvider.overrideWith(
            (_) => Stream.value(MeasurementSystem.metric),
          ),
          profileMemberSinceProvider.overrideWithValue(null),
          profileFriendsCountProvider.overrideWith((_) async => null),
          displayNameProvider.overrideWith((_) => Stream.value('BIL member')),
          profilePhotoProvider.overrideWith((_) => Stream.value(null)),
          profilePhotoPublicUrlProvider.overrideWith((_) async => null),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(_verifiedFreeState()),
          ),
        ],
        child: localizedApp(const ProfileSummaryPage()),
      ),
    );
    await tester.pumpAndSettle();
    _expectAtMostOneVisiblePremium(tester);
    await clear();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(_verifiedFreeState()),
          ),
        ],
        child: localizedApp(const MealCalorieGoalsPage()),
      ),
    );
    await tester.pumpAndSettle();
    _expectAtMostOneVisiblePremium(tester);
    await clear();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(_verifiedFreeState()),
          ),
          storefrontTargetPlanProvider.overrideWith(
            (_) async => CommercePlan.premium,
          ),
        ],
        child: localizedApp(
          const PremiumRouteGlassGate(
            feature: PremiumGateFeature.weeklyReport,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _expectAtMostOneVisiblePremium(tester);
  });

  test('confirmed visual defects stay closed in production source', () {
    final account = source(
      'lib/features/auth/premium_account_gateway_page.dart',
    );
    final mealEntry = source(
      'lib/features/daily_log/daily_log_meal_entry.dart',
    );
    final mealSummary = source(
      'lib/features/daily_log/presentation/daily_log_summary_widgets.dart',
    );
    final mealList = source(
      'lib/features/daily_log/presentation/daily_log_meals_list.dart',
    );
    final foodOverview = source(
      'lib/features/nutrition/presentation/food_catalog_overview.dart',
    );
    final foodNutrients = source(
      'lib/features/nutrition/presentation/food_nutrient_values.dart',
    );
    final dashboard = source(
      'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
    );
    final dashboardPreferences = source(
      'lib/features/dashboard/presentation/dashboard_preferences_actions.dart',
    );
    final dashboardLock = source(
      'lib/features/dashboard/widgets/premium_dashboard_card_lock.dart',
    );
    final settings = source('lib/features/settings/settings_page.dart');
    final referenceSettings = source(
      'lib/features/settings/reference_settings_home_page.dart',
    );
    final nutritionPathways = source(
      'lib/features/nutrition_plans/presentation/nutrition_pathways_page.dart',
    );
    final quickAdd = source('lib/app/router/bil_quick_add_sheet.dart');
    final profileSummary = source(
      'lib/features/profile/profile_summary_page.dart',
    );
    final connectedHealthPage = source(
      'lib/features/connected_health/connected_health_page.dart',
    );
    final routeGlass = source(
      'lib/features/commerce/presentation/premium_route_glass_gate.dart',
    );
    final connectedHealth = source(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    );
    final mealFeatureGate = source(
      'lib/features/settings/premium_meal_features_page.dart',
    );
    final communityPeople = source(
      'lib/features/community/presentation/community_people_page.dart',
    );
    final communityConnections = source(
      'lib/features/community/presentation/community_connections_page.dart',
    );
    final analytics = source('lib/features/analytics/analytics_page.dart');
    final onboarding = source(
      'lib/features/onboarding/onboarding_runtime_copy.dart',
    );
    final recipes = source(
      'lib/features/wellness/presentation/recipe_library_helpers.dart',
    );
    final recipePage = source(
      'lib/features/wellness/presentation/recipe_library_page.dart',
    );
    final workoutLibrary = source(
      'lib/features/wellness/presentation/bil_workout_routines_library.dart',
    );
    final workoutList = source(
      'lib/features/wellness/presentation/bil_workout_routines_list.dart',
    );
    final workoutDetails = source(
      'lib/features/wellness/presentation/bil_workout_routine_details.dart',
    );
    final goldenHarness = source(
      'test/visual_closure/actual_production_pages_golden_test.dart',
    );
    final sleepPage = source(
      'lib/features/wellness/presentation/sleep_tracker_page.dart',
    );
    final sleepExperience = source(
      'lib/features/wellness/presentation/sleep_tracker_experience.dart',
    );

    expect(account, contains('textTheme.labelLarge?.fontFamily'));
    expect(account, isNot(contains("? 'BILArabic'")));
    expect(mealEntry, contains("Key('daily-meal-food-search-bar')"));
    expect(mealEntry, contains('leading: const Icon(Icons.search)'));
    expect(mealEntry, contains("hintText: _mealCopy('searchFoods')"));
    expect(onboarding, contains('"ar": "بماذا تحب أن يناديك BIL؟"'));

    expect(recipes, contains('Wrap('));
    expect(recipes, contains("Key('recipe-category-\$value')"));
    expect(recipes, isNot(contains('scrollDirection: Axis.horizontal')));
    expect(recipes, contains("Key('recipe-premium-page-label')"));
    expect(recipePage, contains('showLabel: false'));
    expect(workoutLibrary, contains('premiumUnlocked: premiumUnlocked'));
    expect(workoutLibrary, contains('onUpgrade: openPremium'));
    expect(
      workoutList,
      contains("ValueKey('workout-section-premium-\$title')"),
    );
    expect(
      workoutList,
      contains("ValueKey('workout-premium-gate-\${item.stableId}')"),
    );
    expect(workoutLibrary, contains("'Wellness programs'"));
    expect(workoutLibrary, isNot(contains("'Premium wellness programs'")));
    expect(workoutList, contains('showLabel: false'));
    expect(workoutList, isNot(contains('class _LockedBadge')));
    expect(workoutList, isNot(contains('Icons.lock_rounded')));
    expect(RegExp('PremiumLabelBadge\\(').allMatches(workoutDetails).length, 1);
    expect(workoutDetails, isNot(contains('Icons.lock_rounded')));
    expect(workoutDetails, isNot(contains('Icons.lock_open_rounded')));

    expect(foodOverview, contains("Key('food-barcode-premium-group')"));
    expect(foodOverview, contains("Key('food-add-barcode-premium-group')"));
    expect(foodOverview, isNot(contains('Scan · Premium')));
    expect(foodOverview, isNot(contains('Barcode · Premium')));
    expect(foodNutrients, contains('showLabel: false'));
    expect(mealEntry, contains("Key('daily-log-food-premium-group')"));
    expect(mealEntry, isNot(contains("Key('daily-log-food-macros-glass')")));
    expect(
      mealEntry,
      isNot(contains("Key('daily-log-nutrition-facts-glass')")),
    );
    expect(mealSummary, contains("Key('daily-meal-detail-premium-group')"));
    expect(
      mealList,
      matches(
        RegExp(
          r"Key\('daily-meal-macros-\$type'\),\s*compact: true,\s*showLabel: false",
        ),
      ),
    );
    expect(dashboard, isNot(contains("tr('Premium nutrient goals'")));
    expect(dashboard, isNot(contains("tr('Premium heart health'")));
    expect(dashboard, contains("Key('dashboard-premium-page-label')"));
    expect(RegExp('showLabel: false').allMatches(dashboard).length, 2);
    expect(dashboardLock, contains('this.showLabel = true'));
    expect(dashboardLock, isNot(contains('Icons.lock_rounded')));
    expect(
      dashboardPreferences,
      contains("Key('dashboard-nutrient-glass-group')"),
    );
    expect(dashboardPreferences, isNot(contains('Icons.lock_outline_rounded')));
    expect(
      RegExp('PremiumLabelBadge\\(').allMatches(nutritionPathways).length,
      1,
    );
    expect(nutritionPathways, isNot(contains("premium ? 'Premium'")));
    expect(nutritionPathways, isNot(contains('Icons.lock_rounded')));
    expect(settings, contains("copy('Start 7-day free trial')"));
    expect(settings, contains("copy('Active')"));
    expect(settings, isNot(contains("copy('Explore Premium')")));
    expect(referenceSettings, contains("copy('BIL Premium')"));
    expect(referenceSettings, contains("copy('Start 7-day free trial')"));
    expect(referenceSettings, isNot(contains("copy('Explore Premium')")));
    expect(
      RegExp("_text\\(context, 'Premium'\\)").allMatches(quickAdd).length,
      1,
    );
    expect(
      RegExp(
        "child: Text\\(_copy\\(context, 'Go Premium'\\)\\)",
      ).allMatches(profileSummary).length,
      1,
    );
    expect(
      RegExp(
        'PremiumDashboardCardLock\\(',
      ).allMatches(connectedHealthPage).length,
      1,
    );
    expect(routeGlass, isNot(contains("title: t('Premium")));
    expect(routeGlass, isNot(contains("body: t('Premium")));
    expect(
      analytics,
      matches(
        RegExp(
          r"Key\('analytics-daily-nutrition-premium-glass'\),\s*showLabel: false",
        ),
      ),
    );
    expect(connectedHealth, contains('var premiumLabelAvailable = true'));
    expect(connectedHealth, contains('showLabel: showPremiumLabel'));
    expect(
      mealFeatureGate,
      isNot(
        contains(
          "Text(\n                    _copy(context, 'This is an independent Premium feature.')",
        ),
      ),
    );
    expect(communityPeople, isNot(contains('PremiumLabelBadge')));
    expect(communityConnections, isNot(contains('PremiumLabelBadge')));

    expect(
      goldenHarness,
      contains('liveHealthNowProvider.overrideWithValue(() => _visualNow)'),
    );
    expect(
      goldenHarness,
      contains('sleepNowProvider.overrideWithValue(() => _visualNow)'),
    );
    expect(sleepPage, isNot(contains('DateTime.now()')));
    expect(sleepExperience, isNot(contains('DateTime.now()')));
  });

  test('AI Coach product copy does not promise unsupported languages', () {
    final sourceText = [
      source('lib/features/commerce/presentation/bil_store_copy.dart'),
      source(
        'lib/features/commerce/presentation/premium_route_glass_gate.dart',
      ),
      source(
        'lib/features/intelligence_center/presentation/intelligence_center_widgets.dart',
      ),
      source('lib/app/localization/runtime_copy_core_pages.dart'),
    ].join('\n').toLowerCase();

    expect(sourceText, isNot(contains('every language')));
    expect(sourceText, isNot(contains('speak any language')));
    expect(sourceText, isNot(contains('all languages')));
    expect(sourceText, contains('multilingual'));
  });
}

SubscriptionState _verifiedFreeState() => SubscriptionState(
  plan: CommercePlan.free,
  entitlements: const {},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: true,
  canRestorePurchases: true,
);

void _expectAtMostOneVisiblePremium(WidgetTester tester) {
  final premiumWord = RegExp(
    r'(?<![A-Za-z])Premium(?![A-Za-z])',
    caseSensitive: false,
  );
  final logicalViewport = Rect.fromLTWH(
    0,
    0,
    tester.view.physicalSize.width / tester.view.devicePixelRatio,
    tester.view.physicalSize.height / tester.view.devicePixelRatio,
  );
  var count = 0;
  final visibleCopy = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize ||
        renderObject.size.isEmpty) {
      continue;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final bottomRight = renderObject.localToGlobal(
      renderObject.size.bottomRight(Offset.zero),
    );
    if (!logicalViewport.overlaps(Rect.fromPoints(topLeft, bottomRight))) {
      continue;
    }
    final text = element.widget as Text;
    final copy = text.data ?? text.textSpan?.toPlainText() ?? '';
    final occurrences = premiumWord.allMatches(copy).length;
    if (occurrences == 0) continue;
    count += occurrences;
    visibleCopy.add(copy);
  }
  expect(
    count,
    lessThanOrEqualTo(1),
    reason: 'Route rendered repeated visible Premium copy: $visibleCopy',
  );
}

final class _PremiumOnceHealthGateway implements ConnectedHealthGateway {
  const _PremiumOnceHealthGateway();

  ConnectedHealthSnapshot get _snapshot => const ConnectedHealthSnapshot(
    status: ConnectedHealthStatus.synchronized,
    platformSource: 'Health Connect',
    availableSources: ['Health Connect'],
    signals: [],
    importedCount: 0,
    lastSyncAt: null,
    failureCode: null,
  );

  @override
  Future<ConnectedHealthSnapshot> load() async => _snapshot;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async => _snapshot;

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      _snapshot;

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async => _snapshot;

  @override
  Future<ConnectedHealthSnapshot> synchronize() async => _snapshot;
}

final class _MemorySettingsStore implements SettingsStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async => _value = value;
}
