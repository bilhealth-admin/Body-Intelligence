import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/settings/premium_meal_features_page.dart';
import 'package:body_intelligence_log/features/settings/reference_goals_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('premium goal surfaces are direct across extended locales', () {
    const keys = {
      'Calorie Goals By Meal',
      'Show Carbs, Protein and Fat By Meal',
      'Exercise Calories',
      'Locked Pro feature',
      'Calorie goals by meal',
      'Macros by meal',
      'Exercise calories',
      'Exercise calorie settings could not be saved.',
    };
    for (final key in keys) {
      final values = ExtendedRuntimeCopy.values[key];
      expect(values, isNotNull, reason: key);
      for (final locale in ExtendedRuntimeCopy.supported) {
        expect(values![locale]?.trim(), isNotEmpty, reason: '$key/$locale');
      }
    }
  });

  test('stored goal preferences reject corrupt or future facts', () {
    final invalid = validateStoredGoalPreferences(
      weeklyGoal: 'Lose 99 kg per week',
      startingWeight: '-4',
      startingDate: '2026-08-15',
      now: DateTime(2026, 8, 14),
    );
    expect(invalid.weeklyGoal, isNull);
    expect(invalid.startingWeight, isNull);
    expect(invalid.startingDate, isNull);
    for (final corruptDate in ['2026-02-30', '2026-08-14T12:00:00']) {
      expect(
        validateStoredGoalPreferences(
          weeklyGoal: null,
          startingWeight: null,
          startingDate: corruptDate,
          now: DateTime(2026, 8, 14),
        ).startingDate,
        isNull,
        reason: corruptDate,
      );
    }

    final valid = validateStoredGoalPreferences(
      weeklyGoal: 'Maintain weight',
      startingWeight: '85.5',
      startingDate: '2026-08-14',
      now: DateTime(2026, 8, 14),
    );
    expect(valid.weeklyGoal, 'Maintain weight');
    expect(valid.startingWeight, 85.5);
    expect(valid.startingDate, '2026-08-14');
  });

  testWidgets('free crowns route to plans rather than pretending to activate', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await _seedProfile(database);
    final router = _router();
    await _pump(
      tester,
      database,
      router: router,
      subscription: FreePlan.createState(),
    );

    await _reveal(
      tester,
      find.byKey(const Key('goals-meal-calories-entitlement-state')),
      520,
    );
    final freeTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Calorie Goals By Meal'),
        matching: find.byType(ListTile),
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('goals-meal-calories-entitlement-state')),
        matching: find.byIcon(Icons.lock_outline_rounded),
      ),
      findsOneWidget,
    );
    expect(freeTile.onTap, isNotNull);
    expect(
      premiumGoalDestination(false, '/settings/nutrition-meal-calorie-goals'),
      '/plans',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    await database.close();
  });

  testWidgets('verified premium crowns dispatch three independent features', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await _seedProfile(database);
    final subscription = _premium();
    final routers = <GoRouter>[];
    for (final entry in const [
      (
        'goals-meal-calories-entitlement-state',
        'Calorie Goals By Meal',
        'meal-calories-target',
      ),
      (
        'goals-meal-macros-entitlement-state',
        'Show Carbs, Protein and Fat By Meal',
        'meal-macros-target',
      ),
      (
        'goals-exercise-calories-entitlement-state',
        'Exercise Calories',
        'exercise-target',
      ),
    ]) {
      final router = _router();
      routers.add(router);
      await _pump(tester, database, router: router, subscription: subscription);
      final trigger = find.byKey(Key(entry.$1));
      await _reveal(
        tester,
        trigger,
        entry.$1 == 'goals-exercise-calories-entitlement-state' ? 850 : 520,
      );
      final tile = tester.widget<ListTile>(
        find.ancestor(of: find.text(entry.$2), matching: find.byType(ListTile)),
      );
      expect(tile.onTap, isNotNull);
      expect(
        premiumGoalDestination(true, switch (entry.$1) {
          'goals-meal-calories-entitlement-state' =>
            '/settings/nutrition-meal-calorie-goals',
          'goals-meal-macros-entitlement-state' =>
            '/settings/diary/macro-display',
          _ => '/settings/exercise-calories',
        }),
        switch (entry.$1) {
          'goals-meal-calories-entitlement-state' =>
            '/settings/nutrition-meal-calorie-goals',
          'goals-meal-macros-entitlement-state' =>
            '/settings/diary/macro-display',
          _ => '/settings/exercise-calories',
        },
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    for (final router in routers) {
      router.dispose();
    }
    await database.close();
  });

  testWidgets('meal calorie goal persists and reloads from repository', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpPage(tester, database, const MealCalorieGoalsPage(), _premium());

    await tester.tap(find.text('Breakfast'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), '620');
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      await PreferencesRepository(
        database,
      ).get(mealCalorieGoalKey('breakfast')),
      '620.0',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpPage(tester, database, const MealCalorieGoalsPage(), _premium());
    expect(find.text('620 kcal'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });

  testWidgets('macro display stores enabled percent mode as one snapshot', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await _pumpPage(tester, database, const MealMacroDisplayPage(), _premium());

    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Percent'));
    await tester.pump(const Duration(milliseconds: 500));
    final repository = PreferencesRepository(database);
    expect(await repository.get(mealMacroDisplayEnabledKey), 'true');
    expect(await repository.get(mealMacroDisplayModeKey), 'percent');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });
}

SubscriptionState _premium() => SubscriptionState(
  plan: CommercePlan.pro,
  entitlements: const {CommerceEntitlement.advancedIntelligence},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: true,
  canRestorePurchases: true,
);

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const ReferenceGoalsPage()),
    for (final route in const {
      '/plans': 'plans-target',
      '/settings/nutrition-meal-calorie-goals': 'meal-calories-target',
      '/settings/diary/macro-display': 'meal-macros-target',
      '/settings/exercise-calories': 'exercise-target',
    }.entries)
      GoRoute(
        path: route.key,
        builder: (_, _) => Scaffold(body: Text(route.value)),
      ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  AppDatabase database, {
  required GoRouter router,
  required SubscriptionState subscription,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        verifiedSubscriptionStateProvider.overrideWithValue(
          AsyncData(subscription),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _seedProfile(AppDatabase database) =>
    UserProfileRepository(database).save(
      gender: 'male',
      age: 35,
      height: 181,
      currentWeight: 93.4,
      targetWeight: 85,
      activityLevel: 'light',
      exercises: true,
    );

Future<void> _pumpPage(
  WidgetTester tester,
  AppDatabase database,
  Widget page,
  SubscriptionState subscription,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        verifiedSubscriptionStateProvider.overrideWithValue(
          AsyncData(subscription),
        ),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: page,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _reveal(
  WidgetTester tester,
  Finder target,
  double distance,
) async {
  await tester.drag(find.byType(ListView), Offset(0, -distance));
  await tester.pump(const Duration(milliseconds: 500));
  expect(target, findsOneWidget);
}
