import 'global_platform_test_support.dart';

void main() {
  test('health runtime blocks access without consent', () async {
    final out =
        await UnifiedHealthDataRuntime(
          bridges: [TestHealthBridge()],
          store: InMemoryGlobalStore(),
          audit: InMemoryGlobalAuditSink(),
        ).synchronize(
          asOf: DateTime.utc(2026),
          consent: GlobalConsentGrant(
            scope: 'health',
            state: GlobalConsentState.denied,
            updatedAt: DateTime.utc(2026),
          ),
        );
    expect(out, isEmpty);
  });
}
