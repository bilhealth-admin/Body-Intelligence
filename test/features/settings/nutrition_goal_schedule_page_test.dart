import 'dart:async';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/nutrition_goal_schedule_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late _FailingNutritionGoalScheduleRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = _FailingNutritionGoalScheduleRepository(
      PreferencesRepository(database),
    );
  });

  tearDown(() => database.close());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nutritionGoalScheduleRepositoryProvider.overrideWithValue(repository),
          nutritionGoalScheduleProvider.overrideWithValue(
            const AsyncData(NutritionGoalSchedule()),
          ),
        ],
        child: const MaterialApp(home: NutritionGoalSchedulePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('weekday save failure is awaited and shown to the user', (
    tester,
  ) async {
    repository.pendingDaySave = Completer<void>();
    await pumpPage(tester);

    await tester.tap(find.text('Monday'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use default'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.daySaveAttempts, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.pendingDaySave!.completeError(
      StateError('simulated local storage failure'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the goal. Your previous goal is unchanged.'),
      findsOneWidget,
    );
    expect(find.text('Scheduled goals'), findsOneWidget);
  });

  testWidgets('meal save failure is awaited and shown to the user', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.scrollUntilVisible(find.text('Breakfast'), 250);
    await tester.tap(find.text('Breakfast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use default'));
    await tester.pumpAndSettle();

    expect(repository.mealSaveAttempts, 1);
    expect(
      find.text('Could not save the goal. Your previous goal is unchanged.'),
      findsOneWidget,
    );
    expect(find.text('Scheduled goals'), findsOneWidget);
  });
}

class _FailingNutritionGoalScheduleRepository
    extends NutritionGoalScheduleRepository {
  _FailingNutritionGoalScheduleRepository(super.preferences);

  int daySaveAttempts = 0;
  int mealSaveAttempts = 0;
  Completer<void>? pendingDaySave;

  @override
  Future<void> saveDay(int weekday, NutritionGoalTarget? target) async {
    daySaveAttempts += 1;
    if (pendingDaySave case final pending?) await pending.future;
    throw StateError('simulated local storage failure');
  }

  @override
  Future<void> saveMeal(String mealType, NutritionGoalTarget? target) async {
    mealSaveAttempts += 1;
    throw StateError('simulated local storage failure');
  }
}
