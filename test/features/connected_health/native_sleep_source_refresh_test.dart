// Genuine gateway, native channel protocol, canonical store and projection.
// Only the HealthKit platform replies are host fixtures, not device evidence.
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/runtime/global_product_composition_root.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final watch in [true, false]) {
    test(
      'same-night native metadata refresh retains genuine device evidence watch=$watch',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        const channel = MethodChannel('bil/apple_health');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final calls = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'availability' => {'available': true},
            'permissions' => <String, bool>{},
            'readDailyTotals' => <Object?>[],
            'enableBackgroundDelivery' => null,
            'readChanges' => {
              'records': <Object?>[],
              'deletedIds': <String>[],
              'nextAnchor': 'unchanged-native-anchor',
              'hasMore': false,
            },
            _ => throw StateError('Unexpected native method ${call.method}'),
          };
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final host = GlobalNativeIntegrationHost.instance;
        await host.initialize(
          database: sqlite3.openInMemory(),
          configuration: const GlobalProductRuntimeConfiguration(
            localeCatalogs: [],
          ),
        );
        addTearDown(host.close);
        final flows = host.productFlows!;
        final now = DateTime.now().toUtc();
        final started = now.subtract(const Duration(hours: 5));
        final native = GlobalHealthSignal(
          key: 'sleep',
          canonicalValue: 2.7,
          canonicalUnit: 'h',
          provenance: GlobalProvenance(
            providerId: flows.appleHealth.bridge.id,
            sourceId: 'com.apple.health.7D45981D-2E64-49B7-B40B-97FAB08A7E3B',
            recordId: 'native-sleep-owner-device',
            observedAt: started,
            confidence: 1,
            timeZoneId: 'UTC',
          ),
          attributes: {
            'sleepStage': 'asleepUnspecified',
            'endedAt': started
                .add(const Duration(minutes: 162))
                .toIso8601String(),
            'sourceProductType': watch ? 'Watch6,2' : 'iPhone14,2',
            if (watch) 'wearableKind': 'apple_watch',
          },
        );
        await flows.store.put(
          'health_signals',
          native.identity,
          native.toMap(),
        );
        // Exact legacy UI projection shape: old aggregation dropped native
        // attributes, but retained the same identity, value and provenance.
        final fresh = aggregateConnectedSleepSignals([native]).single;
        final legacy = fresh.toMap();
        legacy['attributes'] = {
          'endedAt': fresh.attributes['endedAt'],
          'sourceSessionIds': fresh.attributes['sourceSessionIds'],
          'measuredStages': fresh.attributes['measuredStages'],
        };
        await flows.store.put('connected_health_consent', 'Apple Health', {
          'readRequested': true,
          'historicalReadResetAt': now.toIso8601String(),
        });
        await flows.store.put('connected_health_ui', 'snapshot', {
          'lastSyncAt': now.toIso8601String(),
          'importedCount': 1,
          'signals': [legacy],
          'stepHistory': <Object?>[],
          'signalHistory': <Object?>[],
        });
        final gateway = NativeConnectedHealthGateway(flows);
        final cached = await gateway.loadCachedSnapshot();
        expect(cached.deviceVerified, isTrue);
        expect(
          connectedHealthDisplaySource(cached.signals.single),
          'Apple Health',
        );
        final actual = await gateway.synchronize();
        expect(actual.failureCode, isNull);
        expect(actual.deviceVerified, isTrue);
        final sleep = actual.signals.singleWhere((row) => row.key == 'sleep');
        expect(sleep.value, closeTo(2.7, 0.00001));
        expect(sleep.unit, 'h');
        expect(sleep.source, native.provenance.sourceId);
        expect(sleep.observedAt, fresh.provenance.observedAt);
        expect(sleep.confidence, fresh.provenance.confidence);
        expect(
          connectedHealthDisplaySource(sleep),
          watch ? 'Apple Watch' : 'Apple Health',
        );
        expect(
          sleep.attributes['sourceProductType'],
          watch ? 'Watch6,2' : 'iPhone14,2',
        );
        expect(await flows.store.list('health_signals'), [native.toMap()]);
        expect(calls, contains('readChanges'));
        expect(calls, isNot(contains('requestPermissions')));
        final relaunched = await NativeConnectedHealthGateway(
          flows,
        ).loadCachedSnapshot();
        expect(
          connectedHealthDisplaySource(relaunched.signals.single),
          watch ? 'Apple Watch' : 'Apple Health',
        );
        expect(relaunched.signals.single.value, sleep.value);
      },
    );
  }
}
