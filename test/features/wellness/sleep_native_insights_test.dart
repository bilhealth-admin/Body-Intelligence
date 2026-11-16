// Real native gateway, canonical health store, controller/provider and Sleep UI.
// Only native method-channel replies are fixtures; this is not device evidence.
import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_copy.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/global_platform/persistence/owner_scoped_health_store.dart';
import 'package:body_intelligence_log/features/global_platform/runtime/global_product_composition_root.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_tools_pages.dart';
import 'package:body_intelligence_log/features/wellness/presentation/sleep_insights_projection.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real native sleep reaches Insights without local manual rows', (
    tester,
  ) async {
    final fixture = _NativeSleepFixture(tester);
    try {
      await fixture.initialize();
      addTearDown(fixture.close);

      fixture.stages = fixture.night('recent', 0, 6);
      await fixture.synchronize();
      await fixture.mount();
      expect(find.byKey(const Key('sleep-connected-source')), findsOneWidget);
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('6h 0m'), findsOneWidget);
      expect(find.text('1 recorded nights · 6.0 h average'), findsOneWidget);
      expect(find.byKey(const Key('sleep-connect-health')), findsNothing);
      expect(fixture.calls, contains('readChanges'));
      expect(fixture.calls, isNot(contains('requestPermissions')));
      expect(
        fixture.calls.any((call) => call.toLowerCase().contains('write')),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'nullable day is missing but explicit manual zero overrides one native night',
    (tester) async {
      final f = _NativeSleepFixture(tester);
      try {
        await f.initialize();
        addTearDown(f.close);

        f.stages = [...f.night('today', 0, 8), ...f.night('older', 1, 6)];
        final repository = DailyLogRepository(f.db);
        await tester.runAsync(() => repository.startDay(f.lastEnd));
        expect(
          (await tester.runAsync(
            () => repository.getForDay(f.lastEnd),
          ))!.sleepHours,
          isNull,
        );
        await f.synchronize();
        await f.mount();
        await f.insights();
        await f.summary('2 recorded nights · 7.0 h average');
        await tester.runAsync(
          () => repository.updateSleepHours(date: f.lastEnd, sleepHours: 0),
        );
        await tester.pumpAndSettle();
        await f.summary('2 recorded nights · 3.0 h average');
        await tester.scrollUntilVisible(
          find.text('0h 0m'),
          -200,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('sleep-insights-tab')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('0h 0m'), findsOneWidget);
        expect(find.text('Manual'), findsWidgets);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('7 and 30 day windows average only recorded native nights', (
    tester,
  ) async {
    final f = _NativeSleepFixture(tester);
    try {
      await f.initialize();
      addTearDown(f.close);

      f.stages = [
        ...f.night('recent', 0, 6),
        ...f.night('ten-days-old', 10, 8),
      ];
      await f.synchronize();
      await f.mount();
      await f.insights();
      await f.summary('1 recorded nights · 6.0 h average');
      await tester.ensureVisible(find.text('30 days'));
      await tester.tap(find.text('30 days'));
      await tester.pumpAndSettle();
      await f.summary('2 recorded nights · 7.0 h average');
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'native overlap aggregation and source resolver produce one overnight total',
    (tester) async {
      final f = _NativeSleepFixture(tester);
      try {
        await f.initialize();
        addTearDown(f.close);

        final inBed = f.night('bed', 0, 14).single;
        (inBed['attributes']! as Map)['sleepStage'] = 'inBed';
        final awake = f.night('awake', 0, 1).single;
        (awake['attributes']! as Map)['sleepStage'] = 'awake';
        f.stages = [
          ...f.night('watch-full', 0, 8),
          ...f.night('overlap-core', 0, 6),
          ...f.night(
            'other-source',
            0,
            12,
            source: 'com.apple.health.phone',
            confidence: .5,
          ),
          inBed,
          awake,
        ];
        await f.synchronize();
        await f.mount();
        await f.insights();
        await f.summary('1 recorded nights · 8.0 h average');
        expect(find.text('8h 0m'), findsOneWidget);
        final value = projectSleepInsights(
          native: f.container.read(connectedHealthProvider).value,
          manualRows: const [],
          now: f.now,
          windowDays: 7,
        );
        expect(value.nights.single.nativeSignal!.source, 'Apple Watch');
        expect(
          value.nights.single.nativeSignal!.attributes['sourceSessionIds'],
          containsAll(['watch-full', 'overlap-core']),
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'verified connection with no sleep does not ask to connect again',
    (tester) async {
      final f = _NativeSleepFixture(tester);
      try {
        await f.initialize();
        addTearDown(f.close);

        f.stages = [
          {
            ...f.night('heart-only', 0, 1).single,
            'type': 'heartRate',
            'unit': 'count/min',
            'value': 72.0,
            'observedAt': f.now
                .subtract(const Duration(minutes: 2))
                .toUtc()
                .toIso8601String(),
            'attributes': <String, Object?>{},
          },
        ];
        await f.synchronize();
        await f.mount();
        await f.insights();
        expect(
          f.container.read(connectedHealthProvider).value!.deviceVerified,
          isTrue,
        );
        expect(find.byKey(const Key('sleep-connect-health')), findsNothing);
        expect(find.text('No sleep trend yet'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'verified cached history remains recorded without a new native read',
    (tester) async {
      final f = _NativeSleepFixture(tester);
      try {
        await f.initialize();
        addTearDown(f.close);

        f.stages = f.night('cached-native', 0, 6);
        await f.synchronize();
        f.container.invalidate(connectedHealthProvider);
        f.calls.clear();
        await tester.runAsync(
          () => f.container
              .read(connectedHealthProvider.notifier)
              .restoreCachedSnapshot(),
        );
        await f.mount();
        await f.insights();
        await f.summary('1 recorded nights · 6.0 h average');
        final value = projectSleepInsights(
          native: f.container.read(connectedHealthProvider).value,
          manualRows: const [],
          now: f.now,
          windowDays: 7,
        );
        expect(value.cached, isTrue);
        expect(value.hasVerifiedConnection, isTrue);
        expect(f.calls, isNot(contains('readChanges')));
        expect(f.calls, isNot(contains('readLatestSignals')));
        expect(find.byKey(const Key('sleep-connect-health')), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'revocation removes native Insights while local manual rows remain',
    (tester) async {
      final f = _NativeSleepFixture(tester);
      try {
        await f.initialize();
        addTearDown(f.close);

        f.stages = f.night('native', 0, 6);
        await tester.runAsync(
          () => DailyLogRepository(f.db).updateSleepHours(
            date: DateTime(f.lastEnd.year, f.lastEnd.month, f.lastEnd.day - 1),
            sleepHours: 5,
          ),
        );
        await f.synchronize();
        await f.mount();
        await f.insights();
        await f.summary('2 recorded nights · 5.5 h average');
        await tester.runAsync(
          () => f.container
              .read(connectedHealthProvider.notifier)
              .revokePermissions(),
        );
        await tester.pumpAndSettle();
        await f.summary('1 recorded nights · 5.0 h average');
        expect(find.text('6h 0m'), findsNothing);
        expect(
          f.container.read(connectedHealthProvider).value!.deviceVerified,
          isFalse,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'current repository and native owner replace previous-owner data',
    (tester) async {
      final f = _NativeSleepFixture(tester);
      try {
        await f.initialize();
        addTearDown(f.close);

        f.stages = f.night('owner-a', 0, 6);
        await tester.runAsync(
          () => DailyLogRepository(
            f.db,
          ).updateSleepHours(date: f.lastEnd, sleepHours: 5),
        );
        await f.synchronize();
        await f.mount();
        await f.insights();
        await f.summary('1 recorded nights · 5.0 h average');
        await f.replaceOwner('sleep-insights-owner-b');
        expect(find.text('5h 0m'), findsNothing);
        expect(find.text('6h 0m'), findsNothing);
        await tester.pumpAndSettle();
        expect(find.text('No sleep trend yet'), findsOneWidget);
        f.calls.clear();
        await f.synchronize();
        expect(f.calls, isNot(contains('readLatestSignals')));
        expect(f.calls, isNot(contains('readChanges')));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  for (final boundary in ['late', 'owner', 'revoke', 'background']) {
    testWidgets(
      'foreground sleep remains truthful and late history is fenced after $boundary',
      (tester) async {
        final f = _NativeSleepFixture(
          tester,
          deadline: const Duration(seconds: 1),
        );
        try {
          await f.initialize();
          addTearDown(f.close);

          f.stages = f.night('foreground', 0, 6);
          f.heldHistory = Completer<Map<String, Object?>>();
          await f.synchronize();
          expect(
            f.container.read(connectedHealthProvider).value!.failureCode,
            'health_history_sync_incomplete',
          );
          await f.mount();
          await f.insights();
          expect(
            find.text(connectedHealthHistoryIncompleteEnglish),
            findsOneWidget,
          );
          if (boundary == 'owner') {
            await f.replaceOwner('sleep-insights-owner-b');
            await f.replaceOwner('sleep-insights-owner-a');
          } else if (boundary == 'revoke') {
            await tester.runAsync(
              () => f.container
                  .read(connectedHealthProvider.notifier)
                  .revokePermissions(),
            );
          } else if (boundary == 'background') {
            f.container
                .read(connectedHealthProvider.notifier)
                .didChangeAppLifecycleState(AppLifecycleState.paused);
          }
          final before = await tester.runAsync(
            () => f.store.get('connected_health_ui', 'snapshot'),
          );
          f.heldHistory!.complete({
            'records': f.night('late-wrong-night', 1, 12),
            'deletedIds': <String>[],
            'nextAnchor': 'late',
            'hasMore': false,
          });
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();
          expect(
            await tester.runAsync(
              () => f.store.get('connected_health_ui', 'snapshot'),
            ),
            before,
          );
          expect(find.text('12h 0m'), findsNothing);
          if (boundary == 'owner' || boundary == 'revoke') {
            expect(find.text('6h 0m'), findsNothing);
          }
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(Duration.zero);
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
  for (final hours in [15.0, 24.0, 25.0]) {
    testWidgets(
      'native duration boundary $hours follows the reviewed aggregation',
      (tester) async {
        final f = _NativeSleepFixture(tester);
        try {
          await f.initialize();
          addTearDown(f.close);
          f.stages = f.night('duration-boundary', 0, hours);
          await f.synchronize();
          await f.mount();
          await f.insights();
          if (hours <= 24) {
            expect(find.text('${hours.toInt()}h 0m'), findsOneWidget);
          } else {
            expect(find.text('25h 0m'), findsNothing);
            expect(find.text('No sleep trend yet'), findsOneWidget);
          }
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(Duration.zero);
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
  testWidgets('native 6h59m59s rounds to 7h0m without 60 minutes', (
    tester,
  ) async {
    final f = _NativeSleepFixture(tester);
    try {
      await f.initialize();
      addTearDown(f.close);
      f.stages = f.night('minute-boundary', 0, 7 - 1 / 3600);
      await f.synchronize();
      await f.mount();
      await f.insights();
      expect(find.text('7h 0m'), findsOneWidget);
      expect(find.text('6h 60m'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

final class _NativeSleepFixture {
  _NativeSleepFixture(this.tester, {this.deadline});

  final WidgetTester tester;
  final Duration? deadline;
  final host = GlobalNativeIntegrationHost.instance;
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final calls = <String>[];
  final extraDatabases = <AppDatabase>[];
  final now = DateTime.now().toLocal();
  final channel = const MethodChannel('bil/apple_health');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  String currentOwner = 'sleep-insights-owner-a';
  late final OwnerScopedHealthStore store;
  late final NativeConnectedHealthGateway gateway;
  late final ProviderContainer container;
  List<Map<String, Object?>> stages = [];
  Completer<Map<String, Object?>>? heldHistory;

  DateTime get lastEnd {
    final end = DateTime(now.year, now.month, now.day, 7);
    return end.isAfter(now)
        ? DateTime(now.year, now.month, now.day - 1, 7)
        : end;
  }

  List<Map<String, Object?>> night(
    String id,
    int daysAgo,
    double hours, {
    String source = 'com.apple.health.watch',
    double confidence = 1,
  }) {
    final end = DateTime(lastEnd.year, lastEnd.month, lastEnd.day - daysAgo, 7);
    final start = end.subtract(Duration(seconds: (hours * 3600).round()));
    return [
      {
        'id': id,
        'type': 'sleep',
        'value': hours,
        'unit': 'h',
        'observedAt': start.toUtc().toIso8601String(),
        'sourceId': source,
        'deviceId': 'Apple Watch',
        'confidence': confidence,
        'timeZoneId': 'UTC',
        'attributes': {
          'sleepStage': 'core',
          'endedAt': end.toUtc().toIso8601String(),
          'wearableKind': 'apple_watch',
        },
      },
    ];
  }

  Future<void> initialize() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'availability':
          return {'available': true};
        case 'permissions':
          return <String, bool>{};
        case 'readDailyTotals':
          return <Object?>[];
        case 'readLatestSignals':
          final at = DateTime.parse(
            (call.arguments as Map)['asOf'] as String,
          ).toLocal();
          final cutoff = at.subtract(const Duration(hours: 72));
          final floor = DateTime(
            cutoff.year,
            cutoff.month,
            cutoff.day - (cutoff.hour < 12 ? 1 : 0),
            12,
          );
          return [
            for (final row in stages)
              if (!DateTime.parse(row['observedAt']! as String).isBefore(floor))
                {
                  ...row,
                  'attributes': {
                    ...Map<String, Object?>.from(row['attributes']! as Map),
                    'latestSleepWindowStart': floor.toUtc().toIso8601String(),
                  },
                },
          ];
        case 'readChanges':
          return heldHistory?.future ??
              {
                'records': stages,
                'deletedIds': <String>[],
                'nextAnchor': 'sleep-history-complete',
                'hasMore': false,
              };
        case 'enableBackgroundDelivery':
        case 'cancelLatestSignals':
        case 'cancelReadChanges':
          return null;
        case 'revokeAccess':
          return {'revoked': true};
        default:
          throw StateError('Unexpected native method ${call.method}');
      }
    });
    await tester.runAsync(() async {
      await host.initialize(
        database: sqlite.sqlite3.openInMemory(),
        configuration: const GlobalProductRuntimeConfiguration(
          localeCatalogs: [],
        ),
      );
      store = OwnerScopedHealthStore(
        inner: host.productFlows!.store,
        ownerId: currentOwner,
        readCurrentOwnerId: () => currentOwner,
      );
      await store.put('connected_health_consent', 'Apple Health', {
        'readRequested': true,
      });
    });
    gateway = NativeConnectedHealthGateway(
      host.productFlows!,
      ownerId: currentOwner,
      currentOwnerId: () => currentOwner,
    );
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        connectedHealthGatewayProvider.overrideWithValue(gateway),
        if (deadline != null)
          connectedHealthProvider.overrideWith(
            (ref) => ConnectedHealthController(
              ref.watch(connectedHealthGatewayProvider),
              synchronizationTimeout: deadline,
            ),
          ),
        sleepNowProvider.overrideWithValue(() => now),
      ],
    );
  }

  Future<void> synchronize() async {
    await tester.runAsync(
      () => container.read(connectedHealthProvider.notifier).synchronize(),
    );
  }

  Future<void> mount() async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: SleepTrackerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> insights() async {
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
  }

  Future<void> summary(String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('sleep-insights-tab')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text(text), findsOneWidget);
  }

  Future<void> replaceOwner(String next) async {
    currentOwner = next;
    final nextDb = AppDatabase.forTesting(NativeDatabase.memory());
    extraDatabases.add(nextDb);
    container.updateOverrides([
      databaseProvider.overrideWithValue(nextDb),
      connectedHealthGatewayProvider.overrideWithValue(
        NativeConnectedHealthGateway(
          host.productFlows!,
          ownerId: next,
          currentOwnerId: () => currentOwner,
        ),
      ),
      if (deadline != null)
        connectedHealthProvider.overrideWith(
          (ref) => ConnectedHealthController(
            ref.watch(connectedHealthGatewayProvider),
            synchronizationTimeout: deadline,
          ),
        ),
      sleepNowProvider.overrideWithValue(() => now),
    ]);
    await tester.pump(Duration.zero);
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
    container.dispose();
    final pending = heldHistory;
    if (pending != null && !pending.isCompleted) {
      pending.complete({
        'records': <Object?>[],
        'deletedIds': <String>[],
        'nextAnchor': 'late-completed',
        'hasMore': false,
      });
    }
    await tester.runAsync(() async {
      await db.close();
      for (final database in extraDatabases) {
        await database.close();
      }
      await host.close();
    });
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  }
}
