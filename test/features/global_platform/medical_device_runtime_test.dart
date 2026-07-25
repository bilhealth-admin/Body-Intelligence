import 'global_platform_test_support.dart';

void main() {
  test(
    'medical ingestion validates calibration provenance and dedupe',
    () async {
      final store = InMemoryGlobalStore();
      final runtime = MedicalDeviceRuntime(
        providers: [TestMedical()],
        store: store,
        audit: InMemoryGlobalAuditSink(),
      );
      expect((await runtime.ingest(DateTime.utc(2026))).length, 1);
      expect(await runtime.ingest(DateTime.utc(2026)), isEmpty);
    },
  );
}
