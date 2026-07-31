import 'global_platform_test_support.dart';

void main() {
  test(
    'commerce uses cryptographic fingerprint and replay protection',
    () async {
      final store = InMemoryGlobalStore();
      final runtime = CommerceRuntime(
        store: store,
        audit: InMemoryGlobalAuditSink(),
        verifiers: [TestVerifier()],
        productFeatures: {
          'premium': {'reports'},
        },
      );
      expect(
        await runtime.validate(receipt: [1, 2, 3], at: DateTime.utc(2026)),
        isNotNull,
      );
      expect(
        await runtime.validate(receipt: [1, 2, 3], at: DateTime.utc(2026)),
        isNull,
      );
      expect(await runtime.has('a1', 'reports', DateTime.utc(2026)), true);
    },
  );
}
