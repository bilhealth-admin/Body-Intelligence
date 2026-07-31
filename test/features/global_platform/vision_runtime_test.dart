import 'global_platform_test_support.dart';

void main() {
  test('vision persists review lifecycle', () async {
    final store = InMemoryGlobalStore();
    final runtime = VisionRuntime(
      provider: TestVision(),
      store: store,
      audit: InMemoryGlobalAuditSink(),
    );
    final job = await runtime.submit(
      id: 'j1',
      kind: VisionJobKind.meal,
      bytes: [1],
      at: DateTime.utc(2026),
      consent: GlobalConsentGrant(
        scope: 'vision',
        state: GlobalConsentState.granted,
        updatedAt: DateTime.utc(2026),
      ),
    );
    expect(job.status, VisionJobStatus.accepted);
    await runtime.review(
      id: 'j1',
      accept: true,
      corrections: {'food': 'grilled chicken'},
      at: DateTime.utc(2026),
    );
    expect((await store.get('vision_feedback', 'j1'))?['accepted'], true);
  });
}
