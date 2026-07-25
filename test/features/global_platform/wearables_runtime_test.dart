import 'global_platform_test_support.dart';

void main() {
  test('wearable runtime persists cursor and reconciles', () async {
    final store = InMemoryGlobalStore();
    final out = await WearableRuntime(
      providers: [TestWearable()],
      store: store,
      audit: InMemoryGlobalAuditSink(),
    ).synchronize(DateTime.utc(2026));
    expect(out.single.key, 'steps');
    expect((await store.get('wearable_cursor', 'garmin'))?['value'], 'c1');
  });
}
