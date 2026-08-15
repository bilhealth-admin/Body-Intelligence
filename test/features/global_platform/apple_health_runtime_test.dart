import 'package:body_intelligence_log/features/global_platform/health_data/apple_health_platform.dart';

import 'global_platform_test_support.dart';

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
