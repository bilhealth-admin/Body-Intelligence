import 'global_platform_test_support.dart';

void main() {
  test('fitness ingestion validates provenance and dedupe', () async {
    final store = InMemoryGlobalStore();
    final runtime = FitnessDeviceRuntime(
      providers: [TestFitness()],
      store: store,
      audit: InMemoryGlobalAuditSink(),
    );
    expect((await runtime.ingest(DateTime.utc(2026))).length, 1);
    expect(await runtime.ingest(DateTime.utc(2026)), isEmpty);
  });
}
