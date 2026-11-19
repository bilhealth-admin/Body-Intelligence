import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_fasting_history.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_engine.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_provider.dart';
import 'package:body_intelligence_log/features/notifications/services/bil_notification_service.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/wellness/data/fasting_history_repository.dart';
import 'package:body_intelligence_log/features/wellness/providers/fasting_history_provider.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_tools_pages.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('completed history copy covers every production locale directly', () {
    expect(FastingHistoryRuntimeCopy.balanced, isTrue);
    expect(
      FastingHistoryRuntimeCopy.rows.keys.toSet(),
      BilLocalePolicy.productionTags.toSet(),
    );
    for (final row in FastingHistoryRuntimeCopy.rows.entries) {
      expect(row.value, hasLength(FastingHistoryRuntimeCopy.sources.length));
      if (row.key != 'en') {
        for (var index = 0; index < row.value.length; index++) {
          expect(
            row.value[index],
            isNot(FastingHistoryRuntimeCopy.sources[index]),
          );
        }
      }
    }
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      '${locale.languageCode} completed-row Cancel preserves record at narrow160%',
      (tester) async {
        final fixture = await _mount(tester, locale: locale, narrow: true);
        await _openDelete(tester);
        expect(
          find.byKey(const Key('fasting-history-confirm-delete')),
          findsOneWidget,
        );
        await tester.tap(
          find.text(locale.languageCode == 'ar' ? 'إلغاء' : 'Cancel').last,
        );
        await tester.pumpAndSettle();
        expect(fixture.deletes, 0);
        expect(
          await tester.runAsync(
            () => fixture.preferences.get(FastingHistoryRepository.historyKey),
          ),
          fixture.encoded,
        );
        final button = tester.widget<IconButton>(
          find.byKey(const Key('fasting-history-delete-0')),
        );
        expect(
          button.tooltip,
          FastingHistoryRuntimeCopy.text(
            FastingHistoryRuntimeCopy.deleteRecord,
            locale,
          ),
        );
        final rect = tester.getRect(
          find.byKey(const Key('fasting-history-delete-0')),
        );
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'confirmed delete refreshes history and reports without timer notification actions',
    (tester) async {
      final fixture = await _mount(tester, active: true);
      final observation = fixture.container.listen(
        weeklyReportProvider,
        (_, _) {},
      );
      addTearDown(observation.close);
      await tester.runAsync(
        () => fixture.container.read(weeklyReportProvider.future),
      );
      expect(fixture.reportReads, 1);
      await _openDelete(tester);
      await tester.tap(find.byKey(const Key('fasting-history-confirm-delete')));
      await _until(tester, () => fixture.finished.isCompleted);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => fixture.container.read(weeklyReportProvider.future),
      );
      expect(fixture.deletes, 1);
      expect(fixture.reportReads, 2);
      expect(
        await tester.runAsync(
          () => fixture.preferences.get(FastingHistoryRepository.historyKey),
        ),
        '[]',
      );
      expect(
        await tester.runAsync(
          () =>
              fixture.preferences.get(FastingHistoryRepository.lastMinutesKey),
        ),
        isNull,
      );
      expect(find.byKey(const Key('fasting-history-delete-0')), findsNothing);
      expect(
        await tester.runAsync(
          () => fixture.preferences.get('wellness_fasting_session_v2'),
        ),
        fixture.activeEncoded,
      );
      expect(fixture.notifications.requests, 0);
      expect(fixture.notifications.cancellations, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'owner visit retires during confirmation even when same preferences return',
    (tester) async {
      final fixture = await _mount(tester);
      await _openDelete(tester);
      for (var transition = 0; transition < 2; transition++) {
        fixture.visit = Object(); // delivered B then A; same preferences reused
        fixture.container.invalidate(fastingHistoryOwnerVisitProvider);
        fixture.container.read(fastingHistoryOwnerVisitProvider);
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('fasting-history-confirm-delete')));
      await tester.pumpAndSettle();
      expect(fixture.deletes, 0);
      expect(
        await tester.runAsync(
          () => fixture.preferences.get(FastingHistoryRepository.historyKey),
        ),
        fixture.encoded,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'storage failure preserves row and allows an explicit later delete',
    (tester) async {
      final fixture = await _mount(tester);
      fixture.preferences.failNextDelete = true;
      await _openDelete(tester);
      await tester.tap(find.byKey(const Key('fasting-history-confirm-delete')));
      await _until(tester, () => fixture.finished.isCompleted);
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(
          () => fixture.preferences.get(FastingHistoryRepository.historyKey),
        ),
        fixture.encoded,
      );
      expect(find.text(FastingHistoryRuntimeCopy.failed), findsOneWidget);
      fixture.finished = Completer<void>();
      await _openDelete(tester);
      await tester.tap(find.byKey(const Key('fasting-history-confirm-delete')));
      await _until(tester, () => fixture.finished.isCompleted);
      await tester.pumpAndSettle();
      expect(fixture.deletes, 2);
      expect(
        await tester.runAsync(
          () => fixture.preferences.get(FastingHistoryRepository.historyKey),
        ),
        '[]',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!done() && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 16));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pump(const Duration(milliseconds: 16));
  expect(done(), isTrue, reason: 'The real repository boundary must complete.');
}

Future<void> _openDelete(WidgetTester tester) async {
  final action = find.byKey(const Key('fasting-history-delete-0'));
  await tester.scrollUntilVisible(
    action,
    250,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  expect(action.hitTestable(), findsOneWidget);
  expect(tester.widget<IconButton>(action).onPressed, isNotNull);
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool narrow = false,
  bool active = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(narrow ? 320 : 430, narrow ? 720 : 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fixture = _Fixture(AppDatabase.forTesting(NativeDatabase.memory()));
  await tester.runAsync(
    () => fixture.preferences.mutate(
      set: {
        FastingHistoryRepository.historyKey: fixture.encoded,
        FastingHistoryRepository.lastMinutesKey: '44',
        if (active) 'wellness_fasting_session_v2': fixture.activeEncoded,
      },
    ),
  );
  fixture.container = ProviderContainer(
    overrides: [
      preferencesRepositoryProvider.overrideWithValue(fixture.preferences),
      fastingHistoryOwnerVisitProvider.overrideWith((_) => fixture.visit),
      fastingHistoryRepositoryProvider.overrideWith((ref) {
        ref.watch(fastingHistoryOwnerVisitProvider);
        return _TrackedHistory(fixture);
      }),
      fastingNotificationServiceProvider.overrideWithValue(
        fixture.notifications,
      ),
      weeklyReportProvider.overrideWith((_) async {
        fixture.reportReads++;
        return const WeeklyReportEngine().build(
          asOf: DateTime.utc(2026, 11, 18),
          nutrition: const [],
          water: const [],
          weights: const [],
          mealCount: 0,
        );
      }),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    fixture.container.dispose();
    await tester.runAsync(fixture.database.close);
    await tester.pump(Duration.zero);
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(narrow ? 1.6 : 1)),
          child: child!,
        ),
        home: const FastingTimerPage(),
      ),
    ),
  );
  await _until(
    tester,
    () =>
        find
            .byKey(const Key('fasting-reference-introduction'))
            .evaluate()
            .isNotEmpty &&
        fixture.container
                .read(fastingHistorySnapshotProvider)
                .asData
                ?.value
                .records
                .length ==
            1,
  );
  return fixture;
}

class _Fixture {
  _Fixture(this.database) : preferences = _FailPreferences(database);
  final AppDatabase database;
  final _FailPreferences preferences;
  final notifications = _Notifications();
  Object visit = Object();
  late ProviderContainer container;
  int deletes = 0, reportReads = 0;
  Completer<void> finished = Completer<void>();
  final activeEncoded = jsonEncode({
    'startedAtUtc': DateTime.now()
        .subtract(const Duration(minutes: 5))
        .toUtc()
        .toIso8601String(),
    'targetHours': 16,
  });
  final encoded = jsonEncode([
    {
      'startedAtUtc': '2026-11-18T01:00:00.000Z',
      'endedAtUtc': '2026-11-18T01:44:00.000Z',
      'targetHours': 16,
    },
  ]);
}

class _TrackedHistory extends FastingHistoryRepository {
  _TrackedHistory(this.fixture) : super(fixture.preferences);
  final _Fixture fixture;
  @override
  Future<FastingHistorySnapshot?> delete(
    FastingHistoryRecord record, {
    required bool Function() isCurrent,
  }) async {
    fixture.deletes++;
    try {
      return await super.delete(record, isCurrent: isCurrent);
    } finally {
      fixture.finished.complete();
    }
  }
}

class _FailPreferences extends PreferencesRepository {
  _FailPreferences(super.database);
  bool failNextDelete = false;
  @override
  Future<bool> mutateIfUnchanged({
    required Map<String, String?> expected,
    Map<String, String> set = const {},
    Iterable<String> remove = const [],
    bool Function()? isCurrent,
  }) {
    if (failNextDelete) {
      failNextDelete = false;
      return Future.error(StateError('synthetic_delete_storage_failure'));
    }
    return super.mutateIfUnchanged(
      expected: expected,
      set: set,
      remove: remove,
      isCurrent: isCurrent,
    );
  }
}

class _Notifications extends BilNotificationService {
  _Notifications() : super(FlutterLocalNotificationsPlugin());
  int requests = 0, cancellations = 0;
  @override
  Future<BilNotificationPermissionState> permissionState() async =>
      BilNotificationPermissionState.denied;
  @override
  Future<Set<int>> pendingNotificationIds() async => {};
  @override
  Future<bool> requestPermission() async {
    requests++;
    return false;
  }

  @override
  Future<void> cancelFastingSessionNotifications() async {
    cancellations++;
  }
}
