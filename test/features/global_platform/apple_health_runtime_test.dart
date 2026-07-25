import 'global_platform_test_support.dart';

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
}
