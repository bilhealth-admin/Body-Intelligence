import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/runtime/global_product_composition_root.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bil/health_connect');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final host = GlobalNativeIntegrationHost.instance;
  late NativeConnectedHealthGateway gateway;
  late List<MethodCall> calls;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'availability' => {'available': true},
        'permissions' => {
          'steps': true,
          'distance': true,
          'activeEnergy': true,
        },
        'requestPermissions' => {'granted': 3},
        _ => null,
      };
    });
    await host.initialize(
      database: sqlite3.openInMemory(),
      configuration: const GlobalProductRuntimeConfiguration(
        localeCatalogs: [],
      ),
    );
    gateway = NativeConnectedHealthGateway(host.productFlows!);
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await host.close();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'explicit Android request sends only the three activity read types',
    () async {
      await gateway.requestPermissions();
      final request = calls.singleWhere(
        (call) => call.method == 'requestPermissions',
      );
      expect(
        (request.arguments as Map)['types'],
        unorderedEquals(['steps', 'distance', 'activeEnergy']),
      );
      expect((request.arguments as Map)['write'], isFalse);
      expect(calls.map((call) => call.method), isNot(contains('readChanges')));
    },
  );

  test(
    'Android export cannot request native writes or persist export consent',
    () async {
      await gateway.requestWeightWritePermission();
      expect(
        calls.map((call) => call.method),
        isNot(contains('requestPermissions')),
      );
      expect(
        await host.productFlows!.store.get(
          'connected_health_consent',
          'Health Connect',
        ),
        isNull,
      );
    },
  );

  test(
    'obsolete imported types leave the display, not the underlying history',
    () async {
      final store = host.productFlows!.store;
      Map<String, Object?> row(String key, double value, String unit) =>
          GlobalHealthSignal(
            key: key,
            canonicalValue: value,
            canonicalUnit: unit,
            provenance: GlobalProvenance(
              providerId: 'bil/health_connect',
              sourceId: 'fitness-source',
              recordId: key,
              observedAt: DateTime.now(),
              confidence: 1,
            ),
          ).toMap();
      final sleep = row('sleep', 8, 'h');
      await store.put('health_signals', 'retained-sleep', sleep);
      await store.put('connected_health_ui', 'snapshot', {
        'signals': [
          row('steps', 123, 'count'),
          sleep,
          row('bodyFat', 20, '%'),
          row('restingHeartRate', 60, 'count/min'),
        ],
        'importedCount': 4,
      });
      final loaded = await gateway.load();
      expect(loaded.signals.map((signal) => signal.key), ['steps']);
      expect(loaded.importedCount, 1);
      expect(loaded.deviceVerified, isTrue);
      expect(
        (await store.get('connected_health_ui', 'snapshot'))!['signals'],
        hasLength(1),
      );
      expect(await store.get('health_signals', 'retained-sleep'), sleep);
    },
  );

  test('startup never opens an Android permission sheet', () async {
    expect(await gateway.requestStartupPermissions(), isNull);
    expect(calls, isEmpty);
  });
}
