import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/analytics/nutrition_analytics_page.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/daily_log_summary_widgets.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/macro_value_formatter.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_nutrition_goal_resolver.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrient_daily_references.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_defaults_provider.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_snapshot_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test/visual_closure/closure_surface_capture.dart';
import '../../../test/visual_closure/visual_evidence_font.dart';

Future<void> verifyRestoredNutritionReaders(
  WidgetTester tester,
  AppDatabase db, {
  required String ownerId,
}) async {
  await tester.runAsync(loadVisualEvidenceFont);
  debugPrint('Restored readers: fonts ready');
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Access is a separate, explicitly synthetic fixture. This test proves
  // restored nutrition readers, never a live subscription grant or purchase.
  final access = SubscriptionState(
    plan: CommercePlan.premium,
    entitlements: const {CommerceEntitlement.advancedIntelligence},
    authority: EntitlementAuthority.verifiedServer,
    isPurchasable: false,
    canRestorePurchases: false,
  );
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      preferencesRepositoryProvider.overrideWithValue(
        PreferencesRepository(db),
      ),
      seedCatalogProvider.overrideWith((ref) async {}),
      selectedLogDateProvider.overrideWith((ref) => DateTime(2026, 10, 12)),
      userProfileProvider.overrideWithValue(const AsyncData(null)),
      verifiedSubscriptionAccessProvider.overrideWithValue(AsyncData(access)),
      verifiedSubscriptionStateProvider.overrideWithValue(AsyncData(access)),
      nutritionGoalDefaultsProvider.overrideWithValue({
        ...NutrientDailyReferences.values,
        'goal.calories': 2000,
        'goal.carbsPercent': 50,
        'goal.proteinPercent': 20,
        'goal.fatPercent': 30,
      }),
    ],
  );
  try {
    final subscriptions = [
      container.listen(dailyMealsProvider, (_, _) {}),
      container.listen(allMealsProvider, (_, _) {}),
      container.listen(diaryMealNamesProvider, (_, _) {}),
      container.listen(nutritionGoalSnapshotProvider, (_, _) {}),
      container.listen(nutritionGoalScheduleProvider, (_, _) {}),
      container.listen(
        dashboardNutrientGoalProvider('goal.calories'),
        (_, _) {},
      ),
    ];
    for (var i = 0; i < 80; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (container.read(dailyMealsProvider).hasValue &&
          container.read(allMealsProvider).hasValue &&
          container.read(diaryMealNamesProvider).hasValue &&
          container.read(nutritionGoalSnapshotProvider).hasValue &&
          container.read(nutritionGoalScheduleProvider).hasValue &&
          container
              .read(dashboardNutrientGoalProvider('goal.calories'))
              .hasValue) {
        break;
      }
    }
    final diary = container.read(dailyMealsProvider).requireValue;
    expect(diary.length, 2);
    expect(diary.every((meal) => meal.items.isNotEmpty), isTrue);
    expect(container.read(allMealsProvider).requireValue.length, 2);
    final totals = NutritionAnalyticsTotals.fromMeals(diary);
    // Reviewed recipe nutrition is explicitly PER SERVING: half of 300 kcal
    // plus 80 g of the 120 kcal/100 g custom food. Do not divide twice.
    expect(totals.calories, 96 + 300 * 0.5);
    expect(totals.fullTotal(FoodNutrient.transFat), isNull);
    expect(totals.fullTotal(FoodNutrient.cholesterol), 0);
    final snapshot = container.read(nutritionGoalSnapshotProvider).requireValue;
    expect(snapshot.goals['goal.calories']!.value, 1000);
    expect(snapshot.goals['goal.proteinGrams']!.value, 50);
    expect(snapshot.original['goal.lock.protein'], 'true');
    expect(snapshot.original['goal.vitaminA'], '10');
    expect(snapshot.original['goal.vitaminAMcg'], isNull);
    expect(
      container
          .read(dashboardNutrientGoalProvider('goal.calories'))
          .requireValue,
      1000,
    );
    final schedule = container.read(nutritionGoalScheduleProvider).requireValue;
    final coach = CoachNutritionGoalResolver.resolveWithSources(
      localDay: DateTime(2026, 10, 12),
      fallback: const {},
      schedule: schedule,
    );
    expect(coach.targets['caloriesKcal'], 1000);
    expect(coach.targets['carbsG'], 112.5);
    expect(coach.targets['proteinG'], 50);
    expect(coach.targets['fatG'], closeTo(350 / 9, 1e-9));
    expect(coach.sources['proteinG'], 'scheduled_gram_goal');
    expect(container.read(defaultNutritionGoalTargetProvider)!.calories, 1000);
    debugPrint('Restored readers: providers verified');
    for (final page in <String, Widget>{
      'today': const DailyLogPage(),
      'goals': const ReferenceNutritionGoalsPage(),
      'nutrition-analytics': const NutritionAnalyticsPage(),
    }.entries) {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: visualEvidenceTheme(
              BilFlagshipTheme.light(isArabic: true),
              fontFamily: 'NotoArabicEvidence',
            ),
            builder: (context, child) => visualEvidenceTextSurface(
              child!,
              fontFamily: 'NotoArabicEvidence',
            ),
            home: page.value,
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      debugPrint('Restored readers: ${page.key} painted');
      expect(tester.takeException(), isNull, reason: page.key);
      expect(find.byType(page.value.runtimeType), findsOneWidget);
      if (page.key == 'today') {
        final painted = tester.widget<DailyLogSnapshot>(
          find.byType(DailyLogSnapshot),
        );
        expect(painted.calorieGoal, 1000);
        expect(painted.carbsGoal, 112.5);
        expect(painted.proteinGoal, 50);
        expect(painted.fatGoal, closeTo(350 / 9, 1e-9));
        expect(
          find.byKey(const Key('premium-nutrition-entitlement-retry')),
          findsNothing,
        );
        for (final macro in {
          'carbs': (FoodNutrient.carbohydrates, 112.5),
          'protein': (FoodNutrient.protein, 50.0),
          'fat': (FoodNutrient.fat, 350 / 9),
        }.entries) {
          final value = totals.fullTotal(macro.value.$1)!;
          final text = tester.widget<Text>(
            find.byKey(Key('daily-summary-${macro.key}-grams')),
          );
          expect(
            text.textSpan!.toPlainText(),
            '${formatDiaryMacroGrams(value)} / ${formatDiaryMacroGrams(macro.value.$2)}',
          );
        }
      }
      // The painted page is backed by B's real SQLite/provider data, not a
      // screen populated with AsyncData fixture totals.
      expect(container.read(dailyMealsProvider).value!.length, 2);
      expect(
        container
            .read(nutritionGoalSnapshotProvider)
            .value!
            .goals['goal.calories']!
            .value,
        1000,
      );
      await captureClosureSurface(
        tester,
        find.byType(page.value.runtimeType),
        'server-restored-${page.key}-ar',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    for (final subscription in subscriptions) {
      subscription.close();
    }
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    // Drift retires watched queries on a zero-duration timer after Riverpod
    // cancels them. Flush that timer before SQLite close/teardown is awaited.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
  }
}
