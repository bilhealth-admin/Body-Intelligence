import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_engine.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_page.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_provider.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/providers/exercise_calorie_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekly goals use exact day goals and synthetic imports stay out', () {
    final report = const WeeklyReportEngine().build(
      asOf: DateTime(2026, 8, 23),
      mealCount: 2,
      nutrition: const [
        WeeklyNutritionObservation(
          dayKey: '2026-08-23',
          calories: 950,
          proteinG: 0,
          sodiumMg: 0,
          foodCategory: 'historical-total',
          foodName: 'Recorded daily calories',
        ),
        WeeklyNutritionObservation(
          dayKey: '2026-08-23',
          calories: 52,
          proteinG: .3,
          carbsG: 14,
          fatG: .2,
          sodiumMg: 1,
          foodCategory: 'fruit',
          foodName: 'Apple',
        ),
      ],
      water: const [],
      weights: const [],
      activity: const [
        WeeklyActivityObservation(
          dayKey: '2026-08-23',
          exerciseNotes: 'Brisk walk',
          estimatedBurnedCaloriesKcal: 184,
        ),
      ],
      dailyCalorieGoal: 2000,
      calorieGoalsByDay: {'2026-08-23': 2100},
    );

    expect(report.weeklyCalorieGoal, 14100);
    expect(report.days.last.calorieGoal, 2100);
    expect(report.frequentFoods, {'Apple': 1});
    expect(report.foodCategoryCounts, {'fruit': 1});
    expect(report.totalEstimatedBurnedCaloriesKcal, 184);
  });

  test('workout estimate parser accepts only explicit bounded JSON values', () {
    expect(
      estimatedExerciseCaloriesFromNotes(
        '{"estimatedCaloriesKcal":184}\nmanual note\n'
        '{"estimatedCaloriesKcal":36}',
      ),
      220,
    );
    expect(estimatedExerciseCaloriesFromNotes('Brisk walk for 30 min'), isNull);
    expect(
      estimatedExerciseCaloriesFromNotes('{"estimatedCaloriesKcal":99999}'),
      isNull,
    );
  });

  test(
    'weekly evidence uses the same verified activity source as Today and Coach',
    () {
      final day = DateTime(2026, 8, 23, 12);
      final connected = ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.synchronized,
        platformSource: 'health-connect',
        availableSources: const ['health-connect'],
        signals: [
          ConnectedHealthSignalView(
            key: 'activeEnergy',
            value: 320,
            unit: 'kcal',
            source: 'watch',
            observedAt: day,
            confidence: .95,
          ),
        ],
        importedCount: 1,
        lastSyncAt: day,
        failureCode: null,
        deviceVerified: true,
      );
      final authoritative = authoritativeExerciseEnergyForDay(connected, day);
      expect(authoritative?.kcal, 320);

      final report = const WeeklyReportEngine().build(
        asOf: DateTime(2026, 8, 23),
        mealCount: 0,
        nutrition: [],
        water: [WeeklyWaterObservation(dayKey: '2026-08-23', amountMl: 750)],
        weights: [
          WeeklyWeightObservation(
            dayKey: '2026-08-22',
            observedAt: DateTime(2026, 8, 22, 8),
            weightKg: 90,
          ),
          WeeklyWeightObservation(
            dayKey: '2026-08-23',
            observedAt: DateTime(2026, 8, 23, 8),
            weightKg: 89.7,
          ),
        ],
        activity: [
          WeeklyActivityObservation(
            dayKey: '2026-08-23',
            exerciseNotes: 'walk',
            estimatedBurnedCaloriesKcal: 180,
            verifiedActiveEnergyKcal: authoritative?.kcal,
          ),
        ],
        sleep: [
          WeeklySleepObservation(
            dayKey: '2026-08-22',
            hours: 6,
            observedAt: DateTime(2026, 8, 22, 7),
          ),
          WeeklySleepObservation(
            dayKey: '2026-08-22',
            hours: 7.5,
            observedAt: DateTime(2026, 8, 22, 8),
            deviceVerified: true,
          ),
        ],
        fasting: [
          WeeklyFastingObservation(
            dayKey: '2026-08-21',
            durationMinutes: 16 * 60,
            reachedTarget: true,
          ),
        ],
        bodyContext: [
          WeeklyBodyContextObservation(
            dayKey: '2026-08-20',
            types: {'poorSleep'},
          ),
        ],
      );

      expect(report.totalVerifiedActiveEnergyKcal, 320);
      expect(report.totalEstimatedBurnedCaloriesKcal, 180);
      expect(report.totalWaterMl, 750);
      expect(report.latestWeightKg, 89.7);
      expect(report.weightDirectionKg, closeTo(-.3, .0001));
      expect(report.sleepDays, 1);
      expect(report.averageSleepHours, 7.5);
      expect(report.fastingSessions, 1);
      expect(report.fastingTargetsReached, 1);
      expect(report.bodyContextDays, 1);
      expect(report.trackedDays, 4);
    },
  );

  test('My Nutrition preserves the More navigation entry context', () {
    expect(
      ResponsiveAppShell.selectedIndexForUri(
        Uri.parse('/nutrition?from=settings'),
      ),
      ResponsiveAppShell.paths.indexOf('/settings'),
    );
    expect(
      ResponsiveAppShell.selectedIndexForUri(Uri.parse('/nutrition')),
      ResponsiveAppShell.paths.indexOf('/nutrition'),
    );
  });

  final snapshot = const WeeklyReportEngine().build(
    asOf: DateTime(2026, 8, 23),
    mealCount: 1,
    nutrition: const [
      WeeklyNutritionObservation(
        dayKey: '2026-08-23',
        calories: 52,
        proteinG: .3,
        carbsG: 14,
        fatG: .2,
        sodiumMg: 1,
        foodCategory: 'fruit',
        foodName: 'Apple',
      ),
    ],
    water: const [],
    weights: const [],
    activity: const [
      WeeklyActivityObservation(
        dayKey: '2026-08-23',
        exerciseNotes: 'walk',
        estimatedBurnedCaloriesKcal: 184,
      ),
    ],
    dailyCalorieGoal: 2000,
  );

  testWidgets('active Premium is a verified status, not a disabled CTA', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final premium = SubscriptionState(
      plan: CommercePlan.pro,
      entitlements: const {CommerceEntitlement.advancedIntelligence},
      authority: EntitlementAuthority.verifiedServer,
      isPurchasable: true,
      canRestorePurchases: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weeklyReportProvider.overrideWith((ref) async => snapshot),
          accountCreatedAtProvider.overrideWithValue(null),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          preferencesRepositoryProvider.overrideWithValue(
            PreferencesRepository(database),
          ),
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(premium),
          ),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const WeeklyReportPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly-calories-premium-cta')),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('weekly-calories-premium-cta')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('weekly-go-premium')), findsNothing);
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('weekly-calories-premium-cta')),
    );
    expect(semantics.properties.button, isNot(true));
  });

  testWidgets(
    'weekly digest uses the original BIL pulse and signal hierarchy',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weeklyReportProvider.overrideWith((ref) async => snapshot),
            accountCreatedAtProvider.overrideWithValue(null),
            userProfileProvider.overrideWith((ref) => Stream.value(null)),
            preferencesRepositoryProvider.overrideWithValue(
              PreferencesRepository(database),
            ),
            verifiedSubscriptionStateProvider.overrideWithValue(
              AsyncData(FreePlan.createState()),
            ),
          ],
          child: MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const WeeklyReportPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final foodSurface = find.byKey(const Key('weekly-food-insights-hero'));
      expect(find.byKey(const Key('weekly-pulse-hero')), findsOneWidget);
      expect(find.byKey(const Key('weekly-pulse-days')), findsOneWidget);
      expect(
        find.byKey(const Key('weekly-food-composition-strip')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('weekly-food-signal-grid')), findsOneWidget);
      expect(
        find.descendant(of: foodSurface, matching: find.byType(CircleAvatar)),
        findsNothing,
      );
      expect(
        find.descendant(of: foodSurface, matching: find.byType(Image)),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly-evidence-deck')),
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 8,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('weekly-evidence-deck')), findsOneWidget);
      expect(find.byKey(const Key('weekly-evidence-5')), findsOneWidget);
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'weekly digest fits ${locale.toLanguageTag()} at 390x844 and 160%',
      (tester) async {
        final missingTranslations = <String>[];
        final previousDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) {
          if (message?.startsWith('Missing reviewed runtime translation:') ==
              true) {
            missingTranslations.add(message!);
            return;
          }
          previousDebugPrint(message, wrapWidth: wrapWidth);
        };
        addTearDown(() => debugPrint = previousDebugPrint);
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              weeklyReportProvider.overrideWith((ref) async => snapshot),
              accountCreatedAtProvider.overrideWithValue(null),
              userProfileProvider.overrideWith((ref) => Stream.value(null)),
              preferencesRepositoryProvider.overrideWithValue(
                PreferencesRepository(database),
              ),
              verifiedSubscriptionStateProvider.overrideWithValue(
                AsyncData(FreePlan.createState()),
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
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!,
              ),
              home: const WeeklyReportPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('weekly-calorie-goal-line')),
          350,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 10,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('weekly-calorie-goal-line')),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('weekly-keep-section')),
          700,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 20,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        debugPrint = previousDebugPrint;
        expect(
          missingTranslations,
          isEmpty,
          reason: 'Weekly Digest must not fall back to English in $locale.',
        );
      },
    );
  }
}
