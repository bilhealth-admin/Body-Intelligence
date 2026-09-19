import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/providers/exercise_calorie_providers.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/runtime/global_product_composition_root.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test('$platform: native daily kcal reach the dashboard energy selector '
        'without duplication and survive a failed refresh', () async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final ios = platform == TargetPlatform.iOS;
      final source = ios ? 'Apple Health' : 'Health Connect';
      final bridgeId = ios ? 'bil/apple_health' : 'bil/health_connect';
      final channel = MethodChannel(bridgeId);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var failRead = false;
      var emptyRead = false;
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      Map<String, Object?> daily(String key, double value, DateTime at) => {
        'id': '$key:${at.toIso8601String()}',
        'type': key,
        'value': value,
        'unit': key == 'activeEnergy' ? 'kcal' : 'count',
        'observedAt': at.toUtc().toIso8601String(),
        'sourceId': '$bridgeId.statistics',
        'confidence': 1.0,
        'attributes': {'aggregation': 'native_daily'},
      };
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'availability') return {'available': true};
        if (call.method == 'permissions') {
          return {'steps': true, 'distance': true, 'activeEnergy': true};
        }
        if (call.method == 'readDailyTotals') {
          if (failRead) throw PlatformException(code: 'daily_totals_failed');
          if (emptyRead) return const <Object?>[];
          return [
            daily('activeEnergy', 900, yesterday),
            daily('activeEnergy', 321, now),
            daily('activeEnergy', 321, now),
            daily('steps', 4321, now),
          ];
        }
        throw StateError('Unexpected native operation: ${call.method}');
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
      await flows.store.put('connected_health_consent', source, {
        'readRequested': true,
      });
      final original = GlobalHealthSignal(
        key: 'activeEnergy',
        canonicalValue: 111,
        canonicalUnit: 'kcal',
        provenance: GlobalProvenance(
          providerId: bridgeId,
          sourceId: 'previous-native-read',
          recordId: 'previous-native-read',
          observedAt: now,
          confidence: 1,
        ),
      ).toMap();
      // iOS still supports these reads. A lightweight activity refresh must
      // retain them instead of replacing the entire health snapshot. Android
      // deliberately retains its separate, minimum three-type permission scope.
      final otherSignals = [
        if (ios)
          for (final metric in const [
            ('weight', 87.0, 'kg'),
            ('heartRate', 75.0, 'bpm'),
            ('sleep', 7.5, 'h'),
          ])
            GlobalHealthSignal(
              key: metric.$1,
              canonicalValue: metric.$2,
              canonicalUnit: metric.$3,
              provenance: GlobalProvenance(
                providerId: bridgeId,
                sourceId: 'previous-native-read',
                recordId: 'previous-${metric.$1}',
                observedAt: now,
                confidence: 1,
              ),
            ).toMap(),
      ];
      await flows.store.put('health_signals', 'preserved-raw-sample', original);
      await flows.store.put('connected_health_ui', 'snapshot', {
        'importedCount': 42,
        'signals': [original, ...otherSignals],
        'stepHistory': <Object?>[],
      });
      final gateway = NativeConnectedHealthGateway(flows);
      for (var refresh = 0; refresh < 2; refresh++) {
        final result = await gateway.loadDailyActivity();
        expect(result.failureCode, isNull);
        expect(result.deviceVerified, isTrue);
        expect(result.importedCount, 42);
        expect(
          result.signals.where((row) => row.key == 'activeEnergy'),
          hasLength(1),
        );
        expect(authoritativeExerciseEnergyForDay(result, now)?.kcal, 321);
        expect(authoritativeExerciseEnergyForDay(result, yesterday), isNull);
        expect(result.stepHistory.single.value, 4321);
        if (ios) {
          expect(
            result.signals.singleWhere((s) => s.key == 'weight').value,
            87,
          );
          expect(
            result.signals.singleWhere((s) => s.key == 'heartRate').value,
            75,
          );
          expect(
            result.signals.singleWhere((s) => s.key == 'sleep').value,
            7.5,
          );
        }
      }
      emptyRead = true;
      final afterEmpty = await gateway.loadDailyActivity();
      expect(afterEmpty.failureCode, isNull);
      expect(
        afterEmpty.signals.where((row) => row.key == 'activeEnergy'),
        hasLength(1),
      );
      expect(
        afterEmpty.signals
            .singleWhere((row) => row.key == 'activeEnergy')
            .value,
        321,
      );
      expect(afterEmpty.stepHistory.single.value, 4321);
      failRead = true;
      final afterFailure = await gateway.loadDailyActivity();
      expect(
        afterFailure.failureCode,
        'daily_activity_refresh_failed_cache_preserved',
      );
      expect(authoritativeExerciseEnergyForDay(afterFailure, now)?.kcal, 321);
      expect(
        await flows.store.get('health_signals', 'preserved-raw-sample'),
        original,
      );
    });
  }
}
