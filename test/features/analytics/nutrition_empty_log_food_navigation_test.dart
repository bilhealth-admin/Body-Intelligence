import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/features/analytics/nutrition_analytics_page.dart';
import 'package:body_intelligence_log/features/daily_log/food_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty Nutrition Log food opens a real FoodLogPage and returns', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          dailyMealsProvider.overrideWith(
            (ref) => Stream.value(const <MealWithItems>[]),
          ),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          activeGoalProvider.overrideWith((ref) => Stream.value(null)),
          dashboardNutrientDashboardProvider.overrideWith(
            (ref) => Stream.value('core'),
          ),
          dashboardNutrientGoalProvider.overrideWith(
            (ref, key) => Stream.value(null),
          ),
          nutritionGoalScheduleProvider.overrideWith(
            (ref) => Stream.value(const NutritionGoalSchedule()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const NutritionAnalyticsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final action = find.byKey(const Key('nutrition-empty-log-food'));
    expect(action, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.byType(FoodLogPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pop();
    await tester.pumpAndSettle();

    expect(find.byType(NutritionAnalyticsPage), findsOneWidget);
    expect(find.byKey(const Key('nutrition-empty-log-food')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
