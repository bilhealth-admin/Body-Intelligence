import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/features/daily_log/daily_log_page.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/shared/widgets/actionable_error_state.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'DailyLogPage shows privacy-safe retry for meals/water/usual meals and preserves notes',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final initialDate = DateTime(2026, 7, 18);

      final dailyLog = DailyLog(
        id: 1,
        uuid: 'test-daily-log-uuid',
        date: initialDate,
        dayKey: dayKeyFor(initialDate),
        notes: 'hello notes',
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
              (ref) => Stream.error(Exception('private meals detail')),
            ),
            dailyWaterProvider.overrideWith(
              (ref) => Stream.error(Exception('private water detail')),
            ),
            usualMealsProvider(
              'breakfast',
            ).overrideWith((ref) => Future.value(<UsualMealCandidate>[])),
            usualMealsProvider('lunch').overrideWith(
              (ref) => Future.error(Exception('private usual meals detail')),
            ),
            selectedLogDateProvider.overrideWith((ref) => initialDate),
            selectedDailyLogProvider.overrideWith(
              (ref) => Stream.value(dailyLog),
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
            locale: Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: DailyLogPage(initialMealType: 'lunch')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('daily-log-body-context-link')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      // Body context is intentionally isolated on its own focused route. The
      // diary keeps a reachable entry point while private note contents are
      // not duplicated into the main diary surface.
      expect(
        find.byKey(const Key('daily-log-body-context-link')),
        findsOneWidget,
      );
      expect(find.text('hello notes'), findsNothing);
      expect(find.byKey(const Key('body-context-other-field')), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('daily-log-water-section')),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('private meals detail'), findsNothing);
      expect(find.textContaining('private water detail'), findsNothing);
      expect(find.textContaining('private usual meals detail'), findsNothing);

      // Lazy list construction may retain only the currently visible failure
      // surface. It must still expose a privacy-safe retry without leaking the
      // underlying exception detail.
      expect(find.byType(ActionableErrorState), findsOneWidget);
      expect(find.textContaining('Retry'), findsNothing);

      expect(find.text('حاول مرة أخرى'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );
}
