import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_value_mask.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/premium_meal_features_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final saved in <bool?>[null, false, true]) {
    testWidgets(
      'actual meal preference=$saved survives paid/checking/denied/renewed',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final preferences = PreferencesRepository(db);
        if (saved != null) {
          await preferences.set(mealMacroDisplayEnabledKey, '$saved');
        }
        final now = DateTime.utc(2026, 11, 6);
        final paid = SubscriptionState(
          plan: CommercePlan.premium,
          entitlements: const {CommerceEntitlement.advancedIntelligence},
          authority: EntitlementAuthority.verifiedServer,
          startedAt: now.subtract(const Duration(days: 1)),
          currentPeriodEndsAt: now.add(const Duration(days: 1)),
          isPurchasable: false,
          canRestorePurchases: true,
        );
        final denied = SubscriptionState(
          plan: CommercePlan.free,
          entitlements: FreePlan.entitlements,
          authority: EntitlementAuthority.verifiedServer,
          isPurchasable: false,
          canRestorePurchases: true,
        );
        final phase = StateProvider<AsyncValue<SubscriptionState>>(
          (_) => AsyncData(paid),
        );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            preferencesRepositoryProvider.overrideWithValue(preferences),
            seedCatalogProvider.overrideWith((_) async {}),
            foodsProvider.overrideWithValue(const AsyncData(<Food>[])),
            dailyMealsProvider.overrideWithValue(
              const AsyncData(<MealWithItems>[]),
            ),
            dailyWaterProvider.overrideWithValue(
              const AsyncData(<WaterEntry>[]),
            ),
            selectedDailyLogProvider.overrideWithValue(const AsyncData(null)),
            diaryMealNamesProvider.overrideWithValue(
              const AsyncData(<String?>[null, null, null, null]),
            ),
            selectedLogDateProvider.overrideWith((_) => now),
            nutritionGoalScheduleProvider.overrideWithValue(
              const AsyncData(
                NutritionGoalSchedule(
                  mealTargets: {
                    'breakfast': NutritionGoalTarget(
                      calories: 400,
                      carbsPercent: 50,
                      proteinPercent: 20,
                      fatPercent: 30,
                    ),
                  },
                ),
              ),
            ),
            mealCalorieGoalsProvider.overrideWithValue(
              const AsyncData(<String, double>{}),
            ),
            userProfileProvider.overrideWithValue(const AsyncData(null)),
            measurementSystemProvider.overrideWithValue(
              const AsyncData(MeasurementSystem.metric),
            ),
            verifiedEntitlementClockProvider.overrideWithValue(() => now),
            verifiedSubscriptionStateProvider.overrideWithValue(
              AsyncData(paid),
            ),
            verifiedSubscriptionAccessProvider.overrideWith(
              (ref) => ref.watch(phase),
            ),
            for (final key in const [
              'diary.foodInsights',
              'diary.showAllMeals',
              'diary.showFoodTimestamps',
              'diary.useNetCarbs',
              'diary.alwaysShowWater',
            ])
              dailyLogPreferenceProvider(
                key,
              ).overrideWithValue(const AsyncData(false)),
          ],
        );
        var resourcesDisposed = false;
        Future<void> disposeResources() async {
          if (resourcesDisposed) return;
          resourcesDisposed = true;
          await tester.pumpWidget(const SizedBox());
          container.dispose();
          // Drift cancels streams through zero-duration Timer.run callbacks.
          // Drain them in the fake clock before closing SQLite in real async.
          await tester.pump();
          await tester.pump(Duration.zero);
          await tester.runAsync(db.close);
          await tester.pump();
        }

        addTearDown(disposeResources);
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                locale: Locale('en'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: DailyLogPage(
                  initialMealType: 'breakfast',
                  focusMealEntry: true,
                ),
              ),
            ),
          );
          for (
            var i = 0;
            i < 50 && !container.read(mealMacroDisplayProvider).hasValue;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
          }
          await tester.pump();
          expect(
            container.read(mealMacroDisplayProvider).requireValue.enabled,
            saved == true,
          );
          final summary = find.byKey(const Key('daily-meal-detail-summary'));
          await tester.ensureVisible(summary);
          await tester.pump();
          final macroRow = find.byKey(const Key('daily-meal-detail-macros'));
          final minerals = find.byKey(const Key('daily-meal-detail-minerals'));
          final paidSummarySize = tester.getSize(summary);
          final paidMineralSize = tester.getSize(minerals);

          for (final state in <AsyncValue<SubscriptionState>>[
            AsyncData(paid),
            const AsyncLoading(),
            AsyncData(denied),
            AsyncData(paid),
          ]) {
            container.read(phase.notifier).state = state;
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            expect(macroRow, saved == true ? findsOneWidget : findsNothing);
            expect(
              container.read(mealMacroDisplayProvider).requireValue.enabled,
              saved == true,
            );
            expect(
              tester.getSize(minerals),
              paidMineralSize,
              reason:
                  'access never inserts an unwanted macro row or resizes minerals',
            );
            if (state.value?.plan != CommercePlan.free) {
              expect(
                tester.getSize(summary),
                paidSummarySize,
                reason:
                    'paid, checking and renewed layouts preserve exact geometry',
              );
            } else {
              // The existing shared Premium group badge has its own height. It is
              // still present on verified denial; hiding it is not this fix.
              expect(
                tester.getSize(summary).height,
                greaterThanOrEqualTo(paidSummarySize.height),
              );
              final masks = tester.widgetList<PremiumValueMask>(
                find.descendant(
                  of: summary,
                  matching: find.byType(PremiumValueMask),
                ),
              );
              expect(masks, isNotEmpty);
              expect(
                masks.every((mask) => mask.locked),
                isTrue,
                reason:
                    'a display preference cannot grant Premium values/actions',
              );
            }
            expect(tester.takeException(), isNull);
          }
        } finally {
          await disposeResources();
        }
      },
    );
  }
}
