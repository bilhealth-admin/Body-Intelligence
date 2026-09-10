import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/notifications/services/bil_notification_service.dart';
import 'package:body_intelligence_log/features/wellness/domain/sleep_schedule.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_tools_pages.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  testWidgets(
    'sleep meal review enters the shell and dashboard remains navigable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final router = GoRouter(
        initialLocation: '/sleep',
        routes: <RouteBase>[
          GoRoute(path: '/sleep', builder: (_, _) => const SleepTrackerPage()),
          ShellRoute(
            builder: (_, _, child) => ResponsiveAppShell(child: child),
            routes: <RouteBase>[
              GoRoute(
                path: '/dashboard',
                builder: (_, _) =>
                    const Scaffold(body: Text('Dashboard destination')),
              ),
              GoRoute(
                path: '/daily-log',
                builder: (_, _) =>
                    const Scaffold(body: Text('Daily Log destination')),
              ),
              GoRoute(
                path: '/settings',
                builder: (_, _) => const Scaffold(body: Text('Settings')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            userProfileProvider.overrideWith((ref) => const Stream.empty()),
          ],
          child: MaterialApp.router(
            locale: const Locale('en'),
            routerConfig: router,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      final reviewMeals = find.byKey(const Key('sleep-review-meals'));
      await Scrollable.ensureVisible(
        tester.element(reviewMeals),
        alignment: .7,
      );
      await tester.pumpAndSettle();
      await tester.tap(reviewMeals);
      await tester.pumpAndSettle();

      expect(find.text('Daily Log destination'), findsOneWidget);
      expect(find.byKey(const Key('glass-bottom-navigation')), findsOneWidget);
      await tester.tap(find.byKey(const Key('shell-dashboard-destination')));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard destination'), findsOneWidget);
      expect(find.text('Daily Log destination'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'legacy reminders stay quiet and can be disabled on $platform',
      (tester) async {
        final legacy = const SleepSchedule.defaults().copyWith(
          enabled: true,
          bedHour: 12,
          bedMinute: 30,
          wakeHour: 5,
          goalMinutes: 360,
          windDownMinutes: 15,
        );
        SharedPreferences.setMockInitialValues({
          SleepScheduleStore.storageKey: jsonEncode(legacy.toJson()),
        });
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = _ControlledDailyLogRepository(database);
        final notifications = _ControlledSleepNotifications();
        await _pumpSleep(
          tester,
          database,
          repository,
          notifications: notifications,
          platform: platform,
        );
        await _showSleepSchedule(tester);
        for (var tick = 0; tick < 3; tick++) {
          await tester.pump(const Duration(seconds: 1));
          expect(_sleepToggle(tester).value, isTrue);
          expect(find.byKey(const Key('sleep-schedule-error')), findsNothing);
        }
        expect(notifications.permissionCalls, 0);
        expect(notifications.scheduleCalls, 0);
        expect(notifications.cancelCalls, 0);
        expect(tester.binding.hasScheduledFrame, isFalse);

        await tester.tap(find.byKey(const Key('sleep-schedule-toggle')));
        await tester.pumpAndSettle();
        expect(_sleepToggle(tester).value, isFalse);
        expect(_sleepToggle(tester).onChanged, isNotNull);
        expect(find.byKey(const Key('sleep-schedule-error')), findsNothing);
        expect(notifications.permissionCalls, 0);
        expect(notifications.scheduleCalls, 0);
        expect(notifications.cancelCalls, 1);
        expect(repository.writeCalls, 0);
        final saved = await SleepScheduleStore().load();
        expect(saved.toJson(), legacy.copyWith(enabled: false).toJson());

        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpSleep(
          tester,
          database,
          repository,
          notifications: notifications,
          platform: platform,
        );
        await _showSleepSchedule(tester);
        expect(_sleepToggle(tester).value, isFalse);
        expect(find.byKey(const Key('sleep-schedule-error')), findsNothing);
        expect(notifications.cancelCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('permission wait holds one stable switch and one save attempt', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = _ControlledDailyLogRepository(database);
    final notifications = _ControlledSleepNotifications()
      ..pendingPermission = Completer<bool>();
    await _pumpSleep(
      tester,
      database,
      repository,
      notifications: notifications,
      platform: TargetPlatform.iOS,
    );
    await _showSleepSchedule(tester);
    final originalCard = tester.element(
      find.byKey(const Key('sleep-schedule-card')),
    );
    final staleCallback = _sleepToggle(tester).onChanged!;
    await tester.tap(find.byKey(const Key('sleep-schedule-toggle')));
    staleCallback(true);
    await tester.pump();
    for (var tick = 0; tick < 5; tick++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(_sleepToggle(tester).value, isTrue);
      expect(_sleepToggle(tester).onChanged, isNull);
      expect(
        tester.element(find.byKey(const Key('sleep-schedule-card'))),
        same(originalCard),
      );
    }
    expect(notifications.permissionCalls, 1);
    expect(notifications.scheduleCalls, 0);
    expect((await SleepScheduleStore().load()).enabled, isFalse);
    notifications.pendingPermission!.complete(true);
    await tester.pumpAndSettle();
    expect(_sleepToggle(tester).value, isTrue);
    expect(_sleepToggle(tester).onChanged, isNotNull);
    expect((await SleepScheduleStore().load()).enabled, isTrue);
    expect(notifications.permissionCalls, 1);
    expect(notifications.scheduleCalls, 1);
    expect(notifications.cancelCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'permission denial leaves reminders off without retrying itself',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final notifications = _ControlledSleepNotifications()
        ..permissionAllowed = false;
      await _pumpSleep(
        tester,
        database,
        _ControlledDailyLogRepository(database),
        notifications: notifications,
      );
      await _showSleepSchedule(tester);
      await tester.tap(find.byKey(const Key('sleep-schedule-toggle')));
      await tester.pumpAndSettle();
      expect(_sleepToggle(tester).value, isFalse);
      expect(_sleepToggle(tester).onChanged, isNotNull);
      expect(
        find.textContaining('Notification permission is off.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(notifications.permissionCalls, 1);
      expect(notifications.scheduleCalls, 0);
      expect(notifications.cancelCalls, 0);
      expect((await SleepScheduleStore().load()).enabled, isFalse);
    },
  );

  testWidgets(
    'native scheduling failure cannot persist a false enabled state',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final notifications = _ControlledSleepNotifications()
        ..failSchedule = true;
      await _pumpSleep(
        tester,
        database,
        _ControlledDailyLogRepository(database),
        notifications: notifications,
      );
      await _showSleepSchedule(tester);
      await tester.tap(find.byKey(const Key('sleep-schedule-toggle')));
      await tester.pumpAndSettle();
      expect(_sleepToggle(tester).value, isFalse);
      expect(_sleepToggle(tester).onChanged, isNotNull);
      expect((await SleepScheduleStore().load()).enabled, isFalse);
      expect(notifications.permissionCalls, 1);
      expect(notifications.scheduleCalls, 1);
      expect(notifications.cancelCalls, 1);
      expect(
        find.text('The notification preference could not be saved.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('legacy goal validation happens only on explicit enable', (
    tester,
  ) async {
    final legacy = const SleepSchedule.defaults().copyWith(goalMinutes: 360);
    SharedPreferences.setMockInitialValues({
      SleepScheduleStore.storageKey: jsonEncode(legacy.toJson()),
    });
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final notifications = _ControlledSleepNotifications();
    await _pumpSleep(
      tester,
      database,
      _ControlledDailyLogRepository(database),
      notifications: notifications,
    );
    await _showSleepSchedule(tester);
    _sleepToggle(tester).onChanged!(false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sleep-schedule-error')), findsNothing);
    await tester.tap(find.byKey(const Key('sleep-schedule-toggle')));
    await tester.pumpAndSettle();
    expect(_sleepToggle(tester).value, isFalse);
    expect(
      find.text('Choose an adult sleep goal from 7 to 12 hours.'),
      findsOneWidget,
    );
    expect(notifications.permissionCalls, 0);
    expect(notifications.scheduleCalls, 0);
    expect(notifications.cancelCalls, 0);
    expect((await SleepScheduleStore().load()).toJson(), legacy.toJson());
  });
}

Future<void> _pumpSleep(
  WidgetTester tester,
  AppDatabase database,
  DailyLogRepository repository, {
  BilNotificationService? notifications,
  TargetPlatform platform = TargetPlatform.android,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      dailyLogRepositoryProvider.overrideWithValue(repository),
      if (notifications != null)
        fastingNotificationServiceProvider.overrideWithValue(notifications),
    ],
    child: MaterialApp(
      theme: ThemeData(platform: platform),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SleepTrackerPage(),
    ),
  ),
);

SwitchListTile _sleepToggle(WidgetTester tester) => tester
    .widget<SwitchListTile>(find.byKey(const Key('sleep-schedule-toggle')));

Future<void> _showSleepSchedule(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const Key('sleep-schedule-toggle')),
    220,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('sleep-log-tab')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

class _ControlledSleepNotifications extends BilNotificationService {
  _ControlledSleepNotifications() : super(FlutterLocalNotificationsPlugin());

  int permissionCalls = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;
  bool permissionAllowed = true;
  bool failSchedule = false;
  Completer<bool>? pendingPermission;

  @override
  Future<bool> requestPermission() {
    permissionCalls++;
    return pendingPermission?.future ?? Future.value(permissionAllowed);
  }

  @override
  Future<void> scheduleSleepSchedule({
    required int bedHour,
    required int bedMinute,
    required int wakeHour,
    required int wakeMinute,
    required int windDownMinutes,
    required String languageCode,
  }) async {
    scheduleCalls++;
    if (failSchedule) throw StateError('native schedule failed');
  }

  @override
  Future<void> cancelSleepSchedule() async {
    cancelCalls++;
  }
}

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
