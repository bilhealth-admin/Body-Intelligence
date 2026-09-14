import 'dart:async';

import 'package:body_intelligence_log/features/global_platform/health_data/apple_health_platform.dart';

import 'global_platform_test_support.dart';

final class _BurstAppleBridge implements NativeHealthBridge {
  _BurstAppleBridge(this.recordCount);

  final int recordCount;

  @override
  String get id => 'bil/apple_health';

  @override
  Future<void> delete(List<String> recordIds) async {}

  @override
  Future<Map<String, bool>> permissions() async => const {};

  @override
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  }) async => NativeHealthPage(
    records: [
      for (var index = 0; index < recordCount; index++)
        NativeHealthRecord(
          id: 'weight-$index',
          type: HealthDataType.weight,
          value: 80 + (index / 1000),
          unit: 'kg',
          observedAt: asOf.subtract(Duration(minutes: index + 1)),
          sourceId: 'healthkit',
          deviceId: 'watch',
          confidence: 1,
          providerId: id,
        ),
    ],
    deletedIds: const [],
    nextAnchor: 'burst-complete',
    hasMore: false,
  );

  @override
  Future<void> request(Set<String> types, {required bool write}) async {}

  @override
  Future<void> write(List<GlobalHealthSignal> signals) async {}
}

final class _HangingCancellableAppleBridge
    implements NativeHealthBridge, NativeHealthCancellableReadBridge {
  final Completer<NativeHealthPage> pendingRead =
      Completer<NativeHealthPage>();
  int cancellations = 0;

  @override
  String get id => 'bil/apple_health';

  @override
  Future<void> cancelReadChanges() async {
    cancellations++;
  }

  @override
  Future<void> delete(List<String> recordIds) async {}

  @override
  Future<Map<String, bool>> permissions() async => const {};

  @override
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  }) =>
      pendingRead.future;

  @override
  Future<void> request(Set<String> types, {required bool write}) async {}

  @override
  Future<void> write(List<GlobalHealthSignal> signals) async {}
}

final class _RecordingAppleBridge implements NativeHealthBridge {
  int writes = 0;
  @override
  String get id => 'bil/apple_health';
  @override
  Future<void> delete(List<String> recordIds) async {}
  @override
  Future<Map<String, bool>> permissions() async => const {};
  @override
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  }) async => const NativeHealthPage(
    records: [],
    deletedIds: [],
    nextAnchor: null,
    hasMore: false,
  );
  @override
  Future<void> request(Set<String> types, {required bool write}) async {}
  @override
  Future<void> write(List<GlobalHealthSignal> signals) async {
    writes++;
  }
}

void main() {
  test('health bridge performs permissioned anchored normalization', () async {
    final store = InMemoryGlobalStore();
    final runtime = UnifiedHealthDataRuntime(
      bridges: [TestHealthBridge()],
      store: store,
      audit: InMemoryGlobalAuditSink(),
    );
    final out = await runtime.synchronize(
      asOf: DateTime.utc(2026),
      consent: GlobalConsentGrant(
        scope: 'health.read',
        state: GlobalConsentState.granted,
        updatedAt: DateTime.utc(2026),
      ),
    );
    expect(out.single.canonicalValue, closeTo(100, 0.001));
    expect((await store.get('health_anchor', 'test-health'))?['anchor'], 'a1');
  });

  test(
    'health persistence yields an event turn before a large sync completes',
    () async {
      final runtime = UnifiedHealthDataRuntime(
        bridges: [_BurstAppleBridge(32)],
        store: InMemoryGlobalStore(),
        audit: InMemoryGlobalAuditSink(),
      );
      var completed = false;
      var uiTurnObservedBeforeCompletion = false;
      Timer.run(() {
        uiTurnObservedBeforeCompletion = !completed;
      });

      await runtime
          .synchronize(
            asOf: DateTime.utc(2026, 9, 13, 20),
            consent: GlobalConsentGrant(
              scope: 'apple_health_read',
              state: GlobalConsentState.granted,
              updatedAt: DateTime.utc(2026, 9, 13, 20),
            ),
            types: const {HealthDataType.weight},
          )
          .whenComplete(() => completed = true);
      await Future<void>.delayed(Duration.zero);

      expect(uiTurnObservedBeforeCompletion, isTrue);
    },
  );

  test(
    'stalled Apple Health reads hit a foreground deadline and cancel natively',
    () async {
      final bridge = _HangingCancellableAppleBridge();
      final runtime = UnifiedHealthDataRuntime(
        bridges: [bridge],
        store: InMemoryGlobalStore(),
        audit: InMemoryGlobalAuditSink(),
        appleReadTimeout: const Duration(milliseconds: 25),
      );

      await expectLater(
        runtime.synchronize(
          asOf: DateTime.utc(2026, 9, 14, 8),
          consent: GlobalConsentGrant(
            scope: 'apple_health_read',
            state: GlobalConsentState.granted,
            updatedAt: DateTime.utc(2026, 9, 14, 8),
          ),
          types: const {HealthDataType.weight},
        ),
        throwsA(isA<TimeoutException>()),
      );

      expect(bridge.cancellations, 1);
    },
  );

  test(
    'Apple export fails closed before native bridge for nutrition',
    () async {
      final bridge = _RecordingAppleBridge();
      final runtime = AppleHealthRuntime(
        bridge: bridge,
        store: InMemoryGlobalStore(),
        audit: InMemoryGlobalAuditSink(),
      );
      final signal = GlobalHealthSignal(
        key: HealthDataType.nutrition.name,
        canonicalValue: 450,
        canonicalUnit: 'kcal',
        provenance: GlobalProvenance(
          providerId: 'manual',
          sourceId: 'bil_diary',
          recordId: 'meal-1',
          observedAt: DateTime.utc(2026),
          confidence: 1,
        ),
      );

      await expectLater(
        runtime.export(
          signals: [signal],
          consent: GlobalConsentGrant(
            scope: 'health.write',
            state: GlobalConsentState.granted,
            updatedAt: DateTime.utc(2026),
          ),
        ),
        throwsStateError,
      );
      expect(bridge.writes, 0);
    },
  );
}
