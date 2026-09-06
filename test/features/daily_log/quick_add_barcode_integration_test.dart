import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:body_intelligence_log/app/services/runtime_permission_policy.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_capture_providers.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final class _GrantedCameraPolicy extends BilRuntimePermissionPolicy {
  const _GrantedCameraPolicy();

  @override
  Future<BilRuntimePermissionState> status(
    BilRuntimeCapability capability,
  ) async => BilRuntimePermissionState.granted;
}

void main() {
  testWidgets(
    'Quick Add opens the real Daily Log barcode flow every time it is selected',
    (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(
        () => database.close().timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        ),
      );
      final foodRepository = FoodRepository(database);
      final mealRepository = MealRepository(database);
      var scannerLaunches = 0;

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          ShellRoute(
            builder: (_, _, child) => ResponsiveAppShell(child: child),
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, _) =>
                    const Scaffold(body: Center(child: Text('real-dashboard'))),
              ),
              GoRoute(
                path: '/daily-log',
                builder: (_, state) => DailyLogPage(
                  initialAction: state.uri.queryParameters['action'],
                  returnPath: ResponsiveAppShell.safeQuickAddReturnPath(
                    state.uri.queryParameters['from'],
                  ),
                ),
              ),
              for (final path in const [
                '/nutrition',
                '/history',
                '/analytics',
                '/settings',
              ])
                GoRoute(
                  path: path,
                  builder: (_, _) => Scaffold(body: Text(path)),
                ),
            ],
          ),
          GoRoute(
            path: '/plans',
            builder: (_, _) => const Scaffold(body: Text('plans')),
          ),
        ],
      );
      addTearDown(router.dispose);

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
            foodsProvider.overrideWithValue(const AsyncData(<Food>[])),
            foodRepositoryProvider.overrideWithValue(foodRepository),
            mealRepositoryProvider.overrideWithValue(mealRepository),
            dailyWaterProvider.overrideWithValue(
              const AsyncData(<WaterEntry>[]),
            ),
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
            waterRepositoryProvider.overrideWithValue(
              WaterRepository(database),
            ),
            measurementSystemProvider.overrideWithValue(
              const AsyncData(MeasurementSystem.metric),
            ),
            dailyLogRuntimePermissionPolicyProvider.overrideWithValue(
              const _GrantedCameraPolicy(),
            ),
            dailyLogBarcodeScannerLauncherProvider.overrideWithValue((
              context,
            ) async {
              scannerLaunches += 1;
              return null;
            }),
          ],
          child: MaterialApp.router(
            locale: const Locale('en'),
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
      await tester.pumpAndSettle();

      Future<void> selectBarcode() async {
        await tester.tap(find.byKey(const Key('shell-quick-add')));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Scan barcode'));
        await tester.pumpAndSettle();
      }

      await selectBarcode();
      expect(scannerLaunches, 1);
      expect(router.routeInformationProvider.value.uri.path, '/daily-log');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['action'],
        isNull,
        reason:
            'The one-shot action must be consumed after the scanner closes.',
      );
      expect(
        router.routeInformationProvider.value.uri.queryParameters['from'],
        '/dashboard',
      );

      await selectBarcode();
      expect(scannerLaunches, 2);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['action'],
        isNull,
      );
      expect(tester.takeException(), isNull);

      // Dispose Drift-backed providers while fake time can still flush their
      // zero-delay stream cleanup timers.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
