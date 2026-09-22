import 'dart:async';

import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/global_platform/runtime/global_product_composition_root.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'paged HealthKit import and SQLite reconciliation keep yielding; '
    'repeated sync taps share one import without reading a wearable',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('bil/apple_health');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final nativeCalls = <String>[];
      final pageAnchors = <String?>[];
      var completed = false;
      var eventTurnsDuringSync = 0;
      final asOf = DateTime.now().toUtc();
      messenger.setMockMethodCallHandler(channel, (call) async {
        nativeCalls.add(call.method);
        switch (call.method) {
          case 'availability':
            return {'available': true};
          case 'permissions':
            return <String, bool>{}; // HealthKit read access is indeterminate.
          case 'readDailyTotals':
            return <Object?>[];
          case 'enableBackgroundDelivery':
            return null;
          case 'readChanges':
            final args = call.arguments as Map;
            final anchor = args['anchor'] as String?;
            pageAnchors.add(anchor);
            final start = anchor == null ? 0 : 128;
            return {
              'records': [
                for (var index = start; index < start + 128; index++)
                  {
                    'id': 'heart-$index',
                    'type': 'heartRate',
                    'value': 70.0 + index % 5,
                  'unit': 'count/min',
                    'observedAt': asOf
                        .subtract(Duration(minutes: index + 1))
                        .toIso8601String(),
                    'sourceId': 'com.apple.health',
                    'deviceId': 'Apple Watch',
                    'confidence': 1.0,
                  },
              ],
              'deletedIds': <String>[],
              'nextAnchor': anchor == null ? 'page-1' : 'page-2',
              'hasMore': anchor == null,
            };
          default:
            throw StateError('Unexpected native action: ${call.method}');
        }
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
      await flows.store.put('connected_health_consent', 'Apple Health', {
        'readRequested': true,
        'historicalReadResetAt': asOf.toIso8601String(),
      });
      final controller = ConnectedHealthController(
        NativeConnectedHealthGateway(flows),
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      final heartbeat = Timer.periodic(Duration.zero, (_) {
        if (!completed) eventTurnsDuringSync++;
      });
      addTearDown(heartbeat.cancel);
      await Future.wait([
        for (var tap = 0; tap < 5; tap++) controller.synchronize(),
      ]);
      completed = true;
      heartbeat.cancel();

      expect(pageAnchors, [null, 'page-1']);
      expect(eventTurnsDuringSync, greaterThan(8));
      expect((await flows.store.list('health_signals')), hasLength(256));
      expect(controller.state.value!.isBusy, isFalse);
      expect(controller.state.value!.failureCode, isNull);
      expect(
        controller.state.value!.signals.any((s) => s.key == 'heartRate'),
        isTrue,
      );
      expect(nativeCalls, isNot(contains('requestPermissions')));
      expect(nativeCalls, isNot(contains('scan')));
    },
  );
}
