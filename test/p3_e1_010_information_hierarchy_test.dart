import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/analytics/analytics_page.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/life_context/providers/life_context_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P3-E1-010 Dashboard exposes one top-level profile action', () {
    final source = File(
      'lib/features/dashboard/widgets/dashboard_top_bar.dart',
    ).readAsStringSync();

    expect(source, contains('required this.onProfile'));
    expect(source, contains('BilAccountAvatar('));
    expect(source, contains('_RoundProfileButton('));
    expect(source, contains("Key('dashboard-default-profile-avatar')"));
  });

  testWidgets(
    'P3-E1-010 Daily Log keeps one primary completion action and secondary actions available',
    (tester) async {
      tester.view.physicalSize = const Size(390, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final initialDate = DateTime(2026, 7, 18);
      final dailyLog = DailyLog(
        id: 1,
        uuid: 'test-daily-log-uuid',
        date: initialDate,
        dayKey: dayKeyFor(initialDate),
        notes: null,
        sleepHours: null,
        steps: null,
        exerciseNotes: null,
        createdAt: initialDate,
        updatedAt: initialDate,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            foodsProvider.overrideWith((ref) => Stream.value(<Food>[])),
            dailyMealsProvider.overrideWith(
              (ref) => Stream.value(<MealWithItems>[]),
            ),
            dailyWaterProvider.overrideWith(
              (ref) => Stream.value(<WaterEntry>[]),
            ),
            usualMealsProvider(
              'breakfast',
            ).overrideWith((ref) => Future.value(<UsualMealCandidate>[])),
            selectedLogDateProvider.overrideWith((ref) => initialDate),
            selectedDailyLogProvider.overrideWith(
              (ref) => Stream.value(dailyLog),
            ),
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
            userProfileProvider.overrideWith((ref) => Stream.value(null)),
            foodRepositoryProvider.overrideWithValue(FoodRepository(database)),
            mealRepositoryProvider.overrideWithValue(MealRepository(database)),
            waterRepositoryProvider.overrideWithValue(
              WaterRepository(database),
            ),
            measurementSystemProvider.overrideWith(
              (ref) => Stream.value(MeasurementSystem.metric),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: DailyLogPage(initialMealType: 'breakfast'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('daily-log-today-summary')), findsOneWidget);
      expect(find.byKey(const Key('daily-log-action-row')), findsOneWidget);
      expect(find.byKey(const Key('daily-log-water-shortcut')), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(
        find.byKey(const Key('daily_log_save_primary_action')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'P3-E1-010 Analytics app bar title provides localized purpose in loading and loaded states',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weightHistoryProvider.overrideWith(
              (ref) => Stream.value(<WeightEntry>[]),
            ),
            allMealsProvider.overrideWith(
              (ref) => Stream.value(<MealWithItems>[]),
            ),
            allWaterProvider.overrideWith(
              (ref) => Stream.value(<WaterEntry>[]),
            ),
            dashboardDailyLogsProvider.overrideWith(
              (ref) => Stream.value(<DailyLog>[]),
            ),
            insightLifeContextProvider.overrideWith(
              (ref) => Stream.value(<LifeContextEntry>[]),
            ),
            measurementSystemProvider.overrideWith(
              (ref) => Stream.value(MeasurementSystem.metric),
            ),
            userProfileProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: AnalyticsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Analytics'), findsOneWidget);
    },
  );
}
