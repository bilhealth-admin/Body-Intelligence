import 'dart:async';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/features/analytics/nutrition_analytics_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_snapshot_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final fails in [false, true]) {
    testWidgets(
      'schedule ${fails ? 'failure' : 'delay'} never becomes another daily target',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final schedule = StreamController<NutritionGoalSchedule>();
        final date = DateTime(2026, 8, 14);
        await tester.runAsync(() async {
          final preferences = PreferencesRepository(db);
          await preferences.setMany({
            'goal.calories': '2000',
            'goal.carbsPercent': '45',
            'goal.proteinPercent': '20',
            'goal.fatPercent': '35',
          });
          final food = await db
              .into(db.foods)
              .insert(
                FoodsCompanion.insert(
                  name: 'Synthetic schedule state food',
                  calories: 620,
                  protein: 34,
                  carbs: 71,
                  fats: 19,
                ),
              );
          final meals = MealRepository(db);
          final id = await meals.createMeal(
            date: date,
            name: 'breakfast',
            type: 'breakfast',
          );
          await meals.addMealItem(
            mealId: id,
            foodId: food,
            quantity: 100,
            quantityInGrams: true,
          );
        });
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            selectedLogDateProvider.overrideWith((_) => date),
            userProfileProvider.overrideWithValue(const AsyncData(null)),
            activeGoalProvider.overrideWithValue(const AsyncData(null)),
            nutritionGoalScheduleProvider.overrideWith((_) => schedule.stream),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          await schedule.close();
          for (var i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 1));
          }
          await tester.runAsync(db.close);
        });
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
              home: NutritionAnalyticsPage(initialTab: 2),
            ),
          ),
        );
        for (var i = 0; i < 30; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump();
        }
        expect(container.read(nutritionGoalSnapshotProvider).hasValue, isTrue);
        expect(
          container.read(dashboardNutrientDashboardProvider).hasValue,
          isTrue,
        );
        expect(container.read(dailyMealsProvider).requireValue, isNotEmpty);
        if (fails) {
          schedule.addError(StateError('synthetic schedule storage failure'));
          await tester.pumpAndSettle();
          expect(
            container.read(nutritionGoalScheduleProvider).hasError,
            isTrue,
          );
          expect(
            find.text('Nutrition goals could not be loaded.'),
            findsOneWidget,
          );
          expect(find.text('Try again'), findsOneWidget);
        }
        expect(
          find.byKey(const Key('nutrition-goal-carbohydrates')),
          findsNothing,
          reason:
              'A stored day target is unresolved, so the global 2000 target is not its substitute.',
        );
        if (!fails) {
          schedule.add(
            NutritionGoalSchedule(
              dayTargets: {
                date.weekday: const NutritionGoalTarget(
                  calories: 1000,
                  carbsPercent: 45,
                  proteinPercent: 20,
                  fatPercent: 35,
                ),
              },
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('112.5 g'), findsOneWidget);
          expect(find.text('41.5 g'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
