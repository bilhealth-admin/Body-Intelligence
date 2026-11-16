import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_copy.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/persistence/owner_scoped_health_store.dart';
import 'package:body_intelligence_log/features/global_platform/runtime/global_product_composition_root.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const apple = MethodChannel('bil/apple_health');
  const android = MethodChannel('bil/health_connect');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final host = GlobalNativeIntegrationHost.instance;
  late NativeConnectedHealthGateway gateway;
  late OwnerScopedHealthStore store;
  late List<MethodCall> calls;
  late String currentOwner;
  late FutureOr<Object?> Function(MethodCall) latest;
  late FutureOr<Object?> Function(MethodCall) availability;
  late FutureOr<Object?> Function(MethodCall) history;
  late bool activityEnabled;

  Map<String, Object?> row(
    String id,
    String type,
    DateTime at, {
    double value = 72,
    String unit = 'count/min',
    Map<String, Object?> attributes = const {},
  }) => {
    'id': id,
    'type': type,
    'value': value,
    'unit': unit,
    'observedAt': at.toUtc().toIso8601String(),
    'sourceId': 'com.apple.health',
    'deviceId': 'Apple Watch',
    'confidence': 1.0,
    'timeZoneId': 'UTC',
    'attributes': attributes,
  };

  Future<void> consent([String source = 'Apple Health']) =>
      store.put('connected_health_consent', source, {'readRequested': true});

  Future<void> seedCache() async {
    final old = DateTime.now().subtract(const Duration(days: 3));
    final signals = [
      for (final entry in [
        ('heartRate', 64.0, 'count/min'),
        ('sleep', 6.0, 'h'),
      ])
        GlobalHealthSignal(
          key: entry.$1,
          canonicalValue: entry.$2,
          canonicalUnit: entry.$3,
          provenance: GlobalProvenance(
            providerId: apple.name,
            sourceId: 'com.apple.health',
            recordId: 'cached-${entry.$1}',
            observedAt: old,
            confidence: 1,
          ),
        ).toMap(),
    ];
    await store.put('connected_health_ui', 'snapshot', {
      'signals': signals,
      'importedCount': 2,
      'lastSyncAt': old.toUtc().toIso8601String(),
    });
  }

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    currentOwner = 'latest-health-owner';
    calls = [];
    activityEnabled = true;
    latest = (_) => <Object?>[];
    availability = (_) => {'available': true};
    history = (_) => {
      'records': <Object?>[],
      'deletedIds': <String>[],
      'nextAnchor': 'completed-history',
      'hasMore': false,
    };
    Future<Object?> handle(MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'availability':
          return await availability(call);
        case 'permissions':
          return <String, bool>{};
        case 'readLatestSignals':
          final response = await latest(call);
          if (response is! List) return response;
          final asOf = DateTime.parse(
            (call.arguments as Map)['asOf'] as String,
          );
          final cutoff = asOf.subtract(const Duration(hours: 72)).toLocal();
          final floor = DateTime(
            cutoff.year,
            cutoff.month,
            cutoff.day - (cutoff.hour < 12 ? 1 : 0),
            12,
          );
          return [
            for (final raw in response)
              if (raw is Map && raw['type'] == 'sleep')
                {
                  ...raw,
                  'attributes': {
                    'latestSleepWindowStart': floor.toUtc().toIso8601String(),
                    ...Map<String, Object?>.from(
                      raw['attributes'] as Map? ?? {},
                    ),
                  },
                }
              else
                raw,
          ];
        case 'readDailyTotals':
          if (!activityEnabled) return <Object?>[];
          final asOf = DateTime.parse(
            (call.arguments as Map)['asOf'] as String,
          );
          return [
            row(
              'daily:steps',
              'steps',
              asOf,
              value: 1234,
              unit: 'count',
              attributes: {'aggregation': 'native_daily'},
            ),
          ];
        case 'readChanges':
          return await history(call);
        case 'enableBackgroundDelivery':
          return null;
        case 'revokeAccess':
          return {'revoked': true};
        case 'cancelLatestSignals':
        case 'cancelReadChanges':
          return null;
        default:
          throw StateError('Unexpected native operation: ${call.method}');
      }
    }

    messenger.setMockMethodCallHandler(apple, handle);
    messenger.setMockMethodCallHandler(android, handle);
    await host.initialize(
      database: sqlite3.openInMemory(),
      configuration: const GlobalProductRuntimeConfiguration(
        localeCatalogs: [],
      ),
    );
    store = OwnerScopedHealthStore(
      inner: host.productFlows!.store,
      ownerId: currentOwner,
      readCurrentOwnerId: () => currentOwner,
    );
    gateway = NativeConnectedHealthGateway(
      host.productFlows!,
      ownerId: currentOwner,
      currentOwnerId: () => currentOwner,
    );
  });

  tearDown(() async {
    await host.close();
    messenger.setMockMethodCallHandler(apple, null);
    messenger.setMockMethodCallHandler(android, null);
    debugDefaultTargetPlatformOverride = null;
  });

  void recentHeartAndSleep() {
    latest = (call) {
      final asOf = DateTime.parse((call.arguments as Map)['asOf'] as String);
      final local = asOf.toLocal();
      var end = DateTime(local.year, local.month, local.day, 7);
      if (end.isAfter(asOf)) {
        end = DateTime(local.year, local.month, local.day - 1, 7);
      }
      return [
        row(
          'explicit-heart',
          'heartRate',
          asOf.subtract(const Duration(minutes: 2)),
        ),
        row(
          'explicit-sleep',
          'sleep',
          end.subtract(const Duration(hours: 7)),
          value: 7,
          unit: 'h',
          attributes: {
            'sleepStage': 'core',
            'endedAt': end.toUtc().toIso8601String(),
          },
        ),
      ];
    };
  }

  Map<String, Object?> lateHistory() => {
    'records': [
      row(
        'late-history',
        'heartRate',
        DateTime.now().subtract(const Duration(minutes: 1)),
        value: 99,
      ),
    ],
    'deletedIds': ['explicit-heart'],
    'nextAnchor': 'late-history-must-not-commit',
    'hasMore': false,
  };

  Future<Map<String, Object?>> persistedHealth() async => {
    'snapshot': await store.get('connected_health_ui', 'snapshot'),
    'signals': await store.list('health_signals'),
    'seen': await store.list('health_seen'),
    'tombstones': await store.list('health_tombstones'),
    'anchor': await store.get('health_anchor', apple.name),
  };

  ConnectedHealthController explicitController() {
    final controller = ConnectedHealthController(
      gateway,
      synchronizationTimeout: const Duration(milliseconds: 800),
    );
    addTearDown(() {
      if (controller.mounted) controller.dispose();
    });
    return controller;
  }

  test(
    'explicit controller sync publishes verified HR/Sleep before held history '
    'and keeps them at its deadline without accepting late history',
    () async {
      await consent();
      recentHeartAndSleep();
      final pending = Completer<Object?>();
      final started = Completer<void>();
      history = (_) {
        if (!started.isCompleted) started.complete();
        return pending.future;
      };
      final controller = explicitController();
      await controller.refresh();
      calls.clear();
      final sync = controller.synchronize();
      try {
        await started.future.timeout(const Duration(seconds: 2));
        final progress = controller.state.value!;
        expect(progress.isBusy, isTrue);
        expect(progress.status, ConnectedHealthStatus.syncing);
        expect(liveHealthWatchCanShowMetrics(progress), isTrue);
        expect(
          progress.signals.singleWhere((s) => s.key == 'heartRate').value,
          72,
        );
        expect(progress.signals.singleWhere((s) => s.key == 'sleep').value, 7);
        final methods = calls.map((c) => c.method).toList();
        expect(
          methods.indexOf('readLatestSignals'),
          lessThan(methods.indexOf('readChanges')),
        );
        expect(
          methods.take(methods.indexOf('readLatestSignals')),
          isNot(contains('availability')),
        );
        expect(
          methods.take(methods.indexOf('readLatestSignals')),
          isNot(contains('permissions')),
        );
        await sync;
        final finished = controller.state.value!;
        expect(finished.status, ConnectedHealthStatus.degraded);
        expect(finished.failureCode, 'health_history_sync_incomplete');
        expect(liveHealthWatchCanShowMetrics(finished), isTrue);
        expect(
          liveHealthWatchCanShowMetrics(
            finished.copyWith(failureCode: 'unknown_native_failure'),
          ),
          isFalse,
        );
        expect(finished.isBusy, isFalse);
        expect(
          finished.signals.singleWhere((s) => s.key == 'heartRate').value,
          72,
        );
        expect(finished.signals.singleWhere((s) => s.key == 'sleep').value, 7);
        final beforeLate = await persistedHealth();
        pending.complete(lateHistory());
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(await persistedHealth(), beforeLate);
        expect(
          controller.state.value!.failureCode,
          'health_history_sync_incomplete',
        );
        expect(
          calls.map((c) => c.method),
          containsAll(['cancelLatestSignals', 'cancelReadChanges']),
        );
      } finally {
        if (!pending.isCompleted) pending.complete(lateHistory());
        await sync;
      }
    },
  );

  test('explicit controller deadline during held foreground keeps cache, skips '
      'history and fences late foreground records', () async {
    await consent();
    await seedCache();
    final pending = Completer<Object?>();
    final started = Completer<void>();
    latest = (_) {
      started.complete();
      return pending.future;
    };
    final controller = explicitController();
    await controller.refresh();
    final before = await persistedHealth();
    final sync = controller.synchronize();
    try {
      await Future.any([
        started.future,
        sync,
      ]).timeout(const Duration(seconds: 2));
      expect(started.isCompleted, isTrue);
      await sync;
      expect(controller.state.value!.failureCode, 'health_sync_timed_out');
      expect(
        controller.state.value!.signals
            .singleWhere((s) => s.key == 'heartRate')
            .value,
        64,
      );
      expect(calls.map((c) => c.method), isNot(contains('readChanges')));
      pending.complete([
        row(
          'late-foreground',
          'heartRate',
          DateTime.now().subtract(const Duration(minutes: 1)),
          value: 101,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(await persistedHealth(), before);
    } finally {
      if (!pending.isCompleted) pending.complete(<Object?>[]);
      await sync;
    }
  });

  for (final boundary in ['background', 'owner', 'revoke']) {
    test('explicit verified foreground survives safely while $boundary fences '
        'held historical persistence and old controller completion', () async {
      await consent();
      recentHeartAndSleep();
      final pending = Completer<Object?>();
      final started = Completer<void>();
      history = (_) {
        if (!started.isCompleted) started.complete();
        return pending.future;
      };
      final controller = explicitController();
      await controller.refresh();
      final sync = controller.synchronize();
      try {
        await started.future.timeout(const Duration(seconds: 2));
        expect(calls.map((c) => c.method), contains('readLatestSignals'));
        if (boundary == 'background') {
          controller.didChangeAppLifecycleState(AppLifecycleState.paused);
          controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        } else if (boundary == 'owner') {
          currentOwner = 'different-health-owner';
          controller
              .dispose(); // Provider disposal is the real owner-change boundary.
          currentOwner =
              'latest-health-owner'; // A→B→A must not revive the old flight.
        } else {
          await controller.revokePermissions();
        }
        final beforeLate = await persistedHealth();
        pending.complete(lateHistory());
        await sync;
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(await persistedHealth(), beforeLate);
        if (controller.mounted) {
          expect(controller.state.value!.isBusy, isFalse);
          if (boundary == 'revoke') {
            expect(
              controller.state.value!.status,
              ConnectedHealthStatus.permissionRequired,
            );
            expect(controller.state.value!.signals, isEmpty);
            expect(
              liveHealthWatchCanShowMetrics(controller.state.value!),
              isFalse,
            );
          } else {
            expect(
              controller.state.value!.status,
              ConnectedHealthStatus.degraded,
            );
          }
        }
      } finally {
        if (!pending.isCompleted) pending.complete(lateHistory());
        await sync;
      }
    });
  }

  test('explicit real gateway completes foreground and unchanged historical '
      'types with full success when both phases finish', () async {
    await consent();
    recentHeartAndSleep();
    history = (_) => {
      'records': [
        row(
          'historic-weight',
          'weight',
          DateTime.now().subtract(const Duration(hours: 1)),
          value: 68,
          unit: 'kg',
        ),
      ],
      'deletedIds': <String>[],
      'nextAnchor': 'fully-completed',
      'hasMore': false,
    };
    final controller = explicitController();
    await controller.refresh();
    await controller.synchronize();
    final snapshot = controller.state.value!;
    expect(snapshot.status, ConnectedHealthStatus.synchronized);
    expect(snapshot.failureCode, isNull);
    expect(snapshot.signals.singleWhere((s) => s.key == 'heartRate').value, 72);
    expect(snapshot.signals.singleWhere((s) => s.key == 'sleep').value, 7);
    expect(snapshot.signals.singleWhere((s) => s.key == 'weight').value, 68);
    final types =
        (calls.singleWhere((c) => c.method == 'readChanges').arguments
                as Map)['types']
            as List;
    expect(
      types.toSet(),
      connectedHealthReadTypesForPlatform(
        TargetPlatform.iOS,
      ).map((t) => t.name).toSet(),
    );
    expect(
      (await store.get('health_anchor', apple.name))!['anchor'],
      'fully-completed',
    );
  });

  test('explicit real gateway never queries foreground or history before '
      'consent or for a departed owner', () async {
    final controller = explicitController();
    await controller.synchronize();
    expect(
      controller.state.value!.failureCode,
      'explicit_health_consent_required',
    );
    expect(calls.map((c) => c.method), isNot(contains('readLatestSignals')));
    expect(calls.map((c) => c.method), isNot(contains('readChanges')));
    await consent();
    currentOwner = 'different-health-owner';
    await controller.synchronize();
    expect(controller.state.value!.status, ConnectedHealthStatus.unavailable);
    expect(calls.map((c) => c.method), isNot(contains('readLatestSignals')));
    expect(calls.map((c) => c.method), isNot(contains('readChanges')));
  });

  test('an explicit deadline during local preflight starts no later foreground '
      'or historical query and writes no snapshot', () async {
    await consent();
    await seedCache();
    recentHeartAndSleep();
    final controller = ConnectedHealthController(
      gateway,
      synchronizationTimeout: Duration.zero,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    calls.clear();
    final before = await persistedHealth();
    await controller.synchronize();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(controller.state.value!.failureCode, 'health_sync_timed_out');
    expect(calls.map((c) => c.method), isNot(contains('readLatestSignals')));
    expect(calls.map((c) => c.method), isNot(contains('readDailyTotals')));
    expect(calls.map((c) => c.method), isNot(contains('readChanges')));
    expect(await persistedHealth(), before);
  });

  test('partial-history copy is truthful in all five Health locales and '
      'does not expose the internal failure code', () {
    for (final language in ['en', 'ar', 'fr', 'es', 'tr']) {
      final text = connectedHealthTextForLanguage(
        language,
        connectedHealthHistoryIncompleteEnglish,
        connectedHealthHistoryIncompleteArabic,
      );
      expect(text, isNotEmpty);
      expect(text, isNot(contains('health_history_sync_incomplete')));
      expect(text, isNot(contains('could not be reached')));
      if (language == 'ar') {
        expect(text, connectedHealthHistoryIncompleteArabic);
      } else if (language != 'en') {
        expect(text, isNot(connectedHealthHistoryIncompleteEnglish));
      }
    }
  });

  test('passive refresh gets recent HR and a complete many-stage night '
      'independently of a historical backlog', () async {
    await consent();
    await seedCache();
    await store.put('health_anchor', apple.name, {
      'anchor': 'unfinished-history',
      'scope': 'unchanged',
    });
    for (var i = 0; i < 501; i++) {
      await store.put('health_signals', 'history-$i', {'historical': true});
    }
    latest = (call) {
      final asOf = DateTime.parse((call.arguments as Map)['asOf'] as String);
      // 600 measured intervals, including overlap, must not be mistaken for
      // the old five-record import page or one whole-night sample.
      final local = asOf.toLocal();
      var end = DateTime(local.year, local.month, local.day, 7);
      if (end.isAfter(asOf)) {
        end = DateTime(local.year, local.month, local.day - 1, 7);
      }
      final start = end.subtract(const Duration(hours: 7, minutes: 30)).toUtc();
      return [
        row(
          'new-heart',
          'heartRate',
          asOf.subtract(const Duration(minutes: 1)),
        ),
        row(
          'new-resting',
          'restingHeartRate',
          asOf.subtract(const Duration(minutes: 2)),
          value: 60,
        ),
        for (var i = 0; i < 600; i++)
          row(
            'stage-$i',
            'sleep',
            start.add(Duration(seconds: i * 45)),
            value: 45 / 3600,
            unit: 'h',
            attributes: {
              'sleepStage': i.isEven ? 'core' : 'deep',
              'endedAt': start
                  .add(Duration(seconds: (i + 1) * 45))
                  .toIso8601String(),
            },
          ),
        row(
          'overlap',
          'sleep',
          start.add(const Duration(hours: 1)),
          value: 2,
          unit: 'h',
          attributes: {
            'sleepStage': 'rem',
            'endedAt': start.add(const Duration(hours: 3)).toIso8601String(),
          },
        ),
      ];
    };
    final snapshot = await gateway.loadDailyActivity();
    expect(snapshot.signals.singleWhere((s) => s.key == 'heartRate').value, 72);
    expect(
      snapshot.signals.singleWhere((s) => s.key == 'restingHeartRate').value,
      60,
    );
    expect(snapshot.signals.singleWhere((s) => s.key == 'sleep').value, 7.5);
    expect(snapshot.deviceVerified, isTrue);
    expect(
      (await store.get('health_anchor', apple.name))!['anchor'],
      'unfinished-history',
    );
    expect(await store.list('health_signals'), hasLength(1104));
    expect(calls.map((c) => c.method), isNot(contains('readChanges')));
    expect(calls.map((c) => c.method), isNot(contains('requestPermissions')));
    expect(
      (calls.singleWhere((c) => c.method == 'readLatestSignals').arguments
              as Map)
          .keys,
      ['asOf'],
    );
    final cached = await gateway.loadCachedSnapshot();
    expect(cached.signals.singleWhere((s) => s.key == 'sleep').value, 7.5);
  });

  test('no native snapshot is read before explicit consent', () async {
    await gateway.loadDailyActivity();
    expect(calls.map((c) => c.method), isNot(contains('readLatestSignals')));
    expect(calls.map((c) => c.method), isNot(contains('readDailyTotals')));
    expect(calls.map((c) => c.method), isNot(contains('requestPermissions')));
  });

  for (final missingBeginning in [false, true]) {
    test(
      'a complete recent night replaces a partial cached night '
      '${missingBeginning ? 'missing its beginning' : 'with the same start'}',
      () async {
        await consent();
        final now = DateTime.now();
        var end = DateTime(now.year, now.month, now.day, 7);
        if (end.isAfter(now)) {
          end = DateTime(now.year, now.month, now.day - 1, 7);
        }
        final start = end.subtract(const Duration(hours: 8));
        final partialStart = start.add(
          Duration(hours: missingBeginning ? 4 : 0),
        );
        final partial = GlobalHealthSignal(
          key: 'sleep',
          canonicalValue: 2,
          canonicalUnit: 'h',
          provenance: GlobalProvenance(
            providerId: apple.name,
            sourceId: 'com.apple.health',
            recordId: 'partial-night',
            observedAt: partialStart,
            confidence: 1,
          ),
          attributes: {
            'endedAt': partialStart
                .add(const Duration(hours: 2))
                .toIso8601String(),
          },
        );
        await store.put('connected_health_ui', 'snapshot', {
          'signals': [partial.toMap()],
          'signalHistory': [partial.toMap()],
          'importedCount': 1,
          'lastSyncAt': start.toIso8601String(),
        });
        latest = (_) => [
          row(
            'complete-night',
            'sleep',
            start,
            value: 8,
            unit: 'h',
            attributes: {
              'sleepStage': 'asleepUnspecified',
              'endedAt': start.add(const Duration(hours: 8)).toIso8601String(),
            },
          ),
        ];
        final snapshot = await gateway.loadDailyActivity();
        expect(snapshot.signals.singleWhere((s) => s.key == 'sleep').value, 8);
        expect(
          snapshot.signalHistory.where((s) => s.key == 'sleep'),
          hasLength(1),
        );
      },
    );
  }

  test(
    'Android foreground refresh never calls the iOS latest-signal method',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await host.close();
      await host.initialize(
        database: sqlite3.openInMemory(),
        configuration: const GlobalProductRuntimeConfiguration(
          localeCatalogs: [],
        ),
      );
      store = OwnerScopedHealthStore(
        inner: host.productFlows!.store,
        ownerId: currentOwner,
        readCurrentOwnerId: () => currentOwner,
      );
      gateway = NativeConnectedHealthGateway(
        host.productFlows!,
        ownerId: currentOwner,
        currentOwnerId: () => currentOwner,
      );
      await consent('Health Connect');
      await gateway.loadDailyActivity();
      expect(calls.map((c) => c.method), contains('readDailyTotals'));
      expect(calls.map((c) => c.method), isNot(contains('readLatestSignals')));
    },
  );

  for (final fail in [false, true]) {
    test(
      'latest ${fail ? 'error' : 'empty response'} preserves cached HR/Sleep',
      () async {
        await consent();
        await seedCache();
        if (fail) {
          latest = (_) =>
              throw PlatformException(code: 'latest_sleep_limit_exceeded');
        }
        final snapshot = await gateway.loadDailyActivity();
        expect(
          snapshot.signals.singleWhere((s) => s.key == 'heartRate').value,
          64,
        );
        expect(snapshot.signals.singleWhere((s) => s.key == 'sleep').value, 6);
        expect(
          snapshot.signals.singleWhere((s) => s.key == 'steps').value,
          1234,
        );
        expect(await store.list('health_signals'), isEmpty);
      },
    );
  }

  test(
    'empty or in-bed-only data never claims a verified HealthKit read',
    () async {
      await consent();
      activityEnabled = false;
      latest = (call) {
        final at = DateTime.parse((call.arguments as Map)['asOf'] as String);
        return [
          row(
            'bed',
            'sleep',
            at.subtract(const Duration(hours: 8)),
            value: 7,
            unit: 'h',
            attributes: {
              'sleepStage': 'inBed',
              'endedAt': at
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
            },
          ),
        ];
      };
      final snapshot = await gateway.loadDailyActivity();
      expect(snapshot.status, ConnectedHealthStatus.authorizationRequested);
      expect(snapshot.deviceVerified, isFalse);
      expect(snapshot.signals, isEmpty);
      expect(await store.list('health_signals'), isEmpty);
    },
  );

  test(
    'tombstoned, future and stale heart samples cannot re-enter the cache',
    () async {
      await consent();
      await store.put('health_tombstones', '${apple.name}:deleted', {
        'provider': apple.name,
        'recordId': 'deleted',
      });
      latest = (call) {
        final at = DateTime.parse((call.arguments as Map)['asOf'] as String);
        return [
          row('deleted', 'heartRate', at.subtract(const Duration(minutes: 1))),
          row('future', 'heartRate', at.add(const Duration(minutes: 1))),
          row('old', 'heartRate', at.subtract(const Duration(minutes: 31))),
        ];
      };
      final snapshot = await gateway.loadDailyActivity();
      expect(snapshot.signals.where((s) => s.key == 'heartRate'), isEmpty);
      expect(await store.list('health_signals'), isEmpty);
    },
  );

  for (final changeOwner in [false, true]) {
    test(
      '${changeOwner ? 'owner change' : 'background cancellation'} fences a late latest response',
      () async {
        await consent();
        await seedCache();
        final before = await store.get('connected_health_ui', 'snapshot');
        final pending = Completer<Object?>();
        final started = Completer<void>();
        latest = (_) {
          started.complete();
          return pending.future;
        };
        final read = gateway.loadDailyActivity();
        await started.future;
        if (changeOwner) {
          currentOwner = 'different-owner';
        } else {
          await gateway.cancelSynchronization();
        }
        pending.complete([
          row(
            'late-heart',
            'heartRate',
            DateTime.now().subtract(const Duration(minutes: 1)),
          ),
        ]);
        final snapshot = await read;
        if (changeOwner) {
          expect(snapshot.status, ConnectedHealthStatus.unavailable);
        }
        currentOwner = 'latest-health-owner';
        expect(await store.get('connected_health_ui', 'snapshot'), before);
        expect(await store.list('health_signals'), isEmpty);
        if (!changeOwner) {
          expect(calls.map((c) => c.method), contains('cancelLatestSignals'));
        }
      },
    );
  }

  test(
    'a foreground deadline cancels native latest reading and fences late persistence',
    () async {
      await consent();
      await seedCache();
      final pending = Completer<Object?>();
      final started = Completer<void>();
      latest = (_) {
        started.complete();
        return pending.future;
      };
      final controller = ConnectedHealthController(
        gateway,
        synchronizationTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(controller.dispose);
      await controller.restoreCachedSnapshot();
      final read = controller.refreshDailyActivity(force: true);
      await started.future;
      await read;
      expect(controller.state.value!.status, ConnectedHealthStatus.degraded);
      await Future<void>.delayed(Duration.zero);
      expect(calls.map((c) => c.method), contains('cancelLatestSignals'));
      pending.complete([
        row(
          'late-heart',
          'heartRate',
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(await store.list('health_signals'), isEmpty);
      expect(
        controller.state.value!.signals
            .singleWhere((s) => s.key == 'heartRate')
            .value,
        64,
      );
    },
  );

  test(
    'revoked explicit consent fences a latest response already in flight',
    () async {
      await consent();
      final pending = Completer<Object?>();
      final started = Completer<void>();
      latest = (_) {
        started.complete();
        return pending.future;
      };
      final read = gateway.loadDailyActivity();
      await started.future;
      await store.put('connected_health_consent', 'Apple Health', {
        'readRequested': false,
      });
      pending.complete([
        row(
          'late-heart',
          'heartRate',
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ]);
      expect((await read).status, ConnectedHealthStatus.unavailable);
      expect(await store.list('health_signals'), isEmpty);
      expect(await store.get('connected_health_ui', 'snapshot'), isNull);
    },
  );

  for (final truncated in [false, true]) {
    test(
      'oldest sleep night ${truncated ? 'with truncated coverage retains' : 'across the old72h cutoff imports'} all8measured hours',
      () async {
        final asOf = DateTime(2026, 11, 16, 2);
        final start = DateTime(2026, 11, 12, 23);
        final split = DateTime(2026, 11, 13, 2);
        final end = DateTime(2026, 11, 13, 7);
        gateway = NativeConnectedHealthGateway(
          host.productFlows!,
          ownerId: currentOwner,
          currentOwnerId: () => currentOwner,
          foregroundNow: () => asOf,
        );
        await consent();
        activityEnabled = false;
        final retained = GlobalHealthSignal(
          key: 'sleep',
          canonicalValue: 8,
          canonicalUnit: 'h',
          provenance: GlobalProvenance(
            providerId: apple.name,
            sourceId: 'com.apple.health',
            recordId: 'complete-oldest-night',
            observedAt: start,
            confidence: 1,
          ),
          attributes: {'endedAt': end.toUtc().toIso8601String()},
        );
        await store.put('connected_health_ui', 'snapshot', {
          'signals': [retained.toMap()],
          'signalHistory': [retained.toMap()],
          'importedCount': 1,
          'lastSyncAt': asOf.toUtc().toIso8601String(),
        });
        latest = (_) => [
          if (!truncated)
            row(
              'before-old-cutoff',
              'sleep',
              start,
              value: 3,
              unit: 'h',
              attributes: {
                'sleepStage': 'core',
                'endedAt': split.toUtc().toIso8601String(),
              },
            ),
          row(
            'after-old-cutoff',
            'sleep',
            split,
            value: 5,
            unit: 'h',
            attributes: {
              'sleepStage': 'deep',
              'endedAt': end.toUtc().toIso8601String(),
              if (truncated)
                'latestSleepWindowStart': split.toUtc().toIso8601String(),
            },
          ),
        ];
        final snapshot = await gateway.loadDailyActivity();
        expect(snapshot.signals.singleWhere((s) => s.key == 'sleep').value, 8);
        expect(
          snapshot.signalHistory.singleWhere((s) => s.key == 'sleep').value,
          8,
        );
        expect(
          await store.list('health_signals'),
          hasLength(truncated ? 0 : 2),
        );
        expect(calls.map((c) => c.method), isNot(contains('readChanges')));
      },
    );
  }

  test('sleep stage overlapping the lower noon boundary stays whole', () async {
    final asOf = DateTime(2026, 11, 16, 18);
    gateway = NativeConnectedHealthGateway(
      host.productFlows!,
      ownerId: currentOwner,
      currentOwnerId: () => currentOwner,
      foregroundNow: () => asOf,
    );
    await consent();
    activityEnabled = false;
    latest = (_) => [
      row(
        'across-noon',
        'sleep',
        DateTime(2026, 11, 13, 11),
        value: 2,
        unit: 'h',
        attributes: {
          'sleepStage': 'core',
          'endedAt': DateTime(2026, 11, 13, 13).toUtc().toIso8601String(),
        },
      ),
      row(
        'after-noon',
        'sleep',
        DateTime(2026, 11, 13, 13),
        value: 4,
        unit: 'h',
        attributes: {
          'sleepStage': 'deep',
          'endedAt': DateTime(2026, 11, 13, 17).toUtc().toIso8601String(),
        },
      ),
    ];
    final snapshot = await gateway.loadDailyActivity();
    expect(snapshot.signals.singleWhere((s) => s.key == 'sleep').value, 6);
    expect(await store.list('health_signals'), hasLength(2));
  });

  for (final missing in [false, true]) {
    test(
      'ambiguous sleep coverage ${missing ? 'missing' : 'inconsistent'} preserves cache',
      () async {
        await consent();
        await seedCache();
        final before = await store.get('connected_health_ui', 'snapshot');
        latest = (call) {
          final asOf = DateTime.parse(
            (call.arguments as Map)['asOf'] as String,
          );
          return [
            for (var i = 0; i < 2; i++)
              row(
                'ambiguous-$i',
                'sleep',
                asOf.subtract(Duration(hours: 4 - i)),
                value: 1,
                unit: 'h',
                attributes: {
                  'sleepStage': 'core',
                  'endedAt': asOf
                      .subtract(Duration(hours: 3 - i))
                      .toIso8601String(),
                  'latestSleepWindowStart': missing
                      ? null
                      : asOf
                            .subtract(Duration(hours: 72 - i))
                            .toIso8601String(),
                },
              ),
          ];
        };
        final snapshot = await gateway.loadDailyActivity();
        expect(snapshot.signals.singleWhere((s) => s.key == 'sleep').value, 6);
        expect(await store.list('health_signals'), isEmpty);
        expect(
          (await store.get(
            'connected_health_ui',
            'snapshot',
          ))!['signalHistory'],
          before!['signalHistory'] ?? [],
        );
      },
    );
  }

  test(
    'deferred gateway cancellation fences its own held latest response',
    () async {
      await consent();
      await seedCache();
      final before = await store.get('connected_health_ui', 'snapshot');
      final deferred = DeferredConnectedHealthGateway(
        ownerId: currentOwner,
        currentOwnerId: () => currentOwner,
      );
      final pending = Completer<Object?>();
      final started = Completer<void>();
      latest = (_) {
        started.complete();
        return pending.future;
      };
      final read = deferred.loadDailyActivity();
      await started.future;
      await deferred.cancelSynchronization();
      pending.complete([
        row(
          'deferred-late-heart',
          'heartRate',
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ]);
      await read;
      expect(await store.get('connected_health_ui', 'snapshot'), before);
      expect(await store.list('health_signals'), isEmpty);
    },
  );

  for (final deferred in [false, true]) {
    test(
      '${deferred ? 'deferred' : 'native'} cancellation during held availability starts no snapshots',
      () async {
        await consent();
        await seedCache();
        final before = await store.get('connected_health_ui', 'snapshot');
        final ConnectedHealthGateway target = deferred
            ? DeferredConnectedHealthGateway(
                ownerId: currentOwner,
                currentOwnerId: () => currentOwner,
              )
            : gateway;
        final pending = Completer<Object?>();
        final started = Completer<void>();
        availability = (_) {
          started.complete();
          return pending.future;
        };
        final read = (target as ConnectedHealthDailyActivityGateway)
            .loadDailyActivity();
        await started.future;
        await (target as ConnectedHealthCancellableSyncGateway)
            .cancelSynchronization();
        pending.complete({'available': true});
        await read;
        expect(
          calls.map((c) => c.method),
          isNot(contains('readLatestSignals')),
        );
        expect(calls.map((c) => c.method), isNot(contains('readDailyTotals')));
        expect(await store.get('connected_health_ui', 'snapshot'), before);
        expect(await store.list('health_signals'), isEmpty);
      },
    );
  }

  test(
    'sleep ending exactly at the query-floor noon cannot replace a complete cache',
    () async {
      final asOf = DateTime(2026, 11, 16, 18);
      gateway = NativeConnectedHealthGateway(
        host.productFlows!,
        ownerId: currentOwner,
        currentOwnerId: () => currentOwner,
        foregroundNow: () => asOf,
      );
      await consent();
      await seedCache();
      activityEnabled = false;
      latest = (_) => [
        row(
          'ends-at-floor',
          'sleep',
          DateTime(2026, 11, 13, 11),
          value: 1,
          unit: 'h',
          attributes: {
            'sleepStage': 'core',
            'endedAt': DateTime(2026, 11, 13, 12).toUtc().toIso8601String(),
          },
        ),
      ];
      final snapshot = await gateway.loadDailyActivity();
      expect(snapshot.signals.singleWhere((s) => s.key == 'sleep').value, 6);
      expect(await store.list('health_signals'), isEmpty);
    },
  );

  test('sleep noon buckets use half-open interval ends', () {
    GlobalHealthSignal stage(int hour) => GlobalHealthSignal(
      key: 'sleep',
      canonicalValue: 1,
      canonicalUnit: 'h',
      provenance: GlobalProvenance(
        providerId: apple.name,
        sourceId: 'com.apple.health',
        recordId: 'noon-$hour',
        observedAt: DateTime(2026, 11, 13, hour),
        confidence: 1,
      ),
      attributes: {
        'sleepStage': 'core',
        'endedAt': DateTime(2026, 11, 13, hour + 1).toUtc().toIso8601String(),
      },
    );
    final nights = aggregateConnectedSleepSignals([stage(11), stage(12)]);
    expect(nights, hasLength(2));
    expect(nights.map((s) => s.canonicalValue), everyElement(1));
  });

  test(
    'deferred cancellation before native initialization continuation starts no reads',
    () async {
      await consent();
      await seedCache();
      final before = await store.get('connected_health_ui', 'snapshot');
      final deferred = DeferredConnectedHealthGateway(
        ownerId: currentOwner,
        currentOwnerId: () => currentOwner,
      );
      final read = deferred.loadDailyActivity();
      await deferred.cancelSynchronization();
      await read;
      expect(calls.map((c) => c.method), isNot(contains('availability')));
      expect(calls.map((c) => c.method), isNot(contains('readLatestSignals')));
      expect(calls.map((c) => c.method), isNot(contains('readDailyTotals')));
      expect(await store.get('connected_health_ui', 'snapshot'), before);
    },
  );

  test('native latest query is date sorted, own-app filtered and fails instead '
      'of returning truncated sleep; anchors remain separate', () {
    final swift = File(
      'ios/Runner/BILGlobalHealthBridge.swift',
    ).readAsStringSync();
    final method = swift.substring(
      swift.indexOf('  private func readLatestSignals('),
      swift.indexOf('  private func isLatestReadActive('),
    );
    expect(
      method,
      contains('HKSampleSortIdentifierStartDate, ascending: false'),
    );
    expect(
      method,
      contains('HKQuery.predicateForObjects(from: HKSource.default())'),
    );
    expect(method, contains('Self.latestSleepSampleLimit + 1'));
    expect(method, contains('latest_sleep_limit_exceeded'));
    expect(method, contains('Self.recentSleepWindowStart(asOf: asOf)'));
    expect(
      method,
      contains(
        'isSleep ? [.strictEndDate] : [.strictStartDate, .strictEndDate]',
      ),
    );
    expect(method, contains('attributes["latestSleepWindowStart"]'));
    expect(method, contains('guard sample.endDate > sleepWindowStart'));
    expect(
      swift,
      contains(
        'calendar.date(bySettingHour: 12, minute: 0, second: 0, of: cutoff)',
      ),
    );
    expect(method, isNot(contains('HKAnchoredObjectQuery')));
    expect(method, isNot(contains('encodeAnchors')));
    expect(swift, contains('self?.cancelLatestSignals()'));
  });
}
