import 'global_platform_test_support.dart';

void main() {
  test('cloud AI is optional consent gated and budgeted', () async {
    final runtime = OptionalCloudAiRuntime(
      providers: [TestCloudAi()],
      store: InMemoryGlobalStore(),
      audit: InMemoryGlobalAuditSink(),
      monthlyTokenBudget: 100,
    );
    final denied = await runtime.run(
      request: const CloudAiRequest(
        id: '1',
        capability: 'summary',
        redactedPayload: {},
        maxTokens: 20,
        timeout: Duration(seconds: 1),
      ),
      consent: GlobalConsentGrant(
        scope: 'ai',
        state: GlobalConsentState.denied,
        updatedAt: DateTime.utc(2026),
      ),
      localOnly: false,
      at: DateTime.utc(2026),
    );
    expect(denied, isNull);
    final accepted = await runtime.run(
      request: const CloudAiRequest(
        id: '2',
        capability: 'summary',
        redactedPayload: {},
        maxTokens: 20,
        timeout: Duration(seconds: 1),
      ),
      consent: GlobalConsentGrant(
        scope: 'ai',
        state: GlobalConsentState.granted,
        updatedAt: DateTime.utc(2026),
      ),
      localOnly: false,
      at: DateTime.utc(2026),
    );
    expect(accepted?.output, 'summary');
  });
}
