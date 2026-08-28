import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_tools_pages.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sleep starts unset and saves an explicit repository value', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DailyLogRepository(database);
    final today = DateTime.now();
    await repository.save(
      date: today,
      notes: 'keep',
      steps: 6400,
      exerciseNotes: 'walk',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SleepTrackerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('N/A'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Save sleep');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final saved = await repository.getForDay(today);
    expect(saved?.sleepHours, isNotNull);
    expect(saved!.sleepHours, inInclusiveRange(0, 14));
    expect(saved.notes, 'keep');
    expect(saved.steps, 6400);
    expect(saved.exerciseNotes, 'walk');
    expect(find.textContaining('Recorded today:'), findsOneWidget);
    expect(find.byKey(const Key('sleep-manual-source')), findsOneWidget);
    expect(find.text('Source: Manual'), findsOneWidget);
    expect(find.textContaining('Updated locally'), findsOneWidget);
  });

  testWidgets('record load failure exposes a working retry', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _ControlledDailyLogRepository(database)
      ..remainingLoadFailures = 1;

    await _pumpSleep(tester, database, repository);
    await tester.pumpAndSettle();

    expect(find.text('Sleep history unavailable'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Sleep history unavailable'), findsNothing);
    expect(find.text('N/A'), findsOneWidget);
    expect(repository.loadCalls, 2);
  });

  testWidgets('insights stream error retries with a new subscription', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _ControlledDailyLogRepository(database)
      ..failInsights = true;

    await _pumpSleep(tester, database, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('Sleep history unavailable'), findsOneWidget);
    final subscriptionsBeforeRetry = repository.insightsSubscriptions;
    repository.failInsights = false;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Sleep history unavailable'), findsNothing);
    expect(repository.insightsSubscriptions, subscriptionsBeforeRetry + 1);
    expect(repository.activeInsightsSubscriptions, 1);
  });

  testWidgets('insights explicitly offer 7 and 30 day windows', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _ControlledDailyLogRepository(database);
    await _pumpSleep(tester, database, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sleep-insight-window')), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget);
    await tester.tap(find.text('30 days'));
    await tester.pump();
    final selector = tester.widget<SegmentedButton<int>>(
      find.byKey(const Key('sleep-insight-window')),
    );
    expect(selector.selected, <int>{30});
  });

  testWidgets('write failure keeps input and clears busy state', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _ControlledDailyLogRepository(database)
      ..failWrites = true;

    await _pumpSleep(tester, database, repository);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save sleep'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Your saved data was not changed'),
      findsOneWidget,
    );
    final save = find.widgetWithText(FilledButton, 'Save sleep');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(find.text('N/A'), findsNothing);
    expect(repository.writeCalls, 1);
  });

  testWidgets('in-flight save suppresses duplicates and tab navigation', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _ControlledDailyLogRepository(database)
      ..pendingWrite = Completer<void>();

    await _pumpSleep(tester, database, repository);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pump();
    final save = find.widgetWithText(FilledButton, 'Save sleep');
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump();

    expect(repository.writeCalls, 1);
    expect(find.text('Saving…'), findsOneWidget);
    await tester.tap(find.text('Insights'));
    await tester.pump();
    expect(find.byKey(const Key('sleep-log-tab')), findsOneWidget);
    expect(find.byKey(const Key('sleep-insights-tab')), findsNothing);

    repository.pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(repository.writeCalls, 1);
  });
}

Future<void> _pumpSleep(
  WidgetTester tester,
  AppDatabase database,
  DailyLogRepository repository,
) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      dailyLogRepositoryProvider.overrideWithValue(repository),
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
      home: SleepTrackerPage(),
    ),
  ),
);

final class _ControlledDailyLogRepository extends DailyLogRepository {
  _ControlledDailyLogRepository(super.database);

  int remainingLoadFailures = 0;
  bool failInsights = false;
  int loadCalls = 0;
  int insightsSubscriptions = 0;
  int activeInsightsSubscriptions = 0;
  int writeCalls = 0;
  bool failWrites = false;
  Completer<void>? pendingWrite;

  @override
  Future<DailyLog?> getForDay(DateTime date) {
    loadCalls++;
    if (remainingLoadFailures > 0) {
      remainingLoadFailures--;
      return Future<DailyLog?>.error(StateError('load failed'));
    }
    return super.getForDay(date);
  }

  @override
  Stream<List<DailyLog>> watchAll() {
    insightsSubscriptions++;
    late StreamController<List<DailyLog>> controller;
    controller = StreamController<List<DailyLog>>(
      onListen: () {
        activeInsightsSubscriptions++;
        if (failInsights) {
          controller.addError(StateError('stream failed'));
        } else {
          controller.add(const <DailyLog>[]);
        }
      },
      onCancel: () {
        activeInsightsSubscriptions--;
        return controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> updateSleepHours({
    required DateTime date,
    required double sleepHours,
  }) async {
    writeCalls++;
    if (failWrites) throw StateError('write failed');
    final pending = pendingWrite;
    if (pending != null) await pending.future;
    await super.updateSleepHours(date: date, sleepHours: sleepHours);
  }
}
